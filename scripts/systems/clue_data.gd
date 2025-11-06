extends RefCounted
class_name ClueData

## ClueData - Phase 1: Core Discovery & Logging
## Represents a discoverable piece of evidence in the mystery system
## Phase 1: Basic discovery, no claims/confidence yet

# ============================================================================
# CORE IDENTIFICATION
# ============================================================================

var clue_id: String = ""  # Unique identifier (e.g., "clue_ledger_night_sales")
var title: String = "Unknown Clue"  # Display name for journal
var flavor_text: String = ""  # Description shown to player

# ============================================================================
# CLUE PROPERTIES
# ============================================================================

## Modality - How the clue manifests
## "physical" = tangible object (blood stain, document)
## "document" = readable text (ledger, letter, newspaper)
## "testimonial" = NPC dialogue/memory
## "environmental" = location-based (draft, scorch marks, sounds)
## "digital" = electronic data (Phase 2+)
## "occult" = supernatural phenomenon (Phase 2+)
## "meta" = player observation/deduction (Phase 2+)
var modality: String = "physical"

## Reliability - How trustworthy the clue is
## "reliable" = factual, accurate
## "unreliable" = questionable source
## "forged" = intentionally misleading
## "ambiguous" = unclear or contested
var reliability: String = "reliable"

## Supernatural classification (for future use)
## "mundane" = normal evidence
## "occult_sign" = supernatural marking
## "paranormal_event" = ghostly phenomenon
## "glamour" = magically disguised
var supernatural_flag: String = "mundane"

# ============================================================================
# SPAWN LOCATION
# ============================================================================

## Where this clue spawns in the world
var spawn_region: String = ""  # Which region (e.g., "town", "outskirts")
var spawn_placement: String = "interior"  # "interior", "exterior", "path"
var spawn_building_type: String = ""  # Specific building (e.g., "general_store", "tavern")

## Optional: NPC holder (for testimonial clues or items NPCs carry)
## If set, clue is "held" by an NPC and discovered through interaction
var npc_holder_id: String = ""  # Specific NPC entity_id
var npc_holder_pool: String = ""  # Or any NPC from pool
var npc_holder_archetype: String = ""  # Or specific archetype in pool

# ============================================================================
# DISCOVERY STATE (Runtime - managed by ClueManager)
# ============================================================================

## Lifecycle: hidden → seeded → placed → discoverable → observed
var state: String = "hidden"  # Current state in lifecycle
var is_essential: bool = false  # If true, must be discoverable (fallback logic)
var discovered_by_player: bool = false  # Has player found this?
var discovery_timestamp: float = 0.0  # Game time when discovered

# ============================================================================
# TAGS & METADATA
# ============================================================================

## Tags for filtering and quest logic
## Examples: ["evidence", "accounting", "presence_at_scene", "story_critical"]
var tags: Array[String] = []

## Custom data for special behaviors
var metadata: Dictionary = {}

# ============================================================================
# VISUAL REPRESENTATION (Phase 1 - Basic)
# ============================================================================

## For physical clues that appear as world objects
var world_sprite: String = ""  # Sprite path if clue has visual representation
var highlight_color: Color = Color.YELLOW  # Color for discovery highlight
var interaction_prompt: String = "Examine"  # What shows on interact

# ============================================================================
# JOURNAL DISPLAY
# ============================================================================

## How clue appears in player journal
var journal_group: String = "evidence"  # Category in journal (e.g., "documents", "testimony")
var mask_title_until_observed: bool = false  # Show "???" until discovered
var journal_icon: String = ""  # Icon path for journal entry

# PHASE 2: Claims & Evidence
var claims: Array = []  # Array of ClaimData objects (parsed from JSON)
var supports_tags: Array[String] = []  # Tags this clue supports (e.g., ["tag:presence_at_scene"])
var refutes_claims: Array[String] = []  # Claim IDs this clue contradicts

# PHASE 2: Leads
var leads: Array = []  # Array of LeadData objects (parsed from JSON)

# PHASE 2: Corroboration
var corroboration_bonus: float = 0.15  # How much this clue boosts confidence when corroborating

# ============================================================================
# METHODS
# ============================================================================

func _init():
	"""Initialize with defaults"""
	pass

func has_tag(tag: String) -> bool:
	"""Check if clue has a specific tag"""
	return tag in tags

func add_tag(tag: String) -> void:
	"""Add a tag if not already present"""
	if not has_tag(tag):
		tags.append(tag)


func remove_tag(tag: String) -> void:
	"""Remove a tag"""
	tags.erase(tag)


func is_held_by_npc() -> bool:
	"""Check if this clue is held by an NPC"""
	return npc_holder_id != "" or npc_holder_pool != ""


func is_discoverable() -> bool:
	"""Check if clue can currently be discovered"""
	return state == "discoverable" or state == "placed"


func mark_discovered(game_time: float = 0.0) -> void:
	"""Mark clue as discovered by player"""
	discovered_by_player = true
	state = "observed"
	discovery_timestamp = game_time


func get_display_title() -> String:
	"""Get title for display (masked if needed)"""
	if mask_title_until_observed and not discovered_by_player:
		return "???"
	return title


func get_summary() -> String:
	"""Get human-readable summary"""
	var holder_info = ""
	if is_held_by_npc():
		holder_info = " [held by NPC]"
	
	var phase2_info = ""
	if has_claims():
		phase2_info += " [%d claims]" % get_claim_count()
	if has_leads():
		phase2_info += " [%d leads]" % get_lead_count()
	
	return "[CLUE:%s] %s (%s) - %s%s%s" % [
		modality,
		title,
		clue_id,
		state,
		holder_info,
		phase2_info
	]


func has_claims() -> bool:
	"""Check if this clue makes any claims (Phase 2)"""
	return not claims.is_empty()


func has_leads() -> bool:
	"""Check if this clue spawns any leads (Phase 2)"""
	return not leads.is_empty()


func get_claim_count() -> int:
	"""Get number of claims this clue makes"""
	return claims.size()


func get_lead_count() -> int:
	"""Get number of leads this clue spawns"""
	return leads.size()

# ============================================================================
# SERIALIZATION
# ============================================================================

func to_dict() -> Dictionary:
	# Phase 2 fields
	var claims_serialized = []
	for claim in claims:
		if claim is ClaimData:
			claims_serialized.append(claim.to_dict())
		else:
			claims_serialized.append(claim)  # Already a dict

	var leads_serialized = []
	for lead in leads:
		if lead is LeadData:
			leads_serialized.append(lead.to_dict())
		else:
			leads_serialized.append(lead)
	
	"""Convert to dictionary for saving"""
	return {
		"clue_id": clue_id,
		"title": title,
		"flavor_text": flavor_text,
		"modality": modality,
		"reliability": reliability,
		"supernatural_flag": supernatural_flag,
		
		# Spawn location
		"spawn_region": spawn_region,
		"spawn_placement": spawn_placement,
		"spawn_building_type": spawn_building_type,
		"npc_holder_id": npc_holder_id,
		"npc_holder_pool": npc_holder_pool,
		"npc_holder_archetype": npc_holder_archetype,
		
		# State
		"state": state,
		"is_essential": is_essential,
		"discovered_by_player": discovered_by_player,
		"discovery_timestamp": discovery_timestamp,
		
		# Tags & metadata
		"tags": tags,
		"metadata": metadata,
		
		# Visual
		"world_sprite": world_sprite,
		"highlight_color": [highlight_color.r, highlight_color.g, highlight_color.b, highlight_color.a],
		"interaction_prompt": interaction_prompt,
		
		# Journal
		"journal_group": journal_group,
		"mask_title_until_observed": mask_title_until_observed,
		"journal_icon": journal_icon,
		
		# Phase 2
		"claims": claims_serialized,
		"supports_tags": supports_tags,
		"refutes_claims": refutes_claims,
		"leads": leads_serialized,
		"corroboration_bonus": corroboration_bonus
	}


static func from_dict(data: Dictionary) -> ClueData:
	"""Create ClueData from dictionary"""
	var clue = ClueData.new()
	
	# Core
	clue.clue_id = data.get("id", "")
	clue.title = data.get("title", "Unknown Clue")
	clue.flavor_text = data.get("flavor_text", "")
	clue.modality = data.get("modality", "physical")
	clue.reliability = data.get("reliability", "reliable")
	clue.supernatural_flag = data.get("supernatural_flag", "mundane")
	
	# Spawn location (from spawns_in object in JSON)
	var spawns_in = data.get("spawns_in", {})
	if not spawns_in.is_empty():
		clue.spawn_region = spawns_in.get("region", "")
		clue.spawn_placement = spawns_in.get("placement", "interior")
		clue.spawn_building_type = spawns_in.get("building_type", "")
		
		# NPC holder
		var npc_holder = spawns_in.get("npc_holder", {})
		if not npc_holder.is_empty():
			clue.npc_holder_id = npc_holder.get("entity_id", "")
			clue.npc_holder_pool = npc_holder.get("pool", "")
			clue.npc_holder_archetype = npc_holder.get("archetype", "")
	
	# Also support flat format for compatibility
	clue.spawn_region = data.get("spawn_region", clue.spawn_region)
	clue.spawn_placement = data.get("spawn_placement", clue.spawn_placement)
	clue.spawn_building_type = data.get("spawn_building_type", clue.spawn_building_type)
	
	# State
	clue.state = data.get("state", "hidden")
	clue.is_essential = data.get("is_essential", false)
	clue.discovered_by_player = data.get("discovered_by_player", false)
	clue.discovery_timestamp = data.get("discovery_timestamp", 0.0)
	
	# Tags
	var tags_data = data.get("tags", [])
	for tag in tags_data:
		clue.tags.append(str(tag))
	
	# Metadata
	clue.metadata = data.get("metadata", {})
	
	# Visual
	clue.world_sprite = data.get("world_sprite", "")
	clue.interaction_prompt = data.get("interaction_prompt", "Examine")
	
	# Color
	var color_data = data.get("highlight_color", [1.0, 1.0, 0.0, 1.0])
	if color_data is Array and color_data.size() >= 3:
		clue.highlight_color = Color(
			color_data[0], 
			color_data[1], 
			color_data[2], 
			color_data[3] if color_data.size() > 3 else 1.0
		)
	
	# Journal
	var journal = data.get("journal", {})
	if not journal.is_empty():
		clue.journal_group = journal.get("group", "evidence")
		clue.mask_title_until_observed = journal.get("mask_title_until_observed", false)
		clue.journal_icon = journal.get("icon", "")
	
	clue.journal_group = data.get("journal_group", clue.journal_group)
	clue.mask_title_until_observed = data.get("mask_title_until_observed", clue.mask_title_until_observed)
	clue.journal_icon = data.get("journal_icon", clue.journal_icon)
	
	# Phase 2: Claims
	var claims_data = data.get("claims", [])
	for claim_dict in claims_data:
		# Store as dict for now, will be converted to ClaimData by EvidenceGraph
		clue.claims.append(claim_dict)

	# Phase 2: Support/Refute
	var supports = data.get("supports", [])
	for tag in supports:
		clue.supports_tags.append(str(tag))

	var refutes = data.get("refutes", [])
	for claim_id in refutes:
		clue.refutes_claims.append(str(claim_id))

	# Phase 2: Leads
	var leads_data = data.get("leads", [])
	for lead_dict in leads_data:
		# Store as dict for now, will be converted to LeadData by ClueManager
		clue.leads.append(lead_dict)

	clue.corroboration_bonus = data.get("corroboration_bonus", 0.15)
	
	return clue
