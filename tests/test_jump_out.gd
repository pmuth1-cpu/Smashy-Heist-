extends SceneTree

const MainGameScene = preload("res://scenes/world/main_game.tscn")

func _init() -> void:
	await process_frame
	await process_frame
	var game = MainGameScene.instantiate()
	root.add_child(game)
	for f in range(10):
		await process_frame
	var car = game.arcade_car
	print("Car pos before jump: ", car.car_pivot.global_position, " sphere: ", car.physics_sphere.global_position)
	var runner = car.eject_player_character()
	print("Runner spawned: ", runner != null, " pos: ", runner.global_position if runner else Vector3.ZERO)
	for f in range(30):
		await process_frame
		if f % 10 == 0:
			print("Frame ", f, " Car pos: ", car.car_pivot.global_position, " sphere pos: ", car.physics_sphere.global_position, " visible: ", car.car_pivot.visible, " is_inside_tree: ", car.is_inside_tree())
	quit()
