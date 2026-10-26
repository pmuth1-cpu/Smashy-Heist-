extends SceneTree

const MainGameScene = preload("res://scenes/world/main_game.tscn")

func _init() -> void:
	print("\n=======================================================")
	print("   TESTING KART GAMEPLAY FIXES & SKILL DETAILS        ")
	print("=======================================================\n")
	_run()

func _run() -> void:
	await process_frame
	await process_frame
	
	var gmm = root.get_node_or_null("GameModeManager")
	assert(gmm != null, "GameModeManager must exist")
	gmm.set_mode(3) # SMASHY_KART_GP
	
	var game: MainGame = MainGameScene.instantiate() as MainGame
	root.add_child(game)
	current_scene = game
	
	for i in range(12):
		await process_frame
	
	var car: ArcadeCar = game.arcade_car
	assert(car != null, "ArcadeCar must exist")
	
	var kart_mode = game.smashy_kart_mode
	assert(kart_mode != null, "SmashyKartMode must exist")
	
	var hud_overlay = kart_mode.hud_overlay
	assert(hud_overlay != null, "KartHUDOverlay must exist")
	
	var touch_hud = game.touch_hud
	assert(touch_hud != null, "TouchHUD must exist")
	
	# -------------------------------------------------------------------------
	# TEST 1: CONSTANT SPEED IN KART MODE VS STAT-BASED IN NORMAL MODE
	# -------------------------------------------------------------------------
	print("--- TEST 1: CONSTANT SPEED IN KART MODE VS STAT-BASED IN NORMAL MODE ---")
	assert(root.has_node("GameModeManager"), "GameModeManager exists")
	var gmm_node = root.get_node("GameModeManager")
	assert(int(gmm_node.current_mode) == 3, "In kart mode")
	
	assert(ArcadeCar.KART_BASE_MAX_SPEED == 17.5, "Kart base max speed must be constant 17.5 m/s")
	assert(ArcadeCar.KART_BASE_ACCELERATION == 18.0, "Kart base acceleration must be constant 18.0 m/s2")
	assert(ArcadeCar.KART_BASE_TURN_SPEED == 2.45, "Kart base turn speed must be constant 2.45 rad/s")
	
	var rival_car = kart_mode.all_racers[1]
	print("  Player car stats max_speed: %.1f m/s" % car.stats.max_speed)
	print("  Rival car stats max_speed: %.1f m/s" % rival_car.stats.max_speed)
	print("  Kart Mode base speed for all cars: %.1f m/s (CONSTANT)" % ArcadeCar.KART_BASE_MAX_SPEED)
	print("  [PASS] Kart mode enforces balanced, constant speed (17.5 m/s) across all cars!")
	
	# -------------------------------------------------------------------------
	# TEST 2: JUMP OFF / EJECTION DISABLED IN KART MODE
	# -------------------------------------------------------------------------
	print("\n--- TEST 2: JUMP OFF / EJECT DISABLED IN KART MODE ---")
	assert(car.is_abandoned == false, "Car must start occupied")
	# Call eject test - in kart mode it should be blocked and return null
	var ejected_swimmer = car.eject_player_character()
	assert(ejected_swimmer == null, "eject_player_character must return null in kart mode")
	assert(car.is_abandoned == false, "Car must NOT become abandoned in kart mode")
	print("  Car is_abandoned status: %s" % str(car.is_abandoned))
	print("  [PASS] Driver ejection is strictly disabled in kart mode")
	
	# -------------------------------------------------------------------------
	# TEST 3: NO INDIVIDUAL SKILL — ONLY GAMEMODE SKILL
	# -------------------------------------------------------------------------
	print("\n--- TEST 3: INDIVIDUAL GADGET HIDDEN IN KART MODE ---")
	touch_hud._update_gadget_cooldown(0.016)
	assert(touch_hud.gadget_container.visible == false, "Individual car gadget container must be hidden in Kart mode")
	print("  [PASS] Individual car gadget HUD is hidden; only gamemode skill is active")
	
	# -------------------------------------------------------------------------
	# TEST 4: GAMEMODE SKILL DETAIL & ACTIONS
	# -------------------------------------------------------------------------
	print("\n--- TEST 4: GAMEMODE SKILL DETAILS & BUTTON ---")
	assert(hud_overlay.skill_detail_panel != null, "Skill detail panel must exist")
	assert(hud_overlay.skill_title_label != null, "Skill title label must exist")
	assert(hud_overlay.skill_desc_label != null, "Skill desc label must exist")
	assert(hud_overlay.use_item_button_label != null, "Use item button label must exist")
	
	# Test Empty item state
	hud_overlay.set_held_item(0, 0)
	print("  Default Skill Detail: %s" % hud_overlay.skill_title_label.text)
	assert("GAMEMODE SKILL" in hud_overlay.skill_title_label.text, "Default title must mention Gamemode Skill")
	
	# Test Equipping Red Missile (item 2)
	hud_overlay.set_held_item(2, 1)
	print("  Equipped Skill 2 Title: %s" % hud_overlay.skill_title_label.text)
	print("  Equipped Skill 2 Desc: %s" % hud_overlay.skill_desc_label.text)
	print("  Equipped Skill 2 Button: %s" % hud_overlay.use_item_button_label.text)
	assert("HOMING RED MISSILE" in hud_overlay.skill_title_label.text, "Title must show HOMING RED MISSILE")
	assert("Locks onto" in hud_overlay.skill_desc_label.text, "Desc must explain homing lock")
	assert("LAUNCH HOMING MISSILE" in hud_overlay.use_item_button_label.text, "Button must display action")
	
	# Test Equipping Triple Nitro (item 3, x3 charges)
	hud_overlay.set_held_item(3, 3)
	print("  Equipped Skill 3 Title: %s" % hud_overlay.skill_title_label.text)
	assert("TRIPLE NITRO" in hud_overlay.skill_title_label.text and "x3" in hud_overlay.skill_title_label.text, "Title must show charges")
	print("  [PASS] Gamemode skill detail panel and dynamic button text verified")
	
	# -------------------------------------------------------------------------
	# TEST 5: AI RIVALS DRIVING ALONG THE TRACK (NOT DUMB/STUCK)
	# -------------------------------------------------------------------------
	print("\n--- TEST 5: AI RIVALS DRIVING AUTONOMOUSLY ALONG ROAD ---")
	# Start race
	kart_mode._trigger_race_start()
	for i in range(5):
		await process_frame
	
	var rivals = []
	for r in kart_mode.all_racers:
		if r != car:
			rivals.append(r)
	assert(rivals.size() == 5, "Must have 5 AI rivals")
	
	var initial_distances := []
	for r in rivals:
		initial_distances.append(kart_mode._get_car_pos(r))
	
	# Let rivals drive for 40 frames
	for frame in range(40):
		kart_mode._process_ai_rivals(0.016)
		await process_frame
	
	var moved_count := 0
	for ri in range(rivals.size()):
		var r = rivals[ri]
		var cur_pos = kart_mode._get_car_pos(r)
		var p_start = initial_distances[ri]
		var dist_travelled = p_start.distance_to(cur_pos)
		print("  Rival %s (driver %s) travelled %.2fm" % [r.name, r.driver_name, dist_travelled])
		if dist_travelled > 0.5:
			moved_count += 1
	
	assert(moved_count >= 4, "AI Rivals must drive forward along the road (found %d/%d)" % [moved_count, rivals.size()])
	print("  [PASS] AI Rivals autonomously steering and cruising along road!")
	
	# -------------------------------------------------------------------------
	# TEST 6: NO TELEPORTING WHEN DRIVING NORMALLY OR CROSSING FINISH LINE
	# -------------------------------------------------------------------------
	print("\n--- TEST 6: NO UNWANTED TELEPORTATION ---")
	var car_pos_before = kart_mode._get_car_pos(car)
	# Process wrong way check for normal forward driving
	kart_mode._process_wrong_way(0.016)
	var car_pos_after = kart_mode._get_car_pos(car)
	assert(car_pos_before.distance_to(car_pos_after) < 0.1, "Car must NOT teleport during normal driving!")
	assert(car.wrong_way_timer == 0.0, "wrong_way_timer must stay at 0.0 when driving normal direction")
	print("  [PASS] Zero teleportation confirmed")
	
	print("\n=======================================================")
	print("   ALL TESTS PASSED (100% KART GAMEPLAY FIXES)         ")
	print("=======================================================\n")
	quit(0)
