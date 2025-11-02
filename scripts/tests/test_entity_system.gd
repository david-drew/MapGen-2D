extends Node

## Entity System Test Script
## Place this in a test scene to diagnose entity loading issues
## Run this BEFORE trying to use the spawn system

func _ready():
	print("\n" + "============================================================================================================")
	print("ENTITY SYSTEM DIAGNOSTIC TEST")
	print("============================================================================================================")
	
	# Test 1: Get EntityPoolManager instance
	print("\n[TEST 1] Getting EntityPoolManager instance...")
	var entity_mgr = EntityPoolManager.get_instance()
	if entity_mgr:
		print("✓ EntityPoolManager instance obtained")
	else:
		push_error("✗ FAILED: Could not get EntityPoolManager instance")
		return
	
	# Test 2: Check file paths
	print("\n[TEST 2] Checking configured file paths...")
	print("  Catalog path: %s" % entity_mgr.npc_catalog_path)
	print("  Pool directory: %s" % entity_mgr.npc_pool_directory)
	
	if FileAccess.file_exists(entity_mgr.npc_catalog_path):
		print("  ✓ Catalog file exists")
	else:
		push_error("  ✗ Catalog file NOT FOUND at: %s" % entity_mgr.npc_catalog_path)
		print("\n  SOLUTION: Place 'example_npc_catalog.json' at this location")
		print("  Or update entity_mgr.npc_catalog_path to point to your catalog")
	
	# Test 3: Load entities
	print("\n[TEST 3] Loading entities...")
	entity_mgr.load_all_entities()
	
	if entity_mgr.is_loaded:
		print("✓ Entities loaded successfully")
	else:
		push_error("✗ FAILED: Entity loading failed")
	
	# Test 4: Check what was loaded
	print("\n[TEST 4] Checking loaded entities...")
	entity_mgr.print_pool_statistics()
	
	# Test 5: Test queries by ID
	print("\n[TEST 5] Testing entity queries by ID...")
	var test_ids = [
		"npc_bartender_01",
		"npc_merchant_01",
		"npc_farmer_01",
		"npc_guard_01",
		"npc_child_01"
	]
	
	var found_count = 0
	for test_id in test_ids:
		var npc = entity_mgr.get_npc_by_id(test_id)
		if npc:
			print("  ✓ Found: %s - %s" % [test_id, npc.display_name])
			found_count += 1
		else:
			print("  ✗ NOT FOUND: %s" % test_id)
	
	print("\n  Found %d / %d test NPCs" % [found_count, test_ids.size()])
	
	# Test 6: Test query by pool
	print("\n[TEST 6] Testing query by pool...")
	var random_npc = entity_mgr.get_random_npc_from_pool("core_people", null)
	if random_npc:
		print("  ✓ Got random NPC from 'core_people': %s" % random_npc.display_name)
	else:
		print("  ✗ Could not get random NPC from 'core_people' pool")
	
	# Test 7: Test query by archetype
	print("\n[TEST 7] Testing query by archetype...")
	var bartender = entity_mgr.get_npc_by_archetype("bartender", "")
	if bartender:
		print("  ✓ Found bartender archetype: %s" % bartender.display_name)
	else:
		print("  ✗ Could not find bartender archetype")
	
	# Final summary
	print("\n" + "==========================================================================================")
	if found_count == test_ids.size() and random_npc and bartender:
		print("SUCCESS: All tests passed! ✓")
		print("The entity system is working correctly.")
	else:
		push_error("FAILURE: Some tests failed!")
		print("\nCOMMON ISSUES:")
		print("1. Files not in correct location:")
		print("   - Place example_npc_catalog.json at: res://data/npcs/")
		print("   - Rename example_core_people.json to: core_people.json")
		print("   - Place core_people.json at: res://data/npcs/")
		print("\n2. Paths not configured:")
		print("   - Set entity_mgr.npc_catalog_path before calling load_all_entities()")
		print("   - Set entity_mgr.npc_pool_directory before calling load_all_entities()")
		print("\n3. JSON syntax errors:")
		print("   - Check console for JSON parse errors")
		print("   - Validate JSON files with a JSON validator")
	print("============================================================================================================" + "\n")
