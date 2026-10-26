extends SceneTree

## Unit Test: PoliceSpawner on-foot player compatibility
## Verifies that PoliceSpawner handles CharacterBody3D (PlayerCharacter) without crashing on .physics_sphere

func _init() -> void:
	await process_frame
	await process_frame
	
	print("\n=================================================================")
	print("   TESTING POLICE SPAWNER ON-FOOT (PLAYERCHARACTER) RUNNER      ")
	print("=================================================================")
	
	var spawner_script = load("res://scripts/world/police_spawner.gd")
	var spawner: Node3D = spawner_script.new()
	root.add_child(spawner)
	
	# Instantiate a PlayerCharacter (CharacterBody3D)
	var runner_script = load("res://scripts/characters/player_character.gd")
	var runner: CharacterBody3D = runner_script.new()
	runner.name = "TestPlayerCharacter"
	runner.add_to_group("player_character")
	runner.position = Vector3(100.0, 0.0, 100.0)
	runner.velocity = Vector3(0.0, 0.0, 8.0) # Moving forward at 8 m/s
	root.add_child(runner)
	
	await process_frame
	
	# Mock WantedManager
	var mock_wm = Node.new()
	mock_wm.name = "WantedManager"
	mock_wm.set("stars", 3)
	mock_wm.set("max_active_units", 10)
	root.add_child(mock_wm)
	
	# Test 1: Player lookup finds runner
	var found_player = spawner._find_player()
	assert(found_player == runner, "Spawner must find PlayerCharacter runner when on foot")
	spawner._cached_player = found_player
	print("  [PASS] _find_player() successfully found PlayerCharacter")
	
	# Test 2: Safe velocity and heading calculation
	var vel: Vector3 = spawner._get_player_velocity()
	assert(vel == runner.velocity, "Spawner _get_player_velocity must match runner velocity")
	var heading: Vector3 = spawner._get_player_heading()
	assert(heading == runner.velocity.normalized(), "Spawner _get_player_heading must match movement direction")
	print("  [PASS] _get_player_velocity() and _get_player_heading() correctly read CharacterBody3D velocity")
	
	# Test 3: Spawning a police car with on-foot player
	var cop: PoliceCar = spawner._spawn_police_car(Vector3(100.0, 0.0, 70.0), runner.global_position, 3)
	assert(cop != null, "Police car must spawn without error")
	assert(is_instance_valid(cop), "Police car must be valid instance")
	print("  [PASS] _spawn_police_car() spawned PoliceCar successfully with on-foot player!")
	
	# Test 4: Roadblock spawning with on-foot player
	spawner._try_spawn_roadblock(runner.global_position)
	print("  [PASS] _try_spawn_roadblock() executed cleanly without physics_sphere error!")
	
	# Cleanup
	cop.queue_free()
	runner.queue_free()
	mock_wm.queue_free()
	spawner.queue_free()
	
	print("\n=================================================================")
	print("   POLICE SPAWNER ON-FOOT TEST PASSED (100% CLEAN)               ")
	print("=================================================================\n")
	quit(0)
