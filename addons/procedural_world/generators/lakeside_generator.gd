# lakeside_generator.gd
# Generator for lakeside locations with water features and shore activities
class_name LakesideGenerator
extends LocationGeneratorBase

var lake_cells: Array[Vector2i] = []  # Cells that are water

func generate_foundation(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate lakeside foundation with water and shore"""
	print("  Generating lakeside foundation...")
	
	# Generate terrain with water features
	_generate_lakeside_heightmap(grid, rng)
	
	# Create the lake/water body
	_generate_lake(grid, config, rng)
	
	# Add beach/sandy shore areas
	_add_shore_areas(grid, config, rng)
	
	# Create paths along the shore
	_create_shoreline_paths(grid, config, rng)
	
	# Add fishing pier/dock locations (as terrain markers)
	_mark_dock_areas(grid, config, rng)

func _generate_lakeside_heightmap(grid: WorldGrid, rng: RandomNumberGenerator):
	"""Generate terrain that slopes toward water"""
	var noise = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.015
	noise.fractal_octaves = 3
	
	# Center of lake will be lowest point
	var lake_center_x = grid.width / 2
	var lake_center_y = grid.height / 2
	
	for y in range(grid.height):
		for x in range(grid.width):
			var value = noise.get_noise_2d(x, y)
			value = (value + 1.0) * 0.5
			
			# Distance from lake center (normalized)
			var dx = float(x - lake_center_x) / grid.width
			var dy = float(y - lake_center_y) / grid.height
			var dist = sqrt(dx * dx + dy * dy)
			
			# Terrain slopes up away from center
			var height = value * 8.0 + dist * 5.0
			grid.set_height(x, y, height)

func _generate_lake(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Create the lake/water body"""
	var lake_size_factor = config.get("lake_size", 0.3)  # 30% of area by default
	var shoreline_curvature = config.get("shoreline_curvature", 0.6)
	
	print("    Creating lake (size factor: %.1f)..." % lake_size_factor)
	
	var center_x = grid.width / 2
	var center_y = grid.height / 2
	
	# Use noise for organic shoreline
	var noise = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.02 * shoreline_curvature
	noise.fractal_octaves = 2
	
	# Base radius for lake
	var base_radius = min(grid.width, grid.height) * lake_size_factor
	
	var water_count = 0
	
	for y in range(grid.height):
		for x in range(grid.width):
			var dx = x - center_x
			var dy = y - center_y
			var dist = sqrt(dx * dx + dy * dy)
			
			# Add noise variation to radius
			var noise_value = noise.get_noise_2d(x, y)
			var actual_radius = base_radius * (1.0 + noise_value * 0.3)
			
			if dist < actual_radius:
				grid.set_terrain(x, y, WorldGrid.TerrainType.WATER)
				grid.set_height(x, y, -2.0)  # Water is below ground level
				lake_cells.append(Vector2i(x, y))
				water_count += 1
	
	print("    Lake created: %d water cells" % water_count)

func _add_shore_areas(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Add sandy beach areas along shoreline"""
	var beach_width = 3  # cells
	
	print("    Adding beach/shore areas...")
	
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.get_terrain(x, y) == WorldGrid.TerrainType.GRASS:
				# Check if adjacent to water
				var near_water = false
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if dx == 0 and dy == 0:
							continue
						var nx = x + dx
						var ny = y + dy
						if grid.is_valid(nx, ny):
							if grid.get_terrain(nx, ny) == WorldGrid.TerrainType.WATER:
								near_water = true
								break
					if near_water:
						break
				
				if near_water:
					# Check distance to water (for beach width)
					var dist_to_water = _distance_to_nearest_water(grid, x, y)
					if dist_to_water <= beach_width:
						grid.set_terrain(x, y, WorldGrid.TerrainType.BEACH)
						# Flatten beach slightly
						grid.set_height(x, y, grid.get_height(x, y) * 0.7)

func _distance_to_nearest_water(grid: WorldGrid, x: int, y: int) -> int:
	"""Get distance to nearest water cell"""
	var min_dist = 999
	for water_cell in lake_cells:
		var dx = x - water_cell.x
		var dy = y - water_cell.y
		var dist = int(sqrt(dx * dx + dy * dy))
		if dist < min_dist:
			min_dist = dist
	return min_dist

func _create_shoreline_paths(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Create paths that follow the shoreline"""
	var num_paths = config.get("num_shore_paths", 2)
	var path_follows_shore = config.get("path_follows_shore", true)
	
	if not path_follows_shore:
		return
	
	print("    Creating shoreline paths...")
	
	# Find shore cells (grass/beach next to water)
	var shore_cells = []
	for y in range(grid.height):
		for x in range(grid.width):
			var terrain = grid.get_terrain(x, y)
			if terrain == WorldGrid.TerrainType.BEACH:
				shore_cells.append(Vector2i(x, y))
	
	if shore_cells.size() < 10:
		return
	
	# Create path along a section of shore
	var section_size = shore_cells.size() / max(1, num_paths)
	
	for i in range(num_paths):
		var start_idx = i * section_size
		var end_idx = min(start_idx + section_size, shore_cells.size() - 1)
		
		if start_idx < shore_cells.size() and end_idx < shore_cells.size():
			_create_shore_path_segment(grid, shore_cells, start_idx, end_idx)

func _create_shore_path_segment(grid: WorldGrid, shore_cells: Array, start_idx: int, end_idx: int):
	"""Create a path segment along shore"""
	for i in range(start_idx, end_idx):
		var cell = shore_cells[i]
		# Mark as path but keep the beach terrain
		# Actual path will be decorations/props later
		pass

func _mark_dock_areas(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Mark potential dock/pier locations"""
	var num_docks = config.get("num_docks", 5)
	
	print("    Marking %d potential dock locations..." % num_docks)
	
	# Find good dock spots (beach cells with deep water nearby)
	var dock_candidates = []
	
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.get_terrain(x, y) == WorldGrid.TerrainType.BEACH:
				# Check if water is nearby
				var water_nearby = false
				for dy in range(-3, 4):
					for dx in range(-3, 4):
						var nx = x + dx
						var ny = y + dy
						if grid.is_valid(nx, ny):
							if grid.get_terrain(nx, ny) == WorldGrid.TerrainType.WATER:
								water_nearby = true
								break
					if water_nearby:
						break
				
				if water_nearby:
					dock_candidates.append(Vector2i(x, y))
	
	# These are just potential spots - actual docks will be POIs
	# placed by the POI system

func place_required_poi(grid: WorldGrid, poi_type: String, tags: Array, rng: RandomNumberGenerator) -> POIData:
	"""Place a required POI at lakeside"""
	print("    Placing lakeside POI: ", poi_type)
	
	var poi = POIData.new(poi_type)
	for tag in tags:
		poi.tags.append(str(tag))
	poi.required = true
	poi.footprint_radius = _get_poi_footprint(poi_type)
	
	# Find location based on POI type
	var strategy = _get_placement_strategy(poi_type)
	
	var max_attempts = 100
	for attempt in range(max_attempts):
		var pos = _find_poi_location(grid, strategy, poi.footprint_radius, rng)
		
		if pos != Vector2i(-1, -1):
			if grid.reserve_area(pos.x, pos.y, poi.footprint_radius):
				poi.position = pos
				# Mark POI area
				for dy in range(-poi.footprint_radius, poi.footprint_radius + 1):
					for dx in range(-poi.footprint_radius, poi.footprint_radius + 1):
						if dx*dx + dy*dy <= poi.footprint_radius*poi.footprint_radius:
							var px = pos.x + dx
							var py = pos.y + dy
							if grid.is_valid(px, py):
								grid.set_occupancy(px, py, WorldGrid.OccupancyType.POI)
				print("      Placed at: ", pos)
				return poi
	
	push_error("Could not place lakeside POI: " + poi_type)
	return POIData.new()

func _get_poi_footprint(poi_type: String) -> int:
	"""Get footprint radius for lakeside POI types"""
	match poi_type:
		"dock", "pier":
			return 4
		"beach":
			return 10
		"fishing_spot":
			return 2
		"picnic_area":
			return 6
		"swimming_area":
			return 8
		"boathouse":
			return 6
		"marina":
			return 12
		_:
			return 4

func _get_placement_strategy(poi_type: String) -> String:
	"""Determine placement strategy for lakeside POI"""
	match poi_type:
		"dock", "pier", "boathouse", "marina":
			return "waterfront"  # Right at water's edge
		"beach", "swimming_area":
			return "shore"  # On beach/shore areas
		"fishing_spot":
			return "waterfront"  # At water's edge
		"picnic_area":
			return "near_shore"  # Close to shore but on grass
		"campsite":
			return "near_shore"
		_:
			return "near_shore"

func _find_poi_location(grid: WorldGrid, strategy: String, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location based on strategy"""
	match strategy:
		"waterfront":
			return _find_waterfront_location(grid, min_radius, rng)
		"shore":
			return _find_shore_location(grid, min_radius, rng)
		"near_shore":
			return _find_near_shore_location(grid, min_radius, rng)
		_:
			return grid.find_empty_spot(min_radius, 50, rng)

func _find_waterfront_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find spot right at water's edge (for docks, piers)"""
	# Find beach cells adjacent to water
	var waterfront_cells = []
	
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.get_terrain(x, y) == WorldGrid.TerrainType.BEACH:
				# Check if directly adjacent to water
				var adjacent_to_water = false
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if dx == 0 and dy == 0:
							continue
						var nx = x + dx
						var ny = y + dy
						if grid.is_valid(nx, ny):
							if grid.get_terrain(nx, ny) == WorldGrid.TerrainType.WATER:
								adjacent_to_water = true
								break
					if adjacent_to_water:
						break
				
				if adjacent_to_water:
					waterfront_cells.append(Vector2i(x, y))
	
	if waterfront_cells.is_empty():
		return Vector2i(-1, -1)
	
	# Try random waterfront cells
	for attempt in range(50):
		var cell = waterfront_cells[rng.randi() % waterfront_cells.size()]
		
		if grid.is_area_empty(cell.x, cell.y, min_radius):
			return cell
	
	return Vector2i(-1, -1)

func _find_shore_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find spot on beach/shore area"""
	for attempt in range(50):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		# Must be on beach (dirt terrain near water)
		if grid.get_terrain(x, y) == WorldGrid.TerrainType.BEACH:
			if grid.is_area_empty(x, y, min_radius):
				# Verify it's actually beach (near water)
				var dist_to_water = _distance_to_nearest_water(grid, x, y)
				if dist_to_water <= 5:
					return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_near_shore_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find spot near shore but on grass (for picnic areas, campsites)"""
	for attempt in range(50):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		# Must be on grass
		if grid.get_terrain(x, y) == WorldGrid.TerrainType.GRASS:
			if grid.is_area_empty(x, y, min_radius):
				# But close to water
				var dist_to_water = _distance_to_nearest_water(grid, x, y)
				if dist_to_water > 5 and dist_to_water < 30:  # Not too close, not too far
					return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func generate_buildings(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Lakeside has waterfront buildings"""
	print("  Generating lakeside structures...")
	# Buildings will be placed by template system

func get_biome_type() -> String:
	return "lakeside"

func get_lake_cells() -> Array[Vector2i]:
	"""Get water cells for visualization"""
	return lake_cells
