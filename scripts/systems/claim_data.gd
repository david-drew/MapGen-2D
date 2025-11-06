extends RefCounted
class_name ClaimData

## ClaimData - Phase 2: Subject-Predicate-Object Evidence Relationships
## Represents a single claim/assertion that a clue makes about the world
## Example: "Shopkeeper was_present_at General Store during night"

# ============================================================================
# CLAIM STRUCTURE (Subject-Predicate-Object)
# ============================================================================

## Subject: Who/what the claim is about
## Format: {type: "npc|npc_pool|object_tag|place", ...type-specific fields}
var subject: Dictionary = {}

## Predicate: The relationship/action
## Examples: "was_present_at", "possesses", "performed_ritual", "left_trace_at"
var predicate: String = ""

## Object: What the subject relates to
## Format: {type: "npc|npc_pool|object_tag|place", ...type-specific fields}
var object: Dictionary = {}

# ============================================================================
# CONTEXT
# ============================================================================

## Time window when this claim applies
var time_window: String = ""  # "day", "night", "dawn", "dusk", or ""

## Location context (optional, for additional filtering)
var location_context: Dictionary = {}  # {region: "town", building_type: "tavern"}

# ============================================================================
# CONFIDENCE TRACKING
# ============================================================================

## Base confidence when first discovered (0.0 - 1.0)
var confidence_base: float = 0.5

## Current confidence after corroboration/contradiction (0.0 - 1.0)
var confidence_current: float = 0.5

## History of confidence changes
## [{source: "clue_id", delta: +0.15, reason: "corroboration", timestamp: 123.4}]
var confidence_modifiers: Array = []

# ============================================================================
# CLAIM RELATIONSHIPS
# ============================================================================

## Clue IDs that support/corroborate this claim
var supported_by_clues: Array[String] = []

## Clue IDs that contradict/refute this claim
var refuted_by_clues: Array[String] = []

## Tags that this claim contributes to (for proof gates)
## Example: ["tag:presence_at_scene", "tag:motive_link"]
var contributes_to_tags: Array[String] = []

# ============================================================================
# METADATA
# ============================================================================

## Unique identifier for this claim (auto-generated)
var claim_id: String = ""

## Which clue originally made this claim
var source_clue_id: String = ""

## When this claim was first discovered (game time)
var discovered_at: float = 0.0

## Custom metadata
var metadata: Dictionary = {}

# ============================================================================
# METHODS
# ============================================================================

func _init():
	"""Initialize with defaults"""
	pass


func generate_claim_id() -> String:
	"""Generate a unique claim ID from the claim structure"""
	# Create a hash-like ID from subject-predicate-object
	var subj_str = _entity_to_string(subject)
	var obj_str = _entity_to_string(object)
	var id_parts = [subj_str, predicate, obj_str]
	
	if time_window != "":
		id_parts.append(time_window)
	
	return "claim_" + "_".join(id_parts).to_lower().replace(" ", "_")


func _entity_to_string(entity: Dictionary) -> String:
	"""Convert entity dict to string for ID generation"""
	var entity_type = entity.get("type", "unknown")
	
	match entity_type:
		"npc":
			return entity.get("entity_id", "npc")
		"npc_pool":
			var pool = entity.get("pool", "pool")
			var archetype = entity.get("archetype", "")
			return archetype if archetype else pool
		"object_tag":
			return entity.get("tag", "object")
		"place":
			var building = entity.get("building_type", "")
			return building if building else "place"
		_:
			return entity_type


func update_confidence(delta: float, source: String, reason: String = "") -> void:
	"""
	Update confidence score with a modifier
	delta: positive for corroboration, negative for contradiction
	source: what caused the change (usually a clue_id)
	"""
	var old_confidence = confidence_current
	confidence_current = clamp(confidence_current + delta, 0.0, 1.0)
	
	# Record the change
	confidence_modifiers.append({
		"source": source,
		"delta": delta,
		"reason": reason,
		"old_value": old_confidence,
		"new_value": confidence_current,
		"timestamp": Time.get_ticks_msec() / 1000.0
	})


func add_supporting_clue(clue_id: String) -> void:
	"""Mark a clue as supporting this claim"""
	if clue_id not in supported_by_clues:
		supported_by_clues.append(clue_id)


func add_refuting_clue(clue_id: String) -> void:
	"""Mark a clue as contradicting this claim"""
	if clue_id not in refuted_by_clues:
		refuted_by_clues.append(clue_id)


func get_confidence_strength() -> String:
	"""Get human-readable confidence level"""
	if confidence_current >= 0.8:
		return "very_high"
	elif confidence_current >= 0.6:
		return "high"
	elif confidence_current >= 0.4:
		return "medium"
	elif confidence_current >= 0.2:
		return "low"
	else:
		return "very_low"


func is_contested() -> bool:
	"""Check if this claim has contradicting evidence"""
	return not refuted_by_clues.is_empty()


func get_net_support() -> int:
	"""Get net support (supporting - refuting clues)"""
	return supported_by_clues.size() - refuted_by_clues.size()


func matches_entity(entity_dict: Dictionary, entity_to_match: Dictionary) -> bool:
	"""
	Check if an entity description matches another
	Used for finding claims about specific NPCs, locations, etc.
	"""
	var type_a = entity_dict.get("type", "")
	var type_b = entity_to_match.get("type", "")
	
	if type_a != type_b:
		return false
	
	match type_a:
		"npc":
			return entity_dict.get("entity_id", "") == entity_to_match.get("entity_id", "")
		"npc_pool":
			# Match if same pool (archetype optional)
			if entity_dict.get("pool", "") != entity_to_match.get("pool", ""):
				return false
			var arch_a = entity_dict.get("archetype", "")
			var arch_b = entity_to_match.get("archetype", "")
			return arch_a == "" or arch_b == "" or arch_a == arch_b
		"object_tag":
			return entity_dict.get("tag", "") == entity_to_match.get("tag", "")
		"place":
			# Match region and/or building type
			var region_match = (
				entity_dict.get("region", "") == "" or 
				entity_to_match.get("region", "") == "" or
				entity_dict.get("region", "") == entity_to_match.get("region", "")
			)
			var building_match = (
				entity_dict.get("building_type", "") == "" or
				entity_to_match.get("building_type", "") == "" or
				entity_dict.get("building_type", "") == entity_to_match.get("building_type", "")
			)
			return region_match and building_match
	
	return false


func get_summary() -> String:
	"""Get human-readable summary of the claim"""
	var subj_str = _entity_summary(subject)
	var obj_str = _entity_summary(object)
	var time_str = " [%s]" % time_window if time_window else ""
	var conf_str = "%.0f%%" % (confidence_current * 100.0)
	
	return "%s %s %s%s (confidence: %s)" % [
		subj_str,
		predicate,
		obj_str,
		time_str,
		conf_str
	]


func _entity_summary(entity: Dictionary) -> String:
	"""Get display string for an entity"""
	var entity_type = entity.get("type", "unknown")
	
	match entity_type:
		"npc":
			return "NPC<%s>" % entity.get("entity_id", "?")
		"npc_pool":
			var pool = entity.get("pool", "?")
			var arch = entity.get("archetype", "")
			return "%s<%s>" % [arch if arch else "someone", pool]
		"object_tag":
			return entity.get("tag", "?")
		"place":
			var building = entity.get("building_type", "")
			var region = entity.get("region", "")
			if building and region:
				return "%s in %s" % [building, region]
			elif building:
				return building
			elif region:
				return region
			else:
				return "somewhere"
		_:
			return entity_type


# ============================================================================
# SERIALIZATION
# ============================================================================

func to_dict() -> Dictionary:
	"""Convert to dictionary for saving"""
	return {
		"claim_id": claim_id,
		"subject": subject,
		"predicate": predicate,
		"object": object,
		"time_window": time_window,
		"location_context": location_context,
		"confidence_base": confidence_base,
		"confidence_current": confidence_current,
		"confidence_modifiers": confidence_modifiers,
		"supported_by_clues": supported_by_clues,
		"refuted_by_clues": refuted_by_clues,
		"contributes_to_tags": contributes_to_tags,
		"source_clue_id": source_clue_id,
		"discovered_at": discovered_at,
		"metadata": metadata
	}


static func from_dict(data: Dictionary) -> ClaimData:
	"""Create ClaimData from dictionary"""
	var claim = ClaimData.new()
	
	claim.claim_id = data.get("claim_id", "")
	claim.subject = data.get("subject", {})
	claim.predicate = data.get("predicate", "")
	claim.object = data.get("object", {})
	claim.time_window = data.get("time", {}).get("window", "")  # Support nested time object
	claim.location_context = data.get("location", {})  # Support location object
	
	# Confidence
	claim.confidence_base = data.get("confidence_base", 0.5)
	claim.confidence_current = data.get("confidence_current", claim.confidence_base)
	claim.confidence_modifiers = data.get("confidence_modifiers", [])
	
	# Relationships
	var supported = data.get("supported_by_clues", [])
	for clue_id in supported:
		claim.supported_by_clues.append(str(clue_id))
	
	var refuted = data.get("refuted_by_clues", [])
	for clue_id in refuted:
		claim.refuted_by_clues.append(str(clue_id))
	
	var tags = data.get("contributes_to_tags", [])
	for tag in tags:
		claim.contributes_to_tags.append(str(tag))
	
	# Metadata
	claim.source_clue_id = data.get("source_clue_id", "")
	claim.discovered_at = data.get("discovered_at", 0.0)
	claim.metadata = data.get("metadata", {})
	
	# Generate ID if not set
	if claim.claim_id == "":
		claim.claim_id = claim.generate_claim_id()
	
	return claim
