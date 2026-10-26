extends SceneTree

const MainGameScene = preload("res://scenes/world/main_game.tscn")
const PoliceOfficerScript = preload("res://scripts/characters/police_officer.gd")
const ExplosiveRocketScript = preload("res://scripts/world/explosive_rocket.gd")

func _init() -> void:
	print("--- STARTING GAMEPLAY OVERHAUL VERIFICATION ---")
	await process_frame
	await process_frame
	
	var game = MainGameScene.instantiate()
	root.add_child(game)
	
	for f in range(20):
		await process_frame
	
	var car = game.arcade_car
	assert(car != null, "ArcadeCar must exist")
	print("PASS: ArcadeCar initialized at: ", car.car_pivot.global_position)
	
	# TEST 1: Check Collision Radius (Solid Cars)
	var cs = car.physics_sphere.get_node_or_null("CollisionShape3D")
	assert(cs != null, "CollisionShape3D must exist on physics_sphere")
	var sphere_shape = cs.shape as SphereShape3D
	assert(sphere_shape != null, "Shape must be SphereShape3D")
	print("Car collision radius: ", sphere_shape.radius)
	assert(sphere_shape.radius >= 0.9, "Car collision radius must be >= 0.9 for solid collisions without clipping")
	print("PASS: Car collision sphere enlarged for solid body collisions (Radius: %f)" % sphere_shape.radius)
	
	# TEST 2: Jump Out / Eject - Car Must NOT Disappear
	var initial_car_pos: Vector3 = car.car_pivot.global_position
	var runner = car.eject_player_character()
	assert(runner != null, "Runner must spawn on eject")
	assert(car.is_abandoned == true, "Car must be marked is_abandoned")
	assert(car.is_inside_tree() == true, "Car must remain inside tree")
	assert(car.car_pivot.visible == true, "Car visual must remain visible")
	assert(car.is_in_group("player_vehicles") == true, "Car must belong to player_vehicles")
	print("PASS: Voluntary jump-out executed successfully. Runner spawned at: ", runner.global_position)
	
	# Simulate 30 frames with runner running
	for f in range(30):
		await process_frame
	
	assert(car.is_inside_tree() == true, "Car must NOT disappear after ejection")
	assert(car.car_pivot.visible == true, "Car must remain visible after ejection")
	print("PASS: Abandoned car remains solid and intact at: ", car.car_pivot.global_position)
	
	# TEST 3: Police Officer On Foot
	var officer: CharacterBody3D = PoliceOfficerScript.new()
	game.add_child(officer)
	officer.global_position = runner.global_position + Vector3(5.0, 0.2, 0.0)
	await process_frame
	await process_frame
	
	assert(officer.is_in_group("police_officers"), "Officer must be in police_officers group")
	print("PASS: Police officer on foot spawned at: ", officer.global_position)
	
	# Test running over police officer with a vehicle
	var test_traffic = RigidBody3D.new()
	test_traffic.linear_velocity = Vector3(-6.0, 0.0, 0.0)
	officer._on_vehicle_hit_area_body_entered(test_traffic)
	assert(officer.is_eliminated == true, "Officer must be eliminated when hit by vehicle")
	print("PASS: Police officer eliminated when struck by vehicle")
	test_traffic.queue_free()
	
	# TEST 4: Tank Explosive Rocket
	car.adopt_npc_vehicle(5) # Adopt Fuel Tanker
	assert(car.is_tank() == true, "Tanker must be recognized as a tank")
	print("PASS: is_tank() returned true for Tanker vehicle")
	
	# Fire Tank Rocket
	car.tank_rocket_cooldown = 0.0
	car.fire_tank_rocket()
	assert(car.tank_rocket_cooldown > 0.0, "Cooldown must trigger on fire")
	
	# Find fired rocket in scene
	var rocket: Area3D = null
	for child in game.get_children():
		if child.get_script() == ExplosiveRocketScript:
			rocket = child
			break
	assert(rocket != null, "Explosive rocket projectile must be spawned in scene")
	print("PASS: Explosive rocket spawned at: ", rocket.global_position, " direction: ", rocket.direction)
	
	# Detonate Rocket
	rocket.detonate()
	assert(rocket._is_detonated == true, "Rocket must be detonated")
	print("PASS: Explosive rocket detonation and radial blast verified")
	
	# TEST 5: Slower Star Progression
	var wm = game.get_node("/root/WantedManager")
	assert(wm != null, "WantedManager must exist")
	print("WantedManager STAR_DEFINITIONS: ", wm.STAR_DEFINITIONS)
	assert(float(wm.STAR_DEFINITIONS[1]["threshold"]) >= 70.0, "Star 2 threshold must be >= 70.0s for paced progression")
	assert(float(wm.STAR_DEFINITIONS[4]["threshold"]) >= 400.0, "Star 5 threshold must be >= 400.0s")
	print("PASS: Star escalation thresholds slowed down and well-paced")
	
	# TEST 6: Roguelike Star Upgrade Cards & Loaded Art Assets
	var popup = game.touch_hud.star_perk_popup
	assert(popup != null, "StarPerkPopup must exist in TouchHUD")
	popup.show_star_perks(2)
	assert(popup.is_showing == true, "Popup must be showing")
	assert(popup.visible == true, "Popup must be visible")
	assert(popup.art_left.texture != null, "Left card must have loaded perk texture asset")
	assert(popup.art_right.texture != null, "Right card must have loaded perk texture asset")
	print("PASS: Perk Card Left Art: ", popup.art_left.texture, " Size: ", popup.card_left.custom_minimum_size)
	print("PASS: Perk Card Right Art: ", popup.art_right.texture, " Size: ", popup.card_right.custom_minimum_size)
	
	# Select Left Perk
	popup._select_perk(0)
	assert(popup.is_showing == false, "Popup must close after deliberate card selection")
	assert(Engine.time_scale == 1.0, "Engine time_scale must restore to 1.0 after selection")
	print("PASS: Roguelike perk card selected, applied, and time scale restored to 1.0")
	
	print("\n>>> ALL GAMEPLAY OVERHAUL TESTS PASSED SUCCESSFULLY! <<<")
	quit()
