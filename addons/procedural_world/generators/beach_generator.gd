# beach_generator.gd
# Generator for beach/coastal locations with sand, water, palms, and tide pools
class_name BeachGenerator
extends LocationGeneratorBase

var beach_access_points: Array[Vector2i] = []
var tide_pools: Array[Vector2i] = []
var rock_formations: Array[Vector2i] = []

func generate_foundation(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate beach foundation with water, sand, and coastal features"""
	print("  Generating beach foundation...")
	
	# Generate base coastal terrain
	_generate_beach_terrain(grid, config, rng)
	
	# Add tide pools and rock formations
	_create_tide_pools(grid, config, rng)
	
	# Add palm tree clusters and vegetation
	_add_coastal_vegetation(grid, config, rng)
	
	# Create beach paths and boardwalks
	_create_beach_paths(grid, config, rng)

func _generate_beach_terrain(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate coastal terrain with water-to-sand transition"""
	var water_level = config.get("water_level", 0.40)  # Portion that's water
	var beach_width = config.get("beach_width", 0.25)  # Width of sandy beach
	
	print("    Generating beach terrain...")
	
	# Use noise for natural coastline
	var noise_coast = FastNoiseLite.new()
	noise_coast.seed = rng.randi()
	noise_coast.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_coast.frequency = 0.03
	noise_coast.fractal_octaves = 3
	
	# Determine if water is on left, right, top, or bottom
	var water_side = config.get("water_side", "left")  # left, right, top, bottom
	
	for y in range(grid.height):
		for x in range(grid.width):
			var noise_value = noise_coast.get_noise_2d(x, y)
			noise_value = (noise_value + 1.0) * 0.5  # Normalize to 0-1
			
			# Calculate distance from water edge based on side
			var distance_factor = 0.0
			match water_side:
				"left":
					distance_factor = float(x) / grid.width
				"right":
					distance_factor = float(grid.width - x) / grid.width
				"top":
					distance_factor = float(y) / grid.height
				"bottom":
					distance_factor = float(grid.height - y) / grid.height
			
			# Add noise to create natural coastline
			var adjusted_distance = distance_factor + (noise_value - 0.5) * 0.15
			
			# Determine terrain type based on distance from water
			if adjusted_distance < water_level:
				# Ocean water
				grid.set_terrain(x, y, WorldGrid.TerrainType.WATER)
				var depth = (water_level - adjusted_distance) * 10.0
				grid.set_height(x, y, -depth)  # Deeper as you go out
			elif adjusted_distance < water_level + beach_width:
				# Sandy beach
				grid.set_terrain(x, y, WorldGrid.TerrainType.SAND)
				var beach_progress = (adjusted_distance - water_level) / beach_width
				grid.set_height(x, y, beach_progress * 2.0)  # Gradual rise from 0-2m
			elif adjusted_distance < water_level + beach_width + 0.15:
				# Dunes / vegetation line
				grid.set_terrain(x, y, WorldGrid.TerrainType.SAND)
				grid.set_height(x, y, 2.0 + noise_value * 2.0)  # 2-4m dunes
			else:
				# Inland grass
				grid.set_terrain(x, y, WorldGrid.TerrainType.GRASS)
				grid.set_height(x, y, 3.0 + noise_value * 1.5)

func _create_tide_pools(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Create tide pools and rock formations"""
	var num_tide_pools = config.get("num_tide_pools", 4)
	var num_rock_formations = config.get("num_rock_formations", 3)
	
	print("    Creating tide pools and rock formations...")
	
	tide_pools.clear()
	rock_formations.clear()
	
	# Create tide pools (small water areas on the beach)
	for i in range(num_tide_pools):
		var attempts = 0
		while attempts < 25:
			attempts += 1
			
			var tx = rng.randi_range(10, grid.width - 10)
			var ty = rng.randi_range(10, grid.height - 10)
			
			# Must be on sand, near water
			if grid.get_terrain(tx, ty) != WorldGrid.TerrainType.SAND:
				continue
			
			var height = grid.get_height(tx, ty)
			# Tide pools are on low beach (close to water level)
			if height > 1.0:
				continue
			
			# Check if close to existing tide pools
			var too_close = false
			for existing in tide_pools:
				if Vector2i(tx, ty).distance_to(existing) < 15:
					too_close = true
					break
			
			if too_close:
				continue
			
			# Create small tide pool
			var pool_size = rng.randi_range(2, 4)
			for dy in range(-pool_size, pool_size + 1):
				for dx in range(-pool_size, pool_size + 1):
					var dist = sqrt(dx * dx + dy * dy)
					if dist <= pool_size and rng.randf() < 0.8:
						var px = tx + dx
						var py = ty + dy
						
						if px >= 0 and px < grid.width and py >= 0 and py < grid.height:
							if grid.get_terrain(px, py) == WorldGrid.TerrainType.SAND:
								grid.set_terrain(px, py, WorldGrid.TerrainType.WATER)
								grid.set_height(px, py, -0.3)  # Shallow pool
			
			tide_pools.append(Vector2i(tx, ty))
			break
	
	# Create rock formations
	for i in range(num_rock_formations):
		var attempts = 0
		while attempts < 25:
			attempts += 1
			
			var rx = rng.randi_range(8, grid.width - 8)
			var ry = rng.randi_range(8, grid.height - 8)
			
			# Can be on sand or in shallow water
			var terrain = grid.get_terrain(rx, ry)
			if terrain != WorldGrid.TerrainType.SAND and terrain != WorldGrid.TerrainType.WATER:
				continue
			
			# If in water, must be shallow
			if terrain == WorldGrid.TerrainType.WATER:
				var depth = grid.get_height(rx, ry)
				if depth < -2.0:
					continue
			
			# Check distance from existing formations
			var too_close = false
			for existing in rock_formations:
				if Vector2i(rx, ry).distance_to(existing) < 20:
					too_close = true
					break
			
			if too_close:
				continue
			
			# Create rock formation
			var rock_size = rng.randi_range(3, 6)
			for dy in range(-rock_size, rock_size + 1):
				for dx in range(-rock_size, rock_size + 1):
					var dist = sqrt(dx * dx + dy * dy)
					if dist <= rock_size and rng.randf() < 0.65:  # Irregular
						var rock_x = rx + dx
						var rock_y = ry + dy
						
						if rock_x >= 0 and rock_x < grid.width and rock_y >= 0 and rock_y < grid.height:
							grid.set_terrain(rock_x, rock_y, WorldGrid.TerrainType.ROCK)
							grid.set_height(rock_x, rock_y, 1.0 + rng.randf() * 2.0)
			
			rock_formations.append(Vector2i(rx, ry))
			break

func _add_coastal_vegetation(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Add palm tree clusters and beach vegetation"""
	var num_palm_clusters = config.get("num_palm_clusters", 6)
	
	print("    Adding coastal vegetation...")
	
	# Create palm tree clusters (on grass and dunes)
	for i in range(num_palm_clusters):
		var attempts = 0
		while attempts < 20:
			attempts += 1
			
			var vx = rng.randi_range(8, grid.width - 8)
			var vy = rng.randi_range(8, grid.height - 8)
			
			# Must be on grass or sand (dune area)
			var terrain = grid.get_terrain(vx, vy)
			if terrain != WorldGrid.TerrainType.GRASS and terrain != WorldGrid.TerrainType.SAND:
				continue
			
			# If on sand, must be elevated (dunes)
			if terrain == WorldGrid.TerrainType.SAND:
				var height = grid.get_height(vx, vy)
				if height < 2.0:
					continue
			
			# Create small cluster of palms
			# This would be represented visually - for now we just note the location
			# Could add a vegetation flag to the grid if needed
			var cluster_size = rng.randi_range(2, 4)
			for _j in range(cluster_size):
				var offset_x = rng.randi_range(-3, 3)
				var offset_y = rng.randi_range(-3, 3)
				var palm_x = vx + offset_x
				var palm_y = vy + offset_y
				
				if palm_x >= 0 and palm_x < grid.width and palm_y >= 0 and palm_y < grid.height:
					# Mark location for palm tree placement
					# Visual system would place palm tree model here
					pass
			
			break

func _create_beach_paths(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Create boardwalk or sand paths along the beach"""
	print("    Creating beach paths...")
	
	# Create a path parallel to the shoreline
	var water_side = config.get("water_side", "left")
	
	# Find beach access points (transitions from grass to sand)
	beach_access_points.clear()
	
	match water_side:
		"left":
			# Scan from left to right to find beach
			for y in range(10, grid.height - 10, 15):
				for x in range(grid.width):
					if grid.get_terrain(x, y) == WorldGrid.TerrainType.SAND:
						var height = grid.get_height(x, y)
						if height >= 0.5 and height <= 2.0:  # Mid-beach
							beach_access_points.append(Vector2i(x + 10, y))
							break
		"right":
			for y in range(10, grid.height - 10, 15):
				for x in range(grid.width - 1, -1, -1):
					if grid.get_terrain(x, y) == WorldGrid.TerrainType.SAND:
						var height = grid.get_height(x, y)
						if height >= 0.5 and height <= 2.0:
							beach_access_points.append(Vector2i(x - 10, y))
							break
		"top":
			for x in range(10, grid.width - 10, 15):
				for y in range(grid.height):
					if grid.get_terrain(x, y) == WorldGrid.TerrainType.SAND:
						var height = grid.get_height(x, y)
						if height >= 0.5 and height <= 2.0:
							beach_access_points.append(Vector2i(x, y + 10))
							break
		"bottom":
			for x in range(10, grid.width - 10, 15):
				for y in range(grid.height - 1, -1, -1):
					if grid.get_terrain(x, y) == WorldGrid.TerrainType.SAND:
						var height = grid.get_height(x, y)
						if height >= 0.5 and height <= 2.0:
							beach_access_points.append(Vector2i(x, y - 10))
							break
	
	# Connect some access points with a beach path
	if beach_access_points.size() >= 2:
		for i in range(beach_access_points.size() - 1):
			var start = beach_access_points[i]
			var end = beach_access_points[i + 1]
			_create_beach_boardwalk(grid, start, end, rng)

func _create_beach_boardwalk(grid: WorldGrid, start: Vector2i, end: Vector2i, rng: RandomNumberGenerator):
	"""Create a boardwalk/path between two points"""
	var current = start
	var max_steps = 300
	var step_count = 0
	
	while current.distance_to(end) > 2 and step_count < max_steps:
		step_count += 1
		
		# Direction toward goal
		var direction = Vector2(end - current).normalized()
		
		# Slight winding
		var angle_variance = rng.randf_range(-0.15, 0.15)
		var angle = atan2(direction.y, direction.x) + angle_variance
		
		# Take a step
		var next_x = roundi(current.x + cos(angle) * 1.0)
		var next_y = roundi(current.y + sin(angle) * 1.0)
		var next = Vector2i(next_x, next_y)
		
		# Stay in bounds
		if next.x < 1 or next.x >= grid.width - 1 or next.y < 1 or next.y >= grid.height - 1:
			break
		
		# Mark as path
		var terrain = grid.get_terrain(next.x, next.y)
		if terrain != WorldGrid.TerrainType.WATER and terrain != WorldGrid.TerrainType.ROCK:
			grid.set_path(next.x, next.y, true)
			# If on sand, convert to dirt (wooden boardwalk)
			if terrain == WorldGrid.TerrainType.SAND:
				grid.set_terrain(next.x, next.y, WorldGrid.TerrainType.DIRT)
		
		current = next

func get_poi_placement_strategy(poi_type: String) -> String:
	"""Beach-specific POI placement strategies"""
	match poi_type:
		"lifeguard_tower", "beach_chair", "umbrella":
			return "beach"
		"surf_shop", "beach_hut", "snack_bar":
			return "beach_access"
		"dock", "pier", "boat":
			return "water_edge"
		"tide_pool":
			return "tide_pool"
		"lighthouse":
			return "elevated"
		"cave", "sea_cave":
			return "rock_formation"
		"volleyball_net", "fire_pit":
			return "beach"
		"picnic_area", "pavilion":
			return "grass_area"
		"shipwreck", "debris":
			return "shallow_water"
		"shell_collection", "driftwood":
			return "beach"
		_:
			return "beach"

func find_poi_location(grid: WorldGrid, poi_type: String, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find appropriate location based on POI type"""
	var strategy = get_poi_placement_strategy(poi_type)
	
	match strategy:
		"beach":
			return _find_beach_location(grid, min_radius, rng)
		"beach_access":
			return _find_beach_access_location(grid, min_radius, rng)
		"water_edge":
			return _find_water_edge_location(grid, min_radius, rng)
		"tide_pool":
			return _find_tide_pool_location(grid, min_radius, rng)
		"elevated":
			return _find_elevated_location(grid, min_radius, rng)
		"rock_formation":
			return _find_rock_formation_location(grid, min_radius, rng)
		"grass_area":
			return _find_grass_location(grid, min_radius, rng)
		"shallow_water":
			return _find_shallow_water_location(grid, min_radius, rng)
		_:
			return _find_beach_location(grid, min_radius, rng)

func _find_beach_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location on sandy beach"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		if grid.get_terrain(x, y) == WorldGrid.TerrainType.SAND:
			var height = grid.get_height(x, y)
			# Mid-beach (not at water, not on dunes)
			if height >= 0.3 and height <= 2.5:
				if grid.is_area_empty(x, y, min_radius):
					return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_beach_access_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location near beach access points"""
	if not beach_access_points.is_empty():
		var shuffled = beach_access_points.duplicate()
		shuffled.shuffle()
		
		for point in shuffled:
			if grid.is_area_empty(point.x, point.y, min_radius):
				return point
	
	# Fallback to beach
	return _find_beach_location(grid, min_radius, rng)

func _find_water_edge_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location at water's edge"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		# Must be on sand near water
		if grid.get_terrain(x, y) != WorldGrid.TerrainType.SAND:
			continue
		
		var height = grid.get_height(x, y)
		if height > 0.5:  # Not too high up beach
			continue
		
		# Check for adjacent water
		var near_water = false
		for dy in range(-2, 3):
			for dx in range(-2, 3):
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

func _find_tide_pool_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location near a tide pool"""
	if not tide_pools.is_empty():
		var shuffled = tide_pools.duplicate()
		shuffled.shuffle()
		
		for pool in shuffled:
			# Try around the pool
			for attempt in range(15):
				var angle = rng.randf() * TAU
				var distance = rng.randf_range(3, 6)
				var x = int(pool.x + cos(angle) * distance)
				var y = int(pool.y + sin(angle) * distance)
				
				if x >= min_radius and x < grid.width - min_radius and y >= min_radius and y < grid.height - min_radius:
					if grid.is_area_empty(x, y, min_radius):
						return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_elevated_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find elevated location (dunes or cliffs)"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		var height = grid.get_height(x, y)
		if height > 3.0:  # Elevated
			if grid.is_area_empty(x, y, min_radius):
				return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_rock_formation_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location at or near rock formations"""
	if not rock_formations.is_empty():
		var shuffled = rock_formations.duplicate()
		shuffled.shuffle()
		
		for formation in shuffled:
			if grid.is_area_empty(formation.x, formation.y, min_radius):
				return formation
	
	# Fallback to any rocks
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		if grid.get_terrain(x, y) == WorldGrid.TerrainType.ROCK:
			if grid.is_area_empty(x, y, min_radius):
				return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_grass_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location on grass (inland area)"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		if grid.get_terrain(x, y) == WorldGrid.TerrainType.GRASS:
			if grid.is_area_empty(x, y, min_radius):
				return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_shallow_water_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location in shallow water"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		if grid.get_terrain(x, y) == WorldGrid.TerrainType.WATER:
			var depth = grid.get_height(x, y)
			if depth > -2.0:  # Shallow
				if grid.is_area_empty(x, y, min_radius):
					return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func place_poi(grid: WorldGrid, poi_type: String, tags: Array, required: bool, rng: RandomNumberGenerator) -> POIData:
	"""Place a Point of Interest on the beach"""
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
	"""Place a building on the beach"""
	var max_attempts = 30
	
	for attempt in range(max_attempts):
		# Try to find a suitable location (beach or grass areas)
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
		
		# Buildings can be on sand (beach/dunes) or grass (inland)
		var terrain = grid.get_terrain(x, y)
		var height = grid.get_height(x, y)
		
		# Prefer areas that are not too low (not water line) and not too high
		if terrain == WorldGrid.TerrainType.SAND and height >= 1.0 and height <= 3.5:
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
	"""Beaches have few permanent buildings - placed by template system"""
	print("  Generating beach structures...")
	# Buildings will be placed by template system

func get_biome_type() -> String:
	return "beach"

func get_beach_access_points() -> Array[Vector2i]:
	"""Get beach access points for visualization"""
	return beach_access_points
