extends RefCounted
class_name LeadData

## LeadData - Phase 2: Procedural Hints and Investigation Leads
## Represents a hint spawned after discovering a clue
## Points player toward other evidence without hard-scripting the path

# ============================================================================
# LEAD CONTENT
# ============================================================================

## Unique identifier for this lead
var lead_id: String = ""

## The hint text shown to the player
## Example: "Compare receipts to delivery slips"
var lead_text: String = ""

## Which clue spawned this lead
var source_clue_id: String = ""

# ============================================================================
# TARGET (Where the lead points)
# ============================================================================

## What type of target this lead points to
## "building_type" - Points to a type of building
## "npc_pool" - Points to NPCs from a pool
## "npc_archetype" - Points to NPCs with specific archetype
## "region" - Points to a region
## "action" - Points to an action player should take
## "item" - Points to an item the player needs
var target_type: String = ""

## Target details (flexible dictionary based on target_type)
## Examples:
##   {building_type: "general_store"}
##   {pool: "core_people", archetype: "shopkeeper"}
##   {region: "town"}
##   {action: "search", location: "storeroom"}
var target_data: Dictionary = {}

# ============================================================================
# SPECIFICITY
# ============================================================================

## How specific/direct the lead is
## "vague" - General direction ("Talk to people in town")
## "medium" - Narrows down options ("Check the general store")
## "specific" - Very direct ("Question the shopkeeper about the ledger")
var specificity: String = "medium"

# ============================================================================
# STATE
# ============================================================================

## Has the player seen this lead?
var revealed_to_player: bool = false

## Has the player followed/resolved this lead?
var resolved: bool = false

## When was this lead spawned (game time)
var spawned_at: float = 0.0

## When was this lead resolved (game time)
var resolved_at: float = 0.0

# ============================================================================
# METADATA
# ============================================================================

## Tags for filtering/categorization
var tags: Array[String] = []

## Custom data
var metadata: Dictionary = {}

# ============================================================================
# METHODS
# ============================================================================

func _init():
	"""Initialize with defaults"""
	pass


func generate_lead_id() -> String:
	"""Generate a unique lead ID"""
	return "lead_%s_%d" % [source_clue_id, Time.get_ticks_msec()]


func mark_revealed(game_time: float = 0.0) -> void:
	"""Mark this lead as shown to the player"""
	revealed_to_player = true
	if spawned_at == 0.0:
		spawned_at = game_time


func mark_resolved(game_time: float = 0.0) -> void:
	"""Mark this lead as followed/completed"""
	resolved = true
	resolved_at = game_time


func get_target_description() -> String:
	"""Get human-readable description of where this lead points"""
	match target_type:
		"building_type":
			return "the %s" % target_data.get("building_type", "building")
		
		"npc_pool":
			var pool = target_data.get("pool", "people")
			var archetype = target_data.get("archetype", "")
			if archetype:
				return "a %s" % archetype
			else:
				return "someone in %s" % pool
		
		"npc_archetype":
			return "a %s" % target_data.get("archetype", "person")
		
		"region":
			return target_data.get("region", "area")
		
		"action":
			var action = target_data.get("action", "investigate")
			var location = target_data.get("location", "")
			if location:
				return "%s the %s" % [action, location]
			else:
				return action
		
		"item":
			return target_data.get("item", "something")
		
		_:
			return "somewhere"


func matches_location(region: String, building_type: String = "") -> bool:
	"""Check if this lead's target matches a location"""
	match target_type:
		"building_type":
			return target_data.get("building_type", "") == building_type
		
		"region":
			return target_data.get("region", "") == region
		
		"action":
			# Action leads might have location context
			var action_region = target_data.get("region", "")
			var action_building = target_data.get("building_type", "")
			
			if action_region and action_region != region:
				return false
			if action_building and action_building != building_type:
				return false
			
			return true
		
		_:
			return false


func matches_npc(npc_pool: String = "", npc_archetype: String = "") -> bool:
	"""Check if this lead's target matches an NPC"""
	match target_type:
		"npc_pool":
			if target_data.get("pool", "") != npc_pool:
				return false
			
			var lead_archetype = target_data.get("archetype", "")
			if lead_archetype == "" or npc_archetype == "":
				return true  # No archetype filtering
			
			return lead_archetype == npc_archetype
		
		"npc_archetype":
			return target_data.get("archetype", "") == npc_archetype
		
		_:
			return false


func get_summary() -> String:
	"""Get human-readable summary"""
	var status = ""
	if resolved:
		status = "[RESOLVED]"
	elif revealed_to_player:
		status = "[ACTIVE]"
	else:
		status = "[HIDDEN]"
	
	return "%s Lead: \"%s\" → %s (%s)" % [
		status,
		lead_text,
		get_target_description(),
		specificity
	]


# ============================================================================
# SERIALIZATION
# ============================================================================

func to_dict() -> Dictionary:
	"""Convert to dictionary for saving"""
	return {
		"lead_id": lead_id,
		"lead_text": lead_text,
		"source_clue_id": source_clue_id,
		"target_type": target_type,
		"target_data": target_data,
		"specificity": specificity,
		"revealed_to_player": revealed_to_player,
		"resolved": resolved,
		"spawned_at": spawned_at,
		"resolved_at": resolved_at,
		"tags": tags,
		"metadata": metadata
	}


static func from_dict(data: Dictionary) -> LeadData:
	"""Create LeadData from dictionary"""
	var lead = LeadData.new()
	
	lead.lead_id = data.get("lead_id", "")
	lead.lead_text = data.get("text", data.get("lead_text", ""))  # Support both formats
	lead.source_clue_id = data.get("source_clue_id", "")
	
	# Target
	var target = data.get("target", {})
	if not target.is_empty():
		# If target is a dict with nested structure
		if target.has("type"):
			lead.target_type = target.get("type", "")
			# Copy all target fields except 'type' into target_data
			for key in target.keys():
				if key != "type":
					lead.target_data[key] = target[key]
		else:
			# Flat structure - infer type from keys
			if target.has("building_type"):
				lead.target_type = "building_type"
				lead.target_data = target
			elif target.has("pool"):
				lead.target_type = "npc_pool"
				lead.target_data = target
			elif target.has("region"):
				lead.target_type = "region"
				lead.target_data = target
			elif target.has("action"):
				lead.target_type = "action"
				lead.target_data = target
			else:
				lead.target_data = target
	
	lead.specificity = data.get("specificity", "medium")
	
	# State
	lead.revealed_to_player = data.get("revealed_to_player", false)
	lead.resolved = data.get("resolved", false)
	lead.spawned_at = data.get("spawned_at", 0.0)
	lead.resolved_at = data.get("resolved_at", 0.0)
	
	# Tags
	var tags_data = data.get("tags", [])
	for tag in tags_data:
		lead.tags.append(str(tag))
	
	lead.metadata = data.get("metadata", {})
	
	# Generate ID if not set
	if lead.lead_id == "":
		lead.lead_id = lead.generate_lead_id()
	
	return lead
