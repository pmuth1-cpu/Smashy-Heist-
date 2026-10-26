extends SceneTree

const SCREENSHOT_DIR = "res://tools/screenshots"

func _init() -> void:
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("tools/screenshots"):
		dir.make_dir_recursive("tools/screenshots")
		
	await process_frame
	await process_frame
	
	print("\n--- CAPTURING UI OVERHAUL SCREENSHOTS ---")
	root.size = Vector2i(1920, 1080)
	
	# 1. Main Menu Normal
	print("Capturing BrawlMainMenu...")
	var menu_scene = preload("res://scenes/ui/brawl_main_menu.tscn").instantiate()
	root.add_child(menu_scene)
	for i in range(6):
		await process_frame
	_save_viewport("brawl_main_menu_overhaul.png")
	
	# 2. Main Menu with 2x2 Game Mode Drawer Open
	print("Capturing BrawlMainMenu with 2x2 Mode Selection Drawer...")
	if menu_scene.has_method("_toggle_mode_drawer"):
		menu_scene._toggle_mode_drawer()
		for i in range(6):
			await process_frame
		_save_viewport("brawl_main_menu_modes_overhaul.png")
	menu_scene.queue_free()
	await process_frame
	
	# 3. Pause Menu Modal
	print("Capturing PauseMenuModal...")
	var pause_scene = preload("res://scenes/ui/pause_menu_modal.tscn").instantiate()
	root.add_child(pause_scene)
	await process_frame
	pause_scene.open_pause_menu()
	for i in range(6):
		await process_frame
	_save_viewport("pause_menu_modal_overhaul.png")
	pause_scene.queue_free()
	await process_frame
	
	# 4. Login Calendar Modal (7 Days)
	print("Capturing LoginCalendarModal...")
	var calendar_scene = preload("res://scenes/ui/login_calendar_modal.tscn").instantiate()
	root.add_child(calendar_scene)
	for i in range(6):
		await process_frame
	_save_viewport("login_calendar_modal_overhaul.png")
	calendar_scene.queue_free()
	await process_frame
	
	# 5. Daily Quests Drawer
	print("Capturing DailyQuestsDrawer...")
	var quests_scene = preload("res://scenes/ui/daily_quests_drawer.tscn").instantiate()
	root.add_child(quests_scene)
	for i in range(6):
		await process_frame
	_save_viewport("daily_quests_drawer_overhaul.png")
	quests_scene.queue_free()
	await process_frame
	
	# 6. Touch HUD (In-Game Chase HUD)
	print("Capturing TouchHUD...")
	var hud_scene = preload("res://scenes/ui/touch_hud.tscn").instantiate()
	root.add_child(hud_scene)
	await process_frame
	hud_scene.set_wanted_stars(4)
	for i in range(6):
		await process_frame
	_save_viewport("touch_hud_overhaul.png")
	hud_scene.queue_free()
	await process_frame
	
	# 7. Run Summary Panel (Post-Run Victory/Busted)
	print("Capturing RunSummaryPanel...")
	var summary_scene = preload("res://scenes/ui/run_summary_panel.tscn").instantiate()
	root.add_child(summary_scene)
	await process_frame
	summary_scene.populate_stats("BUSTED BY SWAT!", 14850, 92.5, 18)
	for i in range(6):
		await process_frame
	_save_viewport("run_summary_panel_overhaul.png")
	summary_scene.queue_free()
	await process_frame
	
	print(">>> ALL SCREENSHOTS CAPTURED SUCCESSFULLY! <<<")
	quit(0)

func _save_viewport(filename: String) -> void:
	var img = root.get_texture().get_image()
	var full_path = "d:/My project/smashy heist/tools/screenshots/" + filename
	img.save_png(full_path)
	print("Saved screenshot: %s" % full_path)
