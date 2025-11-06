extends Node

# GameTimeManager - Not currently used, add as autoload if needed

var game_time: float = 0.0
var time_scale: float = 1.0
var is_paused: bool = false

signal time_updated(new_time: float)

func _process(delta: float):
	if not is_paused:
		game_time += delta * time_scale
		time_updated.emit(game_time)

func pause_time():
	is_paused = true

func resume_time():
	is_paused = false
