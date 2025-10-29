# graveyard_generator.gd
# Generator for graveyard locations with somber, organized layouts
class_name GraveyardGenerator
extends LocationGeneratorBase

func generate_foundation(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate graveyard foundation with paths and sections"""
	print("  Generating graveyard foundation...")
	
	# Generate mostly flat terrain with slight variation
	_generate_graveyard_heightmap(grid, rng)
	
	# Create main paths (cross pattern or grid)
	_generate_graveyard_paths(grid, config, rng)
	
	# Define burial sections
	_create_burial_sections(grid, config, rng)
	
	# Add iron fence perimeter (optional)
	if config.get("has_fence", true):
		_add_perimeter_fence(grid, rng)

func _generate_graveyard_heightmap(grid: WorldGrid, rng: RandomNumberGenerator):
	"""Generate subtle terrain variation for graveyard"""
	var noise = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.008  # Very gentle variation
	noise.fractal_octaves = 2
	
	for y in range(grid.height):
		for x in range(grid.width):
			var value = noise.get_noise_2d(x, y)
			value = (value + 1.0) * 0.5
			value *= 3.0  # 0-3 meters (very gentle hills)
			grid.set_height(x, y, value)

func _generate_graveyard_paths(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Generate main paths through graveyard"""
	var layout = config.get("layout", "cross")
	var path_width = max(2, int(config.get("path_width_m", 3) / 2.0))
	
	print("    Creating graveyard paths (layout: %s)..." % layout)
	
	match layout:
		"cross":
			_create_cross_paths(grid, path_width)
		"grid":
			_create_grid_paths(grid, path_width)
		_:
			_create_cross_paths(grid, path_width)

func _create_cross_paths(grid: WorldGrid, path_width: int):
	"""Create cross-shaped main paths"""
	var center_x = grid.width / 2
	var center_y = grid.height / 2
	
	# Vertical main path
	for y in range(grid.height):
		for w in range(path_width):
			var x = center_x - path_width / 2 + w
			if grid.is_valid(x, y):
				grid.set_terrain(x, y, WorldGrid.TerrainType.DIRT)
				grid.set_height(x, y, grid.get_height(x, y) * 0.95)
	
	# Horizontal main path
	for x in range(grid.width):
		for w in range(path_width):
			var y = center_y - path_width / 2 + w
			if grid.is_valid(x, y):
				grid.set_terrain(x, y, WorldGrid.TerrainType.DIRT)
				grid.set_height(x, y, grid.get_height(x, y) * 0.95)

func _create_grid_paths(grid: WorldGrid, path_width: int):
	"""Create grid of paths dividing sections"""
	var section_size = 60  # cells between paths
	
	# Vertical paths
	var x = 0
	while x < grid.width:
		for dy in range(grid.height):
			for w in range(path_width):
				if x + w < grid.width:
					grid.set_terrain(x + w, dy, WorldGrid.TerrainType.DIRT)
					grid.set_height(x + w, dy, grid.get_height(x + w, dy) * 0.95)
		x += section_size
	
	# Horizontal paths
	var y = 0
	while y < grid.height:
		for dx in range(grid.width):
			for w in range(path_width):
				if y + w < grid.height:
					grid.set_terrain(dx, y + w, WorldGrid.TerrainType.DIRT)
					grid.set_height(dx, y + w, grid.get_height(dx, y + w) * 0.95)
		y += section_size

func _create_burial_sections(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Mark sections for organized grave placement"""
	# Sections are just areas of grass between paths
	# Actual graves will be placed as POIs later
	var num_sections = config.get("section_count", 6)
	print("    Created %d burial sections" % num_sections)

func _add_perimeter_fence(grid: WorldGrid, rng: RandomNumberGenerator):
	"""Add iron fence around perimeter"""
	var margin = 5
	
	# Top edge
	for x in range(margin, grid.width - margin):
		if grid.is_valid(x, margin):
			# Fence is just marked terrain for now, decorations later
			pass
	
	# Bottom edge
	for x in range(margin, grid.width - margin):
		if grid.is_valid(x, grid.height - margin - 1):
			pass
	
	# Left edge
	for y in range(margin, grid.height - margin):
		if grid.is_valid(margin, y):
			pass
	
	# Right edge
	for y in range(margin, grid.height - margin):
		if grid.is_valid(grid.width - margin - 1, y):
			pass

func place_required_poi(grid: WorldGrid, poi_type: String, tags: Array, rng: RandomNumberGenerator) -> POIData:
	"""Place a required POI in graveyard"""
	print("    Placing graveyard POI: ", poi_type)
	
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
	
	push_error("Could not place graveyard POI: " + poi_type)
	return POIData.new()

func _get_poi_footprint(poi_type: String) -> int:
	"""Get footprint radius for graveyard POI types"""
	match poi_type:
		"mausoleum", "chapel":
			return 8
		"crypt":
			return 5
		"grave_cluster", "memorial_wall":
			return 6
		"monument", "angel_statue":
			return 3
		"old_tree":
			return 4
		_:
			return 4

func _get_placement_strategy(poi_type: String) -> String:
	"""Determine placement strategy for graveyard POI"""
	match poi_type:
		"chapel":
			return "entrance"  # Near entrance
		"mausoleum":
			return "prominent"  # Along main paths
		"crypt":
			return "section"  # Within burial sections
		"grave_cluster":
			return "section"  # Within burial sections
		"monument", "angel_statue", "memorial_wall":
			return "prominent"  # Along main paths
		"old_tree":
			return "corner"  # In corners
		_:
			return "section"

func _find_poi_location(grid: WorldGrid, strategy: String, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find location based on strategy"""
	match strategy:
		"entrance":
			return _find_entrance_location(grid, min_radius, rng)
		"prominent":
			return _find_prominent_location(grid, min_radius, rng)
		"section":
			return _find_section_location(grid, min_radius, rng)
		"corner":
			return _find_corner_location(grid, min_radius, rng)
		_:
			return grid.find_empty_spot(min_radius, 50, rng)

func _find_entrance_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find spot near entrance (bottom center)"""
	var entrance_x = grid.width / 2
	var entrance_y = grid.height - grid.height / 4
	
	for attempt in range(50):
		var offset_x = rng.randi_range(-20, 20)
		var offset_y = rng.randi_range(-20, 20)
		var x = entrance_x + offset_x
		var y = entrance_y + offset_y
		
		if grid.is_area_empty(x, y, min_radius):
			return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_prominent_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find spot along main paths (visible location)"""
	# Find path cells
	var path_cells = []
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.get_terrain(x, y) == WorldGrid.TerrainType.DIRT:
				path_cells.append(Vector2i(x, y))
	
	if path_cells.is_empty():
		return grid.find_empty_spot(min_radius, 50, rng)
	
	# Pick random path cell and look nearby
	for attempt in range(50):
		var path_cell = path_cells[rng.randi() % path_cells.size()]
		
		# Look for empty space adjacent to path
		for distance in range(min_radius + 3, min_radius + 10):
			for angle_deg in [0, 90, 180, 270]:  # Cardinal directions
				var angle_rad = deg_to_rad(angle_deg)
				var offset_x = int(cos(angle_rad) * distance)
				var offset_y = int(sin(angle_rad) * distance)
				var x = path_cell.x + offset_x
				var y = path_cell.y + offset_y
				
				if grid.is_area_empty(x, y, min_radius):
					return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_section_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find spot in burial section (grass area between paths)"""
	for attempt in range(50):
		var x = rng.randi_range(min_radius, grid.width - min_radius - 1)
		var y = rng.randi_range(min_radius, grid.height - min_radius - 1)
		
		# Must be on grass (not path)
		if grid.get_terrain(x, y) == WorldGrid.TerrainType.GRASS:
			if grid.is_area_empty(x, y, min_radius):
				# Check that area is mostly grass (in a section, not on path)
				var grass_count = 0
				var total = 0
				for dy in range(-min_radius, min_radius + 1):
					for dx in range(-min_radius, min_radius + 1):
						if dx*dx + dy*dy <= min_radius*min_radius:
							var nx = x + dx
							var ny = y + dy
							if grid.is_valid(nx, ny):
								total += 1
								if grid.get_terrain(nx, ny) == WorldGrid.TerrainType.GRASS:
									grass_count += 1
				
				if total > 0 and float(grass_count) / total > 0.7:
					return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func _find_corner_location(grid: WorldGrid, min_radius: int, rng: RandomNumberGenerator) -> Vector2i:
	"""Find spot in a corner of the graveyard"""
	var corners = [
		Vector2i(grid.width / 4, grid.height / 4),          # Top-left
		Vector2i(grid.width * 3 / 4, grid.height / 4),      # Top-right
		Vector2i(grid.width / 4, grid.height * 3 / 4),      # Bottom-left
		Vector2i(grid.width * 3 / 4, grid.height * 3 / 4),  # Bottom-right
	]
	
	for attempt in range(50):
		var corner = corners[rng.randi() % corners.size()]
		var offset_x = rng.randi_range(-15, 15)
		var offset_y = rng.randi_range(-15, 15)
		var x = corner.x + offset_x
		var y = corner.y + offset_y
		
		if grid.is_area_empty(x, y, min_radius):
			return Vector2i(x, y)
	
	return Vector2i(-1, -1)

func generate_buildings(grid: WorldGrid, config: Dictionary, rng: RandomNumberGenerator):
	"""Graveyards have few buildings - mainly chapels and crypts"""
	print("  Generating graveyard structures...")
	# Buildings will be placed by template system

func get_biome_type() -> String:
	return "graveyard"
