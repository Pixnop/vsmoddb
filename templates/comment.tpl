<div id="cmt-{$comment['commentId']}" class="editbox comment{if $comment['deleted']} deleted{/if}{if $comment['responseTo'] !== $comment['commentId']} rsp{/if}" data-order="{$i}" data-stamp="{strtotime($comment['created'])}" data-cldn="{$comment['children']}" data-d="{$comment['responseDepth']}">
	<div class="title">
		<span><a style="text-decoration:none;" href="#cmt-{$comment['commentId']}"><i class="bx bx-link-alt"></i></a>
		<a href="/show/user/{$comment['userHash']}">{htmlspecialchars($comment['username'])}</a>{if !empty($comment["flairCode"])} <small class="flair flair-{$comment['flairCode']}"></small>{/if}{if $comment['isBanned']}&nbsp;<span style="color:red;">[currently restricted]</span>{/if}, {fancyDate($comment['created'])} {if $comment['contentLastModified']}(modified {fancyDate($comment['contentLastModified'])}{if $comment['lastModaction'] == MODACTION_KIND_EDIT} by a moderator{/if}){/if}{if $comment['lastModaction'] == MODACTION_KIND_DELETE} (deleted by moderator){/if}</span>
			{if !empty($user)}
					{if $comment["userId"] == $user["userId"]}
						{if !$comment['deleted']}
							<span class="buttons strikethrough-when-banned strikethrough-when-readonly">(<a href="#r" onclick="return false;">respond</a>&nbsp;<a href="#e" onclick="return false;">edit</a>&nbsp;<a href="#d" onclick="return false;">delete</a>)</span>
						{/if}
					{elseif canModerate($comment['userId'], $user) && !($comment["userId"] == $user["userId"])}
							<span class="buttons strikethrough-when-banned strikethrough-when-readonly">(<a href="#r" onclick="return false;">respond</a>&nbsp;{if !$comment['deleted']}<a href="#e" onclick="return false;">edit</a>&nbsp;<a href="#d" onclick="return false;">delete</a>&nbsp;{/if}<a href="/moderate/user/{$comment['userHash']}?source-comment={$comment['commentId']}">moderate user</a>)</span>
					{elseif $asset['createdByUserId'] == $user['userId'] && !$comment['deleted']}
							<span class="buttons strikethrough-when-banned strikethrough-when-readonly">(<a href="#r" onclick="return false;">respond</a>&nbsp;<a href="#d" onclick="return false;">delete</a>)</span>
					{/if}
			{/if}
	</div>
	{if $comment['responseTo'] !== $comment['commentId']}<a class="reference" href="#cmt-{$comment['responseTo']}">@{htmlspecialchars($comment['parentUserName'])}: <span>{htmlspecialchars($comment['parentText'])}</span></a>{/if}
	<div class="body">{postprocessCommentHtml($comment['text'])}</div>
	{if $comment['deleted']}<span class="ribbon-tr">Deleted</span>{/if}
</div>