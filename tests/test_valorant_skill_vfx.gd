extends SceneTree

const ValorantSkillVFX = preload("res://scripts/world/valorant_skill_vfx.gd")
const ArcadeCarScene = preload("res://scenes/vehicles/arcade_car.tscn")
const CarGadgetSystemClass = preload("res://scripts/vehicles/car_gadget_system.gd")

func _init() -> void:
	await process_frame
	await process_frame
	
	print("\n=================================================================")
	print("   STARTING VALORANT MULTI-STATE SKILL VFX INTEGRATION TESTS     ")
	print("=================================================================")
	
	var world := Node3D.new()
	root.add_child(world)
	
	# 1. Test Gas Dome
	print("\n--- TEST 1: GAS DOME (VALORANT BRIMSTONE/OMEN STYLE) ---")
	var gas = ValorantSkillVFX.spawn_gas_smoke_dome(world, Vector3.ZERO, {
		"color": Color.WHITE,
		"radius": 5.0,
		"duration": 2.0
	})
	assert(gas != null, "Gas dome should spawn")
	assert(gas.get_node_or_null("GroundPerimeterRing") != null, "Must have GroundPerimeterRing")
	assert(gas.get_node_or_null("FacetedSmokeDome") != null, "Must have FacetedSmokeDome")
	assert(gas.get_node_or_null("SwirlingCloudVortices") != null, "Must have SwirlingCloudVortices")
	print("  [PASS] Gas smoke dome instantiated with perimeter ring and faceted dome")
	
	# 2. Test Liquid Puddle
	print("\n--- TEST 2: LIQUID PUDDLE (VALORANT MOLLY/ACID STYLE) ---")
	var liq = ValorantSkillVFX.spawn_liquid_puddle(world, Vector3(10, 0, 0), {
		"color": Color("e74c3c"),
		"radius": 3.0,
		"is_boiling": true
	})
	assert(liq != null, "Liquid puddle should spawn")
	assert(liq.find_child("PuddleCenterDisc", true, false) != null, "Must have PuddleCenterDisc")
	assert(liq.get_node_or_null("FlyingDroplet_0") != null, "Must have FlyingDroplet")
	assert(liq.get_node_or_null("LiquidBubble_0") != null, "Must have LiquidBubble")
	print("  [PASS] Liquid puddle instantiated with multi-lobed discs, droplets, and bubbles")
	
	# 3. Test Solid Earth Spikes
	print("\n--- TEST 3: SOLID EARTH SPIKES (VALORANT BREACH FAULT LINE STYLE) ---")
	var solid = ValorantSkillVFX.spawn_earth_spikes_rupture(world, Vector3(20, 0, 0), Vector3.FORWARD)
	assert(solid != null, "Earth spikes should spawn")
	assert(solid.get_node_or_null("EarthSpire_0") != null, "Must have EarthSpire")
	assert(solid.get_node_or_null("AsphaltFractureDecal") != null, "Must have AsphaltFractureDecal")
	print("  [PASS] Earth spikes rupture instantiated with jagged spires and fracture decal")
	
	# 4. Test Solid Ice Field
	print("\n--- TEST 4: SOLID ICE FIELD (VALORANT SAGE SLOW ORB/CRYSTAL STYLE) ---")
	var ice = ValorantSkillVFX.spawn_crystal_ice_field(world, Vector3(30, 0, 0))
	assert(ice != null, "Ice field should spawn")
	assert(ice.get_node_or_null("GroundFrostLattice") != null, "Must have GroundFrostLattice")
	assert(ice.get_node_or_null("IcePrism_0") != null, "Must have IcePrism")
	print("  [PASS] Crystal ice field instantiated with ground frost lattice and ice prisms")
	
	# 5. Test Void Singularity
	print("\n--- TEST 5: VOID SINGULARITY (VALORANT ASTRA/FADE COSMIC VORTEX STYLE) ---")
	var void_vortex = ValorantSkillVFX.spawn_void_singularity_vortex(world, Vector3(40, 0, 0))
	assert(void_vortex != null, "Singularity vortex should spawn")
	assert(void_vortex.get_node_or_null("SingularityCore") != null, "Must have SingularityCore")
	assert(void_vortex.get_node_or_null("EventHorizonRing") != null, "Must have EventHorizonRing")
	assert(void_vortex.get_node_or_null("AccretionDisc") != null, "Must have AccretionDisc")
	print("  [PASS] Void singularity vortex instantiated with accretion disc, core, and horizon ring")
	
	# 6. Test Laser Curtain Wall
	print("\n--- TEST 6: LASER CURTAIN WALL (VALORANT NEON FAST LANE STYLE) ---")
	var laser = ValorantSkillVFX.spawn_laser_curtain_wall(world, Vector3(50, 0, 0), Vector3.FORWARD)
	assert(laser != null, "Laser wall should spawn")
	assert(laser.get_node_or_null("LaserRibbon_0") != null, "Must have LaserRibbon")
	print("  [PASS] Laser curtain wall instantiated with twin vertical ribbons and burn decals")
	
	# 7. Test Dragon Flame Jet
	print("\n--- TEST 7: DRAGON FLAME JET (VALORANT INCENDIARY PLASMA STREAM) ---")
	var dragon = ValorantSkillVFX.spawn_dragon_flame_jet(world, Vector3(60, 0, 0), Vector3.FORWARD)
	assert(dragon != null, "Dragon flame jet should spawn")
	assert(dragon.get_node_or_null("DragonFlamePlume_0") != null, "Must have DragonFlamePlume")
	print("  [PASS] Dragon flame jet instantiated with directional plumes and ground molly burn")
	
	# 8. Test CarGadgetSystem Integration
	print("\n--- TEST 8: CAR GADGET SYSTEM INTEGRATION ---")
	var car_inst: ArcadeCar = ArcadeCarScene.instantiate() as ArcadeCar
	world.add_child(car_inst)
	await process_frame
	
	var gadget_sys: CarGadgetSystem = car_inst.get_node_or_null("CarGadgetSystem") as CarGadgetSystem
	assert(gadget_sys != null, "Car must have CarGadgetSystem")
	
	# Test activating smoke screen
	gadget_sys._activate_smoke_screen()
	await process_frame
	var spawned_smoke = world.get_node_or_null("ValorantGasSmokeDome")
	assert(spawned_smoke != null, "Activating smoke screen must spawn ValorantGasSmokeDome")
	print("  [PASS] Smoke Screen gadget spawns ValorantGasSmokeDome")
	
	# Test activating molten tar
	gadget_sys._activate_molten_tar()
	await process_frame
	var spawned_puddle = world.get_node_or_null("ValorantLiquidPuddle")
	assert(spawned_puddle != null, "Activating molten tar must spawn ValorantLiquidPuddle")
	print("  [PASS] Molten Tar gadget spawns ValorantLiquidPuddle")
	
	# Test activating seismic slam
	gadget_sys._activate_seismic_slam()
	await process_frame
	var spawned_earth = world.get_node_or_null("ValorantEarthSpikesRupture")
	assert(spawned_earth != null, "Activating seismic slam must spawn ValorantEarthSpikesRupture")
	print("  [PASS] Seismic Slam gadget spawns ValorantEarthSpikesRupture")
	
	# Test activating singularity vortex
	gadget_sys._activate_singularity_vortex()
	await process_frame
	var spawned_void = world.get_node_or_null("ValorantSingularityVortex")
	assert(spawned_void != null, "Activating singularity vortex must spawn ValorantSingularityVortex")
	print("  [PASS] Singularity Vortex gadget spawns ValorantSingularityVortex")
	
	print("\n=================================================================")
	print("   ALL VALORANT MULTI-STATE SKILL VFX TESTS PASSED (100% GREEN)  ")
	print("=================================================================\n")
	world.queue_free()
	quit(0)
