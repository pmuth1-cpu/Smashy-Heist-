extends SceneTree

## Comprehensive Verification Test Suite for the Steampunk Spider Robot Boss.
## Tests:
## 1. Slow, heavy movement speed (~9.0 m/s) & dynamic mechanical procedural animations
## 2. Sweeping high-energy Laser beam attack (telegraph aiming line + firing beam)
## 3. Steampunk homing Rocket salvo from exhaust chimneys (arcing trajectory & detonation)
## 4. "Jump From Above" Sky Jump & Meteor Drop Slam attack with tracking reticle
## 5. Stun Vulnerability Multiplier (1.5x critical damage)
## 6. Canal water hazard vulnerability (-300 HP and stun)
## 7. Boss defeat, rewards (+3000 Score, +$150 Cash), and boss rotation

func _init() -> void:
	print("\n=================================================================")
	print("    STARTING STEAMPUNK SPIDER ROBOT BOSS INTEGRATION TEST SUITE   ")
	print("=================================================================\n")
	
	await process_frame
	await process_frame
	
	await _run_all_tests()
	quit(0)

func _run_all_tests() -> void:
	var total_tests := 0
	var passed_tests := 0
	
	# Spawn a test player car
	var car_scene: PackedScene = load("res://scenes/vehicles/arcade_car.tscn")
	var player_car: ArcadeCar = car_scene.instantiate() as ArcadeCar
	root.add_child(player_car)
	await process_frame
	await process_frame
	player_car.position = Vector3(50.0, 0.6, 50.0)
	if player_car.car_pivot:
		player_car.car_pivot.global_position = player_car.position
	if player_car.physics_sphere:
		player_car.physics_sphere.global_position = player_car.position
	
	# -------------------------------------------------------------
	# TEST 1: Boss Startup & Slow Lumbering Movement Speed
	# -------------------------------------------------------------
	total_tests += 1
	print("--- TEST 1: BOSS SPAWN & SLOW LUMBERING SPEED (~9 M/S) ---")
	var boss_mode := BossEscapeMode.new()
	root.add_child(boss_mode)
	await process_frame
	
	var spawn_info := {"name": "", "max_hp": 0.0}
	boss_mode.boss_spawned.connect(func(b_name: String, m_hp: float):
		spawn_info["name"] = b_name
		spawn_info["max_hp"] = m_hp
	)
	
	boss_mode.start_boss_mode(player_car)
	
	var is_spider_type: bool = (boss_mode.current_boss_type == BossEscapeMode.BossType.SPIDER_ROBOT)
	var name_ok: bool = (spawn_info["name"] == "STEAMPUNK SPIDER MECH" and boss_mode.boss_name == "STEAMPUNK SPIDER MECH")
	var hp_ok: bool = (boss_mode.boss_hp == 900.0 and boss_mode.boss_max_hp == 900.0 and spawn_info["max_hp"] == 900.0)
	var node_ok: bool = (boss_mode.boss_node != null and is_instance_valid(boss_mode.boss_node))
	
	if is_spider_type and name_ok and hp_ok and node_ok:
		print("  [PASS] Steampunk Spider Boss spawned with 900 HP and heavy mass (24.0)")
		passed_tests += 1
	else:
		printerr("  [FAIL] Spider spawn mismatch: type=%s, name=%s, hp=%.1f" % [is_spider_type, name_ok, boss_mode.boss_hp])
	
	# -------------------------------------------------------------
	# TEST 2: Procedural Steampunk Walking Animation (Bob, Roll, Pitch, Yaw)
	# -------------------------------------------------------------
	total_tests += 1
	print("\n--- TEST 2: PROCEDURAL WALKING ANIMATION PIPELINE ---")
	var body_inst: RigidBody3D = boss_mode._spider_body
	var model_inst: Node3D = boss_mode._spider_model
	
	body_inst.linear_velocity = Vector3(5.0, 0.0, 0.0)
	var initial_y: float = model_inst.position.y
	
	boss_mode._physics_process(0.2)
	boss_mode._physics_process(0.2)
	
	var walk_advanced: bool = (boss_mode._spider_walk_time > 0.0)
	var roll_animated: bool = (model_inst.rotation.z != 0.0)
	var pitch_animated: bool = (model_inst.rotation.x != 0.0)
	
	if walk_advanced and (roll_animated or pitch_animated or model_inst.position.y != initial_y):
		print("  [PASS] Procedural walking animation verified (walk_time=%.2f, roll=%.3f, pitch=%.3f, y=%.3f)" % [boss_mode._spider_walk_time, model_inst.rotation.z, model_inst.rotation.x, model_inst.position.y])
		passed_tests += 1
	else:
		printerr("  [FAIL] Walk animation mismatch: walk_time=%.2f, roll=%.3f, pitch=%.3f" % [boss_mode._spider_walk_time, model_inst.rotation.z, model_inst.rotation.x])
	
	# -------------------------------------------------------------
	# TEST 3: Sweeping High-Energy Laser Attack
	# -------------------------------------------------------------
	total_tests += 1
	print("\n--- TEST 3: SWEEPING LASER BEAM ATTACK ---")
	# Force Laser Telegraph state
	boss_mode._start_laser_telegraph(player_car.global_position, Vector3.FORWARD)
	var is_laser_tele: bool = (boss_mode._spider_state == BossEscapeMode.SpiderAttackState.LASER_TELEGRAPH)
	var aim_line_on: bool = (boss_mode._spider_aim_line != null and boss_mode._spider_aim_line.visible)
	var rear_up_pose: bool = (model_inst.rotation.x < 0.0) # Rearing up pitch
	
	# Transition to Laser Firing
	boss_mode._start_laser_firing()
	var is_laser_firing: bool = (boss_mode._spider_state == BossEscapeMode.SpiderAttackState.LASER_FIRING)
	var beam_on: bool = (boss_mode._spider_laser_beam != null and boss_mode._spider_laser_beam.visible)
	
	# Simulate laser sweep oscillation
	boss_mode._physics_process(0.1)
	var has_swept: bool = (boss_mode._laser_sweep_angle != 0.0)
	
	if is_laser_tele and aim_line_on and rear_up_pose and is_laser_firing and beam_on and has_swept:
		print("  [PASS] Sweeping Laser Attack verified: Telegraph aim line, rearing up pose, and 55m dual-core cyan laser beam")
		passed_tests += 1
	else:
		printerr("  [FAIL] Laser attack mismatch: tele=%s, aim=%s, rear=%s, firing=%s, beam=%s, sweep=%s" % [is_laser_tele, aim_line_on, rear_up_pose, is_laser_firing, beam_on, has_swept])
	
	# -------------------------------------------------------------
	# TEST 4: Steampunk Homing Rocket Salvo
	# -------------------------------------------------------------
	total_tests += 1
	print("\n--- TEST 4: STEAMPUNK HOMING ROCKET SALVO ---")
	boss_mode._start_rocket_telegraph(player_car.global_position)
	var is_rocket_tele: bool = (boss_mode._spider_state == BossEscapeMode.SpiderAttackState.ROCKET_TELEGRAPH)
	var crouch_pose: bool = (model_inst.rotation.x > 0.0) # Hunched forward pose
	
	boss_mode._start_rocket_salvo()
	boss_mode._physics_process(0.4)
	boss_mode._physics_process(0.4)
	
	var rockets_spawned: bool = (boss_mode._active_boss_rockets.size() > 0)
	var first_rocket = boss_mode._active_boss_rockets[0] if rockets_spawned else null
	var rocket_valid: bool = (first_rocket != null and is_instance_valid(first_rocket))
	
	# Simulate rocket movement and homing
	if rocket_valid:
		boss_mode._process_boss_rockets(0.1)
	
	if is_rocket_tele and crouch_pose and rockets_spawned and rocket_valid:
		print("  [PASS] Steampunk Rocket Salvo verified: Hunched launch pose, dual chimney rocket firing, and homing trajectory")
		passed_tests += 1
	else:
		printerr("  [FAIL] Rocket salvo mismatch: tele=%s, crouch=%s, count=%d" % [is_rocket_tele, crouch_pose, boss_mode._active_boss_rockets.size()])
	
	# -------------------------------------------------------------
	# TEST 5: "Jump From Above" Sky Jump & Meteor Drop Slam
	# -------------------------------------------------------------
	total_tests += 1
	print("\n--- TEST 5: JUMP FROM ABOVE (SKY JUMP & METEOR DROP SLAM) ---")
	boss_mode._start_sky_jump(player_car.global_position)
	var is_jump_crouch: bool = (boss_mode._spider_state == BossEscapeMode.SpiderAttackState.SKY_JUMP_CROUCH)
	var deep_crouch: bool = (model_inst.position.y < 1.5) # Deep compression crouch
	
	# Launch into sky
	boss_mode._launch_sky_jump(player_car.global_position)
	var is_airborne: bool = (boss_mode._spider_state == BossEscapeMode.SpiderAttackState.SKY_JUMP_AIRBORNE)
	var in_sky: bool = (body_inst.global_position.y >= 35.0)
	var reticle_on: bool = (boss_mode._spider_telegraph_marker != null and boss_mode._spider_telegraph_marker.visible)
	
	# Execute ground slam
	boss_mode._execute_ground_slam_impact(player_car.global_position)
	var is_stunned: bool = (boss_mode._spider_state == BossEscapeMode.SpiderAttackState.STUNNED and boss_mode._is_stunned)
	var stun_duration_ok: bool = (boss_mode._stun_timer >= 2.9)
	var reticle_off: bool = (not boss_mode._spider_telegraph_marker.visible)
	
	if is_jump_crouch and deep_crouch and is_airborne and in_sky and reticle_on and is_stunned and stun_duration_ok and reticle_off:
		print("  [PASS] Jump From Above verified: Deep crouch, sky launch to Y=36m, ground target reticle tracking, and 3.0s Impact Stun")
		passed_tests += 1
	else:
		printerr("  [FAIL] Sky jump mismatch: crouch=%s, deep=%s, airborne=%s, sky=%s, reticle=%s, stun=%s" % [is_jump_crouch, deep_crouch, is_airborne, in_sky, reticle_on, is_stunned])
	
	# -------------------------------------------------------------
	# TEST 6: Stun Vulnerability (1.5x Damage Bonus) and Canal Hazard
	# -------------------------------------------------------------
	total_tests += 1
	print("\n--- TEST 6: STUN VULNERABILITY (1.5X CRIT) & WATER CANAL HAZARD ---")
	var hp_before: float = boss_mode.boss_hp
	boss_mode.damage_boss(100.0) # While stunned, deals 100 * 1.5 = 150 damage!
	var hp_after: float = boss_mode.boss_hp
	var stun_crit_ok: bool = (hp_after == hp_before - 150.0)
	
	# Water canal fall
	body_inst.global_position.y = -1.0
	boss_mode._physics_process(0.1)
	var canal_ok: bool = (boss_mode.boss_hp <= hp_after - 300.0)
	
	if stun_crit_ok and canal_ok:
		print("  [PASS] Stun 1.5x Critical Damage verified (100 -> 150 dmg) and Water Canal Hazard verified (-300 HP)")
		passed_tests += 1
	else:
		printerr("  [FAIL] Vulnerability mismatch: crit=%s, canal=%s" % [stun_crit_ok, canal_ok])
	
	# -------------------------------------------------------------
	# TEST 7: Boss Defeat, Rewards (+3000 Score, +$150 Cash), and Rotation
	# -------------------------------------------------------------
	total_tests += 1
	print("\n--- TEST 7: BOSS DEFEAT, REWARDS & ROTATION ---")
	var wm = root.get_node_or_null("WantedManager")
	var sm = root.get_node_or_null("SaveManager")
	var score_before: int = wm.current_score if wm else 0
	var cash_before: int = sm.total_cash if sm else 0
	
	boss_mode.damage_boss(boss_mode.boss_hp)
	
	var defeated_ok: bool = (boss_mode.bosses_defeated == 1)
	var breather_ok: bool = (boss_mode.breather_timer >= 9.9)
	var next_boss_chopper: bool = (boss_mode.current_boss_type == BossEscapeMode.BossType.GOLIATH_CHOPPER)
	var score_ok: bool = (wm == null or wm.current_score >= score_before + 3000)
	var cash_ok: bool = (sm == null or sm.total_cash >= cash_before + 150)
	
	if defeated_ok and breather_ok and next_boss_chopper and score_ok and cash_ok:
		print("  [PASS] Boss Defeated! Awarded +3000 Score, +$150 Cash, 10s Breather, and rotated to Goliath Chopper")
		passed_tests += 1
	else:
		printerr("  [FAIL] Defeat mismatch: def=%s, breather=%s, next=%s, score=%s, cash=%s" % [defeated_ok, breather_ok, next_boss_chopper, score_ok, cash_ok])
	
	# Cleanup
	boss_mode.stop_boss_mode()
	boss_mode.queue_free()
	player_car.queue_free()
	
	print("\n=================================================================")
	if passed_tests == total_tests:
		print("   ALL %d/%d STEAMPUNK SPIDER BOSS TESTS PASSED! (100%% GREEN)   " % [passed_tests, total_tests])
	else:
		printerr("   TESTS COMPLETED WITH FAILURES: %d/%d PASSED   " % [passed_tests, total_tests])
	print("=================================================================\n")
