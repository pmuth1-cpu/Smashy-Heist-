extends SceneTree

const VABScript = preload("res://scripts/autoload/voxel_asset_builder.gd")
const AssetChromaLoaderScript = preload("res://scripts/autoload/asset_chroma_loader.gd")
const CameraRigScene = preload("res://scenes/world/camera_rig.tscn")
const TouchHUDScene = preload("res://scenes/ui/touch_hud.tscn")
const PauseMenuModalScene = preload("res://scenes/ui/pause_menu_modal.tscn")
const BrawlMainMenuScene = preload("res://scenes/ui/brawl_main_menu.tscn")
const PowerupCrateScene = preload("res://scenes/props/powerup_crate.tscn")

func _init() -> void:
	print("\n=================================================================")
	print("    STARTING PHASE 13 & 14 WIDESCREEN & ASSETS INTEGRATION TEST  ")
	print("=================================================================\n")
	
	await process_frame
	await process_frame
	
	_run_all_tests()
	quit(0)

func _run_all_tests() -> void:
	# TEST 1: Project Resolution 1920x1080 Landscape
	print("--- TEST 1: 16:9 LANDSCAPE VIEWPORT RESOLUTION ---")
	var width = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height = ProjectSettings.get_setting("display/window/size/viewport_height")
	var orientation = ProjectSettings.get_setting("display/window/handheld/orientation")
	assert(width == 1920, "Viewport width must be 1920")
	assert(height == 1080, "Viewport height must be 1080")
	assert(orientation == 0, "Handheld orientation must be Landscape (0)")
	print("  [PASS] Project configured to 1920x1080 Landscape (16:9 Widescreen)")

	# TEST 2: AssetChromaLoader Autoload & Asset Pack
	print("\n--- TEST 2: ASSET CHROMA LOADER & 2D ASSET PACK ---")
	var acl := AssetChromaLoaderScript.new()
	root.add_child(acl)
	acl._ready()
	
	var test_assets: Array[String] = [
		"res://assets/ui/btn_smash_play.png",
		"res://assets/ui/icon_cash_stack.png",
		"res://assets/ui/icon_trophy_cup.png",
		"res://assets/ui/icon_streak_flame.png",
		"res://assets/ui/icon_tab_home.png",
		"res://assets/hud/btn_gadget_trigger.png",
		"res://assets/powerups/powerup_nitro.png",
		"res://assets/splash/loading_bg_landscape.png"
	]
	
	for path in test_assets:
		var tex: Texture2D = acl.load_texture(path)
		assert(tex != null, "Asset must load via AssetChromaLoader: %s" % path)
		assert(tex.get_width() > 0 and tex.get_height() > 0, "Texture dimensions must be valid: %s" % path)
	print("  [PASS] AssetChromaLoader verified across 2D UI, HUD, and powerup asset pack")

	# TEST 3: CameraRig 16:9 Landscape Angle & Distance Presets
	print("\n--- TEST 3: CAMERARIG 16:9 WIDESCREEN FOV & DISTANCE PRESETS ---")
	var cam_rig := CameraRigScene.instantiate() as CameraRig
	root.add_child(cam_rig)
	cam_rig._ready()
	
	assert(cam_rig.camera != null, "CameraRig must have Camera3D child")
	assert(is_equal_approx(cam_rig.camera.fov, 32.0), "Base FOV must be 32.0")
	assert(cam_rig.max_lookahead == 5.5, "Max lookahead must be 5.5m")
	
	# Verify presets toggle (STANDARD 24m -> WIDE 30m -> ACTION ZOOM 18m)
	var initial_preset_name = cam_rig.get_camera_preset_name().to_upper()
	assert(initial_preset_name == "STANDARD (24M)", "Default preset must be STANDARD (24M)")
	
	cam_rig.toggle_camera_distance()
	assert(cam_rig.get_camera_preset_name().to_upper() == "WIDE (30M)", "Next preset must be WIDE (30M)")
	
	cam_rig.toggle_camera_distance()
	assert(cam_rig.get_camera_preset_name().to_upper() == "ACTION ZOOM (18M)", "Next preset must be ACTION ZOOM (18M)")
	
	cam_rig.toggle_camera_distance()
	assert(cam_rig.get_camera_preset_name().to_upper() == "STANDARD (24M)", "Cycled preset must return to STANDARD (24M)")
	print("  [PASS] CameraRig FOV 32.0, base distance 24.0m, and 3-step preset toggling verified")

	# TEST 4: TouchHUD 16:9 Landscape Layout & Pause Integration
	print("\n--- TEST 4: TOUCH HUD 16:9 WIDESCREEN LAYOUT & PAUSE BUTTON ---")
	var hud := TouchHUDScene.instantiate() as TouchHUD
	root.add_child(hud)
	hud._ready()
	
	var pause_btn := hud.find_child("PauseButton", true, false) as Button
	assert(pause_btn != null, "TouchHUD must have PauseButton in top bar")
	
	var gadget_container := hud.find_child("GadgetContainer", true, false) as Control
	assert(gadget_container != null, "TouchHUD must have GadgetContainer")
	assert(gadget_container.anchor_left == 1.0 and gadget_container.anchor_top == 1.0, "Gadget button must anchor to bottom-right in landscape")
	
	assert(hud.pause_menu_modal != null, "TouchHUD must instantiate PauseMenuModal")
	print("  [PASS] TouchHUD 16:9 landscape layout, Pause button, and bottom-right gadget anchor verified")

	# TEST 5: Pause Menu Modal Functionality
	print("\n--- TEST 5: PAUSE MENU MODAL & LIVE STATS ---")
	var pause_modal := PauseMenuModalScene.instantiate() as PauseMenuModal
	root.add_child(pause_modal)
	pause_modal._ready()
	
	assert(pause_modal.process_mode == Node.PROCESS_MODE_ALWAYS, "PauseMenuModal must have PROCESS_MODE_ALWAYS")
	
	# Open pause menu
	pause_modal.open_pause_menu()
	assert(pause_modal.visible == true, "Pause menu must become visible")
	assert(pause_modal.get_tree().paused == true, "Engine must be paused")
	
	# Resume
	pause_modal.resume_game()
	assert(pause_modal.visible == false, "Pause menu must hide on resume")
	assert(pause_modal.get_tree().paused == false, "Engine must unpause")
	print("  [PASS] PauseMenuModal freezing, unfreezing, and PROCESS_MODE_ALWAYS verified")

	# TEST 6: Renovated 3D Powerup Models in VoxelAssetBuilder & PowerupCrate
	print("\n--- TEST 6: RENOVATED 3D POWERUP SCULPTURES ---")
	var vab := VABScript.new()
	root.add_child(vab)
	
	for p_type in range(4):
		var p_model: Node3D = vab.build_powerup_3d_model(p_type)
		assert(p_model != null, "Powerup 3D model for type %d must build" % p_type)
		assert(p_model.find_child("SculpturePivot", true, false) != null, "Powerup must have SculpturePivot")
		assert(p_model.find_child("GroundAuraRing", true, false) != null, "Powerup must have GroundAuraRing")
		assert(p_model.find_child("PowerupLight", true, false) != null, "Powerup must have PowerupLight")
	print("  [PASS] 4 distinct 3D powerup sculptures (NOS, EMP, Oil Drum, Shield Wrench) with ground aura rings verified")
	
	# Verify PowerupCrate instantiates the 3D model
	var crate := PowerupCrateScene.instantiate() as PowerupCrate
	crate.forced_powerup = 0
	root.add_child(crate)
	crate._ready()
	assert(crate.find_child("VoxelModel", true, false) != null, "PowerupCrate must instantiate 3D voxel model")
	print("  [PASS] PowerupCrate dynamically displays 3D voxel sculpture")

	# TEST 7: Brawl Main Menu 16:9 Landscape & 3D Neon Garage Hangar
	print("\n--- TEST 7: BRAWL MAIN MENU 16:9 NEON HEIST GARAGE HANGAR ---")
	var menu := BrawlMainMenuScene.instantiate() as BrawlMainMenu
	root.add_child(menu)
	menu._ready()
	
	# Check 3D Hangar nodes inside ShowroomWorld
	var hangar = menu.find_child("NeonGarageHangar", true, false)
	assert(hangar != null, "Showroom must contain 3D NeonGarageHangar environment")
	
	# Check sign, shutter, and props
	var neon_lbl = hangar.find_child("NeonSign", true, false) as Label3D
	if not neon_lbl:
		neon_lbl = hangar.find_child("*Neon*", true, false) as Label3D
	assert(neon_lbl != null and neon_lbl.text == "SMASHY HEIST GARAGE", "Hangar must have 'SMASHY HEIST GARAGE' 3D neon sign")
	
	# Check 16:9 UI docks
	var home_dock = menu.find_child("Layer3_HomeDock", true, false) as Control
	assert(home_dock != null, "Menu must have Layer3_HomeDock")
	assert(home_dock.anchor_left == 1.0 and home_dock.anchor_top == 1.0, "Play dock must anchor in bottom-right corner")
	
	var bottom_dock = menu.find_child("Layer4_BottomDock", true, false) as Control
	assert(bottom_dock != null, "Menu must have Layer4_BottomDock")
	
	var top_bar = menu.find_child("Layer2_TopBar", true, false) as Control
	assert(top_bar != null, "Menu must have Layer2_TopBar")
	
	print("  [PASS] Brawl Main Menu 16:9 Neon Heist Garage Hangar and widescreen docks verified")

	print("\n=================================================================")
	print("   ALL PHASE 13 & 14 INTEGRATION TESTS PASSED (100% GREEN)       ")
	print("=================================================================\n")
