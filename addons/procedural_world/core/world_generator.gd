# world_generator.gd
# Main orchestrator for world generation pipeline
class_name WorldGenerator
extends RefCounted

## Configuration
var story_json: Dictionary
var random_seed: int
var rng: RandomNumberGenerator

## State
var regions: Dictionary = {}  # region_id -> region data
var connectors: Array[ConnectorData] = []  # connections between regions
var generators: Dictionary = {}  # type -> LocationGenerator

## Statistics
var generation_start_time: int
var generation_stats: Dictionary = {}

var template_manager: BiomeTemplateManager = null

func _init(story_data: Dictionary, seed: int = -1):
	story_json = story_data
	random_seed = seed if seed != -1 else randi()
	rng = RandomNumberGenerator.new()
	rng.seed = random_seed
	
	template_manager = BiomeTemplateManager.get_instance()
	
	_register_generators()
	
	print("WorldGenerator initialized with seed: ", random_seed)

func _register_generators():
	"""Register all location type generators"""
	generators["small_town"] = SmallTownGeneratorV2.new()  # Use V2
	generators["forest"] = ForestGenerator.new()
	generators["graveyard"] = GraveyardGenerator.new() 
	generators["lakeside"] = LakesideGenerator.new() 
	generators["city"] = CityGenerator.new() 
	generators["suburban"] = SuburbanGenerator.new()
	generators["mountain"] = MountainGenerator.new() 
	
	# Add more as you create them

func generate() -> Dictionary:
	"""Execute full generation pipeline and return world data"""
	print("\n=== Starting World Generation ===")
	print("Seed: ", random_seed)
	generation_start_time = Time.get_ticks_msec()
	
	# Execute pipeline passes
	_pass_1_world_layout()
	_pass_2_region_foundation()
	_pass_3_required_poi_placement()
	_pass_4_optional_poi_placement()
	_pass_4b_template_poi_placement() 
	_pass_5_building_generation()
	_pass_5b_template_building_placement()
	_pass_6_connector_generation()  # NEW: Generate connections between regions
	
	# Calculate generation time
	var duration = Time.get_ticks_msec() - generation_start_time
	print("\n=== Generation Complete in %d ms ===" % duration)
	
	generation_stats["duration_ms"] = duration
	generation_stats["seed"] = random_seed
	generation_stats["num_regions"] = regions.size()
	generation_stats["num_connectors"] = connectors.size()
	
	return {
		"regions": regions,
		"connectors": connectors,
		"seed": random_seed,
		"stats": generation_stats
	}

func _pass_1_world_layout():
	"""Calculate world bounds and region positions"""
	print("\n[Pass 1] World Layout")
	
	var region_configs = story_json.get("locations", {}).get("regions", [])
	
	if region_configs.is_empty():
		push_error("No regions defined in story JSON!")
		return
	
	# Position regions in world space
	var current_x = 0.0
	var spacing_km = 0.2  # 200m spacing between regions
	
	for region_config in region_configs:
		var size_km = sqrt(region_config.get("size_km2", 1.0))
		
		var region_data = {
			"config": region_config,
			"position": Vector2(current_x, 0),  # Position in km
			"size_km": Vector2(size_km, size_km),
			"size_m": size_km * 1000,
			"grid": null,  # Created in pass 2
			"pois": [],
			"buildings": []
		}
		
		var region_id = region_config.get("id", "region_" + str(regions.size()))
		regions[region_id] = region_data
		
		print("  Region '%s' at (%.1f, 0) km, size %.1fx%.1f km" % [
			region_id, current_x, size_km, size_km
		])
		
		# Move to next position
		current_x += size_km + spacing_km
	
	print("  Initialized %d regions, total width: %.1f km" % [regions.size(), current_x])

func _pass_2_region_foundation():
	"""Generate foundation for each region"""
	print("\n[Pass 2] Region Foundation")
	
	for region_id in regions.keys():
		print("  Processing region: ", region_id)
		var region = regions[region_id]
		var config = region.config
		
		# Get generator for this type
		var region_type = config.get("type", "small_town")
		if not generators.has(region_type):
			push_error("No generator for type: " + region_type)
			continue
		
		var generator = generators[region_type]
		
		# NEW: Get merged config with template defaults
		var merged_config = template_manager.get_merged_config(region_type, config)
		
		# Store merged config back (so later passes can use it)
		region.merged_config = merged_config
		
		# Create grid
		var grid_size = int(region.size_m / 2.0)  # 2m cells
		region.grid = WorldGrid.new(grid_size, grid_size)
		
		print("    Grid size: %d x %d cells" % [grid_size, grid_size])
		
		# Generate foundation (pass merged config instead of raw config)
		generator.generate_foundation(region.grid, merged_config, rng)


func _pass_3_required_poi_placement():
	"""Place all must_have POIs"""
	print("\n[Pass 3] Required POI Placement")
	
	var total_required = 0
	var total_placed = 0
	
	for region_id in regions.keys():
		var region = regions[region_id]
		var config = region.config
		var merged_config = region.get("merged_config", config)  # NEW: Use merged config
		var generator = generators[config.get("type", "small_town")]
		
		var must_haves = merged_config.get("must_have", [])  # Changed from config to merged_config
		total_required += must_haves.size()
		
		print("  Region '%s' has %d required POIs" % [region_id, must_haves.size()])
		
		for poi_spec in must_haves:
			var poi_type = poi_spec.get("type", "unknown")
			var count = poi_spec.get("count", 1)
			var tags = poi_spec.get("tags", [])
			
			for i in range(count):
				var poi = generator.place_poi(region.grid, poi_type, tags, true, rng)
				if poi:
					region.pois.append(poi)
					total_placed += 1
					print("    ✓ Placed required POI: %s" % poi_type)
				else:
					push_warning("    ✗ Failed to place required POI: %s" % poi_type)
	
	print("  Total: %d/%d required POIs placed" % [total_placed, total_required])
	generation_stats["required_pois_placed"] = total_placed
	generation_stats["required_pois_failed"] = total_required - total_placed

func _pass_4_optional_poi_placement():
	"""Place optional POIs based on probability"""
	print("\n[Pass 4] Optional POI Placement")
	
	var total_attempted = 0
	var total_placed = 0
	
	for region_id in regions.keys():
		var region = regions[region_id]
		var config = region.config
		var generator = generators[config.get("type", "small_town")]
		
		var should_haves = config.get("should_have", [])
		
		for poi_spec in should_haves:
			var probability = poi_spec.get("probability", 0.5)
			
			if rng.randf() < probability:
				total_attempted += 1
				var poi_type = poi_spec.get("type", "unknown")
				
				var poi = generator.place_optional_poi(
					region.grid,
					poi_type,
					rng
				)
				
				if poi.is_valid():
					region.pois.append(poi)
					total_placed += 1
	
	print("  Placed %d / %d optional POIs" % [total_placed, total_attempted])
	generation_stats["optional_pois_placed"] = total_placed


# ============================================
# NEW PASS: _pass_4b_template_poi_placement()
# Add this AFTER _pass_4_optional_poi_placement()
# ============================================

func _pass_4b_template_poi_placement():
	"""Place POIs from biome templates using density-based placement"""
	print("\n[Pass 4b] Template POI Placement")
	
	for region_id in regions.keys():
		var region = regions[region_id]
		var config = region.config
		var region_type = config.get("type", "small_town")
		var merged_config = region.get("merged_config", config)
		var generator = generators[region_type]
		
		# Calculate POI budget for this region
		var poi_budget = template_manager.calculate_poi_budget(
			region.config.get("size_km2", 1.0),
			region_type,
			config
		)
		
		print("  Region '%s' POI budget: %d" % [region_id, poi_budget])
		
		# Get POI list with densities
		var poi_list = template_manager.get_poi_list_with_density(region_type, config)
		
		if poi_list.is_empty():
			print("    No template POIs defined for this biome type")
			continue
		
		# Track density targets
		var density_targets = {}
		for poi_config in poi_list:
			var poi_type = poi_config.get("type", "unknown")
			var density = poi_config.get("density", 0.1)
			var target_count = int(poi_budget * density)
			density_targets[poi_type] = {
				"target": target_count,
				"placed": 0,
				"config": poi_config
			}
		
		# Place POIs based on weighted selection until budget exhausted
		var placed_count = 0
		var max_attempts = poi_budget * 3  # Safety limit
		var attempts = 0
		
		while placed_count < poi_budget and attempts < max_attempts:
			attempts += 1
			
			# Select POI type using weighted random
			var poi_config = template_manager.get_weighted_random_poi(poi_list, rng)
			if poi_config.is_empty():
				break
			
			var poi_type = poi_config.get("type", "unknown")
			
			# Check if we've reached density target for this type
			var target_info = density_targets.get(poi_type, {})
			var target = target_info.get("target", 0)
			var current_placed = target_info.get("placed", 0)
			
			# Allow some overflow (10%) but try to respect targets
			if current_placed >= target * 1.1:
				continue  # Try another type
			
			# Try to place this POI
			var poi = generator.place_poi(
				region.grid,
				poi_type,
				[],  # No special tags
				false,  # Not required
				rng
			)
			
			if poi:
				region.pois.append(poi)
				placed_count += 1
				density_targets[poi_type]["placed"] += 1
				print("    ✓ Placed %s POI (%d/%d target)" % [
					poi_type,
					density_targets[poi_type]["placed"],
					target
				])
		
		print("  Placed %d/%d template POIs" % [placed_count, poi_budget])

func _pass_5_building_generation():
	"""Generate buildings and structures"""
	print("\n[Pass 5] Building Generation")
	
	for region_id in regions.keys():
		var region = regions[region_id]
		var config = region.config
		var generator = generators[config.get("type", "small_town")]
		
		generator.generate_buildings(region.grid, config, rng)
		
		# Store buildings if generator supports it
		if generator.has_method("get_buildings"):
			region.buildings = generator.get_buildings()

# ============================================
# NEW PASS: _pass_5b_template_building_placement()
# Add this AFTER _pass_5_building_generation()
# ============================================

func _pass_5b_template_building_placement():
	"""Place buildings from biome templates using density-based placement"""
	print("\n[Pass 5b] Template Building Placement")
	
	for region_id in regions.keys():
		var region = regions[region_id]
		var config = region.config
		var region_type = config.get("type", "small_town")
		var merged_config = region.get("merged_config", config)
		var generator = generators[region_type]
		
		# Calculate building budget for this region
		var building_budget = template_manager.calculate_building_budget(
			region.config.get("size_km2", 1.0),
			region_type,
			config
		)
		
		print("  Region '%s' building budget: %d" % [region_id, building_budget])
		
		# Get building list with densities
		var building_list = template_manager.get_building_list_with_density(region_type, config)
		
		if building_list.is_empty():
			print("    No template buildings defined for this biome type")
			continue
		
		# Track density targets
		var density_targets = {}
		for building_config in building_list:
			var building_type = building_config.get("type", "unknown")
			var density = building_config.get("density", 0.1)
			var target_count = int(building_budget * density)
			density_targets[building_type] = {
				"target": target_count,
				"placed": 0,
				"config": building_config
			}
		
		# Place buildings based on weighted selection
		var placed_count = 0
		var max_attempts = building_budget * 3
		var attempts = 0
		
		while placed_count < building_budget and attempts < max_attempts:
			attempts += 1
			
			# Select building type using weighted random
			var building_config = template_manager.get_weighted_random_building(building_list, rng)
			if building_config.is_empty():
				break
			
			var building_type = building_config.get("type", "unknown")
			
			# Check density target
			var target_info = density_targets.get(building_type, {})
			var target = target_info.get("target", 0)
			var current_placed = target_info.get("placed", 0)
			
			if current_placed >= target * 1.1:
				continue
			
			# Random size within range
			var min_size = building_config.get("min_size", [4, 4])
			var max_size = building_config.get("max_size", [8, 8])
			var width = rng.randi_range(min_size[0], max_size[0])
			var height = rng.randi_range(min_size[1], max_size[1])
			
			# Try to place this building
			var building = generator.place_building(
				region.grid,
				building_type,
				Vector2i(width, height),
				[],  # No special tags
				rng
			)
			
			if building:
				region.buildings.append(building)
				placed_count += 1
				density_targets[building_type]["placed"] += 1
		
		print("  Placed %d/%d template buildings" % [placed_count, building_budget])
		
		# Print summary
		for building_type in density_targets.keys():
			var info = density_targets[building_type]
			print("    %s: %d/%d (%.1f%% of target)" % [
				building_type,
				info.placed,
				info.target,
				(float(info.placed) / max(1, info.target)) * 100.0
			])

func _pass_6_connector_generation():
	"""Generate connections between regions"""
	print("\n[Pass 6] Connector Generation")
	
	# Get connector definitions from story JSON
	var connector_configs = story_json.get("connectors", [])
	
	if connector_configs.is_empty():
		print("  No connectors defined in story JSON")
		# Auto-generate simple connectors between adjacent regions
		_auto_generate_connectors()
		return
	
	# Create connectors from JSON definitions
	for connector_config in connector_configs:
		var connector = ConnectorData.new(
			connector_config.get("id", "connector_" + str(connectors.size())),
			connector_config.get("type", "path"),
			connector_config.get("from", ""),
			connector_config.get("to", "")
		)
		
		connector.from_exit = connector_config.get("from_exit", "east")
		connector.to_entrance = connector_config.get("to_entrance", "west")
		connector.traversal_time_minutes = connector_config.get("travel_time_minutes", 5.0)
		connector.difficulty = connector_config.get("difficulty", "easy")
		
		if connector_config.has("tags"):
			for tag in connector_config.tags:
				connector.tags.append(str(tag))
		
		if connector.is_valid():
			connectors.append(connector)
			print("  Created connector: %s" % connector)
	
	print("  Generated %d connectors" % connectors.size())

func _auto_generate_connectors():
	"""Automatically generate connectors between adjacent regions"""
	var region_ids = regions.keys()
	
	# Connect each region to the next one
	for i in range(region_ids.size() - 1):
		var from_id = region_ids[i]
		var to_id = region_ids[i + 1]
		
		# Determine connector type based on region types
		var from_type = regions[from_id].config.get("type", "")
		var to_type = regions[to_id].config.get("type", "")
		var connector_type = _get_connector_type(from_type, to_type)
		
		var connector = ConnectorData.new(
			"conn_%s_%s" % [from_id, to_id],
			connector_type,
			from_id,
			to_id
		)
		
		connector.from_exit = "east"
		connector.to_entrance = "west"
		connector.traversal_time_minutes = 5.0
		
		connectors.append(connector)
		print("  Auto-created: %s" % connector)

func _get_connector_type(from_type: String, to_type: String) -> String:
	"""Determine appropriate connector type between region types"""
	if "town" in from_type and "forest" in to_type:
		return "old_road"
	elif "forest" in from_type and "town" in to_type:
		return "old_road"
	elif "forest" in from_type and "forest" in to_type:
		return "forest_path"
	elif "town" in from_type and "town" in to_type:
		return "road"
	else:
		return "path"

func get_first_region() -> Dictionary:
	"""Get first region (useful for prototype)"""
	if regions.is_empty():
		return {}
	return regions.values()[0]

func get_stats_summary() -> String:
	"""Get human-readable stats"""
	var summary = "Generation Stats:\n"
	summary += "  Seed: %d\n" % random_seed
	summary += "  Duration: %d ms\n" % generation_stats.get("duration_ms", 0)
	summary += "  Required POIs: %d / %d\n" % [
		generation_stats.get("required_pois_placed", 0),
		generation_stats.get("required_pois_total", 0)
	]
	summary += "  Optional POIs: %d\n" % generation_stats.get("optional_pois_placed", 0)
	return summary
