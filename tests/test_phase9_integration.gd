extends SceneTree

## Comprehensive Phase 9 Integration & Verification Test Suite
## Validates:
## 1. Global Brawl UI Theme & Outlined Typography Factory (BrawlUITheme)
## 2. 3D Slanted Button StyleBox & Universal Elastic Button Juice
## 3. Zero-Asset Procedural Arcade Sound Synthesizer (SoundFX with 6 AudioStreamGenerators)
## 4. 1080x1920 Portrait Brawl Stars Menu with 4-Tab Navigation Dock & Highlight Bar
## 5. Non-overlapping tab switching (HOME, CARS, GACHA, RANKS)
## 6. Overhauled TouchHUD with Slanted Health Bar, 5 Animated Wanted Stars, Combo Drain Bar
## 7. Bottom-Center Active Gadget Button with Cooldown Sweep
## 8. 3D Billboard Floating Combat Text Popups

func _init() -> void:
	print("\n=======================================================")
	print("       STARTING PHASE 9 INTEGRATION TEST SUITE         ")
	print("=======================================================\n")
	await process_frame
	await process_frame
	
	# Ensure autoloads are initialized in root for standalone SceneTree runner
	if root.get_node_or_null("SoundFX") == null:
		var sfx_script = load("res://scripts/autoload/sound_fx.gd")
		var sfx_node: Node = sfx_script.new()
		sfx_node.name = "SoundFX"
		root.add_child(sfx_node)
	
	if root.get_node_or_null("BrawlUITheme") == null:
		var theme_script = load("res://scripts/autoload/brawl_ui_theme.gd")
		var theme_node: Node = theme_script.new()
		theme_node.name = "BrawlUITheme"
		root.add_child(theme_node)
	
	await process_frame
	_run_phase9_tests()

func _run_phase9_tests() -> void:
	var total_tests: int = 0
	var passed_tests: int = 0
	
	# --------------------------------------------------------------------------
	# TEST 1: BrawlUITheme Autoload & Typography Factory
	# --------------------------------------------------------------------------
	total_tests += 1
	var theme_node: Node = root.get_node_or_null("BrawlUITheme")
	if theme_node != null and theme_node.has_method("make_label_settings"):
		var ls: LabelSettings = theme_node.make_label_settings(42, Color.WHITE, 8, 4)
		var valid_ls: bool = (ls != null 
			and ls.font_size == 42 
			and ls.font_color == Color.WHITE 
			and ls.outline_size == 8 
			and ls.outline_color == Color("0d1117") 
			and ls.shadow_size == 4 
			and ls.shadow_offset == Vector2(2, 4)
		)
		if valid_ls:
			passed_tests += 1
			print("✅ [TEST 1 PASSED] BrawlUITheme registered and creates valid high-contrast comic LabelSettings.")
		else:
			print("❌ [TEST 1 FAILED] BrawlUITheme LabelSettings configuration mismatch.")
	else:
		print("❌ [TEST 1 FAILED] BrawlUITheme Autoload not found in /root.")

	# --------------------------------------------------------------------------
	# TEST 2: 3D Slanted Button StyleBox & Elastic Button Juice
	# --------------------------------------------------------------------------
	total_tests += 1
	if theme_node != null and theme_node.has_method("make_card_style"):
		var sb: StyleBoxFlat = theme_node.make_card_style(Color("f39c12"), Color("0d1117"), 0.06, 16)
		var valid_sb: bool = (sb != null
			and sb.bg_color == Color("f39c12")
			and is_equal_approx(sb.skew.x, 0.06)
			and sb.border_color == Color("0d1117")
			and sb.border_width_left == 4
			and sb.border_width_top == 4
			and sb.border_width_right == 4
			and sb.border_width_bottom == 10
			and sb.corner_radius_top_left == 16
			and sb.shadow_size == 8
		)
		
		# Test button juice
		var test_btn := Button.new()
		test_btn.size = Vector2(200, 60)
		root.add_child(test_btn)
		theme_node.attach_button_juice(test_btn, Color("0984e3"))
		var has_normal: bool = test_btn.has_theme_stylebox_override("normal")
		var has_pressed: bool = test_btn.has_theme_stylebox_override("pressed")
		var pressed_sb: StyleBoxFlat = test_btn.get_theme_stylebox("pressed") as StyleBoxFlat
		var valid_depress: bool = pressed_sb != null and pressed_sb.border_width_bottom == 3
		test_btn.queue_free()
		
		if valid_sb and has_normal and has_pressed and valid_depress:
			passed_tests += 1
			print("✅ [TEST 2 PASSED] 3D Slanted Button StyleBox & Elastic Juice correctly depress and style.")
		else:
			print("❌ [TEST 2 FAILED] StyleBox or Button Juice configuration mismatch.")
	else:
		print("❌ [TEST 2 SKIPPED] BrawlUITheme missing.")

	# --------------------------------------------------------------------------
	# TEST 3: SoundFX Procedural Arcade Sound Synthesizer
	# --------------------------------------------------------------------------
	total_tests += 1
	var sfx: Node = root.get_node_or_null("SoundFX")
	if sfx != null:
		var players_valid: bool = sfx.get("_players") != null and sfx._players.size() == 6 and sfx._generators.size() == 6
		var gen_sample: AudioStreamGenerator = sfx._generators[0] as AudioStreamGenerator
		var valid_gen: bool = gen_sample != null and int(gen_sample.mix_rate) == 22050 and is_equal_approx(gen_sample.buffer_length, 0.25)
		
		# Test playing all procedural waveforms
		sfx.play_ui_click()
		sfx.play_smash_hit()
		sfx.play_explosion()
		sfx.play_drift_boost()
		sfx.play_star_up()
		
		if players_valid and valid_gen and not sfx._ui_click_frames.is_empty() and not sfx._explosion_frames.is_empty():
			passed_tests += 1
			print("✅ [TEST 3 PASSED] SoundFX pool of 6 AudioStreamGenerators (22050 Hz, 0.25s) synthesized all waveforms.")
		else:
			print("❌ [TEST 3 FAILED] SoundFX generator configuration or waveform buffer error.")
	else:
		print("❌ [TEST 3 FAILED] SoundFX Autoload not found in /root.")

	# --------------------------------------------------------------------------
	# TEST 4: Clean 1080x1920 Portrait Menu Architecture
	# --------------------------------------------------------------------------
	total_tests += 1
	var menu_scene: PackedScene = load("res://scenes/ui/brawl_main_menu.tscn")
	var menu: Control = menu_scene.instantiate() as Control
	root.add_child(menu)
	await process_frame
	
	var has_layer0: bool = menu.get_node_or_null("Layer0_Backdrop") != null and menu.get_node_or_null("ComicRays") != null
	var has_layer1: bool = menu.get_node_or_null("ShowroomContainer") != null and menu.get_node_or_null("ShowroomUIOverlay") != null
	var has_layer2: bool = menu.get_node_or_null("Layer2_TopBar") != null
	var has_layer3: bool = menu.get_node_or_null("Layer3_HomeDock") != null
	var has_layer4: bool = menu.get_node_or_null("Layer4_BottomDock") != null
	
	if has_layer0 and has_layer1 and has_layer2 and has_layer3 and has_layer4:
		passed_tests += 1
		print("✅ [TEST 4 PASSED] BrawlMainMenu contains all 5 clean layers (Backdrop, Showroom, TopBar, HomeDock, BottomDock).")
	else:
		print("❌ [TEST 4 FAILED] BrawlMainMenu layer missing: L0=%s, L1=%s, L2=%s, L3=%s, L4=%s" % [has_layer0, has_layer1, has_layer2, has_layer3, has_layer4])

	# --------------------------------------------------------------------------
	# TEST 5: Non-Overlapping 4-Tab Switching
	# --------------------------------------------------------------------------
	total_tests += 1
	# Tab 0: Home
	menu.switch_tab(0)
	var home_ok: bool = menu._home_dock_container.visible and not menu._cars_drawer.visible and not menu._gacha_drawer.visible and not menu._ranks_drawer.visible
	# Tab 1: Cars
	menu.switch_tab(1)
	var cars_ok: bool = not menu._home_dock_container.visible and menu._cars_drawer.visible and not menu._gacha_drawer.visible and not menu._ranks_drawer.visible
	# Tab 2: Gacha
	menu.switch_tab(2)
	var gacha_ok: bool = not menu._home_dock_container.visible and not menu._cars_drawer.visible and menu._gacha_drawer.visible and not menu._ranks_drawer.visible
	# Tab 3: Ranks
	menu.switch_tab(3)
	var ranks_ok: bool = not menu._home_dock_container.visible and not menu._cars_drawer.visible and not menu._gacha_drawer.visible and menu._ranks_drawer.visible
	
	menu.switch_tab(0) # Restore home
	
	if home_ok and cars_ok and gacha_ok and ranks_ok:
		passed_tests += 1
		print("✅ [TEST 5 PASSED] 4-Tab Navigation cleanly toggles drawers with ZERO overlap between panels.")
	else:
		print("❌ [TEST 5 FAILED] Tab switching overlap: Home=%s, Cars=%s, Gacha=%s, Ranks=%s" % [home_ok, cars_ok, gacha_ok, ranks_ok])
	
	menu.queue_free()

	# --------------------------------------------------------------------------
	# TEST 6: Overhauled TouchHUD Health, Stars & Combo UI
	# --------------------------------------------------------------------------
	total_tests += 1
	var hud_scene: PackedScene = load("res://scenes/ui/touch_hud.tscn")
	var hud: CanvasLayer = hud_scene.instantiate() as CanvasLayer
	root.add_child(hud)
	await process_frame
	
	var has_health: bool = hud.health_bar != null and hud.health_number != null
	var has_stars: bool = hud.stars_container != null and hud.stars_container.get_child_count() == 5
	var has_score: bool = hud.score_label != null
	var has_combo: bool = hud.combo_badge != null and hud.combo_drain_bar != null
	
	hud.set_score(5420)
	var score_ok: bool = hud.score_label.text == "005420"
	
	hud.set_wanted_stars(3)
	var stars_ok: bool = hud._current_stars == 3
	
	hud.show_combo(4, 200)
	var combo_ok: bool = hud.combo_badge.visible and hud.combo_label.text.contains("x4")
	
	if has_health and has_stars and has_score and has_combo and score_ok and stars_ok and combo_ok:
		passed_tests += 1
		print("✅ [TEST 6 PASSED] TouchHUD health bar, animated wanted stars, and combo drain bar operate correctly.")
	else:
		print("❌ [TEST 6 FAILED] TouchHUD components mismatch.")

	# --------------------------------------------------------------------------
	# TEST 7: Bottom-Center Active Gadget Button
	# --------------------------------------------------------------------------
	total_tests += 1
	var has_gadget_btn: bool = hud.gadget_button != null and hud.gadget_icon != null and hud.gadget_name != null
	var is_centered: bool = hud.gadget_container.anchor_left == 0.5 and hud.gadget_container.anchor_top == 1.0
	
	# Simulate pressing gadget
	hud._on_gadget_button_pressed()
	var cd_active: bool = hud.gadget_cooldown > 0.0 and hud.cooldown_overlay.visible
	
	if has_gadget_btn and is_centered and cd_active:
		passed_tests += 1
		print("✅ [TEST 7 PASSED] Bottom-Center Active Gadget button triggers cooldown sweep and matches layout.")
	else:
		print("❌ [TEST 7 FAILED] Active Gadget button configuration error.")

	# --------------------------------------------------------------------------
	# TEST 8: 3D Billboard Floating Combat Text Popups
	# --------------------------------------------------------------------------
	total_tests += 1
	var test_world_pos := Vector3(10.0, 0.5, -15.0)
	hud.spawn_floating_text(test_world_pos, "💥 +250 WRECKED!", Color("ff4757"), 1.25)
	await process_frame
	
	# Look for spawned Label3D
	var found_label: Label3D = null
	for c in root.get_children():
		if c is Label3D:
			found_label = c as Label3D
			break
	
	var valid_lbl: bool = (found_label != null
		and found_label.text == "💥 +250 WRECKED!"
		and found_label.billboard == BaseMaterial3D.BILLBOARD_ENABLED
		and found_label.font_size == 48
		and found_label.outline_size == 12
		and found_label.no_depth_test == true
	)
	
	if valid_lbl:
		passed_tests += 1
		print("✅ [TEST 8 PASSED] 3D Billboard Floating Text popup correctly spawned and animated.")
	else:
		print("❌ [TEST 8 FAILED] Spawned 3D floating text popup missing or configured incorrectly.")
	
	hud.queue_free()

	# --------------------------------------------------------------------------
	# FINAL SUMMARY
	# --------------------------------------------------------------------------
	print("\n=======================================================")
	print("       PHASE 9 TEST RESULTS: %d / %d PASSED           " % [passed_tests, total_tests])
	print("=======================================================\n")
	
	if passed_tests == total_tests:
		print("🏆 ALL PHASE 9 ACCEPTANCE CRITERIA SUCCESSFULLY VERIFIED!\n")
		quit(0)
	else:
		print("⚠️ SOME TESTS FAILED!\n")
		quit(1)
