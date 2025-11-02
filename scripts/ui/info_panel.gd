# info_panel.gd
# Displays detailed information about clicked cells/buildings
extends PanelContainer

@onready var content_label = $MarginContainer/VBoxContainer/ContentLabel
@onready var title_label = $MarginContainer/VBoxContainer/HBoxContainer/TitleLabel
@onready var close_button = $MarginContainer/VBoxContainer/HBoxContainer/CloseButton
@onready var pin_button = $MarginContainer/VBoxContainer/HBoxContainer/PinButton

var is_pinned: bool = false
var is_visible_toggle: bool = true

func _ready():
	print("InfoPanel ready")
	
	# Check if child nodes exist
	if not content_label:
		push_error("InfoPanel: ContentLabel not found! Check node path.")
	else:
		# CRITICAL FIX: Enable BBCode for rich text formatting
		if content_label is RichTextLabel:
			content_label.bbcode_enabled = true
			print("  BBCode enabled for ContentLabel")
	
	if not title_label:
		push_error("InfoPanel: TitleLabel not found! Check node path.")
	if not close_button:
		push_error("InfoPanel: CloseButton not found! Check node path.")
	if not pin_button:
		push_error("InfoPanel: PinButton not found! Check node path.")
	
	#hide()
	
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if pin_button:
		pin_button.pressed.connect(_on_pin_pressed)

func display_cell_info(info: Dictionary):
	"""Display information about a cell"""
	print("InfoPanel.display_cell_info called")
	
	if not is_visible_toggle:
		print("  Panel visibility toggled off")
		return
	
	if not content_label:
		push_error("  ContentLabel is null!")
		return
	
	# Build info text
	var text = ""
	
	# NEW: Region name
	if info.has("region_name"):
		text += "[b][color=cyan]%s[/color][/b]\n\n" % info.region_name
	
	# Position
	text += "[b]Grid Position:[/b] [%d, %d]\n" % [info.get("x", 0), info.get("y", 0)]
	text += "[b]World Position:[/b] %.1f, %.1f\n\n" % [info.get("world_x", 0.0), info.get("world_z", 0.0)]
	
	# Terrain
	text += "[b]Terrain:[/b] %s\n" % info.get("terrain", "Unknown")
	text += "[b]Height:[/b] %.1fm\n" % info.get("height", 0.0)
	text += "[b]Occupancy:[/b] %s\n\n" % info.get("occupancy", "Empty")
	
	# Building details
	if info.has("building_type"):
		text += "[b][color=orange]═══ Building ═══[/color][/b]\n"
		text += "[b]Type:[/b] %s\n" % info.building_type.capitalize()
		text += "[b]Size:[/b] %dx%d cells\n" % [info.get("building_width", 0), info.get("building_height", 0)]
		
		if info.has("building_tags") and not info.building_tags.is_empty():
			text += "[b]Tags:[/b] %s\n" % ", ".join(info.building_tags)
		text += "\n"
	
	# POI details
	if info.has("poi_type"):
		text += "[b][color=yellow]═══ Point of Interest ═══[/color][/b]\n"
		text += "[b]Type:[/b] %s\n" % info.poi_type.capitalize()
		text += "[b]Radius:[/b] %d cells\n" % info.get("poi_radius", 0)
		
		if info.has("poi_tags") and not info.poi_tags.is_empty():
			text += "[b]Tags:[/b] %s\n" % ", ".join(info.poi_tags)
		
		if info.get("poi_required", false):
			text += "[color=red][b]★ Required POI[/b][/color]\n"
		text += "\n"
	
	# NEW: NPC Spawn details
	if info.has("spawn_type"):
		text += "[b][color=red]═══ NPC Spawn ═══[/color][/b]\n"
		text += "[b]Entity:[/b] %s\n" % info.get("spawn_name", "Unknown")
		text += "[b]ID:[/b] %s\n" % info.get("spawn_id", "unknown")
		text += "[b]Type:[/b] %s\n" % info.get("spawn_type", "npc").capitalize()
		text += "[b]Placement:[/b] %s\n" % info.get("spawn_placement", "exterior").capitalize()
		
		# NPC-specific details
		if info.has("npc_species"):
			text += "\n[b]Character Details:[/b]\n"
			text += "  [b]Species:[/b] %s\n" % info.npc_species.capitalize()
			text += "  [b]Gender:[/b] %s\n" % info.npc_gender.capitalize()
			text += "  [b]Age:[/b] %s\n" % info.npc_age.replace("_", " ").capitalize()
			text += "  [b]Disposition:[/b] %s\n" % info.npc_disposition.capitalize()
			text += "  [b]Behavior:[/b] %s\n" % info.npc_behavior.capitalize()
			
			# Special roles
			var roles = []
			if info.get("npc_is_merchant", false):
				roles.append("[color=green]Merchant[/color]")
			if info.get("npc_is_quest_giver", false):
				roles.append("[color=yellow]Quest Giver[/color]")
			
			if not roles.is_empty():
				text += "  [b]Roles:[/b] %s\n" % ", ".join(roles)
		
		text += "\n"
	
	# Additional info
	if info.has("notes"):
		text += "[i]%s[/i]\n" % info.notes
	
	# Set the text (will now render with BBCode)
	content_label.text = text
	print("  ContentLabel updated with %d characters" % text.length())
	
	# Update title
	if info.has("spawn_name"):
		title_label.text = "NPC: %s" % info.spawn_name
	elif info.has("building_type"):
		title_label.text = "Building: %s" % info.building_type.capitalize()
	elif info.has("poi_type"):
		title_label.text = "POI: %s" % info.poi_type.capitalize()
	else:
		title_label.text = "Cell Info"
	
	print("  Title set to: ", title_label.text)
	print("  Showing InfoPanel")
	show()

func toggle_visibility():
	"""Toggle panel visibility"""
	is_visible_toggle = not is_visible_toggle
	if not is_visible_toggle:
		hide()

func _on_close_pressed():
	"""Close the panel (unless pinned)"""
	if not is_pinned:
		hide()

func _on_pin_pressed():
	"""Toggle pin state"""
	is_pinned = not is_pinned
	if pin_button:
		pin_button.text = "📌" if is_pinned else "📍"

func _input(event):
	"""Handle keyboard shortcuts"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_I:
			toggle_visibility()
			if not is_visible_toggle:
				hide()
