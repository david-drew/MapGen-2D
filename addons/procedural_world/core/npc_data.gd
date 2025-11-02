extends EntityData
class_name NPCData

## NPCData - Specialized EntityData for Non-Player Characters
## Extends EntityData with NPC-specific properties

# Identity
var gender: String = "neutral"  # "male", "female", "neutral"
var age_category: String = "adult"  # "child", "teen", "adult", "elder"
var species: String = "human"  # "human", "elf", "dwarf", etc.

# Personality
var personality_traits: Array[String] = []  # "friendly", "grumpy", "anxious", etc.
var disposition: String = "neutral"  # "friendly", "neutral", "hostile", "fearful"

# Behavior
var behavior_type: String = "idle"  # "idle", "wander", "patrol", "work"
var wander_radius: float = 10.0  # Distance NPC will wander from spawn
var movement_speed: float = 1.0  # Movement speed multiplier

# Schedule (for future time-based behavior)
var schedule: Dictionary = {}  # Time -> behavior mappings

# Dialogue
var dialogue_file: String = ""  # Path to dialogue resource
var greeting_lines: Array[String] = []  # Quick greeting options
var bark_lines: Array[String] = []  # Ambient/bark dialogue

# Inventory & Trading
var is_merchant: bool = false
var merchant_inventory: Array = []  # Item IDs for sale
var currency_amount: int = 0

# Quest relationships
var quest_giver: bool = false
var quest_ids: Array[String] = []  # Quests this NPC is involved in

# Stats - Nested dictionary for all numeric attributes
var stats: Dictionary = {
	"health": 100,
	"max_health": 100,
	"stress": 0,
	"mystery_potential": 0
}


func _init():
	"""Initialize NPC with defaults"""
	entity_type = "npc"


func is_merchant_npc() -> bool:
	"""Check if this NPC can trade"""
	return is_merchant


func is_quest_related() -> bool:
	"""Check if NPC is involved in any quests"""
	return quest_giver or not quest_ids.is_empty()


func get_summary() -> String:
	"""Get NPC-specific summary"""
	# Get base summary manually
	var base = "[%s] %s (%s) - %s" % [entity_type, display_name, entity_id, classification]
	var extras = []
	
	if is_merchant:
		extras.append("Merchant")
	if quest_giver:
		extras.append("Quest Giver")
	if behavior_type != "idle":
		extras.append(behavior_type.capitalize())
	
	if extras.is_empty():
		return base
	else:
		return "%s [%s]" % [base, ", ".join(extras)]


func to_dict() -> Dictionary:
	"""Convert NPC to dictionary"""
	# Manually gather base EntityData fields
	var data = {
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
	
	# Add NPC-specific fields
	data["gender"] = gender
	data["age_category"] = age_category
	data["species"] = species
	data["personality_traits"] = personality_traits
	data["disposition"] = disposition
	data["behavior_type"] = behavior_type
	data["wander_radius"] = wander_radius
	data["movement_speed"] = movement_speed
	data["schedule"] = schedule
	data["dialogue_file"] = dialogue_file
	data["greeting_lines"] = greeting_lines
	data["bark_lines"] = bark_lines
	data["is_merchant"] = is_merchant
	data["merchant_inventory"] = merchant_inventory
	data["currency_amount"] = currency_amount
	data["quest_giver"] = quest_giver
	data["quest_ids"] = quest_ids
	data["stats"] = stats
	
	return data


static func from_dict(data: Dictionary) -> NPCData:
	"""Create NPCData from dictionary"""
	var npc = NPCData.new()
	
	# Load base EntityData fields
	npc.entity_id = data.get("entity_id", "")
	npc.entity_type = "npc"
	npc.display_name = data.get("display_name", "Unknown NPC")
	npc.classification = data.get("classification", "")
	npc.archetype = data.get("archetype", "")
	
	# Pools
	var pools_data = data.get("pools", [])
	for pool in pools_data:
		npc.pools.append(str(pool))
	
	# Visual
	npc.sprite_path = data.get("sprite_path", "")
	npc.sprite_frames = data.get("sprite_frames", "")
	npc.scale = data.get("scale", 1.0)
	
	# Color tint
	var tint = data.get("color_tint", [1.0, 1.0, 1.0, 1.0])
	if tint is Array and tint.size() >= 3:
		npc.color_tint = Color(tint[0], tint[1], tint[2], tint[3] if tint.size() > 3 else 1.0)
	
	# Tags
	var tags_data = data.get("tags", [])
	for tag in tags_data:
		npc.tags.append(str(tag))
	
	# Metadata
	npc.metadata = data.get("metadata", {})
	
	# NPC-specific fields
	npc.gender = data.get("gender", "neutral")
	npc.age_category = data.get("age_category", "adult")
	npc.species = data.get("species", "human")
	
	# Personality
	var personality_data = data.get("personality_traits", [])
	for t in personality_data:
		npc.personality_traits.append(str(t))
	
	npc.disposition = data.get("disposition", "neutral")
	
	# Behavior
	npc.behavior_type = data.get("behavior_type", "idle")
	npc.wander_radius = data.get("wander_radius", 10.0)
	npc.movement_speed = data.get("movement_speed", 1.0)
	npc.schedule = data.get("schedule", {})
	
	# Dialogue
	npc.dialogue_file = data.get("dialogue_file", "")
	
	var greeting_data = data.get("greeting_lines", [])
	for line in greeting_data:
		npc.greeting_lines.append(str(line))
	
	var bark_data = data.get("bark_lines", [])
	for line in bark_data:
		npc.bark_lines.append(str(line))
	
	# Merchant
	npc.is_merchant = data.get("is_merchant", false)
	npc.merchant_inventory = data.get("merchant_inventory", [])
	npc.currency_amount = data.get("currency_amount", 0)
	
	# Quest
	npc.quest_giver = data.get("quest_giver", false)
	
	var quest_data = data.get("quest_ids", [])
	for quest_id in quest_data:
		npc.quest_ids.append(str(quest_id))
	
	# Stats - Support both old flat format and new nested format
	if data.has("stats"):
		# New nested format
		var stats_data = data.get("stats", {})
		npc.stats["health"] = stats_data.get("health", 100)
		npc.stats["max_health"] = stats_data.get("max_health", 100)
		npc.stats["stress"] = stats_data.get("stress", 0)
		npc.stats["mystery_potential"] = stats_data.get("mystery_potential", 0)
	else:
		# Old flat format (backward compatibility)
		npc.stats["health"] = data.get("health", 100)
		npc.stats["max_health"] = data.get("max_health", 100)
		npc.stats["stress"] = data.get("stress", 0)
		npc.stats["mystery_potential"] = data.get("mystery_potential", 0)
	
	return npc
