extends SceneTree

const MainGameScene = preload("res://scenes/world/main_game.tscn")

func _init() -> void:
	await process_frame
	await process_frame
	var game = MainGameScene.instantiate()
	root.add_child(game)
	for f in range(20):
		await process_frame
	var car = game.arcade_car
	var runner = car.eject_player_character()
	for f in range(60):
		await process_frame
		if f < 10 or f % 15 == 0:
			print("Frame ", f, ": Car pos=", car.car_pivot.global_position, " sphere_vel=", car.physics_sphere.linear_velocity, " runner pos=", runner.global_position)
	quit()
