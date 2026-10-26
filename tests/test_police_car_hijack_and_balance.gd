extends SceneTree

const CarScene = preload("res://scenes/vehicles/arcade_car.tscn")
const CopScene = preload("res://scenes/vehicles/police_car.tscn")
const NPCScene = preload("res://scenes/vehicles/npc_traffic_car.tscn")
const TouchHUDScene = preload("res://scenes/ui/touch_hud.tscn")
const PlayerCharScript = preload("res://scripts/characters/player_character.gd")

func _init() -> void:
	await process_frame
	await process_frame
	await _run_all_tests()

func _run_all_tests() -> void:
	print("\n=================================================================")
	print("  STARTING POLICE HIJACK, BALANCE & MOBILE BUTTON TEST SUITE     ")
	print("=================================================================")
	
	test_abandoned_car_not_controlled_by_player()
	await process_frame
	await process_frame
	test_health_preservation_across_cars()
	await process_frame
	await process_frame
	test_police_health_and_no_drift_knockout()
	await process_frame
	await process_frame
	test_direction_to_nearest_car_on_foot()
	await process_frame
	await process_frame
	test_hijacking_and_driving_police_car()
	await process_frame
	await process_frame
	test_mobile_enter_car_and_jump_out_button()
	await process_frame
	await process_frame
	
	print("\n=================================================================")
	print("   ALL POLICE HIJACK & BALANCE TESTS PASSED (100% GREEN)         ")
	print("=================================================================\n")
	quit(0)

## TEST 1: Abandoned car is NOT controlled by player anymore
func test_abandoned_car_not_controlled_by_player() -> void:
	print("\n--- TEST 1: ABANDONED CAR NOT CONTROLLED ---")
	var car := CarScene.instantiate() as ArcadeCar
	root.add_child(car)
	car.is_abandoned = true
	car.input_enabled = false
	car.steer_input = 1.0 # Try to steer
	
	var prev_rot: float = car.car_pivot.rotation.y
	car._physics_process(0.1)
	assert(car.steer_input == 0.0, "Abandoned car must reset steer_input to 0.0")
	assert(is_equal_approx(car.car_pivot.rotation.y, prev_rot), "Abandoned car must not rotate or steer")
	print("  [PASS] Abandoned car does not steer or accelerate from player inputs")
	
	car.queue_free()

## TEST 2: Player CANNOT restore health by entering new cars
func test_health_preservation_across_cars() -> void:
	print("\n--- TEST 2: HEALTH PRESERVATION (NO FREE HEALTH RESTORATION) ---")
	var wm = root.get_node_or_null("/root/WantedManager")
	if wm:
		wm.start_new_run()
	
	var car := CarScene.instantiate() as ArcadeCar
	root.add_child(car)
	car.current_hp = 60.0
	car.max_hp = 180.0
	
	# 1. Player ejects and takes damage on foot down to 40 HP
	var runner = car.eject_player_character() as PlayerCharacter
	assert(runner != null, "Runner must spawn on ejection")
	runner.take_damage(60.0) # Down to 40 HP
	assert(runner.current_hp == 40.0, "Runner HP should be 40.0")
	if wm:
		assert(wm.player_persistent_hp == 40.0, "WantedManager must record persistent player HP at 40.0")
	
	# 2. Player hijacks an NPC car: entering new car does NOT reset player persistent HP to 100!
	var npc := NPCScene.instantiate() as NPCTrafficCar
	root.add_child(npc)
	runner.hijack_vehicle(npc)
	if wm:
		assert(wm.player_persistent_hp == 40.0, "Entering new car must NOT heal the player!")
	
	# 3. Next time player ejects, runner emerges with that same 40 HP, NOT 100 HP!
	car.is_abandoned = false
	car.input_enabled = true
	var runner2 = car.eject_player_character() as PlayerCharacter
	assert(runner2 != null, "Runner 2 must spawn")
	assert(runner2.current_hp == 40.0, "Player must NOT have restored health: still at 40 HP!")
	print("  [PASS] Persistent player health preserved across vehicle transfers (no free health exploit)")
	
	runner2.queue_free()
	car.queue_free()

## TEST 3: Police balance - durable health and immune to drift knockout
func test_police_health_and_no_drift_knockout() -> void:
	print("\n--- TEST 3: POLICE DURABILITY & NO DRIFT KNOCKOUT ---")
	var cop := CopScene.instantiate() as PoliceCar
	root.add_child(cop)
	cop.police_type = PoliceCar.PoliceType.PATROL_CRUISER
	cop._apply_type_config()
	assert(cop.max_hp >= 200.0, "Police Cruiser HP must be balanced at 200+ HP")
	
	var car := CarScene.instantiate() as ArcadeCar
	root.add_child(car)
	cop.global_position = car.global_position + Vector3(2.0, 0, 0)
	
	# Trigger drift shockwave near cop: MUST NOT deal direct damage!
	var initial_cop_hp: float = cop.hp
	car._trigger_drift_shockwave()
	assert(cop.hp == initial_cop_hp, "Drift shockwave must NOT damage or knockout police cruisers")
	print("  [PASS] Police cruisers are durable (200 HP) and immune to drift knockout damage")
	
	cop.queue_free()
	car.queue_free()

## TEST 4: Direction to nearest car when jumped off the car
func test_direction_to_nearest_car_on_foot() -> void:
	print("\n--- TEST 4: DIRECTION TO NEAREST CAR ON FOOT ---")
	# Clean up any leftover group nodes first
	for node in root.get_tree().get_nodes_in_group("player_character"):
		if is_instance_valid(node): node.queue_free()
	for node in root.get_tree().get_nodes_in_group("player_vehicles"):
		if is_instance_valid(node): node.queue_free()
	
	var runner := PlayerCharScript.new() as PlayerCharacter
	root.add_child(runner)
	runner.global_position = Vector3(0, 0, 0)
	
	# Spawn a civilian car 15 meters to the East (+X)
	var npc := NPCScene.instantiate() as NPCTrafficCar
	root.add_child(npc)
	npc.global_position = Vector3(15.0, 0.0, 0.0)
	
	runner._physics_process(0.1)
	var nearest: Node3D = runner.get_nearest_vehicle()
	assert(nearest == npc, "Runner must identify the nearest car")
	assert(runner._guide_arrow != null, "Runner must have 3D guide arrow")
	assert(runner._guide_arrow.visible == true, "3D guide arrow must be visible when cars are available")
	print("  [PASS] 3D Guide Arrow and nearest vehicle resolver successfully guide the runner")
	
	npc.queue_free()
	runner.queue_free()

## TEST 5: Player can drive a Police Car
func test_hijacking_and_driving_police_car() -> void:
	print("\n--- TEST 5: HIJACKING AND DRIVING A POLICE CAR ---")
	for node in root.get_tree().get_nodes_in_group("player_character"):
		if is_instance_valid(node): node.queue_free()
	for node in root.get_tree().get_nodes_in_group("player_vehicles"):
		if is_instance_valid(node): node.queue_free()
	
	var runner := PlayerCharScript.new() as PlayerCharacter
	root.add_child(runner)
	runner.global_position = Vector3(0, 0, 0)
	
	var cop := CopScene.instantiate() as PoliceCar
	root.add_child(cop)
	cop.police_type = PoliceCar.PoliceType.INTERCEPTOR_MUSCLE
	cop.officers_inside = 0
	cop.global_position = Vector3(1.5, 0, 0)
	if cop.physics_sphere:
		cop.physics_sphere.global_position = Vector3(1.5, 0, 0)
	
	# Runner scans and identifies Police Interceptor
	runner._scan_for_hijack_targets()
	assert(runner.get_nearby_vehicle() == cop, "Runner must detect nearby police vehicle")
	
	# Runner hijacks the police car
	runner.hijack_vehicle(cop)
	
	# Find commandeered vehicle
	var hijacked_car: ArcadeCar = null
	for c in root.get_tree().get_nodes_in_group("player_vehicles"):
		if is_instance_valid(c) and c is ArcadeCar and not (c as ArcadeCar).is_abandoned:
			hijacked_car = c as ArcadeCar
			break
	
	assert(hijacked_car != null, "Commandeered car must exist")
	assert(hijacked_car.is_abandoned == false, "Player car restored to active driving")
	assert(hijacked_car.stats.max_speed >= 25.0, "Player adopted balanced Police Interceptor stats")
	print("  [PASS] Player successfully hijacked and commandeered a Police Car")
	
	if hijacked_car:
		hijacked_car.queue_free()

## TEST 6: Mobile Enter Car & Jump Out button
func test_mobile_enter_car_and_jump_out_button() -> void:
	print("\n--- TEST 6: MOBILE VEHICLE ACTION BUTTON ---")
	for node in root.get_tree().get_nodes_in_group("player_character"):
		if is_instance_valid(node): node.queue_free()
	for node in root.get_tree().get_nodes_in_group("player_vehicles"):
		if is_instance_valid(node): node.queue_free()
	
	var hud := TouchHUDScene.instantiate() as TouchHUD
	root.add_child(hud)
	
	var car := CarScene.instantiate() as ArcadeCar
	root.add_child(car)
	car.is_abandoned = false
	car.input_enabled = true
	hud.target_car = car
	
	# 1. In Car: button displays "🏃 JUMP OUT"
	hud._update_mobile_vehicle_button()
	assert(hud.action_vehicle_button != null, "Action vehicle button must exist")
	assert(hud.action_vehicle_button.visible == true, "Action button visible while driving")
	assert("JUMP OUT" in hud.action_vehicle_button.text, "Button text should prompt 'JUMP OUT' when in car")
	print("  [PASS] Mobile button prompts 'JUMP OUT' while driving")
	
	# 2. On Foot: button displays "🚗 ENTER CAR"
	car.is_abandoned = true
	var runner := PlayerCharScript.new() as PlayerCharacter
	root.add_child(runner)
	hud._update_mobile_vehicle_button()
	assert(hud.action_vehicle_button.visible == true, "Action button visible while on foot")
	assert("CAR" in hud.action_vehicle_button.text or "HIJACK" in hud.action_vehicle_button.text, "Button prompts entering/hijacking car")
	print("  [PASS] Mobile button prompts 'ENTER CAR' / 'HIJACK' while on foot")
	
	runner.queue_free()
	car.queue_free()
	hud.queue_free()
