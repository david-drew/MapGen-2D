# poi_data.gd
# Point of Interest data structure
class_name POIData
extends RefCounted

var poi_type: String = ""
var position: Vector2i = Vector2i(-1, -1)
var footprint_radius: int = 5
var tags: Array[String] = []
var required: bool = false

func _init(type: String = "", pos: Vector2i = Vector2i(-1, -1), radius: int = 5):
	poi_type = type
	position = pos
	footprint_radius = radius

func is_valid() -> bool:
	"""Check if POI has valid data"""
	return poi_type != "" and position != Vector2i(-1, -1)

func _to_string() -> String:
	return "POI(%s at %v, radius=%d, tags=%v)" % [poi_type, position, footprint_radius, tags]
