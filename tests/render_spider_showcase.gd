extends SceneTree

func _init() -> void:
	var vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	
	var env = World3D.new()
	vp.world_3d = env
	
	# Directional Lights
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 45, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	vp.add_child(sun)
	
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20, -135, 0)
	fill.light_energy = 0.5
	vp.add_child(fill)
	
	# Ground
	var ground = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(100, 100)
	ground.mesh = pm
	var g_mat = StandardMaterial3D.new()
	g_mat.albedo_color = Color("1e272e")
	ground.material_override = g_mat
	vp.add_child(ground)
	
	# Player Car ahead
	var car_scene: PackedScene = load("res://scenes/vehicles/arcade_car.tscn")
	var car: ArcadeCar = car_scene.instantiate() as ArcadeCar
	car.position = Vector3(0, 0.45, 16)
	vp.add_child(car)
	
	# Boss Escape Mode
	var boss_mode := BossEscapeMode.new()
	vp.add_child(boss_mode)
	boss_mode.start_boss_mode(car)
	
	# Trigger laser firing for showcase
	boss_mode._start_laser_firing()
	boss_mode._fire_single_boss_rocket(0, car.global_position)
	boss_mode._fire_single_boss_rocket(1, car.global_position)
	
	# Position camera for dramatic angle
	var cam = Camera3D.new()
	cam.position = Vector3(14, 8, 8)
	cam.look_at(Vector3(0, 2.0, 6))
	cam.current = true
	vp.add_child(cam)
	
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	
	var img = vp.get_texture().get_image()
	img.save_png("res://tests/spider_combat_showcase.png")
	print("Saved spider_combat_showcase.png successfully!")
	
	boss_mode.stop_boss_mode()
	boss_mode.queue_free()
	car.queue_free()
	vp.queue_free()
	quit(0)
