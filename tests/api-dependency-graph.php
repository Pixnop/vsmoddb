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
}
