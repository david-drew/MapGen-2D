extends Node
class_name SpawnPointManager

# Singleton for managing spawn point placement
# Place in: res://addons/procedural_world/systems/

static var _instance: SpawnPointManager = null

static func get_instance() -> SpawnPointManager:
	if not _instance:
		_instance = SpawnPointManager.new()
		_instance.name = "SpawnPointManager"
	return _instance

func process_story_spawns(story_data: Dictionary, rng: RandomNumberGenerator) -> Array[SpawnData]:
	"""Process spawn_points array from story JSON into SpawnData objects"""
	var spawns: Array[SpawnData] = []
	var spawn_points = story_data.get("spawn_points", [])
	
	if spawn_points.is_empty():
		print("SpawnPointManager: No spawn points in story data")
		return spawns
	
	print("SpawnPointManager: Processing %d spawn points" % spawn_points.size())
	var entity_mgr = EntityPoolManager.get_instance()
	
	for spawn_spec in spawn_points:
		var spawn = _create_spawn_from_spec(spawn_spec, entity_mgr, rng)
		if spawn:
			spawns.append(spawn)
			print("  ✓ Loaded spawn: [%s] %s at %s (%s)" % [
				spawn.spawn_type,
				spawn.entity_data.display_name if spawn.entity_data else "Unknown",
				spawn.region_id,
				spawn.placement_type
			])
		else:
			print("  ✗ Failed to create spawn: %s" % spawn_spec.get("id", "unknown"))
	
	print("SpawnPointManager: Loaded %d valid spawns" % spawns.size())
	return spawns

func _create_spawn_from_spec(spec: Dictionary, entity_mgr: EntityPoolManager, rng: RandomNumberGenerator) -> SpawnData:
	"""Create a SpawnData object from a spawn specification"""
	
	# Required fields
	var spawn_id = spec.get("id", "")
	var spawn_type = spec.get("type", "npc")
	var location = spec.get("location", {})
	
	if spawn_id == "" or location.is_empty():
		push_warning("SpawnPointManager: Invalid spawn spec - missing id or location")
		return null
	
	# Resolve entity
	var entity: EntityData = null
	
	# Priority 1: Specific entity by ID
	if spec.has("entity_id"):
		entity = entity_mgr.get_npc_by_id(spec.entity_id)
		if not entity:
			push_warning("SpawnPointManager: Entity not found: %s" % spec.entity_id)
	
	# Priority 2: Entity by archetype
	elif spec.has("entity_archetype"):
		var pool = spec.get("entity_pool", "")
		entity = entity_mgr.get_npc_by_archetype(spec.entity_archetype, pool)
		if not entity:
			push_warning("SpawnPointManager: No NPC with archetype: %s" % spec.entity_archetype)
	
	# Priority 3: Random from pool
	elif spec.has("entity_pool"):
		entity = entity_mgr.get_random_npc_from_pool(spec.entity_pool, rng)
		if not entity:
			push_warning("SpawnPointManager: Failed to get NPC from pool: %s" % spec.entity_pool)
	
	# Priority 4: Filter-based
	elif spec.has("filter"):
		var matches = entity_mgr.get_npcs_by_filter(spec.filter)
		if not matches.is_empty():
			entity = matches[rng.randi() % matches.size()] if rng else matches[0]
		else:
			push_warning("SpawnPointManager: No NPCs match filter")
	
	if not entity:
		return null
	
	# Create SpawnData
	var spawn = SpawnData.new()
	spawn.spawn_id = spawn_id
	spawn.spawn_type = spawn_type
	spawn.entity_data = entity
	spawn.region_id = location.get("region", "")
	spawn.placement_type = location.get("placement", "exterior")
	
	# Optional fields
	spawn.is_required = spec.get("required", false)
	spawn.is_unique = spec.get("unique", true)
	spawn.spawn_count = spec.get("count", 1)
	spawn.facing_degrees = spec.get("facing", 0.0)
	spawn.scale = spec.get("scale", 1.0)
	spawn.variant = spec.get("variant", "")
	spawn.tags = spec.get("tags", [])
	spawn.spawn_metadata = spec.get("metadata", {})
	
	# Location-specific metadata
	spawn.building_type_filter = location.get("building_type", "")
	spawn.poi_type_filter = location.get("poi_type", "")
	
	# Check for exact position (rare)
	if location.has("position"):
		var pos = location.position
		if pos is Array and pos.size() == 2:
			spawn.set_actual_position(Vector2i(pos[0], pos[1]))  # Use method instead of setting property
	
	return spawn

func expand_multi_spawns(spawns: Array[SpawnData]) -> Array[SpawnData]:
	"""Expand spawns with count > 1 into individual spawns"""
	var expanded: Array[SpawnData] = []
	
	for spawn in spawns:
		if spawn.spawn_count <= 1:
			expanded.append(spawn)
		else:
			# Create multiple instances
			for i in range(spawn.spawn_count):
				var copy = spawn.duplicate()
				copy.spawn_id = "%s_%d" % [spawn.spawn_id, i]
				copy.spawn_count = 1
				expanded.append(copy)
	
	if expanded.size() > spawns.size():
		print("SpawnPointManager: Expanded %d multi-count spawns into %d total spawns" % [
			spawns.size(), expanded.size()
		])
	
	return expanded

func validate_spawns(spawns: Array[SpawnData], regions: Dictionary) -> Dictionary:
	"""Validate that all spawns can potentially be placed"""
	var validation = {
		"valid": true,
		"errors": [],
		"warnings": []
	}
	
	for spawn in spawns:
		# Check region exists
		if not regions.has(spawn.region_id):
			var error = "Spawn '%s' references missing region '%s'" % [spawn.spawn_id, spawn.region_id]
			validation.errors.append(error)
			if spawn.is_required:
				validation.valid = false
		
		# Check building type exists if interior placement
		if spawn.placement_type == "interior" and spawn.building_type_filter != "":
			var region = regions.get(spawn.region_id, {})
			var buildings = region.get("buildings", [])
			var has_building_type = false
			
			for building in buildings:
				if building.building_type == spawn.building_type_filter:
					has_building_type = true
					break
			
			if not has_building_type:
				var warn = "Spawn '%s' requires building type '%s' which doesn't exist in region '%s'" % [
					spawn.spawn_id, spawn.building_type_filter, spawn.region_id
				]
				validation.warnings.append(warn)
				if spawn.is_required:
					validation.errors.append(warn)
					validation.valid = false
		
		# Check POI type exists if POI placement
		if spawn.placement_type == "poi" and spawn.poi_type_filter != "":
			var region = regions.get(spawn.region_id, {})
			var pois = region.get("pois", [])
			var has_poi_type = false
			
			for poi in pois:
				if poi.poi_type == spawn.poi_type_filter:
					has_poi_type = true
					break
			
			if not has_poi_type:
				var warn = "Spawn '%s' requires POI type '%s' which doesn't exist in region '%s'" % [
					spawn.spawn_id, spawn.poi_type_filter, spawn.region_id
				]
				validation.warnings.append(warn)
				if spawn.is_required:
					validation.errors.append(warn)
					validation.valid = false
	
	if validation.valid:
		print("SpawnPointManager: Spawn validation passed")
	else:
		push_error("SpawnPointManager: Spawn validation failed with %d errors" % validation.errors.size())
	
	return validation

func find_spawn_location(spawn: SpawnData, region: Dictionary, grid, existing_spawns: Array[SpawnData]) -> Vector2i:
	"""Find a valid position for a spawn based on its placement type"""
	
	match spawn.placement_type:
		"interior":
			return _find_interior_location(spawn, region)
		"poi":
			return _find_poi_location(spawn, region)
		"exterior_walkable", "path":
			return _find_path_location(spawn, region, existing_spawns)
		"exterior":
			return _find_exterior_location(spawn, region, existing_spawns)
		_:
			push_warning("SpawnPointManager: Unknown placement type: %s" % spawn.placement_type)
			return _find_exterior_location(spawn, region, existing_spawns)

func _find_interior_location(spawn: SpawnData, region: Dictionary) -> Vector2i:
	"""Find position inside a building"""
	var buildings = region.get("buildings", [])
	
	if buildings.is_empty():
		push_warning("SpawnPointManager: No buildings in region for interior spawn")
		return Vector2i(-1, -1)
	
	# Filter by building type if specified
	var valid_buildings = []
	if spawn.building_type_filter != "":
		for building in buildings:
			if building.building_type == spawn.building_type_filter:
				valid_buildings.append(building)
	else:
		valid_buildings = buildings
	
	if valid_buildings.is_empty():
		push_warning("SpawnPointManager: No buildings of type '%s' found" % spawn.building_type_filter)
		return Vector2i(-1, -1)
	
	# Pick a random building
	var building = valid_buildings[randi() % valid_buildings.size()]
	
	# For now, return building center position
	# In Phase 2, this would find a position inside the building
	return building.position

func _find_poi_location(spawn: SpawnData, region: Dictionary) -> Vector2i:
	"""Find position at a POI"""
	var pois = region.get("pois", [])
	
	if pois.is_empty():
		push_warning("SpawnPointManager: No POIs in region for POI spawn")
		return Vector2i(-1, -1)
	
	# Filter by POI type if specified
	var valid_pois = []
	if spawn.poi_type_filter != "":
		for poi in pois:
			if poi.poi_type == spawn.poi_type_filter:
				valid_pois.append(poi)
	else:
		valid_pois = pois
	
	if valid_pois.is_empty():
		push_warning("SpawnPointManager: No POIs of type '%s' found" % spawn.poi_type_filter)
		return Vector2i(-1, -1)
	
	# Pick a random POI
	var poi = valid_pois[randi() % valid_pois.size()]
	return poi.position

func _find_path_location(spawn: SpawnData, region: Dictionary, existing_spawns: Array[SpawnData]) -> Vector2i:
	"""Find position on a path or road"""
	var paths = region.get("paths", [])
	
	if paths.is_empty():
		# Fallback to exterior placement
		return _find_exterior_location(spawn, region, existing_spawns)
	
	# Try to find a non-colliding path position
	var max_attempts = 50
	var spawn_radius = spawn.spawn_metadata.get("spawn_radius", 2)
	
	for attempt in range(max_attempts):
		var path_pos = paths[randi() % paths.size()]
		
		# Check collision with existing spawns
		var collision = false
		for other_spawn in existing_spawns:
			if other_spawn.has_position():  # Use method, not property
				var distance = (path_pos - other_spawn.position).length()
				if distance < spawn_radius:
					collision = true
					break
		
		if not collision:
			return path_pos
	
	# Fallback to any path position
	return paths[randi() % paths.size()]

func _find_exterior_location(spawn: SpawnData, region: Dictionary, existing_spawns: Array[SpawnData]) -> Vector2i:
	"""Find random exterior position in region"""
	
	# Get rough region bounds from buildings and POIs
	var min_pos = Vector2i(999999, 999999)
	var max_pos = Vector2i(-999999, -999999)
	
	var buildings = region.get("buildings", [])
	var pois = region.get("pois", [])
	
	if buildings.is_empty() and pois.is_empty():
		# No reference points, use arbitrary area
		min_pos = Vector2i(0, 0)
		max_pos = Vector2i(100, 100)
	else:
		# Calculate bounds from existing features
		for building in buildings:
			min_pos.x = min(min_pos.x, building.position.x)
			min_pos.y = min(min_pos.y, building.position.y)
			max_pos.x = max(max_pos.x, building.position.x)
			max_pos.y = max(max_pos.y, building.position.y)
		
		for poi in pois:
			min_pos.x = min(min_pos.x, poi.position.x)
			min_pos.y = min(min_pos.y, poi.position.y)
			max_pos.x = max(max_pos.x, poi.position.x)
			max_pos.y = max(max_pos.y, poi.position.y)
		
		# Add padding
		min_pos -= Vector2i(20, 20)
		max_pos += Vector2i(20, 20)
	
	# Try to find non-colliding position
	var max_attempts = 100
	var spawn_radius = spawn.spawn_metadata.get("spawn_radius", 2)
	
	for attempt in range(max_attempts):
		var x = randi_range(min_pos.x, max_pos.x)
		var y = randi_range(min_pos.y, max_pos.y)
		var pos = Vector2i(x, y)
		
		# Check collision with existing spawns
		var collision = false
		for other_spawn in existing_spawns:
			if other_spawn.has_position():  # Use method, not property
				var distance = (pos - other_spawn.position).length()
				if distance < spawn_radius:
					collision = true
					break
		
		if not collision:
			return pos
	
	# Last resort: return any position
	var x = randi_range(min_pos.x, max_pos.x)
	var y = randi_range(min_pos.y, max_pos.y)
	return Vector2i(x, y)

func print_spawn_statistics(spawns: Array[SpawnData]) -> void:
	"""Print statistics about spawn placement"""
	var total = spawns.size()
	var positioned = 0
	var required = 0
	var by_type = {}
	var by_region = {}
	var by_placement = {}
	
	for spawn in spawns:
		if spawn.has_position():  # Use method, not property
			positioned += 1
		if spawn.is_required:
			required += 1
		
		# Count by type
		by_type[spawn.spawn_type] = by_type.get(spawn.spawn_type, 0) + 1
		
		# Count by region
		by_region[spawn.region_id] = by_region.get(spawn.region_id, 0) + 1
		
		# Count by placement
		by_placement[spawn.placement_type] = by_placement.get(spawn.placement_type, 0) + 1
	
	print("\n=== Spawn Statistics ===")
	print("Total spawns: %d" % total)
	print("Positioned: %d" % positioned)
	print("Required: %d" % required)
	
	if not by_type.is_empty():
		print("\nBy Type:")
		for type in by_type.keys():
			print("  %s: %d" % [type, by_type[type]])
	
	if not by_region.is_empty():
		print("\nBy Region:")
		for region in by_region.keys():
			print("  %s: %d" % [region, by_region[region]])
	
	if not by_placement.is_empty():
		print("\nBy Placement:")
		for placement in by_placement.keys():
			print("  %s: %d" % [placement, by_placement[placement]])
