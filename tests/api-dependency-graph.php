<?php

include_once "prelude.php";
include_once $config['basepath'].'lib/version.php';
include_once $config['basepath'].'lib/relations.php';

use PHPUnit\Framework\TestCase;

/** Helper: invoke the dependency-graph endpoint via cURL against the running dev site. */
function callDependencyGraph(array $query = []): array
{
	$gatewayIp = gethostbyname('gateway');
	if ($gatewayIp === 'gateway') $gatewayIp = '127.0.0.1';

	$url = 'https://mods.vintagestory.stage/api/v2/mods/dependency-graph';
	if ($query) $url .= '?'.http_build_query($query);
	$ch = curl_init($url);
	curl_setopt_array($ch, [
		CURLOPT_RETURNTRANSFER => true,
		CURLOPT_SSL_VERIFYPEER => false,
		CURLOPT_SSL_VERIFYHOST => false,
		CURLOPT_RESOLVE        => ['mods.vintagestory.stage:443:'.$gatewayIp],
	]);
	$body = curl_exec($ch);
	$code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
	curl_close($ch);
	return ['code' => $code, 'body' => json_decode($body, true) ?: []];
}

final class ApiDependencyGraphTest extends TestCase
{
	public function testGlobalGraphReturnsNodesAndEdges(): void
	{
		$r = callDependencyGraph();
		$this->assertEquals(200, $r['code']);
		$this->assertArrayHasKey('nodes', $r['body']);
		$this->assertArrayHasKey('edges', $r['body']);
		$this->assertIsArray($r['body']['nodes']);
		$this->assertIsArray($r['body']['edges']);
	}

	public function testNodeShape(): void
	{
		$r = callDependencyGraph();
		$this->assertNotEmpty($r['body']['nodes'], 'global graph should include at least one node');
		$node = $r['body']['nodes'][0];
		$this->assertArrayHasKey('id', $node, 'node must have an id (the modinfo identifier)');
		$this->assertArrayHasKey('label', $node);
		$this->assertArrayHasKey('isLocal', $node, 'node must declare whether it is hosted in this moddb');
		if ($node['isLocal']) {
			$this->assertArrayHasKey('modId', $node);
			$this->assertArrayHasKey('urlAlias', $node);
		}
	}

	public function testEdgeShape(): void
	{
		$r = callDependencyGraph();
		if (empty($r['body']['edges'])) {
			$this->markTestSkipped('No edges in current dataset');
		}
		$edge = $r['body']['edges'][0];
		$this->assertArrayHasKey('from', $edge);
		$this->assertArrayHasKey('to', $edge);
		$this->assertArrayHasKey('type', $edge);
		$this->assertContains($edge['type'], ['required','optional','incompatible','tested_with']);
	}

	public function testFocusedSubgraphReturnsOnlyRelevantNodes(): void
	{
		global $con;
		$modId = $con->getOne("SELECT modId FROM mods WHERE urlAlias = 'rel-test-A'");
		if (!$modId) $this->markTestSkipped('rel-test-A mod not present; run integration tests first');

		$r = callDependencyGraph(['modid' => $modId]);
		$this->assertEquals(200, $r['code']);
		$ids = array_column($r['body']['nodes'], 'id');
		$this->assertContains('rel-test-A', $ids, 'focused graph must include the focused mod itself');
	}

	public function testFocusedSubgraphForUnknownModReturns404(): void
	{
		$r = callDependencyGraph(['modid' => 999999999]);
		$this->assertEquals(404, $r['code']);
	}

	public function testRelationTypeFilter(): void
	{
		$r = callDependencyGraph(['types' => 'required']);
		$this->assertEquals(200, $r['code']);
		foreach ($r['body']['edges'] as $edge) {
			$this->assertEquals('required', $edge['type'], 'types filter must restrict edges');
		}
	}

	public function testCycleHighlightFlagsBackEdges(): void
	{
		global $con;
		$relA = (int)$con->getOne("SELECT releaseId FROM modReleases WHERE identifier = 'rel-test-A'");
		$relB = (int)$con->getOne("SELECT releaseId FROM modReleases WHERE identifier = 'rel-test-B'");
		if (!$relA || !$relB) $this->markTestSkipped('rel-test fixture not present');

		// Wipe and create a tight A -> B -> A cycle.
		$con->execute("DELETE FROM modRelations WHERE releaseId IN (?,?)", [$relA, $relB]);
		$userId = (int)$con->getOne("SELECT userId FROM users LIMIT 1");
		$con->execute("INSERT INTO modRelations (releaseId, targetIdentifier, relationType, origin, createdByUserId) VALUES (?,?,?,?,?)",
			[$relA, 'rel-test-B', 'required', 'manual', $userId]);
		$con->execute("INSERT INTO modRelations (releaseId, targetIdentifier, relationType, origin, createdByUserId) VALUES (?,?,?,?,?)",
			[$relB, 'rel-test-A', 'required', 'manual', $userId]);

		$r = callDependencyGraph();
		$this->assertEquals(200, $r['code']);
		$hasCycleEdge = false;
		foreach ($r['body']['edges'] as $edge) {
			if (!empty($edge['inCycle'])) { $hasCycleEdge = true; break; }
		}
		$this->assertTrue($hasCycleEdge, 'API must flag at least one edge with inCycle when relations form a cycle');

		$con->execute("DELETE FROM modRelations WHERE releaseId IN (?,?)", [$relA, $relB]);
	}

	public function testGlobalGraphHandlesLargeDataset(): void
	{
		// Stress test: 60 mods, each requiring the next two and one optional, forming a wide DAG
		// with several cycles introduced on purpose. Confirms the endpoint completes in reasonable
		// time and returns a coherent graph.
		global $con;
		$userId = (int)$con->getOne("SELECT userId FROM users LIMIT 1");

		$createdMods = [];
		$createdAssets = [];
		$createdReleases = [];
		try {
			$N = 60;
			for ($i = 0; $i < $N; $i++) {
				$id = 'stress-mod-'.$i;
				$existing = $con->getOne("SELECT modId FROM mods WHERE urlAlias = ?", [$id]);
				if ($existing) {
					$createdMods[] = (int)$existing;
					$createdReleases[] = (int)$con->getOne("SELECT releaseId FROM modReleases WHERE modId = ? LIMIT 1", [$existing]);
					continue;
				}
				$con->execute("INSERT INTO assets (createdByUserId, statusId, assetTypeId, name, text) VALUES (?,?,?,?,?)",
					[$userId, STATUS_RELEASED, ASSETTYPE_MOD, 'Stress Mod '.$i, '']);
				$assetId = (int)$con->Insert_ID();
				$createdAssets[] = $assetId;
				$con->execute("INSERT INTO mods (assetId, urlAlias, summary, descriptionSearchable, side, lastReleased) VALUES (?,?,?,?,?,NOW())",
					[$assetId, $id, $id, $id, 'both']);
				$modId = (int)$con->Insert_ID();
				$createdMods[] = $modId;
				$con->execute("INSERT INTO assets (createdByUserId, statusId, assetTypeId, name) VALUES (?,?,?,?)",
					[$userId, STATUS_RELEASED, ASSETTYPE_MOD, $id.'-r1']);
				$relAssetId = (int)$con->Insert_ID();
				$createdAssets[] = $relAssetId;
				$con->execute("INSERT INTO modReleases (assetId, modId, identifier, version) VALUES (?,?,?,?)",
					[$relAssetId, $modId, $id, compileSemanticVersion('1.0.0')]);
				$relId = (int)$con->Insert_ID();
				$createdReleases[] = $relId;
				$con->execute("INSERT INTO files (assetId, assetTypeId, userId, name, cdnPath, `order`) VALUES (?,?,?,?,?,?)",
					[$relAssetId, ASSETTYPE_MOD, $userId, $id.'.zip', '/cdn/'.$id.'.zip', 0]);
			}
			// Wire up relations: each mod requires the next two and optionally tests-with the one after that.
			// Introduce 3 explicit cycles to exercise the detector.
			for ($i = 0; $i < $N; $i++) {
				$src = $createdReleases[$i];
				if ($i + 1 < $N) {
					$con->execute("INSERT IGNORE INTO modRelations (releaseId, targetIdentifier, relationType, origin, createdByUserId) VALUES (?,?,?,?,?)",
						[$src, 'stress-mod-'.($i + 1), 'required', 'manual', $userId]);
				}
				if ($i + 2 < $N) {
					$con->execute("INSERT IGNORE INTO modRelations (releaseId, targetIdentifier, relationType, origin, createdByUserId) VALUES (?,?,?,?,?)",
						[$src, 'stress-mod-'.($i + 2), 'optional', 'manual', $userId]);
				}
			}
			// Cycles: 0 -> 10 -> 0, 20 -> 30 -> 20, 40 -> 55 -> 40
			foreach ([[0, 10], [20, 30], [40, 55]] as $pair) {
				$con->execute("INSERT IGNORE INTO modRelations (releaseId, targetIdentifier, relationType, origin, createdByUserId) VALUES (?,?,?,?,?)",
					[$createdReleases[$pair[0]], 'stress-mod-'.$pair[1], 'required', 'manual', $userId]);
				$con->execute("INSERT IGNORE INTO modRelations (releaseId, targetIdentifier, relationType, origin, createdByUserId) VALUES (?,?,?,?,?)",
					[$createdReleases[$pair[1]], 'stress-mod-'.$pair[0], 'required', 'manual', $userId]);
			}

			$start = microtime(true);
			$r = callDependencyGraph();
			$elapsed = microtime(true) - $start;

			$this->assertEquals(200, $r['code']);
			$this->assertGreaterThanOrEqual($N, count($r['body']['nodes']), 'all stress mods must be in the graph');
			$cycleEdges = array_filter($r['body']['edges'], fn($e) => !empty($e['inCycle']));
			$this->assertGreaterThanOrEqual(3, count($cycleEdges), 'at least the 3 explicit cycles must be flagged');
			$this->assertLessThan(2.0, $elapsed, "global graph endpoint should respond in <2s for $N mods (took {$elapsed}s)");
		} finally {
			// Cleanup in dependency order: relations -> files -> releases -> mods -> assets.
			$relIn = implode(',', array_map('intval', $createdReleases));
			if ($relIn) $con->execute("DELETE FROM modRelations WHERE releaseId IN ($relIn)");
			$con->execute("DELETE FROM modRelations WHERE targetIdentifier LIKE 'stress-mod-%'");
			$assetIn = implode(',', array_map('intval', $createdAssets));
			if ($assetIn) {
				$con->execute("DELETE FROM files WHERE assetId IN ($assetIn)");
				$con->execute("DELETE FROM modReleases WHERE assetId IN ($assetIn)");
			}
			$modIn = implode(',', array_map('intval', $createdMods));
			if ($modIn) $con->execute("DELETE FROM mods WHERE modId IN ($modIn)");
			if ($assetIn) $con->execute("DELETE FROM assets WHERE assetId IN ($assetIn)");
		}
	}
}
