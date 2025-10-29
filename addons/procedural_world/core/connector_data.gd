# connector_data.gd
# Represents a connection between two regions
class_name ConnectorData
extends RefCounted

var connector_id: String = ""
var connector_type: String = ""  # "old_road", "forest_path", "hidden_trail", etc.
var from_region: String = ""
var to_region: String = ""
var from_exit: String = ""  # "north", "south", "east", "west", or specific position
var to_entrance: String = ""
var tags: Array[String] = []
var traversal_time_minutes: float = 5.0
var difficulty: String = "easy"  # "easy", "medium", "hard"
var is_discovered: bool = true  # false for hidden paths

func _init(id: String = "", type: String = "", from: String = "", to: String = ""):
	connector_id = id
	connector_type = type
	from_region = from
	to_region = to

func is_valid() -> bool:
	"""Check if connector has valid data"""
	return connector_id != "" and from_region != "" and to_region != ""

func get_description() -> String:
	"""Get human-readable description"""
	var desc = connector_type.capitalize()
	if difficulty != "easy":
		desc += " (%s)" % difficulty
	if traversal_time_minutes > 0:
		desc += " - %d min travel" % int(traversal_time_minutes)
	return desc

func _to_string() -> String:
	return "Connector(%s: %s → %s via %s)" % [connector_id, from_region, to_region, connector_type]
