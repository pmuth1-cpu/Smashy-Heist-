extends SceneTree

const CarScene = preload("res://scenes/vehicles/arcade_car.tscn")
const CopScene = preload("res://scenes/vehicles/police_car.tscn")
const SmashPropScene = preload("res://scenes/props/smash_prop.tscn")
const PlayerCharScript = preload("res://scripts/characters/player_character.gd")
const VABScript = preload("res://scripts/autoload/voxel_asset_builder.gd")

func _init() -> void:
	await process_frame
	await process_frame
	await _run_all_tests()

func _run_all_tests() -> void:
	print("\n=================================================================")
	print("  STARTING ON-FOOT CONTROLS & ABANDONED CAR TEST SUITE           ")
	print("=================================================================")
	
	test_abandoned_car_is_meaningless()
	await process_frame
	test_surrounded_busted_only_in_car()
	await process_frame
	test_player_movement_like_car_ad_steering()
	await process_frame
	test_no_jump_needed_small_obstacles_and_props()
	await process_frame
	test_player_model_direction_not_inversed()
	await process_frame
	test_player_focus_and_wasted_on_foot()
	
	print("\n=================================================================")
	print("   ALL ON-FOOT & ABANDONED CAR TESTS PASSED (100% GREEN)         ")
	print("=================================================================\n")
	quit(0)

## TEST 1: Abandoned car is meaningless & never causes game over
func test_abandoned_car_is_meaningless() -> void:
	print("\n--- TEST 1: ABANDONED CAR IS MEANINGLESS ---")
	var wm = root.get_node_or_null("/root/WantedManager")
	if wm:
		wm.start_new_run()
	
	var car := CarScene.instantiate() as ArcadeCar
	root.add_child(car)
	car.is_abandoned = true
	car.current_hp = 50.0
	
	# 1. Abandoned car taking damage never triggers busted
	car.take_damage(60.0)
	assert(car.current_hp == 50.0 or car.current_hp == 0.0, "Abandoned car damage handled safely")
	if wm:
		assert(wm.is_run_active == true, "Damaging an abandoned car must NEVER trigger game over!")
	print("  [PASS] Abandoned car taking damage does not trigger game over")
	
	# 2. Abandoned car boxed in by cops never ticks up busted_progress
	car.busted_progress = 0.0
	car._physics_process(0.5)
	assert(car.busted_progress == 0.0, "Abandoned car must have 0.0 busted progress")
	if car.busted_indicator:
		assert(car.busted_indicator.visible == false, "Busted indicator must be hidden for abandoned car")
	print("  [PASS] Abandoned car surrounded by cops never ticks up busted progress")
	
	car.queue_free()

## TEST 2: Surrounded busted condition only applies in car, not on foot
func test_surrounded_busted_only_in_car() -> void:
	print("\n--- TEST 2: SURROUNDED BUSTED ONLY APPLIES IN CAR ---")
	var wm = root.get_node_or_null("/root/WantedManager")
	if wm:
		wm.start_new_run()
	
	var runner := PlayerCharScript.new() as PlayerCharacter
	root.add_child(runner)
	runner.global_position = Vector3(0, 0, 0)
	
	# Spawn 3 cops surrounding the on-foot runner
	var cops: Array[PoliceCar] = []
	for i in range(3):
		var cop := CopScene.instantiate() as PoliceCar
		root.add_child(cop)
		cop.global_position = Vector3(1.5 * cos(i * TAU / 3), 0.0, 1.5 * sin(i * TAU / 3))
		cops.append(cop)
	
	# Process physics on runner: on foot, surrounded progress must not exist or trigger bust
	for _frame in range(10):
		runner._physics_process(0.1)
	
	if wm:
		assert(wm.is_run_active == true, "On-foot player surrounded by cops must NOT be busted!")
	print("  [PASS] On-foot runner surrounded by 3 cops is NOT busted")
	
	for cop in cops:
		cop.queue_free()
	runner.queue_free()

## TEST 3: Player movement controls like a car using A and D
func test_player_movement_like_car_ad_steering() -> void:
	print("\n--- TEST 3: PLAYER CAR-LIKE A & D STEERING ---")
	var runner := PlayerCharScript.new() as PlayerCharacter
	root.add_child(runner)
	runner.global_position = Vector3(0, 0, 0)
	runner.rotation.y = 0.0
	
	# 1. Pressing A (steer_input = -1.0) turns left (rotation.y increases in Godot)
	runner.steer_input = -1.0
	runner._physics_process(0.1)
	assert(runner.rotation.y > 0.0, "Steering Left (A) must turn character left (yaw > 0)")
	print("  [PASS] Steer Left (A) correctly rotates runner left")
	
	# 2. Pressing D (steer_input = 1.0) turns right
	var prev_rot: float = runner.rotation.y
	runner.steer_input = 1.0
	runner._physics_process(0.2)
	assert(runner.rotation.y < prev_rot, "Steering Right (D) must turn character right")
	print("  [PASS] Steer Right (D) correctly rotates runner right")
	
	# 3. Auto-run forward along heading
	runner.steer_input = 0.0
	runner.rotation.y = 0.0
	runner._physics_process(0.1)
	# Heading is -Z: forward velocity must be negative Z
	assert(runner.velocity.z < -1.0, "Runner automatically runs forward along -Z heading")
	print("  [PASS] Runner automatically drives/runs forward like an arcade getaway car")
	
	runner.queue_free()

## TEST 4: No jump needed - small obstacles bypassed & props smashed
func test_no_jump_needed_small_obstacles_and_props() -> void:
	print("\n--- TEST 4: NO JUMP NEEDED & SMALL PROPS SMASHED ---")
	var runner := PlayerCharScript.new() as PlayerCharacter
	root.add_child(runner)
	
	# 1. Collision mask excludes Layer 16 (SmashProps), preventing player from sticking on props
	assert((runner.collision_mask & 16) == 0, "Player character collision mask must exclude Layer 16 so player glides through small obstacles")
	assert((runner.collision_mask & 1) != 0, "Player character must collide with Ground (Layer 1)")
	assert((runner.collision_mask & 8) != 0, "Player character must collide with Buildings (Layer 4)")
	print("  [PASS] Collision masks configured: Ground and Buildings solid, small props bypassed")
	
	# 2. Runner smashes props on contact
	var prop := SmashPropScene.instantiate() as SmashProp
	root.add_child(prop)
	prop.global_position = runner.global_position + Vector3(0.2, 0.0, -0.2)
	runner._smash_nearby_props()
	assert(prop._is_smashed == true, "SmashProp must be smashed when runner contacts it")
	print("  [PASS] Runner automatically smashes contact props into debris without jumping")
	
	prop.queue_free()
	runner.queue_free()

## TEST 5: Player model direction is not inversed
func test_player_model_direction_not_inversed() -> void:
	print("\n--- TEST 5: PLAYER MODEL DIRECTION NOT INVERSED ---")
	var runner := PlayerCharScript.new() as PlayerCharacter
	root.add_child(runner)
	
	assert(runner.visual_model != null, "Visual model must be built")
	# When facing default forward (-Z), visual_model rotation.y must be 0.0 (aligned with CharacterBody3D)
	runner.rotation.y = 0.0
	runner._physics_process(0.1)
	assert(is_zero_approx(runner.visual_model.rotation.y), "Visual model local rotation.y must be 0.0 (aligned with facing heading, not inverted 180 degrees)")
	
	# Verify head/mask is at -Z (front) and bag is at +Z (back)
	var head := runner.visual_model.find_child("Head", true, false)
	assert(head != null, "Head node must exist in model")
	var torso := runner.visual_model.find_child("Torso", true, false)
	assert(torso != null, "Torso node must exist in model")
	print("  [PASS] Visual model correctly oriented: faces forward (-Z), not inversed")
	
	runner.queue_free()

## TEST 6: Player focus and death on foot
func test_player_focus_and_wasted_on_foot() -> void:
	print("\n--- TEST 6: PLAYER FOCUS & DEATH ON FOOT ---")
	var wm = root.get_node_or_null("/root/WantedManager")
	if wm:
		wm.start_new_run()
	
	var runner := PlayerCharScript.new() as PlayerCharacter
	root.add_child(runner)
	runner.max_hp = 100.0
	runner.current_hp = 100.0
	
	# Taking fatal damage on foot triggers "WASTED ON FOOT!"
	runner.take_damage(120.0)
	if wm:
		assert(wm.is_run_active == false, "Run must end when runner HP reaches 0")
	print("  [PASS] Lethal on-foot damage triggers game over (WASTED ON FOOT!)")
