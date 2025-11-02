extends RefCounted
class_name EntityData

## EntityData - Base class for all entity types (NPCs, items, enemies, etc.)
## This is the base that NPCData, ItemData, etc. will extend

# Core identification
var entity_id: String = ""  # Unique ID (e.g., "npc_merchant_01")
var entity_type: String = "npc"  # Type: "npc", "item", "enemy", "event"
var display_name: String = "Unknown Entity"  # Human-readable name

# Classification
var classification: String = ""  # Category (e.g., "merchant", "guard", "weapon")
var archetype: String = ""  # Role/template (e.g., "shopkeeper", "quest_giver")

# Pool membership
var pools: Array[String] = []  # Which pools this entity belongs to

# Visual data
var sprite_path: String = ""  # Path to sprite/texture
var sprite_frames: String = ""  # Path to SpriteFrames for animation
var color_tint: Color = Color.WHITE  # Color modifier
var scale: float = 1.0  # Default scale

# Tags for filtering
var tags: Array[String] = []  # String array for gameplay tags

# Metadata
var metadata: Dictionary = {}  # Custom key-value data


func _init():
	"""Initialize with default values"""
	pass


func has_tag(tag: String) -> bool:
	"""Check if entity has a specific tag"""
	return tag in tags


func add_tag(tag: String) -> void:
	"""Add a tag if not already present"""
	if not has_tag(tag):
		tags.append(tag)


func remove_tag(tag: String) -> void:
	"""Remove a tag"""
	tags.erase(tag)


func get_summary() -> String:
	"""Get a human-readable summary"""
	return "[%s] %s (%s) - %s" % [entity_type, display_name, entity_id, classification]


func to_dict() -> Dictionary:
	"""Convert to dictionary for serialization"""
	return {
		"entity_id": entity_id,
		"entity_type": entity_type,
		"display_name": display_name,
		"classification": classification,
		"archetype": archetype,
		"pools": pools,
		"sprite_path": sprite_path,
		"sprite_frames": sprite_frames,
		"color_tint": [color_tint.r, color_tint.g, color_tint.b, color_tint.a],
		"scale": scale,
		"tags": tags,
		"metadata": metadata
	}


static func from_dict(data: Dictionary) -> EntityData:
	"""Create EntityData from dictionary"""
	var entity = EntityData.new()
	
	entity.entity_id = data.get("entity_id", "")
	entity.entity_type = data.get("entity_type", "npc")
	entity.display_name = data.get("display_name", "Unknown")
	entity.classification = data.get("classification", "")
	entity.archetype = data.get("archetype", "")
	
	# Handle pools
	var pools_data = data.get("pools", [])
	for pool in pools_data:
		entity.pools.append(str(pool))
	
	# Visual
	entity.sprite_path = data.get("sprite_path", "")
	entity.sprite_frames = data.get("sprite_frames", "")
	entity.scale = data.get("scale", 1.0)
	
	# Color tint
	var tint = data.get("color_tint", [1.0, 1.0, 1.0, 1.0])
	if tint is Array and tint.size() >= 3:
		entity.color_tint = Color(tint[0], tint[1], tint[2], tint[3] if tint.size() > 3 else 1.0)
	
	# Tags
	var tags_data = data.get("tags", [])
	for tag in tags_data:
		entity.tags.append(str(tag))
	
	# Metadata
	entity.metadata = data.get("metadata", {})
	
	return entity
