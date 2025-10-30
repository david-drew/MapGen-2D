# desert_generator.gd
# Generator for desert locations with sand dunes, oases, and sparse vegetation
class_name DesertGenerator
extends LocationGeneratorBase

var oasis_locations: Array[Vector2i] = []
var dune_peaks: Array[Vector2i] = []

func generate_foundation(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate desert foundation with dunes, sand, and oases"""
	print("  Generating desert foundation...")
	
	# Generate base desert terrain with dunes
	_generate_desert_terrain(grid, config, rng)
	
	# Create oases (water sources with vegetation)
	_create_oases(grid, config, rng)
	
	# Add rock formations and outcrops
	_add_rock_formations(grid, config, rng)
	
	# Create desert paths (often near dune valleys or between oases)
	_create_desert_trails(grid, config, rng)

func _generate_desert_terrain(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate sandy terrain with dunes"""
	var dune_intensity = config.get("dune_intensity", 0.60)
	
	print("    Generating desert terrain (dune intensity: %.2f)..." % dune_intensity)
	
	# Use multiple noise layers for natural dune formation
	var noise_large = FastNoiseLite.new()
	noise_large.seed = rng.randi()
	noise_large.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_large.frequency = 0.02  # Large dunes
	noise_large.fractal_octaves = 2
	
	var noise_small = FastNoiseLite.new()
	noise_small.seed = rng.randi()
	noise_small.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_small.frequency = 0.08  # Small ripples
	noise_small.fractal_octaves = 2
	
	dune_peaks.clear()
	
	for y in range(grid.height):
		for x in range(grid.width):
			# Combine noise for natural dune patterns
			var large_noise = noise_large.get_noise_2d(x, y)
			large_noise = (large_noise + 1.0) * 0.5  # Normalize to 0-1
			
			var small_noise = noise_small.get_noise_2d(x, y)
			small_noise = (small_noise + 1.0) * 0.5
			
			# Blend noises
			var height_value = (large_noise * 0.7 + small_noise * 0.3) * dune_intensity
			
			# Most of desert is sand
			grid.set_terrain(x, y, WorldGrid.TerrainType.SAND)
			grid.set_height(x, y, height_value * 8.0)  # Dunes can be 0-8m high
			
			# Track dune peaks for potential placement locations
			if height_value > 0.75:
				if rng.randf() < 0.05:  # Only some peaks tracked
					dune_peaks.append(Vector2i(x, y))

func _create_oases(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Create oases with water and vegetation"""
	var oasis_count = config.get("oasis_count", 2)
	var oasis_size = 8  # Radius
	
	print("    Creating %d oases..." % oasis_count)
	
	oasis_locations.clear()
	
	for i in range(oasis_count):
		var attempts = 0
		while attempts < 30:
			attempts += 1
			
			var ox = rng.randi_range(oasis_size + 5, grid.width - oasis_size - 5)
			var oy = rng.randi_range(oasis_size + 5, grid.height - oasis_size - 5)
			
			# Check if too close to existing oases
			var too_close = false
			for existing in oasis_locations:
				if Vector2i(ox, oy).distance_to(existing) < oasis_size * 3:
					too_close = true
					break
			
			if too_close:
				continue
			
			# Create the oasis
			# Center: water
			var water_radius = oasis_size * 0.4
			for dy in range(-int(water_radius), int(water_radius) + 1):
				for dx in range(-int(water_radius), int(water_radius) + 1):
					var dist = sqrt(dx * dx + dy * dy)
					if dist <= water_radius:
						var wx = ox + dx
						var wy = oy + dy
						
						if wx >= 0 and wx < grid.width and wy >= 0 and wy < grid.height:
							grid.set_terrain(wx, wy, WorldGrid.TerrainType.WATER)
							grid.set_height(wx, wy, -0.5)  # Slightly below ground
			
			# Surrounding ring: grass/vegetation
			for dy in range(-oasis_size, oasis_size + 1):
				for dx in range(-oasis_size, oasis_size + 1):
					var dist = sqrt(dx * dx + dy * dy)
					if dist > water_radius and dist <= oasis_size:
						var gx = ox + dx
						var gy = oy + dy
						
						if gx >= 0 and gx < grid.width and gy >= 0 and gy < grid.height:
							# Gradient from grass to sand
							var blend = (dist - water_radius) / (oasis_size - water_radius)
							if blend < 0.6 or (blend < 0.9 and rng.randf() < 0.5):
								grid.set_terrain(gx, gy, WorldGrid.TerrainType.GRASS)
								grid.set_height(gx, gy, 0.0)
			
			oasis_locations.append(Vector2i(ox, oy))
			break

func _add_rock_formations(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Add rocky outcrops and formations"""
	var num_formations = config.get("num_rock_formations", 4)
	
	print("    Adding %d rock formations..." % num_formations)
	
	for i in range(num_formations):
		var attempts = 0
		while attempts < 20:
			attempts += 1
			
			var rx = rng.randi_range(10, grid.width - 10)
			var ry = rng.randi_range(10, grid.height - 10)
			
			# Avoid oases
			var in_oasis = false
			for oasis in oasis_locations:
				if Vector2i(rx, ry).distance_to(oasis) < 15:
					in_oasis = true
					break
			
			if in_oasis:
				continue
			
			# Create rock formation
			var rock_size = rng.randi_range(3, 6)
			for dy in range(-rock_size, rock_size + 1):
				for dx in range(-rock_size, rock_size + 1):
					var dist = sqrt(dx * dx + dy * dy)
					if dist <= rock_size and rng.randf() < 0.7:  # Irregular shape
						var rock_x = rx + dx
						var rock_y = ry + dy
						
						if rock_x >= 0 and rock_x < grid.width and rock_y >= 0 and rock_y < grid.height:
							grid.set_terrain(rock_x, rock_y, WorldGrid.TerrainType.ROCK)
							grid.set_height(rock_x, rock_y, rng.randf_range(1.0, 3.0))
			
			break

func _create_desert_trails(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Create trails through the desert"""
	if oasis_locations.size() < 2:
		return
	
	print("    Creating desert trails...")
	
	# Connect some oases with trails
	var num_trails = mini(2, oasis_locations.size() - 1)
	
	for i in range(num_trails):
		var start_oasis = oasis_locations[i]
		var end_oasis = oasis_locations[i + 1]
		
		_create_winding_trail(grid, start_oasis, end_oasis, rng)

func _create_winding_trail(grid: WorldGrid, start: Vector2i, end: Vector2i, rng: RandomNumberGenerator):
	"""Create a naturally winding trail between two points"""
	var current = start
	var max_steps = 400
	var step_count = 0
	
	while current.distance_to(end) > 3 and step_count < max_steps:
		step_count += 1
		
		# Direction toward goal
		var direction = Vector2(end - current).normalized()
		
		# Add randomness for natural winding
		var angle_variance = rng.randf_range(-0.5, 0.5)
		var angle = atan2(direction.y, direction.x) + angle_variance
		
		# Take a step
		var next_x = roundi(current.x + cos(angle) * 1.5)
		var next_y = roundi(current.y + sin(angle) * 1.5)
		var next = Vector2i(next_x, next_y)
		
		# Stay in bounds
		if next.x < 1 or next.x >= grid.width - 1 or next.y < 1 or next.y >= grid.height - 1:
			break
		
		# Mark as path (packed sand trail)
		var occupancy = grid.get_occupancy(next.x, next.y)
		if occupancy == WorldGrid.OccupancyType.EMPTY:
			grid.set_terrain(next.x, next.y, WorldGrid.TerrainType.DIRT)
			grid.set_path(next.x, next.y, true)
			grid.set_height(next.x, next.y, grid.get_height(next.x, next.y) * 0.8)  # Flatten slightly
		
		current = next

func get_poi_placement_strategy(poi_type: String) -> String:
	"""Desert-specific POI placement strategies"""
	match poi_type:
		"oasis", "well", "water_source":
			return "oasis"
		"cactus_grove", "dead_tree":
			return "desert"
		"tent", "bedouin_camp", "nomad_camp":
			return "flat_area"
		"ancient_ruins", "temple_ruins", "abandoned_village":
			return "elevated"
		"merchant_stop", "trading_post":
			return "trail"
		"mining_site", "quarry":
			return "rock_formation"
		"lookout_tower", "watchtower":
			return "dune_peak"
		"shelter", "cave":
			return "rock_formation"
		_:
			return "flat_area"

func find_poi_location(grid: WorldGrid, poi_type: String, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find appropriate location based on POI type"""
	var strategy = get_poi_placement_strategy(poi_type)
	
	match strategy:
		"oasis":
			return _find_oasis_location(grid, min_radius, rng)
		"desert":
			return _find_open_desert_location(grid, min_radius, rng)
		"flat_area":
			return _find_flat_area_location(grid, min_radius, rng)
		"elevated":
			return _find_elevated_location(grid, min_radius, rng)
		"trail":
			return _find_trail_location(grid, min_radius, rng)
		"rock_formation":
			return _find_rock_location(grid, min_radius, rng)
		"dune_peak":
			return _find_dune_peak_location(grid, min_radius, rng)
		_:
			return _find_flat_area_location(grid, min_radius, rng)

func _find_oasis_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location near an oasis"""
	if not oasis_locations.is_empty():
		var shuffled = oasis_locations.duplicate()
		shuffled.shuffle()
		
		for oasis in shuffled:
			# Try to place near the oasis (in the grass ring)
			for attempt in range(20):
				var angle = rng.randf() * TAU
				var distance = rng.randf_range(8, 12)
				var x = int(oasis.x + cos(angle) * distance)
				var y = int(oasis.y + sin(angle) * distance)
				
				if x >= min_radius and x < grid.width - min_radius and y >= min_radius and y < grid.height - min_radius:
					if grid.get_terrain(x, y) == WorldGrid.TerrainType.GRASS:
						if grid.is_area_empty(x, y, min_radius):
							return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_open_desert_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location in open desert"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		if grid.get_terrain(x, y) == WorldGrid.TerrainType.SAND:
			# Not near oasis
			var near_oasis = false
			for oasis in oasis_locations:
				if Vector2i(x, y).distance_to(oasis) < 20:
					near_oasis = true
					break
			
			if not near_oasis and grid.is_area_empty(x, y, min_radius):
				return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_flat_area_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find relatively flat location in desert"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		if grid.get_terrain(x, y) == WorldGrid.TerrainType.SAND:
			var height = grid.get_height(x, y)
			
			# Check that surrounding area is relatively flat
			var is_flat = true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var check_x = x + dx
					var check_y = y + dy
					if check_x >= 0 and check_x < grid.width and check_y >= 0 and check_y < grid.height:
						var check_height = grid.get_height(check_x, check_y)
						if abs(check_height - height) > 1.5:
							is_flat = false
							break
				if not is_flat:
					break
			
			if is_flat and grid.is_area_empty(x, y, min_radius):
				return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_elevated_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find elevated location (high dune or rock)"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		var height = grid.get_height(x, y)
		
		# Must be elevated
		if height > 4.0:
			if grid.is_area_empty(x, y, min_radius):
				return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_trail_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location along a trail"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		if grid.is_path(x, y):
			if grid.is_area_empty(x, y, min_radius):
				return Vector2i(x, y)
		
		# Or near a path
		var near_path = false
		for dy in range(-3, 4):
			for dx in range(-3, 4):
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

func _find_rock_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location near rocks"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		# Check for nearby rocks
		var near_rock = false
		for dy in range(-5, 6):
			for dx in range(-5, 6):
				var check_x = x + dx
				var check_y = y + dy
				if check_x >= 0 and check_x < grid.width and check_y >= 0 and check_y < grid.height:
					if grid.get_terrain(check_x, check_y) == WorldGrid.TerrainType.ROCK:
						near_rock = true
						break
			if near_rock:
				break
		
		if near_rock and grid.is_area_empty(x, y, min_radius):
			return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_dune_peak_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location at a dune peak"""
	if not dune_peaks.is_empty():
		var shuffled = dune_peaks.duplicate()
		shuffled.shuffle()
		
		for peak in shuffled:
			if grid.is_area_empty(peak.x, peak.y, min_radius):
				return peak
	
	# Fallback to elevated location
	return _find_elevated_location(grid, min_radius, rng)

func place_poi(grid: WorldGrid, poi_type: String, tags: Array, required: bool, rng: RandomNumberGenerator) -> POIData:
	"""Place a Point of Interest in the desert"""
	var min_radius = 3
	var location = find_poi_location(grid, poi_type, min_radius, rng)
	
	if location == Vector2i(-1, -1):
		if required:
			push_warning("Failed to place required POI: %s" % poi_type)
		return null
	
	# Mark area as occupied (circular footprint)
	for dy in range(-min_radius, min_radius + 1):
		for dx in range(-min_radius, min_radius + 1):
			if dx*dx + dy*dy <= min_radius*min_radius:
				var x = location.x + dx
				var y = location.y + dy
				if x >= 0 and x < grid.width and y >= 0 and y < grid.height:
					grid.set_occupancy(x, y, WorldGrid.OccupancyType.POI)
	
	# Create POI data
	var poi = POIData.new(poi_type, location, min_radius)
	# Convert tags array to typed array
	for tag in tags:
		poi.tags.append(str(tag))
	poi.required = required
	
	return poi

func place_optional_poi(grid: WorldGrid, poi_type: String, rng: RandomNumberGenerator) -> POIData:
	"""Place an optional POI"""
	return place_poi(grid, poi_type, [], false, rng)

func place_building(grid: WorldGrid, building_type: String, size: Vector2i, tags: Array, rng: RandomNumberGenerator) -> BuildingData:
	"""Place a building in the desert"""
	var max_attempts = 30
	
	for attempt in range(max_attempts):
		# Try to find a suitable location (flat areas preferred)
		var location = _find_building_location(grid, size, rng)
		
		if location == Vector2i(-1, -1):
			continue
		
		# Check if we can place building here
		if _can_place_building(grid, location, size):
			# Mark area as occupied
			_mark_building_footprint(grid, location, size)
			
			# Create building data
			var building = BuildingData.new(building_type, location, size)
			#building.tags = tags
			for tag in tags:
				building.tags.append(str(tag))
			
			return building
	
	return null

func _find_building_location(grid: WorldGrid, size: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	"""Find a suitable location for a building"""
	var half_size = size / 2
	var margin = maxi(half_size.x, half_size.y) + 2
	
	for attempt in range(40):
		var x = rng.randi_range(margin, grid.width - margin - 1)
		var y = rng.randi_range(margin, grid.height - margin - 1)
		
		# Prefer flat areas or near oases
		var terrain = grid.get_terrain(x, y)
		var height = grid.get_height(x, y)
		
		# Buildings should be on flat sand or near oases (grass)
		if terrain == WorldGrid.TerrainType.SAND and height < 2.0:
			return Vector2i(x, y)
		elif terrain == WorldGrid.TerrainType.GRASS:
			return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _can_place_building(grid: WorldGrid, center: Vector2i, size: Vector2i) -> bool:
	"""Check if building can be placed at location"""
	var half_size = size / 2
	
	for dy in range(-half_size.y, half_size.y + 1):
		for dx in range(-half_size.x, half_size.x + 1):
			var check_x = center.x + dx
			var check_y = center.y + dy
			
			if check_x < 0 or check_x >= grid.width or check_y < 0 or check_y >= grid.height:
				return false
			
			# Check if cell is empty
			if grid.get_occupancy(check_x, check_y) != WorldGrid.OccupancyType.EMPTY:
				return false
			
			# Check terrain is suitable
			var terrain = grid.get_terrain(check_x, check_y)
			if terrain == WorldGrid.TerrainType.WATER or terrain == WorldGrid.TerrainType.ROCK:
				return false
	
	return true

func _mark_building_footprint(grid: WorldGrid, center: Vector2i, size: Vector2i):
	"""Mark grid cells as occupied by building"""
	var half_size = size / 2
	
	for dy in range(-half_size.y, half_size.y + 1):
		for dx in range(-half_size.x, half_size.x + 1):
			var x = center.x + dx
			var y = center.y + dy
			if x >= 0 and x < grid.width and y >= 0 and y < grid.height:
				grid.set_occupancy(x, y, WorldGrid.OccupancyType.BUILDING)

func generate_buildings(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Deserts have very few buildings - placed by template system"""
	print("  Generating desert structures...")
	# Buildings will be placed by template system

func get_biome_type() -> String:
	return "desert"

func get_oasis_locations() -> Array[Vector2i]:
	"""Get oasis locations for visualization"""
	return oasis_locations
