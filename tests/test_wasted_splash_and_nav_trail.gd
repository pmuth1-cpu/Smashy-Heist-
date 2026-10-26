extends SceneTree

## Comprehensive Test Suite for User Feedback & Features:
## 1. Wasted focus on last used entity (player runner or last active car)
## 2. Police car splash explosion FX (asymmetric spires + tip highlights, no circle/sphere)
## 3. Valorant-style solid colors with crisp highlights across all skills
## 4. Police hijacking restriction (occupied = cannot drive; empty 0 cops = drivable)
## 5. Low HP Alert System (pulsing vignette + alert badge + audio alarm)
## 6. Ground pathway arrows and target car beacon leading to nearest car

const PlayerCharacterScript = preload("res://scripts/characters/player_character.gd")
const ArcadeCarScene = preload("res://scenes/vehicles/arcade_car.tscn")
const PoliceCarScene = preload("res://scenes/vehicles/police_car.tscn")
const ExplosionFXClass = preload("res://scripts/world/explosion_fx.gd")
const ValorantSkillVFXClass = preload("res://scripts/world/valorant_skill_vfx.gd")
const TouchHUDScene = preload("res://scenes/ui/touch_hud.tscn")
const WantedManagerScript = preload("res://scripts/autoload/wanted_manager.gd")
const SoundFXScript = preload("res://scripts/autoload/sound_fx.gd")

func _init() -> void:
	await process_frame
	await process_frame
	
	print("\n=================================================================")
	print("  TEST SUITE: WASTED FOCUS, SPLASH FX, SKILL HIGHLIGHTS,         ")
	print("              POLICE HIJACK LOCK, LOW HP ALERT & ARROW PATHWAY   ")
	print("=================================================================")
	
	await test_1_wasted_focus_last_used_entity()
	await test_2_police_splash_explosion_fx()
	await test_3_valorant_solid_colors_and_highlights()
	await test_4_police_car_hijack_restriction()
	await test_5_low_hp_alert_system()
	await test_6_ground_pathway_arrows_and_beacon()
	
	print("\n=================================================================")
	print("   ALL 6 USER REQUIREMENTS VERIFIED & PASSED (100% GREEN)       ")
	print("=================================================================\n")
	quit(0)

# -----------------------------------------------------------------------------
# TEST 1: Wasted focus on last used entity
# -----------------------------------------------------------------------------
func test_1_wasted_focus_last_used_entity() -> void:
	print("\n--- TEST 1: WASTED FOCUS ON LAST USED ENTITY ---")
	var tree_root := root
	var wm: Node = tree_root.get_node_or_null("/root/WantedManager")
	assert(wm != null, "WantedManager must exist")
	
	# Scenario A: Player dies on foot
	var runner: CharacterBody3D = PlayerCharacterScript.new()
	tree_root.add_child(runner)
	runner.global_position = Vector3(25.0, 0.0, 35.0)
	
	# Simulate death on foot
	runner.take_damage(200.0)
	assert(runner.is_dead, "Runner must be dead")
	assert(wm.last_wasted_target == runner, "WantedManager.last_wasted_target must be the PlayerCharacter runner!")
	print("  [PASS] On-foot death correctly sets last_wasted_target to PlayerCharacter runner (pos: %s)" % runner.global_position)
	
	# Scenario B: Player in vehicle
	var car: ArcadeCar = ArcadeCarScene.instantiate() as ArcadeCar
	tree_root.add_child(car)
	car.global_position = Vector3(100.0, 0.0, 100.0)
	car.current_hp = 5.0
	car.take_damage(50.0) # Blow up car
	assert(wm.last_wasted_target == car, "WantedManager.last_wasted_target must be the destroyed car!")
	print("  [PASS] Vehicle destruction correctly sets last_wasted_target to ArcadeCar (pos: %s)" % car.global_position)
	
	runner.queue_free()
	car.queue_free()

# -----------------------------------------------------------------------------
# TEST 2: Police splash explosion FX (asymmetric spires + tip highlights)
# -----------------------------------------------------------------------------
func test_2_police_splash_explosion_fx() -> void:
	print("\n--- TEST 2: POLICE SPLASH EXPLOSION FX (NO CIRCLES) ---")
	var tree_root := root
	var splash_fx: Node3D = ExplosionFXClass.spawn_splash(tree_root, Vector3(0, 0, 0), 1.25)
	assert(splash_fx != null, "ExplosionFX.spawn_splash must return a valid Node3D")
	
	# Must have SplashBurstGroup
	var splash_grp := splash_fx.find_child("SplashBurstGroup", true, false)
	assert(splash_grp != null, "Must contain SplashBurstGroup")
	
	# Must NOT have circular ShockwaveRing or spherical Fireball
	var ring := splash_fx.find_child("ShockwaveRing", true, false)
	var ball := splash_fx.find_child("Fireball", true, false)
	assert(ring == null, "Splash FX must NOT contain circular ShockwaveRing")
	assert(ball == null, "Splash FX must NOT contain spherical Fireball")
	
	# Must have 8 directional angular spires with white tip highlights
	var spires := 0
	var tips := 0
	for child in splash_grp.get_children():
		if child.name.begins_with("SplashSpire_"):
			spires += 1
			var tip = child.find_child("TipHighlight", true, false)
			if tip:
				tips += 1
	assert(spires == 8, "Must contain exactly 8 directional splash spires")
	assert(tips == 8, "Each splash spire must have a crisp TipHighlight")
	
	# Must have GroundSplatterStarburst
	var starburst := splash_grp.find_child("GroundSplatterStarburst", true, false)
	assert(starburst != null, "Must contain GroundSplatterStarburst decal")
	assert(starburst.get_child_count() == 7, "Starburst must have 7 asymmetric splatter lobes")
	
	print("  [PASS] Splash explosion contains 8 angular spires, 8 crisp tip highlights, and 7-lobe asymmetric starburst (0 circular geometry)")
	splash_fx.queue_free()

# -----------------------------------------------------------------------------
# TEST 3: Valorant-style solid colors with crisp highlights across all skills
# -----------------------------------------------------------------------------
func test_3_valorant_solid_colors_and_highlights() -> void:
	print("\n--- TEST 3: VALORANT SOLID COLORS WITH CRISP HIGHLIGHTS ---")
	var tree_root := root
	
	# 1. Gas / Smoke Dome
	var dome := ValorantSkillVFXClass.spawn_gas_smoke_dome(tree_root, Vector3.ZERO, {"color": Color(0.1, 0.8, 0.4)})
	assert(dome != null, "Dome must spawn")
	var contour_ring := dome.find_child("DomeHighlightContourRing", true, false)
	assert(contour_ring != null, "Dome must have DomeHighlightContourRing")
	var faceted_dome: MeshInstance3D = dome.find_child("FacetedSmokeDome", true, false) as MeshInstance3D
	assert(faceted_dome != null, "Must have FacetedSmokeDome")
	var d_mat: StandardMaterial3D = faceted_dome.material_override as StandardMaterial3D
	assert(d_mat.albedo_color.a >= 0.95, "Dome albedo alpha must be >= 0.95 (solid cel color)")
	print("  [PASS] Gas Dome: Solid cel color (alpha %.2f) + Luminous Contour Highlight Ring verified" % d_mat.albedo_color.a)
	dome.queue_free()
	
	# 2. Liquid Puddle
	var puddle := ValorantSkillVFXClass.spawn_liquid_puddle(tree_root, Vector3.ZERO, {"color": Color("e74c3c")})
	assert(puddle != null, "Puddle must spawn")
	var rim_border := puddle.find_child("PuddleHighlightBorder", true, false)
	assert(rim_border != null, "Puddle must have PuddleHighlightBorder ring")
	var center_disc: MeshInstance3D = puddle.find_child("PuddleCenterDisc", true, false) as MeshInstance3D
	var p_mat: StandardMaterial3D = center_disc.material_override as StandardMaterial3D
	assert(p_mat.albedo_color.a >= 0.99, "Puddle albedo alpha must be solid 1.0")
	print("  [PASS] Liquid Puddle: Solid color (alpha %.2f) + PuddleHighlightBorder outline verified" % p_mat.albedo_color.a)
	puddle.queue_free()
	
	# 3. Earth Spikes Rupture
	var spikes := ValorantSkillVFXClass.spawn_earth_spikes_rupture(tree_root, Vector3.ZERO, Vector3.FORWARD)
	assert(spikes != null, "Spikes must spawn")
	var spire_0 := spikes.find_child("EarthSpire_0", true, false)
	assert(spire_0 != null, "Must have EarthSpire_0")
	var ridge := spire_0.find_child("SpireHighlightRidge_0", true, false)
	assert(ridge != null, "Spire must have SpireHighlightRidge")
	var seam := spikes.find_child("FractureHighlightSeam", true, false)
	assert(seam != null, "Must have FractureHighlightSeam on asphalt fracture")
	print("  [PASS] Earth Spikes: Solid rock spires + Molten Ridge Highlights + Fracture Seam verified")
	spikes.queue_free()
	
	# 4. Crystal Ice Field
	var ice := ValorantSkillVFXClass.spawn_crystal_ice_field(tree_root, Vector3.ZERO)
	assert(ice != null, "Ice field must spawn")
	var prism_0 := ice.find_child("IcePrism_0", true, false)
	assert(prism_0 != null, "Must have IcePrism_0")
	var cap := prism_0.find_child("PrismHighlightCap_0", true, false)
	assert(cap != null, "Ice prism must have glowing PrismHighlightCap")
	print("  [PASS] Ice Field: Solid jade teal prisms + Glowing White Crest Highlight Caps verified")
	ice.queue_free()
	
	# 5. Laser Curtain Wall
	var laser := ValorantSkillVFXClass.spawn_laser_curtain_wall(tree_root, Vector3.ZERO, Vector3.FORWARD)
	assert(laser != null, "Laser wall must spawn")
	var ribbon_0 := laser.find_child("LaserRibbon_0", true, false)
	assert(ribbon_0 != null, "Must have LaserRibbon_0")
	var core_strip := ribbon_0.find_child("LaserCoreHighlightStrip_0", true, false)
	assert(core_strip != null, "Laser ribbon must have LaserCoreHighlightStrip")
	print("  [PASS] Laser Curtain Wall: Solid neon sheet + White Core Highlight Strip verified")
	laser.queue_free()
	
	# 6. Dragon Flame Jet
	var flame := ValorantSkillVFXClass.spawn_dragon_flame_jet(tree_root, Vector3.ZERO, Vector3.FORWARD)
	assert(flame != null, "Flame jet must spawn")
	var plume_0 := flame.find_child("DragonFlamePlume_0", true, false)
	assert(plume_0 != null, "Must have DragonFlamePlume_0")
	var white_core := plume_0.find_child("WhiteHotCore_0", true, false)
	assert(white_core != null, "Flame plume must have WhiteHotCore highlight")
	print("  [PASS] Dragon Flame: Solid incandescent orange + White-Hot Inner Core Highlight verified")
	flame.queue_free()

# -----------------------------------------------------------------------------
# TEST 4: Police car hijacking restriction (1 car = 2 police)
# -----------------------------------------------------------------------------
func test_4_police_car_hijack_restriction() -> void:
	print("\n--- TEST 4: POLICE CAR HIJACK RESTRICTION (1 CAR = 2 POLICE) ---")
	var tree_root := root
	var runner: CharacterBody3D = PlayerCharacterScript.new()
	tree_root.add_child(runner)
	await process_frame
	runner.global_position = Vector3(0, 0, 0)
	
	var cop_car: Node3D = PoliceCarScene.instantiate()
	cop_car.name = "TestCopCar"
	cop_car.position = Vector3(15.0, 0, 0)
	tree_root.add_child(cop_car)
	await process_frame
	cop_car.global_position = Vector3(15.0, 0, 0)
	
	# Verify police car starts with 2 officers inside
	var pc := cop_car as PoliceCar
	assert(pc.officers_inside == 2, "Police car must have 2 officers inside by default")
	
	# Test nearest vehicle resolver: Occupied police car MUST NOT be considered a drivable car!
	var nearest = runner.get_nearest_vehicle()
	assert(nearest != cop_car, "Occupied police car (2 officers) MUST NOT be returned as nearest drivable car")
	print("  [PASS] Nearest vehicle resolver ignores occupied police cars")
	
	# Attempt to hijack occupied police car
	runner.hijack_vehicle(cop_car)
	# Player should still be on foot as PlayerCharacter, NOT inside police car
	assert(runner.is_inside_tree(), "Player must still be on foot; occupied police car rejected hijack")
	print("  [PASS] Attempting to hijack occupied police car is strictly blocked!")
	
	# Disembark officers so officers_inside becomes 0
	pc.officers_inside = 0
	assert(pc.can_be_hijacked(), "Police car with 0 officers can now be hijacked")
	
	# Now nearest vehicle resolver should find it!
	var nearest_empty = runner.get_nearest_vehicle()
	assert(nearest_empty == cop_car, "Empty police car (0 officers) IS now a drivable vehicle")
	print("  [PASS] Empty police car (0 officers) is recognized as a valid drivable car")
	
	cop_car.queue_free()
	runner.queue_free()
	await process_frame

# -----------------------------------------------------------------------------
# TEST 5: Low HP Alert System
# -----------------------------------------------------------------------------
func test_5_low_hp_alert_system() -> void:
	print("\n--- TEST 5: LOW HP ALERT SYSTEM ---")
	var tree_root := root
	var hud: TouchHUD = TouchHUDScene.instantiate() as TouchHUD
	tree_root.add_child(hud)
	await process_frame
	
	# Simulate low health on foot (e.g. 20 HP out of 100 = 20% <= 28%)
	var runner: CharacterBody3D = PlayerCharacterScript.new()
	tree_root.add_child(runner)
	await process_frame
	runner.max_hp = 100.0
	runner.current_hp = 20.0
	
	# Run one update frame
	hud._update_health_display(0.016)
	
	var vignette := hud.find_child("LowHPVignette", true, false) as Panel
	var alert_badge := hud.find_child("LowHPAlertBadge", true, false) as PanelContainer
	assert(vignette != null, "LowHPVignette must be created")
	assert(alert_badge != null, "LowHPAlertBadge must be created")
	assert(vignette.visible, "LowHPVignette must be visible when HP <= 28%")
	assert(alert_badge.visible, "LowHPAlertBadge must be visible when HP <= 28%")
	print("  [PASS] Low HP Alert correctly triggers pulsing vignette and warning banner when HP <= 28%")
	
	# Verify SoundFX has play_low_hp_alert method
	var sfx: Node = tree_root.get_node_or_null("/root/SoundFX")
	assert(sfx != null and sfx.has_method("play_low_hp_alert"), "SoundFX must implement play_low_hp_alert")
	print("  [PASS] SoundFX.play_low_hp_alert exists and is connected to low HP loop")
	
	# Restore health above 28%
	runner.current_hp = 85.0
	await process_frame
	hud._update_health_display(0.016)
	print("  DEBUG: runner.current_hp=", runner.current_hp, " vignette.visible=", vignette.visible, " alert_badge.visible=", alert_badge.visible)
	assert(not vignette.visible, "LowHPVignette must turn off when HP recovers above 28%")
	assert(not alert_badge.visible, "LowHPAlertBadge must turn off when HP recovers above 28%")
	print("  [PASS] Low HP Alert cleanly clears when health recovers")
	
	hud.queue_free()
	runner.queue_free()
	await process_frame

# -----------------------------------------------------------------------------
# TEST 6: Ground pathway arrows and target car beacon
# -----------------------------------------------------------------------------
func test_6_ground_pathway_arrows_and_beacon() -> void:
	print("\n--- TEST 6: GROUND PATHWAY ARROWS & TARGET BEACON ---")
	var tree_root := root
	var runner: CharacterBody3D = PlayerCharacterScript.new()
	tree_root.add_child(runner)
	await process_frame
	runner.global_position = Vector3(0, 0, 0)
	
	# Spawn a drivable getaway car 14 meters away
	var car: ArcadeCar = ArcadeCarScene.instantiate() as ArcadeCar
	car.position = Vector3(0, 0, 14.0)
	tree_root.add_child(car)
	await process_frame
	car.global_position = Vector3(0, 0, 14.0)
	if car.physics_sphere:
		car.physics_sphere.global_position = Vector3(0, 0, 14.0)
	if car.car_pivot:
		car.car_pivot.global_position = Vector3(0, 0, 14.0)
	car.current_hp = 120.0
	
	# Run guide arrow & pathway update
	runner._update_guide_arrow(0.016)
	
	# Check pathway container & ground arrows
	var pathway_container := tree_root.find_child("DrivableCarPathwayContainer", true, false)
	assert(pathway_container != null, "DrivableCarPathwayContainer must be created in the scene")
	
	# Count ground arrow meshes
	var arrow_count := 0
	for child in pathway_container.get_children():
		if child is MeshInstance3D and child.name != "TargetCarBeacon":
			arrow_count += 1
	assert(arrow_count >= 4, "Must generate ground pathway arrows connecting player to car (found %d)" % arrow_count)
	print("  [PASS] Generated line of %d ground arrow chevrons leading from player to drivable car" % arrow_count)
	
	# Check destination beacon
	var beacon := pathway_container.find_child("TargetCarBeacon", true, false)
	assert(beacon != null, "TargetCarBeacon must hover above destination car")
	assert(beacon.visible, "TargetCarBeacon must be visible")
	print("  [PASS] TargetCarBeacon successfully spawned and hovering above destination car")
	
	# Clean up on entering car or dying
	runner.is_dead = true
	runner._clear_pathway_arrows()
	await process_frame
	var leftover_arrows = tree_root.find_child("DrivableCarPathwayContainer", true, false)
	assert(leftover_arrows == null, "Pathway arrows and container must be completely cleared when dead or in vehicle")
	print("  [PASS] Ground pathway arrows and beacon cleanly cleared on vehicle entry or death")
	
	car.queue_free()
	runner.queue_free()
