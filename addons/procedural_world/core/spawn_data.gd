extends RefCounted
class_name SpawnData

## SpawnData - Data structure for entity spawn points
## Holds all information about where and how an entity should spawn

# Core identification
var spawn_id: String = ""  # Unique identifier for this spawn
var spawn_type: String = "npc"  # Type: "npc", "item", "event", "enemy", etc.

# Entity reference
var entity_data: EntityData = null  # The actual entity to spawn

# Location data
var region_id: String = ""  # Which region this spawn belongs to
var placement_type: String = "exterior"  # How to place: "exterior", "interior", "poi", "path"
var position: Vector2i = Vector2i(-1, -1)  # Actual world position (set after placement)
var _has_position: bool = false  # Whether position has been determined (internal)

# Placement filters (optional, used during position finding)
var building_type_filter: String = ""  # For interior placement: specific building type
var poi_type_filter: String = ""  # For POI placement: specific POI type

# Spawn behavior
var is_required: bool = false  # If true, generation fails if spawn can't be placed
var is_unique: bool = true  # If true, only one instance should exist
var spawn_count: int = 1  # Number of instances to spawn (expanded by manager)

# Visual properties
var facing_degrees: float = 0.0  # Direction entity faces (0 = north, 90 = east)
var scale: float = 1.0  # Scale multiplier for visual representation
var variant: String = ""  # Visual variant (e.g., "injured", "angry")

# Tags for filtering and logic
var tags: Array = []  # String array for quest/behavior tags

# Additional metadata
var spawn_metadata: Dictionary = {}  # Custom key-value data


func _init():
	"""Initialize with default values"""
	pass


func set_actual_position(pos: Vector2i) -> void:
	"""Set the final spawn position after placement"""
	position = pos
	_has_position = true


func has_position() -> bool:
	"""Check if this spawn has a valid position"""
	return _has_position and position != Vector2i(-1, -1)


func duplicate() -> SpawnData:
	"""Create a deep copy of this spawn data"""
	var copy = SpawnData.new()
	
	# Copy primitives
	copy.spawn_id = spawn_id
	copy.spawn_type = spawn_type
	copy.entity_data = entity_data  # Reference copy (entities are shared)
	copy.region_id = region_id
	copy.placement_type = placement_type
	copy.position = position
	copy._has_position = _has_position
	copy.building_type_filter = building_type_filter
	copy.poi_type_filter = poi_type_filter
	copy.is_required = is_required
	copy.is_unique = is_unique
	copy.spawn_count = spawn_count
	copy.facing_degrees = facing_degrees
	copy.scale = scale
	copy.variant = variant
	
	# Deep copy arrays and dictionaries
	copy.tags = tags.duplicate()
	copy.spawn_metadata = spawn_metadata.duplicate(true)
	
	return copy


func get_summary() -> String:
	"""Get a human-readable summary of this spawn"""
	var entity_name = entity_data.display_name if entity_data else "None"
	var pos_str = str(position) if has_position() else "unplaced"
	var required_str = "REQUIRED" if is_required else "optional"
	
	return "[%s] %s (%s) at %s in region '%s' - %s" % [
		spawn_type,
		entity_name,
		spawn_id,
		pos_str,
		region_id,
		required_str
	]


func to_dict() -> Dictionary:
	"""Convert to dictionary for serialization"""
	return {
		"spawn_id": spawn_id,
		"spawn_type": spawn_type,
		"entity_id": entity_data.entity_id if entity_data else "",
		"region_id": region_id,
		"placement_type": placement_type,
		"position": [position.x, position.y] if has_position() else null,
		"building_type_filter": building_type_filter,
		"poi_type_filter": poi_type_filter,
		"is_required": is_required,
		"is_unique": is_unique,
		"spawn_count": spawn_count,
		"facing_degrees": facing_degrees,
		"scale": scale,
		"variant": variant,
		"tags": tags,
		"metadata": spawn_metadata
	}


static func from_dict(data: Dictionary, entity_mgr: EntityPoolManager) -> SpawnData:
	"""Create SpawnData from dictionary (for deserialization)"""
	var spawn = SpawnData.new()
	
	spawn.spawn_id = data.get("spawn_id", "")
	spawn.spawn_type = data.get("spawn_type", "npc")
	spawn.region_id = data.get("region_id", "")
	spawn.placement_type = data.get("placement_type", "exterior")
	spawn.building_type_filter = data.get("building_type_filter", "")
	spawn.poi_type_filter = data.get("poi_type_filter", "")
	spawn.is_required = data.get("is_required", false)
	spawn.is_unique = data.get("is_unique", true)
	spawn.spawn_count = data.get("spawn_count", 1)
	spawn.facing_degrees = data.get("facing_degrees", 0.0)
	spawn.scale = data.get("scale", 1.0)
	spawn.variant = data.get("variant", "")
	spawn.tags = data.get("tags", [])
	spawn.spawn_metadata = data.get("metadata", {})
	
	# Restore position if present
	var pos = data.get("position", null)
	if pos and pos is Array and pos.size() == 2:
		spawn.position = Vector2i(pos[0], pos[1])
		spawn._has_position = true
	
	# Resolve entity reference
	var entity_id = data.get("entity_id", "")
	if entity_id != "":
		spawn.entity_data = entity_mgr.get_npc_by_id(entity_id)
	
	return spawn
