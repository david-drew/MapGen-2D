# mountain_generator.gd
# Generator for mountain locations with high elevation, sparse buildings, and wilderness features
class_name MountainGenerator
extends LocationGeneratorBase

var peak_locations: Array[Vector2i] = []
var ridge_paths: Array[Array] = []
var clearing_locations: Array[Vector2i] = []  # Store clearing positions for trail connections

func generate_foundation(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate mountainous foundation with peaks, ridges, and valleys"""
	print("  Generating mountain foundation...")
	
	# Generate mountainous heightmap
	_generate_mountain_heightmap(grid, config, rng)
	
	# Identify peaks and ridges
	_identify_peaks(grid, config, rng)
	
	# Add clearings for buildings (BEFORE trails, so trails can connect them)
	_create_clearings(grid, config, rng)
	
	# Create mountain trails/paths (AFTER clearings, connects them)
	_create_mountain_trails(grid, config, rng)
	
	# Mark lookout/watchtower locations
	_mark_lookout_points(grid, config, rng)

func _generate_mountain_heightmap(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate mountainous terrain with peaks and valleys"""
	var noise = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.008  # Lower frequency = larger mountains
	noise.fractal_octaves = 6  # More detail
	noise.fractal_lacunarity = 2.5
	noise.fractal_gain = 0.6
	
	# Secondary noise for variation
	var detail_noise = FastNoiseLite.new()
	detail_noise.seed = rng.randi()
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.frequency = 0.03
	
	var elevation_factor = config.get("elevation_factor", 1.5)  # How tall mountains are
	var ruggedness = config.get("ruggedness", 0.7)  # How rough terrain is
	
	print("    Generating mountainous terrain (elevation: %.1f, ruggedness: %.1f)..." % [elevation_factor, ruggedness])
	
	for y in range(grid.height):
		for x in range(grid.width):
			# Primary mountain shape
			var value = noise.get_noise_2d(x, y)
			value = (value + 1.0) * 0.5  # Normalize to 0-1
			
			# Add detail
			var detail = detail_noise.get_noise_2d(x, y) * 0.3
			value = value * (1.0 - ruggedness) + (value + detail) * ruggedness
			
			# Amplify to create dramatic elevation
			value = pow(value, 1.5) * 25.0 * elevation_factor
			
			grid.set_height(x, y, value)
			
			# Terrain type based on elevation
			if value > 18.0:
				grid.set_terrain(x, y, WorldGrid.TerrainType.ROCK)  # Rocky peaks
			elif value > 12.0:
				grid.set_terrain(x, y, WorldGrid.TerrainType.GRASS)  # Alpine meadows
			elif value > 6.0:
				grid.set_terrain(x, y, WorldGrid.TerrainType.FOREST)  # Forested slopes
			else:
				grid.set_terrain(x, y, WorldGrid.TerrainType.GRASS)  # Valleys

func _identify_peaks(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Find mountain peaks for potential watchtower/lookout placement"""
	var num_peaks = config.get("num_peaks", 3)
	var min_peak_separation = 30
	
	print("    Identifying mountain peaks...")
	
	peak_locations.clear()
	
	# Find local maxima
	var potential_peaks: Array[Dictionary] = []
	
	for y in range(5, grid.height - 5):
		for x in range(5, grid.width - 5):
			var height = grid.get_height(x, y)
			
			# Must be reasonably high
			if height < 15.0:
				continue
			
			# Check if it's higher than surroundings (local maximum)
			var is_peak = true
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					if dx == 0 and dy == 0:
						continue
					var neighbor_height = grid.get_height(x + dx, y + dy)
					if neighbor_height > height:
						is_peak = false
						break
				if not is_peak:
					break
			
			if is_peak:
				potential_peaks.append({
					"pos": Vector2i(x, y),
					"height": height
				})
	
	# Sort by height (tallest first)
	potential_peaks.sort_custom(func(a, b): return a.height > b.height)
	
	# Select peaks with minimum separation
	for peak in potential_peaks:
		if peak_locations.size() >= num_peaks:
			break
		
		var pos = peak.pos
		var too_close = false
		
		for existing_peak in peak_locations:
			var dist = pos.distance_to(existing_peak)
			if dist < min_peak_separation:
				too_close = true
				break
		
		if not too_close:
			peak_locations.append(pos)
	
	print("      Found %d peaks" % peak_locations.size())

func _create_mountain_trails(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Create hiking trails through the mountains"""
	var num_trails = config.get("num_trails", 2)
	var create_trails = config.get("create_trails", true)
	
	if not create_trails:
		return
	
	print("    Creating mountain trails...")
	
	# Connect clearings if we have them
	if clearing_locations.size() >= 2:
		# Connect adjacent clearings
		for i in range(clearing_locations.size() - 1):
			var start_clearing = clearing_locations[i]
			var end_clearing = clearing_locations[i + 1]
			
			_create_winding_path(grid, start_clearing, end_clearing, rng)
		
		# Also create some trails from clearings to peaks
		var trails_to_peaks = mini(num_trails, peak_locations.size())
		for i in range(trails_to_peaks):
			if i < clearing_locations.size() and i < peak_locations.size():
				_create_winding_path(grid, clearing_locations[i], peak_locations[i], rng)
	else:
		# Fallback: create trails from valleys to elevated areas
		for i in range(num_trails):
			var start_pos = _find_valley_location(grid, rng)
			if start_pos == Vector2i(-1, -1):
				continue
			
			var end_pos = _find_elevated_location(grid, start_pos, rng)
			if end_pos == Vector2i(-1, -1):
				continue
			
			_create_winding_path(grid, start_pos, end_pos, rng)

func _create_winding_path(grid: WorldGrid, start: Vector2i, end: Vector2i, rng: RandomNumberGenerator):
	"""Create a naturally winding mountain path"""
	var current = start
	var path: Array[Vector2i] = [start]
	var max_steps = 200
	var step_count = 0
	
	while current.distance_to(end) > 3 and step_count < max_steps:
		step_count += 1
		
		# Direction toward goal
		var direction = Vector2(end - current).normalized()
		
		# Add randomness for natural winding
		var angle_variance = rng.randf_range(-0.8, 0.8)
		var angle = atan2(direction.y, direction.x) + angle_variance
		
		# Next step
		var next_x = roundi(current.x + cos(angle) * 2)
		var next_y = roundi(current.y + sin(angle) * 2)
		var next = Vector2i(next_x, next_y)
		
		# Stay in bounds
		if next.x < 1 or next.x >= grid.width - 1 or next.y < 1 or next.y >= grid.height - 1:
			break
		
		# Mark as path (but don't override buildings/POIs)
		var occupancy = grid.get_occupancy(next.x, next.y)
		if occupancy == WorldGrid.OccupancyType.EMPTY:
			grid.set_terrain(next.x, next.y, WorldGrid.TerrainType.DIRT)  # Make path visible
			grid.set_path(next.x, next.y, true)
		
		path.append(next)
		current = next
	
	ridge_paths.append(path)

func _create_clearings(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Create small clearings for building placement"""
	var num_clearings = config.get("num_clearings", 5)
	var clearing_size = 8  # Radius
	
	print("    Creating %d clearings for structures..." % num_clearings)
	
	for i in range(num_clearings):
		# Find suitable location (moderate elevation, not too steep)
		var attempts = 0
		while attempts < 30:
			attempts += 1
			
			var x = rng.randi_range(clearing_size + 2, grid.width - clearing_size - 2)
			var y = rng.randi_range(clearing_size + 2, grid.height - clearing_size - 2)
			
			var height = grid.get_height(x, y)
			
			# Moderate elevation (not peak, not valley)
			if height < 6.0 or height > 16.0:
				continue
			
			# Check slope (not too steep)
			var max_height_diff = 0.0
			var suitable = true
			
			for dy in range(-clearing_size, clearing_size + 1):
				for dx in range(-clearing_size, clearing_size + 1):
					var check_x = x + dx
					var check_y = y + dy
					
					if check_x < 0 or check_x >= grid.width or check_y < 0 or check_y >= grid.height:
						suitable = false
						break
					
					var dist = sqrt(dx * dx + dy * dy)
					if dist <= clearing_size:
						var neighbor_height = grid.get_height(check_x, check_y)
						var height_diff = abs(neighbor_height - height)
						max_height_diff = max(max_height_diff, height_diff)
				
				if not suitable:
					break
			
			# Not too steep
			if max_height_diff > 3.0:
				continue
			
			if suitable:
				# Flatten the clearing slightly
				for dy in range(-clearing_size, clearing_size + 1):
					for dx in range(-clearing_size, clearing_size + 1):
						var dist = sqrt(dx * dx + dy * dy)
						if dist <= clearing_size:
							var clear_x = x + dx
							var clear_y = y + dy
							# Blend toward center height
							var current_height = grid.get_height(clear_x, clear_y)
							var blended_height = lerp(current_height, height, 0.6)
							grid.set_height(clear_x, clear_y, blended_height)
							grid.set_terrain(clear_x, clear_y, WorldGrid.TerrainType.GRASS)
				
				# Store clearing location for trail connections
				clearing_locations.append(Vector2i(x, y))
				break

func _mark_lookout_points(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Mark potential locations for watchtowers/lookouts on peaks"""
	print("    Marking %d lookout points on peaks..." % peak_locations.size())
	
	# These will be available for watchtower placement
	# The template system will place watchtowers at these optimal locations

func _find_valley_location(grid: WorldGrid, rng: RandomNumberGenerator) -> Vector2i:
	"""Find a location in a valley (lower elevation)"""
	for attempt in range(30):
		var x = rng.randi_range(10, grid.width - 10)
		var y = rng.randi_range(10, grid.height - 10)
		
		var height = grid.get_height(x, y)
		
		if height < 8.0 and height > 2.0:  # Valley but not too low
			return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_elevated_location(grid: WorldGrid, start: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	"""Find a higher elevation location away from start"""
	var best_pos = Vector2i(-1, -1)
	var best_height = -999.0
	
	for attempt in range(50):
		var x = rng.randi_range(10, grid.width - 10)
		var y = rng.randi_range(10, grid.height - 10)
		
		var pos = Vector2i(x, y)
		var dist_from_start = pos.distance_to(start)
		
		# Must be reasonably far from start
		if dist_from_start < 40:
			continue
		
		var height = grid.get_height(x, y)
		
		# Higher is better
		if height > best_height and height > 10.0:
			best_height = height
			best_pos = pos
	
	return best_pos

func _distance_to_nearest_peak(grid: WorldGrid, x: int, y: int) -> float:
	"""Calculate distance to nearest peak"""
	if peak_locations.is_empty():
		return 999.0
	
	var min_dist = 999.0
	for peak in peak_locations:
		var dist = Vector2i(x, y).distance_to(peak)
		min_dist = min(min_dist, dist)
	
	return min_dist

func get_poi_placement_strategy(poi_type: String) -> String:
	"""Mountain-specific POI placement strategies"""
	match poi_type:
		"watchtower", "fire_lookout", "observation_point":
			return "peak"  # On mountain peaks
		"observatory":
			return "peak"  # On highest peaks
		"trailhead", "parking_area":
			return "valley"  # At lower elevations
		"rest_stop", "scenic_overlook", "viewpoint":
			return "elevated"  # Mid-elevation with good views
		"cave_entrance", "mine_entrance":
			return "cliff_side"  # On rocky slopes
		"ranger_station", "trail_marker":
			return "clearing"  # In clearings
		_:
			return "clearing"  # Default to clearings

func find_poi_location(grid: WorldGrid, poi_type: String, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find appropriate location based on POI type"""
	var strategy = get_poi_placement_strategy(poi_type)
	
	match strategy:
		"peak":
			return _find_peak_location(grid, min_radius, rng)
		"valley":
			return _find_valley_poi_location(grid, min_radius, rng)
		"elevated":
			return _find_elevated_poi_location(grid, min_radius, rng)
		"cliff_side":
			return _find_cliff_location(grid, min_radius, rng)
		"clearing":
			return _find_clearing_location(grid, min_radius, rng)
		_:
			return _find_clearing_location(grid, min_radius, rng)

func _find_peak_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location on or near a peak"""
	if peak_locations.is_empty():
		return Vector2i(-1, -1)
	
	# Shuffle peaks for variety
	var shuffled_peaks = peak_locations.duplicate()
	shuffled_peaks.shuffle()
	
	for peak in shuffled_peaks:
		if grid.is_area_empty(peak.x, peak.y, min_radius):
			return peak
	
	return Vector2i(-1, -1)

func _find_valley_poi_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location in valley"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		var height = grid.get_height(x, y)
		
		if height < 7.0 and height > 2.0:
			if grid.is_area_empty(x, y, min_radius):
				return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_elevated_poi_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location at mid-elevation for scenic views"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		var height = grid.get_height(x, y)
		
		# Mid-elevation (10-16 range)
		if height > 10.0 and height < 16.0:
			if grid.is_area_empty(x, y, min_radius):
				return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_cliff_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location on rocky cliff side"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		# Must be rocky terrain
		if grid.get_terrain(x, y) != WorldGrid.TerrainType.ROCK:
			continue
		
		var height = grid.get_height(x, y)
		
		# Check for cliff (steep drop nearby)
		var has_cliff = false
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				if x + dx < 0 or x + dx >= grid.width or y + dy < 0 or y + dy >= grid.height:
					continue
				var neighbor_height = grid.get_height(x + dx, y + dy)
				if height - neighbor_height > 4.0:  # Steep drop
					has_cliff = true
					break
			if has_cliff:
				break
		
		if has_cliff and grid.is_area_empty(x, y, min_radius):
			return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_clearing_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location in a clearing (flat grass area)"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		# Must be grass (clearings)
		if grid.get_terrain(x, y) != WorldGrid.TerrainType.GRASS:
			continue
		
		var height = grid.get_height(x, y)
		
		# Moderate elevation
		if height > 5.0 and height < 15.0:
			# Check that area is relatively flat
			var max_slope = 0.0
			for dy in range(-min_radius, min_radius + 1):
				for dx in range(-min_radius, min_radius + 1):
					var check_x = x + dx
					var check_y = y + dy
					if check_x < 0 or check_x >= grid.width or check_y < 0 or check_y >= grid.height:
						continue
					var neighbor_height = grid.get_height(check_x, check_y)
					max_slope = max(max_slope, abs(height - neighbor_height))
			
			if max_slope < 2.0:  # Relatively flat
				if grid.is_area_empty(x, y, min_radius):
					return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func place_required_poi(grid: WorldGrid, poi_type: String, tags: Array, rng: RandomNumberGenerator) -> POIData:
	"""Place a required POI and return its data"""
	var min_radius = 3
	
	# Find appropriate location based on POI type
	var location = find_poi_location(grid, poi_type, min_radius, rng)
	
	if location == Vector2i(-1, -1):
		print("    WARNING: Could not place mountain POI: %s" % poi_type)
		return POIData.new()  # Return invalid POI
	
	# Reserve the area
	if not grid.reserve_area(location.x, location.y, min_radius):
		print("    WARNING: Could not reserve area for POI: %s" % poi_type)
		return POIData.new()
	
	# Mark center as POI
	grid.set_occupancy(location.x, location.y, WorldGrid.OccupancyType.POI)
	
	# Create POI data
	var poi = POIData.new()
	poi.poi_type = poi_type
	poi.position = location
	poi.footprint_radius = min_radius
	
	# Add tags individually (POIData.tags is Array[String])
	for tag in tags:
		poi.tags.append(str(tag))
	
	return poi

func generate_buildings(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Mountains have very few buildings - placed by template system"""
	print("  Generating mountain structures...")
	# Buildings will be placed by template system

func get_biome_type() -> String:
	return "mountain"

func get_peak_locations() -> Array[Vector2i]:
	"""Get peak locations for visualization"""
	return peak_locations

func get_clearing_locations() -> Array[Vector2i]:
	"""Get clearing locations for visualization"""
	return clearing_locations
