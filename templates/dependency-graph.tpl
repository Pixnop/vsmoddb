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
<script nonce="{$cspNonce}" type="text/javascript" src="/web/js/dep-graph.js"></script>
<script nonce="{$cspNonce}" type="text/javascript">
(function() {
	var canvas        = document.getElementById('dep-graph-canvas');
	var searchBox     = document.getElementById('dep-graph-search');
	var searchResults = document.getElementById('dep-graph-search-results');
	var typeFilters   = document.querySelectorAll('input[data-rel-type]');
	var resetBtn      = document.getElementById('dep-graph-reset');
	var lastNodes     = []; // cached node list for the search autocomplete
	var focusModId    = null;

	function activeTypes() {
		return Array.prototype.map.call(typeFilters, function(cb) { return cb.checked ? cb.dataset.relType : null; })
			.filter(function(t) { return t !== null; });
	}

	function fetchUrl() {
		var params = { types: activeTypes().join(',') };
		if (focusModId) params.modid = focusModId;
		return '/api/v2/mods/dependency-graph?' + $.param(params);
	}

	function clearResults() { while (searchResults.firstChild) searchResults.removeChild(searchResults.firstChild); }

	var graph = initDepGraph(canvas, {
		modId: null,
		fetchUrl: fetchUrl(),
		onNodeTap: function(evt) {
			var n = evt.target.data();
			if (!n.isLocal || !n.modId) return;
			focusModId = n.modId;
			searchBox.value = n.urlAlias || n.id;
			refresh();
		}
	});

	function refresh() {
		// Cache the previously-rendered nodes for the search autocomplete and re-fetch.
		var prevCy = graph.getCy();
		if (prevCy) {
			lastNodes = prevCy.nodes().map(function(n) { return n.data(); }).filter(function(d) { return d.isLocal; });
		}
		graph.refresh(fetchUrl());
	}

	searchBox.addEventListener('input', function() {
		var q = searchBox.value.toLowerCase().trim();
		clearResults();
		if (!q || !lastNodes.length) return;
		var matches = lastNodes.filter(function(n) {
			return (n.id && n.id.toLowerCase().indexOf(q) >= 0) ||
			       (n.label && n.label.toLowerCase().indexOf(q) >= 0) ||
			       (n.urlAlias && n.urlAlias.toLowerCase().indexOf(q) >= 0);
		}).slice(0, 8);
		matches.forEach(function(n) {
			var a = document.createElement('a');
			a.href = '#';
			a.className = 'dep-graph-search-result';
			a.textContent = n.label + ' (' + n.id + ')';
			a.addEventListener('click', function(e) {
				e.preventDefault();
				focusModId = n.modId;
				searchBox.value = n.urlAlias || n.id;
				clearResults();
				refresh();
			});
			searchResults.appendChild(a);
		});
	});

	typeFilters.forEach(function(cb) { cb.addEventListener('change', refresh); });

	resetBtn.addEventListener('click', function() {
		focusModId = null;
		searchBox.value = '';
		clearResults();
		typeFilters.forEach(function(cb) { cb.checked = true; });
		refresh();
	});

	document.getElementById('dep-graph-fit').addEventListener('click', graph.fit);
	document.getElementById('dep-graph-png').addEventListener('click', function() { graph.exportPng('dependency-graph.png'); });

	graph.init();
	// Populate the search cache on first load.
	setTimeout(function() {
		var cy = graph.getCy();
		if (cy) lastNodes = cy.nodes().map(function(n) { return n.data(); }).filter(function(d) { return d.isLocal; });
	}, 500);
})();
</script>
{/capture}

{include file="footer"}
