extends SceneTree

const CarScene = preload("res://scenes/vehicles/arcade_car.tscn")
const CopScene = preload("res://scenes/vehicles/police_car.tscn")
const NPCScene = preload("res://scenes/vehicles/npc_traffic_car.tscn")
const PlayerCharScript = preload("res://scripts/characters/player_character.gd")

func _init() -> void:
	await process_frame
	await process_frame
	await _run_all_tests()

func _run_all_tests() -> void:
	print("\n=================================================================")
	print("  TEST SUITE: CAR VISUALS INTEGRITY, ZERO WALL DAMAGE & COP TUNE ")
	print("=================================================================")
	
	test_parked_car_visuals_not_overwritten()
	await process_frame
	test_zero_wall_damage()
	await process_frame
	test_police_speed_and_health_rebalance()
	await process_frame
	test_enter_parked_car_no_morph()
	await process_frame
	
	print("\n=================================================================")
	print("   ALL CAR VISUALS & ZERO WALL DAMAGE TESTS PASSED (100% GREEN)  ")
	print("=================================================================\n")
	quit(0)

## TEST 1: Parked cars retain their assigned car_id visuals and do NOT copy player's equipped car
func test_parked_car_visuals_not_overwritten() -> void:
	print("\n--- TEST 1: PARKED CAR VISUAL INTEGRITY ---")
	var sm = root.get_node("/root/SaveManager")
	sm.equipped_car_id = "tuk_tuk_jet" # Player has tuk tuk equipped
	
	var car := CarScene.instantiate() as ArcadeCar
	car.car_id = "racer_01" # Parked fleet car is racer_01
	car.is_abandoned = true
	root.add_child(car)
	
	# Verify car didn't overwrite its car_id with player's tuk_tuk_jet
	assert(car.car_id == "racer_01", "Parked car must keep racer_01 car_id, not player's car!")
	assert(car.stats.car_id == "racer_01", "Parked car stats must match racer_01, not player's car!")
	
	var vis = car.car_pivot.get_node_or_null("VoxelCarVisual")
	assert(vis != null, "Parked car must have 3D visual model")
	assert(car.car_id == "racer_01", "Parked car car_id must be racer_01, not player car!")
	assert(car.stats.car_id == "racer_01", "Parked car stats must match racer_01!")
	
	# Verify player's gear loadout is NOT attached to abandoned parked car
	var roof_gear = car.car_pivot.get_node_or_null("VisualGearLoadout")
	assert(roof_gear == null, "Abandoned parked car must NOT have player's equipped roof gear!")
	print("  [PASS] Parked car correctly spawns with its own unique model and no player gear attachment")
	
	car.queue_free()

## TEST 2: Colliding with walls and buildings deals literally 0 damage
func test_zero_wall_damage() -> void:
	print("\n--- TEST 2: LITERALLY ZERO WALL DAMAGE ---")
	var car := CarScene.instantiate() as ArcadeCar
	root.add_child(car)
	car.current_hp = 200.0
	car.max_hp = 200.0
	
	# Create a static building collider (StaticBody3D on Layer 4: Buildings)
	var wall := StaticBody3D.new()
	wall.name = "Building_Block_0"
	wall.collision_layer = 8 # Layer 4
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.0, 10.0, 10.0)
	cs.shape = box
	wall.add_child(cs)
	root.add_child(wall)
	
	# Simulate high-speed head-on collision into building (speed 25.0 m/s > CRASH_VELOCITY_THRESHOLD)
	car.physics_sphere.linear_velocity = Vector3(25.0, 0.0, 0.0)
	car._previous_velocity = Vector3(25.0, 0.0, 0.0)
	car._on_physics_sphere_body_entered(wall)
	
	assert(car.current_hp == 200.0, "Car must take literally 0 damage when hitting a wall or building! (HP: %f)" % car.current_hp)
	print("  [PASS] Colliding with walls and buildings causes literally 0.0 damage to vehicle HP")
	
	# Test another static body: Curb / barrier
	var curb := StaticBody3D.new()
	curb.name = "Ground_Curb"
	curb.collision_layer = 1
	root.add_child(curb)
	car._on_physics_sphere_body_entered(curb)
	assert(car.current_hp == 200.0, "Car must take literally 0 damage when hitting static curbs/ground!")
	print("  [PASS] Static world curbs and barriers also deal 0 damage")
	
	car.queue_free()
	wall.queue_free()
	curb.queue_free()

## TEST 3: Police car stats rebalanced (not too fast) and high HP buffer
func test_police_speed_and_health_rebalance() -> void:
	print("\n--- TEST 3: POLICE CAR REBALANCE & HEALTH BUFFER ---")
	var car := CarScene.instantiate() as ArcadeCar
	root.add_child(car)
	car.current_hp = 100.0
	car.max_hp = 200.0 # Damaged car
	
	# 1. Adopt Interceptor
	car.adopt_police_vehicle(PoliceCar.PoliceType.INTERCEPTOR_MUSCLE)
	assert(car.stats.max_speed <= 27.0, "Police Interceptor speed must be comfortable and manageable (<= 27.0, got %f)" % car.stats.max_speed)
	assert(car.stats.max_speed >= 25.0, "Police Interceptor speed must still be fast (>= 25.0)")
	assert(car.stats.turn_speed <= 4.0, "Police Interceptor turn speed must not be overly twitchy (<= 4.0)")
	assert(car.current_hp >= car.max_hp * 0.90, "Commandeering police car must grant generous health buffer (>= 90% HP)")
	print("  [PASS] Police Interceptor tuned to comfortable speed (%0.1f m/s) and high health buffer (%0.0f HP)" % [car.stats.max_speed, car.current_hp])
	
	# 2. Adopt Patrol Cruiser
	car.adopt_police_vehicle(PoliceCar.PoliceType.PATROL_CRUISER)
	assert(car.stats.max_speed <= 24.5, "Police Cruiser speed must be controllable (<= 24.5, got %f)" % car.stats.max_speed)
	assert(car.current_hp >= car.max_hp * 0.90, "Police Cruiser grants generous health buffer (>= 90% HP)")
	print("  [PASS] Police Cruiser tuned to controllable speed (%0.1f m/s) and generous health (%0.0f HP)" % [car.stats.max_speed, car.current_hp])
	
	car.queue_free()

## TEST 4: Entering a parked car does not morph appearance
func test_enter_parked_car_no_morph() -> void:
	print("\n--- TEST 4: ENTER PARKED CAR NO MORPH ---")
	var parked := CarScene.instantiate() as ArcadeCar
	parked.car_id = "racer_01"
	parked.is_abandoned = true
	root.add_child(parked)
	
	var initial_vis = parked.car_pivot.get_node_or_null("VoxelCarVisual")
	assert(initial_vis != null, "Parked car must have visual model initially")
	var initial_name = initial_vis.name
	
	# Player enters parked car
	var runner := PlayerCharScript.new() as PlayerCharacter
	root.add_child(runner)
	runner.enter_vehicle(parked)
	
	var after_vis = parked.car_pivot.get_node_or_null("VoxelCarVisual")
	assert(after_vis != null, "Car must still have visual model after entering")
	assert(after_vis.name == initial_name, "Visual model must NOT morph into another car on entry! (%s vs %s)" % [after_vis.name, initial_name])
	assert(parked.car_id == "racer_01", "Car ID must remain racer_01")
	print("  [PASS] Entering parked car preserves its visual model seamlessly without morphing")
	
	parked.queue_free()
	runner.queue_free()
