extends SceneTree

const MainGameScene = preload("res://scenes/world/main_game.tscn")

func _init() -> void:
	print("\n=======================================================")
	print("   TESTING SMASHY KART ROAD TRACK & 3RD PERSON CAMERA  ")
	print("=======================================================\n")
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
	
	for i in range(10):
		await process_frame
	
	# -------------------------------------------------------------------------
	# 1. VERIFY ROAD TRACK MESH & GROUND
	# -------------------------------------------------------------------------
	print("--- TEST 1: ROAD TRACK MESH & GROUND VISIBILITY ---")
	var kart_mode = game.smashy_kart_mode
	assert(kart_mode != null, "SmashyKartMode must exist")
	
	var builder = kart_mode.track_builder
	assert(builder != null, "KartTrackBuilder must exist")
	
	var ground = builder.find_child("KartTrackGround", true, false) as MeshInstance3D
	assert(ground != null, "KartTrackGround must exist")
	assert(ground.mesh != null, "Ground mesh must be generated")
	assert(ground.visible, "Ground must be visible")
	print("  [PASS] Scenic Ground Plane verified: %s (size %s)" % [ground.name, str((ground.mesh as PlaneMesh).size)])
	
	var road_body = builder.find_child("RoadSurfaceBody", true, false)
	assert(road_body != null, "RoadSurfaceBody must exist")
	
	var road_mesh_inst: MeshInstance3D = null
	for c in road_body.get_children():
		if c is MeshInstance3D and c.name != "DashLines" and not "curb" in c.name.to_lower():
			road_mesh_inst = c
			break
	
	assert(road_mesh_inst != null, "Road surface MeshInstance3D must exist")
	assert(road_mesh_inst.mesh != null, "Road surface mesh must be committed")
	assert(road_mesh_inst.mesh.get_surface_count() > 0, "Road mesh must have at least 1 surface")
	
	var rmat = road_mesh_inst.material_override as StandardMaterial3D
	assert(rmat != null, "Road material must exist")
	assert(rmat.cull_mode == BaseMaterial3D.CULL_DISABLED, "Road material must have cull_mode DISABLED to prevent invisible culling (found %d)" % rmat.cull_mode)
	print("  [PASS] Road Mesh verified with %d vertices, cull_mode=CULL_DISABLED (visible from all angles)" % road_mesh_inst.mesh.get_faces().size())
	
	# -------------------------------------------------------------------------
	# 2. VERIFY 3RD PERSON BACK CHASE CAMERA
	# -------------------------------------------------------------------------
	print("\n--- TEST 2: 3RD PERSON BACK CHASE CAMERA ---")
	var cam_rig: CameraRig = game.camera_rig
	assert(cam_rig != null, "CameraRig must exist")
	assert(cam_rig.mode == "KART_CHASE", "CameraRig mode must be KART_CHASE (found %s)" % cam_rig.mode)
	print("  [PASS] CameraRig mode set to KART_CHASE")
	
	var cam: Camera3D = cam_rig.camera
	assert(cam != null, "Camera3D must exist in rig")
	
	var car = game.arcade_car
	assert(car != null, "Player car must exist")
	
	# Let physics process 10 frames to settle camera behind car
	for i in range(15):
		await process_frame
	
	var car_pos: Vector3 = car.car_pivot.global_position if car.car_pivot else car.global_position
	var cam_pos: Vector3 = cam.global_position
	var car_fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized() if car.car_pivot else -car.global_transform.basis.z.normalized()
	
	# Vector from car to camera
	var to_cam: Vector3 = cam_pos - car_pos
	var dist_behind: float = to_cam.dot(-car_fwd) # Dot with backward vector
	var height_above: float = cam_pos.y - car_pos.y
	
	print("  Camera global pos: %s, Car pos: %s" % [str(cam_pos), str(car_pos)])
	print("  Camera distance behind car: %.2fm (expected 5.0m - 9.0m)" % dist_behind)
	print("  Camera height above car: %.2fm (expected 1.8m - 3.5m)" % height_above)
	print("  Camera FOV: %.1f deg (expected 58 - 72 deg)" % cam.fov)
	
	assert(dist_behind > 4.5 and dist_behind < 10.0, "Camera must be positioned BEHIND the car (found %.2fm)" % dist_behind)
	assert(height_above > 1.2 and height_above < 4.0, "Camera must be elevated ABOVE the car (found %.2fm)" % height_above)
	assert(cam.fov >= 55.0 and cam.fov <= 75.0, "Camera FOV must match 3rd-person chase racing FOV")
	print("  [PASS] 3rd Person Back View Camera verified!")
	
	# -------------------------------------------------------------------------
	# 3. VERIFY CAMERA ROTATES BEHIND CAR ON TURNING
	# -------------------------------------------------------------------------
	print("\n--- TEST 3: CAMERA CHASE ROTATION TRACKING ---")
	# Rotate car 90 degrees
	var initial_yaw: float = cam_rig._kart_cam_yaw
	if car.car_pivot:
		car.car_pivot.rotation.y += PI * 0.5
	
	# Let camera catch up
	for i in range(30):
		await process_frame
	
	var new_yaw: float = cam_rig._kart_cam_yaw
	var yaw_diff: float = absf(angle_difference(initial_yaw, new_yaw))
	print("  Yaw difference after 90 deg turn: %.2f rad (%.1f deg)" % [yaw_diff, rad_to_deg(yaw_diff)])
	assert(yaw_diff > 0.8, "Camera yaw must track car rotation smoothly")
	print("  [PASS] Camera follows car heading around curves!")
	
	# -------------------------------------------------------------------------
	# 4. RESET TO MODE 0 & VERIFY CAMERA RESTORES TO FOLLOW
	# -------------------------------------------------------------------------
	print("\n--- TEST 4: MODE SWITCH RESTORES FOLLOW CAMERA ---")
	game.start_solo_daily_mode()
	await process_frame
	await process_frame
	assert(cam_rig.mode == "FOLLOW", "CameraRig mode must restore to FOLLOW for solo daily getaway (found %s)" % cam_rig.mode)
	print("  [PASS] Camera restored to isometric FOLLOW on mode change")
	
	print("\n=======================================================")
	print("   ALL ROAD TRACK & 3RD PERSON CAMERA TESTS PASSED!    ")
	print("=======================================================\n")
	quit(0)
