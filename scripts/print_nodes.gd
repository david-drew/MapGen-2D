extends Node

func _ready():
	# Call this function to save the current scene's hierarchy
	var root_node = $".."
	save_node_hierarchy_to_file("res://node_hierarchy.txt", root_node)
	#save_node_hierarchy_to_file("res://node_hierarchy.txt", self)


func save_node_hierarchy_to_file(file_path: String, root_node: Node):
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		_write_node_recursive(file, root_node, 0)
		file.close()
		print("Node hierarchy saved to: " + file_path)
	else:
		print("Error opening file: " + file_path)

func _write_node_recursive(file: FileAccess, node: Node, indent_level: int):
	# Create indentation based on the hierarchy level
	var indent = ""
	for i in range(indent_level):
		indent += "  " # Two spaces per indent level

	# Write node name and type with indentation
	file.store_line(indent + node.name + " (" + node.get_class() + ")")

	# Recursively call for children
	for child in node.get_children():
		_write_node_recursive(file, child, indent_level + 1)
