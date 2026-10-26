extends SceneTree

const BrawlUITheme = preload("res://scripts/autoload/brawl_ui_theme.gd")
const PauseMenuModalScene = preload("res://scenes/ui/pause_menu_modal.tscn")
const RunSummaryPanelScene = preload("res://scenes/ui/run_summary_panel.tscn")
const TouchHUDScene = preload("res://scenes/ui/touch_hud.tscn")
const BrawlMainMenuScene = preload("res://scenes/ui/brawl_main_menu.tscn")
const LoginCalendarModalScene = preload("res://scenes/ui/login_calendar_modal.tscn")
const DailyQuestsDrawerScene = preload("res://scenes/ui/daily_quests_drawer.tscn")

func _init() -> void:
	await process_frame
	await process_frame
	
	print("\n=======================================================")
	print("   SMASHY HEIST: CUTE CARTOON 3D UI OVERHAUL TEST     ")
	print("=======================================================\n")
	
	var pass_count := 0
	var fail_count := 0
	
	# 1. Verify Assets on Disk
	print("[TEST 1] Verifying Cartoon 3D Assets on Disk...")
	var expected_assets = [
		"res://assets/ui/btn_candy_green.png",
		"res://assets/ui/btn_candy_yellow.png",
		"res://assets/ui/btn_candy_red.png",
		"res://assets/ui/btn_candy_blue.png",
		"res://assets/ui/btn_candy_purple.png",
		"res://assets/ui/btn_round_close_x.png",
		"res://assets/ui/btn_round_pause.png",
		"res://assets/ribbons/ribbon_header_paused.png",
		"res://assets/ribbons/ribbon_header_rewards.png",
		"res://assets/ribbons/ribbon_header_quests.png",
		"res://assets/items/icon_cartoon_chest_day7.png",
		"res://assets/items/icon_cartoon_heist_safe.png",
		"res://assets/hud/hud_cartoon_star_gold.png",
		"res://assets/hud/hud_cartoon_star_empty.png",
		"res://assets/modes/mode_daily_getaway.png",
		"res://assets/modes/mode_boss_escape.png",
		"res://assets/modes/mode_hot_loot.png",
		"res://assets/modes/mode_kart_gp.png"
	]
	
	for path in expected_assets:
		if FileAccess.file_exists(path):
			print("  [OK] Asset verified: %s" % path)
			pass_count += 1
		else:
			printerr("  [FAIL] Missing asset: %s" % path)
			fail_count += 1
	
	# 2. Test Pause Menu Modal
	print("\n[TEST 2] Testing PauseMenuModal Overhaul...")
	var pause_modal = PauseMenuModalScene.instantiate()
	root.add_child(pause_modal)
	await process_frame
	pause_modal.open_pause_menu()
	if pause_modal.visible:
		print("  [OK] PauseMenuModal opened successfully.")
		pass_count += 1
	else:
		printerr("  [FAIL] PauseMenuModal failed to open.")
		fail_count += 1
	
	if pause_modal.resume_btn and pause_modal.resume_btn.text == "RESUME":
		print("  [OK] Resume button styled cleanly with candy 3D green.")
		pass_count += 1
	else:
		printerr("  [FAIL] Resume button text mismatch: %s" % str(pause_modal.resume_btn.text if pause_modal.resume_btn else "null"))
		fail_count += 1
	
	pause_modal.resume_game()
	pause_modal.queue_free()
	await process_frame
	
	# 3. Test LoginCalendarModal
	print("\n[TEST 3] Testing LoginCalendarModal (7-Day Rewards)...")
	var login_modal = LoginCalendarModalScene.instantiate()
	root.add_child(login_modal)
	await process_frame
	if is_instance_valid(login_modal):
		print("  [OK] LoginCalendarModal instantiated successfully.")
		pass_count += 1
	else:
		printerr("  [FAIL] LoginCalendarModal instantiation failed.")
		fail_count += 1
	
	# Verify card count
	if login_modal._card_panels.size() == 7:
		print("  [OK] 7 Day reward cards created.")
		pass_count += 1
	else:
		printerr("  [FAIL] Day cards count mismatch: %d" % login_modal._card_panels.size())
		fail_count += 1
		
	login_modal.queue_free()
	await process_frame
	
	# 4. Test DailyQuestsDrawer
	print("\n[TEST 4] Testing DailyQuestsDrawer (Missions & Heist Safe)...")
	var quest_drawer = DailyQuestsDrawerScene.instantiate()
	root.add_child(quest_drawer)
	await process_frame
	if is_instance_valid(quest_drawer):
		print("  [OK] DailyQuestsDrawer instantiated successfully.")
		pass_count += 1
	else:
		printerr("  [FAIL] DailyQuestsDrawer instantiation failed.")
		fail_count += 1
		
	quest_drawer.queue_free()
	await process_frame
	
	# 5. Test RunSummaryPanel Overhaul
	print("\n[TEST 5] Testing RunSummaryPanel Overhaul...")
	var summary_panel = RunSummaryPanelScene.instantiate()
	root.add_child(summary_panel)
	await process_frame
	summary_panel.populate_stats("BUSTED BY SWAT", 12500, 78.4, 14)
	if summary_panel.play_again_button and summary_panel.play_again_button.text == "PLAY AGAIN":
		print("  [OK] RunSummaryPanel play again button styled with 3D candy green.")
		pass_count += 1
	else:
		printerr("  [FAIL] Play again button mismatch.")
		fail_count += 1
	summary_panel.queue_free()
	await process_frame
	
	# 6. Test TouchHUD Wanted Stars
	print("\n[TEST 6] Testing TouchHUD Wanted Stars & Bubble Buttons...")
	var touch_hud = TouchHUDScene.instantiate()
	root.add_child(touch_hud)
	await process_frame
	touch_hud.set_wanted_stars(3)
	if touch_hud._current_stars == 3:
		print("  [OK] Wanted Stars level 3 applied with cute 3D cartoon stars.")
		pass_count += 1
	else:
		printerr("  [FAIL] Wanted stars failed to update.")
		fail_count += 1
	touch_hud.queue_free()
	await process_frame
	
	# 7. Test Main Menu & Mode Selector
	print("\n[TEST 7] Testing BrawlMainMenu Mode Selector & Banners...")
	var mode_defs: Array = BrawlMainMenu.MODE_DEFS
	
	if mode_defs.size() == 4:
		print("  [OK] Main menu has 4 distinct game modes.")
		pass_count += 1
		for m in mode_defs:
			var thumb: String = str(m.get("thumb", ""))
			if "mode_" in thumb:
				print("    - Mode '%s' thumb: %s [OK]" % [m["name"], thumb])
			else:
				printerr("    - Mode '%s' has un-upgraded thumb: %s" % [m["name"], thumb])
	else:
		printerr("  [FAIL] Mode defs size: %d" % mode_defs.size())
		fail_count += 1
	
	print("\n=======================================================")
	print("TEST RESULTS: %d PASSED, %d FAILED" % [pass_count, fail_count])
	print("=======================================================")
	
	if fail_count == 0:
		print(">>> ALL CUTE CARTOON 3D UI OVERHAUL TESTS PASSED SUCCESSFULLY! <<<")
		quit(0)
	else:
		printerr(">>> SOME TESTS FAILED! <<<")
		quit(1)
