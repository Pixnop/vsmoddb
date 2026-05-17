{include file="header" hclass="innercontent dependency-graph-page"}

<div class="dep-graph-fullpage" style="padding: 1em;">
	<h2 style="margin: 0 0 .5em 0;">Mod dependency graph</h2>
	<p style="margin-bottom: 1em; color: var(--color-text-weak);">
		Showing relations from the latest non-retracted release of every mod
		({$nodeCount} mods / {$edgeCount} edges in the database).
	</p>

	<div class="dep-graph-tab" style="display: flex; gap: 1em; align-items: flex-start;">
		<aside style="flex: 0 0 220px; background: var(--color-content-bg); border: 1px solid var(--color-border); padding: .75em;">
			<strong>Filters</strong>
			<div style="margin-top: .5em;">
				<label style="display: block; font-size: .9em; margin-bottom: .25em;">Focus on a mod:</label>
				<input type="text" id="dep-graph-search" placeholder="modid or url alias..." style="width: 100%;">
				<small style="color: var(--color-text-weak);">Type and pick from the list to filter the subgraph.</small>
				<div id="dep-graph-search-results" style="margin-top: .25em; max-height: 200px; overflow-y: auto;"></div>
			</div>

			<div style="margin-top: 1em;">
				<label style="display: block; font-size: .9em; margin-bottom: .25em;">Relation types:</label>
				<label style="display:block;"><input type="checkbox" data-rel-type="required"     checked> Required</label>
				<label style="display:block;"><input type="checkbox" data-rel-type="optional"     checked> Optional</label>
				<label style="display:block;"><input type="checkbox" data-rel-type="incompatible" checked> Incompatible</label>
				<label style="display:block;"><input type="checkbox" data-rel-type="tested_with"  checked> Tested with</label>
			</div>

			<div style="margin-top: 1em;">
				<button type="button" id="dep-graph-reset" style="width: 100%; padding: .4em;">Reset view</button>
			</div>
		</aside>

		<div style="flex: 1; min-width: 0;">
			<div class="dep-graph-toolbar">
				<div class="legend">
					<span class="required">required</span>
					<span class="optional">optional</span>
					<span class="incompatible">incompatible</span>
					<span class="tested_with">tested with</span>
				</div>
				<div style="flex:1"></div>
				<button type="button" id="dep-graph-fit">Fit</button>
				<button type="button" id="dep-graph-png">Export PNG</button>
			</div>
			<div id="dep-graph-canvas" style="height: 75vh;" data-csp-nonce="{$cspNonce}">
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

	function loadCytoscape(cb) {
		if (typeof cytoscape !== 'undefined') return cb();
		var s = document.createElement('script');
		s.src = '/web/js/cytoscape.min.js';
		s.nonce = canvas.dataset.cspNonce;
		s.onload = cb;
		s.onerror = function() { setStatus('dep-graph-error', 'Failed to load Cytoscape library.'); };
		document.head.appendChild(s);
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
		data.edges.forEach(function(e, i) {
			elements.push({ data: { id: 'e'+i, source: e.from, target: e.to, type: e.type } });
		});
		return elements;
	}

	var commonStyle = [
		{ selector: 'node', style: {
			'background-color': '#aaa', 'label': 'data(label)',
			'color': '#333', 'font-size': '11px', 'text-valign': 'bottom',
			'text-margin-y': 4, 'width': 22, 'height': 22,
			'border-width': 1, 'border-color': '#666'
		}},
		{ selector: 'node[?isLocal]', style: { 'background-color': '#3d6594', 'border-color': '#234166' }},
		{ selector: 'node[?focus]', style: { 'background-color': '#c4925e', 'border-color': '#8a5e2e', 'border-width': 2, 'width': 32, 'height': 32 }},
		{ selector: 'node[!isLocal]', style: { 'font-style': 'italic', 'background-color': '#ddd', 'border-color': '#aaa' }},
		{ selector: 'edge', style: { 'width': 1.2, 'curve-style': 'bezier', 'target-arrow-shape': 'triangle', 'line-color': '#888', 'target-arrow-color': '#888' }},
		{ selector: 'edge[type = "required"]',     style: { 'line-color': '#3d6594', 'target-arrow-color': '#3d6594' }},
		{ selector: 'edge[type = "optional"]',     style: { 'line-color': '#4a7a3e', 'target-arrow-color': '#4a7a3e', 'line-style': 'dashed' }},
		{ selector: 'edge[type = "incompatible"]', style: { 'line-color': '#c45e5e', 'target-arrow-color': '#c45e5e', 'width': 2 }},
		{ selector: 'edge[type = "tested_with"]',  style: { 'line-color': '#999',    'target-arrow-color': '#999',    'line-style': 'dotted' }},
	];

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
			layout: focusModId
				? { name: 'breadthfirst', directed: true, padding: 20, spacingFactor: 1.4, roots: '[?focus]' }
				: { name: 'cose', padding: 20, animate: false, idealEdgeLength: 80, nodeOverlap: 8 },
			wheelSensitivity: 0.2
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
