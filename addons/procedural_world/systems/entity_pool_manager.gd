extends Node
class_name EntityPoolManager

## EntityPoolManager - Singleton for loading and managing entity pools
## Loads NPCs, items, enemies from JSON catalogs and provides query methods
## Place in: res://addons/procedural_world/systems/

static var _instance: EntityPoolManager = null

# Storage
var _entities_by_id: Dictionary = {}  # entity_id -> EntityData
var _entities_by_pool: Dictionary = {}  # pool_name -> Array[EntityData]
var _entities_by_archetype: Dictionary = {}  # archetype -> Array[EntityData]
var _all_entities: Array[EntityData] = []

# Paths
var npc_catalog_path: String = "res://data/npcs/npc_catalog.json"
var npc_pool_directory: String = "res://data/npcs/"

# Load status
var is_loaded: bool = false


static func get_instance() -> EntityPoolManager:
	"""Get singleton instance"""
	if not _instance:
		_instance = EntityPoolManager.new()
		_instance.name = "EntityPoolManager"
	return _instance


func _init():
	"""Initialize manager"""
	pass


func load_all_entities() -> void:
	"""Load all entity data from catalogs"""
	if is_loaded:
		print("EntityPoolManager: Already loaded")
		return
	
	print("\n=== EntityPoolManager: Loading Entity Catalogs ===")
	
	# Load NPCs
	_load_npc_catalog()
	
	# Future: Load items, enemies, etc.
	# _load_item_catalog()
	# _load_enemy_catalog()
	
	_build_indices()
	
	is_loaded = true
	print("EntityPoolManager: Loading complete - %d total entities" % _all_entities.size())


func _load_npc_catalog() -> void:
	"""Load NPC catalog and pool files"""
	
	# Load main catalog
	if not FileAccess.file_exists(npc_catalog_path):
		push_warning("EntityPoolManager: NPC catalog not found at %s" % npc_catalog_path)
		return
	
	var file = FileAccess.open(npc_catalog_path, FileAccess.READ)
	if not file:
		push_error("EntityPoolManager: Failed to open NPC catalog: %s" % npc_catalog_path)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("EntityPoolManager: Failed to parse NPC catalog JSON at line %d: %s" % [
			json.get_error_line(), json.get_error_message()
		])
		return
	
	var catalog_data = json.get_data()
	
	if not catalog_data is Dictionary:
		push_error("EntityPoolManager: NPC catalog is not a dictionary")
		return
	
	# Support both old "pool_files" format and new "sets" format
	var pool_files = []
	
	# New format with "sets" array (preferred)
	if catalog_data.has("sets"):
		var sets = catalog_data.get("sets", [])
		print("EntityPoolManager: Found %d NPC sets in catalog" % sets.size())
		
		for set_data in sets:
			if set_data is Dictionary and set_data.has("file"):
				var filename = set_data.get("file", "")
				if filename != "":
					pool_files.append(filename)
					
					# Log metadata for debugging
					var title = set_data.get("title", filename)
					var category = set_data.get("category", "unknown")
					print("  - %s (%s)" % [title, category])
	
	# Old format with "pool_files" array (fallback)
	elif catalog_data.has("pool_files"):
		pool_files = catalog_data.get("pool_files", [])
		print("EntityPoolManager: Found %d NPC pool files in catalog" % pool_files.size())
	
	else:
		push_warning("EntityPoolManager: Catalog has neither 'sets' nor 'pool_files' array")
		return
	
	# Load each pool file
	print("EntityPoolManager: Loading %d pool files..." % pool_files.size())
	for pool_file in pool_files:
		_load_npc_pool_file(pool_file)
	
	print("EntityPoolManager: Loaded %d NPCs from catalog" % _all_entities.size())



func _load_npc_pool_file(pool_file: String) -> void:
	"""Load a single NPC pool JSON file"""
	var full_path = npc_pool_directory + pool_file
	
	# Debug output
	print("  [DEBUG] Attempting to load pool file:")
	print("    pool_file: '%s'" % pool_file)
	print("    npc_pool_directory: '%s'" % npc_pool_directory)
	print("    full_path: '%s'" % full_path)
	print("    file exists: %s" % FileAccess.file_exists(full_path))
	
	if not FileAccess.file_exists(full_path):
		push_warning("EntityPoolManager: Pool file not found: %s" % full_path)
		return
	
	print("    [DEBUG] File exists, attempting to open...")
	var file = FileAccess.open(full_path, FileAccess.READ)
	if not file:
		push_error("EntityPoolManager: Failed to open pool file: %s" % full_path)
		return
	
	print("    [DEBUG] File opened, reading content...")
	var json_text = file.get_as_text()
	file.close()
	print("    [DEBUG] Read %d characters from file" % json_text.length())
	
	print("    [DEBUG] Parsing JSON...")
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("EntityPoolManager: Failed to parse pool file %s at line %d: %s" % [
			pool_file, json.get_error_line(), json.get_error_message()
		])
		return
	
	print("    [DEBUG] JSON parsed successfully")
	var pool_data = json.get_data()
	
	if not pool_data is Dictionary:
		push_error("EntityPoolManager: Pool file %s is not a dictionary" % pool_file)
		return
	
	print("    [DEBUG] Pool data is a dictionary")
	
	# Get pool name and NPCs
	var pool_name = pool_data.get("pool_name", "unknown")
	var npcs = pool_data.get("npcs", [])
	
	print("    [DEBUG] pool_name: '%s', npcs array size: %d" % [pool_name, npcs.size()])
	
	print("  Loading pool '%s': %d NPCs" % [pool_name, npcs.size()])
	
	# Load each NPC
	for npc_dict in npcs:
		var npc = NPCData.from_dict(npc_dict)
		
		if npc.entity_id == "":
			push_warning("    Skipping NPC with empty ID in pool %s" % pool_name)
			continue
		
		# Check for duplicates
		if _entities_by_id.has(npc.entity_id):
			push_warning("    Duplicate NPC ID '%s' in pool %s - overwriting" % [npc.entity_id, pool_name])
		
		# Add to pool if not already in list
		if pool_name not in npc.pools:
			npc.pools.append(pool_name)
		
		# Store
		_entities_by_id[npc.entity_id] = npc
		_all_entities.append(npc)


func _build_indices() -> void:
	"""Build lookup indices for fast queries"""
	
	_entities_by_pool.clear()
	_entities_by_archetype.clear()
	
	for entity in _all_entities:
		# Index by pool
		for pool in entity.pools:
			if not _entities_by_pool.has(pool):
				_entities_by_pool[pool] = []
			_entities_by_pool[pool].append(entity)
		
		# Index by archetype
		if entity.archetype != "":
			if not _entities_by_archetype.has(entity.archetype):
				_entities_by_archetype[entity.archetype] = []
			_entities_by_archetype[entity.archetype].append(entity)
	
	print("EntityPoolManager: Built indices - %d pools, %d archetypes" % [
		_entities_by_pool.size(),
		_entities_by_archetype.size()
	])


# === Query Methods ===

func get_npc_by_id(entity_id: String) -> NPCData:
	"""Get specific NPC by ID"""
	if not is_loaded:
		load_all_entities()
	
	var entity = _entities_by_id.get(entity_id, null)
	
	if entity and entity is NPCData:
		return entity
	elif entity:
		push_warning("EntityPoolManager: Entity '%s' exists but is not an NPC" % entity_id)
	
	return null


func get_npc_by_archetype(archetype: String, pool: String = "") -> NPCData:
	"""Get first NPC matching archetype, optionally filtered by pool"""
	if not is_loaded:
		load_all_entities()
	
	var matches = _entities_by_archetype.get(archetype, [])
	
	if matches.is_empty():
		return null
	
	# Filter by pool if specified
	if pool != "":
		for entity in matches:
			if entity is NPCData and pool in entity.pools:
				return entity
		return null
	
	# Return first match
	for entity in matches:
		if entity is NPCData:
			return entity
	
	return null


func get_random_npc_from_pool(pool: String, rng: RandomNumberGenerator = null) -> NPCData:
	"""Get random NPC from pool"""
	if not is_loaded:
		load_all_entities()
	
	var pool_entities = _entities_by_pool.get(pool, [])
	
	if pool_entities.is_empty():
		return null
	
	# Filter to NPCs only
	var npcs = []
	for entity in pool_entities:
		if entity is NPCData:
			npcs.append(entity)
	
	if npcs.is_empty():
		return null
	
	# Pick random
	if rng:
		return npcs[rng.randi() % npcs.size()]
	else:
		return npcs[randi() % npcs.size()]


func get_npcs_by_filter(filter: Dictionary) -> Array[NPCData]:
	"""Get NPCs matching filter criteria
	
	Filter keys:
	- pool: String or Array[String] - must be in at least one pool
	- archetype: String - must match archetype
	- classification: String - must match classification
	- tags: Array[String] - must have all tags
	- disposition: String - must match disposition
	- is_merchant: bool - must match merchant status
	- quest_giver: bool - must match quest giver status
	"""
	if not is_loaded:
		load_all_entities()
	
	var results: Array[NPCData] = []
	
	# Start with all NPCs
	var candidates = []
	for entity in _all_entities:
		if entity is NPCData:
			candidates.append(entity)
	
	# Apply pool filter
	if filter.has("pool"):
		var pool_filter = filter.pool
		var pools = []
		
		if pool_filter is String:
			pools = [pool_filter]
		elif pool_filter is Array:
			pools = pool_filter
		
		var filtered = []
		for npc in candidates:
			for pool in pools:
				if pool in npc.pools:
					filtered.append(npc)
					break
		candidates = filtered
	
	# Apply other filters
	for npc in candidates:
		var matches = true
		
		# Archetype
		if filter.has("archetype"):
			if npc.archetype != filter.archetype:
				matches = false
		
		# Classification
		if filter.has("classification"):
			if npc.classification != filter.classification:
				matches = false
		
		# Tags (must have ALL specified tags)
		if filter.has("tags"):
			for tag in filter.tags:
				if not npc.has_tag(tag):
					matches = false
					break
		
		# Disposition
		if filter.has("disposition"):
			if npc.disposition != filter.disposition:
				matches = false
		
		# Merchant status
		if filter.has("is_merchant"):
			if npc.is_merchant != filter.is_merchant:
				matches = false
		
		# Quest giver status
		if filter.has("quest_giver"):
			if npc.quest_giver != filter.quest_giver:
				matches = false
		
		if matches:
			results.append(npc)
	
	return results


func get_all_pools() -> Array[String]:
	"""Get list of all pool names"""
	if not is_loaded:
		load_all_entities()
	
	var pools: Array[String] = []
	for pool_name in _entities_by_pool.keys():
		pools.append(pool_name)
	return pools


func get_all_archetypes() -> Array[String]:
	"""Get list of all archetypes"""
	if not is_loaded:
		load_all_entities()
	
	var archetypes: Array[String] = []
	for archetype in _entities_by_archetype.keys():
		archetypes.append(archetype)
	return archetypes


# === Debug Methods ===

func print_pool_statistics() -> void:
	"""Print statistics about loaded entities"""
	if not is_loaded:
		load_all_entities()
	
	print("\n=== Entity Pool Statistics ===")
	print("Total entities: %d" % _all_entities.size())
	print("Unique IDs: %d" % _entities_by_id.size())
	print("\nPools:")
	for pool in _entities_by_pool.keys():
		print("  %s: %d entities" % [pool, _entities_by_pool[pool].size()])
	print("\nArchetypes:")
	for archetype in _entities_by_archetype.keys():
		print("  %s: %d entities" % [archetype, _entities_by_archetype[archetype].size()])


func print_entity_details(entity_id: String) -> void:
	"""Print detailed info about an entity"""
	var entity = get_npc_by_id(entity_id)
	
	if not entity:
		print("Entity not found: %s" % entity_id)
		return
	
	print("\n=== Entity Details: %s ===" % entity_id)
	print("Name: %s" % entity.display_name)
	print("Type: %s" % entity.entity_type)
	print("Classification: %s" % entity.classification)
	print("Archetype: %s" % entity.archetype)
	print("Pools: %s" % ", ".join(entity.pools))
	print("Tags: %s" % ", ".join(entity.tags))
	
	if entity is NPCData:
		print("\n--- NPC Specific ---")
		print("Gender: %s" % entity.gender)
		print("Species: %s" % entity.species)
		print("Disposition: %s" % entity.disposition)
		print("Behavior: %s" % entity.behavior_type)
		print("Merchant: %s" % str(entity.is_merchant))
		print("Quest Giver: %s" % str(entity.quest_giver))
