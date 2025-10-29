# city_generator.gd
# Generator for city locations with high-density urban layouts
class_name CityGenerator
extends LocationGeneratorBase

func generate_foundation(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate city foundation with dense street grid"""
	print("  Generating city foundation...")
	
	# Generate flat terrain (cities are built on leveled ground)
	_generate_city_heightmap(grid, rng)
	
	# Generate street grid
	var layout = config.get("city_layout", "grid")
	match layout:
		"grid":
			_generate_grid_streets(grid, config, rng)
		"radial":
			_generate_radial_streets(grid, config, rng)
		_:
			_generate_grid_streets(grid, config, rng)
	
	# Add sidewalks
	_add_sidewalks(grid)
	
	# Mark district zones (commercial, residential, etc.)
	_mark_districts(grid, config, rng)

func _generate_city_heightmap(grid: WorldGrid, rng: RandomNumberGenerator):
	"""Generate very flat terrain for city"""
	var noise = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.005  # Very low frequency = very gentle variation
	noise.fractal_octaves = 1
	
	for y in range(grid.height):
		for x in range(grid.width):
			var value = noise.get_noise_2d(x, y)
			value = (value + 1.0) * 0.5
			value *= 1.0  # Only 0-1 meter variation (very flat)
			grid.set_height(x, y, value)

func _generate_grid_streets(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate regular grid of streets"""
	var block_size = int(config.get("block_size_m", 100) / 2.0)  # Convert meters to cells
	var road_width = max(2, int(config.get("road_width_m", 10) / 2.0))
	
	print("    Generating grid streets (block: %d cells, road: %d cells)..." % [block_size, road_width])
	
	# Major avenues (wider, every 3 blocks)
	var avenue_width = road_width + 2
	var avenue_spacing = block_size * 3
	
	# Vertical avenues
	var x = 0
	var avenue_count = 0
	while x < grid.width:
		var is_avenue = (avenue_count % 3 == 0)
		var width = avenue_width if is_avenue else road_width
		
		for dy in range(grid.height):
			for dx in range(width):
				if x + dx < grid.width:
					grid.set_terrain(x + dx, dy, WorldGrid.TerrainType.ROAD)
					grid.set_height(x + dx, dy, 0.0)
		
		x += block_size
		avenue_count += 1
	
	# Horizontal streets
	var y = 0
	avenue_count = 0
	while y < grid.height:
		var is_avenue = (avenue_count % 3 == 0)
		var width = avenue_width if is_avenue else road_width
		
		for dx in range(grid.width):
			for dy in range(width):
				if y + dy < grid.height:
					grid.set_terrain(dx, y + dy, WorldGrid.TerrainType.ROAD)
					grid.set_height(dx, y + dy, 0.0)
		
		y += block_size
		avenue_count += 1
	
	print("    Street grid generated")

func _generate_radial_streets(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate radial/hub street pattern"""
	var center_x = grid.width / 2
	var center_y = grid.height / 2
	var road_width = max(2, int(config.get("road_width_m", 10) / 2.0))
	var max_length = min(grid.width, grid.height) / 2  # MOVED OUTSIDE LOOP
	
	print("    Generating radial streets...")
	
	# Create radial spokes
	var num_spokes = 8
	for i in range(num_spokes):
		var angle = (float(i) / num_spokes) * TAU  # TAU = 2*PI
		
		for length in range(0, max_length, 2):
			var x = center_x + int(cos(angle) * length)
			var y = center_y + int(sin(angle) * length)
			
			# Draw road with width
			for dy in range(-road_width / 2, road_width / 2 + 1):
				for dx in range(-road_width / 2, road_width / 2 + 1):
					var nx = x + dx
					var ny = y + dy
					if grid.is_valid(nx, ny):
						grid.set_terrain(nx, ny, WorldGrid.TerrainType.ROAD)
						grid.set_height(nx, ny, 0.0)
	
	# Create concentric ring roads
	var num_rings = 4
	for ring in range(1, num_rings + 1):
		var radius = (max_length / num_rings) * ring
		var circumference = int(TAU * radius)
		
		for i in range(circumference):
			var angle = (float(i) / circumference) * TAU
			var x = center_x + int(cos(angle) * radius)
			var y = center_y + int(sin(angle) * radius)
			
			for dy in range(-road_width / 2, road_width / 2 + 1):
				for dx in range(-road_width / 2, road_width / 2 + 1):
					var nx = x + dx
					var ny = y + dy
					if grid.is_valid(nx, ny):
						grid.set_terrain(nx, ny, WorldGrid.TerrainType.ROAD)
						grid.set_height(nx, ny, 0.0)

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
					grid.set_height(x, y, 0.1)

func _mark_districts(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Mark different city districts (for future use)"""
	# Districts will influence building types and density
	# For now, just log that we could implement this
	var districts = ["downtown", "commercial", "residential", "industrial"]
	print("    City districts defined: ", districts)

func place_required_poi(grid: WorldGrid, poi_type: String, tags: Array, rng: RandomNumberGenerator) -> POIData:
	"""Place a required POI in city"""
	print("    Placing city POI: ", poi_type)
	
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
	
	push_error("Could not place city POI: " + poi_type)
	return POIData.new()

func _get_poi_footprint(poi_type: String) -> int:
	"""Get footprint radius for city POI types"""
	match poi_type:
		"plaza", "city_square":
			return 12
		"park":
			return 15
		"subway_entrance", "metro_station":
			return 2
		"fountain":
			return 2
		"monument", "statue":
			return 3
		"parking_lot":
			return 8
		"bus_stop":
			return 1
		_:
			return 5

func _get_placement_strategy(poi_type: String) -> String:
	"""Determine placement strategy for city POI"""
	match poi_type:
		"plaza", "city_square":
			return "downtown"  # Central area
		"park":
			return "open_area"  # Larger open spaces
		"subway_entrance", "metro_station", "bus_stop":
			return "street_corner"  # At intersections
		"fountain", "monument", "statue":
			return "prominent"  # Visible locations
		"parking_lot":
			return "block"  # Within city blocks
		_:
			return "block"

func _find_poi_location(grid: WorldGrid, strategy: String, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location based on strategy"""
	match strategy:
		"downtown":
			return _find_downtown_location(grid, min_radius, rng)
		"open_area":
			return _find_open_area_location(grid, min_radius, rng)
		"street_corner":
			return _find_street_corner_location(grid, min_radius, rng)
		"prominent":
			return _find_prominent_location(grid, min_radius, rng)
		"block":
			return _find_block_location(grid, min_radius, rng)
		_:
			return grid.find_empty_spot(min_radius, 50, rng)

func _find_downtown_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find spot in downtown/center area"""
	var center_x = grid.width / 2
	var center_y = grid.height / 2
	var search_radius = min(grid.width, grid.height) / 6  # Search central 1/6
	
	for attempt in range(50):
		var offset_x = rng.randi_range(-search_radius, search_radius)
		var offset_y = rng.randi_range(-search_radius, search_radius)
		var x = center_x + offset_x
		var y = center_y + offset_y
		
		if grid.is_area_empty(x, y, min_radius):
			return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_open_area_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find large open area (for parks)"""
	for attempt in range(50):
		var x = rng.randi_range(min_radius * 2, grid.width - min_radius * 2)
		var y = rng.randi_range(min_radius * 2, grid.height - min_radius * 2)
		
		# Check for large empty area
		if grid.is_area_empty(x, y, min_radius * 2):
			return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_street_corner_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find spot at street intersection"""
	# Find intersection cells (road with roads in perpendicular directions)
	var intersections = []
	
	for y in range(2, grid.height - 2):
		for x in range(2, grid.width - 2):
			if grid.get_terrain(x, y) == WorldGrid.TerrainType.ROAD:
				# Check if intersection (roads in multiple directions)
				var has_north = grid.get_terrain(x, y - 1) == WorldGrid.TerrainType.ROAD
				var has_south = grid.get_terrain(x, y + 1) == WorldGrid.TerrainType.ROAD
				var has_east = grid.get_terrain(x + 1, y) == WorldGrid.TerrainType.ROAD
				var has_west = grid.get_terrain(x - 1, y) == WorldGrid.TerrainType.ROAD
				
				var road_count = 0
				if has_north: road_count += 1
				if has_south: road_count += 1
				if has_east: road_count += 1
				if has_west: road_count += 1
				
				if road_count >= 3:  # 3-way or 4-way intersection
					intersections.append(Vector2i(x, y))
	
	if intersections.is_empty():
		return _find_block_location(grid, min_radius, rng)
	
	# Pick random intersection and look nearby
	for attempt in range(50):
		var intersection = intersections[rng.randi() % intersections.size()]
		
		# Look for empty spot near intersection
		for distance in range(min_radius + 2, min_radius + 6):
			for angle_deg in [0, 90, 180, 270]:
				var angle_rad = deg_to_rad(angle_deg)
				var offset_x = int(cos(angle_rad) * distance)
				var offset_y = int(sin(angle_rad) * distance)
				var x = intersection.x + offset_x
				var y = intersection.y + offset_y
				
				if grid.is_area_empty(x, y, min_radius):
					return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_prominent_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find visible location (near major roads)"""
	# Find road cells
	var road_cells = []
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.get_terrain(x, y) == WorldGrid.TerrainType.ROAD:
				road_cells.append(Vector2i(x, y))
	
	if road_cells.is_empty():
		return grid.find_empty_spot(min_radius, 50, rng)
	
	# Pick random road cell and look nearby
	for attempt in range(50):
		var road_cell = road_cells[rng.randi() % road_cells.size()]
		
		for distance in range(min_radius + 2, min_radius + 8):
			for angle_deg in range(0, 360, 45):
				var angle_rad = deg_to_rad(angle_deg)
				var offset_x = int(cos(angle_rad) * distance)
				var offset_y = int(sin(angle_rad) * distance)
				var x = road_cell.x + offset_x
				var y = road_cell.y + offset_y
				
				if grid.is_area_empty(x, y, min_radius):
					return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_block_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find spot within a city block (between roads)"""
	for attempt in range(50):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		# Must be on sidewalk or grass (not road)
		var terrain = grid.get_terrain(x, y)
		if terrain == WorldGrid.TerrainType.SIDEWALK or terrain == WorldGrid.TerrainType.GRASS:
			if grid.is_area_empty(x, y, min_radius):
				return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func generate_buildings(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Cities have many buildings"""
	print("  Generating city buildings...")
	# Buildings will be placed by template system

func get_biome_type() -> String:
	return "city"
