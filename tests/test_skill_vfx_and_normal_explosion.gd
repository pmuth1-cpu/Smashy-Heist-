extends SceneTree

## Integration Test Suite: Normal Bomb Explosion & Skill Bespoke VFX
## Tests:
## 1. Normal Bomb Explosion (moderate light, compact fireball, tight voxel shrapnel, gentle trauma)
## 2. Healing Plus Symbol VFX (3D "+" symbol cross meshes, green aura ring, omni glow)
## 3. Paint Splat VFX (glossy puddle, organic perimeter splatter splotches, airborne droplets, skid hazard)
## 4. Light Skills: Roof Floodlight with volumetric beam cones, Police Siren Strobe, and Flashbang Light

const ArcadeCarScene = preload("res://scenes/vehicles/arcade_car.tscn")
const CarGadgetSystemScript = preload("res://scripts/vehicles/car_gadget_system.gd")
const ExplosionFXClass = preload("res://scripts/world/explosion_fx.gd")

func _init() -> void:
	await process_frame
	await process_frame
	
	print("\n=================================================================")
	print("   STARTING NORMAL BOMB EXPLOSION & SKILL VFX INTEGRATION TESTS  ")
	print("=================================================================")
	
	await test_normal_bomb_explosion()
	await test_healing_plus_symbol_vfx()
	await test_paint_splat_vfx()
	await test_light_skills_vfx()
	
	print("\n=================================================================")
	print("   ALL NORMAL BOMB & SKILL VFX TESTS PASSED (100% GREEN)         ")
	print("=================================================================\n")
	quit(0)

## TEST 1: Normal Bomb Explosion Verification
func test_normal_bomb_explosion() -> void:
	print("\n--- TEST 1: NORMAL BOMB EXPLOSION VERIFICATION ---")
	var fx: Node3D = ExplosionFXClass.spawn(root, Vector3(0, 1, 0), 1.0)
	assert(fx != null, "ExplosionFX.spawn must return an instance")
	await process_frame
	
	var blast_light: OmniLight3D = fx.get_node_or_null("BlastLight")
	var fireball: MeshInstance3D = fx.get_node_or_null("Fireball")
	var shockwave: MeshInstance3D = fx.get_node_or_null("ShockwaveRing")
	var shrapnel: GPUParticles3D = fx.get_node_or_null("BombShrapnelBurst")
	var embers: GPUParticles3D = fx.get_node_or_null("FireEmbers")
	
	assert(blast_light != null, "Explosion must have BlastLight")
	assert(fireball != null, "Explosion must have Fireball")
	assert(shockwave != null, "Explosion must have ShockwaveRing")
	assert(shrapnel != null, "Explosion must have BombShrapnelBurst")
	assert(embers != null, "Explosion must have FireEmbers")
	
	# Verify moderate, balanced "normal bomb explosion" parameters (not blinding or screen-covering)
	assert(blast_light.light_energy <= 5.0, "Flash light must be moderate (<= 5.0), got: %f" % blast_light.light_energy)
	assert(blast_light.omni_range <= 10.0, "Flash range must be reasonable (<= 10.0), got: %f" % blast_light.omni_range)
	assert(shrapnel.amount <= 20, "Voxel shrapnel count must be tight (<= 20), got: %d" % shrapnel.amount)
	assert(embers.amount <= 14, "Embers count must be compact (<= 14), got: %d" % embers.amount)
	
	print("  [PASS] Normal bomb explosion parameters confirmed: snappy, balanced, and readable.")
	fx.queue_free()

## TEST 2: Healing Plus Symbol VFX
func test_healing_plus_symbol_vfx() -> void:
	print("\n--- TEST 2: HEALING PLUS SYMBOL VFX ---")
	var heal_fx = CarGadgetSystemScript.spawn_healing_plus_fx(root, Vector3(10, 0, 10))
	assert(heal_fx != null, "spawn_healing_plus_fx must return an instance")
	await process_frame
	
	var aura_ring = heal_fx.get_node_or_null("HealAuraRing")
	var flash_light = heal_fx.get_node_or_null("HealFlashLight")
	assert(aura_ring != null, "Healing VFX must have HealAuraRing")
	assert(flash_light != null, "Healing VFX must have HealFlashLight")
	
	# Verify floating 3D "+" plus symbols exist with crossed bars
	var plus_count: int = 0
	for c in heal_fx.get_children():
		if c.name.begins_with("PlusSymbol_"):
			plus_count += 1
			assert(c.get_child_count() == 2, "Each plus symbol node must have 2 crossing bars (horizontal and vertical)")
	assert(plus_count >= 5, "Expected at least 5 plus symbols, found: %d" % plus_count)
	print("  Found %d 3D '+' plus symbols floating with aura ring and green flash." % plus_count)
	
	# Verify ArcadeCar.heal() spawns healing plus VFX
	var dummy_car: ArcadeCar = ArcadeCarScene.instantiate()
	root.add_child(dummy_car)
	await process_frame
	
	dummy_car.current_hp = 50.0
	dummy_car.heal(30.0)
	assert(dummy_car.current_hp == 80.0, "ArcadeCar HP must be repaired")
	await process_frame
	
	var spawned_heal = root.get_node_or_null("HealingPlusFX")
	assert(spawned_heal != null, "ArcadeCar.heal() must spawn HealingPlusFX in the world")
	
	dummy_car.queue_free()
	heal_fx.queue_free()
	if spawned_heal: spawned_heal.queue_free()
	print("  [PASS] Healing plus symbol effect and integration confirmed.")

## TEST 3: Paint Splat VFX
func test_paint_splat_vfx() -> void:
	print("\n--- TEST 3: PAINT SPLAT VFX ---")
	var splat_col = Color("e84118") # Hot sauce red paint
	var splat_fx = CarGadgetSystemScript.spawn_paint_splat_fx(root, Vector3(20, 0, 20), splat_col, 4.0, 14)
	assert(splat_fx != null, "spawn_paint_splat_fx must return an instance")
	await process_frame
	
	var puddle: MeshInstance3D = splat_fx.get_node_or_null("PaintPuddle")
	var hazard_area: Area3D = splat_fx.get_node_or_null("PaintHazardArea")
	assert(puddle != null, "Paint splat must have central PaintPuddle mesh")
	assert(hazard_area != null, "Paint splat must have PaintHazardArea for cop skid collision")
	
	# Verify perimeter splatter splotches and airborne droplets
	var splotch_count: int = 0
	var droplet_count: int = 0
	for c in splat_fx.get_children():
		if c.name.begins_with("SplatDot_"):
			splotch_count += 1
		elif c.name.begins_with("PaintDroplet_"):
			droplet_count += 1
	
	assert(splotch_count >= 6, "Expected at least 6 perimeter splatter splotches, found: %d" % splotch_count)
	assert(droplet_count >= 10, "Expected at least 10 airborne paint droplets, found: %d" % droplet_count)
	print("  Found %d perimeter splatter splotches and %d flying droplets." % [splotch_count, droplet_count])
	
	# Verify glossy liquid material
	assert(puddle.material_override is StandardMaterial3D, "Puddle must use StandardMaterial3D")
	var mat := puddle.material_override as StandardMaterial3D
	assert(mat.roughness <= 0.20, "Paint puddle must have low roughness (glossy wet finish), got: %f" % mat.roughness)
	
	splat_fx.queue_free()
	print("  [PASS] Paint splat effect with glossy puddle, splotches, and droplets confirmed.")

## TEST 4: Light Skills (Roof Floodlight, Siren Strobe, Flashbang)
func test_light_skills_vfx() -> void:
	print("\n--- TEST 4: LIGHT SKILLS VFX (FLOODLIGHT, SIREN STROBE, FLASHBANG) ---")
	var dummy_car: ArcadeCar = ArcadeCarScene.instantiate()
	root.add_child(dummy_car)
	await process_frame
	await process_frame
	
	var gadget_system: CarGadgetSystem = dummy_car.get_node_or_null("CarGadgetSystem")
	assert(gadget_system != null, "ArcadeCar must have CarGadgetSystem")
	
	# 1. Test Roof Floodlight with volumetric beam cones
	gadget_system._activate_floodlight()
	await process_frame
	var fl_rig = dummy_car.car_pivot.get_node_or_null("RoofFloodlightRig")
	assert(fl_rig != null, "RoofFloodlightRig must be mounted on car_pivot")
	assert(fl_rig.get_node_or_null("Spot_L") != null, "Must have left Spotlight")
	assert(fl_rig.get_node_or_null("Spot_R") != null, "Must have right Spotlight")
	assert(fl_rig.get_node_or_null("BeamCone_L") != null, "Must have left volumetric beam cone")
	assert(fl_rig.get_node_or_null("BeamCone_R") != null, "Must have right volumetric beam cone")
	print("  [LIGHT OK] Roof floodlight twin spotlights and volumetric beam cones verified.")
	
	# 2. Test Police Siren Strobe Light
	gadget_system._activate_siren_burst()
	await process_frame
	var siren_rig = dummy_car.car_pivot.get_node_or_null("PoliceSirenStrobeRig")
	assert(siren_rig != null, "PoliceSirenStrobeRig must be mounted on car_pivot")
	assert(siren_rig.get_node_or_null("SirenRedLight") != null, "Must have SirenRedLight")
	assert(siren_rig.get_node_or_null("SirenBlueLight") != null, "Must have SirenBlueLight")
	print("  [LIGHT OK] Police siren alternating red/blue strobe lights verified.")
	
	# 3. Test Flashbang Blinding Light
	gadget_system._activate_flashbang_blast()
	await process_frame
	var fb_light = root.get_node_or_null("FlashbangLight")
	var fb_sphere = root.get_node_or_null("FlashbangSphere")
	assert(fb_light != null, "FlashbangLight must be spawned in the world")
	assert(fb_sphere != null, "FlashbangSphere must be spawned in the world")
	assert(fb_light.light_energy >= 10.0, "Flashbang light must be high intensity (>= 10.0)")
	print("  [LIGHT OK] Flashbang blinding omni-light and expanding light wave verified.")
	
	dummy_car.queue_free()
	print("  [PASS] All light-based skill VFX confirmed.")
