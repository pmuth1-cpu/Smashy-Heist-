extends SceneTree

const MainGameScene = preload("res://scenes/world/main_game.tscn")

func _init() -> void:
	print("--- TESTING NATURAL KART GP COUNTDOWN FLOW ---")
	_run()

func _run() -> void:
	await process_frame
	await process_frame
	
	var gmm = root.get_node_or_null("GameModeManager")
	assert(gmm != null, "GameModeManager must exist")
	gmm.set_mode(3)
	
	var game: MainGame = MainGameScene.instantiate() as MainGame
	root.add_child(game)
	current_scene = game
	
	var kart = game.smashy_kart_mode
	assert(kart != null, "SmashyKartMode must exist")
	assert(kart.is_countdown_active, "Countdown must start active")
	
	var car = game.arcade_car
	var p0 = car.physics_sphere.global_position
	
	# Wait until countdown finishes naturally (3.0s)
	while not kart.is_race_active and kart.countdown_timer < 4.0:
		await process_frame
	
	assert(kart.is_race_active, "Race must be active after 3.0s countdown! (countdown_timer: %.2f)" % kart.countdown_timer)
	assert(not kart.is_countdown_active, "Countdown must be inactive")
	assert(car.input_enabled, "Car input must be enabled")
	
	# Let them drive for 60 frames
	for i in range(60):
		await process_frame
	
	var p1 = car.physics_sphere.global_position
	var dist = p0.distance_to(p1)
	print("Car drove %.2fm along the track after natural countdown!" % dist)
	assert(dist > 1.0, "Car must move along the track!")
	
	print("--- NATURAL KART COUNTDOWN & RACE START PASSED (100%) ---")
	quit(0)
