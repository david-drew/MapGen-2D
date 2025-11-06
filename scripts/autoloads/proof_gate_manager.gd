extends Node
#class_name ProofGateManager

## ProofGateManager - Phase 3: Win Conditions & Story Progression
## Evaluates evidence thresholds and opens gates when requirements are met
## Autoload singleton - register in Project Settings
##
## SETUP: Add to Project Settings -> Autoload as "ProofGateManager"

# ============================================================================
# GATE STORAGE
# ============================================================================

## All proof gates (gate_id -> ProofGateData)
var gates: Dictionary = {}

## Opened gates (gate_id -> timestamp when opened)
var opened_gates: Dictionary = {}

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when a gate opens
signal gate_opened(gate_id: String, gate_data: Dictionary)

## Emitted when gate progress changes (for UI feedback)
signal gate_progress_changed(gate_id: String, progress: float)

## Emitted when checking gates (after each clue discovery)
signal gates_evaluated(opened_count: int, total_count: int)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	"""Initialize manager"""
	pass


func clear_all_data() -> void:
	"""Reset all gate data (for new game)"""
	gates.clear()
	opened_gates.clear()
	print("ProofGateManager: All data cleared")

# ============================================================================
# LOADING GATES
# ============================================================================

func load_proof_gates(gates_data: Array) -> int:
	"""Load proof gate definitions from JSON"""
	var loaded_count = 0
	
	for gate_dict in gates_data:
		var gate_id = gate_dict.get("id", "")
		if gate_id == "":
			push_warning("ProofGateManager: Skipping gate with empty ID")
			continue
		
		gates[gate_id] = gate_dict
		loaded_count += 1
		
		print("  ✓ Loaded proof gate: %s (%s)" % [
			gate_id,
			gate_dict.get("label", "Unnamed Gate")
		])
	
	print("ProofGateManager: Loaded %d proof gates" % loaded_count)
	return loaded_count


func load_proof_gates_from_file(file_path: String) -> int:
	"""Load proof gates from a separate JSON file"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("ProofGateManager: Cannot open file: %s" % file_path)
		return 0
	
	var json_text = file.get_as_text()
	file.close()
	
	var gates_data = JSON.parse_string(json_text)
	
	if gates_data == null or not gates_data is Array:
		push_error("ProofGateManager: Invalid JSON in file: %s" % file_path)
		return 0
	
	return load_proof_gates(gates_data)

# ============================================================================
# GATE EVALUATION
# ============================================================================

func evaluate_all_gates() -> Array[String]:
	"""
	Check all gates and open any that meet requirements
	Returns array of newly opened gate_ids
	"""
	var newly_opened: Array[String] = []
	
	for gate_id in gates.keys():
		if is_gate_open(gate_id):
			continue  # Already open
		
		if check_gate_requirements(gate_id):
			open_gate(gate_id)
			newly_opened.append(gate_id)
	
	gates_evaluated.emit(opened_gates.size(), gates.size())
	
	return newly_opened


func check_gate_requirements(gate_id: String) -> bool:
	"""Check if a specific gate's requirements are met"""
	var gate = gates.get(gate_id, null)
	if not gate:
		return false
	
	var requirements = gate.get("requirements", [])
	
	# All requirements must be satisfied
	for requirement in requirements:
		if not _check_single_requirement(requirement):
			return false
	
	return true


func _check_single_requirement(requirement: Dictionary) -> bool:
	"""Check a single requirement (e.g., tag confidence threshold)"""
	var any_of = requirement.get("any_of", [])
	var min_confidence = requirement.get("min_confidence", 0.0)
	
	# At least one of the tags must meet the confidence threshold
	for tag in any_of:
		var confidence = _get_tag_confidence(tag)
		
		if confidence >= min_confidence:
			return true  # Requirement satisfied
	
	return false  # None of the tags met the threshold


func _get_tag_confidence(tag: String) -> float:
	"""Get confidence for a tag (supports multiple methods)"""
	
	# Method 1: Best confidence among claims with this tag
	var best_confidence = EvidenceGraph.get_tag_best_confidence(tag)
	
	# Method 2: Could use average instead
	# var avg_confidence = EvidenceGraph.get_tag_confidence(tag)
	
	return best_confidence


func get_gate_progress(gate_id: String) -> float:
	"""
	Get progress toward opening a gate (0.0 - 1.0)
	Useful for UI progress bars
	"""
	var gate = gates.get(gate_id, null)
	if not gate:
		return 0.0
	
	if is_gate_open(gate_id):
		return 1.0
	
	var requirements = gate.get("requirements", [])
	if requirements.is_empty():
		return 0.0
	
	var total_progress = 0.0
	
	for requirement in requirements:
		var req_progress = _get_requirement_progress(requirement)
		total_progress += req_progress
	
	return total_progress / requirements.size()


func _get_requirement_progress(requirement: Dictionary) -> float:
	"""Get progress for a single requirement (0.0 - 1.0)"""
	var any_of = requirement.get("any_of", [])
	var min_confidence = requirement.get("min_confidence", 0.0)
	
	if any_of.is_empty() or min_confidence <= 0.0:
		return 0.0
	
	var best_confidence = 0.0
	
	for tag in any_of:
		var confidence = _get_tag_confidence(tag)
		if confidence > best_confidence:
			best_confidence = confidence
	
	return clamp(best_confidence / min_confidence, 0.0, 1.0)

# ============================================================================
# OPENING GATES
# ============================================================================

func open_gate(gate_id: String) -> bool:
	"""Open a gate and trigger its effects"""
	if is_gate_open(gate_id):
		return false  # Already open
	
	var gate = gates.get(gate_id, null)
	if not gate:
		return false
	
	# Mark as opened
	opened_gates[gate_id] = Time.get_ticks_msec() / 1000.0
	
	# Execute on_open actions
	var on_open = gate.get("on_open", [])
	for action in on_open:
		_execute_gate_action(action, gate_id)
	
	# Emit signal
	gate_opened.emit(gate_id, gate)
	
	print("ProofGateManager: Gate opened! [%s] %s" % [
		gate_id,
		gate.get("label", "Unnamed Gate")
	])
	
	return true


func _execute_gate_action(action: String, gate_id: String) -> void:
	"""Execute an action when a gate opens"""
	# Parse action format: "verb:parameter"
	var parts = action.split(":", true, 1)
	if parts.size() < 2:
		push_warning("ProofGateManager: Invalid action format: %s" % action)
		return
	
	var verb = parts[0]
	var parameter = parts[1]
	
	match verb:
		"unlock":
			# Unlock a scene/ending/area
			print("  → Unlocked: %s" % parameter)
			# Your game should listen to gate_opened signal and handle this
		
		"reveal":
			# Reveal information
			print("  → Revealed: %s" % parameter)
		
		"spawn":
			# Spawn something (clue, NPC, event)
			print("  → Spawning: %s" % parameter)
			# Phase 3 ClueSpawner can handle this
		
		"award":
			# Give player something
			print("  → Awarded: %s" % parameter)
		
		"trigger":
			# Trigger an event
			print("  → Triggered event: %s" % parameter)
		
		_:
			push_warning("ProofGateManager: Unknown action verb: %s" % verb)


func is_gate_open(gate_id: String) -> bool:
	"""Check if a gate has been opened"""
	return gate_id in opened_gates


func get_opened_gates() -> Array[String]:
	"""Get list of all opened gate IDs"""
	return opened_gates.keys()

# ============================================================================
# QUERIES
# ============================================================================

func get_gate_info(gate_id: String) -> Dictionary:
	"""Get full info about a gate"""
	return gates.get(gate_id, {})


func get_gate_label(gate_id: String) -> String:
	"""Get human-readable label for a gate"""
	var gate = gates.get(gate_id, {})
	return gate.get("label", gate_id)


func get_all_gates() -> Dictionary:
	"""Get all gate data"""
	return gates.duplicate()


func get_gates_by_category(category: String) -> Array[String]:
	"""Get all gates in a category"""
	var result: Array[String] = []
	
	for gate_id in gates.keys():
		var gate = gates[gate_id]
		if gate.get("category", "") == category:
			result.append(gate_id)
	
	return result

# ============================================================================
# DEBUGGING
# ============================================================================

func print_gate_summary() -> void:
	"""Print debug summary of gates"""
	print("\n=== PROOF GATE SUMMARY ===")
	print("Total gates: %d" % gates.size())
	print("Opened gates: %d" % opened_gates.size())
	
	print("\nGate Status:")
	for gate_id in gates.keys():
		var gate = gates[gate_id]
		var label = gate.get("label", gate_id)
		var progress = get_gate_progress(gate_id)
		var status = "[OPEN]" if is_gate_open(gate_id) else "[LOCKED]"
		
		print("  %s %s (%.0f%%)" % [status, label, progress * 100])
		
		if not is_gate_open(gate_id):
			# Show requirements
			var requirements = gate.get("requirements", [])
			for req in requirements:
				var any_of = req.get("any_of", [])
				var min_conf = req.get("min_confidence", 0.0)
				
				for tag in any_of:
					var current_conf = _get_tag_confidence(tag)
					var needed = min_conf - current_conf
					var status_str = "✓" if current_conf >= min_conf else "✗"
					
					print("    %s %s: %.2f / %.2f (need +%.2f)" % [
						status_str,
						tag,
						current_conf,
						min_conf,
						max(0.0, needed)
					])
	
	print("==========================\n")


func get_stats() -> Dictionary:
	"""Get statistics about proof gates"""
	return {
		"total_gates": gates.size(),
		"opened_gates": opened_gates.size(),
		"locked_gates": gates.size() - opened_gates.size()
	}
