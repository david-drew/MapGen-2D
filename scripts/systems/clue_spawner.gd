extends RefCounted
class_name ClueSpawner

## ClueSpawner - Phase 3: Dynamic Mid-Game Clue Spawning
## Spawns clues during gameplay in response to events
## Used by ClueManager for procedural clue generation

# ============================================================================
# EVENT-BASED SPAWNING
# ============================================================================

static func spawn_clue_from_event(event_id: String, context: Dictionary, clue_template_id: String = "") -> ClueData:
	"""
	Spawn a clue dynamically from a game event
	
	event_id: What triggered the spawn (e.g., "npc_dies", "door_opened")
	context: Event details {
		"npc_id": "npc_merchant_01",
		"region": "town",
		"building_type": "general_store",
		"time_window": "night"
	}
	clue_template_id: Optional specific clue to spawn
	
	Returns: ClueData or null if spawn failed
	"""
	
	var clue: ClueData = null
	
	# If specific template requested, use it
	if clue_template_id != "":
		clue = _spawn_from_template(clue_template_id, context)
	else:
		# Generate procedural clue based on event
		clue = _generate_procedural_clue(event_id, context)
	
	if not clue:
		return null
	
	# Spawn through ClueManager
	var spawned = ClueManager.spawn_clue_from_template(clue.clue_id, {
		"region": context.get("region", ""),
		"placement": context.get("placement", "exterior"),
		"building_type": context.get("building_type", "")
	})
	
	if spawned:
		ClueManager.make_clue_discoverable(clue.clue_id)
		print("ClueSpawner: Spawned clue '%s' from event '%s'" % [clue.clue_id, event_id])
	
	return clue


static func _spawn_from_template(template_id: String, context: Dictionary) -> ClueData:
	"""Spawn a clue from an existing template with context overrides"""
	
	var template = ClueManager.get_clue_template(template_id)
	if not template:
		push_warning("ClueSpawner: Template not found: %s" % template_id)
		return null
	
	# Create instance with modified spawn location
	var clue_dict = template.to_dict()
	
	# Override spawn location from context
	if context.has("region"):
		clue_dict["spawns_in"]["region"] = context.region
	if context.has("building_type"):
		clue_dict["spawns_in"]["building_type"] = context.building_type
	if context.has("placement"):
		clue_dict["spawns_in"]["placement"] = context.placement
	
	return ClueData.from_dict(clue_dict)


static func _generate_procedural_clue(event_id: String, context: Dictionary) -> ClueData:
	"""Generate a new clue procedurally based on event type"""
	
	# This is a simplified version - you can expand with more complex generation
	var clue = ClueData.new()
	
	# Generate ID
	clue.clue_id = "clue_generated_%s_%d" % [event_id, Time.get_ticks_msec()]
	
	# Set properties based on event type
	match event_id:
		"npc_dies":
			clue.title = "Evidence of Struggle"
			clue.flavor_text = "Signs of a violent confrontation. The area shows clear evidence of a struggle."
			clue.modality = "physical"
			clue.tags = ["evidence", "violence", "generated"]
		
		"door_forced":
			clue.title = "Forced Entry Marks"
			clue.flavor_text = "Deep scratches around the lock mechanism. Someone broke in here recently."
			clue.modality = "physical"
			clue.tags = ["evidence", "break_in", "generated"]
		
		"ritual_interrupted":
			clue.title = "Interrupted Ritual"
			clue.flavor_text = "A half-drawn circle of salt and candles, hastily abandoned."
			clue.modality = "physical"
			clue.supernatural_flag = "occult_sign"
			clue.tags = ["evidence", "ritual", "occult", "generated"]
		
		_:
			# Generic procedural clue
			clue.title = "Suspicious Evidence"
			clue.flavor_text = "Something here doesn't seem right."
			clue.modality = "environmental"
			clue.tags = ["evidence", "generated"]
	
	# Set spawn location from context
	clue.spawn_region = context.get("region", "")
	clue.spawn_building_type = context.get("building_type", "")
	clue.spawn_placement = context.get("placement", "exterior")
	
	return clue

# ============================================================================
# ESSENTIAL CLUE RELOCATION
# ============================================================================

static func relocate_essential_clue(clue_id: String, reason: String, world_state: Dictionary) -> bool:
	"""
	Relocate an essential clue to a new location
	Used when the original holder dies or location becomes inaccessible
	
	reason: Why relocation is needed ("npc_death", "location_destroyed", etc.)
	world_state: Current game state for finding appropriate new location
	
	Returns: true if successfully relocated
	"""
	
	var clue = ClueManager._active_clues.get(clue_id, null)
	if not clue:
		push_warning("ClueSpawner: Cannot relocate clue, not found: %s" % clue_id)
		return false
	
	if not clue.is_essential:
		print("ClueSpawner: Clue '%s' is not essential, skipping relocation" % clue_id)
		return false
	
	# Find new location
	var new_location = find_fallback_location(clue, reason, world_state)
	
	if new_location.is_empty():
		push_error("ClueSpawner: Could not find fallback location for essential clue: %s" % clue_id)
		return false
	
	# Relocate through ClueManager
	var success = ClueManager.relocate_clue(clue_id, new_location)
	
	if success:
		print("ClueSpawner: Relocated essential clue '%s' due to %s" % [clue_id, reason])
	
	return success


static func find_fallback_location(clue: ClueData, reason: String, world_state: Dictionary) -> Dictionary:
	"""
	Find an appropriate new location for a clue
	Uses smart logic based on clue type and current game state
	"""
	
	var new_location = {}
	
	match reason:
		"npc_death":
			# Find another NPC or make it a physical clue at that location
			new_location = _find_npc_death_fallback(clue, world_state)
		
		"location_destroyed":
			# Move to nearby location
			new_location = _find_nearby_location(clue, world_state)
		
		"time_expired":
			# Move to a different time-accessible location
			new_location = _find_time_accessible_location(clue, world_state)
		
		_:
			# Generic: just drop it in the same region as exterior clue
			new_location = {
				"region": clue.spawn_region,
				"placement": "exterior"
			}
	
	return new_location


static func _find_npc_death_fallback(clue: ClueData, world_state: Dictionary) -> Dictionary:
	"""Find new location when NPC holder dies"""
	
	# Strategy 1: Transfer to another NPC in same pool
	if clue.npc_holder_pool != "":
		var entity_mgr = EntityPoolManager.get_instance()
		var pool_npcs = entity_mgr.get_npcs_in_pool(clue.npc_holder_pool)
		
		# Find an NPC that's not the dead one
		for npc in pool_npcs:
			if npc.entity_id != clue.npc_holder_id:
				return {
					"region": clue.spawn_region,
					"placement": "interior",
					"building_type": clue.spawn_building_type,
					"npc_holder_id": npc.entity_id
				}
	
	# Strategy 2: Make it a physical clue at the death location
	return {
		"region": clue.spawn_region,
		"placement": "exterior",
		"building_type": ""
	}


static func _find_nearby_location(clue: ClueData, world_state: Dictionary) -> Dictionary:
	"""Find a nearby location when current location is destroyed"""
	
	# Simple: move to exterior of same region
	return {
		"region": clue.spawn_region,
		"placement": "exterior"
	}


static func _find_time_accessible_location(clue: ClueData, world_state: Dictionary) -> Dictionary:
	"""Find location accessible at different time"""
	
	# Keep same location, just remove time restrictions
	return {
		"region": clue.spawn_region,
		"placement": clue.spawn_placement,
		"building_type": clue.spawn_building_type
	}

# ============================================================================
# BATCH SPAWNING
# ============================================================================

static func spawn_clue_batch(clue_ids: Array[String], context: Dictionary) -> Array[ClueData]:
	"""
	Spawn multiple clues at once
	Useful for story events that reveal multiple pieces of evidence
	"""
	
	var spawned_clues: Array[ClueData] = []
	
	for clue_id in clue_ids:
		var clue = spawn_clue_from_event("batch_spawn", context, clue_id)
		if clue:
			spawned_clues.append(clue)
	
	print("ClueSpawner: Batch spawned %d clues" % spawned_clues.size())
	
	return spawned_clues

# ============================================================================
# CONDITIONAL SPAWNING
# ============================================================================

static func spawn_if_conditions_met(clue_id: String, conditions: Dictionary, context: Dictionary) -> ClueData:
	"""
	Spawn a clue only if certain conditions are met
	
	conditions: {
		"min_discovered_clues": 3,
		"required_tags": ["ritual_components"],
		"min_confidence": {"tag:presence_at_scene": 0.7},
		"gates_open": ["gate_identify_culprit"]
	}
	"""
	
	# Check discovered clue count
	if conditions.has("min_discovered_clues"):
		if ClueManager.get_discovery_count() < conditions.min_discovered_clues:
			return null
	
	# Check required tags
	if conditions.has("required_tags"):
		for tag in conditions.required_tags:
			var clues = ClueManager.get_clues_by_tag(tag, true)
			if clues.is_empty():
				return null
	
	# Check confidence thresholds
	if conditions.has("min_confidence"):
		for tag in conditions.min_confidence.keys():
			var required = conditions.min_confidence[tag]
			var actual = EvidenceGraph.get_tag_confidence(tag)
			if actual < required:
				return null
	
	# Check open gates
	if conditions.has("gates_open"):
		for gate_id in conditions.gates_open:
			if not ProofGateManager.is_gate_open(gate_id):
				return null
	
	# All conditions met - spawn the clue
	return spawn_clue_from_event("conditional_spawn", context, clue_id)

# ============================================================================
# HELPERS
# ============================================================================

static func can_spawn_in_region(region_id: String) -> bool:
	"""Check if a region exists and can have clues"""
	# This would check your world state
	# For now, basic check
	return region_id != ""


static func get_spawn_candidates(context: Dictionary) -> Array[String]:
	"""
	Get list of clue template IDs that could spawn in this context
	Useful for procedural selection
	"""
	
	var candidates: Array[String] = []
	var all_templates = ClueManager._clue_templates
	
	for clue_id in all_templates.keys():
		var template = all_templates[clue_id]
		
		# Check if spawn location matches context
		if context.has("region") and template.spawn_region != context.region:
			continue
		
		if context.has("building_type") and template.spawn_building_type != "" and template.spawn_building_type != context.building_type:
			continue
		
		# Check if not already spawned
		if ClueManager._active_clues.has(clue_id):
			continue
		
		candidates.append(clue_id)
	
	return candidates
