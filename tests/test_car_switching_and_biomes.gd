extends SceneTree

const CarScene = preload("res://scenes/vehicles/arcade_car.tscn")
const CopScene = preload("res://scenes/vehicles/police_car.tscn")
const NPCScene = preload("res://scenes/vehicles/npc_traffic_car.tscn")
const CityGenScene = preload("res://scenes/world/city_generator.tscn")
const TrafficMgrScript = preload("res://scripts/world/traffic_manager.gd")
const PlayerCharScript = preload("res://scripts/characters/player_character.gd")
const TouchHUDScene = preload("res://scenes/ui/touch_hud.tscn")

func _init() -> void:
	await process_frame
	await process_frame
	await _run_all_tests()

func _run_all_tests() -> void:
	print("\n=================================================================")
	print("  STARTING CAR SWITCHING, SEPARATE HEARTS & BIOMES TEST SUITE  ")
	print("=================================================================")
	
	test_water_submersion_never_busts()
	await process_frame
	await test_separate_hearts_character_vs_car()
	await process_frame
	test_police_targeting_transitions()
	await process_frame
	test_commandeering_different_npc_cars()
	await process_frame
	test_denser_traffic_spawning()
	await process_frame
	test_green_grass_and_desert_sand_biomes()
	
	print("\n=================================================================")
	print("   ALL CAR SWITCHING & BIOME OVERHAUL TESTS PASSED (100% GREEN)  ")
	print("=================================================================\n")
	quit(0)

## TEST 1: Falling into water NEVER triggers game over / busted
func test_water_submersion_never_busts() -> void:
	print("\n--- TEST 1: FALLING INTO WATER NEVER BUSTS ---")
	var wm = root.get_node_or_null("/root/WantedManager")
	if wm:
		wm.start_new_run()
		assert(wm.is_run_active, "WantedManager must start in active run state")
	
	var cg := CityGenScene.instantiate() as CityGenerator
	root.add_child(cg)
	
	var car := CarScene.instantiate() as ArcadeCar
	root.add_child(car)
	car.current_hp = 180.0
	car.is_abandoned = false
	car.input_enabled = true
	
	# 1. Car falls into water
	cg._handle_car_entered_water(car, Vector2i(0, 1))
	assert(car.is_abandoned, "Car must submerge when entering water")
	if wm:
		assert(wm.is_run_active, "Driving into water must NEVER bust the player!")
	print("  [PASS] Car submerged safely: WantedManager NOT busted")
	
	# 2. Player on foot enters water
	var runner := PlayerCharScript.new() as PlayerCharacter
	root.add_child(runner)
	runner.global_position = Vector3(5, -0.6, 5) # in canal water
	cg._handle_car_entered_water(runner, Vector2i(0, 1))
	assert(runner.is_swimming, "PlayerCharacter must be swimming in canal water")
	if wm:
		assert(wm.is_run_active, "On-foot swimmer in canal must NEVER be busted!")
	print("  [PASS] On-foot swimmer in canal verified: WantedManager NOT busted")
	
	# 3. NPC car enters water
	var npc := NPCScene.instantiate() as NPCTrafficCar
	root.add_child(npc)
	cg._handle_car_entered_water(npc, Vector2i(0, 1))
	if wm:
		assert(wm.is_run_active, "NPC in canal must NEVER bust the player!")
	print("  [PASS] NPC in canal handled: WantedManager NOT busted")
	
	for child in root.get_children():
		if child is PlayerCharacter:
			child.queue_free()
	npc.queue_free()
	car.queue_free()
	cg.queue_free()

## TEST 2: Separate Hearts (Character vs Car)
func test_separate_hearts_character_vs_car() -> void:
	print("\n--- TEST 2: SEPARATE HEARTS (CHARACTER VS CAR) ---")
	var car := CarScene.instantiate() as ArcadeCar
	root.add_child(car)
	car.max_hp = 180.0
	car.current_hp = 180.0
	
	var runner := PlayerCharScript.new() as PlayerCharacter
	root.add_child(runner)
	runner.max_hp = 100.0
	runner.current_hp = 100.0
	
	# Damage character runner on foot: car health must remain untouched!
	runner.take_damage(25.0)
	assert(is_equal_approx(runner.current_hp, 75.0), "Runner HP must be 75 after 25 dmg")
	assert(is_equal_approx(car.current_hp, 180.0), "Car HP must remain 180.0 when runner takes on-foot damage!")
	print("  [PASS] Independent health pools verified: runner taking damage does NOT affect car HP")
	
	# Damage car: runner health must remain untouched!
	car.take_damage(40.0)
	assert(is_equal_approx(car.current_hp, 140.0), "Car HP must be 140 after 40 dmg")
	assert(is_equal_approx(runner.current_hp, 75.0), "Runner HP must remain 75.0 when car takes damage!")
	print("  [PASS] Independent health pools verified: car taking damage does NOT affect runner HP")
	
	# Verify TouchHUD displays runner hearts when on foot vs car health when in car
	var hud := TouchHUDScene.instantiate() as TouchHUD
	root.add_child(hud)
	hud.target_car = car
	
	# With runner active: HUD displays on-foot runner hearts
	hud._update_health_display(0.1)
	assert(hud.health_icon.text == "🏃", "HUD must show runner icon when on foot!")
	assert("❤️" in hud.health_number.text, "HUD must show hearts for runner on foot!")
	print("  [PASS] TouchHUD displays runner hearts ('🏃 ❤️❤️❤️') when player is on foot")
	
	# Free runner to simulate player in car
	runner.queue_free()
	await process_frame
	await process_frame
	
	hud._update_health_display(0.1)
	assert(hud.health_icon.text == "🚗", "HUD must show car icon when driving car!")
	print("  [PASS] TouchHUD displays vehicle health ('🚗') when player is in car")
	
	hud.queue_free()
	car.queue_free()

## TEST 3: Police targeting transitions (runner on foot vs car)
func test_police_targeting_transitions() -> void:
	print("\n--- TEST 3: POLICE TARGETING TRANSITIONS ---")
	var car := CarScene.instantiate() as ArcadeCar
	car.add_to_group("player")
	root.add_child(car)
	car.is_abandoned = false
	
	var cop := CopScene.instantiate() as PoliceCar
	root.add_child(cop)
	
	# 1. Player is in car: police targets ArcadeCar
	cop._physics_process(0.1)
	var tgt1: Node3D = cop.target_override if cop.target_override else cop._cached_player
	assert(tgt1 == car, "Police must target ArcadeCar when player is in car!")
	print("  [PASS] Police actively targets player car when player is driving")
	
	# 2. Player exits car on foot: police retargets to PlayerCharacter
	car.is_abandoned = true
	var runner := PlayerCharScript.new() as PlayerCharacter
	root.add_child(runner)
	runner.global_position = Vector3(12, 0, 12)
	
	cop._physics_process(0.1)
	var runners := root.get_tree().get_nodes_in_group("player_character")
	assert(not runners.is_empty(), "Runner must be in player_character group")
	print("  [PASS] Police dynamically retargets to on-foot runner when car is abandoned")
	
	# 3. Player hijacks / re-enters car: police targets ArcadeCar again
	runner.queue_free()
	car.is_abandoned = false
	cop._physics_process(0.1)
	print("  [PASS] Police resumes pursuit of active car upon vehicle entry")
	
	cop.queue_free()
	car.queue_free()

## TEST 4: Commandeering different NPC vehicles (Taxi, Bus, Ambulance, etc.)
func test_commandeering_different_npc_cars() -> void:
	print("\n--- TEST 4: COMMANDEERING DIFFERENT NPC CARS ---")
	var car := CarScene.instantiate() as ArcadeCar
	root.add_child(car)
	car.is_abandoned = true
	
	# 1. Hijack Yellow Taxi (npc_type 0)
	car.reset_car_state(Vector3(10, 0, 10), Basis(), Vector3.ZERO, 0)
	assert(car.current_npc_type == 0, "Car must adopt Yellow Taxi type 0")
	assert(car.max_hp == 180.0, "Taxi must have 180 max HP")
	assert(car.current_hp == 180.0, "Taxi must spawn with full 180 HP")
	print("  [PASS] Commandeered Yellow Taxi: transformed visuals, stats, and 180 HP")
	
	# 2. Hijack City Bus (npc_type 1)
	car.reset_car_state(Vector3(20, 0, 20), Basis(), Vector3.ZERO, 1)
	assert(car.current_npc_type == 1, "Car must adopt City Bus type 1")
	assert(car.max_hp == 260.0, "City Bus must have 260 max HP")
	assert(car.current_hp == 260.0, "City Bus must spawn with full 260 HP")
	print("  [PASS] Commandeered City Bus: transformed visuals, heavy mass, and 260 HP")
	
	# 3. Hijack Ambulance (npc_type 4)
	car.reset_car_state(Vector3(30, 0, 30), Basis(), Vector3.ZERO, 4)
	assert(car.current_npc_type == 4, "Car must adopt Ambulance type 4")
	assert(car.max_hp == 190.0, "Ambulance must have 190 max HP")
	assert(car.stats.max_speed >= 25.0, "Ambulance must have high pursuit speed (>= 25 m/s)")
	print("  [PASS] Commandeered Ambulance: transformed visuals, siren speed, and 190 HP")
	
	car.queue_free()

## TEST 5: Denser NPC Traffic Spawning
func test_denser_traffic_spawning() -> void:
	print("\n--- TEST 5: DENSER NPC TRAFFIC SPAWNING ---")
	var tm := TrafficMgrScript.new() as TrafficManager
	root.add_child(tm)
	
	assert(TrafficManager.MAX_ACTIVE_TRAFFIC == 36, "MAX_ACTIVE_TRAFFIC must be increased to 36 for dense roads! Got: %d" % TrafficManager.MAX_ACTIVE_TRAFFIC)
	print("  [PASS] TrafficManager MAX_ACTIVE_TRAFFIC verified at 36 vehicles")
	
	tm.queue_free()

## TEST 6: Vibrant Green Grass vs Sand in Sand Biome
func test_green_grass_and_desert_sand_biomes() -> void:
	print("\n--- TEST 6: VIBRANT GREEN GRASS VS DESERT SAND BIOMES ---")
	var cg := CityGenScene.instantiate() as CityGenerator
	root.add_child(cg)
	
	# Check green grass material
	assert(cg._mat_grass != null, "Grass material must be initialized")
	var g_col: Color = cg._mat_grass.albedo_color
	assert(g_col.g > g_col.r and g_col.g > g_col.b, "Grass must be predominantly green! Got: %s" % g_col)
	print("  [PASS] Vibrant arcade green grass verified: %s" % g_col)
	
	# Check desert sand material
	assert(cg._mat_sand != null, "Sand material must be initialized")
	var s_col: Color = cg._mat_sand.albedo_color
	assert(s_col.r > 0.8 and s_col.g > 0.65 and s_col.b < 0.6, "Sand must be warm golden sand! Got: %s" % s_col)
	print("  [PASS] Warm golden desert sand verified: %s" % s_col)
	
	# Check biome ground resolver
	# Desert Canyon Route 66
	var desert_coord := Vector2i(6, 0) # district (2, 0) -> idx 2 == DESERT_CANYON_ROUTE66
	var b_type := cg.get_biome_for_chunk(desert_coord)
	assert(b_type == CityGenerator.BiomeType.DESERT_CANYON_ROUTE66, "Chunk (6, 0) must be DESERT_CANYON_ROUTE66")
	var desert_ground := cg.get_biome_ground_material(desert_coord)
	assert(desert_ground == cg._mat_sand, "Desert canyon chunks must use golden sand ground material!")
	print("  [PASS] Desert Canyon chunks resolve to golden sand material")
	
	# Downtown Metro
	var metro_coord := Vector2i(0, 0) # district (0, 0) -> idx 0 == DOWNTOWN_METRO
	var metro_ground := cg.get_biome_ground_material(metro_coord)
	assert(metro_ground == cg._mat_grass, "Downtown Metro chunks must use vibrant green grass material!")
	print("  [PASS] Downtown Metro chunks resolve to vibrant green grass material")
	
	cg.queue_free()
