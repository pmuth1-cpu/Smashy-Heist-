extends SceneTree

const BrawlMainMenuScene = preload("res://scenes/ui/brawl_main_menu.tscn")

func _init() -> void:
	await process_frame
	await process_frame
	
	var menu = BrawlMainMenuScene.instantiate()
	root.add_child(menu)
	menu._ready()
	
	# Wait for 7-day auto-popup timer to fire and close it immediately
	await create_timer(0.6).timeout
	for child in menu.get_children():
		if child.name.begins_with("LoginCalendarModal") or child is Window or child.name == "LoginCalendarModal":
			child.visible = false
	
	if menu._login_calendar_modal:
		menu._login_calendar_modal.visible = false
	
	# Ensure home tab is clean
	menu.switch_tab(0)
	
	await process_frame
	await process_frame
	
	var vp = root.get_viewport()
	if vp:
		var tex = vp.get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png("lobby_fullscreen_screenshot.png")
				print("SAVED lobby_fullscreen_screenshot.png!")
	quit(0)
