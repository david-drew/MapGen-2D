# biome_template_manager.gd
# Manages loading, caching, and merging of biome templates
class_name BiomeTemplateManager
extends RefCounted

## Singleton pattern
static var _instance: BiomeTemplateManager = null

## Cached templates
var templates: Dictionary = {}
var is_loaded: bool = false

## Template file path
const TEMPLATE_FILE_PATH = "res://data/templates/biome_templates.json"

static func get_instance() -> BiomeTemplateManager:
	"""Get or create singleton instance"""
	if _instance == null:
		_instance = BiomeTemplateManager.new()
		_instance.load_templates()
	return _instance

func load_templates() -> bool:
	"""Load biome templates from JSON file"""
	if is_loaded:
		print("BiomeTemplateManager: Templates already loaded")
		return true
	
	print("BiomeTemplateManager: Loading templates from ", TEMPLATE_FILE_PATH)
	
	if not FileAccess.file_exists(TEMPLATE_FILE_PATH):
		push_error("BiomeTemplateManager: Template file not found at ", TEMPLATE_FILE_PATH)
		_load_fallback_templates()
		return false
	
	var file = FileAccess.open(TEMPLATE_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("BiomeTemplateManager: Failed to open template file")
		_load_fallback_templates()
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("BiomeTemplateManager: JSON parse error: ", json.get_error_message())
		_load_fallback_templates()
		return false
	
	var data = json.data
	if not data.has("templates"):
		push_error("BiomeTemplateManager: Missing 'templates' key in JSON")
		_load_fallback_templates()
		return false
	
	templates = data.templates
	is_loaded = true
	
	print("BiomeTemplateManager: Loaded %d biome templates" % templates.size())
	for biome_type in templates.keys():
		print("  - %s" % biome_type)
	
	return true

func _load_fallback_templates():
	"""Load minimal fallback templates if file not found"""
	print("BiomeTemplateManager: Loading fallback templates")
	
	templates = {
		"small_town": {
			"display_name": "Small Town",
			"default_buildings": [
				{"type": "house", "weight": 40, "density": 0.65, "min_size": [4, 4], "max_size": [6, 8]},
				{"type": "store", "weight": 15, "density": 0.15, "min_size": [6, 6], "max_size": [10, 10]}
			],
			"default_pois": [
				{"type": "town_square", "weight": 5, "density": 0.05, "radius": 8}
			],
			"decorations": [
				{"type": "bench", "weight": 20, "occupancy": "decoration"}
			],
			"generation_defaults": {
				"town_layout": "grid",
				"block_size_m": 80,
				"road_width_m": 6,
				"building_density": 0.6
			}
		},
		"forest": {
			"display_name": "Forest",
			"default_buildings": [
				{"type": "cabin", "weight": 8, "density": 0.7, "min_size": [3, 3], "max_size": [5, 5]}
			],
			"default_pois": [
				{"type": "clearing", "weight": 15, "density": 0.3, "radius": 8}
			],
			"decorations": [
				{"type": "fallen_log", "weight": 20, "occupancy": "decoration"}
			],
			"generation_defaults": {
				"tree_density": 0.7,
				"num_clearings": 5,
				"num_paths": 4
			}
		}
	}
	
	is_loaded = true

func get_template(biome_type: String) -> Dictionary:
	"""Get template for a specific biome type"""
	if not is_loaded:
		load_templates()
	
	if not templates.has(biome_type):
		push_warning("BiomeTemplateManager: No template for type '%s', using empty template" % biome_type)
		return _get_empty_template()
	
	return templates[biome_type].duplicate(true)  # Deep copy

func _get_empty_template() -> Dictionary:
	"""Return empty template structure"""
	return {
		"display_name": "Unknown",
		"default_buildings": [],
		"default_pois": [],
		"decorations": [],
		"generation_defaults": {}
	}

func merge_with_story_config(template: Dictionary, story_config: Dictionary) -> Dictionary:
	"""Merge template with story JSON config. Story values override template values."""
	var merged = template.duplicate(true)
	
	# Override simple fields
	if story_config.has("display_name"):
		merged["display_name"] = story_config["display_name"]
	
	# Merge generation_defaults (story overrides template)
	if story_config.has("generation_params"):
		if not merged.has("generation_defaults"):
			merged["generation_defaults"] = {}
		for key in story_config["generation_params"].keys():
			merged["generation_defaults"][key] = story_config["generation_params"][key]
	
	# Handle must_have POIs (these are additions, not replacements)
	if story_config.has("must_have"):
		if not merged.has("must_have"):
			merged["must_have"] = []
		merged["must_have"] = story_config["must_have"].duplicate()
	
	# Handle should_have POIs (these are additions)
	if story_config.has("should_have"):
		if not merged.has("should_have"):
			merged["should_have"] = []
		merged["should_have"] = story_config["should_have"].duplicate()
	
	# Note: default_buildings and default_pois from template are kept as-is
	# Story JSON uses must_have/should_have to add specific requirements
	
	return merged

func get_merged_config(biome_type: String, story_config: Dictionary) -> Dictionary:
	"""Get template and merge with story config in one call"""
	var template = get_template(biome_type)
	return merge_with_story_config(template, story_config)

func get_building_list_with_density(biome_type: String, story_config: Dictionary) -> Array:
	"""
	Get complete building list with weight and density for placement.
	Returns array of: {type, weight, density, min_size, max_size}
	"""
	var merged = get_merged_config(biome_type, story_config)
	return merged.get("default_buildings", []).duplicate()

func get_poi_list_with_density(biome_type: String, story_config: Dictionary) -> Array:
	"""
	Get complete POI list with weight and density for placement.
	Returns array of: {type, weight, density, radius}
	"""
	var merged = get_merged_config(biome_type, story_config)
	return merged.get("default_pois", []).duplicate()

func get_decoration_list(biome_type: String, story_config: Dictionary) -> Array:
	"""
	Get decoration list for context-based placement.
	Returns array of: {type, weight, occupancy}
	"""
	var merged = get_merged_config(biome_type, story_config)
	return merged.get("decorations", []).duplicate()

func get_generation_params(biome_type: String, story_config: Dictionary) -> Dictionary:
	"""Get merged generation parameters"""
	var merged = get_merged_config(biome_type, story_config)
	return merged.get("generation_defaults", {})

func calculate_building_budget(region_size_km2: float, biome_type: String, story_config: Dictionary) -> int:
	"""
	Calculate how many buildings should be placed in this region.
	Based on region size and biome-specific building density.
	"""
	var params = get_generation_params(biome_type, story_config)
	var building_density = params.get("building_density", 0.5)  # Default 0.5
	
	# Base formula: buildings per km²
	var buildings_per_km2 = 50.0  # Baseline
	
	# Adjust based on biome type
	match biome_type:
		"city":
			buildings_per_km2 = 100.0
		"small_town":
			buildings_per_km2 = 50.0
		"suburban":
			buildings_per_km2 = 40.0
		"forest":
			buildings_per_km2 = 5.0
		"graveyard":
			buildings_per_km2 = 20.0
		"lakeside":
			buildings_per_km2 = 15.0
		"mountain":
			buildings_per_km2 = 3.0
	
	var total_buildings = region_size_km2 * buildings_per_km2 * building_density
	return int(max(1, total_buildings))  # At least 1 building

func calculate_poi_budget(region_size_km2: float, biome_type: String, story_config: Dictionary) -> int:
	"""
	Calculate how many POIs should be placed in this region.
	"""
	# POIs are typically fewer than buildings
	var pois_per_km2 = 3.0  # Baseline
	
	# Adjust based on biome type
	match biome_type:
		"forest":
			pois_per_km2 = 5.0  # More natural features
		"graveyard":
			pois_per_km2 = 8.0  # Many grave clusters
		"city":
			pois_per_km2 = 4.0
		"small_town":
			pois_per_km2 = 3.0
	
	var total_pois = region_size_km2 * pois_per_km2
	return int(max(1, total_pois))

func get_weighted_random_building(building_list: Array, rng: RandomNumberGenerator) -> Dictionary:
	"""
	Select a random building from list based on weights.
	Returns building config or empty dict if list is empty.
	"""
	if building_list.is_empty():
		return {}
	
	# Calculate total weight
	var total_weight = 0.0
	for building in building_list:
		total_weight += building.get("weight", 1.0)
	
	# Random selection
	var random_value = rng.randf() * total_weight
	var cumulative = 0.0
	
	for building in building_list:
		cumulative += building.get("weight", 1.0)
		if random_value <= cumulative:
			return building.duplicate()
	
	# Fallback (shouldn't reach here)
	return building_list[0].duplicate()

func get_weighted_random_poi(poi_list: Array, rng: RandomNumberGenerator) -> Dictionary:
	"""
	Select a random POI from list based on weights.
	Returns POI config or empty dict if list is empty.
	"""
	if poi_list.is_empty():
		return {}
	
	# Calculate total weight
	var total_weight = 0.0
	for poi in poi_list:
		total_weight += poi.get("weight", 1.0)
	
	# Random selection
	var random_value = rng.randf() * total_weight
	var cumulative = 0.0
	
	for poi in poi_list:
		cumulative += poi.get("weight", 1.0)
		if random_value <= cumulative:
			return poi.duplicate()
	
	# Fallback
	return poi_list[0].duplicate()

func print_template_summary(biome_type: String):
	"""Print summary of a template (for debugging)"""
	var template = get_template(biome_type)
	
	print("\n=== Template: %s ===" % biome_type)
	print("Display Name: %s" % template.get("display_name", "Unknown"))
	
	var buildings = template.get("default_buildings", [])
	print("\nBuildings (%d types):" % buildings.size())
	for building in buildings:
		print("  - %s: weight=%s, density=%s, size=%s-%s" % [
			building.get("type", "?"),
			building.get("weight", "?"),
			building.get("density", "?"),
			building.get("min_size", "?"),
			building.get("max_size", "?")
		])
	
	var pois = template.get("default_pois", [])
	print("\nPOIs (%d types):" % pois.size())
	for poi in pois:
		print("  - %s: weight=%s, density=%s, radius=%s" % [
			poi.get("type", "?"),
			poi.get("weight", "?"),
			poi.get("density", "?"),
			poi.get("radius", "?")
		])
	
	var decorations = template.get("decorations", [])
	print("\nDecorations (%d types):" % decorations.size())
	for deco in decorations:
		print("  - %s: weight=%s" % [deco.get("type", "?"), deco.get("weight", "?")])
	
	print("\nGeneration Defaults:")
	var params = template.get("generation_defaults", {})
	for key in params.keys():
		print("  %s: %s" % [key, params[key]])
