extends Node
#class_name ClueDecaySystem

## ClueDecaySystem - Phase 3: Time-Limited Evidence
## Manages clues that degrade or disappear over time
## Autoload singleton - register in Project Settings
##
## SETUP: Add to Project Settings -> Autoload as "ClueDecaySystem"

# ============================================================================
# DECAY TRACKING
# ============================================================================

## Clues currently tracked for decay (clue_id -> decay_info)
var _decaying_clues: Dictionary = {}

## Clues that have decayed (clue_id -> decay_timestamp)
var _decayed_clues: Dictionary = {}

# Current game time (seconds)
var _current_game_time: float = 0.0

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when a clue starts decaying
signal clue_decay_started(clue_id: String, time_remaining: float)

## Emitted periodically as clue decays (for UI updates)
signal clue_decaying(clue_id: String, time_remaining: float, progress: float)

## Emitted when a clue has fully decayed
signal clue_decayed(clue_id: String, decay_type: String)

## Emitted when decay is about to happen (warning)
signal clue_decay_warning(clue_id: String, time_remaining: float)

# ============================================================================
# CONFIGURATION
# ============================================================================

## How often to check for decay (seconds)
var decay_check_interval: float = 1.0

## When to emit warning (seconds before decay)
var decay_warning_threshold: float = 300.0  # 5 minutes

var _time_since_last_check: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	"""Initialize system"""
	pass

'''
func _ready() -> void:
    #GameTimeManager.time_updated.connect(update_game_time)  	# Not currently used
'''

func _process(delta: float) -> void:
	_current_game_time = Time.get_ticks_msec() / 1000.0
	
	"""Update decay system each frame"""
	_time_since_last_check += delta
	
	if _time_since_last_check >= decay_check_interval:
		_check_all_decay()
		# ClueDecaySystem.update_game_time(_time_since_last_check)
		_time_since_last_check = 0.0

func clear_all_data() -> void:
	"""Reset all decay tracking"""
	_decaying_clues.clear()
	_decayed_clues.clear()
	_current_game_time = 0.0
	_time_since_last_check = 0.0
	print("ClueDecaySystem: All data cleared")

# ============================================================================
# TIME MANAGEMENT
# ============================================================================

func update_game_time(new_time: float) -> void:
	"""Update current game time (seconds since game start)"""
	_current_game_time = new_time


func get_game_time() -> float:
	"""Get current game time"""
	return _current_game_time

# ============================================================================
# REGISTERING CLUES FOR DECAY
# ============================================================================

func register_clue_for_decay(clue: ClueData, trigger_condition: String = "") -> bool:
	"""
	Start tracking a clue for decay
	trigger_condition examples:
	  - "clue_observed" - Start decay after discovery
	  - "time_passed:600" - Start decay after 600 seconds
	  - "event:npc_dies" - Start decay when event happens
	"""
	
	if not clue.has("decay") or clue.decay.is_empty():
		return false
	
	var decay_config = clue.decay
	var decay_type = decay_config.get("type", "physical")
	var start_condition = decay_config.get("start_condition", "clue_observed")
	var end_condition = decay_config.get("end_condition", "")
	
	# Check if start condition is met
	if trigger_condition != "" and start_condition != trigger_condition:
		return false  # Not yet time to start decay
	
	# Calculate decay duration
	var duration = _parse_duration(end_condition)
	if duration <= 0.0:
		push_warning("ClueDecaySystem: Invalid end_condition for clue %s" % clue.clue_id)
		return false
	
	# Register for decay
	var decay_info = {
		"clue_id": clue.clue_id,
		"type": decay_type,
		"start_time": _current_game_time,
		"end_time": _current_game_time + duration,
		"duration": duration,
		"warning_sent": false
	}
	
	_decaying_clues[clue.clue_id] = decay_info
	
	clue_decay_started.emit(clue.clue_id, duration)
	
	print("ClueDecaySystem: Clue '%s' will decay in %.0f seconds" % [clue.clue_id, duration])
	
	return true


func _parse_duration(end_condition: String) -> float:
	"""
	Parse end_condition into seconds
	Examples:
	  - "3_days_passed" → 259200 seconds
	  - "12_hours_passed" → 43200 seconds
	  - "immediate" → 0 seconds
	"""
	
	if end_condition == "immediate":
		return 0.0
	
	# Parse "N_days_passed", "N_hours_passed", "N_minutes_passed"
	var parts = end_condition.split("_")
	
	if parts.size() >= 2:
		var amount = parts[0].to_int()
		var unit = parts[1].to_lower()
		
		match unit:
			"day", "days":
				return amount * 86400.0  # 24 hours
			"hour", "hours":
				return amount * 3600.0
			"minute", "minutes":
				return amount * 60.0
			"second", "seconds":
				return amount * 1.0
	
	# Try parsing as direct seconds
	if end_condition.is_valid_int():
		return end_condition.to_int()
	
	push_warning("ClueDecaySystem: Cannot parse duration: %s" % end_condition)
	return 0.0

# ============================================================================
# DECAY CHECKING
# ============================================================================

func _check_all_decay() -> void:
	"""Check all registered clues for decay"""
	var to_decay: Array[String] = []
	
	for clue_id in _decaying_clues.keys():
		var decay_info = _decaying_clues[clue_id]
		
		# Check if decay time has passed
		if _current_game_time >= decay_info.end_time:
			to_decay.append(clue_id)
			continue
		
		# Check for warning threshold
		var time_remaining = decay_info.end_time - _current_game_time
		
		if not decay_info.warning_sent and time_remaining <= decay_warning_threshold:
			clue_decay_warning.emit(clue_id, time_remaining)
			decay_info.warning_sent = true
		
		# Emit progress update
		var progress = (_current_game_time - decay_info.start_time) / decay_info.duration
		clue_decaying.emit(clue_id, time_remaining, progress)
	
	# Decay clues that expired
	for clue_id in to_decay:
		_decay_clue(clue_id)


func _decay_clue(clue_id: String) -> void:
	"""Mark a clue as decayed and remove it"""
	var decay_info = _decaying_clues.get(clue_id, {})
	var decay_type = decay_info.get("type", "physical")
	
	# Move to decayed list
	_decayed_clues[clue_id] = _current_game_time
	_decaying_clues.erase(clue_id)
	
	# Remove from ClueManager (make it undiscoverable)
	if ClueManager._active_clues.has(clue_id):
		var clue = ClueManager._active_clues[clue_id]
		clue.state = "decayed"
		
		# Don't fully remove - keep for history
		# ClueManager._active_clues.erase(clue_id)
	
	clue_decayed.emit(clue_id, decay_type)
	
	print("ClueDecaySystem: Clue '%s' has decayed (%s)" % [clue_id, decay_type])

# ============================================================================
# QUERIES
# ============================================================================

func is_clue_decaying(clue_id: String) -> bool:
	"""Check if a clue is currently decaying"""
	return clue_id in _decaying_clues


func has_clue_decayed(clue_id: String) -> bool:
	"""Check if a clue has already decayed"""
	return clue_id in _decayed_clues


func get_time_remaining(clue_id: String) -> float:
	"""Get seconds remaining before clue decays (-1 if not decaying)"""
	if not is_clue_decaying(clue_id):
		return -1.0
	
	var decay_info = _decaying_clues[clue_id]
	return max(0.0, decay_info.end_time - _current_game_time)


func get_decay_progress(clue_id: String) -> float:
	"""Get decay progress (0.0 = just started, 1.0 = about to decay)"""
	if not is_clue_decaying(clue_id):
		return 0.0
	
	var decay_info = _decaying_clues[clue_id]
	var elapsed = _current_game_time - decay_info.start_time
	return clamp(elapsed / decay_info.duration, 0.0, 1.0)


func get_all_decaying_clues() -> Array[String]:
	"""Get all clue IDs currently decaying"""
	return _decaying_clues.keys()


func get_all_decayed_clues() -> Array[String]:
	"""Get all clue IDs that have decayed"""
	return _decayed_clues.keys()

# ============================================================================
# MANUAL CONTROL
# ============================================================================

func stop_decay(clue_id: String) -> bool:
	"""Stop a clue from decaying (preserve it)"""
	if not is_clue_decaying(clue_id):
		return false
	
	_decaying_clues.erase(clue_id)
	print("ClueDecaySystem: Stopped decay for clue '%s'" % clue_id)
	return true


func accelerate_decay(clue_id: String, seconds_to_subtract: float) -> bool:
	"""Speed up decay (make it happen sooner)"""
	if not is_clue_decaying(clue_id):
		return false
	
	var decay_info = _decaying_clues[clue_id]
	decay_info.end_time = max(decay_info.start_time, decay_info.end_time - seconds_to_subtract)
	
	print("ClueDecaySystem: Accelerated decay for clue '%s' by %.0f seconds" % [
		clue_id, seconds_to_subtract
	])
	return true


func delay_decay(clue_id: String, seconds_to_add: float) -> bool:
	"""Delay decay (give more time)"""
	if not is_clue_decaying(clue_id):
		return false
	
	var decay_info = _decaying_clues[clue_id]
	decay_info.end_time += seconds_to_add
	
	print("ClueDecaySystem: Delayed decay for clue '%s' by %.0f seconds" % [
		clue_id, seconds_to_add
	])
	return true

# ============================================================================
# DEBUGGING
# ============================================================================

func print_decay_summary() -> void:
	"""Print debug summary"""
	print("\n=== DECAY SYSTEM SUMMARY ===")
	print("Current game time: %.1f seconds" % _current_game_time)
	print("Decaying clues: %d" % _decaying_clues.size())
	print("Decayed clues: %d" % _decayed_clues.size())
	
	if not _decaying_clues.is_empty():
		print("\nCurrently Decaying:")
		for clue_id in _decaying_clues.keys():
			var time_left = get_time_remaining(clue_id)
			var progress = get_decay_progress(clue_id)
			print("  %s: %.0f seconds (%.0f%%)" % [
				clue_id,
				time_left,
				progress * 100
			])
	
	print("============================\n")


func get_stats() -> Dictionary:
	"""Get statistics"""
	return {
		"decaying_clues": _decaying_clues.size(),
		"decayed_clues": _decayed_clues.size(),
		"game_time": _current_game_time
	}
