			<div style="clear:both;"><br></div>
			<h3><a name="comments"></a>{count($comments)} Comment{count($comments) !== 1 ? 's' : ''} <span style="font-size:70%">(<a href="#orderoldestfirst" onclick="return false;">oldest first</a> | <a href="#ordernewestfirst" onclick="return false;">newest first</a>)</span></h3>
			<div class="comments">
				{if !empty($user)}
				<div class="comment comment-editor editbox overlay-when-banned overlay-when-readonly" style="display:none;">
					<div class="title">Add new comment:</div>
					<div class="body">
						
						<form name="commentformtemplate" autocomplete="off">
							<textarea name="commenttext" class="whitetext editor" data-editorname="comment" style="width: 100%; height: 50px;"></textarea>
						</form>
					</div>
					<p style="margin:4px; margin-top:5px;"><button class="button shine" type="submit" name="save">Add Comment</button>
				</div>
				{/if}
			
				{foreach from=$comments item=comment key=i}
					<div id="cmt-{$comment['commentId']}" class="editbox comment{if $comment['deleted']} deleted{/if}{if $comment['responseTo']} rsp-{$comment['responseDepth']}{/if}" data-order="-{$i}">
						<div class="title">
							<span><a style="text-decoration:none;" href="#cmt-{$comment['commentId']}"><i class="bx bx-link-alt"></i></a>
							<a href="/show/user/{$comment['userHash']}">{$comment['username']}</a>{if !empty($comment["flairCode"])} <small class="flair flair-{$comment['flairCode']}"></small>{/if}{if $comment['isBanned']}&nbsp;<span style="color:red;">[currently restricted]</span>{/if}, {fancyDate($comment['created'])} {if $comment['contentLastModified']}(modified {fancyDate($comment['contentLastModified'])}{if $comment['lastModaction'] == MODACTION_KIND_EDIT} by a moderator{/if}){/if}{if $comment['lastModaction'] == MODACTION_KIND_DELETE} (deleted by moderator){/if}</span>
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
						<div class="body">{postprocessCommentHtml($comment['text'])}</div>
						{if $comment['deleted']}<span class="ribbon-tr">Deleted</span>{/if}
					</div>
				{/foreach}
			</div>
