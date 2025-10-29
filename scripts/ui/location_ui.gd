# location_ui.gd
# UI for displaying current location and navigating between regions
extends Control

@onready var location_label = $HBox/LocationLabel
@onready var prev_button = $HBox/PrevButton
@onready var next_button = $HBox/NextButton

func _ready():
	# Style the buttons
	if prev_button:
		prev_button.text = "◀"
	if next_button:
		next_button.text = "▶"
	
	# Initial state
	update_display("No Location", false)

func update_display(location_name: String, has_multiple_locations: bool):
	"""Update the location label and button states"""
	if location_label:
		location_label.text = location_name
	
	# Enable/disable navigation buttons
	if prev_button:
		prev_button.disabled = not has_multiple_locations
	if next_button:
		next_button.disabled = not has_multiple_locations
