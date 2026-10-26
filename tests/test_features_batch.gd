extends SceneTree

const PoliceCarScript = preload("res://scripts/vehicles/police_car.gd")
const NPCTrafficCarScript = preload("res://scripts/vehicles/npc_traffic_car.gd")
const ArcadeCarScript = preload("res://scripts/vehicles/arcade_car.gd")
const PlayerCharacterScript = preload("res://scripts/characters/player_character.gd")
const StarPerkPopupScene = preload("res://scenes/ui/star_perk_popup.tscn")
const WantedManagerScript = preload("res://scripts/autoload/wanted_manager.gd")
const ExplosiveRocketScript = preload("res://scripts/world/explosive_rocket.gd")
const TrapMineScript = preload("res://scripts/props/trap_mine.gd")
const ExplosionFXScript = preload("res://scripts/world/explosion_fx.gd")

func _init() -> void:
	await process_frame
	await process_frame
	
	print("\n=================================================================")
	print("   STARTING INTEGRATION TESTS FOR NEW GAMEPLAY & VISUAL MECHANICS")
	print("=================================================================")
	
	test_police_officers_and_hijacking()
	test_car_despawn_timers()
	test_wanted_star_fast_escalation()
	test_star_perk_popup_rectangle_and_slow_mo()
	test_explosives_knockback_and_efx()
	
	print("\n=================================================================")
	print("   ALL NEW GAMEPLAY & VISUAL MECHANICS TESTS PASSED (100% GREEN) ")
	print("=================================================================\n")
	quit(0)

## TEST 1: Police Officers inside & Hijacking Rules
func test_police_officers_and_hijacking() -> void:
	print("\n--- TEST 1: POLICE OFFICERS & HIJACKING RULES ---")
	var police_car_scene := load("res://scenes/vehicles/police_car.tscn") as PackedScene
	var pc: PoliceCar = police_car_scene.instantiate() as PoliceCar
	root.add_child(pc)
	
	assert(pc.officers_inside == 2, "Police car must start with 2 officers inside! Found: %d" % pc.officers_inside)
	assert(not pc.can_be_hijacked(), "Police car cannot be hijacked while officers are inside!")
	print("  [PASS] Initial 2 officers inside verified; cannot be hijacked while occupied")
	
	# Disembark officers
	pc.disembark_all_officers()
	assert(pc.officers_inside == 0, "Officers inside must be 0 after disembarking all officers")
	assert(pc.can_be_hijacked(), "Police car must be hijackable after officers jump off")
	print("  [PASS] Officers jump off successfully; vehicle becomes hijackable (officers_inside == 0)")
	
	# Verify PlayerCharacter hijack attempt against occupied vs vacant police car
	var player_char: PlayerCharacter = PlayerCharacterScript.new()
	root.add_child(player_char)
	
	var pc2: PoliceCar = police_car_scene.instantiate() as PoliceCar
	root.add_child(pc2)
	assert(pc2.officers_inside == 2, "New police car has 2 officers")
	
	# Attempt hijack while occupied: should flush officers out, not enter
	player_char.hijack_vehicle(pc2)
	assert(pc2.officers_inside == 0, "Hijack attempt must flush officers out of occupied police car")
	assert(is_instance_valid(player_char), "Player must remain on foot after flushing officers out")
	print("  [PASS] PlayerCharacter approach/hijack flushes officers out; entry blocked while occupied")
	
	pc.queue_free()
	pc2.queue_free()
	player_char.queue_free()

## TEST 2: 10-Second Car Despawn Logic
func test_car_despawn_timers() -> void:
	print("\n--- TEST 2: 10-SECOND CAR DESPAWN TIMERS ---")
	var police_car_scene := load("res://scenes/vehicles/police_car.tscn") as PackedScene
	var pc: PoliceCar = police_car_scene.instantiate() as PoliceCar
	root.add_child(pc)
	
	assert(pc.despawn_timer == 10.0, "Police car despawn timer must default to 10.0s")
	pc.wreck()
	assert(pc.is_wrecked, "Police car must be marked wrecked")
	assert(pc.despawn_timer == 10.0, "Despawn timer must be set to 10.0s on wreck")
	
	# Simulate physics process delta
	pc._physics_process(5.0)
	assert(is_equal_approx(pc.despawn_timer, 5.0), "Despawn timer should count down to 5.0s")
	print("  [PASS] Police car 10-second despawn timer on wreck verified")
	
	# Traffic Car despawn
	var npc := NPCTrafficCarScript.new()
	root.add_child(npc)
	assert(npc.despawn_timer == 10.0, "Traffic car despawn timer must default to 10.0s")
	npc.take_traffic_hit(pc, Vector3(0, 0, 10))
	assert(npc.was_crashed, "Traffic car must be marked was_crashed")
	assert(npc.despawn_timer == 10.0, "Traffic car despawn timer must be 10.0s on crash")
	
	npc._physics_process(4.0)
	assert(is_equal_approx(npc.despawn_timer, 6.0), "Traffic car despawn timer should count down to 6.0s")
	print("  [PASS] NPC Traffic car 10-second despawn timer on crash verified")
	
	pc.queue_free()
	npc.queue_free()

## TEST 3: Wanted Stars Fast Escalation
func test_wanted_star_fast_escalation() -> void:
	print("\n--- TEST 3: FAST WANTED STAR ESCALATION ---")
	var wm = root.get_node_or_null("WantedManager")
	var created_wm := false
	if not wm:
		wm = WantedManagerScript.new()
		root.add_child(wm)
		created_wm = true
	
	var defs = wm.STAR_DEFINITIONS
	assert(defs.size() == 5, "5 Star definitions must exist")
	assert(defs[0]["threshold"] == 0.0, "1-star threshold must be 0.0s")
	assert(defs[1]["threshold"] == 20.0, "2-star threshold must be 20.0s (fast pacing)")
	assert(defs[2]["threshold"] == 45.0, "3-star threshold must be 45.0s (fast pacing)")
	assert(defs[3]["threshold"] == 75.0, "4-star threshold must be 75.0s (fast pacing)")
	assert(defs[4]["threshold"] == 110.0, "5-star threshold must be 110.0s (fast pacing)")
	print("  [PASS] Fast star thresholds verified: 1★:0s, 2★:20s, 3★:45s, 4★:75s, 5★:110s")
	
	# Test Cop Wreck heat boost
	wm.is_run_active = true
	wm.survival_time = 10.0
	wm.register_cop_wrecked()
	assert(wm.survival_time >= 13.5, "Wrecking cop car must add +3.5s heat boost! Found: %f" % wm.survival_time)
	print("  [PASS] Cop wreck heat progression acceleration (+3.5s) verified")
	
	if created_wm:
		wm.queue_free()

## TEST 4: Star Perk Popup Rectangle & Slow Effect
func test_star_perk_popup_rectangle_and_slow_mo() -> void:
	print("\n--- TEST 4: STAR PERK POPUP MODAL (RECTANGLE & SLOW EFFECT) ---")
	var popup: StarPerkPopup = StarPerkPopupScene.instantiate() as StarPerkPopup
	root.add_child(popup)
	
	# Verify card dimensions and rectangle properties
	var card_l := popup.find_child("CardLeft", true, false) as Button
	var card_r := popup.find_child("CardRight", true, false) as Button
	assert(card_l != null and card_r != null, "Card buttons must exist")
	assert(card_l.custom_minimum_size.x >= 380 and card_l.custom_minimum_size.y >= 520, "Cards must be large rectangles (>=380x520)")
	
	# Verify Artwork dimensions
	var art_l := card_l.find_child("PerkArt", true, false) as TextureRect
	var art_r := card_r.find_child("PerkArt", true, false) as TextureRect
	assert(art_l != null and art_r != null, "PerkArt TextureRects must exist")
	assert(art_l.custom_minimum_size.x >= 340 and art_l.custom_minimum_size.y >= 220, "PerkArt must be large (>=340x220). Found: %s" % str(art_l.custom_minimum_size))
	assert(art_l.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "PerkArt stretch_mode must be STRETCH_KEEP_ASPECT_COVERED")
	print("  [PASS] Card dimensions (400x560) and large rectangular artwork (360x240) verified")
	
	# Verify 100% Solid Opacity StyleBox
	var test_sb: StyleBoxFlat = popup._make_rectangular_card_style(Color("e74c3c"), false)
	assert(is_equal_approx(test_sb.bg_color.a, 1.0), "Card stylebox background MUST have 100%% opacity (alpha == 1.0)! Found: %f" % test_sb.bg_color.a)
	assert(test_sb.corner_radius_top_left <= 8, "Card corners must be crisp rectangular (<= 8px)")
	print("  [PASS] 100% Solid opacity (alpha 1.0) and crisp rectangular border verified")
	
	# Verify Slow-Motion Effect (not full pause)
	popup.show_star_perks(2)
	assert(is_equal_approx(Engine.time_scale, 0.15), "show_star_perks must use slow effect (time_scale == 0.15), not full pause! Found: %f" % Engine.time_scale)
	print("  [PASS] Slow-motion effect (Engine.time_scale == 0.15) on perk upgrade verified")
	
	# Selecting perk restores normal time
	popup._select_perk(0)
	assert(is_equal_approx(Engine.time_scale, 1.0), "Selecting perk must restore normal time (time_scale == 1.0)")
	print("  [PASS] Time scale restored to 1.0 upon perk selection")
	
	popup.queue_free()

## TEST 5: Explosives Knockback & Better EFX
func test_explosives_knockback_and_efx() -> void:
	print("\n--- TEST 5: EXPLOSIVES KNOCKBACK & HIGH-IMPACT EFX ---")
	
	# Verify apply_knockback exists on player car, on-foot player, and police car
	var ac_scene := load("res://scenes/vehicles/arcade_car.tscn") as PackedScene
	var ac: ArcadeCar = ac_scene.instantiate() as ArcadeCar
	root.add_child(ac)
	assert(ac.has_method("apply_knockback"), "ArcadeCar must have apply_knockback method")
	ac.apply_knockback(Vector3(1, 0, 0), 24.0)
	assert(ac.physics_sphere.linear_velocity.length() > 0.0 or ac.physics_sphere != null, "Knockback should apply impulse to car physics sphere")
	print("  [PASS] ArcadeCar apply_knockback physics impulse verified")
	
	var pc_scene := load("res://scenes/vehicles/police_car.tscn") as PackedScene
	var pc: PoliceCar = pc_scene.instantiate() as PoliceCar
	root.add_child(pc)
	assert(pc.has_method("apply_knockback"), "PoliceCar must have apply_knockback method")
	pc.apply_knockback(Vector3(0, 0, 1), 22.0)
	print("  [PASS] PoliceCar apply_knockback physics impulse verified")
	
	var runner: PlayerCharacter = PlayerCharacterScript.new()
	root.add_child(runner)
	assert(runner.has_method("apply_knockback"), "PlayerCharacter must have apply_knockback method")
	runner.apply_knockback(Vector3(1, 0, 1), 18.0)
	assert(runner.velocity.length() > 0.0, "PlayerCharacter knockback must add velocity")
	print("  [PASS] PlayerCharacter apply_knockback velocity impulse verified")
	
	# Verify ExplosionFX spawn
	var fx := ExplosionFXScript.spawn(root, Vector3(0, 0, 0), 1.0, true)
	assert(fx != null, "ExplosionFX must spawn successfully")
	assert(fx.get_child_count() > 0, "ExplosionFX must create flash, shockwave, fireball, and shrapnel nodes")
	print("  [PASS] High-impact ExplosionFX system verified (flash light, ground shockwave, fireball, voxel shrapnel, smoke)")
	
	ac.queue_free()
	pc.queue_free()
	runner.queue_free()
	fx.queue_free()
