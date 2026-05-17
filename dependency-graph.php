<?php

include_once $config['basepath'].'lib/relations.php';

// CSP: allow the dependency-graph API endpoint for fetch and cytoscape's inline styles.
cspReplaceAllowedFetchSources("{$_SERVER['HTTP_HOST']}/api/v2/mods/dependency-graph");
cspAllowCytoscape();

// Quick stats for the page header.
$nodeCount = (int)$con->getOne("SELECT COUNT(*) FROM mods");
$edgeCount = (int)$con->getOne("SELECT COUNT(*) FROM modRelations r JOIN (
	SELECT identifier, MAX(releaseId) AS maxRel
	FROM modReleases
	WHERE identifier IS NOT NULL
	GROUP BY identifier
) latest ON latest.maxRel = r.releaseId");

// Optional ?tag=X filter is handled client-side once data is fetched (the API doesn't yet support tag filtering;
// adding it server-side would require joining modTags - flagged as a follow-up).
$view->assign('pagetitle', 'Dependency Graph - ');
$view->assign('nodeCount', $nodeCount, null, true);
$view->assign('edgeCount', $edgeCount, null, true);
$view->assign('headerHighlight', HEADER_HIGHLIGHT_DEPGRAPH, null, true);

$view->display('dependency-graph');
