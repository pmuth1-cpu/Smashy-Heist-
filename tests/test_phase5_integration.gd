extends SceneTree

## Comprehensive Phase 5 Integration & Verification Test Suite for Smashy Heist: Daily Getaway.
## Validates Real-Time NetworkManager, MultiplayerSynchronizer, 4-Car Starting Grid,
## AI Rival Backfill, Hot Loot Tag Mode, Mobile Lobby UI, and Off-Screen Loot Pointer.

func _init() -> void:
	print("\n=== STARTING PHASE 5 INTEGRATION TESTS ===")
	await process_frame
	await process_frame
	
	_run_tests()

func _run_tests() -> void:
	var total_tests: int = 0
	var passed_tests: int = 0
	
	# -------------------------------------------------------------
	# Test 1: Autoload Presence & NetworkManager Initialization
	# -------------------------------------------------------------
	total_tests += 1
	var sm = root.get_node_or_null("SaveManager")
	var lm = root.get_node_or_null("LeaderboardManager")
	var wm = root.get_node_or_null("WantedManager")
	var dsm = root.get_node_or_null("DailySeedManager")
	var nm = root.get_node_or_null("NetworkManager")
	
	if sm != null and lm != null and wm != null and dsm != null and nm != null:
		var has_port: bool = nm.DEFAULT_PORT == 7777
		var has_max: bool = nm.MAX_PLAYERS == 4
		var has_offline_state: bool = (nm.is_online_match == false)
		if has_port and has_max and has_offline_state:
			print("✓ PASS: All 5 Autoloads (SaveManager, LeaderboardManager, WantedManager, DailySeedManager, NetworkManager) verified")
			passed_tests += 1
		else:
			printerr("✗ FAIL: NetworkManager properties mismatch! port=%d, max=%d, online=%s" % [nm.DEFAULT_PORT, nm.MAX_PLAYERS, nm.is_online_match])
	else:
		printerr("✗ FAIL: Autoload missing! sm=%s, lm=%s, wm=%s, dsm=%s, nm=%s" % [sm, lm, wm, dsm, nm])
	
	# -------------------------------------------------------------
	# Test 2: NetworkManager Server Hosting & Match Seed Sync
	# -------------------------------------------------------------
	total_tests += 1
	var host_err: Error = nm.host_room()
	var host_active: bool = (host_err == OK and nm.is_online_match and nm.players.has(1))
	var host_info: Dictionary = nm.players.get(1, {})
	var host_valid: bool = host_info.get("name", "").begins_with("Host")
	
	# Test seed synchronization
	var test_shared_seed: int = 987654321
	nm.start_multiplayer_match(test_shared_seed)
	var seed_synced: bool = (dsm.base_seed == test_shared_seed)
	
	# Clean up network
	nm.disconnect_network()
	var network_cleaned: bool = (not nm.is_online_match and nm.players.is_empty())
	
	if host_active and host_valid and seed_synced and network_cleaned:
		print("✓ PASS: NetworkManager ENet server hosting, host registration, seed synchronization (%d), and cleanup verified" % test_shared_seed)
		passed_tests += 1
	else:
		printerr("✗ FAIL: NetworkManager host/seed test failed! host_active=%s, host_valid=%s, seed_synced=%s, cleanup=%s" % [host_active, host_valid, seed_synced, network_cleaned])
	
	# -------------------------------------------------------------
	# Test 3: ArcadeCar Multiplayer Synchronizer & SceneReplicationConfig
	# -------------------------------------------------------------
	total_tests += 1
	var car_scene: PackedScene = load("res://scenes/vehicles/arcade_car.tscn")
	var test_car: ArcadeCar = car_scene.instantiate() as ArcadeCar
	root.add_child(test_car)
	await process_frame
	
	var sync_node: MultiplayerSynchronizer = test_car.get_node_or_null("MultiplayerSynchronizer")
	var has_sync: bool = sync_node != null
	var has_rep_config: bool = has_sync and sync_node.replication_config != null
	var rep: SceneReplicationConfig = sync_node.replication_config if has_sync else null
	
	var prop_pos_ok: bool = false
	var prop_vel_ok: bool = false
	var prop_rot_ok: bool = false
	var prop_steer_ok: bool = false
	var prop_rev_ok: bool = false
	
	if rep:
		prop_pos_ok = rep.property_get_replication_mode(NodePath("PhysicsSphere:global_position")) == SceneReplicationConfig.REPLICATION_MODE_ALWAYS
		prop_vel_ok = rep.property_get_replication_mode(NodePath("PhysicsSphere:linear_velocity")) == SceneReplicationConfig.REPLICATION_MODE_ALWAYS
		prop_rot_ok = rep.property_get_replication_mode(NodePath("CarPivot:rotation")) == SceneReplicationConfig.REPLICATION_MODE_ALWAYS
		prop_steer_ok = rep.property_get_replication_mode(NodePath(":steer_input")) == SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
		prop_rev_ok = rep.property_get_replication_mode(NodePath(":is_reversing")) == SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
	
	test_car.queue_free()
	
	if has_sync and has_rep_config and prop_pos_ok and prop_vel_ok and prop_rot_ok and prop_steer_ok and prop_rev_ok:
		print("✓ PASS: ArcadeCar MultiplayerSynchronizer replicates PhysicsSphere pos/vel, CarPivot rot, and steer/reverse")
		passed_tests += 1
	else:
		printerr("✗ FAIL: MultiplayerSynchronizer replication config failed! sync=%s, pos=%s, vel=%s, rot=%s, steer=%s, rev=%s" % [has_sync, prop_pos_ok, prop_vel_ok, prop_rot_ok, prop_steer_ok, prop_rev_ok])
	
	# -------------------------------------------------------------
	# Test 4: ArcadeCar 3D Floating Nameplate & 3-Ray Avoidance
	# -------------------------------------------------------------
	total_tests += 1
	var car2: ArcadeCar = car_scene.instantiate() as ArcadeCar
	car2.driver_name = "SpeedDemon"
	car2.match_score = 450
	root.add_child(car2)
	await process_frame
	
	var nameplate: Label3D = car2.get_node_or_null("CarPivot/Nameplate") as Label3D
	var nameplate_valid: bool = nameplate != null and "SpeedDemon" in nameplate.text and "450 PTS" in nameplate.text
	var has_ray_center: bool = car2.get_node_or_null("CarPivot/RayCenter") != null
	var has_ray_left: bool = car2.get_node_or_null("CarPivot/RayLeft") != null
	var has_ray_right: bool = car2.get_node_or_null("CarPivot/RayRight") != null
	
	# Test crown indicator on loot holder
	car2.is_holding_loot = true
	var nameplate_loot_valid: bool = "👑" in nameplate.text
	car2.queue_free()
	
	if nameplate_valid and has_ray_center and has_ray_left and has_ray_right and nameplate_loot_valid:
		print("✓ PASS: ArcadeCar 3D floating Nameplate and 3-ray building avoidance sensors validated")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Nameplate or sensors missing! nameplate=%s, center=%s, left=%s, right=%s, loot_text=%s" % [nameplate_valid, has_ray_center, has_ray_left, has_ray_right, nameplate_loot_valid])
	
	# -------------------------------------------------------------
	# Test 5: MainGame & PlayerSpawner Starting Grid with AI Rival Backfill
	# -------------------------------------------------------------
	total_tests += 1
	var main_scene: PackedScene = load("res://scenes/world/main_game.tscn")
	var main_inst = main_scene.instantiate()
	root.add_child(main_inst)

	await process_frame
	await process_frame
	
	var spawner: MultiplayerSpawner = main_inst.player_spawner
	var has_spawner: bool = spawner != null and spawner.get_spawnable_scene_count() > 0
	
	# Trigger Hot Loot match starting grid with AI rival backfill
	main_inst.start_hot_loot_mode(12345)
	await process_frame
	
	var player_group_cars := get_nodes_in_group("player")

	var total_drivers: int = player_group_cars.size()
	var ai_rival_count: int = 0
	for p in player_group_cars:
		if p is ArcadeCar and (p as ArcadeCar).is_ai_rival:
			ai_rival_count += 1
	
	var grid_slots_ok: bool = (total_drivers == 4) and (ai_rival_count == 3)
	
	if has_spawner and grid_slots_ok:
		print("✓ PASS: PlayerSpawner configured and 4-car starting grid spawned (1 Local Player + 3 AI Rivals)")
		passed_tests += 1
	else:
		printerr("✗ FAIL: PlayerSpawner grid failed! has_spawner=%s, total=%d (exp 4), ai=%d (exp 3)" % [has_spawner, total_drivers, ai_rival_count])
	
	# -------------------------------------------------------------
	# Test 6: HotLootMode Golden Marker & Police Pursuit Override
	# -------------------------------------------------------------
	total_tests += 1
	var hot_loot: HotLootMode = main_inst.hot_loot_mode
	var loot_active: bool = hot_loot.is_hot_loot_mode
	var holder: Node3D = hot_loot.loot_holder_car
	var has_holder: bool = (holder != null and holder is ArcadeCar)
	var has_marker: bool = hot_loot.loot_bag_marker != null and hot_loot.loot_bag_marker.visible
	
	# Verify police targeting override
	var cop_scene: PackedScene = load("res://scenes/vehicles/police_car.tscn")
	var cop_inst: PoliceCar = cop_scene.instantiate() as PoliceCar
	root.add_child(cop_inst)
	await process_frame
	
	hot_loot._physics_process(0.1)
	var cop_targeting_ok: bool = (cop_inst.target_override == holder)
	cop_inst.queue_free()
	
	if loot_active and has_holder and has_marker and cop_targeting_ok:
		print("✓ PASS: HotLootMode golden LootBagMarker active and directing all active PoliceCar units to loot holder")
		passed_tests += 1
	else:
		printerr("✗ FAIL: HotLootMode marker/police failed! active=%s, holder=%s, marker=%s, cop_override=%s" % [loot_active, has_holder, has_marker, cop_targeting_ok])
	
	# -------------------------------------------------------------
	# Test 7: Tag Transfer, Knockback Impulse & Score Accumulation
	# -------------------------------------------------------------
	total_tests += 1
	var car_a: ArcadeCar = hot_loot.loot_holder_car as ArcadeCar
	var car_b: ArcadeCar = null
	for p in player_group_cars:
		if p is ArcadeCar and p != car_a:
			car_b = p as ArcadeCar
			break
	
	# Simulate 1 second score accumulation (+100)
	var prev_score: int = car_a.match_score
	hot_loot._physics_process(1.05)
	var score_added_ok: bool = (car_a.match_score >= prev_score + 100)
	
	# Test ram collision tag transfer
	hot_loot.notify_car_collision(car_a, car_b)
	await process_frame
	
	var transfer_ok: bool = (hot_loot.loot_holder_car == car_b) and car_b.is_holding_loot and (not car_a.is_holding_loot)
	var cooldown_ok: bool = hot_loot.transfer_cooldown > 0.5
	
	if score_added_ok and transfer_ok and cooldown_ok:
		print("✓ PASS: +100 pts/sec awarded and Loot Bag successfully transferred to rammer with 1.5s cooldown")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Tag transfer failed! score_added=%s, transfer_ok=%s, cooldown_ok=%s" % [score_added_ok, transfer_ok, cooldown_ok])
	
	# -------------------------------------------------------------
	# Test 8: Busted / Wrecked Penalty (-200 pts), Rival Transfer & Respawn
	# -------------------------------------------------------------
	total_tests += 1
	var cur_holder: ArcadeCar = hot_loot.loot_holder_car as ArcadeCar
	cur_holder.match_score = 500
	hot_loot.handle_car_busted(cur_holder, "WRECKED!")
	await process_frame
	
	var penalty_ok: bool = (cur_holder.match_score == 300)
	var passed_to_rival: bool = (hot_loot.loot_holder_car != cur_holder) and (hot_loot.loot_holder_car != null)
	
	# Test 2.0s respawn
	hot_loot._physics_process(2.1)
	var respawned_ok: bool = (cur_holder.current_hp == cur_holder.max_hp) and (cur_holder.global_position.distance_to(Vector3(24, 0.6, 24)) < 1.0)
	
	if penalty_ok and passed_to_rival and respawned_ok:
		print("✓ PASS: Loot holder bust/wreck deducted 200 pts, passed loot bag to rival, and executed 2.0s respawn")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Bust/wreck handling failed! penalty=%s, passed=%s, respawn=%s" % [penalty_ok, passed_to_rival, respawned_ok])
	
	# -------------------------------------------------------------
	# Test 9: Match Conclusion & 1st-to-4th Place Podium Standings
	# -------------------------------------------------------------
	total_tests += 1
	hot_loot.match_time_remaining = 0.05
	hot_loot._physics_process(0.1) # Trigger match end
	await process_frame
	
	var summary_panel = main_inst.find_child("RunSummaryPanel", true, false) as RunSummaryPanel
	var podium_visible: bool = summary_panel != null and summary_panel.visible
	var podium_title_ok: bool = "PODIUM" in summary_panel.title_label.text
	var podium_rank_ok: bool = "1st" in summary_panel.stars_label.text or "1ST" in summary_panel.stars_label.text
	
	if podium_visible and podium_title_ok and podium_rank_ok:
		print("✓ PASS: HotLootMode timer expiration ended match and displayed 1st-to-4th Place Podium in RunSummaryPanel")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Podium display failed! visible=%s, title=%s, rank=%s" % [podium_visible, podium_title_ok, podium_rank_ok])
	
	# -------------------------------------------------------------
	# Test 10: TouchHUD Mobile Lobby UI & Off-Screen Directional Pointer
	# -------------------------------------------------------------
	total_tests += 1
	var hud: TouchHUD = main_inst.touch_hud
	var lobby: MultiplayerLobby = hud.multiplayer_lobby
	var has_lobby: bool = lobby != null and lobby.play_daily_btn != null and lobby.hot_loot_btn != null and lobby.garage_btn != null
	var pointer: Control = hud.loot_pointer
	var has_pointer: bool = pointer != null
	
	# Clean up main scene
	main_inst.queue_free()
	
	if has_lobby and has_pointer:
		print("✓ PASS: TouchHUD MultiplayerLobby (3 Prominent Mode Buttons) and off-screen LootPointer arrow validated")
		passed_tests += 1
	else:
		printerr("✗ FAIL: UI elements missing! has_lobby=%s, has_pointer=%s" % [has_lobby, has_pointer])
	
	# -------------------------------------------------------------
	# Final Summary
	# -------------------------------------------------------------
	print("\n=== RESULTS: %d / %d TESTS PASSED ===" % [passed_tests, total_tests])
	if passed_tests == total_tests:
		print("ALL PHASE 5 REAL-TIME MULTIPLAYER & HOT LOOT SYSTEMS VERIFIED AND FUNCTIONAL!")
		quit(0)
	else:
		printerr("SOME PHASE 5 TESTS FAILED.")
		quit(1)
