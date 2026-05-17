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
			'color': '#333', 'font-size': '13px', 'text-valign': 'bottom',
			'text-margin-y': 8, 'width': 38, 'height': 38,
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
