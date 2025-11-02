# test_scene.gd
# Main test scene for 2D prototype
extends Node2D

@onready var visualizer = $GridVisualizer2D
@onready var camera = $Camera2D
@onready var ui = $GridVisualizer2D/UI
@onready var info_panel = $GridVisualizer2D/UI/InfoPanel
@onready var location_ui = $GridVisualizer2D/UI/LocationUI  # NEW: Location navigation UI

var current_generator: WorldGenerator = null
var current_world: Dictionary = {}
var story_json: Dictionary = {}
var current_region_id: String = ""  # Currently displayed region
var current_region_index: int = 0  # Track which region we're viewing

# Camera controls
var camera_drag_start = Vector2.ZERO
var is_dragging = false
var zoom_speed = 0.1
var min_zoom = 0.1
var max_zoom = 3.0

func _ready():
	print("Test Scene Ready")
	
	# Load test story
	_load_test_story()
	
	# Generate first world
	generate_world()
	
	# Setup UI
	_setup_ui()
	_setup_location_ui()  # NEW

func _load_test_story():
	"""Load story JSON from file"""
	var all_files:Array[String] = [ 
		"res://data/stories/test_town.json", "res://data/stories/test_town_forest.json", "res://data/stories/test_graveyard.json", 
		"res://data/stories/test_lakeside.json", "res://data/stories/test_city.json", "res://data/stories/test_suburban.json",
		"res://data/stories/test_mountain.json", "res://data/stories/test_desert.json", "res://data/stories/test_beach.json", 
		"res://data/stories/test_swamp.json", "res://data/stories/test_multi_biome.json" 
	]
	#"res://data/stories/test_multi_biome_2.json"
	var file_path = "res://data/stories/example_story_with_spawns.json"
	
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		
		if error == OK:
			story_json = json.data
			print("Loaded story: ", story_json.get("story_metadata", {}).get("title", "Unknown"))
		else:
			push_error("JSON Parse Error: " + json.get_error_message())
			_use_fallback_story()
	else:
		print("Story file not found, using fallback")
		_use_fallback_story()

func _use_fallback_story():
	"""Fallback story if file not found"""
	story_json = {
		"story_metadata": {
			"title": "Test Town (Fallback)"
		},
		"world_config": {
			"total_size_km2": 2.0
		},
		"locations": {
			"regions": [
				{
					"id": "test_town",
					"type": "small_town",
					"size_km2": 2.0,
					"theme": "gothic",
					"must_have": [
						{"type": "chapel", "count": 1, "tags": ["quest_critical"]},
						{"type": "hotel", "count": 1, "tags": ["player_home"]}
					],
					"should_have": [
						{"type": "fountain", "probability": 0.8},
						{"type": "town_square", "probability": 0.9}
					],
					"generation_params": {
						"town_layout": "grid",
						"block_size_m": 80,
						"road_width_m": 6,
						"sidewalk_width_m": 2,
						"residential_density": "medium"
					}
				}
			]
		}
	}

func generate_world(seed: int = -1):
	"""Generate a new world"""
	print("\n--- Generating World ---")
	
	current_generator = WorldGenerator.new(story_json, seed)
	current_world = current_generator.generate()
	
	# Display first region
	current_region_index = 0
	if not current_world.regions.is_empty():
		var first_region_id = current_world.regions.keys()[current_region_index]
		display_region(first_region_id)
	
	# Update UI stats
	_update_stats_display()
	_update_location_ui()  # NEW
	
	print(current_generator.get_stats_summary())

func display_region(region_id: String):
	"""Display a specific region"""
	if not current_world.regions.has(region_id):
		push_error("Region not found: " + region_id)
		return
	
	current_region_id = region_id
	var region = current_world.regions[region_id]
	
	print("\n=== Displaying Region: %s ===" % region_id)
	
	# NEW: Get spawns for this region
	var region_spawns = _get_spawns_for_region(region_id)
	print("  Found %d spawns in this region" % region_spawns.size())
	
	# Pass spawns to visualizer
	visualizer.visualize(region.grid, region.pois, region.buildings, region_spawns)
	_center_camera_on_grid(region.grid)
	
	# Update location UI
	_update_location_ui()

func _center_camera_on_grid(grid: WorldGrid):
	"""Center camera on grid"""
	var grid_pixel_width = grid.width * visualizer.cell_size
	var grid_pixel_height = grid.height * visualizer.cell_size
	camera.position = Vector2(grid_pixel_width / 2, grid_pixel_height / 2)

func _setup_ui():
	"""Setup UI controls"""
	if ui and ui.has_node("Panel/VBox/GenerateButton"):
		ui.get_node("Panel/VBox/GenerateButton").pressed.connect(_on_generate_pressed)
	if ui and ui.has_node("Panel/VBox/ZoomInButton"):
		ui.get_node("Panel/VBox/ZoomInButton").pressed.connect(_on_zoom_in_pressed)
	if ui and ui.has_node("Panel/VBox/ZoomOutButton"):
		ui.get_node("Panel/VBox/ZoomOutButton").pressed.connect(_on_zoom_out_pressed)

func _setup_location_ui():
	"""Setup location navigation UI - NEW"""
	if not location_ui:
		return
	
	if location_ui.has_node("HBox/PrevButton"):
		location_ui.get_node("HBox/PrevButton").pressed.connect(_on_prev_location_pressed)
	if location_ui.has_node("HBox/NextButton"):
		location_ui.get_node("HBox/NextButton").pressed.connect(_on_next_location_pressed)

func _update_location_ui():
	"""Update location name and navigation buttons - NEW"""
	if not location_ui:
		return
	
	# Update location name label
	if location_ui.has_node("HBox/LocationLabel"):
		var label = location_ui.get_node("HBox/LocationLabel")
		
		if current_world.regions.is_empty():
			label.text = "No Location"
			return
		
		# Get region info
		var region = current_world.regions.get(current_region_id)
		if region:
			var region_name = _format_region_name(current_region_id)
			var region_type = region.config.get("type", "unknown").replace("_", " ").capitalize()
			label.text = "%s (%s)" % [region_name, region_type]
		else:
			label.text = current_region_id
	
	# Enable/disable navigation buttons based on region count
	var num_regions = current_world.regions.size()
	var has_multiple = num_regions > 1
	
	if location_ui.has_node("HBox/PrevButton"):
		location_ui.get_node("HBox/PrevButton").disabled = not has_multiple
	if location_ui.has_node("HBox/NextButton"):
		location_ui.get_node("HBox/NextButton").disabled = not has_multiple

func _format_region_name(region_id: String) -> String:
	"""Format region ID into display name"""
	# Convert "willow_town" -> "Willow Town"
	var words = region_id.split("_")
	var formatted_words = []
	for word in words:
		formatted_words.append(word.capitalize())
	return " ".join(formatted_words)

func _on_prev_location_pressed():
	"""Navigate to previous location - NEW"""
	if current_world.regions.is_empty():
		return
	
	var region_ids = current_world.regions.keys()
	current_region_index = (current_region_index - 1 + region_ids.size()) % region_ids.size()
	display_region(region_ids[current_region_index])
	print("◀ Previous location: %s" % region_ids[current_region_index])

func _on_next_location_pressed():
	"""Navigate to next location - NEW"""
	if current_world.regions.is_empty():
		return
	
	var region_ids = current_world.regions.keys()
	current_region_index = (current_region_index + 1) % region_ids.size()
	display_region(region_ids[current_region_index])
	print("▶ Next location: %s" % region_ids[current_region_index])

func _get_spawns_for_region(region_id: String) -> Array:
	"""Get all spawns belonging to a specific region"""
	var region_spawns: Array = []
	
	if not current_generator:
		return region_spawns
	
	var all_spawns = current_generator.generation_stats.get("spawns", [])
	for spawn in all_spawns:
		if spawn.region_id == region_id and spawn.has_position():
			region_spawns.append(spawn)
	
	return region_spawns

func _update_stats_display():
	"""Update stats label"""
	if ui and ui.has_node("Panel/VBox/StatsLabel"):
		var stats = current_generator.get_stats_summary()
		ui.get_node("Panel/VBox/StatsLabel").text = stats

func _input(event):
	# Regenerate on SPACE
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		generate_world()
	
	# Toggle info panel with I key
	if event is InputEventKey and event.pressed and event.keycode == KEY_I:
		if info_panel:
			info_panel.toggle_visibility()
	
	# Switch regions with number keys OR arrow keys - MODIFIED
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			_switch_to_region_index(0)
		elif event.keycode == KEY_2:
			_switch_to_region_index(1)
		elif event.keycode == KEY_3:
			_switch_to_region_index(2)
		elif event.keycode == KEY_LEFT:
			_on_prev_location_pressed()
		elif event.keycode == KEY_RIGHT:
			_on_next_location_pressed()
	
	# Camera panning with middle mouse or right mouse
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_dragging = true
				camera_drag_start = get_viewport().get_mouse_position()
			else:
				is_dragging = false
		
		# Zoom with mouse wheel
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(1.0 + zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(1.0 - zoom_speed)
	
	if event is InputEventMouseMotion and is_dragging:
		var current_pos = get_viewport().get_mouse_position()
		var delta = (camera_drag_start - current_pos) * camera.zoom.x
		camera.position += delta
		camera_drag_start = current_pos
	
	# Click to inspect cell
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_inspect_cell_at_mouse()

func _zoom_camera(factor: float):
	"""Zoom camera by factor"""
	var new_zoom = camera.zoom * factor
	new_zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
	new_zoom.y = clamp(new_zoom.y, min_zoom, max_zoom)
	camera.zoom = new_zoom

func _inspect_cell_at_mouse():
	"""Show detailed info about cell at mouse position"""
	var mouse_pos = get_global_mouse_position()
	var cell = visualizer.get_cell_at_position(mouse_pos)
	
	if current_region_id == "":
		return
	
	if not current_world.regions.has(current_region_id):
		return
	
	var region = current_world.regions[current_region_id]
	var grid = region.grid
	
	if not grid.is_valid(cell.x, cell.y):
		return
	
	# Gather all information
	var info = {
		"x": cell.x,
		"y": cell.y,
		"world_x": cell.x * 2.0,
		"world_z": cell.y * 2.0,
		"terrain": grid.get_terrain_name(grid.get_terrain(cell.x, cell.y)),
		"height": grid.get_height(cell.x, cell.y),
		"occupancy": grid.get_occupancy_name(grid.get_occupancy(cell.x, cell.y)),
		"region_name": _format_region_name(current_region_id)  # NEW: Add region name
	}
	
	# Check if this is a building
	var building = _find_building_at_cell(cell, region.buildings)
	if building:
		info["building_type"] = building.building_type
		info["building_width"] = building.size.x
		info["building_height"] = building.size.y
		info["building_tags"] = building.tags
	
	# Check if this is a POI
	var poi = _find_poi_at_cell(cell, region.pois)
	if poi:
		info["poi_type"] = poi.poi_type
		info["poi_radius"] = poi.footprint_radius
		info["poi_tags"] = poi.tags
		info["poi_required"] = poi.required
	
	# Check if this is an NPC spawn
	var region_spawns = _get_spawns_for_region(current_region_id)
	var spawn = _find_spawn_at_cell(cell, region_spawns)
	if spawn and spawn.entity_data:
		info["spawn_type"] = spawn.spawn_type
		info["spawn_name"] = spawn.entity_data.display_name
		info["spawn_id"] = spawn.spawn_id
		info["spawn_placement"] = spawn.placement_type
		
		# Add NPC-specific info if it's an NPC
		if spawn.entity_data is NPCData:
			var npc = spawn.entity_data as NPCData
			info["npc_gender"] = npc.gender
			info["npc_age"] = npc.age_category
			info["npc_species"] = npc.species
			info["npc_disposition"] = npc.disposition
			info["npc_behavior"] = npc.behavior_type
			if npc.is_merchant:
				info["npc_is_merchant"] = true
			if npc.quest_giver:
				info["npc_is_quest_giver"] = true
	
	# Print to console (enhanced)
	_print_cell_info_to_console(info)
	
	# Display in UI panel
	if info_panel:
		info_panel.display_cell_info(info)

func _switch_to_region_index(index: int):
	"""Switch to region by index (0, 1, 2, etc.)"""
	if current_world.regions.is_empty():
		return
	
	var region_ids = current_world.regions.keys()
	if index >= 0 and index < region_ids.size():
		current_region_index = index
		display_region(region_ids[current_region_index])
		print("Switched to region: %s (press 1-%d to switch)" % [region_ids[current_region_index], region_ids.size()])

func _find_spawn_at_cell(cell: Vector2i, spawns: Array) -> SpawnData:
	"""Find spawn at specific cell"""
	for spawn in spawns:
		if not spawn or not spawn.has_position():
			continue
		if spawn.position == cell:
			return spawn
	return null

func _find_building_at_cell(cell: Vector2i, buildings: Array) -> BuildingData:
	"""Find building that contains this cell"""
	for building in buildings:
		if not building or not building.is_valid():
			continue
		var bounds = building.get_bounds()
		if bounds.has_point(cell):
			return building
	return null

func _find_poi_at_cell(cell: Vector2i, pois: Array) -> POIData:
	"""Find POI that contains this cell"""
	for poi in pois:
		if not poi or not poi.is_valid():
			continue
		var dx = cell.x - poi.position.x
		var dy = cell.y - poi.position.y
		var dist_sq = dx * dx + dy * dy
		if dist_sq <= poi.footprint_radius * poi.footprint_radius:
			return poi
	return null

func _print_cell_info_to_console(info: Dictionary):
	"""Print formatted cell info to console"""
	var output = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
	
	# NEW: Add region name
	if info.has("region_name"):
		output += "Location: %s\n" % info.region_name
	
	output += "Cell [%d, %d]: " % [info.x, info.y]
	
	# Add building type if present
	if info.has("building_type"):
		output += "[%s BUILDING] " % info.building_type.to_upper()
	
	# Add POI type if present
	if info.has("poi_type"):
		output += "[%s POI] " % info.poi_type.to_upper()
	
	output += "\n"
	output += "  Terrain: %s, Occupancy: %s\n" % [info.terrain, info.occupancy]
	output += "  Height: %.1fm, World: (%.1f, %.1f)\n" % [info.height, info.world_x, info.world_z]
	
	if info.has("building_type"):
		output += "  Building: %s (%dx%d cells)\n" % [
			info.building_type.capitalize(),
			info.building_width,
			info.building_height
		]
	
	if info.has("poi_type"):
		output += "  POI: %s (radius %d)" % [info.poi_type.capitalize(), info.poi_radius]
		if info.poi_required:
			output += " ★ REQUIRED"
		output += "\n"
	
	# NPC spawn info
	if info.has("spawn_type"):
		output += "  NPC: %s [%s]\n" % [info.get("spawn_name", "Unknown"), info.get("spawn_id", "")]
		output += "    Type: %s, Placement: %s\n" % [
			info.spawn_type.capitalize(),
			info.spawn_placement.capitalize()
		]
		if info.has("npc_species"):
			output += "    %s %s %s" % [
				info.npc_age.replace("_", " ").capitalize(),
				info.npc_gender.capitalize(),
				info.npc_species.capitalize()
			]
			if info.get("npc_is_merchant", false):
				output += " [MERCHANT]"
			if info.get("npc_is_quest_giver", false):
				output += " [QUEST]"
			output += "\n"
	
	output += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	
	print(output)

func _on_generate_pressed():
	generate_world()

func _on_zoom_in_pressed():
	_zoom_camera(1.2)

func _on_zoom_out_pressed():
	_zoom_camera(0.8)

func _on_toggle_npcs(button_pressed: bool):
	"""Handle NPC visibility toggle"""
	visualizer.set_show_npcs(button_pressed)
	print("NPC visibility: ", "ON" if button_pressed else "OFF")
