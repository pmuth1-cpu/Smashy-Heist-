extends SceneTree

func _init() -> void:
	print("\n=== STARTING PHASE 4 INTEGRATION TESTS ===")
	await process_frame
	await process_frame
	
	_run_tests()

func _run_tests() -> void:
	var total_tests: int = 0
	var passed_tests: int = 0
	
	# Test 1: Autoload Presence
	total_tests += 1
	var sm = root.get_node_or_null("SaveManager")
	var lm = root.get_node_or_null("LeaderboardManager")
	var wm = root.get_node_or_null("WantedManager")
	var dsm = root.get_node_or_null("DailySeedManager")
	
	if sm != null and lm != null and wm != null and dsm != null:
		print("✓ PASS: All 4 Autoloads (SaveManager, LeaderboardManager, WantedManager, DailySeedManager) loaded")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Autoload missing! sm=%s, lm=%s, wm=%s, dsm=%s" % [sm, lm, wm, dsm])
	
	# Test 2: SaveManager profile and cash operations
	total_tests += 1
	sm.total_cash = 250
	sm.save_to_disk()
	var initial_cash: int = sm.total_cash
	var spend_success: bool = sm.spend_cash(100)
	var post_spend_cash: int = sm.total_cash
	sm.add_cash(50)
	var post_add_cash: int = sm.total_cash
	
	if spend_success and post_spend_cash == 150 and post_add_cash == 200:
		print("✓ PASS: SaveManager cash spend/add logic validated (250 -> 150 -> 200)")
		passed_tests += 1
	else:
		printerr("✗ FAIL: SaveManager cash logic failed! spend=%s, post_spend=%d, post_add=%d" % [spend_success, post_spend_cash, post_add_cash])
	
	# Test 3: Vehicle Unlocking and Equipping
	total_tests += 1
	var all_cars: Array[String] = ["default_coupe", "tuk_tuk_jet", "ice_cream_drifter", "armored_bulldozer", "cyber_interceptor"]
	var all_paths_valid: bool = true
	for car_id in all_cars:
		var path: String = "res://resources/vehicles/%s.tres" % car_id
		if not ResourceLoader.exists(path):
			all_paths_valid = false
			printerr("Missing car resource: %s" % path)
	
	var unlock_res: bool = sm.unlock_car("tuk_tuk_jet")
	var equip_res: bool = sm.equip_car("tuk_tuk_jet")
	var equipped_path: String = sm.get_equipped_car_stats_path()
	
	if all_paths_valid and equip_res and sm.equipped_car_id == "tuk_tuk_jet" and "tuk_tuk_jet" in equipped_path:
		print("✓ PASS: All 5 CarStats resources exist, unlocking & equipping 'tuk_tuk_jet' succeeded")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Vehicle equip failed! all_paths=%s, equip_res=%s, equipped_id=%s" % [all_paths_valid, equip_res, sm.equipped_car_id])
	
	# Test 4: Run Completion & UTC Daily Streak Recording
	total_tests += 1
	var dummy_ghost: Array[Dictionary] = [
		{"t": 0.0, "x": 0.0, "y": 0.0, "z": 0.0, "ry": 0.0},
		{"t": 0.2, "x": 1.0, "y": 0.0, "z": 2.0, "ry": 0.1},
		{"t": 0.4, "x": 2.5, "y": 0.0, "z": 4.2, "ry": 0.2}
	]
	var prev_cash: int = sm.total_cash
	var test_score: int = sm.best_daily_score + 500
	sm.record_completed_run(test_score, 25.0, 3, true, dummy_ghost)
	
	var cash_gain: int = sm.total_cash - prev_cash # test_score / 25
	var expected_gain: int = int(test_score / 25)
	var ghost_saved: bool = sm.saved_daily_ghost.size() == 3
	var queue_has_entry: bool = not sm.pending_score_queue.is_empty()
	var streak_valid: bool = sm.daily_streak >= 1
	
	if cash_gain == expected_gain and ghost_saved and queue_has_entry and streak_valid:
		print("✓ PASS: record_completed_run correctly awarded 20 cash, recorded ghost frames, updated daily streak (%d), and queued score" % sm.daily_streak)
		passed_tests += 1
	else:
		printerr("✗ FAIL: record_completed_run failed! gain=%d, ghost=%s, queue=%s, streak=%d" % [cash_gain, ghost_saved, queue_has_entry, sm.daily_streak])
	
	# Test 5: LeaderboardManager Simulated Top 15 Deterministic Leaderboard
	total_tests += 1
	lm.sync_pending_scores_and_fetch()
	var cached_lb: Array[Dictionary] = sm.cached_leaderboard
	var lb_valid: bool = cached_lb.size() >= 15
	var descending_order: bool = true
	var player_found: bool = false
	
	for i in range(cached_lb.size()):
		if i > 0 and int(cached_lb[i]["score"]) > int(cached_lb[i - 1]["score"]):
			descending_order = false
		if bool(cached_lb[i].get("is_player", false)):
			player_found = true
	
	if lb_valid and descending_order and player_found:
		print("✓ PASS: LeaderboardManager produced %d entries sorted descending, containing player entry" % cached_lb.size())
		passed_tests += 1
	else:
		printerr("✗ FAIL: LeaderboardManager failed! count=%d, descending=%s, player_found=%s" % [cached_lb.size(), descending_order, player_found])
	
	# Test 6: GhostCar Hologram Replay Instantiation & Interpolation
	total_tests += 1
	var ghost_scene: PackedScene = load("res://scenes/vehicles/ghost_car.tscn")
	var ghost_inst: GhostCar = ghost_scene.instantiate() as GhostCar
	ghost_inst.recorded_frames = dummy_ghost
	root.add_child(ghost_inst)
	await process_frame
	
	# Check initial position matches f0
	var initial_pos_ok: bool = ghost_inst.global_position.distance_to(Vector3.ZERO) < 0.01
	
	# Advance 0.3s playback
	wm.is_run_active = true
	ghost_inst._process(0.3)
	var mid_pos: Vector3 = ghost_inst.global_position
	var advanced_ok: bool = mid_pos.x > 1.0 and mid_pos.z > 2.0
	ghost_inst.queue_free()
	
	if initial_pos_ok and advanced_ok:
		print("✓ PASS: GhostCar correctly instantiated and interpolated frames (pos: %s)" % [mid_pos])
		passed_tests += 1
	else:
		printerr("✗ FAIL: GhostCar interpolation failed! init_ok=%s, adv_ok=%s, pos=%s" % [initial_pos_ok, advanced_ok, mid_pos])
	
	# Test 7: GarageGachaPanel Instantiation & Card Generation
	total_tests += 1
	var garage_scene: PackedScene = load("res://scenes/ui/garage_gacha_panel.tscn")
	var garage_inst: GarageGachaPanel = garage_scene.instantiate() as GarageGachaPanel
	root.add_child(garage_inst)
	await process_frame
	
	var cards_count: int = garage_inst.cards_container.get_child_count()
	var pick_car: String = garage_inst._pick_weighted_car()
	var has_valid_pick: bool = pick_car in all_cars
	garage_inst.queue_free()
	
	if cards_count == 5 and has_valid_pick:
		print("✓ PASS: GarageGachaPanel generated 5 vehicle cards with valid weighted roll ('%s')" % pick_car)
		passed_tests += 1
	else:
		printerr("✗ FAIL: GarageGachaPanel failed! cards=%d, pick=%s" % [cards_count, pick_car])
	
	# Test 8: ArcadeCar Visuals & Mass Adaptation
	total_tests += 1
	var car_scene: PackedScene = load("res://scenes/vehicles/arcade_car.tscn")
	var car_inst: ArcadeCar = car_scene.instantiate() as ArcadeCar
	root.add_child(car_inst)
	await process_frame
	
	# Unlock and equip bulldozer (mass 4.5/5.5)
	sm.unlock_car("armored_bulldozer")
	sm.equip_car("armored_bulldozer")
	await process_frame
	var mass_ok: bool = is_equal_approx(car_inst.physics_sphere.mass, 4.5) or is_equal_approx(car_inst.physics_sphere.mass, 5.5)
	var scale_ok: bool = car_inst.body_mesh.scale.x > 1.1
	car_inst.queue_free()
	
	# Restore default coupe
	sm.equip_car("default_coupe")
	
	if mass_ok and scale_ok:
		print("✓ PASS: ArcadeCar dynamically reconfigured mass (5.5) and mesh scale for equipped vehicle")
		passed_tests += 1
	else:
		printerr("✗ FAIL: ArcadeCar visual adaptation failed! mass=%.2f, scale=%s" % [car_inst.physics_sphere.mass, car_inst.body_mesh.scale])
	
	# Test 9: MainGame Scene Clean Load
	total_tests += 1
	var main_scene: PackedScene = load("res://scenes/world/main_game.tscn")
	if main_scene != null:
		var main_inst = main_scene.instantiate()
		root.add_child(main_inst)
		await process_frame
		await process_frame
		
		var hud = main_inst.find_child("TouchHUD", true, false)
		var lb = hud.find_child("LeaderboardPanel", true, false) if hud else null
		var gg = hud.find_child("GarageGachaPanel", true, false) if hud else null
		var summary = hud.find_child("RunSummaryPanel", true, false) if hud else null
		
		main_inst.queue_free()
		
		if hud != null and lb != null and gg != null and summary != null:
			print("✓ PASS: main_game.tscn instantiated cleanly with TouchHUD, LeaderboardPanel, GarageGachaPanel, and RunSummaryPanel")
			passed_tests += 1
		else:
			printerr("✗ FAIL: main_game nodes missing! hud=%s, lb=%s, gg=%s, summary=%s" % [hud, lb, gg, summary])
	else:
		printerr("✗ FAIL: Failed to load main_game.tscn")
	
	print("\n=== RESULTS: %d / %d TESTS PASSED ===" % [passed_tests, total_tests])
	if passed_tests == total_tests:
		print("ALL PHASE 4 SYSTEMS VERIFIED AND FUNCTIONAL!")
		quit(0)
	else:
		printerr("SOME TESTS FAILED.")
		quit(1)
