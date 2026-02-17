function attachUserSearchHandler(scopeEl : HTMLElement) : void
{
	let waitTimeout : number|null = null, lastWaitTimeout : number|null = null;

	const input = scopeEl.getElementsByClassName('chosen-search-input')[0] as HTMLInputElement;
	const select = scopeEl.getElementsByTagName('select')[0];

	const urlTemplate = select.dataset.url;
	if(!urlTemplate) {
		console.warn("attachUserSearchHandler called on an element who's select does not have a url in its dataset.");
		return
	}

	input.addEventListener('keydown', e => {
		if(waitTimeout !== null)  clearTimeout(waitTimeout);

		lastWaitTimeout = waitTimeout;
		waitTimeout = setTimeout(() => {
			const search = input.value;
			if(!search) {
				waitTimeout = null;
				return;
			}

			const timeoutRef = lastWaitTimeout;
			const url = urlTemplate.replace('{name}', search);
			$.get(url, (authors : Object) => {
				if(lastWaitTimeout !== timeoutRef)  return;

				if(!authors) {
					waitTimeout = null;
					return;
				}

				const currentUserIds = $(select).val();
				select.replaceChildren(...Array.from(select.querySelectorAll('option:checked')));

				for(const [id, name] of Object.entries(authors as Object)) {
					if(currentUserIds != null && currentUserIds.includes(id))  continue;

					const opt = document.createElement('option');
					opt.value = id; opt.textContent = name;
					select.append(opt);
				}

				const oldWidth = getComputedStyle(input).width;
				$(select).trigger('chosen:updated');
				input.value = search;
				// Choses resets this values in the update call. We manually modify the search, so we need to set the width as well.
				input.style.width = oldWidth;
				waitTimeout = null;
			});

		}, 500);
	})
}

function attachVersionSelectorHandlers(versionSelectorEl : HTMLDetailsElement) : void
{
	const countLabelEl = versionSelectorEl.getElementsByClassName('count-label')[0];
	const updateSelectedCounter = () => {
		const count = versionSelectorEl.querySelectorAll('input:checked').length;
		countLabelEl.textContent = `${count} Version${count !== 1 ? 's' : ''} Selected`;
	}
	versionSelectorEl.addEventListener('click', e => {
		let t = e.target as Element | null
		if(!t || !t.nodeName) return;

		if(t.nodeName === 'INPUT') {
			updateSelectedCounter();
			return;
		}

		// <div><span>subversion</></>
		// <div>container for all the inputs of that subversion</>
		if(t.nodeName !== 'DIV' || t.firstChild?.nodeName !== 'SPAN') {
			if(t.nodeName !== 'SPAN' || t.parentElement?.nodeName !== 'DIV') return;

			t = t.parentElement;
		}

		e.stopPropagation()

		const ns = t.nextElementSibling!;
		const inputs = ns.nodeName === 'INPUT' ? [ns as HTMLInputElement] : ns.getElementsByTagName('input');

		let toggleOn = false;
		for(const el of inputs) {
			if(!el.checked) {
				// As long as there is one unchecked input in the subset check them all first.
				toggleOn = true;
				break;
			}
		}
		for(const el of inputs) {
			el.checked = toggleOn;
		}
		
		updateSelectedCounter();
	})
}

function attachTagVoteButtons(tagsContainerEl : HTMLElement, addTagModalEl : HTMLDialogElement) : void
{
	tagsContainerEl.addEventListener('click', e => {
		const buttonEl = e.target as Element;
		if(!buttonEl || !buttonEl.classList) return;

		const tagEl = buttonEl.parentElement!;
		const tagId = tagEl.dataset.tagid;
		if(!tagId) return;

		const oldValue = tagEl.dataset.vote;
		let newValue : number;
		if(buttonEl.classList.contains('add')) {
			newValue = tagEl.dataset.vote === '1' ? 0 : 1;
		}
		else if(buttonEl.classList.contains('rem')) {
			newValue = tagEl.dataset.vote === '-1' ? 0 : -1;
		}
		else {
			return;
		}

		tagEl.dataset.vote = String(newValue);
		const xhr = $.ajax(`/api/v2/mods/${modId}/tags/${tagId}/vote`, { method: 'PUT', data: { at: actiontoken, vote: newValue } }) as jqXHR;
		R.attachDefaultFailHandler(xhr, "Failed to vote")
			.fail(() => tagEl.dataset.vote = oldValue); // Reset value in case of error.
	})

	attachDialogSendHandler(addTagModalEl, (form, data) => {
		if(!data.get('newTags')) {
			R.markAsErrorElement(form.querySelector('[name="newTags"]')!);
			return false;
		}
		return true;
	}, (jqXHR) => {
		R.attachDefaultFailHandler(jqXHR, "Failed to add tag")
			.done(() => {
				addTagModalEl.close();
				
			});
	});
}
