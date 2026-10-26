extends SceneTree

func _init() -> void:
	print("\n=== STARTING CLICK & INPUT VERIFICATION TESTS ===")
	await process_frame
	await process_frame
	
	var main_scene = load("res://scenes/world/main_game.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame
	
	var hud: TouchHUD = main_scene.find_child("TouchHUD", true, false) as TouchHUD
	var car: ArcadeCar = main_scene.find_child("ArcadeCar", true, false) as ArcadeCar
	
	var passed: int = 0
	var total: int = 0
	
	# Test 1: Direct Left Zone GUI input
	total += 1
	var ev_l = InputEventMouseButton.new()
	ev_l.button_index = MOUSE_BUTTON_LEFT
	ev_l.pressed = true
	hud._on_left_touch_gui_input(ev_l)
	hud._process(0.016)
	
	if is_equal_approx(hud.steer_input, -1.0) and is_equal_approx(car.steer_input, -1.0) and hud.left_indicator.visible:
		print("✓ PASS: Left zone click accurately sets steer_input = -1.0 and drives ArcadeCar")
		passed += 1
	else:
		printerr("✗ FAIL: Left zone click failed! hud_steer=%.2f, car_steer=%.2f" % [hud.steer_input, car.steer_input])
	
	# Release left
	ev_l.pressed = false
	hud._on_left_touch_gui_input(ev_l)
	hud._process(0.016)
	
	# Test 2: Direct Right Zone GUI input
	total += 1
	var ev_r = InputEventMouseButton.new()
	ev_r.button_index = MOUSE_BUTTON_LEFT
	ev_r.pressed = true
	hud._on_right_touch_gui_input(ev_r)
	hud._process(0.016)
	
	if is_equal_approx(hud.steer_input, 1.0) and is_equal_approx(car.steer_input, 1.0) and hud.right_indicator.visible:
		print("✓ PASS: Right zone click accurately sets steer_input = 1.0 and drives ArcadeCar")
		passed += 1
	else:
		printerr("✗ FAIL: Right zone click failed! hud_steer=%.2f, car_steer=%.2f" % [hud.steer_input, car.steer_input])
	
	# Release right
	ev_r.pressed = false
	hud._on_right_touch_gui_input(ev_r)
	hud._process(0.016)
	
	# Test 3: Right Mouse Button Reverse / Brake
	total += 1
	var ev_rev = InputEventMouseButton.new()
	ev_rev.button_index = MOUSE_BUTTON_RIGHT
	ev_rev.pressed = true
	hud._on_left_touch_gui_input(ev_rev)
	hud._process(0.016)
	
	if hud.is_reversing and car.is_reversing:
		print("✓ PASS: Right-click reverse accurately sets is_reversing = true on HUD and Car")
		passed += 1
	else:
		printerr("✗ FAIL: Right-click reverse failed! hud_rev=%s, car_rev=%s" % [hud.is_reversing, car.is_reversing])
	
	ev_rev.pressed = false
	hud._on_left_touch_gui_input(ev_rev)
	hud._process(0.016)
	
	# Test 4: Leaderboard Button click opens LeaderboardPanel
	total += 1
	hud.leaderboard_btn.emit_signal("pressed")
	await process_frame
	
	var lb_open: bool = hud.leaderboard_panel.visible
	var modal_blocks: bool = hud._is_modal_open()
	hud._process(0.016)
	var steer_zeroed: bool = is_equal_approx(hud.steer_input, 0.0) and is_equal_approx(car.steer_input, 0.0)
	
	if lb_open and modal_blocks and steer_zeroed:
		print("✓ PASS: Leaderboard Button opens panel and locks car steering")
		passed += 1
	else:
		printerr("✗ FAIL: Leaderboard Button failed! lb_open=%s, modal_blocks=%s, steer_zeroed=%s" % [lb_open, modal_blocks, steer_zeroed])
	
	hud.leaderboard_panel.visible = false
	await process_frame
	
	# Test 5: Garage Button click opens GarageGachaPanel
	total += 1
	hud.garage_btn.emit_signal("pressed")
	await process_frame
	
	var gg_open: bool = hud.garage_panel.visible
	if gg_open:
		print("✓ PASS: Garage Button opens GarageGachaPanel")
		passed += 1
	else:
		printerr("✗ FAIL: Garage Button failed! gg_open=%s" % gg_open)
	
	hud.garage_panel.visible = false
	await process_frame
	
	# Test 6: Safe Area and mouse_filter on SafeMarginContainer
	total += 1
	var smc_filter_ok: bool = hud.safe_margin_container.mouse_filter == Control.MOUSE_FILTER_IGNORE
	if smc_filter_ok:
		print("✓ PASS: SafeMarginContainer mouse_filter is MOUSE_FILTER_IGNORE (never blocks child clicks)")
		passed += 1
	else:
		printerr("✗ FAIL: SafeMarginContainer mouse_filter is not IGNORE (was %d)" % hud.safe_margin_container.mouse_filter)
	
	main_scene.queue_free()
	
	print("\n=== RESULTS: %d / %d TESTS PASSED ===" % [passed, total])
	if passed == total:
		print("ALL CLICK & INPUT SYSTEMS FULLY VERIFIED!")
		quit(0)
	else:
		printerr("SOME TESTS FAILED.")
		quit(1)
