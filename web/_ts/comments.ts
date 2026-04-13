
function attachCommentHandlers() {
	const container = document.getElementsByClassName('comments')[0];

	function updateCommentOrder()
	{
		const comments = Array.from(container.children as HTMLCollectionOf<HTMLElement>);
		const sortByDate = $.cookie('commentstructure') === 'flat';

		let sorted : HTMLElement[];
		if($.cookie("commentsort") !== 'oldestfirst') {
			sorted = sortByDate
				? comments.sort(function (a, b) {
						var dt = parseInt(b.dataset.stamp!) - parseInt(a.dataset.stamp!);
						return dt < 0 ? -1 : dt > 0 ? 1 : 0;
					})
				: comments.sort(function (a, b) {
						var dt = parseFloat(b.dataset.order!) - parseFloat(a.dataset.order!);
						return dt < 0 ? -1 : dt > 0 ? 1 : 0;
					})
		}
		else {
			sorted = sortByDate
				? comments.sort(function (a, b) {
						var dt = parseInt(a.dataset.stamp!) - parseInt(b.dataset.stamp!);
						return dt < 0 ? -1 : dt > 0 ? 1 : 0;
					})
				: comments.sort(function (a, b) {
						var dt = parseFloat(a.dataset.order!) - parseFloat(b.dataset.order!);
						return dt < 0 ? -1 : dt > 0 ? 1 : 0;
					})
		}

		container.replaceChildren(...sorted);
	}

	R.get('cmt-ord-desc')!.addEventListener('click', e => {
		e.preventDefault();
		$.cookie("commentsort", "newestfirst", { expires: 365, path: '/' });
		updateCommentOrder();
	});
	R.get('cmt-ord-asc')!.addEventListener('click', e => {
		e.preventDefault();
		$.cookie("commentsort", "oldestfirst", { expires: 365, path: '/' });
		updateCommentOrder();
	});

	R.get('cmt-threaded')!.addEventListener('click', e => {
		e.preventDefault();
		container.classList.add('threaded');
		$.cookie("commentstructure", "threaded", { expires: 365, path: '/' });
		updateCommentOrder();
	});
	R.get('cmt-flat')!.addEventListener('click', e => {
		e.preventDefault();
		container.classList.remove('threaded');
		$.cookie("commentstructure", "flat", { expires: 365, path: '/' });
		updateCommentOrder();
	});

	// @hack: This will cause a resort after the page finishes loading if the user selected flat view.
	// I to avoid that we need to store the threaded order on the objects, and do a bunch of time parsing.
	// TODO(Rennorb) @cleanup: Should probably just clean up the time formatting so this isn't such a penalty.
	if($.cookie("commentstructure") === "flat") updateCommentOrder();

	const newCommentWrapperEl = container.getElementsByClassName("comment-editor")[0];
	let cEditorInitialized = false;
	$("textarea", newCommentWrapperEl).focus(function (e : FocusEvent) {
		if (cEditorInitialized) return;
		cEditorInitialized = true;

		$(this).removeClass("whitetext");

		$('form[name=commentformtemplate]').trigger('reinitialize.areYouSure');
		
		const ta = e.currentTarget as HTMLTextAreaElement
		createEditor(ta, tinymceSettingsCmt);
		setTimeout(() => tinyMCE.get(ta.id).focus(), 100);
	});

	$("button[name='save']", newCommentWrapperEl).click(function (e : MouseEvent) {
		const editorWrapper = $(this).parents(".comment.comment-editor")[0] as HTMLElement;
		
		const editorTAEl = editorWrapper.getElementsByTagName("textarea")[0];
		const content = getEditorContents($(editorTAEl));
		if(!content) return;

		const button = e.target as HTMLButtonElement;
		button.disabled = true; // prevent double submission by impatient user
		const prevButtonText = button.textContent;

		const spinnerInterval = startSubmissionSpinner(button);

		const xhr = $.ajax({ url: `/api/v2/mods/${modId}/comments?at=`+actiontoken, method: 'PUT', data: content, contentType: 'text/html', dataType: 'text' })
			.done(function (response : string, _, jqXHR : jqXHR) {
				const cmtFrag = jqXHR.getResponseHeader('Location')!;  // the response contains the newly generated comment id in the location header as a fragment link (e.g. `#cmt-213`)
				const commentId = cmtFrag.slice(5) // slice off the #cmt- from the link

				const cmt = createComment(commentId, 0, response, 0);
				editorWrapper.after(cmt)

				tinyMCE.get(editorTAEl.id).setContent(''); // Clear the editor

				temporaryHighlight(cmt);

				clearInterval(spinnerInterval);
				button.textContent = prevButtonText;
				button.disabled = false;
			})
			.fail(function() {
				clearInterval(spinnerInterval);
				button.textContent = prevButtonText;
				button.disabled = false;
			});
		R.attachDefaultFailHandler(xhr, 'Failed to submit comment');
	})

	$(".comment.comment-editor", container).show(); // Hidden initially until we are fully loaded. TODO @cleanup: dot cause reflow, just show a loading spinner.

	//
	// Set up comment head functions (edit, delete, moderate)
	//

	function clickRespond(e : MouseEvent)
	{
		e.preventDefault();
		const targetCommentEl = $(this).parents(".comment")[0] as HTMLElement;

		const targetCommentId = targetCommentEl.id.split('-')[1];
		const wrapperId = 'repl-'+targetCommentId;

		const prevWrapper = document.getElementById(wrapperId);
		if(prevWrapper) {
			const prevForm = prevWrapper.getElementsByTagName("form")[0];
			if (prevForm.classList.contains("dirty")) {
				var ok = confirm("Discard changed comment data?");
				if (!ok) return false;
			}

			destroyEditor($("textarea", prevForm));
			prevWrapper.remove();
			return false;
		}
		

		let responseDepth = 1;
		// If we respond to a already responded to comment we need to go deeper:
		for(const clazz of targetCommentEl.classList) {
			if(clazz.startsWith('rsp-')) responseDepth = parseInt(clazz.substring(4)) + 1;
		}
		responseDepth = Math.min(responseDepth, 10); // :MaxResponseDepth

		const editorWrapperEl = $(`
<div id="${wrapperId}" class="comment comment-editor editbox rsp-${responseDepth}">
	<div class="title">Response to comment:</div>
	<a class="reference" href="#${targetCommentEl.id}"><span></span></a>
	<div class="body"></div>
</div>
`)[0] as HTMLElement;
		const shortResponseText = targetCommentEl.getElementsByClassName('body')[0].textContent!.substring(0, 255);
		editorWrapperEl.getElementsByTagName('span')[0].textContent = shortResponseText;

		for(const anchor of targetCommentEl.getElementsByClassName('title')[0].getElementsByTagName('a')) {
			if(anchor.href.includes('user')) {
				editorWrapperEl.getElementsByClassName('title')[0].textContent = `Respond to ${anchor.textContent}'s comment:`;
				break;
			}
		}

		let targetOrder = 0;

		if($.cookie("commentsort") === 'oldestfirst') {
			let insertAfterEl = targetCommentEl;
			for(; insertAfterEl.nextElementSibling; insertAfterEl = insertAfterEl.nextElementSibling! as HTMLElement) {
				let foundEqualOrHigherResponseLevel = false;
				for(const clazz of insertAfterEl.nextElementSibling.classList) {
					if(clazz.startsWith('rsp') && parseInt(clazz.substring(4)) >= responseDepth) {
						foundEqualOrHigherResponseLevel = true;
					}
				}
				if(!foundEqualOrHigherResponseLevel) break;
			}
			targetOrder = parseFloat(insertAfterEl.dataset.order!);
			insertAfterEl.after(editorWrapperEl);
		}
		else {
			let insertBeforeEl = targetCommentEl;
			for(; insertBeforeEl.previousElementSibling; insertBeforeEl = insertBeforeEl.previousElementSibling! as HTMLElement) {
				let foundEqualOrHigherResponseLevel = false;
				for(const clazz of insertBeforeEl.previousElementSibling.classList) {
					if(clazz.startsWith('rsp') && parseInt(clazz.substring(4)) >= responseDepth) {
						foundEqualOrHigherResponseLevel = true;
					}
				}
				if(!foundEqualOrHigherResponseLevel) break;
			}
			targetOrder = parseFloat(insertBeforeEl.dataset.order!);
			insertBeforeEl.before(editorWrapperEl);
		}

		editorWrapperEl.scrollIntoView({ behavior: "smooth", block: "nearest" })

		createInlineEditor(editorWrapperEl.getElementsByClassName('body')[0], 'Add Response', '', (button, content, form, editor) => {
			button.disabled = true; // prevent impatience
			const prevButtonText = button.textContent;
			const spinnerInterval = startSubmissionSpinner(button);

			const xhr = $.ajax({ url: `/api/v2/mods/${modId}/comments?response-to=${targetCommentId}&at=`+actiontoken, method: 'PUT', data: content, contentType: 'text/html', dataType: 'text' })
				.done(function(response, _, jqXHR : jqXHR) {
					clearInterval(spinnerInterval);

					const cmtFrag = jqXHR.getResponseHeader('Location')!;  // the response contains the newly generated comment id in the location header as a fragment link (e.g. `#cmt-213`)
					const commentId = cmtFrag.slice(5) // slice off the #cmt- from the link
					
					// @hack: Adding .01 will fail after adding 100 messages without reloading the page, meaning sorting will be wired until a reload. Literally irrelevant.
					const cmt = createComment(commentId, responseDepth, response, targetOrder + .01);

					const usernameRef = targetCommentEl.getElementsByTagName('a')[1].textContent; //TODO(Rennorb) @hardcoded
					const ref = R.make<HTMLAnchorElement>('a.reference', '@'+usernameRef+": ", R.make('span', shortResponseText))
					ref.href = '#'+targetCommentEl.id;
					cmt.getElementsByClassName('title')[0].after(ref);

					tinyMCE.remove("#" + editor.id);
					editorWrapperEl.replaceWith(cmt);

					temporaryHighlight(cmt);
				})
				.fail(function() {
					clearInterval(spinnerInterval);
					button.textContent = prevButtonText;
					button.disabled = false;
				});
			R.attachDefaultFailHandler(xhr, 'Failed to submit comment');
		});

		return false;
	}

	function clickEdit(e : MouseEvent)
	{
		e.preventDefault();
		const $comment = $(this).parents(".comment");
		const $body = $('.body', $comment);

		if ($comment.data("editing") == 1) {
			const $form = $comment.find("form");
			if ($form.hasClass("dirty")) {
				var ok = confirm("Discard changed comment data?");
				if (!ok) return false;
			}

			destroyEditor($("textarea", $comment));
			$form.remove();
			$body.show();

			$comment.data("editing", 0);
			$('form[name=commentformedit]').trigger('reinitialize.areYouSure');
			return false;
		}

		$body.hide();
		$comment.data("editing", 1);

		const commentId = $comment[0].id.split('-')[1];
		createInlineEditor($comment[0], 'Update Comment', $body.html(), (button, content, form, editor) => {
			//TODO(Rennorb): optimistic update

			const xhr = $.ajax({ url: `/api/v2/comments/${commentId}?at=`+actiontoken, method: 'POST', data: content, contentType: 'text/html', dataType: 'json' })
				.done(function(response) {
					tinyMCE.remove("#" + editor.id);
					form.remove();

					$body.html(response.html);
					attachSpoilerToggle($('.spoiler-toggle', $body));
					$comment.data("editing", 0);
					$body.show();
				});
			R.attachDefaultFailHandler(xhr, 'Failed to edit comment');
		});

		return false;
	}

	function clickDelete(e : MouseEvent)
	{
		e.preventDefault();
		if (confirm("Are you sure you want to delete this comment?")) {
			const $comment = $(this).parents(".comment");
			$comment.hide();

			const commentId = $comment[0].id.split('-')[1];
			const xhr = $.ajax({ url: `/api/v2/comments/${commentId}?at=`+actiontoken, method: 'DELETE'})
			R.attachDefaultFailHandler(xhr, 'Failed to delete comment')
				.fail(() => $comment.show()); // Make it visible again if we failed to delete it, so the user may retry.
		}
	}

	$(container).on("click", 'a[href="#r"]', clickRespond);
	$(container).on("click", 'a[href="#e"]', clickEdit);
	$(container).on("click", 'a[href="#d"]', clickDelete);
	$(container).on("click", 'a[href^="#cmt-"]', highlightClickedEl);

	//
	// Highlight for direct comment links
	//

	if(document.location.hash.split('-')[0] === '#cmt') {
		const el = document.getElementById(document.location.hash.substring(1));
		if(el) temporaryHighlight(el);
	}

	function highlightClickedEl(_ : MouseEvent)
	{
		const href = (this as HTMLAnchorElement).getAttribute('href');
		if(!href) return;

		const id = href.slice(1)
		var target = document.getElementById(id)!;
		setTimeout(() => temporaryHighlight(target), 100); // wait until scrolled into view
	}

	function temporaryHighlight(el : HTMLElement)
	{
		el.classList.add('highlight');
		setTimeout(() => el.classList.remove('highlight'), 2000); // remove so sorting doesn't re-trigger the highlight.
	}

	//
	// Util stuff
	//

	function createInlineEditor(wrapperEl : Element, buttonText : string, contents : string, saveCallback : (button : HTMLButtonElement, editorContents : string, form : HTMLFormElement, editor : HTMLTextAreaElement) => void) : void
	{
		const formEl = $(`
			<form name="commentformedit" onsubmit="return false;">
				<textarea name="commenttext" class="editor editcommenteditor" data-editorname="editcomment" style="width: 100%; height: 135px;"></textarea>
				<p style="margin:4px; margin-top:5px;"><button class="shine" type="submit" name="save">${buttonText}</button></p>
			</form>
		`)[0] as HTMLFormElement;

		formEl.getElementsByTagName('textarea')[0].textContent = contents;

		wrapperEl.append(formEl);
		$(formEl).areYouSure();

		const editorTAEl = formEl.getElementsByTagName("textarea")[0];
		createEditor(editorTAEl, tinymceSettingsCmt);

		setTimeout(() => tinyMCE.get(editorTAEl.id).focus(), 100);

		const button = formEl.querySelector("button[name='save']")! as HTMLButtonElement;
		button.addEventListener('click', (e) => {
			e.preventDefault();

			var content = getEditorContents($(editorTAEl));
			saveCallback(button, content, formEl, editorTAEl);
		});
	}

	function createComment(commentId : number|string, responseDepth : number, safeBody : string, responseTargetOrder : number) : HTMLElement
	{
		// We don't have direct information about the current user in js land, so we extract it form the menu:
		const accMenu = R.get('account-menu');
		const userName = accMenu!.firstElementChild!.textContent;
		const userUrl = (accMenu!.lastElementChild!.firstElementChild as HTMLAnchorElement).getAttribute('href');

		const cmt = $(`
<div id="cmt-${commentId}" class="editbox comment${responseDepth ? ' rsp-'+responseDepth : ''}" data-order="${responseTargetOrder}" data-stamp="${Date.now()}">
	<div class="title">
		<span><a style="text-decoration:none;" class="cmt-pinner" href="#cmt-${commentId}"><i class="bx bx-link-alt"></i></a> <a href="${userUrl}">${userName}</a>, just now</span>
		<span class="buttons">(<a href="#r" onclick="return false;">respond</a>&nbsp;<a href="#e" onclick="return false;">edit</a>&nbsp;<a href="#d" onclick="return false;">delete</a>)</span>
	</div>
	<div class="body">${safeBody}</div>
</div>
`)[0] as HTMLElement;

		attachSpoilerToggle($('.spoiler-toggle', $(cmt)));

		return cmt;
	}

	function startSubmissionSpinner(button : HTMLButtonElement) : number
	{
		button.textContent = 'Submitting..';
		let dots = 0;
		const buttonInterval = setInterval(() => {
			button.textContent = 'Submitting....'.slice(0, 12 + dots);
			dots = (dots + 1) % 3;
		}, 300);
		return buttonInterval;
	}


}
