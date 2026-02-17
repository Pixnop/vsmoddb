<?php

if(empty($urlparts)) {
	fail(404);
}

switch($urlparts[0]) {
	case 'by-name':
		if(count($urlparts) !== 2)  fail(HTTP_NOT_FOUND);
		validateMethod('GET');

		$limit = filter_input(INPUT_GET, 'limit', FILTER_VALIDATE_INT);
		if($limit === null) $limit = 10;
		else if(!$limit || $limit > 200)  fail(HTTP_BAD_REQUEST, ['reason' => 'Invalid limit provided.']);

		$search = urldecode($urlparts[1]);
		if(strlen($search) === 0)  fail(HTTP_BAD_REQUEST, ['reason' => 'Empty search phrase provided.']);

		//TODO(Rennorb) @correctness: This at least selects perfect matches, but something like order by levenshtein distance would be better.
		// Issue here is just performance, this needs a bit more thinking.
		$map = $con->getAssoc(<<<SQL
			SELECT tagId, name
				FROM tags
				WHERE name = ?
			UNION
				SELECT tagId, name
				FROM tags
				WHERE name LIKE ?
			LIMIT ?
		SQL, [$search, '%'.escapeStringForLikeQuery($search).'%', $limit]);

		good($map, JSON_FORCE_OBJECT);
}