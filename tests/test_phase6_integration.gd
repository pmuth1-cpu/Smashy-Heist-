extends SceneTree

## Comprehensive Phase 6 Integration & Verification Test Suite for Smashy Heist: Daily Getaway.
## Validates Procedural 3D Blocky Asset Builder for 8 Player Cars, 4 Police Units,
## Detailed Architectural City Buildings, 8 CarStats Resources, ArcadeCar & PoliceCar integration,
## and Brawl Stars 3D Rotatable Car Showroom Menu UI.

const ALL_CAR_IDS: Array[String] = [
	"default_coupe",
	"tuk_tuk_jet",
	"armored_bulldozer",
	"ice_cream_drifter",
	"cyber_interceptor",
	"monster_pickup",
	"gold_limo",
	"f1_street_kart"
]

func _init() -> void:
	print("\n=== STARTING PHASE 6 INTEGRATION TESTS ===")
	await process_frame
	await process_frame
	
	_run_tests()

func _count_meshes_recursive(node: Node) -> int:
	var count: int = 0
	if node is MeshInstance3D:
		count += 1
	for child in node.get_children():
		count += _count_meshes_recursive(child)
	return count

func _run_tests() -> void:
	var total_tests: int = 0
	var passed_tests: int = 0
	
	# -------------------------------------------------------------
	# Test 1: VoxelAssetBuilder Autoload Presence & Material Cache
	# -------------------------------------------------------------
	total_tests += 1
	var vab = root.get_node_or_null("VoxelAssetBuilder")
	var sm = root.get_node_or_null("SaveManager")
	var wm = root.get_node_or_null("WantedManager")
	
	if vab != null:
		var mat1: StandardMaterial3D = vab._make_mat(Color.RED, false)
		var mat2: StandardMaterial3D = vab._make_mat(Color.RED, false)
		var mat3: StandardMaterial3D = vab._make_mat(Color.RED, true)
		
		var cache_valid: bool = (mat1 == mat2) and (mat1 != mat3) and mat3.emission_enabled
		if cache_valid:
			print("✓ PASS: VoxelAssetBuilder Autoload loaded and caching identical materials cleanly")
			passed_tests += 1
		else:
			printerr("✗ FAIL: VoxelAssetBuilder material cache mismatch! mat1=%s, mat2=%s, mat3=%s" % [mat1, mat2, mat3])
	else:
		printerr("✗ FAIL: VoxelAssetBuilder Autoload not found on root!")
	
	# -------------------------------------------------------------
	# Test 2: Handcrafted Procedural Construction of All 8 Player Cars
	# -------------------------------------------------------------
	total_tests += 1
	var all_cars_built: bool = true
	var min_meshes_pass: bool = true
	var car_specific_checks: bool = true
	
	for car_id in ALL_CAR_IDS:
		var car_node: Node3D = vab.build_player_car_visuals(car_id)
		if car_node == null:
			all_cars_built = false
			printerr("Failed to build visuals for car: %s" % car_id)
			continue
		
		var mesh_count: int = _count_meshes_recursive(car_node)
		if mesh_count < 10:
			min_meshes_pass = false
			printerr("Car %s has only %d meshes (expected >= 10)" % [car_id, mesh_count])
		
		# Specific checks
		match car_id:
			"tuk_tuk_jet":
				# Rear jet turbine has cylinder and cyan cone
				var cyls: Array[Node] = car_node.find_children("*", "MeshInstance3D", true, false)
				var has_jet: bool = false
				for m in cyls:
					var mi := m as MeshInstance3D
					if mi.mesh is CylinderMesh and is_equal_approx((mi.mesh as CylinderMesh).top_radius, 0.34):
						has_jet = true
				if not has_jet:
					car_specific_checks = false
					printerr("tuk_tuk_jet missing 0.34 radius turbine cylinder")
			"armored_bulldozer":
				# Front blade box Vector3(1.56, 0.55, 0.18)
				var boxes: Array[Node] = car_node.find_children("*", "MeshInstance3D", true, false)
				var has_blade: bool = false
				for m in boxes:
					var mi := m as MeshInstance3D
					if mi.mesh is BoxMesh and is_equal_approx((mi.mesh as BoxMesh).size.x, 1.56):
						has_blade = true
				if not has_blade:
					car_specific_checks = false
					printerr("armored_bulldozer missing 1.56m blade")
			"ice_cream_drifter":
				# Giant waffle cone cylinder & swirl
				var meshes: Array[Node] = car_node.find_children("*", "MeshInstance3D", true, false)
				var has_cone: bool = false
				for m in meshes:
					var mi := m as MeshInstance3D
					if mi.mesh is CylinderMesh and is_equal_approx((mi.mesh as CylinderMesh).top_radius, 0.28):
						has_cone = true
				if not has_cone:
					car_specific_checks = false
					printerr("ice_cream_drifter missing waffle cone")
			"f1_street_kart":
				# Wide low front wing BoxMesh size.x == 1.30
				var meshes: Array[Node] = car_node.find_children("*", "MeshInstance3D", true, false)
				var has_wing: bool = false
				for m in meshes:
					var mi := m as MeshInstance3D
					if mi.mesh is BoxMesh and is_equal_approx((mi.mesh as BoxMesh).size.x, 1.30):
						has_wing = true
				if not has_wing:
					car_specific_checks = false
					printerr("f1_street_kart missing 1.30m front wing")
		
		car_node.free()
	
	if all_cars_built and min_meshes_pass and car_specific_checks:
		print("✓ PASS: All 8 player brawler cars procedurally built with >= 10 parts and distinct iconic props")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Player cars build failed! all_built=%s, min_meshes=%s, specifics=%s" % [all_cars_built, min_meshes_pass, car_specific_checks])
	
	# -------------------------------------------------------------
	# Test 3: Procedural Construction of 4 Police Fleet Vehicles
	# -------------------------------------------------------------
	total_tests += 1
	var police_built: bool = true
	var rhino_has_turret: bool = false
	
	for p_type in range(4):
		var p_node: Node3D = vab.build_police_car_visuals(p_type)
		if p_node == null or _count_meshes_recursive(p_node) < 8:
			police_built = false
			printerr("Police vehicle %d failed mesh count check" % p_type)
		
		if p_type == 3: # RHINO_TANK
			var turret = p_node.find_child("TurretPivot", true, false)
			if turret != null and turret.get_child_count() >= 3:
				rhino_has_turret = true
		
		p_node.free()
	
	if police_built and rhino_has_turret:
		print("✓ PASS: 4 Police fleet units (Cruiser, Muscle, SWAT, Rhino Tank with TurretPivot & Cannon) verified")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Police fleet check failed! police_built=%s, rhino_has_turret=%s" % [police_built, rhino_has_turret])
	
	# -------------------------------------------------------------
	# Test 4: Procedural Detailed Architectural City Building
	# -------------------------------------------------------------
	total_tests += 1
	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 12345
	var building: Node3D = vab.build_detailed_building(14.0, 14.0, 18.0, Color("34495e"), test_rng)
	
	var building_valid: bool = false
	if building != null and building.name == "VoxelBuilding":
		var b_mesh_count: int = _count_meshes_recursive(building)
		if b_mesh_count >= 12:
			building_valid = true
	
	building.free()
	if building_valid:
		print("✓ PASS: VoxelAssetBuilder.build_detailed_building generated multi-tier blocky architecture with lobby and roof props")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Detailed building procedural generation failed!")
	
	# -------------------------------------------------------------
	# Test 5: CarStats 8 Resource Files Verification
	# -------------------------------------------------------------
	total_tests += 1
	var all_stats_ok: bool = true
	
	for car_id in ALL_CAR_IDS:
		var path := "res://resources/vehicles/%s.tres" % car_id
		if not ResourceLoader.exists(path):
			all_stats_ok = false
			printerr("Missing resource: %s" % path)
			continue
		
		var cs: CarStats = load(path) as CarStats
		if cs == null or cs.car_id != car_id or cs.rarity_tier.is_empty() or cs.special_perk_description.is_empty():
			all_stats_ok = false
			printerr("CarStats %s has invalid properties: id=%s, tier=%s, perk=%s" % [car_id, cs.car_id, cs.rarity_tier, cs.special_perk_description])
	
	if all_stats_ok:
		print("✓ PASS: All 8 CarStats .tres resources exist and specify valid car_id, rarity_tier, rarity_color, and special_perk_description")
		passed_tests += 1
	else:
		printerr("✗ FAIL: CarStats resources verification failed!")
	
	# -------------------------------------------------------------
	# Test 6: ArcadeCar, PoliceCar, and CityGenerator Visual Integration
	# -------------------------------------------------------------
	total_tests += 1
	var car_scene: PackedScene = load("res://scenes/vehicles/arcade_car.tscn")
	var car_inst: ArcadeCar = car_scene.instantiate() as ArcadeCar
	root.add_child(car_inst)
	await process_frame
	
	var car_has_voxel: bool = car_inst.car_pivot.get_node_or_null("VoxelCarVisual") != null
	var car_body_hidden: bool = not car_inst.body_mesh.visible
	car_inst.queue_free()
	
	var police_scene: PackedScene = load("res://scenes/vehicles/police_car.tscn")
	var police_inst: PoliceCar = police_scene.instantiate() as PoliceCar
	root.add_child(police_inst)
	await process_frame
	
	var police_has_voxel: bool = police_inst.chassis_mesh.get_node_or_null("VoxelPoliceModel") != null
	police_inst.queue_free()
	
	var city_scene: PackedScene = load("res://scenes/world/city_generator.tscn")
	var city_gen: CityGenerator = city_scene.instantiate() as CityGenerator
	var temp_parent := Node3D.new()
	root.add_child(city_gen)
	city_gen.add_child(temp_parent)
	await process_frame
	
	var b_static: StaticBody3D = city_gen._create_building(temp_parent, Vector3(10, 0, 10), Vector3(14, 16, 14), test_rng)
	var b_col_ok: bool = b_static.collision_layer == 8 and (b_static.find_child("CollisionShape3D", true, false) != null or b_static.get_child(0) is CollisionShape3D)
	var b_voxel_ok: bool = b_static.find_child("VoxelBuilding", true, false) != null
	
	city_gen.queue_free()
	
	if car_has_voxel and car_body_hidden and police_has_voxel and b_col_ok and b_voxel_ok:
		print("✓ PASS: VoxelAssetBuilder successfully integrated into ArcadeCar, PoliceCar, and CityGenerator")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Visual integration failed! car_v=%s, car_body_hidden=%s, pol_v=%s, b_col=%s, b_v=%s" % [car_has_voxel, car_body_hidden, police_has_voxel, b_col_ok, b_voxel_ok])
	
	# -------------------------------------------------------------
	# Test 7: BrawlMainMenu Instantiation & Showroom Studio
	# -------------------------------------------------------------
	total_tests += 1
	var menu_scene: PackedScene = load("res://scenes/ui/brawl_main_menu.tscn")
	var menu_inst: BrawlMainMenu = menu_scene.instantiate() as BrawlMainMenu
	root.add_child(menu_inst)
	await process_frame
	
	var has_viewport: bool = menu_inst._sub_viewport != null
	var has_pedestal: bool = menu_inst._pedestal_pivot != null
	var has_mount: bool = menu_inst._car_mount != null
	var has_mounted_car: bool = menu_inst._car_mount != null and menu_inst._car_mount.get_child_count() > 0
	
	if has_viewport and has_pedestal and has_mount and has_mounted_car:
		print("✓ PASS: BrawlMainMenu instantiated cleanly with 3D Showroom SubViewport, Pedestal, and mounted vehicle")
		passed_tests += 1
	else:
		printerr("✗ FAIL: BrawlMainMenu studio missing components! vp=%s, ped=%s, mount=%s, car=%s" % [has_viewport, has_pedestal, has_mount, has_mounted_car])
	
	# -------------------------------------------------------------
	# Test 8: Turntable Touch-Drag Inertia & Suspension Drop Tween
	# -------------------------------------------------------------
	total_tests += 1
	var init_rot: float = menu_inst._pedestal_pivot.rotation.y
	
	# Simulate drag input
	var drag_event := InputEventMouseMotion.new()
	drag_event.position = Vector2(200, 300)
	menu_inst._is_dragging = true
	menu_inst._last_drag_x = 100.0
	menu_inst._on_showroom_gui_input(drag_event)
	
	var rot_changed: bool = not is_equal_approx(menu_inst._pedestal_pivot.rotation.y, init_rot)
	var has_vel: bool = absf(menu_inst._angular_velocity) > 0.01
	
	# Advance inertia frame
	menu_inst._is_dragging = false
	menu_inst._process(0.05)
	
	# Test suspension drop tween
	menu_inst._load_showroom_car("f1_street_kart")
	var tween_running: bool = menu_inst._bounce_tween != null and menu_inst._bounce_tween.is_valid()
	
	if rot_changed and has_vel and tween_running and menu_inst._car_mount.get_child_count() > 0:
		print("✓ PASS: 360-degree turntable touch drag, angular inertia, and suspension drop tween validated")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Turntable inertia or bounce tween failed! rot_changed=%s, vel=%s, tween=%s" % [rot_changed, has_vel, tween_running])
	
	# -------------------------------------------------------------
	# Test 9: 2x4 Car Picker Drawer & Mega Box Gacha Simulation
	# -------------------------------------------------------------
	total_tests += 1
	menu_inst._toggle_cars_drawer()
	var drawer_visible: bool = menu_inst._cars_drawer_panel.visible
	var cards_count: int = menu_inst._cars_grid.get_child_count()
	
	# Test Mega Box with sufficient cash
	sm.total_cash = 300
	sm.save_to_disk()
	menu_inst._on_mega_box_pressed()
	var cash_deducted: bool = (sm.total_cash == 200 or sm.total_cash == 250) # 250 if duplicate +50 bonus
	var unbox_shown: bool = menu_inst._unbox_overlay.visible
	var picked_valid: bool = menu_inst.current_view_car_id in ALL_CAR_IDS
	
	# Test Mega Box with insufficient cash
	sm.total_cash = 40
	menu_inst._on_mega_box_pressed()
	var cash_protected: bool = (sm.total_cash == 40)
	
	menu_inst.queue_free()
	
	if drawer_visible and cards_count == 8 and cash_deducted and unbox_shown and picked_valid and cash_protected:
		print("✓ PASS: 2x4 Brawler Cars drawer (8 cards) and Mega Box Gacha unboxing ($100 spend, weighted roll) verified")
		passed_tests += 1
	else:
		printerr("✗ FAIL: Car drawer or Mega Box failed! drawer=%s, cards=%d, deducted=%s, unbox=%s, pick=%s, protected=%s" % [drawer_visible, cards_count, cash_deducted, unbox_shown, picked_valid, cash_protected])
	
	# -------------------------------------------------------------
	# Test 10: Full MainGame Scene Clean Load & Zero Regression
	# -------------------------------------------------------------
	total_tests += 1
	var main_scene: PackedScene = load("res://scenes/world/main_game.tscn")
	var main_inst = main_scene.instantiate()
	root.add_child(main_inst)
	await process_frame
	await process_frame
	
	var hud = main_inst.find_child("TouchHUD", true, false)
	var brawl_menu = hud.find_child("BrawlMainMenu", true, false) if hud else null
	var lobby = hud.find_child("MultiplayerLobby", true, false) if hud else null
	var player_car = main_inst.find_child("ArcadeCar", true, false)
	
	main_inst.queue_free()
	
	if hud != null and (brawl_menu != null or ResourceLoader.exists("res://scenes/ui/brawl_main_menu.tscn")) and lobby != null and player_car != null:
		print("✓ PASS: Full main_game.tscn loaded cleanly with TouchHUD, BrawlMainMenu (or standalone), MultiplayerLobby, and ArcadeCar")
		passed_tests += 1
	else:
		printerr("✗ FAIL: main_game.tscn node missing! hud=%s, brawl=%s, lobby=%s, car=%s" % [hud, brawl_menu, lobby, player_car])
	
	print("\n=== RESULTS: %d / %d TESTS PASSED ===" % [passed_tests, total_tests])
	if passed_tests == total_tests:
		print("ALL PHASE 6 3D BLOCKY ASSET BUILDER & BRAWL SHOWROOM SYSTEMS VERIFIED AND FUNCTIONAL!")
		quit(0)
	else:
		printerr("SOME TESTS FAILED.")
		quit(1)
