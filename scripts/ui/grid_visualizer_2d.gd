# grid_visualizer_2d.gd
# Visualizes WorldGrid in 2D with colored cells
extends Node2D

var grid: WorldGrid = null
var cell_size: int = 4  # Pixels per grid cell
var pois: Array = []
var buildings: Array = []  # Array of BuildingData

var spawns: Array = []  # Array of SpawnData
var show_npcs: bool = true  # Toggle visibility

# Color scheme
var colors = {
	"grass": Color(0.2, 0.6, 0.2),
	"dirt": Color(0.6, 0.5, 0.3),
	"road": Color(0.3, 0.3, 0.3),
	"sidewalk": Color(0.5, 0.5, 0.5),
	"water": Color(0.2, 0.4, 0.8),
	"rock": Color(0.4, 0.4, 0.4),
	"sand": Color(0.8, 0.7, 0.5),
	"empty": Color(0.1, 0.1, 0.1),
	
	"poi": Color(1.0, 0.9, 0.2),
	"building": Color(0.6, 0.4, 0.3),
	"reserved": Color(0.8, 0.6, 0.2),
	"decoration": Color(0.4, 0.6, 0.8),
	
	# Building type colors
	"house": Color(0.7, 0.5, 0.3),
	"apartment": Color(0.6, 0.5, 0.4),
	"store": Color(0.5, 0.6, 0.7),
	"restaurant": Color(0.8, 0.6, 0.4),
	"hotel": Color(0.7, 0.6, 0.5),
	"clinic": Color(0.9, 0.9, 0.9),
	"hospital": Color(0.95, 0.95, 0.95),
	
	# Actor colors
	"npc": Color(0.95, 0.25, 0.35),  			# Red/pink for NPCs
	"npc_merchant": Color(0.8, 0.2, 0.7),  	# Pink-Violet for merchants
	"npc_quest": Color(0.9, 0.4, 0.7),     	# Pink for quest givers
	"npc_hostile": Color(0.7, 0.2, 0.2) 		# Dark red for hostile
}

func visualize(world_grid: WorldGrid, poi_list: Array = [], building_list: Array = [], spawn_list: Array = []):
	"""Set grid to visualize and trigger redraw"""
	grid = world_grid
	pois = poi_list
	buildings = building_list
	spawns = spawn_list  		# Store spawn list
	queue_redraw()

func _draw():
	if grid == null:
		return
	
	# Draw terrain
	for y in range(grid.height):
		for x in range(grid.width):
			var color = _get_cell_color(x, y)
			var rect = Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
			draw_rect(rect, color, true)
	
	# Draw POI markers on top
	for poi in pois:
		if poi.is_valid():
			var pos = Vector2(poi.position.x * cell_size, poi.position.y * cell_size)
			var radius = poi.footprint_radius * cell_size
			var center = pos + Vector2(cell_size/2, cell_size/2)
			
			# Draw semi-transparent fill
			draw_circle(center, radius, Color(colors.poi, 0.2), true)  # 20% opacity fill
			
			# Draw more visible outline
			draw_arc(center, radius, 0, TAU, 32, Color(colors.poi, 0.8), 2.0)  # 80% opacity outline
			
			# Draw POI type label (optional, for debugging)
			# draw_string(ThemeDB.fallback_font, pos, poi.poi_type, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	
	_draw_building_rectangles() 		# Draw building outlines
	_draw_npcs()						# NEW: Draw NPC spawns on top of everything
	
func _draw_building_rectangles():
	"""Draw rectangles for actual buildings"""
	for building in buildings:
		if not building or not building.is_valid():
			continue
		
		var bounds = building.get_bounds()
		var rect = Rect2(
			bounds.position.x * cell_size,
			bounds.position.y * cell_size,
			bounds.size.x * cell_size,
			bounds.size.y * cell_size
		)
		
		# Get color for building type
		var fill_color = colors.get(building.building_type, colors.building)
		var outline_color = fill_color.darkened(0.3)
		
		# Draw filled rectangle (semi-transparent)
		draw_rect(rect, Color(fill_color, 0.6), true)
		
		# Draw outline
		draw_rect(rect, outline_color, false, 2.0)


func _draw_npcs():
	"""Draw NPC spawn markers"""
	if not show_npcs:
		return
	
	for spawn in spawns:
		if not spawn or not spawn.has_position():
			continue
		
		# Calculate center position
		var grid_pos = spawn.position
		var pixel_pos = Vector2(grid_pos.x * cell_size, grid_pos.y * cell_size)
		var center = pixel_pos + Vector2(cell_size * 0.5, cell_size * 0.5)
		
		# Determine color based on NPC type
		var npc_color = colors.npc
		if spawn.entity_data and spawn.entity_data is NPCData:
			var npc = spawn.entity_data as NPCData
			if npc.is_merchant:
				npc_color = colors.npc_merchant
			elif npc.quest_giver:
				npc_color = colors.npc_quest
			elif npc.disposition == "hostile":
				npc_color = colors.npc_hostile
		
		# Draw filled circle
		var radius = cell_size * 0.4
		draw_circle(center, radius, npc_color, true)
		
		# Draw white outline for visibility
		draw_arc(center, radius, 0, TAU, 16, Color.WHITE, 1.0)
		
		# Optional: Draw facing direction indicator
		if spawn.facing_degrees != 0.0:
			var facing_rad = deg_to_rad(spawn.facing_degrees)
			var direction = Vector2(cos(facing_rad), sin(facing_rad))
			var line_end = center + direction * (radius + 2)
			draw_line(center, line_end, Color.WHITE, 2.0)

func set_show_npcs(enabled: bool):
	"""Toggle NPC visibility"""
	show_npcs = enabled
	queue_redraw()

func _get_cell_color(x: int, y: int) -> Color:
	"""Get color for cell based on occupancy and terrain"""
	var occ = grid.get_occupancy(x, y)
	
	# Occupancy takes priority for coloring
	match occ:
		WorldGrid.OccupancyType.POI:
			# POI cells: blend with terrain (show through)
			var terrain_color = _get_terrain_color(grid.get_terrain(x, y))
			return terrain_color.lerp(colors.poi, 0.3)  # 30% POI color, 70% terrain
		WorldGrid.OccupancyType.BUILDING:
			# Building cells: blend with terrain (show through)
			var terrain_color = _get_terrain_color(grid.get_terrain(x, y))
			return terrain_color.lerp(colors.building, 0.4)  # 40% building color, 60% terrain
		WorldGrid.OccupancyType.RESERVED:
			# Reserved areas should show terrain, not a special color
			# They're just "claimed" by nearby POIs/buildings
			pass  # Fall through to terrain
		WorldGrid.OccupancyType.DECORATION:
			return colors.decoration
	
	# Fall back to terrain
	return _get_terrain_color(grid.get_terrain(x, y))

func _get_terrain_color(terrain: WorldGrid.TerrainType) -> Color:
	"""Get color for terrain type"""
	match terrain:
		WorldGrid.TerrainType.GRASS:
			return colors.grass
		WorldGrid.TerrainType.DIRT:
			return colors.dirt
		WorldGrid.TerrainType.ROAD:
			return colors.road
		WorldGrid.TerrainType.SIDEWALK:
			return colors.sidewalk
		WorldGrid.TerrainType.WATER:
			return colors.water
		WorldGrid.TerrainType.ROCK:
			return colors.rock
		WorldGrid.TerrainType.SAND:
			return colors.sand
		_:
			return colors.empty
func get_cell_at_position(screen_pos: Vector2) -> Vector2i:
	"""Convert screen position to grid cell coordinates"""
	var local_pos = to_local(screen_pos)
	var grid_x = int(local_pos.x / cell_size)
	var grid_y = int(local_pos.y / cell_size)
	return Vector2i(grid_x, grid_y)

func set_cell_size(new_size: int):
	"""Change cell size and redraw"""
	cell_size = max(1, new_size)
	queue_redraw()
