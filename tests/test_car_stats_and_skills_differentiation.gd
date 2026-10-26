extends SceneTree

# Test suite verifying car stats (HP & speed) differentiation, TouchHUD feedback, and unique skill mechanics

func _init() -> void:
	await process_frame
	await process_frame
	
	print("\n=================================================================")
	print("   STARTING CAR STATS & SKILLS DIFFERENTIATION TESTS             ")
	print("=================================================================\n")
	
	var all_passed := true
	all_passed = await test_vehicle_database_stats_variance() and all_passed
	all_passed = await test_arcade_car_dynamic_hp() and all_passed
	all_passed = await test_touch_hud_gadget_and_hp_sync() and all_passed
	all_passed = await test_physical_obstacle_and_skill_spawners() and all_passed
	
	if all_passed:
		print("\n=================================================================")
		print("   ALL CAR STATS & SKILLS DIFFERENTIATION TESTS PASSED (100% OK) ")
		print("=================================================================\n")
		quit(0)
	else:
		printerr("\n[FAILURE] One or more tests failed!")
		quit(1)

func _get_vdb() -> Node:
	var vdb = root.get_node_or_null("VehicleDatabase")
	if not vdb:
		var s = load("res://scripts/autoload/vehicle_database.gd")
		vdb = s.new()
		vdb.name = "VehicleDatabase"
		root.add_child(vdb)
	return vdb

func test_vehicle_database_stats_variance() -> bool:
	print("--- TEST 1: VEHICLE DATABASE STATS VARIANCE ---")
	var vdb = _get_vdb()
	
	var car_ids = ["turbo_civic", "paramedic_rapid", "garbage_compactor", "armored_bulldozer", "steamroller_iron", "f1_street_kart"]
	var hp_values: Array[float] = []
	var speed_values: Array[float] = []
	
	for cid in car_ids:
		var stats: CarStats = vdb.get_car_stats(cid)
		if stats == null:
			printerr("  [FAIL] Failed to get stats for %s" % cid)
			return false
		hp_values.append(stats.max_hp)
		speed_values.append(stats.max_speed)
		print("  Car '%s' -> HP: %.1f, Max Speed: %.1f m/s, Accel: %.1f" % [cid, stats.max_hp, stats.max_speed, stats.acceleration])
	
	var unique_hps := {}
	for hp in hp_values: unique_hps[hp] = true
	var unique_speeds := {}
	for spd in speed_values: unique_speeds[spd] = true
	
	if unique_hps.size() < 4:
		printerr("  [FAIL] Insufficient HP variance across cars! Found: %s" % str(hp_values))
		return false
	
	if unique_speeds.size() < 4:
		printerr("  [FAIL] Insufficient Speed variance across cars! Found: %s" % str(speed_values))
		return false
	
	print("  [PASS] VehicleDatabase produces distinct HP (%.1f to %.1f) and Speed (%.1f to %.1f m/s)" % [
		hp_values.min(), hp_values.max(), speed_values.min(), speed_values.max()
	])
	return true

func test_arcade_car_dynamic_hp() -> bool:
	print("\n--- TEST 2: ARCADE CAR DYNAMIC HP & EQUIPMENT ---")
	var car_scene = load("res://scenes/vehicles/arcade_car.tscn")
	var car = car_scene.instantiate() as ArcadeCar
	root.add_child(car)
	await process_frame
	
	# Test equipping light tuner (175 HP)
	car._on_car_equipped("turbo_civic")
	var civic_hp = car.max_hp
	var civic_curr = car.current_hp
	print("  Equipped 'turbo_civic' -> max_hp: %.1f, current_hp: %.1f" % [civic_hp, civic_curr])
	
	# Test equipping heavy bulldozer (380 HP)
	car._on_car_equipped("armored_bulldozer")
	var dozer_hp = car.max_hp
	var dozer_curr = car.current_hp
	print("  Equipped 'armored_bulldozer' -> max_hp: %.1f, current_hp: %.1f" % [dozer_hp, dozer_curr])
	
	# Test equipping massive steamroller (460 HP)
	car._on_car_equipped("steamroller_iron")
	var steam_hp = car.max_hp
	var steam_curr = car.current_hp
	print("  Equipped 'steamroller_iron' -> max_hp: %.1f, current_hp: %.1f" % [steam_hp, steam_curr])
	
	if civic_hp == dozer_hp or dozer_hp == steam_hp or civic_hp >= steam_hp:
		printerr("  [FAIL] Car HP is not dynamic! civic=%.1f, dozer=%.1f, steam=%.1f" % [civic_hp, dozer_hp, steam_hp])
		car.queue_free()
		return false
	
	if car.current_hp != car.max_hp:
		printerr("  [FAIL] current_hp does not match max_hp upon equipment!")
		car.queue_free()
		return false
	
	print("  [PASS] ArcadeCar dynamically loads and updates max_hp and current_hp across tiers.")
	car.queue_free()
	await process_frame
	return true

func test_touch_hud_gadget_and_hp_sync() -> bool:
	print("\n--- TEST 3: TOUCH HUD GADGET & HP RESOLUTION ---")
	var hud_scene = load("res://scenes/ui/touch_hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	await process_frame
	
	# Mock target car
	var car_scene = load("res://scenes/vehicles/arcade_car.tscn")
	var car = car_scene.instantiate() as ArcadeCar
	root.add_child(car)
	await process_frame
	
	hud.target_car = car
	if not hud.gadget_name:
		hud.gadget_name = hud.find_child("GadgetName", true, false)
	if not hud.gadget_icon:
		hud.gadget_icon = hud.find_child("GadgetIcon", true, false)
	
	# Check 1: turbo_civic
	car._on_car_equipped("turbo_civic")
	hud._refresh_gadget_info()
	var g_name1 = hud.gadget_name.text if hud.gadget_name else ""
	var g_icon1 = hud.gadget_icon.text if hud.gadget_icon else ""
	print("  Car 'turbo_civic' in HUD -> Gadget: '%s', Icon: '%s'" % [g_name1, g_icon1])
	
	# Check 2: garbage_compactor
	car._on_car_equipped("garbage_compactor")
	hud._refresh_gadget_info()
	var g_name2 = hud.gadget_name.text if hud.gadget_name else ""
	var g_icon2 = hud.gadget_icon.text if hud.gadget_icon else ""
	print("  Car 'garbage_compactor' in HUD -> Gadget: '%s', Icon: '%s'" % [g_name2, g_icon2])
	
	# Check 3: paramedic_rapid
	car._on_car_equipped("paramedic_rapid")
	hud._refresh_gadget_info()
	var g_name3 = hud.gadget_name.text if hud.gadget_name else ""
	var g_icon3 = hud.gadget_icon.text if hud.gadget_icon else ""
	print("  Car 'paramedic_rapid' in HUD -> Gadget: '%s', Icon: '%s'" % [g_name3, g_icon3])
	
	if g_name1 == g_name2 or g_name2 == g_name3 or g_name1 == "NITRO BOOST":
		printerr("  [FAIL] HUD still shows generic/identical gadgets across cars!")
		hud.queue_free()
		car.queue_free()
		return false
	
	print("  [PASS] TouchHUD correctly resolves unique gadget names and custom icons for distinct cars.")
	hud.queue_free()
	car.queue_free()
	await process_frame
	return true

func test_physical_obstacle_and_skill_spawners() -> bool:
	print("\n--- TEST 4: PHYSICAL OBSTACLE & VOLUMETRIC SMOKE SPAWNERS ---")
	var test_parent := Node3D.new()
	root.add_child(test_parent)
	await process_frame
	
	# 1. Physical trash obstacle
	var trash_node = CarGadgetSystem.spawn_physical_obstacle(test_parent, Vector3(0, 0, 0), "trash", 3)
	if not trash_node or not is_instance_valid(trash_node):
		printerr("  [FAIL] spawn_physical_obstacle('trash') failed to create node!")
		test_parent.queue_free()
		return false
	var trash_bins = 0
	for c in trash_node.get_children():
		if "TrashBin" in c.name: trash_bins += 1
	if trash_bins != 3:
		printerr("  [FAIL] Expected 3 trash bins, found %d" % trash_bins)
		test_parent.queue_free()
		return false
	print("  [OK] Physical trash obstacles spawned with 3 collision bins.")
	
	# 2. Physical boulder obstacle
	var boulder_node = CarGadgetSystem.spawn_physical_obstacle(test_parent, Vector3(5, 0, 0), "boulder", 2)
	if not boulder_node:
		printerr("  [FAIL] spawn_physical_obstacle('boulder') failed!")
		test_parent.queue_free()
		return false
	print("  [OK] Physical boulder obstacles spawned.")
	
	# 3. Volumetric smoke cloud
	var smoke_node = CarGadgetSystem.spawn_volumetric_smoke_cloud(test_parent, Vector3(10, 0, 0), Color("333333"), 6.0, 3.0)
	if not smoke_node:
		printerr("  [FAIL] spawn_volumetric_smoke_cloud failed!")
		test_parent.queue_free()
		return false
	var puffs = 0
	for c in smoke_node.get_children():
		if "SmokePuff" in c.name: puffs += 1
	if puffs < 4:
		printerr("  [FAIL] Expected at least 4 volumetric smoke puffs, found %d" % puffs)
		test_parent.queue_free()
		return false
	print("  [OK] Volumetric smoke cloud spawned with %d billowing puffs." % puffs)
	
	print("  [PASS] All obstacle and volumetric smoke skill spawners verified.")
	test_parent.queue_free()
	await process_frame
	return true
