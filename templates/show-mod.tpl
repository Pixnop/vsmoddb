{capture name="head"}
<meta content="{$asset['name']}" property="og:title" />
<meta content="{htmlspecialchars(strip_tags($assetraw['text']))}" property="og:description" />
<meta name="twitter:card" content="summary_large_image">
{if (empty($asset['logoUrl']))}
<meta content="/web/img/mod-default.png" property="og:image" />
{else}
<meta content="{$asset['logoUrl']}" property="og:image" />
{/if}
<meta content="#91A357" name="theme-color" />
{/capture}

{include file="header"}

{if $transferownership}
	<form class="teaminvite overlay-when-readonly" method="post">
		<input type="hidden" name="at" value="{$user['actionToken']}">
		<span>You have been invited to become the owner of this modification.</span>
		<div class="buttons">
			<button type="submit" name="acceptownershiptransfer" value="1" title="Accept Ownership" class="button submit">Accept</button>
			<button type="submit" name="acceptownershiptransfer" value="0" title="Decline Ownership" class="button btndelete">Decline</button>
		</div>
	</form>
{elseif $teaminvite}
	<form class="teaminvite overlay-when-readonly" method="post">
		<input type="hidden" name="at" value="{$user['actionToken']}">
		<span>You have been invited to join the team of this mod</span>
		<div class="buttons">
			<button type="submit" name="acceptteaminvite" value="1" title="Click here to join to the team of this mod" class="button submit">Accept</button>
			<button type="submit" name="acceptteaminvite" value="0" title="Click here to decline the invitation to the team" class="button btndelete">Decline</button>
		</div>
	</form>
{/if}

<div class="edit-asset mod-{$asset['statusCode']}">
	<h2>
		<span>
		{if $asset['category'] === CATEGORY_SERVER_TWEAK}
			<a href="/list/mod?c=s">Server Tweaks</a>
		{else}
			<a href="/list/mod">Mods</a>
		{/if}
		</span> /
		<span>
			{$asset["name"] ?? 'Add new Mod'}
		</span>
	</h2>

	{if $asset['statusCode']=='draft'}
		<div class="showmod-draftnotice">
			<h2 style="margin-bottom: 0;">Draft</h2>
			<small>Set to published to be listed. A draft mod is still visible to everyone via direct link</small>
		</div>
	{elseif $asset['statusCode']=='locked'}
		<div class="showmod-draftnotice" style="color:#e00">
			<h2 style="margin-bottom: 0;">Locked&nbsp;<i class="ico alert"></i></h2>
			<small>This mod has been locked by a moderator. The author may edit their mod to address existing issues.</small>
		</div>
	{/if}

	<input class="tab-trigger" id="tab-description" type="radio" name="tab" checked="true" autocomplete="off">
	<input class="tab-trigger" id="tab-files" type="radio" name="tab" autocomplete="off">
	<input class="tab-trigger" id="tab-graph" type="radio" name="tab" autocomplete="off">

	<script nonce="{$cspNonce}">
		(function() {
			var byHash = { '#tab-files': 'tab-files', '#tab-graph': 'tab-graph' };
			var initial = byHash[location.hash] || 'tab-description';
			document.getElementById(initial).checked = true;
			window.addEventListener('pageshow', function(e) {
				if (e.persisted) document.getElementById(byHash[location.hash] || 'tab-description').checked = true;
			});
		})();
	</script>


	<ul class="tabs no-mark">
		<li><label for="tab-description" onclick="location.hash = 'tab-description'">Description</label></li>
		<li><label for="tab-files" onclick="location.hash = 'tab-files'">Files</label></li>
		<li><label for="tab-graph" onclick="location.hash = 'tab-graph'">Graph</label></li>
		{if $asset['homepageUrl']}
			<li><a class="external" rel="external nofollow" target="_blank" href="{$asset['homepageUrl']}">Homepage</a></li>
		{/if}
		{if $asset['wikiUrl']}
			<li><a class="external" rel="external nofollow" target="_blank" href="{$asset['wikiUrl']}">Wiki</a></li>
		{/if}
		{if $asset['issueTrackerUrl']}
			<li><a class="external" rel="external nofollow" target="_blank" href="{$asset['issueTrackerUrl']}">Issue tracker</a></li>
		{/if}
		{if $asset['sourceCodeUrl']}
			<li><a class="external" rel="external nofollow" target="_blank" href="{$asset['sourceCodeUrl']}">Source</a></li>
		{/if}
		{if $asset['donateUrl']}
			<li><a class="external" rel="external nofollow" target="_blank" href="{$asset['donateUrl']}">Donate</a></li>
		{/if}
	</ul>

	<div class="tab-container">
		<div class="tab-content description">
			<div style="float: right; margin-bottom: 1em;">
				{if isset($user) && canEditAsset($asset, $user)}
					<a class="button large shine strikethrough-when-banned strikethrough-when-readonly" href="/edit/mod/?assetid={$asset['assetId']}">Edit</a>&nbsp;
					<a class="button large shine strikethrough-when-banned strikethrough-when-readonly" href="/edit/release/?modid={$asset['modId']}">Add release</a>
				{/if}
			</div>

			<div class="imageslideshow fotorama" data-max-width="min(800px, 100%)" data-max-height="450"{if !empty($asset['trailerVideoUrl'])} data-width="800"{/if} data-autoplay="5000" data-nav="thumbs" data-allowfullscreen="true">
				{if !empty($asset['trailerVideoUrl'])}
					<a rel="nofollow" href="{$asset['trailerVideoUrl']}">Trailer Video</a>
				{/if}
				{foreach from=$files item=file}
					<img src="{$file['url']}">
				{/foreach}
				{if empty($files) && empty($asset['trailerVideoUrl']) && !empty($asset['logoUrl'])}
				<img src="{$asset['logoUrl']}">
				{/if}
			</div>

			<dl class="infobox{if empty($asset['trailerVideoUrl']) && empty($files)} nomedia{/if}">
				<dt>Tags:</dt>
				{if empty($user) || DISABLE_USER_TAGS}
				<dd class="tags">
					{if $hiddenTagsCount > 0}<input type="checkbox" id="more-tags-trigger" autocomplete="off" />{/if}
					{foreach from=$tags item=tag key=i}
					<a href="/list/mod?tagids[]={$tag['tagId']}" class="tag{if $tag['votes'] < TAG_DOWNVOTED_THRESHOLD} downvoted hidden{elseif $i >= 8} hidden{/if}" style="background-color:{$tag['color']}" title="{$tag['text']}">{$tag['name']}</a>
					{/foreach}
				</dd>
				{else}
				<dd class="tags votable">
					{if $hiddenTagsCount > 0}<input type="checkbox" id="more-tags-trigger" autocomplete="off" />{/if}
					{foreach from=$tags item=tag key=i}
					<span class="tag{if $tag['votes'] < TAG_DOWNVOTED_THRESHOLD} downvoted hidden{elseif $i >= 8} hidden{/if}" style="background-color:{$tag['color']}" title="{$tag['text']}" data-tagid="{$tag['tagId']}" data-vote="{$tag['vote'] ?? 0}">
						<a href="/list/mod?tagids[]={$tag['tagId']}">{$tag['name']}</a><span class="add"></span><span class="rem"></span>
					</span>
					{/foreach}
					{if $hiddenTagsCount > 0}<label for="more-tags-trigger">{$hiddenTagsCount}</label>{/if}
					<a href="#" data-opens-dialog="add-tag-mdl" onclick="return false;">Add tags...</a>
				</dd>
				{/if}

				{if !empty($teamMembers)}
				<dt>Authors:</dt>
				<dd><a class="username" href="/show/user/{$asset['creatorHash']}">{$asset['creatorName']}</a>{foreach from=$teamMembers item=teamMember}, <a class="username" href="/show/user/{$teamMember['userHash']}">{$teamMember['name']}</a>{/foreach}</dd>
				{else}
				<dt>Author:</dt><dd><a class="username" href="/show/user/{$asset['creatorHash']}">{$asset['creatorName']}</a></dd>
				{/if}

				<dt>Side:</dt><dt>{ucfirst($asset['side'])}</dt>
				{if !empty($relations['required'])}
				<dt>Requires:</dt>
				<dd class="mod-relations">
					{foreach from=$relations['required'] item=rel key=i}{if $i > 0}, {/if}{if $rel['resolvedMod']}<a class="mod-link" href="{formatModPath($rel['resolvedMod'])}" title="{$rel['resolvedMod']['summary']}">{$rel['resolvedMod']['name']}{if $rel['minVersion']} &ge;{formatSemanticVersion($rel['minVersion'])}{/if}</a>{else}<span class="mod-link unresolved" title="Not hosted on this moddb">{$rel['targetIdentifier']}{if $rel['minVersion']} &ge;{formatSemanticVersion($rel['minVersion'])}{/if}</span>{/if}{/foreach}
				</dd>
				{/if}
				{if !empty($relations['optional'])}
				<dt>Recommended:</dt>
				<dd class="mod-relations">{include file="show-mod-relation-list" list=$relations['optional']}</dd>
				{/if}
				{if !empty($relations['tested_with'])}
				<dt>Verified compatible with:</dt>
				<dd class="mod-relations">{include file="show-mod-relation-list" list=$relations['tested_with']}</dd>
				{/if}
				{if !empty($relations['incompatible'])}
				<dt class="warn">Incompatible with:</dt>
				<dd class="mod-relations incompatible">{include file="show-mod-relation-list" list=$relations['incompatible']}</dd>
				{/if}
				<dt>Created:</dt><dt>{fancyDate($asset['created'])}</dt>
				<dt>Last modified:</dt><dt>{fancyDate($asset['lastReleased'])}</dt>
				<dt>Downloads:</dt><dt>{intval($asset['downloads'])}</dt>
				<dd class="full-width">
					<a href="{if !empty($user)}#follow{else}/login{/if}" class="interactbox {if $isFollowing}on{else}off{/if}">
						<span class="off"><i class="bx bx-star"></i>Follow</span>
						<span class="on"><i class="bx bxs-star"></i>Unfollow</span>
						<span class="count">{$asset["follows"]}</span>
					</a>
				</dd>
				<dd class="full-width">
					{if $recommendedReleaseStable}
						{if count($recommendedReleaseStable['compatibleGameVersions']) > 0}<strong>
							{formatRecommendationAdjustedHint('Recommended', $recommendationIsInfluencedBySearch, $highestTargetVersion)}
							download (for Vintage Story {formatGrammaticallyCorrectEnumeration($recommendedReleaseStable['compatibleGameVersionsFolded'])}):</strong><br>
						{else}<strong>Recommended download:</strong><br>
						{/if}

						<a class="button square ico-button mod-dl" href="{formatDownloadTrackingUrl($recommendedReleaseStable['file'])}">{htmlspecialchars($recommendedReleaseStable['file']['name'])}</a>
						{if !empty($recommendedReleaseStable['identifier']) && $shouldShowOneClickInstall}&nbsp;{include file="button-one-click-install" release=$recommendedReleaseStable}{/if}
						{if $recommendedReleaseUnstable}<br>{/if}
					{elseif $fallbackRelease}
						{if count($fallbackRelease['compatibleGameVersions']) > 0}<strong>
							{formatRecommendationAdjustedHint('Latest', $recommendationIsInfluencedBySearch, $highestTargetVersion)}
							release (for Vintage Story {formatVersionsAndWarning($fallbackRelease, $highestTargetVersion)}):</strong><br>
						{else}<strong>Latest release:</strong><br>
						{/if}

						<a class="button square ico-button mod-dl" href="{formatDownloadTrackingUrl($fallbackRelease['file'])}">{htmlspecialchars($fallbackRelease['file']['name'])}</a>
						{if !empty($fallbackRelease['identifier']) && $shouldShowOneClickInstall}&nbsp;{include file="button-one-click-install" release=$fallbackRelease}{/if}
						{if $recommendedReleaseUnstable}<br>{/if}
					{/if}
					{if $recommendedReleaseUnstable}
						{if count($recommendedReleaseUnstable['compatibleGameVersions']) > 0}<strong>For testers (for Vintage Story {formatVersionsAndWarning($recommendedReleaseUnstable, $highestTargetVersion)}):</strong><br>
						{else}<strong>For testers:</strong><br>
						{/if}

						<a class="button square ico-button mod-dl" href="{formatDownloadTrackingUrl($recommendedReleaseUnstable['file'])}">{htmlspecialchars($recommendedReleaseUnstable['file']['name'])}</a>
						{if !empty($recommendedReleaseUnstable['identifier']) && $shouldShowOneClickInstall}&nbsp;{include file="button-one-click-install" release=$recommendedReleaseUnstable}{/if}
					{/if}
				</dd>
			</dl>

			<div style="clear:both;"><br></div>
			{$assetraw['text']}
			<div style="clear:both;"></div>
		</div>

		<div class="tab-content files">
			<div style="float: right; margin-bottom: 1em;">
				{if isset($user) && canEditAsset($asset, $user)}
					<a class="button large shine strikethrough-when-banned strikethrough-when-readonly" href="/edit/release/?modid={$asset['modId']}">Add release</a>
				{/if}
			</div>

			<p style="clear: both"></p>
			<div style="overflow-x:auto;">
			<table class="stdtable release-table {$shouldListCompatibleGameVersion ? 'gv' : 'no-gv'} {$shouldShowOneClickInstall ? 'oc' : 'oc-oc'}">
				<thead>
					<tr>
						<th class="version">Mod Version</th>
						{if $shouldListCompatibleGameVersion}<th>Mod Identifier</th><th class="gameversion">For Game version</th>{/if}
						<th class="downloads">Downloads</th>
						<th class="releasedate">Released</th>
						<th class="changelog">Changelog</th>
						<th class="download">Download</th>
						{if $shouldShowOneClickInstall}<th><abbr title="Requires game version v1.18.0-rc.1 or later, currently not supported on MacOS.">1-click mod install*</abbr></th>{/if}
					</tr>
				</thead>
				<tbody>
				{if !empty($releases)}
					{foreach from=$releases item=release}
						<tr data-assetid="{$release['assetId']}" {$release['retractionReason'] ? 'class="retracted"' : ''}>
							<td>
								{if isset($user) && (!$release['retractionReason'] || canModerate(null, $user)) && canEditAsset($asset, $user)}
									<a style="display:block;" href="/edit/release?assetid={$release['assetId']}">{formatSemanticVersion($release['version'])}</a>
								{else}{formatSemanticVersion($release['version'])}{/if}
							</td>
							{if $shouldListCompatibleGameVersion}<td>
								{$release['identifier']}
							</td>
							<td>
								<div class="tags">
								{foreach from=$release['compatibleGameVersionsFolded'] item=versionStr}
									{if contains($versionStr, ' - ')}<span class="tag">{$versionStr}</span>
									{else}<a href="/list/mod?gv[]={$versionStr}" class="tag" rel="tag">{$versionStr}</a>{/if}
								{/foreach}
								</div>
							</td>{/if}
							<td>{if !empty($release['file'])}{intval($release['file']['downloads'])}{/if}</td>
							<td>{fancyDate($release['created'])}</td>
							<td>{if $release['text'] || $release['retractionReason']}<label for="cl-trigger-{$release['assetId']}" class="button square cl-trigger">Show</label>{else}Empty{/if}</td>
							{if !$release['retractionReason']}
								<td>{if !empty($release['file'])}<a class="button square ico-button mod-dl" href="{formatDownloadTrackingUrl($release['file'])}">{htmlspecialchars($release['file']['name'])}</a>{/if}</td>
							{if $shouldShowOneClickInstall}<td>{if !empty($release['identifier'])}{include file="button-one-click-install"}{/if}</td>{/if}
							{else}
								<td {if $shouldShowOneClickInstall} colspan="2"{/if}>Release Retracted</td>
							{/if}
						</tr>
						{if $release['text'] || $release['retractionReason']}
						<tr><td class="collapsable cl-changelog" colspan="{$changelogColspan}">
							<input type="checkbox" id="cl-trigger-{$release['assetId']}" autocomplete="off">
							<div><div><div class="release-changelog">{if $release['retractionReason']}<div><h4>Retraction Reason:</h4>{$release['retractionReason']}</div><h4>Changelog:</h4>{/if}{$release['text'] ?? ''}</div></div></div>
						</td></tr>
						{/if}
					{/foreach}
				{else}
					<tr>
						<td colspan="6"><i>No releases found</i></td>
					</tr>
				{/if}
				</tbody>
			</table>
			</div>

			<script nonce="{$cspNonce}" type="text/javascript">
			{
				const table = document.getElementsByClassName('release-table')[0];
				table.addEventListener('change', e => {
					const t = e.target;
					table.querySelector(`label[for="${t.id}"]`).textContent = t.checked ? 'Hide' : 'Show';
				})
			}
			</script>

			<div style="clear:both;"></div>
		</div>

		<div class="tab-content graph dep-graph-tab">
			<div class="dep-graph-toolbar">
				<div class="legend">
					<span class="required">required</span>
					<span class="optional">optional</span>
					<span class="incompatible">incompatible</span>
					<span class="tested_with">tested with</span>
				</div>
				<div style="flex:1"></div>
				<button type="button" id="dep-graph-fit" title="Fit graph in view">Fit</button>
				<button type="button" id="dep-graph-png" title="Download a PNG of the current view">Export PNG</button>
			</div>
			<div id="dep-graph-canvas" data-modid="{$asset['modId']}" data-csp-nonce="{$cspNonce}">
				<div class="dep-graph-loading">Loading dependency graph...</div>
			</div>
		</div>
	</div>

	<div style="clear:both;"></div>

	{if !empty($user) && !DISABLE_USER_TAGS}
	<dialog id="add-tag-mdl">
		<form class="with-buttons-bottom" method="dialog" data-method="post" autocomplete="off" action="/api/v2/mods/{$asset['modId']}/tags">
			<h1>Add Tags</h1>
			<p>While anyone can add tags to mods, everyone is also allowed to vote whether or not the tag makes sense.</p>
			<p>Tags that get downvoted will eventually be hidden, not show up in searches and get removed.</p>
			<p>The tags you want to add, separated by comma (you can add arbitrary new tags):</p>
			<div id="tag-input-wrap">
				<input type="text" name="newTags" maxlength="255" value="" autofocus>
				<div></div>
			</div>
			<input type="hidden" name="at" value="{$user['actionToken']}">
			<div class="buttons">
				<button class="button large submit shine" id="tag-subm" onclick="return false;">Add</button>
				<button class="button large shine" style="margin-left:auto;" formmethod="dialog">Cancel</button>
			</div>
		</form>
	</dialog>
	{/if}


{include file="comments"}

{capture name="footerjs"}
	<script nonce="{$cspNonce}" type="text/javascript">
		modId = {$asset['modId']};

		{if !empty($user) && !DISABLE_USER_TAGS}attachTagVoteButtons(document.getElementsByClassName('tags votable')[0], R.get('add-tag-mdl'));{/if}

		$(function() {
			attachCommentHandlers();

			$("a[href='#follow']").click(function() {
				const oldCount = parseInt($(".count", $(this)).text());

				let promise;
				if ($(this).hasClass("on")) {
					$(this).toggleClass("on off");
					$(".count", $(this)).text("" + (oldCount - 1));

					promise = $.post(`/api/v2/notifications/settings/followed-mods/${modId}/unfollow`);
				} else {
					$(this).toggleClass("on off");
					$(".count", $(this)).text("" + (oldCount + 1));

					promise = $.post(`/api/v2/notifications/settings/followed-mods/${modId}`, { 'new': 1 /* @hardcoded */ });
				}

				promise.fail(jqXHR => {
					$(this).toggleClass("on off");
					$(".count", $(this)).text("" + oldCount);

					const d = JSON.parse(jqXHR.responseText);
					R.addMessage(MSG_CLASS_ERROR, 'Failed to (un-)follow mod' + (d.reason ? (': '+d.reason) : '.'), true)
				});
			});
		});

		// Dependency graph: lazy-init when the Graph tab is first activated.
		(function() {
			var graphTrigger = document.getElementById('tab-graph');
			var canvas = document.getElementById('dep-graph-canvas');
			if (!graphTrigger || !canvas) return;

			var inited = false;
			var cy = null;

			function setStatus(klass, text) {
				while (canvas.firstChild) canvas.removeChild(canvas.firstChild);
				var div = document.createElement('div');
				div.className = klass;
				div.textContent = text;
				canvas.appendChild(div);
			}

			function ensureLoaded(cb) {
				if (typeof cytoscape !== 'undefined') return cb();
				var s = document.createElement('script');
				s.src = '/web/js/cytoscape.min.js';
				s.nonce = canvas.dataset.cspNonce;
				s.onload = cb;
				s.onerror = function() { setStatus('dep-graph-error', 'Failed to load Cytoscape library.'); };
				document.head.appendChild(s);
			}

			function render() {
				var modId = canvas.dataset.modid;
				$.get('/api/v2/mods/dependency-graph?modid=' + encodeURIComponent(modId))
					.done(function(data) {
						if (!data.nodes || !data.nodes.length) {
							setStatus('dep-graph-empty', 'No relations declared yet for this mod.');
							return;
						}
						while (canvas.firstChild) canvas.removeChild(canvas.firstChild);
						var elements = [];
						data.nodes.forEach(function(n) {
							elements.push({ data: {
								id: n.id, label: n.label, isLocal: !!n.isLocal,
								modId: n.modId || 0, urlAlias: n.urlAlias || '',
								version: n.latestVersion || '', focus: (n.modId == modId)
							}});
						});
						data.edges.forEach(function(e, i) {
							elements.push({ data: { id: 'e'+i, source: e.from, target: e.to, type: e.type } });
						});

						cy = cytoscape({
							container: canvas,
							elements: elements,
							style: [
								{ selector: 'node', style: {
									'background-color': '#aaa', 'label': 'data(label)',
									'color': '#333', 'font-size': '11px', 'text-valign': 'bottom',
									'text-margin-y': 4, 'width': 24, 'height': 24,
									'border-width': 1, 'border-color': '#666'
								}},
								{ selector: 'node[?isLocal]', style: { 'background-color': '#3d6594', 'border-color': '#234166' }},
								{ selector: 'node[?focus]', style: { 'background-color': '#c4925e', 'border-color': '#8a5e2e', 'border-width': 2, 'width': 32, 'height': 32 }},
								{ selector: 'node[!isLocal]', style: { 'font-style': 'italic', 'background-color': '#ddd', 'border-color': '#aaa' }},
								{ selector: 'edge', style: {
									'width': 1.5, 'curve-style': 'bezier',
									'target-arrow-shape': 'triangle',
									'line-color': '#888', 'target-arrow-color': '#888'
								}},
								{ selector: 'edge[type = "required"]',     style: { 'line-color': '#3d6594', 'target-arrow-color': '#3d6594' }},
								{ selector: 'edge[type = "optional"]',     style: { 'line-color': '#4a7a3e', 'target-arrow-color': '#4a7a3e', 'line-style': 'dashed' }},
								{ selector: 'edge[type = "incompatible"]', style: { 'line-color': '#c45e5e', 'target-arrow-color': '#c45e5e', 'width': 2 }},
								{ selector: 'edge[type = "tested_with"]',  style: { 'line-color': '#999',    'target-arrow-color': '#999',    'line-style': 'dotted' }},
								{ selector: 'edge[?inCycle]',              style: { 'line-color': '#c45e5e', 'target-arrow-color': '#c45e5e', 'width': 3, 'line-style': 'solid' }},
							],
							layout: { name: 'breadthfirst', directed: true, padding: 20, spacingFactor: 1.4, roots: '[?focus]' },
							wheelSensitivity: 0.2
						});

						cy.on('tap', 'node', function(evt) {
							var n = evt.target.data();
							if (n.isLocal && n.urlAlias) {
								window.location.href = '/show/mod/' + n.modId;
							}
						});
					})
					.fail(function() { setStatus('dep-graph-error', 'Failed to load dependency graph.'); });
			}

			function initIfNeeded() {
				if (inited || !graphTrigger.checked) return;
				inited = true;
				ensureLoaded(render);
			}

			graphTrigger.addEventListener('change', initIfNeeded);
			if (graphTrigger.checked) initIfNeeded();

			document.getElementById('dep-graph-fit').addEventListener('click', function() { if (cy) cy.fit(); });
			document.getElementById('dep-graph-png').addEventListener('click', function() {
				if (!cy) return;
				var png = cy.png({ scale: 2, bg: '#fff8e8' });
				var a = document.createElement('a');
				a.href = png;
				a.download = 'dependency-graph-' + canvas.dataset.modid + '.png';
				a.click();
			});
		})();
	</script>
	<script nonce="{$cspNonce}" type="text/javascript" src="/web/js/jquery.fancybox.min.js" async></script>
	<link nonce="{$cspNonce}" href="https://cdnjs.cloudflare.com/ajax/libs/fotorama/4.6.4/fotorama.css" rel="stylesheet">
	<script nonce="{$cspNonce}" type="text/javascript" src="/web/js/fotorama.js?v=2"></script>
{/capture}

{include file="footer"}