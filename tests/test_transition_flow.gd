extends SceneTree

func _init() -> void:
	print("TESTING SCENE TRANSITION...")
	_run()

func _run() -> void:
	# Load main menu first
	var menu_scene = load("res://scenes/ui/brawl_main_menu.tscn")
	var menu = menu_scene.instantiate()
	root.add_child(menu)
	current_scene = menu
	
	await process_frame
	await process_frame
	print("Menu mounted. Current scene: %s" % current_scene.name)
	
	var stm = root.get_node_or_null("SceneTransitionManager")
	assert(stm != null, "SceneTransitionManager must exist")
	
	print("Triggering transition to main_game.tscn...")
	stm.transition_to_scene("res://scenes/world/main_game.tscn")
	
	var timer: float = 0.0
	while timer < 3.0:
		await process_frame
		timer += 0.016
		if current_scene and current_scene.name == "MainGame":
			print("SUCCESS: Transition completed to MainGame in %.2fs!" % timer)
			break
	
	assert(current_scene and current_scene.name == "MainGame", "Transition did not reach MainGame! Current scene is %s" % (current_scene.name if current_scene else "null"))
	print("MainGame running! Car name: %s" % (current_scene.arcade_car.name if current_scene.arcade_car else "null"))
	quit(0)
