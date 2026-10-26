extends SceneTree

const BrawlMainMenuClass = preload("res://scripts/ui/brawl_main_menu.gd")
const CarsScreenClass = preload("res://scripts/ui/cars_screen.gd")
const GearScreenClass = preload("res://scripts/ui/gear_screen.gd")
const BrawlUITheme = preload("res://scripts/autoload/brawl_ui_theme.gd")
const LoadingScreenClass = preload("res://scripts/ui/loading_screen.gd")
const RunSummaryPanelClass = preload("res://scripts/ui/run_summary_panel.gd")

func _init() -> void:
	await process_frame
	await process_frame
	
	print("\n=================================================================")
	print("   STARTING GARAGE OVERLAP, NEUMORPHISM & TEXTURE TESTS         ")
	print("=================================================================\n")
	
	await test_brawl_main_menu_showroom_isolation_and_scale()
	await test_loading_screen_isolation()
	await test_run_summary_panel_garage_flow()
	test_neumorphic_buttons()
	await test_3d_textures_car_and_gear()
	
	print("\n=================================================================")
	print("   ALL GARAGE OVERLAP, NEUMORPHISM & TEXTURE TESTS PASSED (100% GREEN)")
	print("=================================================================\n")
	quit(0)

func test_brawl_main_menu_showroom_isolation_and_scale() -> void:
	print("--- TEST 1: SHOWROOM VIEWPORT ISOLATION & LOBBY CAR SCALE/ROTATION ---")
	var menu := BrawlMainMenuClass.new()
	root.add_child(menu)
	await process_frame
	
	# Verify SubViewport is isolated in its own private 3D world
	assert(menu._sub_viewport != null, "Showroom SubViewport must exist")
	assert(menu._sub_viewport.own_world_3d == true, "Showroom SubViewport must have own_world_3d=true to prevent car overlap")
	assert(menu._sub_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Showroom SubViewport should be active on tab 0")
	print("  [PASS] Showroom SubViewport own_world_3d = true verified")
	
	# Verify lobby car scale and rotation (level with floor X=0.0, orbited Y=142.0 to match plate)
	assert(menu._pedestal_pivot != null, "Pedestal pivot must exist")
	assert(is_equal_approx(menu._pedestal_pivot.scale.x, 0.85), "Pedestal pivot scale should be enlarged to 0.85")
	assert(is_equal_approx(menu._pedestal_pivot.rotation_degrees.x, 0.0), "Pedestal pivot X rotation must be backed up to 0.0 (level on floor plate)")
	assert(is_equal_approx(menu._pedestal_pivot.rotation_degrees.y, 142.0), "Pedestal pivot Y rotation must be orbited to 142.0 degrees")
	assert(is_equal_approx(menu._pedestal_pivot.position.y, -0.40), "Pedestal pivot Y position must align with background plate at -0.40")
	print("  [PASS] Lobby car scale (0.85), level X stance (0.0 deg), and plate orbit (142.0 deg) verified")
	
	# Verify switching to CARS tab disables showroom SubViewport rendering
	menu.switch_tab(1)
	assert(menu.active_tab_index == 1, "Must switch to tab 1 (CARS / Garage)")
	assert(menu._sub_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Showroom SubViewport must be disabled when on CARS tab")
	print("  [PASS] Showroom SubViewport disabled on tab 1 to prevent car overlap")
	
	# Switch back to Home
	menu.switch_tab(0)
	assert(menu._sub_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Showroom SubViewport re-enabled on tab 0")
	print("  [PASS] Showroom SubViewport restored on tab 0")
	
	menu.queue_free()

func test_loading_screen_isolation() -> void:
	print("\n--- TEST 2: LOADING SCREEN SUBVIEWPORT ISOLATION & CLEANUP ---")
	var ls: LoadingScreen = LoadingScreenClass.new()
	root.add_child(ls)
	await process_frame
	
	assert(ls._sub_viewport != null, "LoadingScreen SubViewport must exist")
	assert(ls._sub_viewport.own_world_3d == true, "LoadingScreen SubViewport must have own_world_3d=true to prevent leaking cars into world")
	
	ls.setup_equipped_car("tuk_tuk_jet")
	ls.show_screen()
	assert(ls._sub_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "LoadingScreen SubViewport active when showing")
	
	ls.hide_screen()
	assert(ls._sub_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "LoadingScreen SubViewport disabled when hidden")
	assert(ls._car_model == null, "LoadingScreen car model freed on hide")
	print("  [PASS] LoadingScreen SubViewport isolated and car model freed on hide")
	
	ls.queue_free()

func test_run_summary_panel_garage_flow() -> void:
	print("\n--- TEST 3: RUN SUMMARY PANEL GARAGE RETURN & BUTTON SIZING ---")
	var scene = load("res://scenes/ui/run_summary_panel.tscn")
	var panel: RunSummaryPanel = scene.instantiate()
	root.add_child(panel)
	await process_frame
	
	assert(panel.garage_button != null, "Garage button must exist on scorecard")
	assert(panel.garage_button.custom_minimum_size.y >= 60.0, "Garage button height should be enlarged for mobile touch")
	
	var sig_box: Array[bool] = [false]
	panel.garage_requested.connect(func(): sig_box[0] = true)
	
	panel._on_garage_pressed()
	assert(sig_box[0] == true, "garage_requested signal emitted")
	
	var sm = root.get_node_or_null("SaveManager")
	if sm:
		assert(sm.has_meta("return_to_tab") and int(sm.get_meta("return_to_tab")) == 1, "return_to_tab metadata set to 1 for Garage tab")
		sm.remove_meta("return_to_tab")
	print("  [PASS] RunSummaryPanel garage_button routes to Garage tab cleanly")
	
	panel.queue_free()

func test_neumorphic_buttons() -> void:
	print("\n--- TEST 4: AUTHENTIC NEUMORPHIC BUTTON STYLES & MOBILE SCALING ---")
	var btn := Button.new()
	btn.text = "TEST NEUMORPHIC BUTTON"
	root.add_child(btn)
	
	BrawlUITheme.attach_button_juice(btn, Color("f39c12"))
	
	# Verify styleboxes
	var normal_sb = btn.get_theme_stylebox("normal")
	assert(normal_sb is StyleBoxFlat, "Button normal style should be StyleBoxFlat")
	var flat := normal_sb as StyleBoxFlat
	assert(flat.border_blend == true, "Neumorphic border should be smoothly blended for soft bevel")
	assert(flat.border_width_top == 2, "Neumorphic subtle highlight border should be 2px")
	assert(flat.corner_radius_top_left == 18, "Corner radius should be smooth 18px")
	assert(flat.shadow_size >= 8, "Soft drop shadow should be present")
	assert(flat.shadow_offset.x > 0.0 and flat.shadow_offset.y > 0.0, "Dual directional shadow offset required")
	
	# Verify mobile touch scaling
	assert(btn.custom_minimum_size.y >= 60.0, "Button height must be at least 60px for mobile touch")
	assert(btn.custom_minimum_size.x >= 64.0, "Button width must be at least 64px for mobile touch")
	print("  [PASS] Authentic Neumorphic Soft UI styling and mobile touch scaling verified")
	
	btn.queue_free()

func test_3d_textures_car_and_gear() -> void:
	print("\n--- TEST 5: ACCURATE 3D STUDIO LIGHTING & CLEAN VOXEL MODELS ---")
	
	# Verify texture generators exist for stage/pedestal
	var carbon_tex = BrawlUITheme.get_carbon_fiber_texture()
	assert(carbon_tex != null and carbon_tex.get_width() == 32, "Carbon fiber texture must be 32x32")
	var hex_tex = BrawlUITheme.get_hex_grid_texture()
	assert(hex_tex != null and hex_tex.get_width() == 64, "Hex grid texture must be 64x64")
	print("  [PASS] Procedural stage textures available")
	
	# Verify CarsScreen accurate studio lighting and clean voxel model mounting
	var cars_scr: CarsScreen = CarsScreenClass.new()
	root.add_child(cars_scr)
	await process_frame
	cars_scr.select_car("racer_01")
	assert(cars_scr._car_mount.get_child_count() > 0, "Car model mounted on turntable")
	
	# Check for WorldEnvironment and shadow-enabled key light
	var cars_we: WorldEnvironment = null
	var cars_key_light: DirectionalLight3D = null
	var cars_rim_light: DirectionalLight3D = null
	for child in cars_scr._sub_viewport.get_child(0).get_children():
		if child is WorldEnvironment:
			cars_we = child
		elif child is DirectionalLight3D:
			if (child as DirectionalLight3D).shadow_enabled:
				cars_key_light = child
			elif (child as DirectionalLight3D).name == "RimLight":
				cars_rim_light = child
	assert(cars_we != null, "CarsScreen must have WorldEnvironment for ACES tonemapping and glow")
	assert(cars_we.environment.tonemap_mode == Environment.TONE_MAPPER_ACES, "ACES tonemapper must be enabled")
	assert(cars_key_light != null and cars_key_light.shadow_enabled, "CarsScreen key light must have contact shadow enabled")
	assert(cars_rim_light != null, "CarsScreen must have rim backlight")
	print("  [PASS] CarsScreen ACES WorldEnvironment, contact shadows, and studio lighting verified")
	cars_scr.queue_free()
	
	# Verify GearScreen accurate studio lighting and clean voxel gear mounting
	var gear_scr: GearScreen = GearScreenClass.new()
	root.add_child(gear_scr)
	await process_frame
	gear_scr.inspect_gear("jet_v8")
	assert(gear_scr._gear_mount.get_child_count() > 0, "Gear model mounted on pedestal")
	
	var gear_we: WorldEnvironment = null
	var gear_key_light: DirectionalLight3D = null
	for child in gear_scr._sub_viewport.get_child(0).get_children():
		if child is WorldEnvironment:
			gear_we = child
		elif child is DirectionalLight3D and (child as DirectionalLight3D).shadow_enabled:
			gear_key_light = child
	assert(gear_we != null, "GearScreen must have WorldEnvironment for ACES tonemapping and glow")
	assert(gear_we.environment.tonemap_mode == Environment.TONE_MAPPER_ACES, "ACES tonemapper must be enabled on GearScreen")
	assert(gear_key_light != null and gear_key_light.shadow_enabled, "GearScreen key light must have contact shadow enabled")
	print("  [PASS] GearScreen ACES WorldEnvironment, contact shadows, and studio lighting verified")
	gear_scr.queue_free()
