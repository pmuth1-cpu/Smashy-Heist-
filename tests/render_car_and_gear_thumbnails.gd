extends SceneTree

const ALL_CARS := [
	"default_coupe",
	"ice_cream_drifter",
	"tuk_tuk_jet",
	"armored_bulldozer",
	"cyber_interceptor",
	"monster_pickup",
	"racer_01",
	"tanker",
	"shadow",
	"fire_dragon"
]

func _init() -> void:
	await process_frame
	await process_frame
	
	print("\n--- RENDERING 3D CAR AND GEAR TRANSPARENT THUMBNAILS ---")
	
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
	cam.look_at_from_position(Vector3(3.0, 2.0, -3.4), Vector3(0.0, 0.4, 0.0), Vector3.UP)
	cam.fov = 36.0
	world.add_child(cam)
	
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 45.0, 0.0)
	sun.light_color = Color("ffffff")
	sun.light_energy = 1.6
	world.add_child(sun)
	
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(30.0, -135.0, 0.0)
	fill.light_color = Color("81ecec")
	fill.light_energy = 0.8
	world.add_child(fill)
	
	var mount := Node3D.new()
	world.add_child(mount)
	
	# 1. Render all Cars
	for cid in ALL_CARS:
		for c in mount.get_children():
			c.queue_free()
		await process_frame
		
		var car_node = vab.build_player_car_visuals(cid)
		if car_node:
			mount.add_child(car_node)
			# Isometric rotation for dynamic showcase angle
			car_node.rotation_degrees = Vector3(0.0, 35.0, 0.0)
		
		for f in range(5):
			await process_frame
		
		var img := vp.get_texture().get_image()
		if img:
			var save_path := "res://assets/textures/cars/car_%s.png" % cid
			img.save_png(save_path)
			print("  [RENDERED CAR] %s -> %s" % [cid, save_path])
	
	# 2. Render all Gears
	var gears = [
		{"name": "jet_engine", "node": vab.build_gear_jet_engine()},
		{"name": "wheels", "node": vab.build_gear_wheels()},
		{"name": "wings", "node": vab.build_gear_wings()},
		{"name": "armor", "node": vab.build_gear_armor()},
		{"name": "gadget", "node": vab.build_gear_gadget()},
		{"name": "skin", "node": vab.build_gear_skin()}
	]
	
	for g in gears:
		for c in mount.get_children():
			c.queue_free()
		await process_frame
		
		if g["node"]:
			mount.add_child(g["node"])
			g["node"].rotation_degrees = Vector3(0.0, 150.0, 0.0)
		
		for f in range(5):
			await process_frame
		
		var img := vp.get_texture().get_image()
		if img:
			var save_path := "res://assets/textures/gear/gear_%s.png" % g["name"]
			img.save_png(save_path)
			print("  [RENDERED GEAR] %s -> %s" % [g["name"], save_path])
	
	print("--- FINISHED RENDERING ALL 3D THUMBNAILS ---")
	quit()
