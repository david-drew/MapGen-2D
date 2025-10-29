# suburban_generator.gd
# Generator for suburban locations with curved streets and residential focus
class_name SuburbanGenerator
extends LocationGeneratorBase

var cul_de_sacs: Array[Vector2i] = []  # Track cul-de-sac centers

func generate_foundation(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate suburban foundation with curved streets"""
	print("  Generating suburban foundation...")
	
	# Generate gentle terrain (suburbs have slight hills)
	_generate_suburban_heightmap(grid, rng)
	
	# Create main road through suburb
	_generate_main_road(grid, config, rng)
	
	# Create residential street loops
	_generate_residential_streets(grid, config, rng)
	
	# Create cul-de-sacs
	_generate_cul_de_sacs(grid, config, rng)
	
	# Add sidewalks along streets
	_add_sidewalks(grid)

func _generate_suburban_heightmap(grid: WorldGrid, rng: RandomNumberGenerator):
	"""Generate gentle rolling hills for suburb"""
	var noise = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.012
	noise.fractal_octaves = 2
	
	for y in range(grid.height):
		for x in range(grid.width):
			var value = noise.get_noise_2d(x, y)
			value = (value + 1.0) * 0.5
			value *= 4.0  # 0-4 meters (gentle hills)
			grid.set_height(x, y, value)

func _generate_main_road(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate main thoroughfare through suburb"""
	var road_width = max(2, int(config.get("main_road_width_m", 8) / 2.0))
	
	print("    Creating main road...")
	
	# Main road runs horizontally through middle
	var center_y = grid.height / 2
	
	for x in range(grid.width):
		for w in range(road_width):
			var y = center_y - road_width / 2 + w
			if grid.is_valid(x, y):
				grid.set_terrain(x, y, WorldGrid.TerrainType.ROAD)
				grid.set_height(x, y, grid.get_height(x, y) * 0.95)

func _generate_residential_streets(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate curved residential streets"""
	var num_loops = config.get("num_residential_loops", rng.randi_range(4, 7))
	var road_width = 2  # Narrower residential streets
	
	print("    Creating %d residential street loops..." % num_loops)
	
	for i in range(num_loops):
		_create_curved_residential_street(grid, road_width, rng)

func _create_curved_residential_street(grid: WorldGrid, road_width: int, rng: RandomNumberGenerator):
	"""Create a single curved residential street"""
	# Pick random start point along main road
	var start_x = rng.randi_range(50, grid.width - 50)
	var start_y = grid.height / 2
	
	# Create curving path that loops back
	var current = Vector2(start_x, start_y)
	var angle = rng.randf_range(-PI/3, PI/3)  # Initial direction (away from main road)
	var steps = rng.randi_range(40, 80)
	
	for step in range(steps):
		# Mark current position as road
		for dy in range(-road_width, road_width + 1):
			for dx in range(-road_width, road_width + 1):
				var x = int(current.x) + dx
				var y = int(current.y) + dy
				if grid.is_valid(x, y):
					grid.set_terrain(x, y, WorldGrid.TerrainType.ROAD)
					grid.set_height(x, y, grid.get_height(x, y) * 0.95)
		
		# Move forward with curve
		angle += rng.randf_range(-0.15, 0.15)  # Gentle curves
		var step_size = 3.0
		current.x += cos(angle) * step_size
		current.y += sin(angle) * step_size
		
		# Keep within bounds
		current.x = clampf(current.x, 20, grid.width - 20)
		current.y = clampf(current.y, 20, grid.height - 20)
		
		# Curve back toward main road after halfway
		if step > steps / 2:
			var target_y = grid.height / 2
			var dy = target_y - current.y
			angle = lerp_angle(angle, atan2(dy, 1.0), 0.05)

func _generate_cul_de_sacs(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate cul-de-sacs (dead-end circular streets)"""
	var num_culs = config.get("num_cul_de_sacs", rng.randi_range(6, 10))
	var road_width = 2
	
	print("    Creating %d cul-de-sacs..." % num_culs)
	
	for i in range(num_culs):
		# Find a spot not too close to existing roads
		for attempt in range(30):
			var x = rng.randi_range(50, grid.width - 50)
			var y = rng.randi_range(50, grid.height - 50)
			
			# Check if far enough from main road and other cul-de-sacs
			var main_road_y = grid.height / 2
			var dist_from_main = abs(y - main_road_y)
			
			if dist_from_main > 30:
				# Check distance from other cul-de-sacs
				var too_close = false
				for other_cul in cul_de_sacs:
					var dx = x - other_cul.x
					var dy = y - other_cul.y
					if sqrt(dx * dx + dy * dy) < 40:
						too_close = true
						break
				
				if not too_close:
					_create_cul_de_sac(grid, Vector2i(x, y), road_width, rng)
					cul_de_sacs.append(Vector2i(x, y))
					break

func _create_cul_de_sac(grid: WorldGrid, center: Vector2i, road_width: int, rng: RandomNumberGenerator):
	"""Create a single cul-de-sac"""
	var radius = rng.randi_range(8, 12)
	
	# Draw circular road
	var circumference = int(TAU * radius)
	for i in range(circumference):
		var angle = (float(i) / circumference) * TAU
		var x = center.x + int(cos(angle) * radius)
		var y = center.y + int(sin(angle) * radius)
		
		# Draw with width
		for dy in range(-road_width, road_width + 1):
			for dx in range(-road_width, road_width + 1):
				var nx = x + dx
				var ny = y + dy
				if grid.is_valid(nx, ny):
					grid.set_terrain(nx, ny, WorldGrid.TerrainType.ROAD)
					grid.set_height(nx, ny, grid.get_height(nx, ny) * 0.95)
	
	# Connect to nearest road with short street
	_connect_cul_de_sac_to_road(grid, center, road_width, rng)

func _connect_cul_de_sac_to_road(grid: WorldGrid, cul_center: Vector2i, road_width: int, rng: RandomNumberGenerator):
	"""Connect cul-de-sac to nearest main road"""
	# Find nearest road cell
	var nearest_road = Vector2i(-1, -1)
	var min_dist = 999999.0
	
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.get_terrain(x, y) == WorldGrid.TerrainType.ROAD:
				var dx = x - cul_center.x
				var dy = y - cul_center.y
				var dist = sqrt(dx * dx + dy * dy)
				if dist < min_dist and dist > 15:  # Not too close
					min_dist = dist
					nearest_road = Vector2i(x, y)
	
	if nearest_road == Vector2i(-1, -1):
		return
	
	# Draw connecting street
	var current = Vector2(cul_center.x, cul_center.y)
	var target = Vector2(nearest_road.x, nearest_road.y)
	var steps = int(current.distance_to(target) / 3)
	
	for step in range(steps):
		var t = float(step) / steps
		var pos = current.lerp(target, t)
		
		for dy in range(-road_width, road_width + 1):
			for dx in range(-road_width, road_width + 1):
				var x = int(pos.x) + dx
				var y = int(pos.y) + dy
				if grid.is_valid(x, y):
					grid.set_terrain(x, y, WorldGrid.TerrainType.ROAD)
					grid.set_height(x, y, grid.get_height(x, y) * 0.95)

func _add_sidewalks(grid: WorldGrid):
	"""Add sidewalks adjacent to roads"""
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.get_terrain(x, y) == WorldGrid.TerrainType.GRASS:
				# Check if adjacent to road
				var near_road = false
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if dx == 0 and dy == 0:
							continue
						var nx = x + dx
						var ny = y + dy
						if grid.is_valid(nx, ny):
							if grid.get_terrain(nx, ny) == WorldGrid.TerrainType.ROAD:
								near_road = true
								break
					if near_road:
						break
				
				if near_road:
					grid.set_terrain(x, y, WorldGrid.TerrainType.SIDEWALK)
					grid.set_height(x, y, grid.get_height(x, y) * 0.98)

func place_required_poi(grid: WorldGrid, poi_type: String, tags: Array, rng: RandomNumberGenerator) -> POIData:
	"""Place a required POI in suburb"""
	print("    Placing suburban POI: ", poi_type)
	
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
	
	push_error("Could not place suburban POI: " + poi_type)
	return POIData.new()

func _get_poi_footprint(poi_type: String) -> int:
	"""Get footprint radius for suburban POI types"""
	match poi_type:
		"playground":
			return 6
		"park":
			return 12
		"cul_de_sac":
			return 10
		"basketball_court":
			return 5
		"swimming_pool":
			return 4
		"school":
			return 15
		"community_center":
			return 10
		_:
			return 5

func _get_placement_strategy(poi_type: String) -> String:
	"""Determine placement strategy for suburban POI"""
	match poi_type:
		"playground":
			return "park_area"  # In green spaces
		"park":
			return "open_area"  # Large open areas
		"cul_de_sac":
			return "cul_de_sac"  # Use existing cul-de-sacs
		"basketball_court":
			return "park_area"  # Near parks or schools
		"swimming_pool":
			return "community"  # Near community areas
		"school":
			return "prominent"  # Visible location
		"community_center":
			return "prominent"  # Visible location
		_:
			return "residential"

func _find_poi_location(grid: WorldGrid, strategy: String, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location based on strategy"""
	match strategy:
		"park_area":
			return _find_park_area_location(grid, min_radius, rng)
		"open_area":
			return _find_open_area_location(grid, min_radius, rng)
		"cul_de_sac":
			return _find_cul_de_sac_location(grid, min_radius, rng)
		"community":
			return _find_community_location(grid, min_radius, rng)
		"prominent":
			return _find_prominent_location(grid, min_radius, rng)
		"residential":
			return _find_residential_location(grid, min_radius, rng)
		_:
			return grid.find_empty_spot(min_radius, 50, rng)

func _find_park_area_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find spot in green/park area"""
	for attempt in range(50):
		var x = rng.randi_range(min_radius * 2, grid.width - min_radius * 2)
		var y = rng.randi_range(min_radius * 2, grid.height - min_radius * 2)
		
		if grid.get_terrain(x, y) == WorldGrid.TerrainType.GRASS:
			if grid.is_area_empty(x, y, min_radius):
				# Check for large grass area nearby (park-like)
				var grass_count = 0
				var total = 0
				for dy in range(-15, 16):
					for dx in range(-15, 16):
						var nx = x + dx
						var ny = y + dy
						if grid.is_valid(nx, ny):
							total += 1
							if grid.get_terrain(nx, ny) == WorldGrid.TerrainType.GRASS:
								grass_count += 1
				
				if total > 0 and float(grass_count) / total > 0.6:
					return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_open_area_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find large open area"""
	for attempt in range(50):
		var x = rng.randi_range(min_radius * 2, grid.width - min_radius * 2)
		var y = rng.randi_range(min_radius * 2, grid.height - min_radius * 2)
		
		if grid.is_area_empty(x, y, min_radius * 2):
			return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_cul_de_sac_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find spot at a cul-de-sac center"""
	if cul_de_sacs.is_empty():
		return _find_residential_location(grid, min_radius, rng)
	
	# Pick random cul-de-sac
	var cul = cul_de_sacs[rng.randi() % cul_de_sacs.size()]
	
	# Check if center is available
	if grid.is_area_empty(cul.x, cul.y, min_radius):
		return cul
	
	return Vector2i(-1, -1)

func _find_community_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find spot near community areas"""
	# Look for areas with moderate density (not too packed, not too empty)
	for attempt in range(50):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		if grid.is_area_empty(x, y, min_radius):
			return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_prominent_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find visible location near main road"""
	var main_road_y = grid.height / 2
	
	for attempt in range(50):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = main_road_y + rng.randi_range(10, 30) * (1 if rng.randf() > 0.5 else -1)
		
		if grid.is_area_empty(x, y, min_radius):
			return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_residential_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find spot in residential area"""
	for attempt in range(50):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		# Must be on grass/sidewalk (not road)
		var terrain = grid.get_terrain(x, y)
		if terrain == WorldGrid.TerrainType.GRASS or terrain == WorldGrid.TerrainType.SIDEWALK:
			if grid.is_area_empty(x, y, min_radius):
				return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func generate_buildings(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Suburbs have residential buildings"""
	print("  Generating suburban buildings...")
	# Buildings will be placed by template system

func get_biome_type() -> String:
	return "suburban"

func get_cul_de_sacs() -> Array[Vector2i]:
	"""Get cul-de-sac centers for visualization"""
	return cul_de_sacs
