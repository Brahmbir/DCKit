extends RefCounted

class ProfilerNode:
	var name     : String
	var start_us : int
	var end_us   : int
	var children : Array[ProfilerNode] = []

	func total_ms() -> float:
		return float(end_us - start_us) / 1000.0

	func self_ms() -> float:
		var child := 0.0
		for c in children:
			child += c.total_ms()
		return total_ms() - child


var enabled := false
var root    : ProfilerNode = null

var _stack  : Array[ProfilerNode] = []


func begin(command: String) -> void:
	var node := ProfilerNode.new()
	node.name = command
	node.start_us = Time.get_ticks_usec()

	if _stack.is_empty():
		root = node
	else:
		_stack.back().children.append(node)

	_stack.push_back(node)


func end() -> void:
	var node :ProfilerNode= _stack.pop_back()
	node.end_us = Time.get_ticks_usec()


func reset() -> void:
	root = null
	_stack.clear()


func report() -> String:
	if root == null:
		return "No profiling data."

	var out : PackedStringArray = []
	_print(root, "", true, out)
	out.append("")
	out.append("Total: %.3f ms" % root.total_ms())
	return "\n".join(out)


func _print(node: ProfilerNode, prefix: String, last: bool, out: PackedStringArray) -> void:
	var branch := "" if prefix.is_empty() else ("└── " if last else "├── ")
	out.append(prefix + branch + "%s (%.3f ms)" % [node.name, node.total_ms()])

	var next_prefix := prefix
	if not prefix.is_empty():
		next_prefix += "    " if last else "│   "

	for i in node.children.size():
		_print(node.children[i], next_prefix, i == node.children.size() - 1, out)
