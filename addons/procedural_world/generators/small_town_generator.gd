# small_town_generator_v2.gd
# Improved generator with specific building types
extends LocationGeneratorBase
class_name SmallTownGeneratorV2

# Building type configurations
const BUILDING_CONFIGS = {
	"house": {"min_size": Vector2i(4, 4), "max_size": Vector2i(6, 6), "color": Color(0.7, 0.5, 0.3)},
	"apartment": {"min_size": Vector2i(8, 10), "max_size": Vector2i(12, 15), "color": Color(0.6, 0.5, 0.4)},
	"store": {"min_size": Vector2i(6, 6), "max_size": Vector2i(10, 8), "color": Color(0.5, 0.6, 0.7)},
	"restaurant": {"min_size": Vector2i(5, 6), "max_size": Vector2i(8, 9), "color": Color(0.8, 0.6, 0.4)},
	"hotel": {"min_size": Vector2i(10, 12), "max_size": Vector2i(15, 18), "color": Color(0.7, 0.6, 0.5)},
	"clinic": {"min_size": Vector2i(6, 6), "max_size": Vector2i(8, 8), "color": Color(0.9, 0.9, 0.9)},
	"hospital": {"min_size": Vector2i(15, 15), "max_size": Vector2i(25, 25), "color": Color(0.95, 0.95, 0.95)},
}

var buildings: Array[BuildingData] = []

func generate_foundation(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate town foundation with roads"""
	print("  Generating small town foundation...")
	
	# Generate VERY slight terrain variation (towns are mostly flat)
	var noise = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.01 * 0.2
	noise.fractal_octaves = 2
	
	for y in range(grid.height):
		for x in range(grid.width):
			var value = noise.get_noise_2d(x, y)
			value = (value + 1.0) * 0.5
			value *= 2.0  # 0-2 meters for towns
			grid.set_height(x, y, value)
	
	# Generate road network
	var layout = config.get("town_layout", "grid")
	if layout == "grid":
		_generate_grid_roads(grid, config, rng)
	
	# Add sidewalks
	_add_sidewalks(grid, config)

func _generate_grid_roads(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate grid-style roads"""
	var block_size = int(config.get("block_size_m", 80) / 2.0)
	var road_width = max(1, int(config.get("road_width_m", 6) / 2.0))
	
	print("    Block size: %d cells, Road width: %d cells" % [block_size, road_width])
	
	# Vertical roads
	var x = 0
	while x < grid.width:
		for dy in range(grid.height):
			for dx in range(road_width):
				if x + dx < grid.width:
					grid.set_terrain(x + dx, dy, WorldGrid.TerrainType.ROAD)
					grid.set_height(x + dx, dy, 0.0)
		x += block_size
	
	# Horizontal roads
	var y = 0
	while y < grid.height:
		for dx in range(grid.width):
			for dy in range(road_width):
				if y + dy < grid.height:
					grid.set_terrain(dx, y + dy, WorldGrid.TerrainType.ROAD)
					grid.set_height(dx, y + dy, 0.0)
		y += block_size
	
	print("    Roads generated")

func _add_sidewalks(grid: WorldGrid, config: Dictionary):
	"""Add sidewalks adjacent to roads"""
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.get_terrain(x, y) == WorldGrid.TerrainType.GRASS:
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
					grid.set_height(x, y, 0.0)

func place_required_poi(grid: WorldGrid, poi_type: String, tags: Array, rng: RandomNumberGenerator) -> POIData:
	"""Place a required POI in town"""
	print("    Placing POI: ", poi_type)
	
	var poi = POIData.new(poi_type)
	for tag in tags:
		poi.tags.append(str(tag))
	poi.required = true
	poi.footprint_radius = _get_poi_footprint(poi_type)
	
	var strategy = _get_placement_strategy(poi_type)
	
	var max_attempts = 100
	for attempt in range(max_attempts):
		var pos = _find_poi_location(grid, strategy, poi.footprint_radius, rng)
		
		if pos != Vector2i(-1, -1):
			if grid.reserve_area(pos.x, pos.y, poi.footprint_radius):
				poi.position = pos
				for dy in range(-poi.footprint_radius, poi.footprint_radius + 1):
					for dx in range(-poi.footprint_radius, poi.footprint_radius + 1):
						if dx*dx + dy*dy <= poi.footprint_radius*poi.footprint_radius:
							var px = pos.x + dx
							var py = pos.y + dy
							if grid.is_valid(px, py):
								grid.set_occupancy(px, py, WorldGrid.OccupancyType.POI)
				print("      Placed at: ", pos)
				return poi
	
	push_error("Could not place POI: " + poi_type)
	return POIData.new()

func _get_poi_footprint(poi_type: String) -> int:
	match poi_type:
		"chapel", "church": return 8
		"hotel", "inn": return 6
		"town_square": return 10
		"fountain": return 3
		_: return 5

func _get_placement_strategy(poi_type: String) -> String:
	match poi_type:
		"chapel", "church": return "central"
		"hotel", "inn": return "main_street"
		"coffeehouse", "diner": return "commercial"
		"town_square", "fountain": return "central"
		_: return "random"

func _find_poi_location(grid: WorldGrid, strategy: String, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	match strategy:
		"central": return _find_central_location(grid, min_radius, rng)
		"main_street": return _find_street_location(grid, min_radius, rng)
		"commercial": return _find_commercial_location(grid, min_radius, rng)
		_: return grid.find_empty_spot(min_radius, 50, rng)

func _find_central_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	var center_x = grid.width / 2
	var center_y = grid.height / 2
	var search_radius = min(grid.width, grid.height) / 4
	
	for attempt in range(50):
		var offset_x = rng.randi_range(-search_radius, search_radius)
		var offset_y = rng.randi_range(-search_radius, search_radius)
		var x = center_x + offset_x
		var y = center_y + offset_y
		
		if grid.is_area_empty(x, y, min_radius):
			return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_street_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	var road_cells = []
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.get_terrain(x, y) == WorldGrid.TerrainType.ROAD:
				road_cells.append(Vector2i(x, y))
	
	if road_cells.is_empty():
		return Vector2i(-1, -1)
	
	for attempt in range(50):
		var road_cell = road_cells[rng.randi() % road_cells.size()]
		
		for distance in range(min_radius + 2, min_radius + 10):
			for angle_deg in range(0, 360, 45):
				var angle_rad = deg_to_rad(angle_deg)
				var offset_x = int(cos(angle_rad) * distance)
				var offset_y = int(sin(angle_rad) * distance)
				var x = road_cell.x + offset_x
				var y = road_cell.y + offset_y
				
				if grid.is_area_empty(x, y, min_radius):
					return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_commercial_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	return _find_street_location(grid, min_radius, rng)

func generate_buildings(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate specific building types"""
	print("  Generating buildings...")
	
	buildings.clear()
	
	var is_city = config.get("population_density", "medium") == "high"
	
	# Determine counts based on town vs city
	var counts = _get_building_counts(is_city)
	
	# Place each building type
	_place_buildings_of_type(grid, "hospital", counts.hospital, rng)
	_place_buildings_of_type(grid, "clinic", counts.clinic, rng)
	_place_buildings_of_type(grid, "hotel", counts.hotel, rng)
	_place_buildings_of_type(grid, "apartment", counts.apartment, rng)
	_place_buildings_of_type(grid, "restaurant", counts.restaurant, rng)
	_place_buildings_of_type(grid, "store", counts.store, rng)
	_place_buildings_of_type(grid, "house", counts.house, rng)
	
	print("    Placed %d total buildings:" % buildings.size())
	print("      Houses: %d, Apartments: %d, Stores: %d" % [
		_count_type("house"), _count_type("apartment"), _count_type("store")
	])
	print("      Restaurants: %d, Hotels: %d, Clinics: %d, Hospitals: %d" % [
		_count_type("restaurant"), _count_type("hotel"), _count_type("clinic"), _count_type("hospital")
	])

func _get_building_counts(is_city: bool) -> Dictionary:
	"""Get building counts for town or city"""
	if is_city:
		return {
			"house": randi_range(60, 100),
			"apartment": randi_range(10, 20),
			"store": randi_range(20, 30),
			"restaurant": randi_range(10, 20),
			"hotel": randi_range(5, 10),
			"clinic": randi_range(1, 5),
			"hospital": randi_range(1, 2)
		}
	else:  # Town
		return {
			"house": randi_range(30, 50),
			"apartment": randi_range(5, 10),
			"store": randi_range(5, 10),
			"restaurant": randi_range(3, 6),
			"hotel": randi_range(1, 4),
			"clinic": randi_range(0, 2),
			"hospital": randi_range(0, 1)
		}

func _place_buildings_of_type(grid: WorldGrid, building_type: String, count: int, rng: RandomNumberGenerator):
	"""Place multiple buildings of a specific type"""
	var config = BUILDING_CONFIGS[building_type]
	
	for i in range(count):
		var building = _try_place_building(grid, building_type, config, rng)
		if building and building.is_valid():
			buildings.append(building)

func _try_place_building(grid: WorldGrid, building_type: String, config: Dictionary, rng: RandomNumberGenerator, max_attempts: int = 30) -> BuildingData:
	"""Try to place a single building"""
	for attempt in range(max_attempts):
		# Random size within config range
		var size = Vector2i(
			rng.randi_range(config.min_size.x, config.max_size.x),
			rng.randi_range(config.min_size.y, config.max_size.y)
		)
		
		# Random position
		var x = rng.randi_range(size.x / 2 + 2, grid.width - size.x / 2 - 2)
		var y = rng.randi_range(size.y / 2 + 2, grid.height - size.y / 2 - 2)
		
		# Check if can place
		if _can_place_building_rect(grid, Vector2i(x, y), size):
			# Mark cells as building
			var building = BuildingData.new(building_type, Vector2i(x, y), size)
			for cell in building.get_cells():
				if grid.is_valid(cell.x, cell.y):
					grid.set_occupancy(cell.x, cell.y, WorldGrid.OccupancyType.BUILDING)
			
			return building
	
	return null

func _can_place_building_rect(grid: WorldGrid, center: Vector2i, size: Vector2i) -> bool:
	"""Check if a rectangular building can be placed"""
	var half_w = size.x / 2
	var half_h = size.y / 2
	
	for dy in range(-half_h, half_h + 1):
		for dx in range(-half_w, half_w + 1):
			var x = center.x + dx
			var y = center.y + dy
			
			if not grid.is_valid(x, y):
				return false
			
			# Must be grass and empty
			if grid.get_terrain(x, y) != WorldGrid.TerrainType.GRASS:
				return false
			if grid.get_occupancy(x, y) != WorldGrid.OccupancyType.EMPTY:
				return false
	
	return true

func _count_type(type: String) -> int:
	var count = 0
	for building in buildings:
		if building.building_type == type:
			count += 1
	return count

func get_buildings() -> Array[BuildingData]:
	"""Get all placed buildings"""
	return buildings

func get_biome_type() -> String:
	return "small_town"
