static func close_bbcode(text: String) -> String:
	const SELF_CLOSING := ["img", "lb", "rb", "lbracket", "rbracket", "newline"]

	var stack : Array = []
	var i     := 0

	while i < text.length():
		if text[i] != "[":
			i += 1
			continue

		var end := text.find("]", i + 1)
		if end == -1:
			break   # unclosed bracket — stop scanning

		# Extract and normalise the tag content, e.g. "COLOR=yellow" → "color"
		var raw := text.substr(i + 1, end - i - 1).strip_edges().to_lower()
		var tag := raw.split("=")[0].split(" ")[0]  # strip parameters

		if tag.begins_with("/"):
			# Closing tag — pop the stack if the innermost open tag matches.
			var close_tag := tag.substr(1)
			if not stack.is_empty() and stack.back() == close_tag:
				stack.pop_back()
		elif tag not in SELF_CLOSING:
			# Opening tag that needs a matching close.
			stack.push_back(tag)

		i = end + 1

	if stack.is_empty():
		return text

	# Append missing closing tags in innermost-first order.
	var suffix := PackedStringArray()
	for j in range(stack.size() - 1, -1, -1):
		suffix.append("[/%s]" % stack[j])

	return text + "".join(suffix)

static func strip_bbcode(text: String) -> String:
	var parts  := PackedStringArray()
	var i      := 0
	var start  := 0

	while i < text.length():
		if text[i] == "[":
			# Flush the plain-text span before this tag.
			if i > start:
				parts.append(text.substr(start, i - start))

			var close := text.find("]", i + 1)
			if close == -1:
				break      # truncated tag — discard the remainder
			i     = close + 1
			start = i
		else:
			i += 1

	# Trailing plain-text after the last tag.
	if start < text.length():
		parts.append(text.substr(start))

	return "".join(parts)
