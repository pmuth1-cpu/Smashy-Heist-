extends SceneTree

const ArcadeCarScene = preload("res://scenes/vehicles/arcade_car.tscn")
const PlayerCharScene = preload("res://scenes/characters/player_character.tscn")
const NPCTrafficCarScene = preload("res://scenes/vehicles/npc_traffic_car.tscn")
const TouchHUDScene = preload("res://scenes/ui/touch_hud.tscn")
const VehicleDatabaseScript = preload("res://scripts/autoload/vehicle_database.gd")
const VoxelAssetBuilderScript = preload("res://scripts/autoload/voxel_asset_builder.gd")
const TrafficManagerClass = preload("res://scripts/world/traffic_manager.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("================================================================================")
	print("🧪 RUNNING TEST SUITE: 100-Car Traffic Spawns & Seamless Vehicle Ejection")
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
	# Ensure core autoload singletons are in tree for tests
	var vdb: Node = null
	if not root.has_node("VehicleDatabase"):
		vdb = VehicleDatabaseScript.new()
		vdb.name = "VehicleDatabase"
		root.add_child(vdb)
	
	var vab: Node = null
	if not root.has_node("VoxelAssetBuilder"):
		vab = VoxelAssetBuilderScript.new()
		vab.name = "VoxelAssetBuilder"
		root.add_child(vab)
	
	_test_car_ejection_mechanics()
	_test_npc_traffic_fleet_cars()
	_test_traffic_manager_tier_spawns()
	_test_traffic_car_hijack_and_gadget_inheritance()
	_test_touch_hud_ejection_and_hijack_integration()
	
	if vdb: vdb.queue_free()
	if vab: vab.queue_free()
	
	print("\n================================================================================")
	print("📊 RESULTS: %d/%d Passed (%d Failed)" % [passed_tests, total_tests, failed_tests])
	print("================================================================================\n")
	
	if failed_tests > 0:
		quit(1)
	else:
		quit(0)

func _test_car_ejection_mechanics() -> void:
	print("\n--- 1. Testing Car Ejection Mechanics ---")
	var car := ArcadeCarScene.instantiate() as ArcadeCar
	root.add_child(car)
	car.position = Vector3(10, 0.5, 10)
	
	assert_true(car.input_enabled, "Car input is enabled by default")
	assert_true(not car.is_abandoned, "Car is not abandoned initially")
	assert_true(car._eject_cooldown >= 0.0, "Car has _eject_cooldown property")
	
	# Simulate high speed drive (32 m/s)
	if car.physics_sphere:
		car.physics_sphere.linear_velocity = Vector3(0, 0, -32.0)
	
	# Eject player character at high speed
	var runner := car.eject_player_character()
	assert_true(runner != null, "Player character successfully ejected at 32 m/s high speed")
	assert_true(car.is_abandoned, "Car marked as abandoned after ejection")
	assert_true(not car.input_enabled, "Car input disabled after ejection")
	assert_true(car._eject_cooldown > 0.0, "Car _eject_cooldown reset on ejection")
	assert_true(runner is PlayerCharacter, "Ejected node is PlayerCharacter")
	assert_true(runner._eject_grace_timer > 0.0, "Runner has active _eject_grace_timer preventing instant re-entry")
	assert_true(runner.velocity.length() > 0.0, "Runner received outward/forward jump velocity")
	
	if is_instance_valid(runner): runner.queue_free()
	car.queue_free()

func _test_npc_traffic_fleet_cars() -> void:
	print("\n--- 2. Testing 100 Fleet Cars on NPCTrafficCar ---")
	var test_cars := [
		{"id": "default_coupe", "tier": "COMMON", "cat": "tuner"},
		{"id": "ice_cream_drifter", "tier": "RARE", "cat": "van"},
		{"id": "f1_street_kart", "tier": "EPIC", "cat": "kart"},
		{"id": "bat_vigilante_tank", "tier": "LEGENDARY", "cat": "heavy"},
		{"id": "fire_dragon", "tier": "MYTHIC", "cat": "hyper"}
	]
	
	for entry in test_cars:
		var cid: String = entry["id"]
		var npc := NPCTrafficCarScene.instantiate() as NPCTrafficCar
		npc.car_id = cid
		root.add_child(npc)
		
		assert_true(npc.car_id == cid, "NPC traffic car has car_id = %s" % cid)
		assert_true(npc.visual_model != null, "NPC traffic car built 3D voxel visual model for %s" % cid)
		assert_true(npc.visual_model.name == "VoxelCarVisual", "Visual model named VoxelCarVisual")
		assert_true(npc.mass > 0.0, "NPC car has valid physics mass (%s = %.1f kg)" % [cid, npc.mass])
		assert_true(npc.cruise_speed > 0.0, "NPC car has valid cruise speed (%s = %.1f m/s)" % [cid, npc.cruise_speed])
		
		if cid == "fire_dragon":
			assert_true(npc.npc_trail != null, "Mythic Fire Dragon NPC car has active particle trail attached")
		
		npc.queue_free()

func _test_traffic_manager_tier_spawns() -> void:
	print("\n--- 3. Testing TrafficManager Full Fleet Tier Spawning ---")
	var tm = TrafficManagerClass.new()
	root.add_child(tm)
	
	var dummy_player = Node3D.new()
	root.add_child(dummy_player)
	dummy_player.position = Vector3(100, 0, 100)
	tm.target_player = dummy_player
	
	# Spawn multiple traffic cars and check diversity
	var spawned_ids: Array[String] = []
	for i in range(12):
		tm._try_spawn_traffic_car(true)
	
	for c in tm._active_cars:
		if is_instance_valid(c) and c is NPCTrafficCar:
			if not (c as NPCTrafficCar).car_id.is_empty():
				spawned_ids.append((c as NPCTrafficCar).car_id)
	
	assert_true(spawned_ids.size() > 0, "TrafficManager spawned fleet cars with car_id (found %d cars)" % spawned_ids.size())
	print("    Sample road traffic fleet vehicles: %s" % str(spawned_ids.slice(0, 6)))
	
	dummy_player.queue_free()
	tm.queue_free()

func _test_traffic_car_hijack_and_gadget_inheritance() -> void:
	print("\n--- 4. Testing Traffic Fleet Car Hijack & Unique Gadget Inheritance ---")
	var runner := PlayerCharScene.instantiate() as PlayerCharacter
	root.add_child(runner)
	runner.position = Vector3(20, 0.2, 20)
	
	# Spawn a travelling Mythic Fire Dragon NPC car
	var npc := NPCTrafficCarScene.instantiate() as NPCTrafficCar
	npc.car_id = "fire_dragon"
	root.add_child(npc)
	npc.global_position = Vector3(21.2, 0.5, 20.0) # Close to runner
	
	# Process proximity scan
	runner._eject_grace_timer = 0.0
	runner._scan_for_hijack_targets()
	
	assert_true(runner._nearby_vehicle == npc, "Runner detected nearby travelling fleet car")
	assert_true("FIRE DRAGON" in runner._interaction_label.text, "Prompt shows real car name: '%s'" % runner._interaction_label.text)
	
	# Hijack the Fire Dragon!
	runner.hijack_vehicle(npc)
	
	# Find newly instantiated player ArcadeCar
	var new_car: ArcadeCar = null
	var cars := root.get_tree().get_nodes_in_group("player_vehicles")
	for c in cars:
		if is_instance_valid(c) and c is ArcadeCar and not (c as ArcadeCar).is_abandoned:
			new_car = c as ArcadeCar
			break
	
	assert_true(new_car != null, "New ArcadeCar successfully created from hijacked NPC traffic")
	if new_car:
		assert_true(new_car.car_id == "fire_dragon", "Player inherited exact car_id: %s" % new_car.car_id)
		assert_true(new_car.max_hp == 280.0, "Player car inherited Fire Dragon max HP (280)")
		assert_true(new_car.current_hp == 280.0, "Player car HP is 280")
		assert_true(new_car.gadget_system != null, "Car has gadget system attached")
		
		# Test activating Fire Dragon's unique Dragon Flame gadget
		var activated: bool = new_car.gadget_system.activate_gadget()
		assert_true(activated, "Fire Dragon unique DRAGON_FLAME gadget activated successfully")
		assert_true("DRAGON FLAME" in new_car.gadget_system.gadget_name, "Gadget title matches: %s" % new_car.gadget_system.gadget_name)
		assert_true(new_car.gadget_system.cooldown > 0.0, "Gadget cooldown started")
		
		# Now test getting off / ejecting from the Fire Dragon!
		new_car._eject_cooldown = 0.0
		var runner_2 := new_car.eject_player_character()
		assert_true(runner_2 != null, "Player successfully got off / ejected from hijacked Fire Dragon")
		assert_true(new_car.is_abandoned, "Fire Dragon is now abandoned on street")
		if is_instance_valid(runner_2): runner_2.queue_free()
		new_car.queue_free()

func _test_touch_hud_ejection_and_hijack_integration() -> void:
	print("\n--- 5. Testing TouchHUD Mobile Button Integration ---")
	var hud := TouchHUDScene.instantiate() as TouchHUD
	root.add_child(hud)
	
	# 1. On foot state
	var runner := PlayerCharScene.instantiate() as PlayerCharacter
	root.add_child(runner)
	runner.position = Vector3(50, 0.2, 50)
	
	hud._update_mobile_vehicle_button()
	assert_true(hud.action_vehicle_button != null, "Action vehicle button exists on HUD")
	assert_true(hud.action_vehicle_button.visible, "Action button visible while on foot")
	assert_true("ENTER CAR" in hud.action_vehicle_button.text or "HIJACK" in hud.action_vehicle_button.text, "Button prompts to enter/hijack vehicle")
	
	# Spawn nearby NPC car (Ice Cream Drifter)
	var npc := NPCTrafficCarScene.instantiate() as NPCTrafficCar
	npc.car_id = "ice_cream_drifter"
	root.add_child(npc)
	npc.global_position = Vector3(51.0, 0.5, 50.0)
	runner._nearby_vehicle = npc
	
	hud._update_mobile_vehicle_button()
	assert_true("ICE CREAM DRIFTER" in hud.action_vehicle_button.text, "HUD button shows real car name: '%s'" % hud.action_vehicle_button.text)
	
	# Enter car
	runner.queue_free()
	npc.queue_free()
	
	var car := ArcadeCarScene.instantiate() as ArcadeCar
	root.add_child(car)
	car.set_car_profile("ice_cream_drifter")
	hud.target_car = car
	
	hud._update_mobile_vehicle_button()
	assert_true("JUMP OUT" in hud.action_vehicle_button.text, "HUD button shows 'JUMP OUT' when in car: '%s'" % hud.action_vehicle_button.text)
	
	# Press the HUD button to jump out
	hud._on_action_vehicle_button_pressed()
	assert_true(car.is_abandoned, "Car successfully ejected when clicking HUD Action Button")
	
	# Clean up
	var runners := root.get_tree().get_nodes_in_group("player_character")
	for r in runners:
		if is_instance_valid(r): r.queue_free()
	car.queue_free()
	hud.queue_free()
