extends RefCounted
class_name ClueGateEvaluator

## ClueGateEvaluator - Phase 3: Discovery Requirements
## Checks if player has required skills, items, or meets time conditions to discover clues
## Used by ClueManager before allowing clue discovery

# ============================================================================
# EVALUATION
# ============================================================================

static func can_discover_clue(clue: ClueData, player_state: Dictionary) -> bool:
	"""
	Check if player can discover a clue based on gates
	player_state format:
	{
		"skills": {"observation": 3, "occult": 2},
		"inventory": ["uv_lamp", "magnifying_glass"],
		"time_window": "night",
		"region": "town",
		"building_type": "tavern"
	}
	"""
	
	# If clue has no gates, it's always discoverable
	if not clue.has("gates") or clue.gates.is_empty():
		return true
	
	var gates = clue.gates
	
	# Check skill requirements
	if gates.has("skill"):
		if not check_skill_gate(gates.skill, player_state.get("skills", {})):
			return false
	
	# Check item requirements
	if gates.has("item"):
		if not check_item_gate(gates.item, player_state.get("inventory", [])):
			return false
	
	# Check time requirements
	if gates.has("time"):
		if not check_time_gate(gates.time, player_state.get("time_window", "")):
			return false
	
	# Check location requirements (optional)
	if gates.has("location"):
		if not check_location_gate(gates.location, player_state):
			return false
	
	# All gates passed
	return true


static func get_missing_requirements(clue: ClueData, player_state: Dictionary) -> Dictionary:
	"""
	Get detailed info about which requirements are missing
	Returns: {
		"can_discover": bool,
		"missing_skills": {"observation": 2},  // skill: required_level
		"missing_items": ["uv_lamp"],
		"wrong_time": "night",  // required time window
		"wrong_location": {...}
	}
	"""
	
	var result = {
		"can_discover": true,
		"missing_skills": {},
		"missing_items": [],
		"wrong_time": "",
		"wrong_location": {}
	}
	
	if not clue.has("gates") or clue.gates.is_empty():
		return result
	
	var gates = clue.gates
	
	# Check skills
	if gates.has("skill"):
		var player_skills = player_state.get("skills", {})
		for skill_name in gates.skill.keys():
			var required_level = gates.skill[skill_name]
			var player_level = player_skills.get(skill_name, 0)
			
			if player_level < required_level:
				result.missing_skills[skill_name] = required_level
				result.can_discover = false
	
	# Check items
	if gates.has("item"):
		var player_inventory = player_state.get("inventory", [])
		for required_item in gates.item:
			if required_item not in player_inventory:
				result.missing_items.append(required_item)
				result.can_discover = false
	
	# Check time
	if gates.has("time"):
		var required_window = gates.time.get("window", "")
		var current_window = player_state.get("time_window", "")
		
		if required_window != "" and required_window != current_window:
			result.wrong_time = required_window
			result.can_discover = false
	
	# Check location
	if gates.has("location"):
		if not check_location_gate(gates.location, player_state):
			result.wrong_location = gates.location
			result.can_discover = false
	
	return result

# ============================================================================
# GATE CHECKERS
# ============================================================================

static func check_skill_gate(required_skills: Dictionary, player_skills: Dictionary) -> bool:
	"""
	Check if player has required skill levels
	required_skills: {"observation": 2, "occult": 1}
	player_skills: {"observation": 3, "occult": 0}
	"""
	
	for skill_name in required_skills.keys():
		var required_level = required_skills[skill_name]
		var player_level = player_skills.get(skill_name, 0)
		
		if player_level < required_level:
			return false
	
	return true


static func check_item_gate(required_items: Array, player_inventory: Array) -> bool:
	"""
	Check if player has all required items
	required_items: ["uv_lamp", "magnifying_glass"]
	player_inventory: ["uv_lamp", "notebook", "magnifying_glass"]
	"""
	
	for required_item in required_items:
		if required_item not in player_inventory:
			return false
	
	return true


static func check_time_gate(time_requirement: Dictionary, current_time_window: String) -> bool:
	"""
	Check if current time matches requirement
	time_requirement: {"window": "night"}
	current_time_window: "night"
	"""
	
	var required_window = time_requirement.get("window", "")
	
	if required_window == "":
		return true  # No time requirement
	
	return required_window == current_time_window


static func check_location_gate(location_requirement: Dictionary, player_state: Dictionary) -> bool:
	"""
	Check if player is in the right location
	location_requirement: {"region": "town", "building_type": "tavern"}
	"""
	
	var required_region = location_requirement.get("region", "")
	var required_building = location_requirement.get("building_type", "")
	
	var player_region = player_state.get("region", "")
	var player_building = player_state.get("building_type", "")
	
	if required_region != "" and required_region != player_region:
		return false
	
	if required_building != "" and required_building != player_building:
		return false
	
	return true

# ============================================================================
# UI HELPERS
# ============================================================================

static func get_requirements_text(clue: ClueData) -> String:
	"""
	Get human-readable description of requirements
	Returns: "Requires: Observation 2, UV Lamp, Night time"
	"""
	
	if not clue.has("gates") or clue.gates.is_empty():
		return ""
	
	var parts: Array[String] = []
	var gates = clue.gates
	
	# Skills
	if gates.has("skill"):
		var skill_parts: Array[String] = []
		for skill_name in gates.skill.keys():
			var level = gates.skill[skill_name]
			skill_parts.append("%s %d" % [skill_name.capitalize(), level])
		
		if not skill_parts.is_empty():
			parts.append("Skills: " + ", ".join(skill_parts))
	
	# Items
	if gates.has("item"):
		var item_parts: Array[String] = []
		for item in gates.item:
			item_parts.append(item.replace("_", " ").capitalize())
		
		if not item_parts.is_empty():
			parts.append("Items: " + ", ".join(item_parts))
	
	# Time
	if gates.has("time"):
		var window = gates.time.get("window", "")
		if window != "":
			parts.append("Time: " + window.capitalize())
	
	if parts.is_empty():
		return ""
	
	return "Requires: " + ", ".join(parts)


static func get_missing_requirements_text(missing: Dictionary) -> String:
	"""
	Get human-readable description of what's missing
	Returns: "Missing: Observation 2, UV Lamp"
	"""
	
	if missing.can_discover:
		return ""
	
	var parts: Array[String] = []
	
	# Missing skills
	if not missing.missing_skills.is_empty():
		var skill_parts: Array[String] = []
		for skill_name in missing.missing_skills.keys():
			var level = missing.missing_skills[skill_name]
			skill_parts.append("%s %d" % [skill_name.capitalize(), level])
		
		parts.append("Skills: " + ", ".join(skill_parts))
	
	# Missing items
	if not missing.missing_items.is_empty():
		var item_parts: Array[String] = []
		for item in missing.missing_items:
			item_parts.append(item.replace("_", " ").capitalize())
		
		parts.append("Items: " + ", ".join(item_parts))
	
	# Wrong time
	if missing.wrong_time != "":
		parts.append("Wait until " + missing.wrong_time)
	
	if parts.is_empty():
		return ""
	
	return "Missing: " + ", ".join(parts)

# ============================================================================
# GATE COMPLEXITY SCORING
# ============================================================================

static func get_gate_complexity_score(clue: ClueData) -> int:
	"""
	Get complexity score for gates (higher = more requirements)
	Useful for difficulty balancing
	"""
	
	if not clue.has("gates") or clue.gates.is_empty():
		return 0
	
	var score = 0
	var gates = clue.gates
	
	# Skills add to complexity
	if gates.has("skill"):
		for level in gates.skill.values():
			score += level
	
	# Each required item adds 1
	if gates.has("item"):
		score += gates.item.size()
	
	# Time restriction adds 1
	if gates.has("time") and gates.time.get("window", "") != "":
		score += 1
	
	# Location restriction adds 1
	if gates.has("location"):
		score += 1
	
	return score
