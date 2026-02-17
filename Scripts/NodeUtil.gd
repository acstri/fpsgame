extends Object
class_name NodeUtil

static func find_child_by_type(root: Node, t: Variant) -> Node:
	if root == null:
		return null
	for c in root.get_children():
		if is_instance_of(c, t):
			return c
		var deep := find_child_by_type(c, t)
		if deep != null:
			return deep
	return null

static func find_child_by_name(root: Node, name: StringName) -> Node:
	if root == null:
		return null
	if root.has_node(NodePath(name)):
		return root.get_node(NodePath(name))
	for c in root.get_children():
		if StringName(c.name) == name:
			return c
		var deep := find_child_by_name(c, name)
		if deep != null:
			return deep
	return null

static func require(node: Object, what: String) -> bool:
	if node == null:
		push_error("Missing required reference: %s" % what)
		return false
	return true
