{include file="header" hclass="innercontent dependency-graph-page"}

<div class="dep-graph-fullpage">
	<h2>Mod dependency graph</h2>
	<p class="dep-graph-intro">
		Showing relations from the latest non-retracted release of every mod
		({$nodeCount} mods / {$edgeCount} edges in the database).
	</p>

	<div class="dep-graph-tab dep-graph-layout">
		<aside class="dep-graph-sidebar">
			<strong>Filters</strong>

			<div class="filter-group">
				<label>Focus on a mod:</label>
				<input type="text" id="dep-graph-search" placeholder="modid or url alias...">
				<small class="hint">Type and pick from the list to filter the subgraph.</small>
				<div id="dep-graph-search-results"></div>
			</div>

			<div class="filter-group">
				<label>Relation types:</label>
				<label class="option-row"><input type="checkbox" data-rel-type="required"     checked> Required</label>
				<label class="option-row"><input type="checkbox" data-rel-type="optional"     checked> Optional</label>
				<label class="option-row"><input type="checkbox" data-rel-type="incompatible" checked> Incompatible</label>
				<label class="option-row"><input type="checkbox" data-rel-type="tested_with"  checked> Tested with</label>
			</div>

			<div class="filter-group">
				<button type="button" id="dep-graph-reset">Reset view</button>
			</div>
		</aside>

		<div class="dep-graph-main">
			<div class="dep-graph-toolbar">
				<div class="legend">
					<span class="required">required</span>
					<span class="optional">optional</span>
					<span class="incompatible">incompatible</span>
					<span class="tested_with">tested with</span>
				</div>
				<div class="spacer"></div>
				<button type="button" id="dep-graph-fit">Fit</button>
				<button type="button" id="dep-graph-png">Export PNG</button>
			</div>
			<div id="dep-graph-canvas" data-csp-nonce="{$cspNonce}">
				<div class="dep-graph-loading">Loading dependency graph...</div>
			</div>
		</div>
	</div>
</div>

{capture name="footerjs"}
<script nonce="{$cspNonce}" type="text/javascript">
(function() {
	var canvas = document.getElementById('dep-graph-canvas');
	var searchBox = document.getElementById('dep-graph-search');
	var searchResults = document.getElementById('dep-graph-search-results');
	var typeFilters = document.querySelectorAll('input[data-rel-type]');
	var resetBtn = document.getElementById('dep-graph-reset');
	var cy = null;
	var rawData = null;
	var focusModId = null;

	function setStatus(klass, text) {
		while (canvas.firstChild) canvas.removeChild(canvas.firstChild);
		var div = document.createElement('div');
		div.className = klass;
		div.textContent = text;
		canvas.appendChild(div);
	}

	function loadScript(src, cb) {
		var s = document.createElement('script');
		s.src = src;
		s.nonce = canvas.dataset.cspNonce;
		s.onload = cb;
		s.onerror = function() { setStatus('dep-graph-error', 'Failed to load ' + src); };
		document.head.appendChild(s);
	}

	function loadCytoscape(cb) {
		if (typeof cytoscape !== 'undefined' && cytoscape.layouts && cytoscape.layouts.cola) return cb();
		var chain = function(scripts, done) {
			if (!scripts.length) return done();
			loadScript(scripts.shift(), function() { chain(scripts, done); });
		};
		chain(['/web/js/cytoscape.min.js', '/web/js/cola.min.js', '/web/js/cytoscape-cola.js'], function() {
			if (typeof cytoscape !== 'undefined' && typeof cytoscapeCola !== 'undefined') {
				cytoscape.use(cytoscapeCola);
			}
			cb();
		});
	}

	function activeTypes() {
		return Array.prototype.map.call(typeFilters, function(cb) { return cb.checked ? cb.dataset.relType : null; })
			.filter(function(t) { return t !== null; });
	}

	function fetchData(cb) {
		var params = { types: activeTypes().join(',') };
		if (focusModId) params.modid = focusModId;
		$.get('/api/v2/mods/dependency-graph?' + $.param(params))
			.done(function(data) { rawData = data; cb(); })
			.fail(function() { setStatus('dep-graph-error', 'Failed to load dependency graph.'); });
	}

	function buildElements(data) {
		var elements = [];
		data.nodes.forEach(function(n) {
			elements.push({ data: {
				id: n.id, label: n.label || n.id, isLocal: !!n.isLocal,
				modId: n.modId || 0, urlAlias: n.urlAlias || '',
				version: n.latestVersion || '', focus: (focusModId && n.modId == focusModId)
			}});
		});

		// Detect pairs of opposite-direction edges with the same type (A -required-> B AND
		// B -required-> A). Render those as one edge with arrows on both ends so the graph
		// stays readable and the cycle is obvious without an "X" of two crossing arrows.
		var seen = Object.create(null);
		data.edges.forEach(function(e) {
			var fwdKey = e.from + '|' + e.to + '|' + e.type;
			var revKey = e.to + '|' + e.from + '|' + e.type;
			if (seen[revKey]) {
				seen[revKey].bidirectional = true;
				seen[revKey].inCycle = seen[revKey].inCycle || !!e.inCycle;
				return;
			}
			var data2 = { id: 'e-' + fwdKey, source: e.from, target: e.to, type: e.type };
			if (e.inCycle) data2.inCycle = true;
			seen[fwdKey] = data2;
			elements.push({ data: data2 });
		});
		return elements;
	}

	var commonStyle = [
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
		{ selector: 'node[?isLocal]', style: { 'background-color': '#3d6594', 'border-color': '#234166' }},
		{ selector: 'node[?focus]', style: { 'background-color': '#c4925e', 'border-color': '#8a5e2e', 'border-width': 2, 'width': 50, 'height': 50 }},
		{ selector: 'node[!isLocal]', style: { 'font-style': 'italic', 'background-color': '#ddd', 'border-color': '#aaa' }},
		{ selector: 'edge', style: { 'width': 1.2, 'curve-style': 'bezier', 'target-arrow-shape': 'triangle', 'line-color': '#888', 'target-arrow-color': '#888' }},
		{ selector: 'edge[type = "required"]',     style: { 'line-color': '#3d6594', 'target-arrow-color': '#3d6594' }},
		{ selector: 'edge[type = "optional"]',     style: { 'line-color': '#4a7a3e', 'target-arrow-color': '#4a7a3e', 'line-style': 'dashed' }},
		{ selector: 'edge[type = "incompatible"]', style: { 'line-color': '#c45e5e', 'target-arrow-color': '#c45e5e', 'width': 2 }},
		{ selector: 'edge[type = "tested_with"]',  style: { 'line-color': '#999',    'target-arrow-color': '#999',    'line-style': 'dotted' }},
		{ selector: 'edge[?inCycle]',              style: { 'line-color': '#c45e5e', 'target-arrow-color': '#c45e5e', 'width': 3, 'line-style': 'solid' }},
		{ selector: 'edge[?bidirectional]', style: { 'source-arrow-shape': 'triangle', 'source-arrow-color': 'data(lineColor)' }},
		// Re-apply per-type colors to the source arrow to match the edge.
		{ selector: 'edge[type = "required"][?bidirectional]',     style: { 'source-arrow-color': '#3d6594' }},
		{ selector: 'edge[type = "optional"][?bidirectional]',     style: { 'source-arrow-color': '#4a7a3e' }},
		{ selector: 'edge[type = "incompatible"][?bidirectional]', style: { 'source-arrow-color': '#c45e5e' }},
		{ selector: 'edge[type = "tested_with"][?bidirectional]',  style: { 'source-arrow-color': '#999'    }},
		{ selector: 'edge[?inCycle][?bidirectional]',              style: { 'source-arrow-color': '#c45e5e' }},
	];

	// cola is a continuous force-directed layout (Obsidian-style): nodes repel each other, edges
	// act like springs, and dragging a node makes the rest react in real time. Falls back to
	// breadthfirst when the user focused on one mod so the hierarchy stays clear.
	function pickLayout(nodeCount) {
		var bboxSize = Math.min(900, 250 + nodeCount * 35);
		var bbox = { x1: 0, y1: 0, w: bboxSize, h: bboxSize };
		if (focusModId) {
			return { name: 'breadthfirst', directed: true, padding: 30, spacingFactor: 1.3, roots: '[?focus]', avoidOverlap: true, fit: false, boundingBox: bbox };
		}
		return {
			name: 'cola',
			animate: true,
			refresh: 1,
			maxSimulationTime: 4000,
			ungrabifyWhileSimulating: false,
			fit: false,
			padding: 30,
			boundingBox: bbox,
			nodeSpacing: 30,
			edgeLength: 120,
			randomize: false,
			avoidOverlap: true,
			infinite: false
		};
	}

	function render() {
		if (!rawData) return;
		if (!rawData.nodes.length) {
			setStatus('dep-graph-empty', 'No relations declared in the database yet.');
			return;
		}
		while (canvas.firstChild) canvas.removeChild(canvas.firstChild);
		cy = cytoscape({
			container: canvas,
			elements: buildElements(rawData),
			style: commonStyle,
			layout: pickLayout(rawData.nodes.length),
			minZoom: 0.2,
			maxZoom: 3,
			wheelSensitivity: 0.2
		});
		// Center the graph at a comfortable zoom level (not auto-fit). For small graphs this keeps
		// nodes readable; user can hit Fit if they want everything edge-to-edge.
		cy.one('layoutstop', function() {
			cy.zoom(1);
			cy.center(cy.elements());
		});
		cy.on('tap', 'node', function(evt) {
			var n = evt.target.data();
			if (n.isLocal && n.modId) {
				focusModId = n.modId;
				searchBox.value = n.urlAlias || n.id;
				refresh();
			}
		});
	}

	function refresh() {
		loadCytoscape(function() { fetchData(render); });
	}

	// Search: incremental filter against rawData (or fetch full and filter).
	searchBox.addEventListener('input', function() {
		var q = searchBox.value.toLowerCase().trim();
		while (searchResults.firstChild) searchResults.removeChild(searchResults.firstChild);
		if (!q || !rawData) return;
		var matches = rawData.nodes.filter(function(n) {
			return n.isLocal && ((n.id && n.id.toLowerCase().indexOf(q) >= 0) ||
				(n.label && n.label.toLowerCase().indexOf(q) >= 0) ||
				(n.urlAlias && n.urlAlias.toLowerCase().indexOf(q) >= 0));
		}).slice(0, 8);
		matches.forEach(function(n) {
			var a = document.createElement('a');
			a.href = '#';
			a.style.cssText = 'display:block;padding:.25em;text-decoration:none;color:var(--color-link);';
			a.textContent = n.label + ' (' + n.id + ')';
			a.onclick = function(e) {
				e.preventDefault();
				focusModId = n.modId;
				searchBox.value = n.urlAlias || n.id;
				while (searchResults.firstChild) searchResults.removeChild(searchResults.firstChild);
				refresh();
			};
			searchResults.appendChild(a);
		});
	});

	typeFilters.forEach(function(cb) { cb.addEventListener('change', refresh); });

	resetBtn.addEventListener('click', function() {
		focusModId = null;
		searchBox.value = '';
		while (searchResults.firstChild) searchResults.removeChild(searchResults.firstChild);
		typeFilters.forEach(function(cb) { cb.checked = true; });
		refresh();
	});

	document.getElementById('dep-graph-fit').addEventListener('click', function() { if (cy) cy.fit(); });
	document.getElementById('dep-graph-png').addEventListener('click', function() {
		if (!cy) return;
		var png = cy.png({ scale: 2, bg: '#fff8e8' });
		var a = document.createElement('a');
		a.href = png;
		a.download = 'dependency-graph.png';
		a.click();
	});

	refresh();
})();
</script>
{/capture}

{include file="footer"}
