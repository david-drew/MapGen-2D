extends Node
#class_name ClueManager

## ClueManager - Phase 1: Core Discovery & State Management
## Autoload singleton that manages all clues in the game world
## Handles: spawning, state tracking, discovery, journal integration
## 
## SETUP: Add to Project Settings -> Autoload as "ClueManager"
## USAGE: ClueManager.discover_clue("clue_id") - no get_instance() needed

# ============================================================================
# CLUE STORAGE
# ============================================================================

## All clues in the game (templates loaded from JSON)
var _clue_templates: Dictionary = {}  # clue_id -> ClueData

## Active clues in the world (placed/spawnable)
var _active_clues: Dictionary = {}  # clue_id -> ClueData

## Discovered clues (player has found)
var _discovered_clues: Array[String] = []  # Array of clue_ids

## Clues by location (for quick lookup)
var _clues_by_region: Dictionary = {}  # region_id -> Array[clue_id]
var _clues_by_building: Dictionary = {}  # building_type -> Array[clue_id]
var _clues_by_npc: Dictionary = {}  # npc_id -> Array[clue_id]

# ============================================================================
# GAME STATE
# ============================================================================

var _current_game_time: float = 0.0  # For discovery timestamps
var _clue_discovery_order: Array[String] = []  # Order clues were discovered

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when a clue is placed in the world
signal clue_placed(clue_id: String, region: String, placement: String, building_type: String)

## Emitted when a clue becomes discoverable (gates passed)
signal clue_discoverable(clue_id: String)

## Emitted when player discovers a clue
signal clue_observed(clue_id: String, clue_data: ClueData)

## Emitted when clue needs to be relocated (NPC dies, etc.)
signal clue_needs_relocation(clue_id: String, reason: String)

## Signal for lead spawning
signal lead_spawned(lead: LeadData)
signal lead_revealed(lead_id: String, lead: LeadData)
signal lead_resolved(lead_id: String)

# ============================================================================
# PHASE 2: LEAD SPAWNING
# ============================================================================

## Storage for spawned leads
var _active_leads: Dictionary = {}  # lead_id -> LeadData
var _leads_by_clue: Dictionary = {}  # clue_id -> Array[lead_id]
var _revealed_leads: Array[String] = []  # lead_ids shown to player


# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	"""Initialize manager"""
	pass


func clear_all_data() -> void:
	"""Reset all clue data (for new game)"""

	_clue_templates.clear()
	_active_clues.clear()
	_discovered_clues.clear()
	_clues_by_region.clear()
	_clues_by_building.clear()
	_clues_by_npc.clear()
	_clue_discovery_order.clear()
	_current_game_time = 0.0

	print("ClueManager: All Phase 1 data cleared")
	
	# Clear Phase 2 data
	_active_leads.clear()
	_leads_by_clue.clear()
	_revealed_leads.clear()
	
	# Clear evidence graph
	EvidenceGraph.clear_all_data()
	
	print("ClueManager: All Phase 2 data cleared")

# ============================================================================
# TEMPLATE LOADING (from story.json or clues.json)
# ============================================================================

func load_clue_templates(clues_data: Array) -> int:
	"""Load clue templates from JSON array"""
	var loaded_count = 0
	
	#print("DEBUG: load_clue_templates called with %d items" % clues_data.size())
	
	for clue_dict in clues_data:
		#print("DEBUG: Processing clue dict: ", clue_dict.get("id", "NO_ID"))
		#print("DEBUG: Keys in dict: ", clue_dict.keys())
		
		var clue = ClueData.from_dict(clue_dict)
		
		if clue.clue_id == "":
			push_warning("ClueManager: Skipping clue with empty ID")
			#print("DEBUG: Clue had empty ID after from_dict!")
			continue
		
		_clue_templates[clue.clue_id] = clue
		loaded_count += 1
		
		print("  ✓ Loaded clue template: [%s] %s" % [clue.modality, clue.title])
	
	print("ClueManager: Loaded %d clue templates" % loaded_count)
	return loaded_count


func get_clue_template(clue_id: String) -> ClueData:
	"""Get a clue template by ID"""
	return _clue_templates.get(clue_id, null)


func has_clue_template(clue_id: String) -> bool:
	"""Check if a clue template exists"""
	return clue_id in _clue_templates

# ============================================================================
# CLUE SPAWNING (World Generation)
# ============================================================================

func spawn_clue_from_template(clue_id: String, override_spawn: Dictionary = {}) -> ClueData:
	"""
	Spawn a clue instance from a template.
	override_spawn can customize spawn location:
	  {"region": "town", "placement": "interior", "building_type": "tavern"}
	"""
	
	var template = get_clue_template(clue_id)
	if not template:
		push_error("ClueManager: Cannot spawn clue, template not found: %s" % clue_id)
		return null
	
	# Create instance from template
	var clue = ClueData.from_dict(template.to_dict())
	
	# Apply spawn overrides
	if not override_spawn.is_empty():
		clue.spawn_region = override_spawn.get("region", clue.spawn_region)
		clue.spawn_placement = override_spawn.get("placement", clue.spawn_placement)
		clue.spawn_building_type = override_spawn.get("building_type", clue.spawn_building_type)
		
		var npc_holder = override_spawn.get("npc_holder", {})
		if not npc_holder.is_empty():
			clue.npc_holder_id = npc_holder.get("entity_id", clue.npc_holder_id)
			clue.npc_holder_pool = npc_holder.get("pool", clue.npc_holder_pool)
			clue.npc_holder_archetype = npc_holder.get("archetype", clue.npc_holder_archetype)
	
	# Set initial state
	clue.state = "placed"
	
	# Register as active
	_active_clues[clue.clue_id] = clue
	
	# Index by location
	_index_clue_by_location(clue)
	
	# Emit signal
	clue_placed.emit(clue.clue_id, clue.spawn_region, clue.spawn_placement, clue.spawn_building_type)
	
	print("ClueManager: Spawned clue [%s] %s in %s/%s" % [
		clue.modality,
		clue.title,
		clue.spawn_region,
		clue.spawn_building_type if clue.spawn_building_type else clue.spawn_placement
	])
	
	return clue


func _index_clue_by_location(clue: ClueData) -> void:
	"""Add clue to location indexes"""
	
	# Index by region
	if clue.spawn_region != "":
		if not _clues_by_region.has(clue.spawn_region):
			_clues_by_region[clue.spawn_region] = []
		_clues_by_region[clue.spawn_region].append(clue.clue_id)
	
	# Index by building type
	if clue.spawn_building_type != "":
		if not _clues_by_building.has(clue.spawn_building_type):
			_clues_by_building[clue.spawn_building_type] = []
		_clues_by_building[clue.spawn_building_type].append(clue.clue_id)
	
	# Index by NPC holder
	if clue.npc_holder_id != "":
		if not _clues_by_npc.has(clue.npc_holder_id):
			_clues_by_npc[clue.npc_holder_id] = []
		_clues_by_npc[clue.npc_holder_id].append(clue.clue_id)


func make_clue_discoverable(clue_id: String) -> bool:
	"""
	Mark a clue as discoverable (e.g., after passing gates).
	In Phase 1, this is automatic. Phase 2+ will check skill/item gates.
	"""
	var clue = _active_clues.get(clue_id, null)
	if not clue:
		push_warning("ClueManager: Cannot make discoverable, clue not active: %s" % clue_id)
		return false
	
	if clue.state == "placed":
		clue.state = "discoverable"
		clue_discoverable.emit(clue_id)
		return true
	
	return false

# ============================================================================
# CLUE DISCOVERY (Player Interaction)
# ============================================================================

func discover_clue(clue_id: String, game_time: float = 0.0) -> bool:
	"""
	Player discovers a clue. Returns true if successful.
	This should be called when player interacts with clue location/NPC.
	"""
	var clue = _active_clues.get(clue_id, null)
	if not clue:
		push_warning("ClueManager: Cannot discover clue, not active: %s" % clue_id)
		return false
	
	# Check if already discovered
	if clue.discovered_by_player:
		push_warning("ClueManager: Clue already discovered: %s" % clue_id)
		return false
	
	# Check if discoverable
	if not clue.is_discoverable():
		push_warning("ClueManager: Clue not yet discoverable (state: %s): %s" % [clue.state, clue_id])
		return false
	
	# Mark as discovered
	clue.mark_discovered(game_time if game_time > 0.0 else _current_game_time)
	_discovered_clues.append(clue_id)
	_clue_discovery_order.append(clue_id)
	
	# Emit signal for journal/UI updates
	clue_observed.emit(clue_id, clue)
	
	print("ClueManager: Clue discovered! [%s] %s" % [clue.modality, clue.title])
	
	# Phase 2+: This is where we'd spawn leads
	
	return true


func is_clue_discovered(clue_id: String) -> bool:
	"""Check if player has discovered a clue"""
	return clue_id in _discovered_clues


func get_discovered_clues() -> Array[ClueData]:
	"""Get all clues the player has discovered"""
	var clues: Array[ClueData] = []
	for clue_id in _discovered_clues:
		var clue = _active_clues.get(clue_id, null)
		if clue:
			clues.append(clue)
	return clues


func get_discovery_count() -> int:
	"""Get total number of discovered clues"""
	return _discovered_clues.size()

# ============================================================================
# CLUE QUERIES (Location-based)
# ============================================================================

func get_clues_in_region(region_id: String, include_discovered: bool = true) -> Array[ClueData]:
	"""Get all clues in a specific region"""
	var clues: Array[ClueData] = []
	var clue_ids = _clues_by_region.get(region_id, [])
	
	for clue_id in clue_ids:
		var clue = _active_clues.get(clue_id, null)
		if clue and (include_discovered or not clue.discovered_by_player):
			clues.append(clue)
	
	return clues


func get_clues_in_building(building_type: String, include_discovered: bool = true) -> Array[ClueData]:
	"""Get all clues in a specific building type"""
	var clues: Array[ClueData] = []
	var clue_ids = _clues_by_building.get(building_type, [])
	
	for clue_id in clue_ids:
		var clue = _active_clues.get(clue_id, null)
		if clue and (include_discovered or not clue.discovered_by_player):
			clues.append(clue)
	
	return clues


func get_clues_held_by_npc(npc_id: String, include_discovered: bool = true) -> Array[ClueData]:
	"""Get all clues held by a specific NPC"""
	var clues: Array[ClueData] = []
	var clue_ids = _clues_by_npc.get(npc_id, [])
	
	for clue_id in clue_ids:
		var clue = _active_clues.get(clue_id, null)
		if clue and (include_discovered or not clue.discovered_by_player):
			clues.append(clue)
	
	return clues


func get_clues_by_tag(tag: String, include_discovered: bool = true) -> Array[ClueData]:
	"""Get all clues with a specific tag"""
	var clues: Array[ClueData] = []
	
	for clue in _active_clues.values():
		if clue.has_tag(tag) and (include_discovered or not clue.discovered_by_player):
			clues.append(clue)
	
	return clues

# ============================================================================
# MID-GAME CLUE MANAGEMENT (Phase 1 basics, full in Phase 3)
# ============================================================================

func relocate_clue(clue_id: String, new_location: Dictionary) -> bool:
	"""
	Move a clue to a new location (e.g., NPC dies, clue transfers).
	new_location format: {"region": "town", "npc_holder_id": "npc_guard_02"}
	"""
	var clue = _active_clues.get(clue_id, null)
	if not clue:
		push_warning("ClueManager: Cannot relocate clue, not active: %s" % clue_id)
		return false
	
	# Remove from old indexes
	_remove_clue_from_indexes(clue)
	
	# Update location
	if new_location.has("region"):
		clue.spawn_region = new_location.region
	if new_location.has("placement"):
		clue.spawn_placement = new_location.placement
	if new_location.has("building_type"):
		clue.spawn_building_type = new_location.building_type
	if new_location.has("npc_holder_id"):
		clue.npc_holder_id = new_location.npc_holder_id
	
	# Re-index
	_index_clue_by_location(clue)
	
	print("ClueManager: Relocated clue %s to new location" % clue_id)
	clue_placed.emit(clue.clue_id, clue.spawn_region, clue.spawn_placement, clue.spawn_building_type)
	
	return true


func _remove_clue_from_indexes(clue: ClueData) -> void:
	"""Remove clue from all location indexes"""
	
	# Remove from region index
	if clue.spawn_region in _clues_by_region:
		_clues_by_region[clue.spawn_region].erase(clue.clue_id)
	
	# Remove from building index
	if clue.spawn_building_type in _clues_by_building:
		_clues_by_building[clue.spawn_building_type].erase(clue.clue_id)
	
	# Remove from NPC index
	if clue.npc_holder_id in _clues_by_npc:
		_clues_by_npc[clue.npc_holder_id].erase(clue.clue_id)


func handle_npc_death(npc_id: String) -> void:
	"""
	Handle clues when an NPC dies.
	Essential clues will be relocated, others may be lost.
	"""
	var npc_clues = get_clues_held_by_npc(npc_id, false)  # Only undiscovered
	
	for clue in npc_clues:
		if clue.is_essential:
			# Relocate essential clues (Phase 3 will have smarter logic)
			print("ClueManager: Essential clue needs relocation after NPC death: %s" % clue.clue_id)
			clue_needs_relocation.emit(clue.clue_id, "npc_death")
			
			# For now, just drop it at the NPC's location
			clue.npc_holder_id = ""
			clue.spawn_placement = "exterior"
			_remove_clue_from_indexes(clue)
			_index_clue_by_location(clue)
		else:
			print("ClueManager: Non-essential clue lost with NPC: %s" % clue.clue_id)

# ============================================================================
# TIME MANAGEMENT
# ============================================================================

func update_game_time(new_time: float) -> void:
	"""Update current game time (for discovery timestamps)"""
	_current_game_time = new_time


func get_game_time() -> float:
	"""Get current game time"""
	return _current_game_time

func update_player_state(player_state:Dictionary):
	print("[ClueManager] ...pretend we updated player state here...")

# ============================================================================
# DEBUGGING & UTILITIES
# ============================================================================

func get_all_active_clues() -> Array[ClueData]:
	"""Get all active clues in the world"""
	var clues: Array[ClueData] = []
	for clue in _active_clues.values():
		clues.append(clue)
	return clues


func print_clue_summary() -> void:
	"""Print debug summary of all clues"""
	print("\n=== CLUE MANAGER SUMMARY ===")
	print("Templates loaded: %d" % _clue_templates.size())
	print("Active clues: %d" % _active_clues.size())
	print("Discovered: %d" % _discovered_clues.size())
	print("\nActive Clues:")
	for clue in _active_clues.values():
		print("  %s" % clue.get_summary())
	print("===========================\n")


func get_stats() -> Dictionary:
	"""Get statistics about clue system"""
	return {
		"templates_count": _clue_templates.size(),
		"active_count": _active_clues.size(),
		"discovered_count": _discovered_clues.size(),
		"regions_with_clues": _clues_by_region.size(),
		"buildings_with_clues": _clues_by_building.size(),
		"npcs_holding_clues": _clues_by_npc.size()
	}

# ============================================================================
# PHASE 2: CLAIMS PROCESSING
# ============================================================================

func process_clue_claims(clue: ClueData) -> Array[String]:
	"""
	Process all claims from a newly discovered clue
	Adds them to EvidenceGraph and handles corroboration/contradiction
	Returns array of claim_ids
	"""
	if not clue.has_claims():
		return []
	
	var claim_ids: Array[String] = []
	
	# Add claims to evidence graph
	claim_ids = EvidenceGraph.add_claims_from_clue(clue, clue.clue_id)
	
	# Process support/refute relationships
	if not clue.supports_tags.is_empty() or not clue.refutes_claims.is_empty():
		EvidenceGraph.process_claim_relationships(
			clue.clue_id,
			clue.supports_tags,
			clue.refutes_claims
		)
	
	print("ClueManager: Processed %d claims from clue '%s'" % [claim_ids.size(), clue.clue_id])
	
	return claim_ids	



func spawn_leads_from_clue(clue: ClueData) -> Array[LeadData]:
	"""
	Spawn all leads defined in a clue
	Called automatically after clue discovery in Phase 2
	"""
	if not clue.has_leads():
		return []
	
	var spawned_leads: Array[LeadData] = []
	
	for lead_dict in clue.leads:
		var lead: LeadData
		
		# Convert dict to LeadData if needed
		if lead_dict is LeadData:
			lead = lead_dict
		else:
			lead = LeadData.from_dict(lead_dict)
		
		# Set source if not already set
		if lead.source_clue_id == "":
			lead.source_clue_id = clue.clue_id
		
		# Generate ID if needed
		if lead.lead_id == "":
			lead.lead_id = lead.generate_lead_id()
		
		# Store lead
		_active_leads[lead.lead_id] = lead
		
		# Index by source clue
		if not _leads_by_clue.has(clue.clue_id):
			_leads_by_clue[clue.clue_id] = []
		_leads_by_clue[clue.clue_id].append(lead.lead_id)
		
		spawned_leads.append(lead)
		
		# Emit signal
		lead_spawned.emit(lead)
		
		print("ClueManager: Spawned lead '%s' → %s" % [
			lead.lead_id,
			lead.get_target_description()
		])
	
	return spawned_leads


func reveal_lead(lead_id: String, game_time: float = 0.0) -> bool:
	"""Mark a lead as revealed to the player"""
	var lead = _active_leads.get(lead_id, null)
	if not lead:
		return false
	
	if lead.revealed_to_player:
		return false  # Already revealed
	
	lead.mark_revealed(game_time if game_time > 0.0 else _current_game_time)
	_revealed_leads.append(lead_id)
	
	lead_revealed.emit(lead_id, lead)
	
	return true


func resolve_lead(lead_id: String, game_time: float = 0.0) -> bool:
	"""Mark a lead as resolved/followed"""
	var lead = _active_leads.get(lead_id, null)
	if not lead:
		return false
	
	if lead.resolved:
		return false  # Already resolved
	
	lead.mark_resolved(game_time if game_time > 0.0 else _current_game_time)
	
	lead_resolved.emit(lead_id)
	
	print("ClueManager: Lead resolved: %s" % lead_id)
	
	return true


func get_leads_at_location(region: String, building_type: String = "") -> Array[LeadData]:
	"""Get all active leads that point to a specific location"""
	var leads: Array[LeadData] = []
	
	for lead in _active_leads.values():
		if not lead.resolved and lead.matches_location(region, building_type):
			leads.append(lead)
	
	return leads


func get_leads_for_npc(npc_pool: String = "", npc_archetype: String = "") -> Array[LeadData]:
	"""Get all active leads that point to an NPC"""
	var leads: Array[LeadData] = []
	
	for lead in _active_leads.values():
		if not lead.resolved and lead.matches_npc(npc_pool, npc_archetype):
			leads.append(lead)
	
	return leads


func get_all_active_leads(include_resolved: bool = false) -> Array[LeadData]:
	"""Get all leads (optionally include resolved ones)"""
	var leads: Array[LeadData] = []
	
	for lead in _active_leads.values():
		if include_resolved or not lead.resolved:
			leads.append(lead)
	
	return leads


# ============================================================================
# PHASE 2: ENHANCED DISCOVERY
# ============================================================================

func discover_clue_phase2(clue_id: String, game_time: float = 0.0) -> bool:
	"""
	Enhanced discovery that processes claims and spawns leads
	Use this instead of discover_clue() for Phase 2
	"""
	# First, do standard Phase 1 discovery
	var success = discover_clue(clue_id, game_time)
	
	if not success:
		return false
	
	# Get the clue
	var clue = _active_clues.get(clue_id, null)
	if not clue:
		return false
	
	# PHASE 2: Process claims
	if clue.has_claims():
		var claim_ids = process_clue_claims(clue)
		print("  → Added %d claims to evidence graph" % claim_ids.size())
	
	# PHASE 2: Spawn leads
	if clue.has_leads():
		var leads = spawn_leads_from_clue(clue)
		print("  → Spawned %d leads" % leads.size())
		
		# Auto-reveal leads (Phase 1 behavior - Phase 3 might add gates)
		for lead in leads:
			reveal_lead(lead.lead_id, game_time)
	
	return true


# ============================================================================
# PHASE 2: STATISTICS
# ============================================================================

func get_stats_phase2() -> Dictionary:
	"""Get enhanced statistics including Phase 2 features"""
	var base_stats = get_stats()
	
	# Add Phase 2 stats
	base_stats["total_claims"] = 0
	base_stats["total_leads"] = _active_leads.size()
	base_stats["revealed_leads"] = _revealed_leads.size()
	base_stats["resolved_leads"] = 0
	
	# Count claims and resolved leads
	for clue in _active_clues.values():
		if clue.has_claims():
			base_stats.total_claims += clue.get_claim_count()
	
	for lead in _active_leads.values():
		if lead.resolved:
			base_stats.resolved_leads += 1
	
	# Evidence graph stats
	var evidence_stats = EvidenceGraph.get_stats()
	base_stats["evidence_graph"] = evidence_stats
	
	return base_stats


func print_clue_summary_phase2() -> void:
	"""Enhanced summary with Phase 2 info"""
	print("\n=== CLUE MANAGER SUMMARY (Phase 2) ===")
	
	var stats = get_stats_phase2()
	
	print("Templates loaded: %d" % _clue_templates.size())
	print("Active clues: %d" % _active_clues.size())
	print("Discovered: %d" % _discovered_clues.size())
	
	print("\nPhase 2 Features:")
	print("  Total claims: %d" % stats.total_claims)
	print("  Evidence graph: %d claims tracked" % stats.evidence_graph.total_claims)
	print("  Active leads: %d" % stats.total_leads)
	print("  Revealed leads: %d" % stats.revealed_leads)
	print("  Resolved leads: %d" % stats.resolved_leads)
	
	print("\nEvidence Graph:")
	print("  Corroborations: %d" % stats.evidence_graph.corroborations)
	print("  Contradictions: %d" % stats.evidence_graph.contradictions)
	print("  Contested claims: %d" % stats.evidence_graph.contested_claims)
	print("  High confidence claims (≥0.7): %d" % stats.evidence_graph.high_confidence_claims)
	
	print("\nActive Clues:")
	for clue in _active_clues.values():
		var discovered_str = "[✓]" if clue.discovered_by_player else "[ ]"
		var claims_str = " (%d claims)" % clue.get_claim_count() if clue.has_claims() else ""
		var leads_str = " (%d leads)" % clue.get_lead_count() if clue.has_leads() else ""
		print("  %s %s%s%s" % [discovered_str, clue.title, claims_str, leads_str])
	
	print("=========================================\n")
