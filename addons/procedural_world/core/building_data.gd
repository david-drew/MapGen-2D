# building_data.gd
# Represents a specific building with type and footprint
class_name BuildingData
extends RefCounted

var building_type: String = ""  # "house", "apartment", "store", etc.
var position: Vector2i = Vector2i(-1, -1)  # Center position
var size: Vector2i = Vector2i(0, 0)  # Width x Height in cells
var rotation: float = 0.0  # Rotation in degrees (0, 90, 180, 270)
var tags: Array[String] = []

func _init(type: String = "", pos: Vector2i = Vector2i(-1, -1), sz: Vector2i = Vector2i(0, 0)):
	building_type = type
	position = pos
	size = sz

func is_valid() -> bool:
	"""Check if building has valid data"""
	return building_type != "" and position != Vector2i(-1, -1) and size.x > 0 and size.y > 0

func get_bounds() -> Rect2i:
	"""Get bounding rectangle"""
	return Rect2i(
		position.x - size.x / 2,
		position.y - size.y / 2,
		size.x,
		size.y
	)

func get_cells() -> Array[Vector2i]:
	"""Get all cells occupied by this building"""
	var cells: Array[Vector2i] = []
	var bounds = get_bounds()
	
	for y in range(bounds.position.y, bounds.position.y + bounds.size.y):
		for x in range(bounds.position.x, bounds.position.x + bounds.size.x):
			cells.append(Vector2i(x, y))
	
	return cells

func _to_string() -> String:
	return "Building(%s at %v, size=%v)" % [building_type, position, size]
