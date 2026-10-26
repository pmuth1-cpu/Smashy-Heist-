extends SceneTree

## Tool: Batch-render 256x256 transparent PNG thumbnails for all 4 Mythic cars

func _init() -> void:
	await process_frame
	await process_frame
	
	print("\n=============================================================")
	print("     BATCH-RENDERING 4 MYTHIC CAR TRANSPARENT THUMBNAILS     ")
	print("=============================================================")
	
	var vdb_script = load("res://scripts/autoload/vehicle_database.gd")
	var vdb: Node = vdb_script.new()
	root.add_child(vdb)
	
	var vab_script = load("res://scripts/autoload/voxel_asset_builder.gd")
	var vab: Node = vab_script.new()
	root.add_child(vab)
	
	# Transparent SubViewport
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	
	var world := Node3D.new()
	vp.add_child(world)
	
	var cam := Camera3D.new()
	cam.look_at_from_position(Vector3(3.4, 2.2, -3.8), Vector3(0.0, 0.45, 0.0), Vector3.UP)
	cam.fov = 36.0
	world.add_child(cam)
	
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 45.0, 0.0)
	sun.light_color = Color("ffffff")
	sun.light_energy = 1.6
	world.add_child(sun)
	
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(30.0, -135.0, 0.0)
	fill.light_color = Color("e056fd") # Radiant celestial purple fill light for mythic tier
	fill.light_energy = 1.1
	world.add_child(fill)
	
	var mount := Node3D.new()
	world.add_child(mount)
	
	var mythic_cars: Array = vdb.get_mythic_cars()
	print("Found %d Mythic cars to render." % mythic_cars.size())
	
	var rendered_count: int = 0
	for cinfo in mythic_cars:
		var cid: String = String(cinfo["id"])
		for c in mount.get_children():
			c.queue_free()
		await process_frame
		
		var car_node: Node3D = vab.build_player_car_visuals(cid)
		if car_node:
			mount.add_child(car_node)
			car_node.rotation_degrees = Vector3(0.0, 35.0, 0.0)
		
		for f in range(6):
			await process_frame
		
		var img := vp.get_texture().get_image()
		if img:
			var save_path := "res://assets/textures/cars/car_%s.png" % cid
			var err = img.save_png(save_path)
			if err == OK:
				rendered_count += 1
				print("  [%2d/4] Rendered: %-22s -> %s" % [rendered_count, cid, save_path])
			else:
				print("  [ERROR] Failed to save %s (err: %d)" % [cid, err])
	
	print("\n=============================================================")
	print("     RENDER COMPLETE: %d / %d MYTHIC CAR THUMBNAILS SAVED     " % [rendered_count, mythic_cars.size()])
	print("=============================================================\n")
	quit(0)
