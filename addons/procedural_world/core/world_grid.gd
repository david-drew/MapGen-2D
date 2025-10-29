# world_grid.gd
# Core 2.5D grid system for terrain and placement
class_name WorldGrid
extends RefCounted

## Grid dimensions
var width: int
var height: int

## Cell data (flat arrays for performance)
var terrain_types: PackedByteArray  # TerrainType per cell
var heights: PackedFloat32Array  # Height per cell
var occupancy_types: PackedByteArray  # OccupancyType per cell
var path_markers: PackedByteArray  # Boolean path markers (0 or 1)

## Enums
enum TerrainType {
	EMPTY = 0,
	GRASS = 1,
	DIRT = 2,
	ROAD = 3,
	SIDEWALK = 4,
	WATER = 5,
	ROCK = 6,
	SAND = 7,
	FOREST = 8,    # Dense woodland/trees
	SWAMP = 9,     # Wetland/marshy areas
	DESERT = 10,   # Arid sandy/rocky areas
	BEACH = 11     # Sandy shoreline
}

enum OccupancyType {
	EMPTY = 0,
	RESERVED = 1,
	BUILDING = 2,
	POI = 3,
	DECORATION = 4,
	BLOCKED = 5
}

func _init(w: int, h: int):
	width = w
	height = h
	
	# Initialize arrays
	var size = width * height
	terrain_types.resize(size)
	heights.resize(size)
	occupancy_types.resize(size)
	path_markers.resize(size)
	
	terrain_types.fill(TerrainType.GRASS)
	heights.fill(0.0)
	occupancy_types.fill(OccupancyType.EMPTY)
	path_markers.fill(0)  # No paths initially

func get_index(x: int, y: int) -> int:
	"""Convert 2D coords to flat array index"""
	return y * width + x

func is_valid(x: int, y: int) -> bool:
	"""Check if coordinates are within grid"""
	return x >= 0 and x < width and y >= 0 and y < height

# Terrain access
func get_terrain(x: int, y: int) -> TerrainType:
	if not is_valid(x, y):
		return TerrainType.EMPTY
	return terrain_types[get_index(x, y)]

func set_terrain(x: int, y: int, terrain: TerrainType):
	if is_valid(x, y):
		terrain_types[get_index(x, y)] = terrain

# Height access
func get_height(x: int, y: int) -> float:
	if not is_valid(x, y):
		return 0.0
	return heights[get_index(x, y)]

func set_height(x: int, y: int, h: float):
	if is_valid(x, y):
		heights[get_index(x, y)] = h

# Occupancy access
func get_occupancy(x: int, y: int) -> OccupancyType:
	if not is_valid(x, y):
		return OccupancyType.BLOCKED
	return occupancy_types[get_index(x, y)]

func set_occupancy(x: int, y: int, occ: OccupancyType):
	if is_valid(x, y):
		occupancy_types[get_index(x, y)] = occ

# Path access
func is_path(x: int, y: int) -> bool:
	if not is_valid(x, y):
		return false
	return path_markers[get_index(x, y)] == 1

func set_path(x: int, y: int, is_path_value: bool):
	if is_valid(x, y):
		path_markers[get_index(x, y)] = 1 if is_path_value else 0

# Area operations
func reserve_area(center_x: int, center_y: int, radius: int) -> bool:
	"""Reserve a circular area - returns true if successful"""
	# First check if area is available
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx*dx + dy*dy <= radius*radius:
				var x = center_x + dx
				var y = center_y + dy
				
				if not is_valid(x, y):
					return false
				
				if get_occupancy(x, y) != OccupancyType.EMPTY:
					return false
	
	# Actually reserve
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx*dx + dy*dy <= radius*radius:
				set_occupancy(center_x + dx, center_y + dy, OccupancyType.RESERVED)
	
	return true

func is_area_empty(center_x: int, center_y: int, radius: int) -> bool:
	"""Check if circular area is empty"""
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx*dx + dy*dy <= radius*radius:
				var x = center_x + dx
				var y = center_y + dy
				
				if not is_valid(x, y):
					return false
				
				if get_occupancy(x, y) != OccupancyType.EMPTY:
					return false
	
	return true

func is_area_buildable(center_x: int, center_y: int, radius: int) -> bool:
	"""Check if area is suitable for buildings (grass only, no roads/sidewalks)"""
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx*dx + dy*dy <= radius*radius:
				var x = center_x + dx
				var y = center_y + dy
				
				if not is_valid(x, y):
					return false
				
				# Must be empty occupancy
				if get_occupancy(x, y) != OccupancyType.EMPTY:
					return false
				
				# Must be grass terrain (not road, not sidewalk)
				var terrain = get_terrain(x, y)
				if terrain != TerrainType.GRASS:
					return false
	
	return true

func find_empty_spot(min_radius: int, max_attempts: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find a random empty spot with given radius"""
	for attempt in range(max_attempts):
		var x = rng.randi_range(min_radius, width - min_radius - 1)
		var y = rng.randi_range(min_radius, height - min_radius - 1)
		
		if is_area_empty(x, y, min_radius):
			return Vector2i(x, y)
	
	return Vector2i(-1, -1)  # Failed

func clear_area(x: int, y: int, radius: int):
	"""Clear occupancy in circular area (set to EMPTY)"""
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx*dx + dy*dy <= radius*radius:
				var clear_x = x + dx
				var clear_y = y + dy
				
				if is_valid(clear_x, clear_y):
					set_occupancy(clear_x, clear_y, OccupancyType.EMPTY)

func fill_terrain(x: int, y: int, radius: int, terrain: TerrainType):
	"""Fill circular area with terrain type"""
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx*dx + dy*dy <= radius*radius:
				var fill_x = x + dx
				var fill_y = y + dy
				
				if is_valid(fill_x, fill_y):
					set_terrain(fill_x, fill_y, terrain)

# Coordinate conversion
func grid_to_world(grid_x: int, grid_y: int) -> Vector3:
	"""Convert grid coordinates to world position (2m cells)"""
	var h = get_height(grid_x, grid_y)
	return Vector3(grid_x * 2.0, h, grid_y * 2.0)

func world_to_grid(world_pos: Vector3) -> Vector2i:
	"""Convert world position to grid coordinates"""
	return Vector2i(int(world_pos.x / 2.0), int(world_pos.z / 2.0))

# Utility
func count_terrain_type(terrain: TerrainType) -> int:
	"""Count how many cells have the specified terrain type"""
	var count = 0
	var size = width * height
	for i in range(size):
		if terrain_types[i] == terrain:
			count += 1
	return count

func count_occupancy_type(occupancy: OccupancyType) -> int:
	"""Count how many cells have the specified occupancy type"""
	var count = 0
	var size = width * height
	for i in range(size):
		if occupancy_types[i] == occupancy:
			count += 1
	return count

func get_neighbors(x: int, y: int, include_diagonals: bool = false) -> Array:
	"""Get valid neighboring cells"""
	var neighbors = []
	
	# Orthogonal neighbors
	var offsets = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	
	# Add diagonals if requested
	if include_diagonals:
		offsets.append_array([
			Vector2i(-1, -1), Vector2i(1, -1),
			Vector2i(-1, 1), Vector2i(1, 1)
		])
	
	for offset in offsets:
		var nx = x + offset.x
		var ny = y + offset.y
		if is_valid(nx, ny):
			neighbors.append(Vector2i(nx, ny))
	
	return neighbors

# Display helpers
func get_terrain_name(terrain: TerrainType) -> String:
	"""Get string name for terrain type"""
	match terrain:
		TerrainType.EMPTY: return "Empty"
		TerrainType.GRASS: return "Grass"
		TerrainType.DIRT: return "Dirt"
		TerrainType.ROAD: return "Road"
		TerrainType.SIDEWALK: return "Sidewalk"
		TerrainType.WATER: return "Water"
		TerrainType.ROCK: return "Rock"
		TerrainType.SAND: return "Sand"
		TerrainType.FOREST: return "Forest"
		TerrainType.SWAMP: return "Swamp"
		TerrainType.DESERT: return "Desert"
		TerrainType.BEACH: return "Beach"
		_: return "Unknown"

func get_occupancy_name(occ: OccupancyType) -> String:
	"""Get string name for occupancy type"""
	match occ:
		OccupancyType.EMPTY: return "Empty"
		OccupancyType.RESERVED: return "Reserved"
		OccupancyType.BUILDING: return "Building"
		OccupancyType.POI: return "POI"
		OccupancyType.DECORATION: return "Decoration"
		OccupancyType.BLOCKED: return "Blocked"
		_: return "Unknown"

func get_terrain_color(terrain: TerrainType) -> Color:
	"""Get color for terrain type for visualization"""
	match terrain:
		TerrainType.EMPTY: return Color(0.1, 0.1, 0.1)        # Dark gray
		TerrainType.GRASS: return Color(0.3, 0.7, 0.3)        # Green
		TerrainType.DIRT: return Color(0.6, 0.4, 0.2)         # Brown
		TerrainType.ROAD: return Color(0.3, 0.3, 0.3)         # Gray
		TerrainType.SIDEWALK: return Color(0.5, 0.5, 0.5)     # Light gray
		TerrainType.WATER: return Color(0.2, 0.4, 0.8)        # Blue
		TerrainType.ROCK: return Color(0.5, 0.5, 0.5)         # Gray
		TerrainType.SAND: return Color(0.9, 0.8, 0.6)         # Tan
		TerrainType.FOREST: return Color(0.1, 0.5, 0.1)       # Dark green
		TerrainType.SWAMP: return Color(0.3, 0.5, 0.3)        # Murky green
		TerrainType.DESERT: return Color(0.9, 0.7, 0.4)       # Sandy yellow
		TerrainType.BEACH: return Color(0.95, 0.9, 0.7)       # Light sand
		_: return Color(1.0, 0.0, 1.0)                        # Magenta (error)

func get_occupancy_color(occ: OccupancyType) -> Color:
	"""Get color for occupancy type for debugging visualization"""
	match occ:
		OccupancyType.EMPTY: return Color(0.0, 0.0, 0.0, 0.0)       # Transparent
		OccupancyType.RESERVED: return Color(1.0, 1.0, 0.0, 0.3)    # Yellow tint
		OccupancyType.BUILDING: return Color(0.8, 0.2, 0.2, 0.6)    # Red
		OccupancyType.POI: return Color(0.2, 0.2, 0.8, 0.6)         # Blue
		OccupancyType.DECORATION: return Color(0.2, 0.8, 0.2, 0.4)  # Green
		OccupancyType.BLOCKED: return Color(0.0, 0.0, 0.0, 0.8)     # Black
		_: return Color(1.0, 0.0, 1.0, 0.5)                         # Magenta (error)
