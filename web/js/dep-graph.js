// Shared dependency-graph renderer used by show-mod's Graph tab and the standalone
// /dependency-graph page. Exposes a single global initDepGraph(canvas, opts) factory.
//
//   opts = {
//     modId:      number | null,    // null = global view
//     fetchUrl:   string,           // /api/v2/mods/dependency-graph[?modid=X]
//     onNodeTap:  function(data)    // optional: custom click handler, default navigates
//   }
//
// Returns { init, refresh, fit, exportPng, getCy }.
(function(global) {
	'use strict';

	function clear(el) { while (el.firstChild) el.removeChild(el.firstChild); }

	function setStatus(canvas, klass, text) {
		clear(canvas);
		var div = document.createElement('div');
		div.className = klass;
		div.textContent = text;
		canvas.appendChild(div);
	}

	function loadScript(src, nonce, cb, onerr) {
		var s = document.createElement('script');
		s.src = src;
		if (nonce) s.nonce = nonce;
		s.onload = cb;
		s.onerror = onerr;
		document.head.appendChild(s);
	}

	function loadLibs(canvas, cb) {
		var nonce = canvas.dataset.cspNonce;
		var fail = function() { setStatus(canvas, 'dep-graph-error', 'Failed to load Cytoscape library.'); };
		if (typeof cytoscape !== 'undefined' && cytoscape.layouts && cytoscape.layouts.cola) return cb();
		var chain = function(scripts, done) {
			if (!scripts.length) return done();
			loadScript(scripts.shift(), nonce, function() { chain(scripts, done); }, fail);
		};
		chain(['/web/js/cytoscape.min.js', '/web/js/cola.min.js', '/web/js/cytoscape-cola.js'], function() {
			if (typeof cytoscape !== 'undefined' && typeof cytoscapeCola !== 'undefined') {
				cytoscape.use(cytoscapeCola);
			}
			cb();
		});
	}

	// Detect pairs of opposite-direction edges with the same type (A -required-> B AND
	// B -required-> A) and merge them into a single edge with arrowheads on both ends.
	// Avoids the visually-noisy "X" of two crossing arrows in cycles.
	function buildElements(data, focusModId) {
		var elements = [];
		data.nodes.forEach(function(n) {
			elements.push({ data: {
				id: n.id, label: n.label || n.id, isLocal: !!n.isLocal,
				modId: n.modId || 0, urlAlias: n.urlAlias || '',
				version: n.latestVersion || '',
				focus: (focusModId && n.modId == focusModId)
			}});
		});
		var seen = Object.create(null);
		data.edges.forEach(function(e) {
			var fwdKey = e.from + '|' + e.to + '|' + e.type;
			var revKey = e.to + '|' + e.from + '|' + e.type;
			if (seen[revKey]) {
				seen[revKey].bidirectional = true;
				seen[revKey].inCycle = seen[revKey].inCycle || !!e.inCycle;
				return;
			}
			var ed = { id: 'e-' + fwdKey, source: e.from, target: e.to, type: e.type };
			if (e.inCycle) ed.inCycle = true;
			seen[fwdKey] = ed;
			elements.push({ data: ed });
		});
		return elements;
	}

	var STYLE = [
		{ selector: 'node', style: {
			'background-color': '#aaa', 'label': 'data(label)',
			'color': '#333', 'font-size': '13px',
			// text-valign/halign center so text-margin-x/y is the only positioning - auto-placement
			// (and the shift+drag override) then push labels in any direction relative to the node.
			'text-valign': 'center', 'text-halign': 'center',
			'text-margin-y': 30,
			'width': 38, 'height': 38,
			'border-width': 1, 'border-color': '#666',
			'text-wrap': 'wrap', 'text-max-width': '140px',
			'text-background-color': '#fff8e8',
			'text-background-opacity': 0.9,
			'text-background-padding': '3px',
			'text-background-shape': 'roundrectangle'
		}},
		{ selector: 'node[?isLocal]',  style: { 'background-color': '#3d6594', 'border-color': '#234166' }},
		{ selector: 'node[?focus]',    style: { 'background-color': '#c4925e', 'border-color': '#8a5e2e', 'border-width': 2, 'width': 50, 'height': 50 }},
		{ selector: 'node[!isLocal]',  style: { 'font-style': 'italic', 'background-color': '#ddd', 'border-color': '#aaa' }},
		{ selector: 'edge',            style: { 'width': 1.5, 'curve-style': 'bezier', 'target-arrow-shape': 'triangle', 'line-color': '#888', 'target-arrow-color': '#888' }},
		{ selector: 'edge[type = "required"]',     style: { 'line-color': '#3d6594', 'target-arrow-color': '#3d6594' }},
		{ selector: 'edge[type = "optional"]',     style: { 'line-color': '#4a7a3e', 'target-arrow-color': '#4a7a3e', 'line-style': 'dashed' }},
		{ selector: 'edge[type = "incompatible"]', style: { 'line-color': '#c45e5e', 'target-arrow-color': '#c45e5e', 'width': 2 }},
		{ selector: 'edge[type = "tested_with"]',  style: { 'line-color': '#999',    'target-arrow-color': '#999',    'line-style': 'dotted' }},
		{ selector: 'edge[?inCycle]',              style: { 'line-color': '#c45e5e', 'target-arrow-color': '#c45e5e', 'width': 3, 'line-style': 'solid' }},
		{ selector: 'edge[?bidirectional]',        style: { 'source-arrow-shape': 'triangle' }},
		{ selector: 'edge[type = "required"][?bidirectional]',     style: { 'source-arrow-color': '#3d6594' }},
		{ selector: 'edge[type = "optional"][?bidirectional]',     style: { 'source-arrow-color': '#4a7a3e' }},
		{ selector: 'edge[type = "incompatible"][?bidirectional]', style: { 'source-arrow-color': '#c45e5e' }},
		{ selector: 'edge[type = "tested_with"][?bidirectional]',  style: { 'source-arrow-color': '#999'    }},
		{ selector: 'edge[?inCycle][?bidirectional]',              style: { 'source-arrow-color': '#c45e5e' }}
	];

	// cola: continuous force-directed (Obsidian-style). breadthfirst when focused on one mod so
	// the deps/dependents hierarchy stays clear.
	function pickLayout(focusModId) {
		if (focusModId) {
			return { name: 'breadthfirst', directed: true, padding: 30, spacingFactor: 1.3, roots: '[?focus]', avoidOverlap: true, fit: true };
		}
		return {
			name: 'cola',
			animate: true, refresh: 1, maxSimulationTime: 4000,
			ungrabifyWhileSimulating: false,
			fit: true, padding: 60,
			nodeSpacing: 30, edgeLength: 140,
			randomize: false, avoidOverlap: true, infinite: false
		};
	}

	function defaultNodeTap(evt) {
		var n = evt.target.data();
		if (n.isLocal && n.modId) window.location.href = '/show/mod/' + n.modId;
	}

	global.initDepGraph = function(canvas, opts) {
		opts = opts || {};
		var cy = null;
		var inited = false;

		function render(data) {
			if (!data || !data.nodes || !data.nodes.length) {
				setStatus(canvas, 'dep-graph-empty', 'No relations to show.');
				return;
			}
			clear(canvas);
			cy = cytoscape({
				container: canvas,
				elements: buildElements(data, opts.modId),
				style: STYLE,
				layout: pickLayout(opts.modId),
				minZoom: 0.2, maxZoom: 3,
				wheelSensitivity: 0.2
			});
			cy.on('tap', 'node', opts.onNodeTap || defaultNodeTap);
			attachLabelDrag(cy);
			// Re-place labels each time the layout settles or the user moves a node, so labels keep
			// drifting toward the least-crowded side instead of always sitting under the circle.
			cy.on('layoutstop', function() { autoPlaceLabels(cy); });
			cy.on('dragfree', 'node', function(evt) { autoPlaceLabels(cy, evt.target); });
		}

		// Two-pass auto-placement.
		// Pass 1: position each node's label opposite the centroid of its neighbors so it lands
		// on the side with fewest edges.
		// Pass 2: iteratively detect label-label bounding-box overlaps and push the offending
		// labels apart along the line connecting their centers, until no overlap or maxIter hit.
		// Nodes pinned via shift+drag are skipped.
		function autoPlaceLabels(cyInstance, only) {
			var moving = only ? cyInstance.collection([only]) : cyInstance.nodes().filter(function(n) { return !n.data('_labelPinned'); });
			if (!moving.length) return;

			// Pass 1: initial direction from neighbor centroid.
			moving.forEach(function(node) {
				var neighbors = node.openNeighborhood().nodes();
				if (!neighbors.length) {
					node.style({ 'text-margin-x': 0, 'text-margin-y': 30 });
					return;
				}
				var p = node.position();
				var sx = 0, sy = 0;
				neighbors.forEach(function(nb) {
					var np = nb.position();
					sx += np.x - p.x;
					sy += np.y - p.y;
				});
				var ax = sx / neighbors.length, ay = sy / neighbors.length;
				var mag = Math.sqrt(ax * ax + ay * ay) || 1;
				var dist = 28;
				node.style({
					'text-margin-x': -ax / mag * dist,
					'text-margin-y': -ay / mag * dist
				});
			});

			// Pass 2: relax label-label overlaps. Compare every pair of moving labels and push them
			// along the connecting line until their bounding boxes no longer overlap.
			var all = cyInstance.nodes();
			var movingSet = {};
			moving.forEach(function(n) { movingSet[n.id()] = true; });
			for (var iter = 0; iter < 30; iter++) {
				var anyOverlap = false;
				for (var i = 0; i < all.length; i++) {
					for (var j = i + 1; j < all.length; j++) {
						var a = all[i], b = all[j];
						var ba = labelBB(a), bb = labelBB(b);
						if (ba.x2 < bb.x1 || bb.x2 < ba.x1 || ba.y2 < bb.y1 || bb.y2 < ba.y1) continue;
						// overlap: push each label half the overlap distance away from the other
						var cax = (ba.x1 + ba.x2) / 2, cay = (ba.y1 + ba.y2) / 2;
						var cbx = (bb.x1 + bb.x2) / 2, cby = (bb.y1 + bb.y2) / 2;
						var dx = cax - cbx, dy = cay - cby;
						var d = Math.sqrt(dx * dx + dy * dy) || 1;
						var overlapX = (ba.w + bb.w) / 2 - Math.abs(cax - cbx);
						var overlapY = (ba.h + bb.h) / 2 - Math.abs(cay - cby);
						var push = Math.min(overlapX, overlapY) / 2 + 1;
						var nx = dx / d * push, ny = dy / d * push;
						if (movingSet[a.id()]) shiftMargin(a, nx, ny);
						if (movingSet[b.id()]) shiftMargin(b, -nx, -ny);
						anyOverlap = true;
					}
				}
				if (!anyOverlap) break;
			}
		}

		function labelBB(node) {
			var p = node.position();
			var mx = parseFloat(node.style('text-margin-x')) || 0;
			var my = parseFloat(node.style('text-margin-y')) || 0;
			// Approx label box from the rendered text. Cytoscape doesn't expose label metrics
			// directly; this is an estimate (avg char width ~7px at font-size 13, line height 16).
			var label = node.data('label') || '';
			var maxLineLen = label.split('\n').reduce(function(m, l) { return Math.max(m, l.length); }, 0);
			if (!maxLineLen) maxLineLen = label.length;
			var w = Math.min(140, Math.max(40, maxLineLen * 7)) + 6;
			var lines = Math.ceil(label.length * 7 / 140);
			var h = lines * 16 + 6;
			var cx = p.x + mx, cy = p.y + my;
			return { x1: cx - w / 2, y1: cy - h / 2, x2: cx + w / 2, y2: cy + h / 2, w: w, h: h };
		}

		function shiftMargin(node, dx, dy) {
			node.style({
				'text-margin-x': (parseFloat(node.style('text-margin-x')) || 0) + dx,
				'text-margin-y': (parseFloat(node.style('text-margin-y')) || 0) + dy
			});
		}

		// Shift+drag on a node moves its label only (text-margin-x/y), not the node itself.
		// Lets authors nudge labels out of edge crossings to read busy graphs more easily.
		function attachLabelDrag(cyInstance) {
			var drag = null;
			cyInstance.on('tapstart', 'node', function(evt) {
				if (!evt.originalEvent || !evt.originalEvent.shiftKey) return;
				var node = evt.target;
				drag = {
					node: node,
					startX: evt.position.x,
					startY: evt.position.y,
					baseX: parseFloat(node.style('text-margin-x')) || 0,
					baseY: parseFloat(node.style('text-margin-y')) || 0
				};
				node.ungrabify(); // suppress the normal node drag
				evt.preventDefault();
			});
			cyInstance.on('tapdrag', function(evt) {
				if (!drag) return;
				drag.node.style({
					'text-margin-x': drag.baseX + (evt.position.x - drag.startX),
					'text-margin-y': drag.baseY + (evt.position.y - drag.startY)
				});
			});
			cyInstance.on('tapend', function() {
				if (!drag) return;
				drag.node.data('_labelPinned', true); // opt out of auto-placement going forward
				drag.node.grabify();
				drag = null;
			});
		}

		function fetchAndRender(url) {
			$.get(url || opts.fetchUrl)
				.done(render)
				.fail(function() { setStatus(canvas, 'dep-graph-error', 'Failed to load dependency graph.'); });
		}

		return {
			init: function() {
				if (inited) return;
				inited = true;
				loadLibs(canvas, function() { fetchAndRender(); });
			},
			refresh: function(url) {
				loadLibs(canvas, function() { fetchAndRender(url); });
			},
			fit: function() { if (cy) cy.fit(); },
			exportPng: function(filename) {
				if (!cy) return;
				var a = document.createElement('a');
				a.href = cy.png({ scale: 2, bg: '#fff8e8' });
				a.download = filename || 'dependency-graph.png';
				a.click();
			},
			getCy: function() { return cy; }
		};
	};
})(window);
