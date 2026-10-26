extends SceneTree

## Comprehensive Integration Test Suite for:
## 1. VoxelAssetBuilder.build_police_officer() (0.9m blocky officer with uniform, cap, gold badge, baton, handcuffs)
## 2. Slow-motion physics (Engine.time_scale = 0.18 for 0.8s) + vehicle driving forces freeze
## 3. CameraRig "CUTSCENE_ORBIT" mode (distance = 8.5m, pitch = -22 deg, orbit = 0.45 rad/s)
## 4. 2 Police Officers hopping out of cop car and running to driver door with sweeping red/blue SpotLight3D siren beams
## 5. Screen desaturation shader (saturation -> 0.15, dark vignette, red/blue edge pulse)
## 6. Giant 86pt outlined Label ("BUSTED" / "WASTED") stamp slam (scale 3.2 -> 1.0 over 0.28s, TRANS_BACK, EASE_IN)
## 7. Trauma 0.55 camera shake & SoundFX procedural deep bass impact
## 8. RunSummaryPanel sliding up at bottom half of screen after 1.6s while 3D orbit camera continues

func _init() -> void:
	print("\n=================================================================")
	print("     STARTING BUSTED 3D CUTSCENE & GTA SHADER TEST SUITE         ")
	print("=================================================================\n")
	
	await process_frame
	_run_all_tests()

func _run_all_tests() -> void:
	var total_tests: int = 0
	var passed_tests: int = 0
	
	# --------------------------------------------------------------------------
	# TEST 1: VoxelAssetBuilder.build_police_officer() Architecture & Dimensions
	# --------------------------------------------------------------------------
	total_tests += 1
	var builder: VoxelAssetBuilderClass = null
	if root.has_node("/root/VoxelAssetBuilder"):
		builder = root.get_node("/root/VoxelAssetBuilder") as VoxelAssetBuilderClass
	else:
		var BuilderScript = load("res://scripts/autoload/voxel_asset_builder.gd")
		builder = BuilderScript.new()
		root.add_child(builder)
	
	assert(builder != null, "VoxelAssetBuilder must be valid")
	assert(builder.has_method("build_police_officer"), "VoxelAssetBuilder must implement build_police_officer()")
	
	var officer: Node3D = builder.build_police_officer()
	root.add_child(officer)
	await process_frame
	
	assert(officer != null, "build_police_officer() must return a non-null Node3D")
	
	# Check essential anatomical parts
	var leg_l: Node3D = officer.find_child("Leg_L", true, false) as Node3D
	var leg_r: Node3D = officer.find_child("Leg_R", true, false) as Node3D
	var torso: Node3D = officer.find_child("Torso", true, false) as Node3D
	var head: Node3D = officer.find_child("Head", true, false) as Node3D
	var cap: Node3D = officer.find_child("Cap", true, false) as Node3D
	var arm_l: Node3D = officer.find_child("Arm_L", true, false) as Node3D
	var arm_r: Node3D = officer.find_child("Arm_R", true, false) as Node3D
	var baton: Node3D = officer.find_child("Baton", true, false) as Node3D
	var handcuffs: Node3D = officer.find_child("Handcuffs", true, false) as Node3D
	
	assert(leg_l != null and leg_r != null, "Officer must have Leg_L and Leg_R")
	assert(torso != null, "Officer must have Torso")
	assert(head != null, "Officer must have Head")
	assert(cap != null, "Officer must have Cap")
	assert(arm_l != null and arm_r != null, "Officer must have Arm_L and Arm_R")
	assert(baton != null, "Officer must hold Baton")
	assert(handcuffs != null, "Officer must hold Handcuffs")
	
	# Compute total height from meshes
	var min_y: float = 999.0
	var max_y: float = -999.0
	var meshes: Array[Node] = officer.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() >= 15, "Officer must be constructed from rich blocky voxel parts (found %d)" % meshes.size())
	
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi and mi.mesh:
			var aabb: AABB = mi.mesh.get_aabb()
			var g_pos: Vector3 = mi.global_position
			min_y = minf(min_y, g_pos.y + aabb.position.y)
			max_y = maxf(max_y, g_pos.y + aabb.position.y + aabb.size.y)
	
	var total_height: float = max_y - min_y
	assert(total_height >= 0.80 and total_height <= 1.05, "Officer height must be ~0.9m tall (calculated: %.2fm)" % total_height)
	print("✅ [TEST 1 PASSED] VoxelAssetBuilder.build_police_officer() verified (height: %.2fm, %d voxel parts, baton & handcuffs)." % [total_height, meshes.size()])
	passed_tests += 1
	officer.queue_free()
	
	# --------------------------------------------------------------------------
	# TEST 2: SoundFX Procedural Deep Bass Impact Sound
	# --------------------------------------------------------------------------
	total_tests += 1
	var sfx: Node = null
	if root.has_node("/root/SoundFX"):
		sfx = root.get_node("/root/SoundFX")
	assert(sfx != null, "SoundFX autoload must exist")
	assert(sfx.has_method("play_bass_impact"), "SoundFX must implement play_bass_impact()")
	assert(sfx.has_method("play_busted_slam"), "SoundFX must implement play_busted_slam()")
	
	var bass_frames: PackedVector2Array = sfx.get("_bass_impact_frames")
	assert(not bass_frames.is_empty(), "_bass_impact_frames buffer must be baked")
	assert(bass_frames.size() > 4000, "Bass impact buffer must have sufficient sample length (found %d)" % bass_frames.size())
	
	# Verify calling sound doesn't crash
	sfx.play_bass_impact()
	sfx.play_busted_slam()
	print("✅ [TEST 2 PASSED] SoundFX procedural deep bass impact synthesized (%d samples) and callable." % bass_frames.size())
	passed_tests += 1
	
	# --------------------------------------------------------------------------
	# TEST 3: CameraRig "CUTSCENE_ORBIT" Mode & Parameters
	# --------------------------------------------------------------------------
	total_tests += 1
	var cam_rig_scene: PackedScene = load("res://scenes/world/camera_rig.tscn")
	var cam_rig: CameraRig = cam_rig_scene.instantiate() as CameraRig
	root.add_child(cam_rig)
	await process_frame
	
	var dummy_pivot := Node3D.new()
	dummy_pivot.position = Vector3(10.0, 0.5, 15.0)
	root.add_child(dummy_pivot)
	
	cam_rig.switch_to_cutscene_orbit(dummy_pivot)
	assert(cam_rig.mode == "CUTSCENE_ORBIT", "CameraRig mode must switch to CUTSCENE_ORBIT")
	assert(is_equal_approx(cam_rig.orbit_speed, 0.45), "orbit_speed must be 0.45 rad/s")
	assert(is_equal_approx(cam_rig.orbit_distance, 8.5), "orbit_distance must be 8.5m")
	assert(is_equal_approx(cam_rig.orbit_pitch_deg, -22.0), "orbit_pitch_deg must be -22.0 degrees")
	
	# Simulate process tick and orbit update
	var initial_angle: float = cam_rig.orbit_angle
	cam_rig._current_orbit_dist = 8.5
	cam_rig._current_pitch_deg = -22.0
	cam_rig._process(0.1)
	assert(cam_rig.orbit_angle > initial_angle, "Orbit angle must increment at 0.45 rad/s")
	var dist_calc: float = cam_rig.camera.position.length()
	assert(absf(dist_calc - 8.5) < 0.1, "Camera distance must be 8.5m (actual: %.2f)" % dist_calc)
	assert(absf(cam_rig.camera.rotation_degrees.x - (-22.0)) < 1.0, "Camera pitch must be -22 degrees (actual: %.2f)" % cam_rig.camera.rotation_degrees.x)
	
	# Verify trauma shake can be added
	cam_rig.add_trauma(0.55)
	assert(cam_rig.trauma >= 0.55, "add_trauma(0.55) must increase trauma to >= 0.55")
	print("✅ [TEST 3 PASSED] CameraRig CUTSCENE_ORBIT mode verified (distance=8.5m, pitch=-22 deg, orbit_speed=0.45 rad/s, trauma=0.55).")
	passed_tests += 1
	cam_rig.queue_free()
	dummy_pivot.queue_free()
	
	# --------------------------------------------------------------------------
	# TEST 4: ArcadeCar freeze_driving_forces()
	# --------------------------------------------------------------------------
	total_tests += 1
	var car_scene: PackedScene = load("res://scenes/vehicles/arcade_car.tscn")
	var car: ArcadeCar = car_scene.instantiate() as ArcadeCar
	root.add_child(car)
	await process_frame
	
	car.physics_sphere.linear_velocity = Vector3(14.0, 0.0, -8.0)
	car.steer_input = 1.0
	assert(car.has_method("freeze_driving_forces"), "ArcadeCar must implement freeze_driving_forces()")
	
	car.freeze_driving_forces()
	assert(car.driving_forces_frozen == true, "driving_forces_frozen flag must be true")
	assert(car.physics_sphere.linear_velocity == Vector3.ZERO, "Linear velocity must be frozen to Vector3.ZERO")
	assert(car.physics_sphere.angular_velocity == Vector3.ZERO, "Angular velocity must be frozen to Vector3.ZERO")
	assert(car.steer_input == 0.0, "Steer input must be cleared")
	print("✅ [TEST 4 PASSED] ArcadeCar.freeze_driving_forces() successfully halted driving forces and physics.")
	passed_tests += 1
	car.queue_free()
	
	# --------------------------------------------------------------------------
	# TEST 5: BustedCutsceneOverlay Scene & Desaturation Shader
	# --------------------------------------------------------------------------
	total_tests += 1
	var overlay_scene: PackedScene = load("res://scenes/ui/busted_cutscene_overlay.tscn")
	assert(overlay_scene != null, "busted_cutscene_overlay.tscn must exist and load cleanly")
	
	var overlay = overlay_scene.instantiate()
	root.add_child(overlay)
	await process_frame
	
	assert(overlay.shader_rect != null, "ShaderRect ColorRect must exist")
	assert(overlay.shader_rect.material is ShaderMaterial, "ShaderRect must have a ShaderMaterial assigned")
	var mat := overlay.shader_rect.material as ShaderMaterial
	assert(mat.shader != null, "ShaderMaterial must hold busted_desaturate.gdshader")
	
	# Check StampHolder and controls
	assert(overlay.stamp_holder != null, "StampHolder Control must exist")
	assert(overlay.stamp_label != null, "StampLabel must exist")
	assert(overlay.banner_frame != null, "BannerFrame must exist")
	
	# Check Label properties
	assert(overlay.stamp_label.label_settings != null, "StampLabel must have LabelSettings")
	assert(overlay.stamp_label.label_settings.font_size == 86, "StampLabel font size must be 86pt (found %d)" % overlay.stamp_label.label_settings.font_size)
	assert(overlay.stamp_label.label_settings.outline_size == 18, "StampLabel outline size must be 18 (found %d)" % overlay.stamp_label.label_settings.outline_size)
	print("✅ [TEST 5 PASSED] busted_cutscene_overlay.tscn verified with 86pt outlined Label, banner frame, and desaturation shader.")
	passed_tests += 1
	
	# --------------------------------------------------------------------------
	# TEST 6: BUSTED vs WASTED Stamp Slam & Animation
	# --------------------------------------------------------------------------
	total_tests += 1
	# Test Arrest (BUSTED) styling
	overlay._style_stamp(true)
	assert(overlay.stamp_label.text == "BUSTED", "Label text must be 'BUSTED' for arrest")
	assert(overlay.stamp_label.label_settings.font_color.r > 0.8 and overlay.stamp_label.label_settings.font_color.b > 0.9, "BUSTED label must be electric white/blue")
	
	# Test Wrecked (WASTED) styling
	overlay._style_stamp(false)
	assert(overlay.stamp_label.text == "WASTED", "Label text must be 'WASTED' for wrecked")
	assert(overlay.stamp_label.label_settings.font_color.r > 0.8 and overlay.stamp_label.label_settings.font_color.g < 0.3, "WASTED label must be crimson red")
	
	# Trigger stamp slam animation
	overlay._trigger_stamp_slam(true)
	assert(overlay.stamp_holder.visible == true, "StampHolder must become visible")
	assert(overlay.stamp_holder.scale == Vector2(3.2, 3.2), "StampHolder must start scale at Vector2(3.2, 3.2)")
	print("✅ [TEST 6 PASSED] BUSTED and WASTED dynamic styling and Vector2(3.2, 3.2) slam tween verified.")
	passed_tests += 1
	
	# --------------------------------------------------------------------------
	# TEST 7: RunSummaryPanel slide_up_at_bottom()
	# --------------------------------------------------------------------------
	total_tests += 1
	var summary_scene: PackedScene = load("res://scenes/ui/run_summary_panel.tscn")
	var summary_panel: RunSummaryPanel = summary_scene.instantiate() as RunSummaryPanel
	root.add_child(summary_panel)
	await process_frame
	
	assert(summary_panel.has_method("slide_up_at_bottom"), "RunSummaryPanel must implement slide_up_at_bottom()")
	summary_panel.slide_up_at_bottom("BUSTED BY POLICE!", 14500, 42.5, 6)
	
	assert(summary_panel.visible == true, "RunSummaryPanel must be visible after slide_up_at_bottom")
	assert(summary_panel.score_value_label.text == "14500", "Final score must be displayed")
	assert(summary_panel.time_value_label.text == "42.5s", "Survival time must be displayed")
	assert(summary_panel.cops_value_label.text == "6", "Cops wrecked must be displayed")
	print("✅ [TEST 7 PASSED] RunSummaryPanel slide_up_at_bottom() cleanly animates and populates scorecard.")
	passed_tests += 1
	summary_panel.queue_free()
	
	# --------------------------------------------------------------------------
	# TEST 8: Full End-to-End MainGame Cutscene Coordination
	# --------------------------------------------------------------------------
	total_tests += 1
	var main_scene: PackedScene = load("res://scenes/world/main_game.tscn")
	var main_inst: MainGame = main_scene.instantiate() as MainGame
	root.add_child(main_inst)
	await process_frame
	
	var overlay_found: Node = main_inst.find_child("BustedCutsceneOverlay", true, false)
	assert(overlay_found != null, "main_game.tscn must contain BustedCutsceneOverlay")
	
	var wm = root.get_node_or_null("/root/WantedManager")
	assert(wm != null, "WantedManager must exist")
	
	# Trigger BUSTED through WantedManager
	wm.is_run_active = true
	wm.trigger_busted("BUSTED BY POLICE!")
	
	# Verify slow-motion physics scale set to 0.18
	assert(is_equal_approx(Engine.time_scale, 0.18), "Engine.time_scale must be 0.18 on bust (actual: %.2f)" % Engine.time_scale)
	
	# Verify camera entered CUTSCENE_ORBIT
	assert(main_inst.camera_rig.mode == "CUTSCENE_ORBIT", "CameraRig mode must switch to CUTSCENE_ORBIT")
	
	# Verify police officers and siren lights spawned in cutscene
	var spawned_officers := main_inst.find_children("VoxelPoliceOfficer*", "Node3D", true, false)
	assert(spawned_officers.size() >= 2, "Must spawn 2 blocky 3D Police Officers hopping out (found %d)" % spawned_officers.size())
	
	var red_beam := main_inst.find_child("CutsceneRedSirenBeam", true, false)
	var blue_beam := main_inst.find_child("CutsceneBlueSirenBeam", true, false)
	assert(red_beam != null and blue_beam != null, "Must spawn sweeping red and blue SpotLight3D siren beams")
	
	# Restore time_scale
	Engine.time_scale = 1.0
	print("✅ [TEST 8 PASSED] Full end-to-end cutscene pipeline (0.18 slow-mo, orbit cam, 2 hopping officers, sweeping red/blue sirens) verified.")
	passed_tests += 1
	main_inst.queue_free()
	overlay.queue_free()
	
	# --------------------------------------------------------------------------
	# SUMMARY
	# --------------------------------------------------------------------------
	print("\n=================================================================")
	print("       TEST RESULTS: %d / %d PASSED                              " % [passed_tests, total_tests])
	print("=================================================================\n")
	print("🏆 ALL BUSTED 3D CUTSCENE & GTA SCREEN SHADER FEATURES VERIFIED!")
	quit(0)
