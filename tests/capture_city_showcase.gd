extends SceneTree

const CityGenScene = preload("res://scenes/world/city_generator.tscn")

func _init() -> void:
	await process_frame
	await process_frame
	
	print("\n--- CAPTURING REALISTIC CITY INFRASTRUCTURE SCREENSHOTS ---")
	
	# 1. Setup Showcase Viewport & Camera
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	
	var world := Node3D.new()
	viewport.add_child(world)
	
	# Environment lighting
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("74b9ff") # Crisp daytime blue sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dfe6e9")
	env.ambient_light_energy = 0.8
	env_node.environment = env
	world.add_child(env_node)
	
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 45.0, 0.0)
	sun.light_color = Color("fffaf0")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	
	# City Generator
	var cg := CityGenScene.instantiate() as CityGenerator
	world.add_child(cg)
	
	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 48.0
	world.add_child(camera)
	
	# =========================================================================
	# SHOT 1: Farmland Biome (Red Barn, Silo, Tractor, Windmill, Crops, Hay)
	# =========================================================================
	var farm_chunk := Node3D.new()
	cg._build_farmland_chunk(farm_chunk, RandomNumberGenerator.new(), Vector2i(12, 0))
	world.add_child(farm_chunk)
	
	camera.position = Vector3(58.0, 36.0, 58.0)
	camera.look_at(Vector3(24.0, 3.0, 24.0), Vector3.UP)
	
	for f in range(6):
		await process_frame
	
	var img_farm := viewport.get_texture().get_image()
	img_farm.save_png("farm_showcase.png")
	print("  [SAVED] Farmland showcase screenshot: farm_showcase.png")
	farm_chunk.queue_free()
	
	# =========================================================================
	# SHOT 2: River Arched Bridge & Stone Quays (Isometric View)
	# =========================================================================
	var river_chunk := Node3D.new()
	cg._build_river_arched_bridge(river_chunk, RandomNumberGenerator.new(), Vector2i(0, 3))
	world.add_child(river_chunk)
	
	camera.position = Vector3(52.0, 24.0, 48.0)
	camera.look_at(Vector3(24.0, 0.0, 24.0), Vector3.UP)
	
	for f in range(6):
		await process_frame
	
	var img_river := viewport.get_texture().get_image()
	img_river.save_png("river_bridge_showcase.png")
	print("  [SAVED] River Arched Bridge showcase screenshot: river_bridge_showcase.png")
	river_chunk.queue_free()
	
	# =========================================================================
	# SHOT 3: River Canal Stunt Channel & Flaming Ring Jump
	# =========================================================================
	var canal_chunk := Node3D.new()
	cg._build_river_quay_canal(canal_chunk, RandomNumberGenerator.new(), Vector2i(1, 3))
	world.add_child(canal_chunk)
	
	camera.position = Vector3(50.0, 22.0, 46.0)
	camera.look_at(Vector3(24.0, 0.0, 24.0), Vector3.UP)
	
	for f in range(6):
		await process_frame
	
	var img_canal := viewport.get_texture().get_image()
	img_canal.save_png("river_canal_stunt_showcase.png")
	print("  [SAVED] River Canal Stunt showcase screenshot: river_canal_stunt_showcase.png")
	canal_chunk.queue_free()
	
	# =========================================================================
	# SHOT 4: Railway Corridor, Level Crossing & Moving Freight Train
	# =========================================================================
	var rail_chunk := Node3D.new()
	cg._build_railway_corridor(rail_chunk, RandomNumberGenerator.new(), Vector2i(5, 0))
	world.add_child(rail_chunk)
	
	# Spawn freight train on the tracks
	var vab = cg._get_vab()
	if vab and vab.has_method("build_freight_train_multi_car"):
		var train = vab.build_freight_train_multi_car()
		train.position = Vector3(24.0, 0.0, 24.0)
		rail_chunk.add_child(train)
	
	camera.position = Vector3(52.0, 22.0, 48.0)
	camera.look_at(Vector3(24.0, 2.0, 24.0), Vector3.UP)
	
	for f in range(6):
		await process_frame
	
	var img_rail := viewport.get_texture().get_image()
	img_rail.save_png("railway_train_showcase.png")
	print("  [SAVED] Railway & Freight Train showcase screenshot: railway_train_showcase.png")
	rail_chunk.queue_free()
	
	# =========================================================================
	# SHOT 5: Steel Through-Truss Railway Bridge Crossing River
	# =========================================================================
	var rail_bridge_chunk := Node3D.new()
	cg._build_railway_river_bridge(rail_bridge_chunk, RandomNumberGenerator.new(), Vector2i(5, 3))
	world.add_child(rail_bridge_chunk)
	
	camera.position = Vector3(54.0, 24.0, 50.0)
	camera.look_at(Vector3(24.0, 2.0, 24.0), Vector3.UP)
	
	for f in range(6):
		await process_frame
	
	var img_rail_bridge := viewport.get_texture().get_image()
	img_rail_bridge.save_png("railway_river_bridge_showcase.png")
	print("  [SAVED] Railway River Bridge showcase screenshot: railway_river_bridge_showcase.png")
	rail_bridge_chunk.queue_free()
	
	# =========================================================================
	# SHOT 5: Skyscraper Plaza & Drivable Parking Garage Rooftop Stunt
	# =========================================================================
	var sky_chunk := Node3D.new()
	cg._build_skyscraper_plaza(sky_chunk, RandomNumberGenerator.new(), Vector2i(0, 1))
	world.add_child(sky_chunk)
	
	camera.position = Vector3(56.0, 30.0, 56.0)
	camera.look_at(Vector3(24.0, 6.0, 24.0), Vector3.UP)
	
	for f in range(6):
		await process_frame
	
	var img_sky := viewport.get_texture().get_image()
	img_sky.save_png("skyscraper_garage_showcase.png")
	print("  [SAVED] Skyscraper Plaza & Parking Garage showcase screenshot: skyscraper_garage_showcase.png")
	sky_chunk.queue_free()
	
	print("\nALL SHOWCASE SCREENSHOTS GENERATED SUCCESSFULLY!")
	quit(0)
