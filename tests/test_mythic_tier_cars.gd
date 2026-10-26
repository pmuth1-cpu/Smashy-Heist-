extends SceneTree

## Integration Test Suite: 4 Mythic Tier Cars & Gameplay Car Equip System
## Verifies 100-Car Database Milestone, 3D Voxel Meshes, Gadgets, CarsScreen, and Gameplay Equipping

const CarsScreenScene = preload("res://scripts/ui/cars_screen.gd")
const ArcadeCarScene = preload("res://scenes/vehicles/arcade_car.tscn")

func _init() -> void:
	await process_frame
	await process_frame
	
	print("\n=================================================================")
	print("   STARTING 4 MYTHIC TIER CARS & EQUIP INTEGRATION TESTS         ")
	print("=================================================================")
	
	test_vehicle_database_100_cars()
	test_voxel_car_builder_mythic()
	await test_car_gadgets_mythic()
	await test_car_equip_in_gameplay()
	await test_cars_screen_mythic_filter()
	await test_mythic_trails_and_explosion_fx()
	
	print("\n=================================================================")
	print("   ALL MYTHIC TIER & CAR EQUIP TESTS PASSED (100% GREEN)         ")
	print("=================================================================\n")
	quit(0)

func _get_vdb() -> Node:
	var vdb: Node = root.get_node_or_null("/root/VehicleDatabase")
	if not vdb:
		var vdb_script = load("res://scripts/autoload/vehicle_database.gd")
		vdb = vdb_script.new()
		vdb.name = "VehicleDatabase"
		root.add_child(vdb)
	return vdb

func _get_vab() -> Node:
	var vab: Node = root.get_node_or_null("/root/VoxelAssetBuilder")
	if not vab:
		var vab_script = load("res://scripts/autoload/voxel_asset_builder.gd")
		vab = vab_script.new()
		vab.name = "VoxelAssetBuilder"
		root.add_child(vab)
	return vab

func _get_sm() -> Node:
	var sm: Node = root.get_node_or_null("/root/SaveManager")
	if not sm:
		var sm_script = load("res://scripts/autoload/save_manager.gd")
		sm = sm_script.new()
		sm.name = "SaveManager"
		root.add_child(sm)
	return sm

## TEST 1: Vehicle Database 100-Car Fleet & Mythic Tier Validation
func test_vehicle_database_100_cars() -> void:
	print("\n--- TEST 1: 100-CAR FLEET & MYTHIC DATABASE VALIDATION ---")
	var vdb = _get_vdb()
	
	var total_ids = vdb.get_all_car_ids()
	print("  Total vehicles registered: %d" % total_ids.size())
	assert(total_ids.size() == 100, "VehicleDatabase MUST contain exactly 100 vehicles! Found: %d" % total_ids.size())
	
	var common_cars: Array = vdb.get_common_cars()
	var rare_cars: Array = vdb.get_rare_cars()
	var epic_cars: Array = vdb.get_epic_cars()
	var leg_cars: Array = vdb.get_legendary_cars()
	var mythic_cars: Array = vdb.get_mythic_cars()
	
	print("  Tiers breakdown: %d COMMON, %d RARE, %d EPIC, %d LEGENDARY, %d MYTHIC" % [
		common_cars.size(), rare_cars.size(), epic_cars.size(), leg_cars.size(), mythic_cars.size()
	])
	assert(common_cars.size() == 30, "Expected 30 COMMON cars, got %d" % common_cars.size())
	assert(rare_cars.size() == 30, "Expected 30 RARE cars, got %d" % rare_cars.size())
	assert(epic_cars.size() == 24, "Expected 24 EPIC cars, got %d" % epic_cars.size())
	assert(leg_cars.size() == 12, "Expected 12 LEGENDARY cars, got %d" % leg_cars.size())
	assert(mythic_cars.size() == 4, "Expected 4 MYTHIC cars, got %d" % mythic_cars.size())
	
	var expected_mythics = ["fire_dragon", "dark_matter_phantom", "ufo_flying_saucer", "cosmic_hyper_star"]
	for m_id in expected_mythics:
		assert(vdb.has_car(m_id), "Mythic car %s must be present in VehicleDatabase" % m_id)
		var car = vdb.get_car(m_id)
		assert(car["rarity_tier"] == "MYTHIC", "Car %s must have rarity_tier MYTHIC" % m_id)
		assert(car["stars"] == 5, "Car %s must have 5 stars" % m_id)
		assert(car.has("gadget_id") and not car["gadget_id"].is_empty(), "Car %s missing gadget_id" % m_id)
		assert(car.has("passive_perk") and not car["passive_perk"].is_empty(), "Car %s missing passive perk" % m_id)
		for stat in ["speed", "accel", "handling", "boost", "mass_weight", "max_hp"]:
			assert(car.has(stat) and car[stat] > 0.0, "Car %s stat %s must be > 0" % [m_id, stat])
	
	print("  [PASS] 100-car fleet milestone confirmed with exactly 4 Mythic cars.")

## TEST 2: Procedural 3D Voxel Meshes for all 4 Mythic Cars
func test_voxel_car_builder_mythic() -> void:
	print("\n--- TEST 2: VOXEL CAR BUILDER 3D MESH GENERATION (MYTHIC) ---")
	var vab = _get_vab()
	var vdb = _get_vdb()
	var mythic_cars: Array = vdb.get_mythic_cars()
	
	var built_count: int = 0
	for car in mythic_cars:
		var cid: String = car["id"]
		var mesh_root: Node3D = vab.build_player_car_visuals(cid)
		assert(mesh_root != null, "build_player_car_visuals must return Node3D for %s" % cid)
		assert(mesh_root.get_child_count() > 0, "Car %s mesh root must have procedural voxel children" % cid)
		mesh_root.queue_free()
		built_count += 1
		print("  Built 3D mesh for: %s" % cid)
	
	assert(built_count == 4, "Expected 4 Mythic 3D models built, got %d" % built_count)
	print("  [PASS] Successfully generated 3D procedural meshes for all 4 Mythic cars.")

## TEST 3: Mythic Car Gadget Activation Suite
func test_car_gadgets_mythic() -> void:
	print("\n--- TEST 3: MYTHIC CAR GADGET ACTIVATION SUITE ---")
	var dummy_car: ArcadeCar = ArcadeCarScene.instantiate()
	root.add_child(dummy_car)
	await process_frame
	await process_frame
	
	var gadget_system: CarGadgetSystem = dummy_car.get_node_or_null("CarGadgetSystem")
	assert(gadget_system != null, "CarGadgetSystem must be attached to ArcadeCar")
	
	var mythic_test_cars = [
		"fire_dragon",
		"dark_matter_phantom",
		"ufo_flying_saucer",
		"cosmic_hyper_star"
	]
	
	for cid in mythic_test_cars:
		if dummy_car.stats == null:
			dummy_car.stats = CarStats.new()
		dummy_car.stats.car_id = cid
		dummy_car.current_hp = 100.0
		gadget_system.cooldown = 0.0
		
		var activated: bool = gadget_system.activate_gadget()
		assert(activated, "Gadget for Mythic car %s must activate successfully" % cid)
		assert(gadget_system.cooldown > 0.0, "Gadget for %s must set cooldown" % cid)
		gadget_system.cooldown = 0.0
		print("  Activated gadget for: %s (name: %s)" % [cid, gadget_system.gadget_name])
	
	dummy_car.queue_free()
	print("  [PASS] Successfully verified all 4 Mythic gadget handlers.")

## TEST 4: Car Equipping in Gameplay & SaveManager Persistence
func test_car_equip_in_gameplay() -> void:
	print("\n--- TEST 4: CAR EQUIP SYSTEM & GAMEPLAY PROPAGATION ---")
	var sm = _get_sm()
	var vdb = _get_vdb()
	
	var test_cars = [
		"default_coupe",          # Common Starter
		"boss_mustang_302",       # Common non-starter
		"skyline_phantom",        # Rare
		"midnight_supra",         # Epic
		"tron_light_cycle",       # Legendary
		"dark_matter_phantom",    # Mythic
		"ufo_flying_saucer"       # Mythic
	]
	
	var dummy_car: ArcadeCar = ArcadeCarScene.instantiate()
	root.add_child(dummy_car)
	await process_frame
	await process_frame
	
	for cid in test_cars:
		# 1. Equip in SaveManager
		var equip_result: bool = sm.equip_car(cid)
		assert(equip_result, "SaveManager.equip_car(%s) MUST succeed" % cid)
		assert(sm.equipped_car_id == cid, "SaveManager.equipped_car_id must be %s" % cid)
		assert(cid in sm.unlocked_cars, "Car %s must be in unlocked_cars" % cid)
		
		# 2. Propagate to ArcadeCar
		dummy_car._on_car_equipped(cid)
		assert(dummy_car.stats != null, "ArcadeCar stats must not be null for %s" % cid)
		assert(dummy_car.stats.car_id == cid, "ArcadeCar stats.car_id must match equipped car %s" % cid)
		
		var expected_stats = vdb.get_car_stats(cid)
		assert(is_equal_approx(dummy_car.physics_sphere.mass, expected_stats.mass_weight), "ArcadeCar mass must match stats mass")
		
		# Verify voxel model attached
		var car_pivot = dummy_car.get_node_or_null("CarPivot")
		assert(car_pivot != null, "ArcadeCar must have CarPivot")
		var visual = car_pivot.get_node_or_null("VoxelCarVisual")
		assert(visual != null, "VoxelCarVisual must be mounted inside CarPivot for %s" % cid)
		
		print("  [EQUIP OK] Successfully equipped %-22s -> ArcadeCar synchronized!" % cid)
	
	dummy_car.queue_free()
	print("  [PASS] Car equip persistence and in-game ArcadeCar synchronization fully confirmed.")

## TEST 5: CarsScreen Virtualized Carousel & Mythic Rarity Filter
func test_cars_screen_mythic_filter() -> void:
	print("\n--- TEST 5: CARS SCREEN MYTHIC CAR INTEGRATION ---")
	var cars_screen: Control = CarsScreenScene.new()
	root.add_child(cars_screen)
	await process_frame
	await process_frame
	
	# Switch filter to MYTHIC
	cars_screen.set_filter("MYTHIC")
	assert(cars_screen.current_filter == "MYTHIC", "Filter must be set to MYTHIC")
	
	var visible_mythic_cards: int = 0
	for cid in cars_screen._car_cards:
		if cars_screen._car_cards[cid].visible:
			visible_mythic_cards += 1
	
	print("  Visible MYTHIC cars in carousel: %d" % visible_mythic_cards)
	assert(visible_mythic_cards == 4, "Filtered carousel for MYTHIC must show exactly 4 cars, got: %d" % visible_mythic_cards)
	
	# Select each of the 4 Mythic cars and verify preview + equip
	var mythic_ids = ["fire_dragon", "dark_matter_phantom", "ufo_flying_saucer", "cosmic_hyper_star"]
	var sm = _get_sm()
	for cid in mythic_ids:
		cars_screen.select_car(cid)
		assert(cars_screen.current_car_id == cid, "Selected car must be %s" % cid)
		assert(cars_screen._car_mount.get_child_count() > 0, "3D turntable must contain mounted car mesh for %s" % cid)
		assert(cars_screen._rarity_badge_label.text.to_upper() == "MYTHIC", "Rarity badge must show MYTHIC")
		assert(sm.equipped_car_id == cid, "SaveManager must reflect equipped car %s from CarsScreen" % cid)
		print("  Selected and previewed Mythic car: %s" % cid)
	
	cars_screen.queue_free()
	print("  [PASS] CarsScreen filtering, 4 Mythic cards visibility, 3D preview, and equip confirmed.")

## TEST 6: Mythic Particle Trails, Upgraded Helicopter-Style Explosion FX, and Cop Durability
func test_mythic_trails_and_explosion_fx() -> void:
	print("\n--- TEST 6: MYTHIC TRAILS, HELICOPTER EXPLOSION FX & COP DURABILITY ---")
	
	# 1. Mythic Particle Trails
	var dummy_car: ArcadeCar = ArcadeCarScene.instantiate()
	root.add_child(dummy_car)
	await process_frame
	await process_frame
	
	var mythic_ids = ["fire_dragon", "dark_matter_phantom", "ufo_flying_saucer", "cosmic_hyper_star"]
	for mid in mythic_ids:
		dummy_car._on_car_equipped(mid)
		assert(dummy_car.mythic_trail != null, "Mythic car %s must instantiate mythic_trail" % mid)
		assert(dummy_car.mythic_trail_aux != null, "Mythic car %s must instantiate mythic_trail_aux" % mid)
		assert(dummy_car.current_mythic_car_id == mid, "current_mythic_car_id must be %s" % mid)
		assert(dummy_car.mythic_trail.get_parent() == dummy_car.car_pivot, "mythic_trail must be child of car_pivot")
		print("  [TRAIL OK] Mythic trail active for: %s" % mid)
	
	# Non-mythic car should have no trail
	dummy_car._on_car_equipped("default_coupe")
	assert(dummy_car.mythic_trail == null, "Non-mythic car must clear mythic_trail")
	assert(dummy_car.mythic_trail_aux == null, "Non-mythic car must clear mythic_trail_aux")
	print("  [TRAIL OK] Non-mythic car cleared mythic trail successfully.")
	dummy_car.queue_free()
	
	# 2. Helicopter-Bomb Explosion FX Validation
	var ExplosionFXClass = load("res://scripts/world/explosion_fx.gd")
	var fx = ExplosionFXClass.spawn(root, Vector3(0, 1, 0), 1.5)
	assert(fx != null, "ExplosionFX.spawn must return Node3D instance")
	await process_frame
	
	var fireball = fx.get_node_or_null("Fireball")
	var shockwave = fx.get_node_or_null("ShockwaveRing")
	var shrapnel = fx.get_node_or_null("BombShrapnelBurst")
	var embers = fx.get_node_or_null("FireEmbers")
	var blast_light = fx.get_node_or_null("BlastLight")
	
	assert(fireball != null, "ExplosionFX must contain Fireball mesh")
	assert(shockwave != null, "ExplosionFX must contain ShockwaveRing mesh")
	assert(shrapnel != null, "ExplosionFX must contain BombShrapnelBurst GPUParticles3D")
	assert(embers != null, "ExplosionFX must contain FireEmbers GPUParticles3D")
	assert(blast_light != null, "ExplosionFX must contain BlastLight OmniLight3D")
	print("  [FX OK] Upgraded helicopter-style car explosion VFX verified with all layers.")
	
	# 3. Police Officer Durability Check
	var OfficerScript = load("res://scripts/characters/police_officer.gd")
	var cop: PoliceOfficer = OfficerScript.new()
	root.add_child(cop)
	await process_frame
	
	assert(cop.max_hp >= 80.0, "Police officer max_hp must be at least 80.0, found: %f" % cop.max_hp)
	assert(cop.current_hp >= 80.0, "Police officer current_hp must be at least 80.0, found: %f" % cop.current_hp)
	assert(cop.has_method("take_damage"), "Police officer must have take_damage method")
	
	cop.take_damage(20.0)
	assert(cop.current_hp > 50.0, "Cop should not die easily! HP after 20 dmg: %f" % cop.current_hp)
	assert(not cop.is_eliminated, "Cop must remain alive after 20 dmg")
	cop.queue_free()
	print("  [COP OK] Police officer durability and survivability verified.")
	
	print("  [PASS] Mythic trails, helicopter bomb VFX, and cop durability verified.")

