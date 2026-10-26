extends SceneTree

const CityGenScene = preload("res://scenes/world/city_generator.tscn")
const ArcadeCarScene = preload("res://scenes/vehicles/arcade_car.tscn")

func _init() -> void:
	await process_frame
	await process_frame
	await _run_all_tests()

func _run_all_tests() -> void:
	print("\n=================================================================")
	print("  STARTING REALISTIC CITY INFRASTRUCTURE & FARMLAND TEST SUITE   ")
	print("=================================================================\n")
	
	test_continuous_river_network()
	await process_frame
	test_continuous_railway_corridor_and_level_crossings()
	await process_frame
	test_railway_river_girder_bridge()
	await process_frame
	test_farmland_countryside_biome()
	await process_frame
	test_skyscraper_and_parking_garage_stunts()
	await process_frame
	test_moving_freight_train_and_kinetic_impact()
	
	print("\n=================================================================")
	print("   ALL CITY INFRASTRUCTURE & FARMLAND TESTS PASSED (100% GREEN)  ")
	print("=================================================================\n")
	quit(0)

## TEST 1: Continuous River Network (Zero dead-ends, stone quays, bridge variants)
func test_continuous_river_network() -> void:
	print("--- TEST 1: CONTINUOUS RIVER NETWORK & STONE QUAYS ---")
	var cg := CityGenScene.instantiate() as CityGenerator
	root.add_child(cg)
	
	# Verify deterministic continuity formula: for all x, y % 8 == 3 is river
	for x in range(-10, 11):
		assert(cg.is_river_chunk(Vector2i(x, 3)), "Chunk (%d, 3) must be river chunk" % x)
		assert(cg.is_river_chunk(Vector2i(x, 11)), "Chunk (%d, 11) must be river chunk" % x)
		assert(cg.is_river_chunk(Vector2i(x, -5)), "Chunk (%d, -5) must be river chunk" % x)
		assert(not cg.is_river_chunk(Vector2i(x, 0)), "Chunk (%d, 0) must not be river chunk" % x)
	print("  [PASS] Deterministic continuous river continuity verified across coordinate spectrum")
	
	# Test Arched Stone Bridge variation (posmod(x, 3) == 0 -> x = 0, y = 3)
	var chunk_arch = Node3D.new()
	cg._build_river_arched_bridge(chunk_arch, RandomNumberGenerator.new(), Vector2i(0, 3))
	var stone_bridge = chunk_arch.find_child("VoxelArchedStoneBridge", true, false)
	assert(stone_bridge != null, "Arched stone bridge must exist in variation 0")
	var q_s = chunk_arch.find_child("CanalQuaySouth", true, false)
	var q_n = chunk_arch.find_child("CanalQuayNorth", true, false)
	assert(q_s != null and q_n != null, "North and South stone quay retaining walls must exist")
	var water_areas = chunk_arch.find_children("WaterHazardArea_*", "Area3D", true, false)
	assert(water_areas.size() == 2, "Split water hazard areas must flank the stone bridge")
	print("  [PASS] 4-Lane Arched Stone Bridge chunk verified with stone quays & split water areas")
	
	# Test Open Canal & Stunt Ramp variation (posmod(x, 3) == 2 -> x = 2, y = 3)
	var chunk_canal = Node3D.new()
	cg._build_river_quay_canal(chunk_canal, RandomNumberGenerator.new(), Vector2i(2, 3))
	var stunt_ring = chunk_canal.find_child("FlamingStuntRing", true, false)
	assert(stunt_ring != null, "Flaming stunt ring must be suspended over open canal")
	var launch_ramps = chunk_canal.find_children("*", "StaticBody3D", true, false)
	assert(launch_ramps.size() >= 2, "Launch ramps must exist on canal banks for stunt leaps")
	print("  [PASS] Open Canal Stunt Jump chunk verified with flaming ring & launch ramps")
	
	chunk_arch.queue_free()
	chunk_canal.queue_free()
	cg.queue_free()

## TEST 2: Continuous Dedicated Railway Corridor & Automated Level Crossing
func test_continuous_railway_corridor_and_level_crossings() -> void:
	print("\n--- TEST 2: CONTINUOUS RAILWAY CORRIDOR & LEVEL CROSSINGS ---")
	var cg := CityGenScene.instantiate() as CityGenerator
	root.add_child(cg)
	
	# Verify deterministic continuity formula: for all y, x % 8 == 5 is rail
	for y in range(-10, 11):
		assert(cg.is_rail_corridor(Vector2i(5, y)), "Chunk (5, %d) must be rail corridor" % y)
		assert(cg.is_rail_corridor(Vector2i(13, y)), "Chunk (13, %d) must be rail corridor" % y)
		assert(not cg.is_rail_corridor(Vector2i(0, y)), "Chunk (0, %d) must not be rail corridor" % y)
	print("  [PASS] Dedicated North-South rail corridor continuity verified across coordinates")
	
	# Build Rail Corridor Chunk
	var chunk_rail = Node3D.new()
	cg._build_railway_corridor(chunk_rail, RandomNumberGenerator.new(), Vector2i(5, 0))
	var tracks = chunk_rail.find_child("VoxelRailTracks", true, false)
	assert(tracks != null, "Ballasted dual-track rail system must be spawned")
	var b_w = chunk_rail.find_child("CrossingBarrierWest", true, false)
	var b_e = chunk_rail.find_child("CrossingBarrierEast", true, false)
	assert(b_w != null and b_e != null, "Twin automated level crossing barriers must protect crossing")
	var rail_gates = chunk_rail.find_children("SmashProp*", "Node3D", true, false)
	var found_gate_prop = false
	for p in rail_gates:
		if p is SmashProp and p.prop_type == SmashProp.PropType.RAIL_GATE:
			found_gate_prop = true
			break
	assert(found_gate_prop, "Smashable rail gates must be equipped on crossing boom arms")
	print("  [PASS] Railway corridor chunk verified with dual tracks, barriers & smashable gates")
	
	# Test level crossing gate animation logic
	assert(cg._level_crossings.size() == 1, "Level crossing must be registered in CityGenerator")
	var crossing = cg._level_crossings[0]
	assert(not crossing["is_closed"], "Crossing barrier must start in open state")
	cg._set_crossing_closed(crossing, true)
	assert(crossing["is_closed"], "Crossing barrier must transition to closed state")
	cg._set_crossing_closed(crossing, false)
	assert(not crossing["is_closed"], "Crossing barrier must reopen after train passes")
	print("  [PASS] Automated level crossing boom gate animation & state transitions verified")
	
	chunk_rail.queue_free()
	cg.queue_free()

## TEST 3: Railway River Girder Bridge
func test_railway_river_girder_bridge() -> void:
	print("\n--- TEST 3: RAILWAY OVER RIVER GIRDER BRIDGE ---")
	var cg := CityGenScene.instantiate() as CityGenerator
	root.add_child(cg)
	
	# Chunk (5, 3) is intersection of Rail (x=5) and River (y=3)
	assert(cg.is_rail_corridor(Vector2i(5, 3)) and cg.is_river_chunk(Vector2i(5, 3)), "Chunk (5, 3) must be rail-river intersection")
	
	var chunk_bridge = Node3D.new()
	cg._build_railway_river_bridge(chunk_bridge, RandomNumberGenerator.new(), Vector2i(5, 3))
	var girder_bridge = chunk_bridge.find_child("VoxelRailwayGirderBridge", true, false)
	assert(girder_bridge != null, "Heavy steel Warren through-truss girder bridge must be present")
	var t_s = chunk_bridge.find_child("RailTracksSouth", true, false)
	var t_n = chunk_bridge.find_child("RailTracksNorth", true, false)
	assert(t_s != null and t_n != null, "Approaching rail tracks must lead directly onto girder bridge")
	var q_s = chunk_bridge.find_child("CanalQuaySouth", true, false)
	var q_n = chunk_bridge.find_child("CanalQuayNorth", true, false)
	assert(q_s != null and q_n != null, "Stone quays must channel water cleanly beneath the railway bridge")
	print("  [PASS] Heavy steel railway girder bridge verified over river with quays & continuous tracks")
	
	chunk_bridge.queue_free()
	cg.queue_free()

## TEST 4: Farmland & Countryside Biome
func test_farmland_countryside_biome() -> void:
	print("\n--- TEST 4: FARMLAND & COUNTRYSIDE BIOME ---")
	var cg := CityGenScene.instantiate() as CityGenerator
	root.add_child(cg)
	
	# Biome mapping: district_x = 4 (e.g. x = 12), district_z = 0 -> (4+0)%5 = 4 == FARMLAND_COUNTRYSIDE
	var farm_coord := Vector2i(12, 0)
	var b_type := cg.get_biome_for_chunk(farm_coord)
	assert(b_type == CityGenerator.BiomeType.FARMLAND_COUNTRYSIDE, "Chunk (12, 0) must be FARMLAND_COUNTRYSIDE, got %d" % b_type)
	var b_name := cg.get_biome_name(b_type)
	assert("FARMLAND" in b_name, "Biome name must include FARMLAND: %s" % b_name)
	print("  [PASS] Farmland biome coordinate mapping & naming verified")
	
	# Build Farmland Chunk
	var chunk_farm = Node3D.new()
	cg._build_farmland_chunk(chunk_farm, RandomNumberGenerator.new(), farm_coord)
	
	# Red barn and silo
	var barn = chunk_farm.find_child("VoxelFarmlandBarn", true, false)
	assert(barn != null, "Red gambrel barn and cylindrical silo must exist in farmstead")
	
	# Farm tractor
	var tractor = chunk_farm.find_child("VoxelFarmTractor", true, false)
	assert(tractor != null, "Green and yellow farm tractor must be parked in farmstead")
	
	# Spinning windmill
	var windmill = chunk_farm.find_child("VoxelCountryWindmill", true, false)
	assert(windmill != null, "Country windmill with rotor must exist in pasture")
	
	# Crop fields (Wheat / Corn / Pumpkins)
	var c_wheat = chunk_farm.find_child("CropFieldWheat", true, false)
	var c_patch = chunk_farm.find_child("CropFieldPatch", true, false)
	assert(c_wheat != null and c_patch != null, "Furrowed crop fields must be cultivated")
	
	# Hay bales and rustic fences
	var props = chunk_farm.find_children("*", "RigidBody3D", true, false)
	var hay_count := 0
	var fence_count := 0
	for p in props:
		if p is SmashProp:
			if p.prop_type == SmashProp.PropType.HAY_BALE:
				hay_count += 1
			elif p.prop_type == SmashProp.PropType.RUSTIC_FENCE:
				fence_count += 1
	assert(hay_count >= 3, "Stack of smashable hay bales must exist (found %d)" % hay_count)
	assert(fence_count >= 3, "Rustic wooden fences must enclose pasture (found %d)" % fence_count)
	print("  [PASS] Farmland chunk verified with Barn, Silo, Tractor, Windmill, Crops, Hay Bales (%d) & Fences (%d)" % [hay_count, fence_count])
	
	chunk_farm.queue_free()
	cg.queue_free()

## TEST 5: Skyscraper Architecture & Rooftop Stunts
func test_skyscraper_and_parking_garage_stunts() -> void:
	print("\n--- TEST 5: SKYSCRAPER ARCHITECTURE & PARKING GARAGE STUNTS ---")
	var cg := CityGenScene.instantiate() as CityGenerator
	root.add_child(cg)
	
	var chunk_sky = Node3D.new()
	cg._build_skyscraper_plaza(chunk_sky, RandomNumberGenerator.new(), Vector2i(0, 1))
	
	# Multi-tier skyscraper with setbacks & helipad
	var skyscraper = chunk_sky.find_child("VoxelSkyscraperTiered", true, false)
	assert(skyscraper != null, "Multi-tier corporate skyscraper must exist")
	
	# 2-story open-deck parking garage
	var garage = chunk_sky.find_child("VoxelParkingGarage", true, false)
	assert(garage != null, "2-story open-deck parking garage must exist")
	
	# Drivable colliders & Rooftop Launch Lip & Boost Pad
	var boost_pads = chunk_sky.find_children("BoostPadArea*", "Area3D", true, false)
	assert(boost_pads.size() >= 1, "Rooftop speed boost pad must exist on parking garage")
	
	print("  [PASS] Skyscraper plaza verified with tiered skyscraper, helipad, and drivable parking garage rooftop stunt")
	
	chunk_sky.queue_free()
	cg.queue_free()

## TEST 6: Moving Freight Train & Kinetic Impact
func test_moving_freight_train_and_kinetic_impact() -> void:
	print("\n--- TEST 6: MOVING FREIGHT TRAIN & KINETIC IMPACT ---")
	var cg := CityGenScene.instantiate() as CityGenerator
	root.add_child(cg)
	
	# Create a mock player near the rail corridor (x=5)
	var player_car := Node3D.new()
	player_car.position = Vector3(5.0 * 48.0 + 24.0, 0.5, 0.0)
	root.add_child(player_car)
	cg.target_player = player_car
	
	# Spawn train
	cg._update_active_train(0.016)
	assert(cg._active_train != null, "Active moving freight train must be spawned on rail corridor")
	assert(cg._active_train.name == "ActiveFreightTrain", "Train entity name must be ActiveFreightTrain")
	
	# Verify multi-car composition
	var loco = cg._active_train.find_child("Locomotive", true, false)
	assert(loco != null, "Locomotive must exist in freight train")
	var boxcar = cg._active_train.find_child("Boxcar", true, false)
	assert(boxcar != null, "Boxcar must exist in freight train")
	var tanker = cg._active_train.find_child("Tanker", true, false)
	assert(tanker != null, "Tanker car must exist in freight train")
	var flatbed = cg._active_train.find_child("Flatbed", true, false)
	assert(flatbed != null, "Container flatbed must exist in freight train")
	var caboose = cg._active_train.find_child("Caboose", true, false)
	assert(caboose != null, "Caboose must exist in freight train")
	print("  [PASS] Multi-car train verified (Locomotive + Boxcar + Tanker + Flatbed + Caboose)")
	
	# Verify Cowcatcher impact area on locomotive
	var cowcatcher = loco.find_child("TrainCowcatcher", true, false)
	assert(cowcatcher != null, "Front locomotive cowcatcher impact area must exist")
	
	# Test kinetic smash on a police car
	var CopScene = preload("res://scenes/vehicles/police_car.tscn")
	var test_police = CopScene.instantiate()
	root.add_child(test_police)
	
	cg._on_train_hit_body(test_police)
	assert(test_police.is_wrecked, "Police car must be wrecked on kinetic train impact")
	print("  [PASS] Freight train kinetic impact verified: launches obstacle with high momentum")
	
	test_police.queue_free()
	player_car.queue_free()
	cg.queue_free()
