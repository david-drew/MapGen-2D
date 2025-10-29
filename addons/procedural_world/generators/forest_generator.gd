# forest_generator.gd
# Generator for forest locations with dense trees and clearings
class_name ForestGenerator
extends LocationGeneratorBase

var clearing_locations: Array[Vector2i] = []

func generate_foundation(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate forest foundation with trees and clearings"""
	print("  Generating forest foundation...")
	
	# Generate base forest terrain
	_generate_forest_terrain(grid, config, rng)
	
	# Create clearings for buildings and activities
	_create_clearings(grid, config, rng)
	
	# Add natural water features (ponds)
	_add_water_features(grid, config, rng)
	
	# Create forest paths
	_create_forest_paths(grid, config, rng)

func _generate_forest_terrain(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate dense forest coverage"""
	var tree_density = config.get("tree_density", 0.70)
	
	print("    Generating forest terrain (density: %.2f)..." % tree_density)
	
	# Use noise for natural forest distribution
	var noise = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05
	noise.fractal_octaves = 3
	
	for y in range(grid.height):
		for x in range(grid.width):
			var noise_value = noise.get_noise_2d(x, y)
			noise_value = (noise_value + 1.0) * 0.5  # Normalize to 0-1
			
			# Most of the area is forest
			if noise_value < tree_density:
				grid.set_terrain(x, y, WorldGrid.TerrainType.FOREST)
				grid.set_height(x, y, noise_value * 3.0)  # Gentle terrain variation
			else:
				# Open areas / natural clearings
				grid.set_terrain(x, y, WorldGrid.TerrainType.GRASS)
				grid.set_height(x, y, noise_value * 2.0)

func _create_clearings(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Create open clearings in the forest"""
	var clearing_count = config.get("clearing_count", 5)
	var clearing_size = 12  # Radius
	
	print("    Creating %d clearings..." % clearing_count)
	
	clearing_locations.clear()
	
	for i in range(clearing_count):
		# Find a spot for clearing
		var attempts = 0
		while attempts < 30:
			attempts += 1
			
			var cx = rng.randi_range(clearing_size + 5, grid.width - clearing_size - 5)
			var cy = rng.randi_range(clearing_size + 5, grid.height - clearing_size - 5)
			
			# Check if too close to existing clearings
			var too_close = false
			for existing in clearing_locations:
				if Vector2i(cx, cy).distance_to(existing) < clearing_size * 2:
					too_close = true
					break
			
			if too_close:
				continue
			
			# Create the clearing
			for dy in range(-clearing_size, clearing_size + 1):
				for dx in range(-clearing_size, clearing_size + 1):
					var dist = sqrt(dx * dx + dy * dy)
					if dist <= clearing_size:
						var clear_x = cx + dx
						var clear_y = cy + dy
						
						if clear_x >= 0 and clear_x < grid.width and clear_y >= 0 and clear_y < grid.height:
							# Blend edge for natural look
							if dist > clearing_size - 3:
								# Edge of clearing - sometimes keep as forest
								if rng.randf() < 0.6:
									grid.set_terrain(clear_x, clear_y, WorldGrid.TerrainType.GRASS)
							else:
								# Center of clearing - always grass
								grid.set_terrain(clear_x, clear_y, WorldGrid.TerrainType.GRASS)
							
							# Flatten slightly
							var current_height = grid.get_height(clear_x, clear_y)
							grid.set_height(clear_x, clear_y, current_height * 0.7)
			
			clearing_locations.append(Vector2i(cx, cy))
			break

func _add_water_features(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Add small ponds to the forest"""
	var num_ponds = config.get("num_ponds", 2)
	
	print("    Adding %d water features..." % num_ponds)
	
	for i in range(num_ponds):
		var attempts = 0
		while attempts < 20:
			attempts += 1
			
			var px = rng.randi_range(15, grid.width - 15)
			var py = rng.randi_range(15, grid.height - 15)
			
			# Avoid clearings
			var in_clearing = false
			for clearing in clearing_locations:
				if Vector2i(px, py).distance_to(clearing) < 20:
					in_clearing = true
					break
			
			if in_clearing:
				continue
			
			# Create small pond
			var pond_size = rng.randi_range(4, 7)
			for dy in range(-pond_size, pond_size + 1):
				for dx in range(-pond_size, pond_size + 1):
					var dist = sqrt(dx * dx + dy * dy)
					if dist <= pond_size:
						var water_x = px + dx
						var water_y = py + dy
						
						if water_x >= 0 and water_x < grid.width and water_y >= 0 and water_y < grid.height:
							grid.set_terrain(water_x, water_y, WorldGrid.TerrainType.WATER)
							grid.set_height(water_x, water_y, -1.0)  # Below ground level
			
			break

func _create_forest_paths(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Create winding paths through the forest"""
	var path_density = config.get("path_density", 0.05)
	
	if clearing_locations.size() < 2:
		return
	
	print("    Creating forest paths...")
	
	# Connect some clearings with paths
	var num_paths = mini(3, clearing_locations.size() - 1)
	
	for i in range(num_paths):
		var start_clearing = clearing_locations[i]
		var end_clearing = clearing_locations[i + 1]
		
		_create_winding_path(grid, start_clearing, end_clearing, rng)

func _create_winding_path(grid: WorldGrid, start: Vector2i, end: Vector2i, rng: RandomNumberGenerator):
	"""Create a naturally winding path between two points"""
	var current = start
	var max_steps = 300
	var step_count = 0
	
	while current.distance_to(end) > 3 and step_count < max_steps:
		step_count += 1
		
		# Direction toward goal
		var direction = (end - current).normalized()
		
		# Add randomness for natural winding
		var angle_variance = rng.randf_range(-0.6, 0.6)
		var angle = atan2(direction.y, direction.x) + angle_variance
		
		# Take a step
		var next_x = roundi(current.x + cos(angle) * 1.5)
		var next_y = roundi(current.y + sin(angle) * 1.5)
		var next = Vector2i(next_x, next_y)
		
		# Stay in bounds
		if next.x < 1 or next.x >= grid.width - 1 or next.y < 1 or next.y >= grid.height - 1:
			break
		
		# Mark as path (dirt trail through forest)
		var occupancy = grid.get_occupancy(next.x, next.y)
		if occupancy == WorldGrid.OccupancyType.EMPTY:
			grid.set_terrain(next.x, next.y, WorldGrid.TerrainType.DIRT)
			grid.set_path(next.x, next.y, true)
		
		current = next

func get_poi_placement_strategy(poi_type: String) -> String:
	"""Forest-specific POI placement strategies"""
	match poi_type:
		"campsite", "fire_pit":
			return "clearing"  # In open areas
		"pond", "stream":
			return "water"  # Near water
		"old_tree", "ancient_tree":
			return "forest"  # Deep in forest
		"hunter_blind", "tree_stand":
			return "forest_edge"  # Edge of forest/clearing
		"trail_marker", "sign":
			return "path"  # Along paths
		"hermit_hut", "cabin":
			return "clearing"  # In clearings
		_:
			return "clearing"  # Default to clearings

func find_poi_location(grid: WorldGrid, poi_type: String, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find appropriate location based on POI type"""
	var strategy = get_poi_placement_strategy(poi_type)
	
	match strategy:
		"clearing":
			return _find_clearing_location(grid, min_radius, rng)
		"water":
			return _find_water_location(grid, min_radius, rng)
		"forest":
			return _find_deep_forest_location(grid, min_radius, rng)
		"forest_edge":
			return _find_forest_edge_location(grid, min_radius, rng)
		"path":
			return _find_path_location(grid, min_radius, rng)
		_:
			return _find_clearing_location(grid, min_radius, rng)

func _find_clearing_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location in a clearing"""
	# Try clearings first
	if not clearing_locations.is_empty():
		var shuffled = clearing_locations.duplicate()
		shuffled.shuffle()
		
		for clearing in shuffled:
			if grid.is_area_empty(clearing.x, clearing.y, min_radius):
				return clearing
	
	# Fall back to any grass area
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		if grid.get_terrain(x, y) == WorldGrid.TerrainType.GRASS:
			if grid.is_area_empty(x, y, min_radius):
				return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_water_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location near water"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		# Must be grass (near water, not in water)
		if grid.get_terrain(x, y) != WorldGrid.TerrainType.GRASS:
			continue
		
		# Check for nearby water
		var near_water = false
		for dy in range(-5, 6):
			for dx in range(-5, 6):
				var check_x = x + dx
				var check_y = y + dy
				if check_x >= 0 and check_x < grid.width and check_y >= 0 and check_y < grid.height:
					if grid.get_terrain(check_x, check_y) == WorldGrid.TerrainType.WATER:
						near_water = true
						break
			if near_water:
				break
		
		if near_water and grid.is_area_empty(x, y, min_radius):
			return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_deep_forest_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location deep in forest"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		# Must be in forest
		if grid.get_terrain(x, y) != WorldGrid.TerrainType.FOREST:
			continue
		
		# Check that surroundings are also forest (deep in woods)
		var forest_count = 0
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var check_x = x + dx
				var check_y = y + dy
				if check_x >= 0 and check_x < grid.width and check_y >= 0 and check_y < grid.height:
					if grid.get_terrain(check_x, check_y) == WorldGrid.TerrainType.FOREST:
						forest_count += 1
		
		# Surrounded by forest
		if forest_count > 30 and grid.is_area_empty(x, y, min_radius):
			return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_forest_edge_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location at forest/clearing edge"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		# Must be in forest
		if grid.get_terrain(x, y) != WorldGrid.TerrainType.FOREST:
			continue
		
		# Check for nearby grass (edge condition)
		var near_grass = false
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var check_x = x + dx
				var check_y = y + dy
				if check_x >= 0 and check_x < grid.width and check_y >= 0 and check_y < grid.height:
					if grid.get_terrain(check_x, check_y) == WorldGrid.TerrainType.GRASS:
						near_grass = true
						break
			if near_grass:
				break
		
		if near_grass and grid.is_area_empty(x, y, min_radius):
			return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_path_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location along a path"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		# Must be on or near a path
		if grid.is_path(x, y):
			if grid.is_area_empty(x, y, min_radius):
				return Vector2i(x, y)
		
		# Or near a path
		var near_path = false
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var check_x = x + dx
				var check_y = y + dy
				if check_x >= 0 and check_x < grid.width and check_y >= 0 and check_y < grid.height:
					if grid.is_path(check_x, check_y):
						near_path = true
						break
			if near_path:
				break
		
		if near_path and grid.is_area_empty(x, y, min_radius):
			return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func generate_buildings(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Forests have very few buildings - placed by template system"""
	print("  Generating forest structures...")
	# Buildings will be placed by template system

func get_biome_type() -> String:
	return "forest"

func get_clearing_locations() -> Array[Vector2i]:
	"""Get clearing locations for visualization"""
	return clearing_locations
