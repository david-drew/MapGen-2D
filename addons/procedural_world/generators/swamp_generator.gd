# swamp_generator.gd
# Generator for swamp locations with water, mud, elevated areas, and dense vegetation
class_name SwampGenerator
extends LocationGeneratorBase

var dry_islands: Array[Vector2i] = []
var deep_water_areas: Array[Vector2i] = []

func generate_foundation(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate swamp foundation with water, mud, and islands"""
	print("  Generating swamp foundation...")
	
	# Generate base swamp terrain with water and mud
	_generate_swamp_terrain(grid, config, rng)
	
	# Create dry islands/elevated areas
	_create_dry_islands(grid, config, rng)
	
	# Add dead trees and fallen logs
	_add_swamp_features(grid, config, rng)
	
	# Create boardwalks and paths between islands
	_create_swamp_paths(grid, config, rng)

func _generate_swamp_terrain(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate waterlogged terrain with mud patches"""
	var water_coverage = config.get("water_coverage", 0.60)
	
	print("    Generating swamp terrain (water coverage: %.2f)..." % water_coverage)
	
	# Use noise for water distribution
	var noise_water = FastNoiseLite.new()
	noise_water.seed = rng.randi()
	noise_water.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_water.frequency = 0.04
	noise_water.fractal_octaves = 3
	
	# Secondary noise for mud vs shallow water
	var noise_detail = FastNoiseLite.new()
	noise_detail.seed = rng.randi()
	noise_detail.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_detail.frequency = 0.08
	noise_detail.fractal_octaves = 2
	
	deep_water_areas.clear()
	
	for y in range(grid.height):
		for x in range(grid.width):
			var water_noise = noise_water.get_noise_2d(x, y)
			water_noise = (water_noise + 1.0) * 0.5  # Normalize to 0-1
			
			var detail_noise = noise_detail.get_noise_2d(x, y)
			detail_noise = (detail_noise + 1.0) * 0.5
			
			# Determine terrain type based on noise
			if water_noise < water_coverage:
				# Water areas
				if detail_noise < 0.3:
					# Deep water
					grid.set_terrain(x, y, WorldGrid.TerrainType.WATER)
					grid.set_height(x, y, -2.0 - detail_noise * 2.0)  # Up to 4m deep
					if rng.randf() < 0.02:
						deep_water_areas.append(Vector2i(x, y))
				else:
					# Shallow water / mud
					grid.set_terrain(x, y, WorldGrid.TerrainType.WATER)
					grid.set_height(x, y, -0.5)  # Shallow
			elif water_noise < water_coverage + 0.15:
				# Mud areas (transition zone)
				grid.set_terrain(x, y, WorldGrid.TerrainType.DIRT)
				grid.set_height(x, y, -0.2)  # Below water level but not submerged
			else:
				# Higher ground (grass patches)
				grid.set_terrain(x, y, WorldGrid.TerrainType.GRASS)
				grid.set_height(x, y, water_noise * 1.5)  # Slight elevation

func _create_dry_islands(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Create elevated dry areas/islands in the swamp"""
	var island_count = config.get("island_count", 6)
	var island_size = 10  # Radius
	
	print("    Creating %d dry islands..." % island_count)
	
	dry_islands.clear()
	
	for i in range(island_count):
		var attempts = 0
		while attempts < 30:
			attempts += 1
			
			var ix = rng.randi_range(island_size + 5, grid.width - island_size - 5)
			var iy = rng.randi_range(island_size + 5, grid.height - island_size - 5)
			
			# Check if too close to existing islands
			var too_close = false
			for existing in dry_islands:
				if Vector2i(ix, iy).distance_to(existing) < island_size * 2:
					too_close = true
					break
			
			if too_close:
				continue
			
			# Create the island with irregular shape
			for dy in range(-island_size, island_size + 1):
				for dx in range(-island_size, island_size + 1):
					var dist = sqrt(dx * dx + dy * dy)
					# Irregular edge
					var radius_variance = rng.randf_range(0.7, 1.3)
					if dist <= island_size * radius_variance:
						var island_x = ix + dx
						var island_y = iy + dy
						
						if island_x >= 0 and island_x < grid.width and island_y >= 0 and island_y < grid.height:
							# Blend edge for natural look
							if dist > island_size * 0.7:
								# Edge of island - sometimes mud
								if rng.randf() < 0.5:
									grid.set_terrain(island_x, island_y, WorldGrid.TerrainType.GRASS)
									grid.set_height(island_x, island_y, 1.0)
								else:
									grid.set_terrain(island_x, island_y, WorldGrid.TerrainType.DIRT)
									grid.set_height(island_x, island_y, 0.3)
							else:
								# Center of island - solid ground
								grid.set_terrain(island_x, island_y, WorldGrid.TerrainType.GRASS)
								grid.set_height(island_x, island_y, 1.5 + rng.randf() * 0.5)
			
			dry_islands.append(Vector2i(ix, iy))
			break

func _add_swamp_features(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Add atmospheric swamp features like dead trees and mist areas"""
	print("    Adding swamp features...")
	
	# Mark areas with dense vegetation (mangrove-like)
	var num_vegetation_clusters = config.get("num_vegetation_clusters", 8)
	
	for i in range(num_vegetation_clusters):
		var attempts = 0
		while attempts < 15:
			attempts += 1
			
			var vx = rng.randi_range(5, grid.width - 5)
			var vy = rng.randi_range(5, grid.height - 5)
			
			# Must be in shallow water or mud
			var terrain = grid.get_terrain(vx, vy)
			if terrain != WorldGrid.TerrainType.WATER and terrain != WorldGrid.TerrainType.DIRT:
				continue
			
			# Avoid dry islands
			var on_island = false
			for island in dry_islands:
				if Vector2i(vx, vy).distance_to(island) < 12:
					on_island = true
					break
			
			if on_island:
				continue
			
			# Mark this area as having dense vegetation
			# (Visual representation would show mangroves, reeds, etc.)
			var cluster_size = rng.randi_range(3, 5)
			for dy in range(-cluster_size, cluster_size + 1):
				for dx in range(-cluster_size, cluster_size + 1):
					var dist = sqrt(dx * dx + dy * dy)
					if dist <= cluster_size and rng.randf() < 0.6:
						var cx = vx + dx
						var cy = vy + dy
						
						if cx >= 0 and cx < grid.width and cy >= 0 and cy < grid.height:
							# This could set a flag for vegetation density
							# For now, slightly raise water level to indicate vegetation
							if grid.get_terrain(cx, cy) == WorldGrid.TerrainType.WATER:
								var current_height = grid.get_height(cx, cy)
								grid.set_height(cx, cy, current_height + 0.3)
			
			break

func _create_swamp_paths(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Create boardwalk-style paths between dry islands"""
	if dry_islands.size() < 2:
		return
	
	print("    Creating swamp paths...")
	
	# Connect some islands with paths (boardwalks)
	var num_paths = mini(4, dry_islands.size() - 1)
	
	for i in range(num_paths):
		var start_island = dry_islands[i]
		var end_island = dry_islands[(i + 1) % dry_islands.size()]
		
		_create_boardwalk(grid, start_island, end_island, rng)

func _create_boardwalk(grid: WorldGrid, start: Vector2i, end: Vector2i, rng: RandomNumberGenerator):
	"""Create a straight-ish boardwalk between two points"""
	var current = start
	var max_steps = 400
	var step_count = 0
	
	while current.distance_to(end) > 3 and step_count < max_steps:
		step_count += 1
		
		# Direction toward goal
		var direction = Vector2(end - current).normalized()
		
		# Less winding than forest paths (boardwalks are straighter)
		var angle_variance = rng.randf_range(-0.2, 0.2)
		var angle = atan2(direction.y, direction.x) + angle_variance
		
		# Take a step
		var next_x = roundi(current.x + cos(angle) * 1.0)
		var next_y = roundi(current.y + sin(angle) * 1.0)
		var next = Vector2i(next_x, next_y)
		
		# Stay in bounds
		if next.x < 1 or next.x >= grid.width - 1 or next.y < 1 or next.y >= grid.height - 1:
			break
		
		# Mark as path (elevated boardwalk over water/mud)
		var terrain = grid.get_terrain(next.x, next.y)
		if terrain == WorldGrid.TerrainType.WATER or terrain == WorldGrid.TerrainType.DIRT:
			# Change to dirt (representing boardwalk)
			grid.set_terrain(next.x, next.y, WorldGrid.TerrainType.DIRT)
			grid.set_path(next.x, next.y, true)
			grid.set_height(next.x, next.y, 0.5)  # Elevated above water
		elif terrain == WorldGrid.TerrainType.GRASS:
			# On dry land, just mark as path
			grid.set_path(next.x, next.y, true)
		
		current = next

func get_poi_placement_strategy(poi_type: String) -> String:
	"""Swamp-specific POI placement strategies"""
	match poi_type:
		"shack", "hut", "cabin", "witch_hut":
			return "dry_island"
		"ritual_site", "altar", "shrine":
			return "dry_island"
		"boat", "canoe", "raft":
			return "water_edge"
		"dead_tree", "stump":
			return "water"
		"fishing_spot":
			return "water_edge"
		"abandoned_dock", "pier":
			return "water_edge"
		"sinking_structure", "ruins":
			return "shallow_water"
		"campsite":
			return "dry_island"
		"mysterious_light", "will_o_wisp":
			return "deep_water"
		"grave_marker", "sunken_grave":
			return "mud"
		_:
			return "dry_island"

func find_poi_location(grid: WorldGrid, poi_type: String, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find appropriate location based on POI type"""
	var strategy = get_poi_placement_strategy(poi_type)
	
	match strategy:
		"dry_island":
			return _find_dry_island_location(grid, min_radius, rng)
		"water_edge":
			return _find_water_edge_location(grid, min_radius, rng)
		"water":
			return _find_water_location(grid, min_radius, rng)
		"shallow_water":
			return _find_shallow_water_location(grid, min_radius, rng)
		"deep_water":
			return _find_deep_water_location(grid, min_radius, rng)
		"mud":
			return _find_mud_location(grid, min_radius, rng)
		_:
			return _find_dry_island_location(grid, min_radius, rng)

func _find_dry_island_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location on a dry island"""
	if not dry_islands.is_empty():
		var shuffled = dry_islands.duplicate()
		shuffled.shuffle()
		
		for island in shuffled:
			# Try to place near center of island
			for attempt in range(20):
				var offset_x = rng.randi_range(-5, 5)
				var offset_y = rng.randi_range(-5, 5)
				var x = island.x + offset_x
				var y = island.y + offset_y
				
				if x >= min_radius and x < grid.width - min_radius and y >= min_radius and y < grid.height - min_radius:
					if grid.get_terrain(x, y) == WorldGrid.TerrainType.GRASS:
						if grid.is_area_empty(x, y, min_radius):
							return Vector2i(x, y)
	
	# Fallback to any grass
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		if grid.get_terrain(x, y) == WorldGrid.TerrainType.GRASS:
			if grid.is_area_empty(x, y, min_radius):
				return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_water_edge_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location at water's edge (on land)"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		# Must be on grass or dirt
		var terrain = grid.get_terrain(x, y)
		if terrain != WorldGrid.TerrainType.GRASS and terrain != WorldGrid.TerrainType.DIRT:
			continue
		
		# Check for nearby water
		var near_water = false
		for dy in range(-3, 4):
			for dx in range(-3, 4):
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

func _find_water_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location in water"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		if grid.get_terrain(x, y) == WorldGrid.TerrainType.WATER:
			if grid.is_area_empty(x, y, min_radius):
				return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_shallow_water_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location in shallow water"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		if grid.get_terrain(x, y) == WorldGrid.TerrainType.WATER:
			var height = grid.get_height(x, y)
			# Shallow water is not too deep
			if height > -1.5:
				if grid.is_area_empty(x, y, min_radius):
					return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_deep_water_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location in deep water"""
	if not deep_water_areas.is_empty():
		var shuffled = deep_water_areas.duplicate()
		shuffled.shuffle()
		
		for location in shuffled:
			if grid.is_area_empty(location.x, location.y, min_radius):
				return location
	
	# Fallback to any deep water
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		if grid.get_terrain(x, y) == WorldGrid.TerrainType.WATER:
			var height = grid.get_height(x, y)
			if height < -2.0:
				if grid.is_area_empty(x, y, min_radius):
					return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_mud_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location in muddy area"""
	for attempt in range(40):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		if grid.get_terrain(x, y) == WorldGrid.TerrainType.DIRT:
			var height = grid.get_height(x, y)
			# Mud is at or below water level
			if height <= 0.0:
				if grid.is_area_empty(x, y, min_radius):
					return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func place_poi(grid: WorldGrid, poi_type: String, tags: Array, required: bool, rng: RandomNumberGenerator) -> POIData:
	"""Place a Point of Interest in the swamp"""
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
	"""Place a building in the swamp"""
	var max_attempts = 30
	
	for attempt in range(max_attempts):
		# Try to find a suitable location (dry islands preferred)
		var location = _find_building_location(grid, size, rng)
		
		if location == Vector2i(-1, -1):
			continue
		
		# Check if we can place building here
		if _can_place_building(grid, location, size):
			# Mark area as occupied
			_mark_building_footprint(grid, location, size)
			
			# Create building data
			var building = BuildingData.new(building_type, location, size)
			for tag in tags:
				building.tags.append(str(tag))
			
			return building
	
	return null

func _find_building_location(grid: WorldGrid, size: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	"""Find a suitable location for a building"""
	var half_size = size / 2
	var margin = maxi(half_size.x, half_size.y) + 2
	
	# First try dry islands
	if not dry_islands.is_empty():
		var shuffled = dry_islands.duplicate()
		shuffled.shuffle()
		
		for island in shuffled:
			for attempt in range(10):
				var offset_x = rng.randi_range(-4, 4)
				var offset_y = rng.randi_range(-4, 4)
				var x = island.x + offset_x
				var y = island.y + offset_y
				
				if x >= margin and x < grid.width - margin and y >= margin and y < grid.height - margin:
					if grid.get_terrain(x, y) == WorldGrid.TerrainType.GRASS:
						return Vector2i(x, y)
	
	# Fallback to any grass area
	for attempt in range(40):
		var x = rng.randi_range(margin, grid.width - margin - 1)
		var y = rng.randi_range(margin, grid.height - margin - 1)
		
		if grid.get_terrain(x, y) == WorldGrid.TerrainType.GRASS:
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
			
			# Check terrain is suitable (grass only for swamp)
			var terrain = grid.get_terrain(check_x, check_y)
			if terrain != WorldGrid.TerrainType.GRASS:
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
	"""Swamps have very few buildings - placed by template system"""
	print("  Generating swamp structures...")
	# Buildings will be placed by template system

func get_biome_type() -> String:
	return "swamp"

func get_dry_island_locations() -> Array[Vector2i]:
	"""Get dry island locations for visualization"""
	return dry_islands
