extends SceneTree

func _init() -> void:
	var vp = SubViewport.new()
	vp.size = Vector2i(800, 600)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	
	var env = World3D.new()
	vp.world_3d = env
	
	# Light
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_energy = 1.8
	vp.add_child(light)
	
	var fill_light = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(30, -135, 0)
	fill_light.light_energy = 0.6
	vp.add_child(fill_light)
	
	# Camera
	var cam = Camera3D.new()
	cam.position = Vector3(0, 3, 7)
	cam.look_at(Vector3(0, 0, 0))
	cam.current = true
	vp.add_child(cam)
	
	# Spider Model
	var scn = load("res://assets/models/bosses/steampunk_spider_robot.glb")
	var spider: Node3D = scn.instantiate() as Node3D
	spider.scale = Vector3.ONE * 0.01
	spider.position = Vector3(0, 2.14, 0) # align feet to ground
	vp.add_child(spider)
	
	await process_frame
	await process_frame
	await process_frame
	
	var img = vp.get_texture().get_image()
	img.save_png("res://tests/spider_preview.png")
	print("Saved spider_preview.png successfully!")
	
	spider.queue_free()
	vp.queue_free()
	quit(0)
