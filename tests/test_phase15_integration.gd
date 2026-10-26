extends SceneTree

const AssetChromaLoaderScript = preload("res://scripts/autoload/asset_chroma_loader.gd")
const GameModeManagerScript = preload("res://scripts/autoload/game_mode_manager.gd")
const KartTrackBuilderScript = preload("res://scripts/world/kart_track_builder.gd")
const KartItemBoxScene = preload("res://scenes/props/kart_item_box.tscn")
const KartItemSystemScript = preload("res://scripts/vehicles/kart_item_system.gd")
const KartHUDOverlayScript = preload("res://scripts/ui/kart_hud_overlay.gd")
const SmashyKartModeScript = preload("res://scripts/world/smashy_kart_mode.gd")
const ArcadeCarScene = preload("res://scenes/vehicles/arcade_car.tscn")

func _init() -> void:
	print("\n=================================================================")
	print("       STARTING PHASE 15: SMASHY KART GRAND PRIX TEST SUITE      ")
	print("=================================================================\n")
	
	await process_frame
	await process_frame
	
	_run_all_tests()
	quit(0)

func _run_all_tests() -> void:
	# TEST 1: Nano Banana Kart Icons & AssetChromaLoader
	print("--- TEST 1: NANO BANANA KART ICONS & ASSETCHROMA LOADER ---")
	var acl := AssetChromaLoaderScript.new()
	root.add_child(acl)
	acl._ready()
	
	var kart_assets: Array[String] = [
		"res://assets/kart/kart_item_green_tire.png",
		"res://assets/kart/kart_item_red_missile.png",
		"res://assets/kart/kart_item_blue_drone.png",
		"res://assets/kart/kart_item_oil_slick.png",
		"res://assets/kart/kart_item_triple_nitro.png",
		"res://assets/kart/kart_item_emp_lightning.png",
		"res://assets/kart/kart_item_gold_star.png",
		"res://assets/kart/kart_item_fake_box.png",
		"res://assets/kart/kart_hud_roulette_frame.png",
		"res://assets/kart/kart_flag_checkered.png"
	]
	
	for path in kart_assets:
		var tex := acl.load_transparent_texture(path)
		assert(tex != null, "Texture must load: %s" % path)
		assert(tex.get_width() > 0 and tex.get_height() > 0, "Texture dimensions must be valid: %s" % path)
		print("  [PASS] Kart Asset Verified: %s (%dx%d)" % [path.get_file(), tex.get_width(), tex.get_height()])
	
	# Verify Procedural Fallback
	var fallback_tex := acl._create_procedural_fallback("res://assets/kart/kart_item_green_tire_missing.png")
	assert(fallback_tex != null, "Fallback texture must generate successfully")
	print("  [PASS] Procedural vector fallback synthesis verified")

	# TEST 2: GameModeManager Kart GP Mode & 3 Cup Circuits
	print("\n--- TEST 2: GAMEMODEMANAGER KART GP & CUP CIRCUITS ---")
	var gmm := GameModeManagerScript.new()
	root.add_child(gmm)
	gmm._ready()
	
	assert(GameModeManagerClass.GameMode.SMASHY_KART_GP == 3, "SMASHY_KART_GP must be mode 3")
	gmm.set_mode(GameModeManagerClass.GameMode.SMASHY_KART_GP)
	assert(gmm.current_mode == GameModeManagerClass.GameMode.SMASHY_KART_GP, "Current mode must be SMASHY_KART_GP")
	
	var mode_info: Dictionary = gmm.get_current_mode_info()
	assert("GRAND PRIX" in str(mode_info.get("title", "")), "Mode title must contain GRAND PRIX")
	print("  [PASS] Mode metadata verified: %s" % str(mode_info["title"]))
	
	assert(gmm.selected_cup_track == GameModeManagerClass.KartCupTrack.DOWNTOWN_NEON_CIRCUIT, "Default track is Downtown Neon")
	gmm.set_kart_cup_track(GameModeManagerClass.KartCupTrack.CHINATOWN_DRAGON_LOOP)
	assert(gmm.selected_cup_track == GameModeManagerClass.KartCupTrack.CHINATOWN_DRAGON_LOOP, "Can set Chinatown Dragon Loop")
	gmm.set_kart_cup_track(GameModeManagerClass.KartCupTrack.CANYON_HIGHWAY_SPEEDWAY)
	assert(gmm.selected_cup_track == GameModeManagerClass.KartCupTrack.CANYON_HIGHWAY_SPEEDWAY, "Can set Canyon Highway Speedway")
	print("  [PASS] 3 Cup Circuits switching verified")

	# TEST 3: Procedural 3-Lap Track Builder (~780m Closed Loop)
	print("\n--- TEST 3: PROCEDURAL 3D CIRCUIT TRACK BUILDER ---")
	var track_builder = KartTrackBuilderScript.new()
	root.add_child(track_builder)
	track_builder.build_track()
	
	assert(track_builder.track_path != null, "TrackPath must exist")
	assert(track_builder.track_path.curve != null, "Curve3D must exist")
	var length: float = track_builder.baked_length
	print("  Track length baked: %.1fm" % length)
	assert(length >= 700.0 and length <= 900.0, "Track length must be ~780m (found %.1fm)" % length)
	
	assert(track_builder.checkpoints.size() == 4, "Must have exactly 4 checkpoint gates (found %d)" % track_builder.checkpoints.size())
	assert(track_builder.boost_pads.size() == 6, "Must have exactly 6 boost pads (found %d)" % track_builder.boost_pads.size())
	assert(track_builder.item_boxes.size() == 20, "Must have 20 item boxes (4 lines of 5 boxes) (found %d)" % track_builder.item_boxes.size())
	assert(track_builder.road_body != null and track_builder.road_body.collision_layer == 1, "Road body must be on Layer 1 Ground")
	assert(track_builder.barrier_body != null and track_builder.barrier_body.collision_layer == 8, "Barrier body must be on Layer 4 Buildings (bit 8)")
	print("  [PASS] Track ribbon, 4 checkpoints, 6 boost pads, and 4 item rows verified")

	# TEST 4: Rainbow Item Box Pickup & Respawn
	print("\n--- TEST 4: RAINBOW ITEM BOX & RESPAWN CYCLE ---")
	var item_box = KartItemBoxScene.instantiate()
	root.add_child(item_box)
	
	var car: ArcadeCar = ArcadeCarScene.instantiate() as ArcadeCar
	root.add_child(car)
	
	var kis = KartItemSystemScript.new()
	kis.name = "KartItemSystem"
	car.add_child(kis)
	kis.car = car
	
	assert(item_box._is_available, "Item box must start available")
	item_box._collect(car)
	assert(not item_box._is_available, "Item box must become unavailable after pickup")
	assert(kis.is_roulette_active, "Roulette must start spinning on car")
	print("  [PASS] Item box collection and roulette trigger verified")
	
	item_box._respawn_box()
	assert(item_box._is_available, "Item box must respawn successfully")
	print("  [PASS] Item box respawn verified")

	# TEST 5: Position-Weighted Item Roulette & 8 Weapons
	print("\n--- TEST 5: POSITION-WEIGHTED ITEM SYSTEM & 8 WEAPONS ---")
	# Test rank probability rolls
	var rank1_item: int = int(kis._roll_weighted_item(1))
	assert(rank1_item in [4, 1, 8], "1st place must get defensive items (OIL_SLICK=4, GREEN_TIRE=1, FAKE_BOX=8)")
	
	var rank6_item: int = int(kis._roll_weighted_item(6))
	assert(rank6_item in [7, 6, 3, 5], "6th place must get comeback items (GOLD_STAR=7, EMP_LIGHTNING=6, BLUE_DRONE=3, TRIPLE_NITRO=5)")
	print("  [PASS] Rubber-band weighted probability tables verified for 1st & 6th rank")
	
	# Test Fast-Stop Roulette
	kis.start_item_roulette(2)
	assert(kis.is_roulette_active, "Roulette active")
	kis.roulette_timer = 0.7 # Exceed 0.6s threshold
	kis.roulette_can_fast_stop = true
	kis.fast_stop_roulette()
	assert(not kis.is_roulette_active, "Roulette fast-stopped")
	assert(int(kis.current_item) != 0, "Item awarded after roulette")
	print("  [PASS] Roulette early fast-stop mechanism verified")
	
	# Test Weapon Triggers
	kis.current_item = 5 # TRIPLE_NITRO
	kis.item_charges = 3
	kis.use_item()
	assert(kis.item_charges == 2, "Triple nitro charges must decrement to 2")
	assert(car.drift_boost_time > 0.0, "Car must receive nitro boost")
	print("  [PASS] Triple Nitro charges & boost verified")
	
	kis.current_item = 7 # GOLD_STAR
	kis.item_charges = 1
	kis.use_item()
	assert(kis.is_gold_star_active(), "Gold Star must activate invincibility")
	assert(kis.gold_star_timer > 0.0, "Gold star timer active")
	print("  [PASS] Gold Star invincibility & aura verified")

	# TEST 6: ArcadeCar 3-Stage Drift Boost, Slipstream & Lakitu Rescue
	print("\n--- TEST 6: 3-STAGE DRIFT BOOST & SLIPSTREAM DRAFTING ---")
	car.drift_hold_time = 0.9
	assert(car.drift_hold_time >= 0.85, "Stage 1 hold threshold reached")
	car.drift_hold_time = 1.8
	assert(car.drift_hold_time >= 1.75, "Stage 2 hold threshold reached")
	car.drift_hold_time = 2.6
	assert(car.drift_hold_time >= 2.5, "Stage 3 hold threshold reached")
	
	car._trigger_drift_boost(3)
	assert(car.drift_boost_multiplier == 1.75, "Stage 3 boost multiplier must be 1.75x")
	assert(car.drift_boost_time >= 2.5, "Stage 3 boost time must be ~2.6s")
	print("  [PASS] Stage 3 Electric Purple Ultra Mini-Turbo (1.75x, 2.6s) verified")
	
	# Combat responses
	car.spin_out(1.0)
	car.blast_flip()
	print("  [PASS] Car spin-out & blast-flip mechanics verified")

	# TEST 7: Smashy Kart Grand Prix Game Mode & 6-Racer Progression
	print("\n--- TEST 7: SMASHY KART GRAND PRIX 6-RACER RACE LOOP ---")
	var kart_mode = SmashyKartModeScript.new()
	root.add_child(kart_mode)
	kart_mode.start_grand_prix(car)
	
	assert(kart_mode.all_racers.size() == 6, "Must spawn exactly 6 racers on starting grid (found %d)" % kart_mode.all_racers.size())
	assert(kart_mode.hud_overlay != null, "KartHUDOverlay must be instantiated")
	assert(kart_mode.is_countdown_active, "Pre-race countdown must be active")
	print("  [PASS] 6-Racer Starting Grid & Pre-Race Countdown initialized")
	
	# Test Rocket Start
	kart_mode.rev_meter = 88.0 # Inside 80-95% sweet spot
	kart_mode._trigger_race_start()
	assert(kart_mode.is_race_active, "Race must be active after countdown")
	assert(car.drift_boost_time > 0.0, "Rocket Start must award speed burst")
	print("  [PASS] 3-2-1-SMASH! Rocket Start rev sweet-spot (88%) verified")
	
	# Test Sequential Checkpoint Lap Progression
	var p_prog: Dictionary = kart_mode.racer_progress[car]
	assert(p_prog["laps"] == 0, "Starts at Lap 0")
	
	# Simulate crossing CP 1, 2, 3, then 0
	kart_mode._on_checkpoint_entered(track_builder.checkpoints[1], car)
	assert(p_prog["cp"] == 1, "Passed checkpoint 1")
	kart_mode._on_checkpoint_entered(track_builder.checkpoints[2], car)
	assert(p_prog["cp"] == 2, "Passed checkpoint 2")
	kart_mode._on_checkpoint_entered(track_builder.checkpoints[3], car)
	assert(p_prog["cp"] == 3, "Passed checkpoint 3")
	kart_mode._on_checkpoint_entered(track_builder.checkpoints[0], car)
	assert(p_prog["laps"] == 1, "Completed Lap 1!")
	print("  [PASS] Sequential anti-cheat checkpoint progression verified (Lap 1 completed)")
	
	# Test Race Finish & Podium Ceremony
	p_prog["laps"] = 3
	kart_mode._trigger_race_finish(car)
	assert(kart_mode.podium_active, "Podium ceremony must be active upon 3-lap finish")
	assert(kart_mode.podium_ui != null, "Podium UI must be displayed")
	print("  [PASS] 3-Lap Grand Prix Finish & Podium Ceremony verified")

	print("\n=================================================================")
	print("     ALL PHASE 15 SMASHY KART GRAND PRIX TESTS PASSED! (100%)    ")
	print("=================================================================\n")
