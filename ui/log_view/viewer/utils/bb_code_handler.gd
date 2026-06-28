# bb_code_handler.gd
# Parses a BBCode string into a node tree, then renders it for a specific view.
#
#   A single regex pass can only produce a string — it has no awareness of
#   nesting, attributes, or invalid structure. The tree separates parsing
#   from rendering so that:
#     - Simple views  (RichTextLabel) call to_bbcode(tree) → String
#     - Complex views (TextEdit + syntax highlighter) walk the raw tree
#     - Both share the same parse result; no double-work
#
# NODE TYPES
#   "root"    — document root, only appears at the top level
#   "text"    — plain text leaf; field: text
#   "element" — allowed standard BBCode tag; fields: name, attrs, children
#   "custom"  — user-defined semantic tag;   fields: name, attrs, children, def
#   "unknown" — not in either list;          fields: name, attrs, children
#               string renderer strips markers, children rendered as-is
#               complex views can inspect or flag these as errors
#
# ATTRIBUTES
#   [color=#ff0000]       → attrs: { "": "#ff0000" }
#   [img width=100 h=50]  → attrs: { "width": "100", "h": "50" }
#   [b]                   → attrs: {}
#   Stored on every element/custom/unknown node.
#
# INVALID NESTING
#   [a][b][/a][/b] — when [/a] is found and b is on top of the stack:
#   force-close b (marking it invalid_close: true), then close a.
#   Orphaned close tags ([/x] with no matching open) are discarded.
#   Auto-close any tags still open at end of input (auto_closed: true).
#   Both flags are visible in the tree for syntax highlighters to use.
#
# CUSTOM TAG DEFINITIONS
#   Two forms:
#     color("error",  "#F28B82")
#     define("pulse", { "open": "[wave]", "close": "[/wave]" })
#
# USAGE
#   var h := BBCodeHandler.new()
#       .allow(["b", "i", "u", "color", "wave"])
#       .color("error", "#F28B82")
#       .color("ok",    "#4EC9B0")
#       .define("pulse", { "open": "[wave]", "close": "[/wave]" })
#
#   # Simple string view (RichTextLabel):
#   label.append_text(h.process(entry.content))
#
#   # Complex view (syntax highlighter):
#   var tree := h.parse(entry.content)
#   _walk(tree)   # your own tree walker

extends RefCounted

# Configuration

var _allowed : Dictionary = {}   # name → true
var _custom  : Dictionary = {}   # name → { "open": String, "close": String }

# Whitelist standard BBCode tag names this view supports.
# Only the base name is needed — "color" covers [color=#f00] and [/color].
func allow(tags: Array):
	for t : String in tags:
		_allowed[t.to_lower()] = true
	return self

# Register a custom semantic tag with explicit open/close BBCode strings.
# definition must have "open" and "close" keys.
# Example: define("pulse", { "open": "[wave]", "close": "[/wave]" })
func define(name: String, definition: Dictionary) :
	_custom[name.to_lower()] = definition
	return self

# Shorthand: register a semantic tag that only changes colour.
# Equivalent to: define(name, { "open": "[color=hex]", "close": "[/color]" })
func color(name: String, hex: String):
	return define(name, { "open": "[color=%s]" % hex, "close": "[/color]" })


# Main API

# Returns a style-resolved tree ready for depth-first traversal.
# No tag-name logic needed in the consumer — every node already knows its style.
#
# Branch node:  { "style": Dictionary, "children": Array }
# Leaf node:    { "text": String }
#
# Traversal pattern (same for RTL and syntax highlighter):
#   func _render(node):
#       if node.has("text"):
#           emit(node.text)
#           return
#       push(node.style)          # empty dict = nothing to push
#       for child in node.children:
#           _render(child)
#       pop(node.style)           # only if you pushed
func styled_tree(text: String) -> Dictionary:
	return _resolve(parse(text))

# Parse a BBCode string into a node tree.
# See NODE TYPES in the file header for the tree structure.
func parse(text: String) -> Dictionary:
	return _build_tree(_tokenize(text))


func _resolve(node: Dictionary) -> Dictionary:
	match node.get("type", ""):

		"text":
			return { "text": node.get("text", "") }

		"root", "unknown":
			return { "style": {}, "children": _resolve_children(node) }

		"element":
			return { "style": _style_from_element(node), "children": _resolve_children(node) }

		"custom":
			return { "style": _style_from_custom(node),  "children": _resolve_children(node) }

	return { "style": {}, "children": [] }


func _resolve_children(node: Dictionary) -> Array:
	var out : Array = []
	for child : Dictionary in node.get("children", []):
		out.append(_resolve(child))
	return out


func _style_from_element(node: Dictionary) -> Dictionary:
	var attrs : Dictionary = node.get("attrs", {})
	match node.get("name", ""):
		"b":     return { "bold":          true }
		"i":     return { "italic":        true }
		"u":     return { "underline":     true }
		"s":     return { "strikethrough": true }
		"color":
			var hex : String = attrs.get("", "")
			return {} if hex.is_empty() else { "color": Color.html(hex) }
	return {}


func _style_from_custom(node: Dictionary) -> Dictionary:
	var open_str : String = _custom.get(node.get("name", ""), {}).get("open", "")
	if open_str.begins_with("[color=") and open_str.ends_with("]"):
		return { "color": Color.html(open_str.substr(7, open_str.length() - 8)) }
	return {}


# Tokenizer

enum _TK { TEXT, OPEN, CLOSE }

func _tokenize(text: String) -> Array:
	var tokens   : Array  = []
	var regex    := RegEx.new()
	var last_end : int    = 0

	# Group 1 → "/" if closing tag
	# Group 2 → tag name
	# Group 3 → attribute string (everything after name until ])
	regex.compile("\\[(/?)([a-zA-Z0-9_]+)([^\\]]*)\\]")

	for m : RegExMatch in regex.search_all(text):
		if m.get_start() > last_end:
			tokens.append({ "kind": _TK.TEXT, "text": text.substr(last_end, m.get_start() - last_end) })

		var name : String = m.get_string(2).to_lower()
		tokens.append({
			"kind"  : _TK.CLOSE if m.get_string(1) == "/" else _TK.OPEN,
			"name"  : name,
			"attrs" : _parse_attrs(m.get_string(3)),
			"raw"   : m.get_string(0),
		})
		last_end = m.get_end()

	if last_end < text.length():
		tokens.append({ "kind": _TK.TEXT, "text": text.substr(last_end) })

	return tokens


# Parses the attribute portion of a tag (everything after the name).
#   ""                    → {}
#   "=#ff0000"            → { "": "#ff0000" }
#   " width=100 height=50"→ { "width": "100", "height": "50" }
func _parse_attrs(raw: String) -> Dictionary:
	raw = raw.strip_edges()
	if raw.is_empty():
		return {}
	if raw.begins_with("="):
		return { "": raw.substr(1).strip_edges() }
	var out     := {}
	var kv_re   := RegEx.new()
	kv_re.compile("([a-zA-Z0-9_]+)=([^\\s\\]]+)")
	for m : RegExMatch in kv_re.search_all(raw):
		out[m.get_string(1).to_lower()] = m.get_string(2)
	return out


# Tree builder

func _build_tree(tokens: Array) -> Dictionary:
	var root  : Dictionary = _node("root", "", {})
	var stack : Array      = [root]

	for token : Dictionary in tokens:
		match token.kind:
			_TK.TEXT:
				stack.back().children.append({ "type": "text", "text": token.text })

			# NEW
			_TK.OPEN:
				if _classify(token.name) == "unknown":
					stack.back().children.append({ "type": "text", "text": token.raw })
				else:
					var node := _node(_classify(token.name), token.name, token.attrs)
					if token.name in _custom:
						node["def"] = _custom[token.name]
					stack.append(node)

			# NEW
			_TK.CLOSE:
				var match_idx := -1
				for i in range(stack.size() - 1, 0, -1):
					if stack[i].name == token.name:
						match_idx = i
						break
				if match_idx == -1:
					stack.back().children.append({ "type": "text", "text": token.raw })
				else:
					_close(token.name, stack)

	# Auto-close any tags still open at end of input.
	while stack.size() > 1:
		var node : Dictionary = stack.pop_back()
		node["auto_closed"] = true
		stack.back().children.append(node)

	return root


# Closes the nearest matching open tag in the stack.
# Force-closes anything between the top and the matched tag (invalid nesting).
# Discards the close token entirely if no matching open tag exists.
func _close(name: String, stack: Array) -> void:
	# Find the nearest matching open tag, searching from the top down.
	var match_idx : int = -1
	for i in range(stack.size() - 1, 0, -1):
		if stack[i].name == name:
			match_idx = i
			break

	if match_idx == -1:
		return  # Orphaned close tag — no matching open anywhere, discard.

	# Force-close everything above the matched tag.
	# These nodes had an outer tag close before they did — invalid nesting.
	while stack.size() - 1 > match_idx:
		var orphan : Dictionary = stack.pop_back()
		orphan["invalid_close"] = true
		stack.back().children.append(orphan)

	# Close the matched tag normally — pop it and attach to its parent.
	stack.back().children.append(stack.pop_back())


func _node(type: String, name: String, attrs: Dictionary) -> Dictionary:
	return { "type": type, "name": name, "attrs": attrs, "children": [] }

func _classify(name: String) -> String:
	if _custom.has(name):  return "custom"
	if _allowed.has(name): return "element"
	return "unknown"


# Renderers

func _render_bbcode(node: Dictionary) -> String:
	match node.get("type", ""):
		"root", "unknown":
			return _render_children(node)

		"text":
			return node.get("text", "")

		"element":
			return "%s%s[/%s]" % [_open_tag(node), _render_children(node), node.name]

		"custom":
			var def   : Dictionary = node.get("def", {})
			var inner : String     = _render_children(node)
			return "%s%s%s" % [def.get("open", ""), inner, def.get("close", "")]

	return ""


func _render_children(node: Dictionary) -> String:
	var out := ""
	for child : Dictionary in node.get("children", []):
		out += _render_bbcode(child)
	return out


func _render_plain(node: Dictionary) -> String:
	if node.get("type", "") == "text":
		return node.get("text", "")
	var out := ""
	for child : Dictionary in node.get("children", []):
		out += _render_plain(child)
	return out


# Reconstructs the opening tag string from a parsed element node.
#   attrs: {}            → [color]       (shouldn't happen for color, but safe)
#   attrs: {"": "#f00"}  → [color=#f00]
#   attrs: {"w":"1","h":"2"} → [img w=1 h=2]
func _open_tag(node: Dictionary) -> String:
	var attrs : Dictionary = node.get("attrs", {})
	if attrs.is_empty():
		return "[%s]" % node.name
	if attrs.size() == 1 and attrs.has(""):
		return "[%s=%s]" % [node.name, attrs[""]]
	var pairs : Array = []
	for k : String in attrs:
		pairs.append("%s=%s" % [k, attrs[k]])
	return "[%s %s]" % [node.name, " ".join(pairs)]
