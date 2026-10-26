extends SceneTree

const SmashPropScript = preload("res://scripts/props/smash_prop.gd")
const SmashPropScene = preload("res://scenes/props/smash_prop.tscn")
const ArcadeCarScene = preload("res://scenes/vehicles/arcade_car.tscn")
const PlayerCharScene = preload("res://scenes/characters/player_character.tscn")
const CityGeneratorScript = preload("res://scripts/world/city_generator.gd")
const VoxelAssetBuilderScript = preload("res://scripts/autoload/voxel_asset_builder.gd")
const VehicleDatabaseScript = preload("res://scripts/autoload/vehicle_database.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("================================================================================")
	print("🧪 RUNNING TEST SUITE: Solid Buildings, Smash Props, & Fleet Car Commandeering")
	print("================================================================================")
	call_deferred("_run_all_tests")

func assert_true(condition: bool, msg: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  ✅ PASS: %s" % msg)
	else:
		failed_tests += 1
		printerr("  ❌ FAIL: %s" % msg)

func _run_all_tests() -> void:
	# 1. Test SmashProp PUMPKIN & PLANT
	_test_smash_props_pumpkin_and_plant()
	
	# 2. Test Solid Colliders on Landmarks & Warehouses
	_test_solid_biome_landmarks_and_warehouses()
	
	# 3. Test Solid Colliders on Multi-Car Moving Train
	_test_multi_car_train_colliders()
	
	# 4. Test ArcadeCar set_car_profile and Gadget Sync
	_test_car_profile_and_gadget_sync()
	
	# 5. Test PlayerCharacter Commandeering Workflow
	_test_player_character_commandeering()
	
	# 6. Test CityGenerator Fleet Cars and Smashable Spawns
	_test_city_generator_spawns()
	
	print("================================================================================")
	print("📊 RESULTS: %d/%d Passed (%d Failed)" % [passed_tests, total_tests, failed_tests])
	print("================================================================================")
	
	if failed_tests > 0:
		quit(1)
	else:
		quit(0)

func _test_smash_props_pumpkin_and_plant() -> void:
	print("\n--- 1. Testing SmashProp: PUMPKIN & PLANT ---")
	
	# Verify enum values exist
	assert_true(SmashPropScript.PropType.PUMPKIN != null, "SmashProp.PropType.PUMPKIN exists")
	assert_true(SmashPropScript.PropType.PLANT != null, "SmashProp.PropType.PLANT exists")
	
	# Instantiate Pumpkin prop
	var pumpkin: SmashProp = SmashPropScene.instantiate()
	root.add_child(pumpkin)
	pumpkin.prop_type = SmashPropScript.PropType.PUMPKIN
	
	assert_true(pumpkin.base_points == 120, "Pumpkin base points is 120")
	assert_true(pumpkin.mass == 0.5, "Pumpkin mass is 0.5kg")
	assert_true(pumpkin.collision_layer == 16, "Pumpkin collision layer is 16 (SmashProps)")
	assert_true(pumpkin.collision_shape != null and pumpkin.collision_shape.shape is BoxShape3D, "Pumpkin has BoxShape3D collider")
	assert_true(pumpkin.mesh_instance != null, "Pumpkin has 3D mesh instance")
	
	# Test smashing pumpkin
	var dummy_hitter = RigidBody3D.new()
	dummy_hitter.linear_velocity = Vector3(0, 0, -15.0)
	root.add_child(dummy_hitter)
	pumpkin._smash(dummy_hitter)
	assert_true(pumpkin._is_smashed == true, "Pumpkin registers as smashed upon collision")
	assert_true(pumpkin.freeze == false, "Pumpkin unfreezes for physics tumble")
	
	# Instantiate Plant prop
	var plant: SmashProp = SmashPropScene.instantiate()
	root.add_child(plant)
	plant.prop_type = SmashPropScript.PropType.PLANT
	
	assert_true(plant.base_points == 80, "Plant base points is 80")
	assert_true(is_equal_approx(plant.mass, 0.4), "Plant mass is 0.4kg")
	assert_true(plant.collision_shape != null and plant.collision_shape.shape is BoxShape3D, "Plant has BoxShape3D collider")
	
	plant._smash(dummy_hitter)
	assert_true(plant._is_smashed == true, "Plant registers as smashed upon collision")
	
	pumpkin.queue_free()
	plant.queue_free()
	dummy_hitter.queue_free()

func _test_solid_biome_landmarks_and_warehouses() -> void:
	print("\n--- 2. Testing Solid Colliders on Landmarks, Warehouses & Barns ---")
	
	var vab: Node = VoxelAssetBuilderScript.new()
	root.add_child(vab)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	
	# Test Chinatown Pagoda (Biome 1, Type 0)
	var pagoda: Node3D = vab.build_biome_landmark(1, 0, rng)
	var pagoda_colliders = _find_colliders_on_layer(pagoda, 8)
	assert_true(pagoda_colliders.size() >= 2, "Chinatown Pagoda has >= 2 solid colliders on Layer 8 (found %d)" % pagoda_colliders.size())
	pagoda.queue_free()
	
	# Test Cyber Arcade (Biome 1, Type 1)
	var arcade: Node3D = vab.build_biome_landmark(1, 1, rng)
	var arcade_colliders = _find_colliders_on_layer(arcade, 8)
	assert_true(arcade_colliders.size() >= 1, "Cyber Arcade has solid building collider on Layer 8 (found %d)" % arcade_colliders.size())
	arcade.queue_free()
	
	# Test Retro Gas Station (Biome 2, Type 0)
	var gas_station: Node3D = vab.build_biome_landmark(2, 0, rng)
	var gas_colliders = _find_colliders_on_layer(gas_station, 8)
	assert_true(gas_colliders.size() >= 2, "Retro Gas Station store & canopy have solid colliders on Layer 8 (found %d)" % gas_colliders.size())
	gas_station.queue_free()
	
	# Test Crossing Freight Train (Biome 2, Type 1)
	var crossing_train: Node3D = vab.build_biome_landmark(2, 1, rng)
	var train_colliders = _find_colliders_on_layer(crossing_train, 8)
	assert_true(train_colliders.size() >= 2, "Stationary Freight Train & gates have solid colliders on Layer 8 (found %d)" % train_colliders.size())
	crossing_train.queue_free()
	
	# Test Cargo Harbor Container Warehouse Stacks (Biome 3)
	var harbor: Node3D = vab.build_biome_landmark(3, 0, rng)
	var harbor_colliders = _find_colliders_on_layer(harbor, 8)
	assert_true(harbor_colliders.size() >= 4, "Harbor shipping container warehouse stacks & gantry crane have >= 4 solid colliders on Layer 8 (found %d)" % harbor_colliders.size())
	harbor.queue_free()
	
	# Test Grand Bank (Biome 0, Type 0)
	var bank: Node3D = vab.build_biome_landmark(0, 0, rng)
	var bank_colliders = _find_colliders_on_layer(bank, 8)
	assert_true(bank_colliders.size() >= 2, "Grand Bank main hall & columns have solid colliders on Layer 8 (found %d)" % bank_colliders.size())
	bank.queue_free()
	
	# Test Donut Shop (Biome 0, Type 1)
	var donut_shop: Node3D = vab.build_biome_landmark(0, 1, rng)
	var donut_colliders = _find_colliders_on_layer(donut_shop, 8)
	assert_true(donut_colliders.size() >= 1, "Donut Shop building has solid collider on Layer 8 (found %d)" % donut_colliders.size())
	donut_shop.queue_free()
	
	# Test Farmland Barn & Silo
	var barn: Node3D = vab.build_red_barn_and_silo(rng)
	var barn_colliders = _find_colliders_on_layer(barn, 8)
	assert_true(barn_colliders.size() >= 2, "Farmland Barn & Silo have solid colliders on Layer 8 (found %d)" % barn_colliders.size())
	barn.queue_free()
	
	# Test Country Windmill
	var windmill: Node3D = vab.build_country_windmill(rng)
	var windmill_colliders = _find_colliders_on_layer(windmill, 8)
	assert_true(windmill_colliders.size() >= 1, "Windmill tower has solid collider on Layer 8 (found %d)" % windmill_colliders.size())
	windmill.queue_free()
	
	vab.queue_free()

func _test_multi_car_train_colliders() -> void:
	print("\n--- 3. Testing Solid Colliders on Multi-Car Train ---")
	
	var vab: Node = VoxelAssetBuilderScript.new()
	root.add_child(vab)
	
	var train: Node3D = vab.build_freight_train_multi_car()
	root.add_child(train)
	
	var loco = train.find_child("Locomotive", true, false)
	var boxcar = train.find_child("Boxcar", true, false)
	var tanker = train.find_child("Tanker", true, false)
	var flatbed = train.find_child("Flatbed", true, false)
	var caboose = train.find_child("Caboose", true, false)
	
	assert_true(loco != null, "Train contains Locomotive")
	assert_true(boxcar != null, "Train contains Boxcar")
	assert_true(tanker != null, "Train contains Tanker")
	assert_true(flatbed != null, "Train contains Flatbed")
	assert_true(caboose != null, "Train contains Caboose")
	
	var loco_col = _find_colliders_on_layer(loco, 8)
	var box_col = _find_colliders_on_layer(boxcar, 8)
	var tank_col = _find_colliders_on_layer(tanker, 8)
	var flat_col = _find_colliders_on_layer(flatbed, 8)
	var cab_col = _find_colliders_on_layer(caboose, 8)
	
	assert_true(loco_col.size() >= 1, "Locomotive has solid collider on Layer 8")
	assert_true(box_col.size() >= 1, "Boxcar has solid collider on Layer 8")
	assert_true(tank_col.size() >= 1, "Tanker has solid collider on Layer 8")
	assert_true(flat_col.size() >= 1, "Flatbed has solid collider on Layer 8")
	assert_true(cab_col.size() >= 1, "Caboose has solid collider on Layer 8")
	
	train.queue_free()
	vab.queue_free()

func _test_car_profile_and_gadget_sync() -> void:
	print("\n--- 4. Testing ArcadeCar set_car_profile & Gadget Sync ---")
	
	var vdb: Node = VehicleDatabaseScript.new()
	vdb.name = "VehicleDatabase"
	root.add_child(vdb)
	
	var car: ArcadeCar = ArcadeCarScene.instantiate()
	root.add_child(car)
	
	# Test profile 1: Ice Cream Drifter (Epic Tier)
	car.set_car_profile("ice_cream_drifter")
	assert_true(car.car_id == "ice_cream_drifter", "Car ID updated to ice_cream_drifter")
	assert_true(car.max_hp > 150.0, "Car HP updated to ice_cream_drifter max_hp (%f)" % car.max_hp)
	assert_true(car.current_hp == car.max_hp, "Current HP matches car profile max_hp")
	assert_true(car.stats != null and car.stats.car_id == "ice_cream_drifter", "Stats car_id matches profile")
	assert_true(car.gadget_system != null, "Car has gadget system attached")
	
	# Activate ice_cream_drifter gadget
	var g_activated: bool = car.gadget_system.activate_gadget()
	assert_true(g_activated == true, "Ice Cream Drifter unique gadget activated")
	assert_true(car.gadget_system.cooldown > 0.0, "Gadget cooldown started")
	
	# Test profile 2: Fire Dragon (Mythic Tier)
	car.set_car_profile("fire_dragon")
	assert_true(car.car_id == "fire_dragon", "Car ID updated to fire_dragon")
	assert_true(car.max_hp > 250.0, "Fire dragon has mythic high max_hp (%f)" % car.max_hp)
	assert_true(car.stats.max_speed >= 25.0, "Fire dragon has mythic high top speed (%f)" % car.stats.max_speed)
	
	car.queue_free()
	vdb.queue_free()

func _test_player_character_commandeering() -> void:
	print("\n--- 5. Testing Player Character Vehicle Commandeering ---")
	
	var vdb: Node = VehicleDatabaseScript.new()
	vdb.name = "VehicleDatabase"
	root.add_child(vdb)
	
	var runner: PlayerCharacter = PlayerCharScene.instantiate()
	root.add_child(runner)
	runner.global_position = Vector3(0.0, 0.0, 0.0)
	
	# Spawn a parked abandoned fleet car nearby
	var parked_car: ArcadeCar = ArcadeCarScene.instantiate()
	parked_car.car_id = "armored_bulldozer"
	parked_car.is_abandoned = true
	parked_car.input_enabled = false
	root.add_child(parked_car)
	parked_car.set_car_profile("armored_bulldozer")
	parked_car.global_position = Vector3(1.5, 0.0, 0.0)
	
	# Runner scans for nearby vehicles
	runner._scan_for_hijack_targets()
	var target = runner.get_nearby_vehicle()
	assert_true(target == parked_car, "PlayerCharacter detected nearby parked fleet car")
	assert_true(runner._interaction_label != null and runner._interaction_label.visible == true, "Interaction label is visible")
	assert_true("BULLDOZER" in runner._interaction_label.text or "ARMORED" in runner._interaction_label.text, "Interaction prompt displays car name (%s)" % runner._interaction_label.text)
	
	# Runner hijacks/enters parked car
	runner.hijack_vehicle(parked_car)
	assert_true(parked_car.is_abandoned == false, "Parked car is no longer abandoned")
	assert_true(parked_car.input_enabled == true, "Parked car input is enabled")
	assert_true(parked_car.stats.car_id == "armored_bulldozer", "Parked car retains bulldozer stats and identity")
	
	parked_car.queue_free()
	vdb.queue_free()

func _test_city_generator_spawns() -> void:
	print("\n--- 6. Testing CityGenerator Fleet Cars & Smashable Props ---")
	
	var vab: Node = VoxelAssetBuilderScript.new()
	vab.name = "VoxelAssetBuilder"
	root.add_child(vab)
	
	var vdb: Node = VehicleDatabaseScript.new()
	vdb.name = "VehicleDatabase"
	root.add_child(vdb)
	
	var city_gen := CityGeneratorScript.new()
	root.add_child(city_gen)
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	
	# Test Safe Plaza (Chunk 0, 0)
	var plaza_root := Node3D.new()
	city_gen._build_safe_plaza(plaza_root, rng)
	var plaza_fleet_cars = _find_arcade_cars(plaza_root)
	var plaza_plants = _find_smash_props_by_type(plaza_root, SmashPropScript.PropType.PLANT)
	assert_true(plaza_fleet_cars.size() >= 2, "Safe Plaza spawns >= 2 parked fleet cars (found %d)" % plaza_fleet_cars.size())
	assert_true(plaza_plants.size() >= 2, "Safe Plaza spawns >= 2 potted plants (found %d)" % plaza_plants.size())
	plaza_root.queue_free()
	
	# Test Farmland Chunk
	var farm_root := Node3D.new()
	city_gen._build_farmland_chunk(farm_root, rng, Vector2i(0, 5))
	var farm_pumpkins = _find_smash_props_by_type(farm_root, SmashPropScript.PropType.PUMPKIN)
	var farm_fleet_cars = _find_arcade_cars(farm_root)
	var farm_plants = _find_smash_props_by_type(farm_root, SmashPropScript.PropType.PLANT)
	assert_true(farm_pumpkins.size() >= 4, "Farmland spawns rows of smashable pumpkins (found %d)" % farm_pumpkins.size())
	assert_true(farm_fleet_cars.size() >= 1, "Farmland spawns parked fleet car near barn (found %d)" % farm_fleet_cars.size())
	assert_true(farm_plants.size() >= 1, "Farmland spawns potted plants (found %d)" % farm_plants.size())
	farm_root.queue_free()
	
	# Test Park Shortcut
	var park_root := Node3D.new()
	city_gen._build_park_shortcut(park_root, rng, Vector2i(1, 1))
	var park_plants = _find_smash_props_by_type(park_root, SmashPropScript.PropType.PLANT)
	var park_fleet_cars = _find_arcade_cars(park_root)
	assert_true(park_plants.size() >= 4, "Park Shortcut spawns potted plants around fountain/paths (found %d)" % park_plants.size())
	assert_true(park_fleet_cars.size() >= 1, "Park Shortcut spawns parked fleet car at trailhead (found %d)" % park_fleet_cars.size())
	park_root.queue_free()
	
	# Test Skyscraper Plaza
	var sky_root := Node3D.new()
	city_gen._build_skyscraper_plaza(sky_root, rng, Vector2i(2, 2))
	var sky_fleet_cars = _find_arcade_cars(sky_root)
	var sky_plants = _find_smash_props_by_type(sky_root, SmashPropScript.PropType.PLANT)
	assert_true(sky_fleet_cars.size() >= 2, "Skyscraper Plaza spawns parked fleet cars in garage & alley (found %d)" % sky_fleet_cars.size())
	assert_true(sky_plants.size() >= 2, "Skyscraper Plaza spawns potted plants (found %d)" % sky_plants.size())
	sky_root.queue_free()
	
	city_gen.queue_free()
	vdb.queue_free()
	vab.queue_free()

func _find_colliders_on_layer(node: Node, layer_bit: int) -> Array[CollisionObject3D]:
	var results: Array[CollisionObject3D] = []
	if node is CollisionObject3D:
		var col = node as CollisionObject3D
		if (col.collision_layer & layer_bit) != 0:
			results.append(col)
	for child in node.get_children():
		results.append_array(_find_colliders_on_layer(child, layer_bit))
	return results

func _find_arcade_cars(node: Node) -> Array[ArcadeCar]:
	var results: Array[ArcadeCar] = []
	if node is ArcadeCar:
		results.append(node as ArcadeCar)
	for child in node.get_children():
		results.append_array(_find_arcade_cars(child))
	return results

func _find_smash_props_by_type(node: Node, prop_type: SmashPropScript.PropType) -> Array[SmashProp]:
	var results: Array[SmashProp] = []
	if node is SmashProp:
		var sp = node as SmashProp
		if sp.prop_type == prop_type:
			results.append(sp)
	for child in node.get_children():
		results.append_array(_find_smash_props_by_type(child, prop_type))
	return results
