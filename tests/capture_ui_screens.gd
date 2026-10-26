extends SceneTree

const CarsScreenClass = preload("res://scripts/ui/cars_screen.gd")
const GearScreenClass = preload("res://scripts/ui/gear_screen.gd")
const GachaScreenClass = preload("res://scripts/ui/gacha_screen.gd")
const BrawlUITheme = preload("res://scripts/autoload/brawl_ui_theme.gd")

func _init() -> void:
	await process_frame
	await process_frame
	
	print("\n--- CAPTURING CARS, GEAR, AND GACHA UI SCREENS (1920x1080) ---")
	
	# SHOT 1: CARS SCREEN (Top-Right Reference Quadrant)
	var cars_screen := CarsScreenClass.new()
	root.add_child(cars_screen)
	
	for f in range(20):
		await process_frame
	
	var img_cars := root.get_texture().get_image()
	if img_cars:
		img_cars.save_png("res://cars_screen_showcase.png")
		print("  [SAVED] cars_screen_showcase.png")
	
	cars_screen.queue_free()
	await process_frame
	await process_frame
	
	# SHOT 2: GEAR SCREEN (Bottom-Left Reference Quadrant)
	var gear_screen := GearScreenClass.new()
	root.add_child(gear_screen)
	
	for f in range(20):
		await process_frame
	
	var img_gear := root.get_texture().get_image()
	if img_gear:
		img_gear.save_png("res://gear_screen_showcase.png")
		print("  [SAVED] gear_screen_showcase.png")
	
	gear_screen.queue_free()
	await process_frame
	await process_frame
	
	# SHOT 3: GACHA SCREEN MAIN (Cosmic Portal & Turntable)
	var gacha_screen := GachaScreenClass.new()
	root.add_child(gacha_screen)
	
	for f in range(20):
		await process_frame
	
	var img_gacha := root.get_texture().get_image()
	if img_gacha:
		img_gacha.save_png("res://gacha_screen_showcase.png")
		print("  [SAVED] gacha_screen_showcase.png")
	
	# SHOT 4: GACHA CHEST OPENING & FLASH EXPLOSION
	gacha_screen._perform_spins(10)
	for tw in gacha_screen._active_anim_tweens:
		if tw and is_instance_valid(tw) and tw.is_valid():
			tw.kill()
	gacha_screen._active_anim_tweens.clear()
	
	var opened_tex: Texture2D = BrawlUITheme.load_texture_safe("res://assets/textures/ui/gacha_chest_opened_flash.jpg")
	if opened_tex:
		gacha_screen._chest_rect.texture = opened_tex
	gacha_screen._chest_rect.custom_minimum_size = Vector2(480, 480)
	gacha_screen._chest_rect.scale = Vector2(1.15, 1.15)
	gacha_screen._chest_rect.modulate.a = 1.0
	gacha_screen._chest_container.visible = true
	gacha_screen._flash_rect.color = Color(1.0, 0.96, 0.85, 0.08) # Radiant aura burst without washing out the chest
	gacha_screen._reveal_content.visible = false
	
	for f in range(12):
		await process_frame
	
	var img_chest_flash := root.get_texture().get_image()
	if img_chest_flash:
		img_chest_flash.save_png("res://gacha_chest_opening_showcase.png")
		print("  [SAVED] gacha_chest_opening_showcase.png")
	
	# SHOT 5: GACHA REWARD CELEBRATION MODAL ("WHAT WE GOT IN GACHA")
	gacha_screen._finish_gacha_animation()
	gacha_screen._chest_container.visible = false # Focus on reward cards
	for f in range(12):
		await process_frame
	
	var img_rewards := root.get_texture().get_image()
	if img_rewards:
		img_rewards.save_png("res://gacha_rewards_showcase.png")
		print("  [SAVED] gacha_rewards_showcase.png")
	
	gacha_screen.queue_free()
	await process_frame
	
	print("--- ALL SHOWCASE SCREENS CAPTURED SUCCESSFULLY ---")
	quit()
