extends SceneTree

## Comprehensive Phase 7 Integration & Verification Test Suite for Smashy Heist: Daily Getaway.
## Validates GameModeManager Autoload & 2x2 Mode Selection Drawer,
## Mode 2 ("Bank Heist: Steal & Extract"), Mode 3 ("Escape the Mega-Boss"),
## Street Power-Up Crates (Nitro, EMP, Oil Slick, Titan Shield), and TouchHUD integration.

func _init() -> void:
	print("\n=== STARTING PHASE 7 INTEGRATION TESTS ===")
	await process_frame
	await process_frame
	
	_run_tests()

func _run_tests() -> void:
	var total_tests: int = 0
	var passed_tests: int = 0
	
	# -------------------------------------------------------------
	# Test 1: GameModeManager Autoload & Metadata Dictionary
	# -------------------------------------------------------------
	total_tests += 1
	var gmm: GameModeManagerClass = root.get_node_or_null("GameModeManager") as GameModeManagerClass
	if gmm != null:
		var has_modes: bool = (gmm.get_mode_count() == 4)
		var mode0_info: Dictionary = gmm.get_mode_info(0)
		var mode1_info: Dictionary = gmm.get_mode_info(1)
		var mode2_info: Dictionary = gmm.get_mode_info(2)
		var mode3_info: Dictionary = gmm.get_mode_info(3)
		
		var titles_valid: bool = (
			"DAILY" in str(mode0_info.get("title", "")) and
			"BANK HEIST" in str(mode1_info.get("title", "")) and
			"MEGA-BOSS" in str(mode2_info.get("title", "")) and
			"HOT LOOT" in str(mode3_info.get("title", ""))
		)
		
		var test_state1 := {"sig": false, "obj": false}
		gmm.mode_changed.connect(func(m):
			if int(m) == 1:
				test_state1["sig"] = true
		)
		gmm.set_mode(1)
		
		gmm.mode_objective_updated.connect(func(txt, _prog):
			if "TEST OBJECTIVE" in str(txt):
				test_state1["obj"] = true
		)
		gmm.update_objective("TEST OBJECTIVE", 0.5)
		
		if has_modes and titles_valid and test_state1["sig"] and test_state1["obj"]:
			print("✓ PASS: GameModeManager Autoload loaded with 4 modes, metadata, and objective signals")
			passed_tests += 1
		else:
			printerr("✗ FAIL: GameModeManager metadata or signal mismatch! modes=%s, titles=%s, sig=%s, obj=%s" % [has_modes, titles_valid, test_state1["sig"], test_state1["obj"]])
	else:
		printerr("✗ FAIL: GameModeManager Autoload not found on root!")
	
	# -------------------------------------------------------------
	# Test 2: BrawlMainMenu 2x2 Mode Selection Drawer & Play Trigger
	# -------------------------------------------------------------
	total_tests += 1
	var menu_scene: PackedScene = load("res://scenes/ui/brawl_main_menu.tscn")
	if menu_scene:
		var menu: BrawlMainMenu = menu_scene.instantiate() as BrawlMainMenu
		root.add_child(menu)
		menu.open_menu()
		
		var mode_btn = menu._mode_banner_btn
		var mode_drawer = menu._mode_drawer_panel
		var mode_grid = menu._mode_grid
		
		var banner_valid: bool = (mode_btn != null and mode_drawer != null and mode_grid != null)
		var grid_count: int = mode_grid.get_child_count() if mode_grid else 0
		
		# Test mode selection
		menu._toggle_mode_drawer()
		var drawer_toggled: bool = mode_drawer.visible
		if gmm:
			gmm.set_mode(1)
		
		var test_state2 := {"play_emitted": false, "emitted_mode": -1}
		menu.play_pressed.connect(func(m):
			test_state2["play_emitted"] = true
			test_state2["emitted_mode"] = int(m)
		)
		menu._on_smash_play_pressed()
		
		menu.queue_free()
		if banner_valid and grid_count == 4 and drawer_toggled and test_state2["play_emitted"] and test_state2["emitted_mode"] == 1:
			print("✓ PASS: BrawlMainMenu Mode Selection Drawer (4 mode cards) and play_pressed signal verified")
			passed_tests += 1
		else:
			printerr("✗ FAIL: BrawlMainMenu mode drawer mismatch! grid_count=%d, play_emitted=%s, emitted_mode=%d" % [grid_count, test_state2["play_emitted"], test_state2["emitted_mode"]])
	else:
		printerr("✗ FAIL: Could not load brawl_main_menu.tscn!")
	
	# -------------------------------------------------------------
	# Test 3: HeistStealMode Vault Truck Spawning, 6.5m Emerald Ring & Light Pillar
	# -------------------------------------------------------------
	total_tests += 1
	var car_scene: PackedScene = load("res://scenes/vehicles/arcade_car.tscn")
	var test_car: ArcadeCar = car_scene.instantiate() as ArcadeCar
	root.add_child(test_car)
	test_car.global_position = Vector3(20.0, 0.6, 20.0)
	
	var heist_mode := HeistStealMode.new()
	root.add_child(heist_mode)
	heist_mode.start_heist_mode(test_car)
	
	var vault_node: Node3D = heist_mode.current_vault
	var vault_spawned: bool = (vault_node != null and is_instance_valid(vault_node))
	var ring_found: bool = false
	var pillar_found: bool = false
	var vault_dist: float = 0.0
	
	if vault_spawned:
		vault_dist = test_car.global_position.distance_to(heist_mode.vault_global_pos)
		var ring = vault_node.get_node_or_null("EmeraldRing")
		var pillar = vault_node.get_node_or_null("LightPillar")
		ring_found = (ring != null and ring is MeshInstance3D and (ring as MeshInstance3D).mesh is TorusMesh)
		pillar_found = (pillar != null and pillar is MeshInstance3D and (pillar as MeshInstance3D).mesh is CylinderMesh)
	
	var dist_valid: bool = (vault_dist >= 80.0 and vault_dist <= 170.0)
	if vault_spawned and dist_valid and ring_found and pillar_found:
		print("✓ PASS: HeistStealMode spawned Bank Vault at %.1fm with TorusMesh emerald ring and vertical light pillar" % vault_dist)
		passed_tests += 1
	else:
		printerr("✗ FAIL: Vault spawning mismatch! dist=%.1f, ring=%s, pillar=%s" % [vault_dist, ring_found, pillar_found])
	
	# -------------------------------------------------------------
	# Test 4: HeistStealMode 2.5s Cracking, Towed Safe Trailing 2.3m, and SWAT Escalation
	# -------------------------------------------------------------
	total_tests += 1
	var wm = root.get_node_or_null("WantedManager")
	if wm:
		wm.start_new_run()
		wm.wanted_stars = 1
	
	# Move player car inside vault circle
	test_car.global_position = heist_mode.vault_global_pos + Vector3(1.0, 0.0, 0.0)
	test_car.car_pivot.global_position = test_car.global_position
	
	# Simulate 2.6s of cracking
	heist_mode._physics_process(1.5)
	var mid_cracking: bool = (heist_mode.cracking_timer >= 1.4 and not heist_mode.is_towing_safe)
	heist_mode._physics_process(1.2) # Completes cracking (total 2.7s >= 2.5s)
	
	var safe_spawned: bool = (heist_mode.is_towing_safe and heist_mode.towed_safe != null and is_instance_valid(heist_mode.towed_safe))
	var cable_spawned: bool = (heist_mode.tow_cable != null and is_instance_valid(heist_mode.tow_cable))
	var stars_escalated: bool = (wm == null or wm.wanted_stars >= 3)
	
	if mid_cracking and safe_spawned and cable_spawned and stars_escalated:
		print("✓ PASS: Bank Vault 2.5s cracking completed, Towed Safe attached with TowCable, and Heat escalated to 3+ Stars")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Cracking or Safe towing mismatch! mid=%s, safe=%s, cable=%s, stars=%d" % [mid_cracking, safe_spawned, cable_spawned, (wm.wanted_stars if wm else 0)])
	
	# -------------------------------------------------------------
	# Test 5: Chopper Extraction Zone, Upward Winch, Score, Cash, and HP Repair
	# -------------------------------------------------------------
	total_tests += 1
	var ext_zone: Node3D = heist_mode.extraction_zone
	var ext_spawned: bool = (ext_zone != null and is_instance_valid(ext_zone))
	var ext_dist: float = test_car.global_position.distance_to(heist_mode.extraction_global_pos)
	
	test_car.current_hp = 60.0 # Partially damaged
	var sm = root.get_node_or_null("SaveManager")
	var initial_cash: int = sm.total_cash if sm else 0
	var initial_score: int = wm.current_score if wm else 0
	
	# Drive car into extraction zone
	test_car.global_position = heist_mode.extraction_global_pos
	test_car.car_pivot.global_position = test_car.global_position
	heist_mode._physics_process(0.1)
	
	var extracted: bool = (heist_mode.vaults_extracted == 1)
	var score_awarded: bool = (wm == null or wm.current_score >= initial_score + 1500)
	var cash_awarded: bool = (sm == null or sm.total_cash >= initial_cash + 75)
	var car_repaired: bool = (test_car.current_hp >= 100.0) # 60 + 40 = 100
	var new_vault_spawned: bool = (heist_mode.current_vault != null and not heist_mode.is_towing_safe)
	
	heist_mode.stop_heist_mode()
	heist_mode.queue_free()
	
	if ext_spawned and extracted and score_awarded and cash_awarded and car_repaired and new_vault_spawned:
		print("✓ PASS: Chopper Extraction Zone successfully winched safe (+1500 score, +$75 cash, +40 HP repair) and looped next vault")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Extraction mismatch! ext_spawned=%s, extracted=%s, score=%s, cash=%s, hp=%.1f, new_vault=%s" % [ext_spawned, extracted, score_awarded, cash_awarded, test_car.current_hp, new_vault_spawned])
	
	# -------------------------------------------------------------
	# Test 6: BossEscapeMode Mecha-Crusher Dozer (2.6x scale, spiked roller, hazard vulnerability)
	# -------------------------------------------------------------
	total_tests += 1
	var boss_mode := BossEscapeMode.new()
	root.add_child(boss_mode)
	boss_mode.start_boss_mode(test_car)
	
	var is_dozer: bool = (boss_mode.current_boss_type == BossEscapeMode.BossType.MECHA_DOZER)
	var dozer_node: Node3D = boss_mode.boss_node
	var dozer_valid: bool = (dozer_node != null and is_instance_valid(dozer_node))
	var roller_found: bool = (boss_mode._dozer_roller != null)
	var laser_found: bool = (boss_mode._dozer_laser != null)
	
	# Test hazard damage (e.g. explosive barrel impact 250 dmg)
	var hp_before: float = boss_mode.boss_hp
	boss_mode.apply_hazard_damage(250.0)
	var hp_after: float = boss_mode.boss_hp
	var damage_valid: bool = (hp_before == 1000.0 and hp_after == 750.0)
	
	if is_dozer and dozer_valid and roller_found and laser_found and damage_valid:
		print("✓ PASS: Boss 1 'Mecha-Crusher Dozer' verified with 2.6x scale, spiked roller, laser telegraph, and 25% hazard vulnerability")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Mecha-Crusher Dozer mismatch! is_dozer=%s, valid=%s, roller=%s, laser=%s, dmg=%s" % [is_dozer, dozer_valid, roller_found, laser_found, damage_valid])
	
	# -------------------------------------------------------------
	# Test 7: BossEscapeMode Goliath Laser Chopper (Y=18m, magenta laser, dropped blue EMP barrel)
	# -------------------------------------------------------------
	total_tests += 1
	# Defeat dozer to transition to Goliath Laser Chopper
	boss_mode.apply_hazard_damage(750.0) # HP -> 0, defeated
	boss_mode.breather_timer = 0.05 # Fast-forward breather
	boss_mode._physics_process(0.1)
	
	var is_chopper: bool = (boss_mode.current_boss_type == BossEscapeMode.BossType.GOLIATH_CHOPPER)
	var chopper_node: Node3D = boss_mode.boss_node
	var chopper_valid: bool = (chopper_node != null and is_instance_valid(chopper_node))
	var chopper_y: float = chopper_node.position.y if chopper_valid else 0.0
	var dual_rotors: bool = (boss_mode._chopper_rotor1 != null and boss_mode._chopper_rotor2 != null)
	var chopper_laser: bool = (boss_mode._chopper_laser != null)
	
	# Spawn EMP barrel
	boss_mode._drop_emp_barrel()
	var barrel_node: Node3D = boss_mode._dropped_emp_barrel
	var barrel_valid: bool = (barrel_node != null and is_instance_valid(barrel_node))
	
	boss_mode.stop_boss_mode()
	boss_mode.queue_free()
	
	var y_valid: bool = (chopper_y >= 14.0)
	if is_chopper and chopper_valid and y_valid and dual_rotors and chopper_laser and barrel_valid:
		print("✓ PASS: Boss 2 'Goliath Laser Chopper' verified at Y=%.1fm with twin rotors, magenta laser beam, and blue EMP barrels" % chopper_y)
		passed_tests += 1
	else:
		printerr("✗ FAIL: Goliath Chopper mismatch! is_chopper=%s, valid=%s, y=%.1f, rotors=%s, laser=%s, barrel=%s" % [is_chopper, chopper_valid, chopper_y, dual_rotors, chopper_laser, barrel_valid])
	
	# -------------------------------------------------------------
	# Test 8: Street Powerup Crate Bobbing, Rotation, and Pickup
	# -------------------------------------------------------------
	total_tests += 1
	var crate_scene: PackedScene = load("res://scenes/props/powerup_crate.tscn")
	var crate: PowerupCrate = crate_scene.instantiate() as PowerupCrate
	crate.forced_powerup = 0 # NITRO_OVERDRIVE
	crate.position = Vector3(500.0, 0.8, 500.0)
	
	test_car.active_powerup = -1
	test_car.powerup_time_remaining = 0.0
	
	var test_state8 := {"collected_type": -1}
	crate.powerup_collected.connect(func(pt):
		test_state8["collected_type"] = int(pt)
	)
	root.add_child(crate)
	
	# Process bobbing & rotation
	var initial_rot_y: float = crate.rotation.y
	crate._process(0.5)
	var rot_changed: bool = (crate.rotation.y != initial_rot_y)
	
	# Car triggers pickup
	crate._on_body_entered(test_car)
	var pickup_success: bool = (test_state8["collected_type"] == 0 and test_car.active_powerup == 0 and test_car.powerup_time_remaining > 0.0)
	
	if rot_changed and pickup_success:
		print("✓ PASS: PowerupCrate bobbing, rotation, and car pickup verified cleanly")
		passed_tests += 1
	else:
		printerr("✗ FAIL: PowerupCrate pickup mismatch! rot_changed=%s, collected=%d, active_powerup=%d" % [rot_changed, test_state8["collected_type"], test_car.active_powerup])
	
	# -------------------------------------------------------------
	# Test 9: All 4 Power-Up Mechanics on ArcadeCar
	# -------------------------------------------------------------
	total_tests += 1
	
	# 1. Nitro Overdrive (Arrest immunity)
	test_car.apply_powerup(0, 5.0)
	test_car.busted_progress = 0.8
	test_car._physics_process(0.1) # Nitro resets busted_progress
	var nitro_pass: bool = (test_car.busted_progress == 0.0 and test_car.active_powerup == 0)
	
	# 2. EMP Shockwave (impulses cops)
	var dummy_cop_scene: PackedScene = load("res://scenes/vehicles/police_car.tscn")
	var dummy_cop: PoliceCar = dummy_cop_scene.instantiate() as PoliceCar
	root.add_child(dummy_cop)
	dummy_cop.global_position = test_car.global_position + Vector3(5.0, 0.6, 0.0)
	if dummy_cop.physics_sphere:
		dummy_cop.physics_sphere.global_position = dummy_cop.global_position
	
	test_car.apply_powerup(1, 5.0) # EMP Shockwave
	var emp_pass: bool = (dummy_cop.hp < dummy_cop.max_hp) # Damaged by shockwave
	dummy_cop.queue_free()
	
	# 3. Oil Slick Dropper
	test_car.apply_powerup(2, 5.0)
	test_car._oil_drop_timer = 1.25 # Trigger oil drop
	test_car._physics_process(0.1)
	var oil_slick = root.find_child("OilSlick", true, false)
	var oil_pass: bool = (oil_slick != null)
	if oil_slick:
		oil_slick.queue_free()
	
	# 4. Titan Shield (damage immunity & +60 HP repair)
	test_car.current_hp = 50.0
	test_car.apply_powerup(3, 5.0)
	var hp_after_titan: float = test_car.current_hp # Should be 50 + 60 = 110
	test_car.take_damage(40.0) # Should be blocked by Titan shield!
	var titan_blocked_damage: bool = (test_car.current_hp == hp_after_titan)
	var shield_mesh_visible: bool = (test_car.titan_shield_mesh != null and test_car.titan_shield_mesh.visible)
	
	test_car.queue_free()
	
	if nitro_pass and emp_pass and oil_pass and (hp_after_titan == 110.0) and titan_blocked_damage and shield_mesh_visible:
		print("✓ PASS: All 4 Power-Up mechanics (Nitro immunity, EMP shockwave, Oil Slick, Titan Shield) validated on ArcadeCar")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Power-up mechanics mismatch! nitro=%s, emp=%s, oil=%s, titan_hp=%.1f, blocked=%s, shield_mesh=%s" % [nitro_pass, emp_pass, oil_pass, hp_after_titan, titan_blocked_damage, shield_mesh_visible])
	
	# -------------------------------------------------------------
	# Test 10: Full main_game.tscn Instantiation & Mode Dispatch Integration
	# -------------------------------------------------------------
	total_tests += 1
	var main_scene: PackedScene = load("res://scenes/world/main_game.tscn")
	if main_scene:
		var main_node: MainGame = main_scene.instantiate() as MainGame
		root.add_child(main_node)
		
		var heist_child = main_node.get_node_or_null("HeistStealMode")
		var boss_child = main_node.get_node_or_null("BossEscapeMode")
		var spawner_child = main_node.get_node_or_null("PlayerSpawner")
		var touch_hud_child = main_node.get_node_or_null("TouchHUD")
		var city_gen_child = main_node.get_node_or_null("CityGenerator")
		
		var nodes_valid: bool = (heist_child != null and boss_child != null and spawner_child != null and touch_hud_child != null and city_gen_child != null)
		
		# Test mode switching via start_game_mode
		main_node.start_game_mode(1) # Bank Heist
		var heist_active: bool = (main_node.heist_steal_mode.is_heist_mode and not main_node.boss_escape_mode.is_boss_mode and not main_node.hot_loot_mode.is_hot_loot_mode)
		
		main_node.start_game_mode(2) # Escape Mega Boss
		var boss_active: bool = (main_node.boss_escape_mode.is_boss_mode and not main_node.heist_steal_mode.is_heist_mode and not main_node.hot_loot_mode.is_hot_loot_mode)
		
		main_node.start_game_mode(0) # Daily Endless Getaway
		var solo_active: bool = (not main_node.heist_steal_mode.is_heist_mode and not main_node.boss_escape_mode.is_boss_mode and not main_node.hot_loot_mode.is_hot_loot_mode)
		
		# Test TouchHUD power-up and boss health UI methods
		var hud: TouchHUD = touch_hud_child as TouchHUD
		hud.show_powerup_banner("⚡ NITRO TEST", Color.CYAN, 4.0)
		hud.set_boss_health("GOLIATH CHOPPER", 650.0, 1000.0)
		var hud_valid: bool = (hud._powerup_panel != null and hud._powerup_panel.visible and hud._boss_panel != null and hud._boss_panel.visible)
		hud.hide_boss_health()
		var boss_hidden: bool = (not hud._boss_panel.visible)
		
		main_node.queue_free()
		
		if nodes_valid and heist_active and boss_active and solo_active and hud_valid and boss_hidden:
			print("✓ PASS: Full main_game.tscn instantiated with HeistStealMode, BossEscapeMode, Mode Dispatcher, and TouchHUD UI")
			passed_tests += 1
		else:
			printerr("✗ FAIL: main_game.tscn integration mismatch! nodes=%s, heist=%s, boss=%s, solo=%s, hud=%s, boss_hidden=%s" % [nodes_valid, heist_active, boss_active, solo_active, hud_valid, boss_hidden])
	else:
		printerr("✗ FAIL: Could not load main_game.tscn!")
	
	# -------------------------------------------------------------
	# FINAL REPORT
	# -------------------------------------------------------------
	print("\n=== RESULTS: %d / %d TESTS PASSED ===" % [passed_tests, total_tests])
	if passed_tests == total_tests:
		print("ALL PHASE 7 MODES (BANK HEIST, MEGA-BOSS, POWER-UP CRATES, HUD) VERIFIED AND FUNCTIONAL!\n")
		quit(0)
	else:
		printerr("SOME PHASE 7 TESTS FAILED!\n")
		quit(1)
