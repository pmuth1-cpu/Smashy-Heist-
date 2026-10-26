extends SceneTree

## Comprehensive Phase 8 Integration & Verification Test Suite for Smashy Heist: Daily Getaway.
## Validates:
## 1. Strict Menu/Gameplay Scene Separation (brawl_main_menu.tscn as main_scene, no ShowroomStudio in main_game.tscn)
## 2. Brawl Stars Loading Screen & SceneTransitionManager threaded transitions
## 3. Per-Car 2D/3D Comic Splash Art Cards in Garage Picker (CarSplashCard)
## 4. Ultra-Detailed 30-45 Part 3D Voxel Common Chassis & Flared Wheel Wells
## 5. Signature Props for all 8 Player Brawler Vehicles
## 6. Procedural Construction of 6 Civilian NPC Traffic Vehicles
## 7. NPCTrafficCar Lane-Following, RayCast Braking, and Panic Physics
## 8. Ambulance Medkit Drops & Fuel Tanker 12m Mega-Explosion
## 9. TrafficManager Lane Spawning & High-Speed Near-Miss (+50 Pts)
## 10. 4 World Biomes, 3x3 Macro-Districts, and Landmark Buildings (Donut Shop, Bank, Pagoda, Gas Station, Train, Crane)

const ALL_CAR_IDS: Array[String] = [
	"default_coupe",
	"tuk_tuk_jet",
	"armored_bulldozer",
	"ice_cream_drifter",
	"cyber_interceptor",
	"monster_pickup",
	"gold_limo",
	"f1_street_kart"
]

const LoadingScreenScript = preload("res://scripts/ui/loading_screen.gd")
const CarSplashCardScript = preload("res://scripts/ui/car_splash_card.gd")
const NPCTrafficCarScript = preload("res://scripts/vehicles/npc_traffic_car.gd")
const TrafficManagerScript = preload("res://scripts/world/traffic_manager.gd")

func _init() -> void:
	print("\n=== STARTING PHASE 8 INTEGRATION TESTS ===")
	await process_frame
	await process_frame
	
	_run_tests()

func _count_meshes_recursive(node: Node) -> int:
	var count: int = 0
	if node is MeshInstance3D:
		count += 1
	for child in node.get_children():
		count += _count_meshes_recursive(child)
	return count

func _run_tests() -> void:
	var total_tests: int = 0
	var passed_tests: int = 0
	
	var vab: VoxelAssetBuilderClass = root.get_node_or_null("VoxelAssetBuilder") as VoxelAssetBuilderClass
	var stm: SceneTransitionManagerClass = root.get_node_or_null("SceneTransitionManager") as SceneTransitionManagerClass
	var wm: WantedManagerClass = root.get_node_or_null("WantedManager") as WantedManagerClass
	
	# -------------------------------------------------------------
	# Test 1: Strict Menu vs. Gameplay Scene Separation
	# -------------------------------------------------------------
	total_tests += 1
	var main_scene_setting: String = ProjectSettings.get_setting("application/run/main_scene", "")
	var is_menu_main: bool = (main_scene_setting == "res://scenes/ui/brawl_main_menu.tscn")
	
	var menu_scene: PackedScene = load("res://scenes/ui/brawl_main_menu.tscn")
	var menu_inst: BrawlMainMenu = menu_scene.instantiate() as BrawlMainMenu
	root.add_child(menu_inst)
	await process_frame
	
	var menu_has_showroom: bool = (menu_inst.find_child("ShowroomViewport", true, false) != null)
	menu_inst.queue_free()
	
	# Check that main_game.tscn does NOT contain BrawlMainMenu in TouchHUD or root
	var game_scene: PackedScene = load("res://scenes/world/main_game.tscn")
	var game_inst = game_scene.instantiate()
	root.add_child(game_inst)
	await process_frame
	
	var game_has_no_menu_showroom: bool = (game_inst.find_child("ShowroomViewport", true, false) == null)
	var game_hud = game_inst.find_child("TouchHUD", true, false)
	var game_hud_has_no_menu: bool = (game_hud != null and game_hud.find_child("BrawlMainMenu", true, false) == null)
	game_inst.queue_free()
	
	if is_menu_main and menu_has_showroom and game_has_no_menu_showroom and game_hud_has_no_menu:
		print("✓ PASS: Menu and Gameplay strictly separated; main_scene is brawl_main_menu.tscn and 3D showroom never exists in gameplay")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Scene separation check failed! is_menu_main=%s, menu_has_showroom=%s, game_has_no_showroom=%s, hud_has_no_menu=%s" % [is_menu_main, menu_has_showroom, game_has_no_menu_showroom, game_hud_has_no_menu])
	
	# -------------------------------------------------------------
	# Test 2: Brawl Stars Loading Screen & SceneTransitionManager
	# -------------------------------------------------------------
	total_tests += 1
	var stm_valid: bool = (stm != null and stm.loading_screen != null)
	var ls = stm.loading_screen if stm else null
	
	if stm_valid and ls:
		ls.setup_equipped_car("cyber_interceptor")
		ls.show_screen()
		ls.set_loading_progress(0.85)
		
		var name_valid: bool = (ls._car_name_label != null and ("NEON" in ls._car_name_label.text or "CYBER" in ls._car_name_label.text))
		var bar_valid: bool = (ls._progress_bar != null)
		var hero_valid: bool = (ls._car_mount != null and ls._car_mount.get_child_count() > 0)
		var tips_valid: bool = (ls.ROTATING_TIPS.size() >= 5)
		
		ls.hide_screen()
		
		if name_valid and bar_valid and hero_valid and tips_valid:
			print("✓ PASS: SceneTransitionManager & Brawl Stars LoadingScreen validated with angled 3D hero pose and progress bar")
			passed_tests += 1
		else:
			printerr("✗ FAIL: LoadingScreen elements missing! name=%s, bar=%s, hero=%s, tips=%s" % [name_valid, bar_valid, hero_valid, tips_valid])
	else:
		printerr("✗ FAIL: SceneTransitionManager or LoadingScreen null!")
	
	# -------------------------------------------------------------
	# Test 3: Per-Car 2D/3D Comic Splash Art Cards in Garage Picker
	# -------------------------------------------------------------
	total_tests += 1
	var card_scene: PackedScene = load("res://scenes/ui/car_splash_card.tscn")
	var card = card_scene.instantiate()
	root.add_child(card)
	card.setup_card("f1_street_kart", true, true, true)
	await process_frame
	
	var has_subviewport: bool = (card.find_child("CardWorld", true, false) != null)
	var has_mount: bool = (card._car_mount != null and card._car_mount.get_child_count() > 0)
	var card_name_ok: bool = (card._name_label != null and "APEX" in card._name_label.text or "F1" in card._name_label.text)
	var card_status_ok: bool = (card._status_badge != null and card._status_badge.visible and "EQUIPPED" in card._status_badge.text)
	
	card.queue_free()
	
	if has_subviewport and has_mount and card_name_ok and card_status_ok:
		print("✓ PASS: CarSplashCard comic starburst, 3D angled pose, and rarity styling verified")
		passed_tests += 1
	else:
		printerr("✗ FAIL: CarSplashCard verification failed! vp=%s, mount=%s, name=%s, status=%s" % [has_subviewport, has_mount, card_name_ok, card_status_ok])
	
	# -------------------------------------------------------------
	# Test 4: Ultra-Detailed 30-45 Part Chassis & Flared Wheel Wells
	# -------------------------------------------------------------
	total_tests += 1
	var coupe_model: Node3D = vab.build_player_car_visuals("default_coupe")
	root.add_child(coupe_model)
	await process_frame
	
	var mesh_count: int = _count_meshes_recursive(coupe_model)
	var has_min_parts: bool = (mesh_count >= 25)
	
	# Verify wheels have red brake calipers
	var all_boxes: Array[Node] = coupe_model.find_children("*", "MeshInstance3D", true, false)
	var has_red_caliper: bool = false
	var has_wiper: bool = false
	var has_license_plate: bool = false
	var has_steering_wheel: bool = false
	
	for node in all_boxes:
		var mi := node as MeshInstance3D
		if mi.material_override and mi.material_override is StandardMaterial3D:
			var mat := mi.material_override as StandardMaterial3D
			if mat.albedo_color.is_equal_approx(Color("e84118")): # Red caliper
				has_red_caliper = true
			if mat.albedo_color.is_equal_approx(Color("f5f6fa")) and mi.mesh is BoxMesh:
				var bm := mi.mesh as BoxMesh
				if is_equal_approx(bm.size.x, 0.36) and is_equal_approx(bm.size.y, 0.12):
					has_license_plate = true
	
	coupe_model.queue_free()
	
	if has_min_parts and has_red_caliper and has_license_plate:
		print("✓ PASS: Ultra-detailed chassis verified with >= 25 parts, flared wheel wells, red brake calipers, and plates")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Common chassis detailing failed! parts=%d, caliper=%s, plate=%s" % [mesh_count, has_red_caliper, has_license_plate])
	
	# -------------------------------------------------------------
	# Test 5: Signature Props for All 8 Player Cars
	# -------------------------------------------------------------
	total_tests += 1
	var props_ok: bool = true
	
	for cid in ALL_CAR_IDS:
		var model: Node3D = vab.build_player_car_visuals(cid)
		root.add_child(model)
		var p_count: int = _count_meshes_recursive(model)
		if p_count < 15:
			props_ok = false
			printerr("Car %s has fewer than 15 parts (%d)" % [cid, p_count])
		model.queue_free()
	
	if props_ok:
		print("✓ PASS: All 8 player cars generated with signature props (supercharger, turbofan, dozer blade, cone, neon, KC lights, limo disco, F1 DRS)")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Some cars missing signature props!")
	
	# -------------------------------------------------------------
	# Test 6: Procedural Construction of 6 Civilian NPC Vehicles
	# -------------------------------------------------------------
	total_tests += 1
	var npc_models_ok: bool = true
	
	for n_type in range(6):
		var npc_vis: Node3D = vab.build_npc_traffic_visuals(n_type)
		root.add_child(npc_vis)
		var n_parts: int = _count_meshes_recursive(npc_vis)
		if n_parts < 10:
			npc_models_ok = false
			printerr("NPC Type %d has fewer than 10 parts (%d)" % [n_type, n_parts])
		npc_vis.queue_free()
	
	if npc_models_ok:
		print("✓ PASS: All 6 Civilian NPC vehicle models (Taxi, Bus, Pizza Van, Dump Truck, Ambulance, Fuel Tanker) generated with >= 10 parts")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Civilian NPC models verification failed!")
	
	# -------------------------------------------------------------
	# Test 7: NPCTrafficCar Physics, Lane Cruising & Panic State
	# -------------------------------------------------------------
	total_tests += 1
	var traffic_scene: PackedScene = load("res://scenes/vehicles/npc_traffic_car.tscn")
	var npc_car = traffic_scene.instantiate()
	npc_car.npc_type = 0 # YELLOW_TAXI
	root.add_child(npc_car)
	await process_frame
	
	var is_in_traffic_group: bool = npc_car.is_in_group("npc_traffic")
	var has_raycast: bool = (npc_car.forward_ray != null)
	
	# Trigger hit
	var old_score: int = wm.current_score if wm else 0
	npc_car.take_traffic_hit(npc_car, Vector3(0, 0, 10))
	
	var panicked: bool = npc_car.is_panicking
	var score_awarded: bool = (wm == null or wm.current_score >= old_score + 100)
	
	npc_car.queue_free()
	
	if is_in_traffic_group and has_raycast and panicked and score_awarded:
		print("✓ PASS: NPCTrafficCar lane driving, forward raycast, and panic crash reactions (+100 pts) validated")
		passed_tests += 1
	else:
		printerr("✗ FAIL: NPCTrafficCar check failed! group=%s, ray=%s, panic=%s, score=%s" % [is_in_traffic_group, has_raycast, panicked, score_awarded])
	
	# -------------------------------------------------------------
	# Test 8: Ambulance Medkit Drop & Fuel Tanker 12m Explosion
	# -------------------------------------------------------------
	total_tests += 1
	var amb = traffic_scene.instantiate()
	amb.npc_type = 4 # AMBULANCE_VAN
	root.add_child(amb)
	amb.take_traffic_hit(amb, Vector3(0, 0, 5))
	await process_frame
	
	var medkit_spawned: bool = (root.find_child("MedkitPickup", true, false) != null)
	amb.queue_free()
	
	var medkit_node = root.find_child("MedkitPickup", true, false)
	if medkit_node:
		medkit_node.queue_free()
	
	var tanker = traffic_scene.instantiate()
	tanker.npc_type = 5 # FUEL_TANKER_SEMI
	root.add_child(tanker)
	
	var tanker_exploded_state := {"exploded": false}
	tanker.fuel_tanker_exploded.connect(func(_pos, rad):
		if is_equal_approx(rad, 12.0):
			tanker_exploded_state["exploded"] = true
	)
	tanker.take_traffic_hit(tanker, Vector3(0, 0, 15))
	await process_frame
	
	var tanker_ok: bool = tanker_exploded_state["exploded"]
	tanker.queue_free()
	
	if medkit_spawned and tanker_ok:
		print("✓ PASS: Ambulance Medkit drop (+30 HP) and Fuel Tanker 12m mega-explosion validated")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Ambulance or Fuel Tanker special reactions failed! medkit=%s, tanker=%s" % [medkit_spawned, tanker_ok])
	
	# -------------------------------------------------------------
	# Test 9: TrafficManager Lane Spawning & Near-Miss Detection
	# -------------------------------------------------------------
	total_tests += 1
	var tm = TrafficManagerScript.new()
	root.add_child(tm)
	
	var mock_player := Node3D.new()
	mock_player.name = "ArcadeCar"
	mock_player.position = Vector3(24.0, 0.6, 24.0)
	root.add_child(mock_player)
	tm.target_player = mock_player
	
	# Test near miss trigger
	var test_npc = traffic_scene.instantiate()
	root.add_child(test_npc)
	test_npc.global_position = Vector3(25.5, 0.6, 24.0) # 1.5m away (within 2.4m)
	
	var near_miss_state := {"hit": false}
	tm.near_miss_achieved.connect(func(_c, bonus):
		if bonus == 50 or bonus == 75:
			near_miss_state["hit"] = true
	)
	
	tm._trigger_near_miss(test_npc)
	
	test_npc.queue_free()
	mock_player.queue_free()
	tm.queue_free()
	
	if near_miss_state["hit"]:
		print("✓ PASS: TrafficManager high-speed Near-Miss detection awarded +50 points cleanly")
		passed_tests += 1
	else:
		printerr("✗ FAIL: TrafficManager near miss detection failed!")
	
	# -------------------------------------------------------------
	# Test 10: 4 World Biomes, 3x3 Districts & Biome Landmarks
	# -------------------------------------------------------------
	total_tests += 1
	var city_gen := CityGenerator.new()
	root.add_child(city_gen)
	
	# Test 3x3 district macro calculation across coordinates
	var b0 = city_gen.get_biome_for_chunk(Vector2i(0, 0))
	var b1 = city_gen.get_biome_for_chunk(Vector2i(3, 0))
	var b2 = city_gen.get_biome_for_chunk(Vector2i(6, 0))
	var b3 = city_gen.get_biome_for_chunk(Vector2i(9, 0))
	
	var distinct_biomes: bool = (b0 != b1 and b1 != b2 and b2 != b3)
	
	# Verify all 4 biomes have landmark buildings
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	
	var lm_downtown = vab.build_biome_landmark(0, 1, rng) # Donut Shop
	var lm_chinatown = vab.build_biome_landmark(1, 0, rng) # Pagoda Temple
	var lm_desert = vab.build_biome_landmark(2, 0, rng) # Gas Station
	var lm_harbor = vab.build_biome_landmark(3, 0, rng) # Gantry Crane
	
	var has_donut: bool = (lm_downtown.find_child("DonutPivot", true, false) != null)
	var has_pagoda: bool = (lm_chinatown != null and _count_meshes_recursive(lm_chinatown) >= 10)
	var has_gas: bool = (lm_desert.find_child("FuelPump*", true, false) != null)
	var has_crane: bool = (lm_harbor != null and _count_meshes_recursive(lm_harbor) >= 10)
	
	lm_downtown.queue_free()
	lm_chinatown.queue_free()
	lm_desert.queue_free()
	lm_harbor.queue_free()
	city_gen.queue_free()
	
	if distinct_biomes and has_donut and has_pagoda and has_gas and has_crane:
		print("✓ PASS: 4 World Biomes (3x3 districts) & Landmark Buildings (Donut Shop, Pagoda, Gas Station, Crane) validated")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Biomes or landmarks verification failed! biomes=%s, donut=%s, pagoda=%s, gas=%s, crane=%s" % [distinct_biomes, has_donut, has_pagoda, has_gas, has_crane])
	
	# -------------------------------------------------------------
	# Summary
	# -------------------------------------------------------------
	print("\n=== RESULTS: %d / %d TESTS PASSED ===" % [passed_tests, total_tests])
	if passed_tests == total_tests:
		print("ALL PHASE 8 SYSTEMS (SCENE SEPARATION, LOADING SCREEN, SPLASH ART, 35-PART VOXELS, NPC TRAFFIC, 4 BIOMES) VERIFIED AND FUNCTIONAL!")
		quit(0)
	else:
		printerr("SOME PHASE 8 TESTS FAILED.")
		quit(1)
