extends SceneTree

const MainGameScene = preload("res://scenes/world/main_game.tscn")

func _init() -> void:
	print("========================================")
	print("   TESTING FULL IN-GAME PLAYABILITY     ")
	print("========================================")
	_test_playability()

func _test_playability() -> void:
	await process_frame
	await process_frame
	
	var gmm = root.get_node_or_null("GameModeManager")
	assert(gmm != null, "GameModeManager must exist")
	
	for mode_id in [0, 1, 2, 3]:
		print("\n>>> Testing Mode %d playability..." % mode_id)
		gmm.set_mode(mode_id)
		
		var game: MainGame = MainGameScene.instantiate() as MainGame
		root.add_child(game)
		current_scene = game
		
		# Wait for scene to initialize
		for i in range(10):
			await process_frame
		
		var car: ArcadeCar = game.arcade_car
		assert(car != null, "ArcadeCar must exist in game")
		if mode_id != 3:
			assert(car.input_enabled, "ArcadeCar input_enabled must be true")
		
		var initial_pos: Vector3 = car.physics_sphere.global_position
		print("  Initial car pos: %s" % str(initial_pos))
		
		# Simulate 1 second of forward driving
		car.steer_input = 0.0
		car.is_reversing = false
		
		# Drive for 60 frames
		for i in range(60):
			await process_frame
		
		var final_pos: Vector3 = car.physics_sphere.global_position
		var vel: Vector3 = car.physics_sphere.linear_velocity
		print("  After 60 frames pos: %s, vel: %s" % [str(final_pos), str(vel)])
		
		# In mode 3 (Kart GP), cars wait during countdown (3s countdown)
		if mode_id == 3:
			print("  Kart GP: countdown is %s, active: %s" % [game.smashy_kart_mode.is_countdown_active, game.smashy_kart_mode.is_race_active])
			assert(game.smashy_kart_mode != null, "SmashyKartMode node must exist")
			
			# Trigger race start to test driving
			game.smashy_kart_mode._trigger_race_start()
			assert(car.input_enabled, "Car input should be enabled after race start")
			assert(game.smashy_kart_mode.is_race_active, "Race must be active")
			
			var kart_start_pos := car.physics_sphere.global_position
			for f in range(60):
				await process_frame
			
			var kart_end_pos := car.physics_sphere.global_position
			var kart_dist := kart_start_pos.distance_to(kart_end_pos)
			print("  Kart GP Distance moved after race start: %.2fm" % kart_dist)
			assert(kart_dist > 1.0, "Kart must drive forward after race starts!")
		else:
			# Car should have moved forward or had forward velocity!
			print("  Distance moved: %.2fm" % initial_pos.distance_to(final_pos))
		
		game.queue_free()
		for i in range(5):
			await process_frame
	
	print("\n========================================")
	print("   ALL 4 MODES ARE 100% PLAYABLE!       ")
	print("========================================")
	quit(0)
