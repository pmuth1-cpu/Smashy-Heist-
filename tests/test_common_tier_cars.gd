extends SceneTree

## Integration Test Suite: 30 Common Tier Cars System
## Verifies Database, 3D Voxel Meshes, Gadgets, Shard Upgrades, and UI Integration

const CarsScreenScene = preload("res://scripts/ui/cars_screen.gd")
const ArcadeCarScene = preload("res://scenes/vehicles/arcade_car.tscn")

func _init() -> void:
	await process_frame
	await process_frame
	
	print("\n=================================================================")
	print("   STARTING 30 COMMON TIER CARS EXPANSION INTEGRATION TESTS      ")
	print("=================================================================")
	
	test_vehicle_database()
	test_voxel_car_builder()
	await test_car_gadgets()
	test_save_manager_shards()
	await test_cars_screen_carousel()
	
	print("\n=================================================================")
	print("   ALL 30 COMMON TIER CAR TESTS PASSED (100% GREEN)             ")
	print("=================================================================\n")
	quit(0)

func _get_vdb() -> Node:
	var vdb: Node = root.get_node_or_null("/root/VehicleDatabase")
	if not vdb:
		var vdb_script = load("res://scripts/autoload/vehicle_database.gd")
		vdb = vdb_script.new()
		root.add_child(vdb)
	return vdb

func _get_vab() -> Node:
	var vab: Node = root.get_node_or_null("/root/VoxelAssetBuilder")
	if not vab:
		var vab_script = load("res://scripts/autoload/voxel_asset_builder.gd")
		vab = vab_script.new()
		root.add_child(vab)
	return vab

func _get_sm() -> Node:
	var sm: Node = root.get_node_or_null("/root/SaveManager")
	if not sm:
		var sm_script = load("res://scripts/autoload/save_manager.gd")
		sm = sm_script.new()
		root.add_child(sm)
	return sm

## TEST 1: Vehicle Database Completeness & Validation
func test_vehicle_database() -> void:
	print("\n--- TEST 1: VEHICLE DATABASE SUITE ---")
	var vdb = _get_vdb()
	
	var common_cars: Array = vdb.get_common_cars()
	print("  Found %d Common cars registered in VehicleDatabase" % common_cars.size())
	assert(common_cars.size() == 30, "VehicleDatabase must contain exactly 30 COMMON tier cars! Found: %d" % common_cars.size())
	
	var found_categories: Dictionary = {}
	
	for car in common_cars:
		var cid: String = car["id"]
		assert(not cid.is_empty(), "Car must have a non-empty ID")
		assert(car["rarity_tier"] == "COMMON", "Car %s must have rarity_tier COMMON" % cid)
		assert(car.has("name") and not car["name"].is_empty(), "Car %s must have a valid display name" % cid)
		assert(car.has("category"), "Car %s must have a category" % cid)
		found_categories[car["category"]] = found_categories.get(car["category"], 0) + 1
		
		# Validate stats
		for stat_key in ["speed", "accel", "handling", "boost", "mass_weight", "max_hp"]:
			assert(car.has(stat_key), "Car %s missing required stat: %s" % [cid, stat_key])
			assert(car[stat_key] > 0.0, "Car %s stat %s must be greater than 0" % [cid, stat_key])
		
		# Validate gadget
		assert(car.has("gadget_id") and not car["gadget_id"].is_empty(), "Car %s missing gadget_id" % cid)
		assert(car.has("gadget_name") and not car["gadget_name"].is_empty(), "Car %s missing gadget_name" % cid)
		assert(car.has("gadget_cooldown") and car["gadget_cooldown"] > 0.0, "Car %s missing gadget_cooldown" % cid)
		
		# Validate passive perk
		assert(car.has("passive_perk") and not car["passive_perk"].is_empty(), "Car %s missing passive perk" % cid)
		assert(car.has("passive_desc") and not car["passive_desc"].is_empty(), "Car %s missing passive desc" % cid)
		
		# Validate builder recipe
		var recipe: Dictionary = car.get("recipe", {})
		assert(recipe.has("archetype"), "Car %s missing builder recipe archetype" % cid)
		assert(recipe.has("primary_color"), "Car %s missing primary color" % cid)
		assert(recipe.has("secondary_color"), "Car %s missing secondary color" % cid)
	
	print("  [PASS] All 30 Common cars validated with complete stats, gadgets, perks, and recipes.")
	print("  Category breakdown (%d distinct categories): %s" % [found_categories.size(), str(found_categories)])

## TEST 2: Procedural 3D Voxel Meshes for all 30 Common Cars
func test_voxel_car_builder() -> void:
	print("\n--- TEST 2: VOXEL CAR BUILDER 3D MESH GENERATION ---")
	var vab = _get_vab()
	var vdb = _get_vdb()
	var common_cars: Array = vdb.get_common_cars()
	
	var built_count: int = 0
	for car in common_cars:
		var cid: String = car["id"]
		var mesh_root: Node3D = vab.build_player_car_visuals(cid)
		assert(mesh_root != null, "build_player_car_visuals must return Node3D for %s" % cid)
		assert(mesh_root.get_child_count() > 0, "Car mesh for %s must contain child mesh parts" % cid)
		mesh_root.free()
		built_count += 1
	
	print("  [PASS] Successfully generated 3D procedural meshes for all %d Common cars." % built_count)

## TEST 3: Car Gadget System Handlers for Common Cars
func test_car_gadgets() -> void:
	print("\n--- TEST 3: COMMON CAR GADGET ACTIVATION SUITE ---")
	var dummy_car: ArcadeCar = ArcadeCarScene.instantiate()
	root.add_child(dummy_car)
	await process_frame
	await process_frame
	
	var gadget_system: CarGadgetSystem = dummy_car.get_node_or_null("CarGadgetSystem")
	assert(gadget_system != null, "CarGadgetSystem must be attached to ArcadeCar")
	
	# Test activating gadget across representative Common car archetypes
	var test_cars = [
		"drift_panda",            # SMOKE_SCREEN
		"turbo_civic",            # VTEC_BOOST
		"boss_mustang_302",       # ROARING_BURNOUT
		"dune_sand_rail",         # SUSPENSION_BOUNCE
		"steamroller_iron",       # STEAM_WHISTLE_INTIMIDATE
		"garbage_compactor",      # TRASH_BIN_DROP
		"street_asphalt_paver",   # BITUMEN_SLICK
		"patrol_cruiser",         # SIREN_CLEAR_LANE
		"metro_transit_bus",      # PASSENGER_EJECT_DISC
		"pizza_delivery_van",     # HOT_PIZZA_TOSS
		"giant_donut_mobile",     # GLAZE_SLICK
		"hot_dog_express",        # MUSTARD_STREAM
		"compact_city_smart"      # MICRO_U_TURN
	]
	
	for cid in test_cars:
		if dummy_car.stats == null:
			dummy_car.stats = CarStats.new()
		dummy_car.stats.car_id = cid
		dummy_car.current_hp = 100.0
		gadget_system.cooldown = 0.0
		
		var activated: bool = gadget_system.activate_gadget()
		assert(activated, "Gadget for car %s must activate successfully" % cid)
		assert(gadget_system.cooldown > 0.0, "Gadget for %s must set cooldown" % cid)
		
		# Reset for next car
		gadget_system.cooldown = 0.0
	
	dummy_car.queue_free()
	print("  [PASS] Successfully verified gadget triggers and active handlers across %d Common cars." % test_cars.size())

## TEST 4: SaveManager Shard Storage & Upgrades
func test_save_manager_shards() -> void:
	print("\n--- TEST 4: SAVEMANAGER SHARDS & PROGRESSION ---")
	var sm = _get_sm()
	
	var test_car: String = "turbo_civic"
	var initial_shards: int = sm.get_car_shards(test_car)
	
	# Add shards
	sm.add_car_shards(test_car, 15)
	assert(sm.get_car_shards(test_car) == initial_shards + 15, "Car shards must increase by 15")
	
	# Verify upgrade logic
	sm.car_levels[test_car] = 1
	assert(sm.can_upgrade_car_with_shards(test_car), "Car should be eligible for upgrade at level 1 with >= 5 shards")
	
	var upgraded: bool = sm.upgrade_car_with_shards(test_car)
	assert(upgraded, "Car upgrade with shards must succeed")
	assert(sm.car_levels[test_car] == 2, "Car level must increment to 2")
	assert(sm.get_car_shards(test_car) == initial_shards + 15 - 5, "5 shards should be deducted")
	
	print("  [PASS] Shard addition, eligibility check, shard deduction, and level upgrade verified.")

## TEST 5: CarsScreen Virtualized Carousel & Common Rarity Filter
func test_cars_screen_carousel() -> void:
	print("\n--- TEST 5: CARS SCREEN COMMON CAR INTEGRATION ---")
	var cars_screen: Control = CarsScreenScene.new()
	root.add_child(cars_screen)
	await process_frame
	await process_frame
	
	# Switch filter to COMMON
	cars_screen.set_filter("COMMON")
	assert(cars_screen.current_filter == "COMMON", "Filter must be set to COMMON")
	
	var visible_common_cards: int = 0
	for cid in cars_screen._car_cards:
		if cars_screen._car_cards[cid].visible:
			visible_common_cards += 1
	
	print("  Visible COMMON cars in carousel: %d" % visible_common_cards)
	assert(visible_common_cards == 30, "Filtered carousel for COMMON must show exactly 30 cars, got: %d" % visible_common_cards)
	
	# Verify selecting several Common cars updates UI models and stat panels
	var sample_selection = ["turbo_civic", "steamroller_iron", "taco_loco_truck", "giant_donut_mobile"]
	for cid in sample_selection:
		cars_screen.select_car(cid)
		assert(cars_screen.current_car_id == cid, "Selected car must be %s" % cid)
		assert(cars_screen._car_mount.get_child_count() > 0, "3D turntable must contain mounted car mesh for %s" % cid)
		assert(cars_screen._rarity_badge_label.text.to_upper() == "COMMON", "Rarity badge must show COMMON")
	
	cars_screen.queue_free()
	print("  [PASS] CarsScreen filtering, 30 Common cards visibility, and 3D preview confirmed.")
