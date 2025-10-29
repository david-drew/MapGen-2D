# location_generator_base.gd
# Abstract base class for location generators
extends RefCounted
class_name LocationGeneratorBase

## Override these methods in derived classes

func generate_foundation(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate base terrain and primary structure"""
	push_error("generate_foundation not implemented in " + get_script().resource_path)

func place_required_poi(grid: WorldGrid, poi_type: String, tags: Array, rng: RandomNumberGenerator) -> POIData:
	"""Place a required POI and return its data"""
	push_error("place_required_poi not implemented in " + get_script().resource_path)
	return POIData.new()

func place_optional_poi(grid: WorldGrid, poi_type: String, rng: RandomNumberGenerator) -> POIData:
	"""Place an optional POI and return its data"""
	# Default: try to place like required
	return place_required_poi(grid, poi_type, [], rng)

func generate_buildings(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate buildings/structures"""
	# Default: no buildings
	pass

func get_biome_type() -> String:
	"""Return the biome type for this generator (e.g. 'forest', 'small_town')"""
	push_error("get_biome_type not implemented in " + get_script().resource_path)
	return "unknown"

## NEW: Shared methods for template-based placement

func place_poi(
	grid: WorldGrid,
	poi_type: String,
	tags: Array,
	required: bool,
	rng: RandomNumberGenerator
) -> POIData:
	"""
	Place a POI using template data for properties.
	This is called by the template system for both required and optional POIs.
	Delegates to the biome-specific place_required_poi() implementation.
	"""
	
	# Get POI properties from template
	var template_mgr = BiomeTemplateManager.get_instance()
	var biome_type = get_biome_type()
	var poi_list = template_mgr.get_poi_list_with_density(biome_type, {})
	
	# Find this POI type's radius from template (no hardcoding!)
	var template_radius = 3  # Fallback default
	for poi_config in poi_list:
		if poi_config.get("type") == poi_type:
			template_radius = poi_config.get("radius", 3)
			break
	
	# Use the existing biome-specific placement logic
	var poi = place_required_poi(grid, poi_type, tags, rng)
	
	# Override the radius with template value if POI was placed
	if poi and poi.is_valid():
		poi.footprint_radius = template_radius
		poi.required = required
	
	return poi

func place_building(
	grid: WorldGrid,
	building_type: String,
	size: Vector2i,
	tags: Array,
	rng: RandomNumberGenerator
) -> BuildingData:
	"""
	Place a building of the given type and size.
	Uses shared placement logic - tries to find empty space and marks it occupied.
	"""
	
	var max_attempts = 100
	
	for attempt in range(max_attempts):
		# Random position
		var x = rng.randi_range(0, grid.width - size.x - 1)
		var y = rng.randi_range(0, grid.height - size.y - 1)
		
		# Check if location is suitable
		if _can_place_building_at(grid, x, y, size):
			# Create building
			var building = BuildingData.new()
			building.building_type = building_type
			building.position = Vector2i(x, y)
			building.size = size
			
			# Add tags individually (BuildingData.tags is Array[String])
			for tag in tags:
				building.tags.append(str(tag))
			
			# Mark area as occupied
			_mark_building_area(grid, x, y, size)
			
			return building
	
	# Failed to place
	return null

func _can_place_building_at(grid: WorldGrid, x: int, y: int, size: Vector2i) -> bool:
	"""Check if building can be placed at location"""
	for dy in range(size.y):
		for dx in range(size.x):
			var check_x = x + dx
			var check_y = y + dy
			
			if not grid.is_valid(check_x, check_y):
				return false
			
			var occupancy = grid.get_occupancy(check_x, check_y)
			
			# Must be empty
			if occupancy != WorldGrid.OccupancyType.EMPTY:
				return false
			
			# Prefer grass terrain (avoid roads, water, etc.)
			var terrain = grid.get_terrain(check_x, check_y)
			if terrain == WorldGrid.TerrainType.ROAD or terrain == WorldGrid.TerrainType.WATER:
				return false
	
	return true

func _mark_building_area(grid: WorldGrid, x: int, y: int, size: Vector2i):
	"""Mark area as occupied by building"""
	for dy in range(size.y):
		for dx in range(size.x):
			var check_x = x + dx
			var check_y = y + dy
			
			if grid.is_valid(check_x, check_y):
				grid.set_occupancy(check_x, check_y, WorldGrid.OccupancyType.BUILDING)

## Helper methods available to all generators

func generate_heightmap(grid: WorldGrid, roughness: float, rng: RandomNumberGenerator):
	"""Generate terrain height using Perlin noise"""
	var noise = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.01 * roughness
	noise.fractal_octaves = 3
	
	for y in range(grid.height):
		for x in range(grid.width):
			var value = noise.get_noise_2d(x, y)
			value = (value + 1.0) * 0.5  # Normalize to 0-1
			value *= 20.0  # Scale to meters
			grid.set_height(x, y, value)

func draw_line_on_grid(grid: WorldGrid, from: Vector2i, to: Vector2i, terrain: WorldGrid.TerrainType):
	"""Draw a line of terrain type on grid (Bresenham's algorithm)"""
	var dx = abs(to.x - from.x)
	var dy = abs(to.y - from.y)
	var sx = 1 if from.x < to.x else -1
	var sy = 1 if from.y < to.y else -1
	var err = dx - dy
	
	var x = from.x
	var y = from.y
	
	while true:
		if grid.is_valid(x, y):
			grid.set_terrain(x, y, terrain)
		
		if x == to.x and y == to.y:
			break
		
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy

func fill_rect_on_grid(grid: WorldGrid, top_left: Vector2i, size: Vector2i, terrain: WorldGrid.TerrainType):
	"""Fill a rectangular area with terrain type"""
	for dy in range(size.y):
		for dx in range(size.x):
			var x = top_left.x + dx
			var y = top_left.y + dy
			if grid.is_valid(x, y):
				grid.set_terrain(x, y, terrain)
