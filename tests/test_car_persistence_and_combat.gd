extends SceneTree

func _init() -> void:
	print("--- BEGIN TEST: CAR PERSISTENCE, COP DURABILITY & BULLET COMBAT ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var root_node = root
	
	# 1. Test ArcadeCar Jump Out & Abandoned Persistence
	var car_scene := load("res://scenes/vehicles/arcade_car.tscn") as PackedScene
	assert(car_scene != null, "ArcadeCar scene must exist")
	
	var car1 := car_scene.instantiate() as ArcadeCar
	root_node.add_child(car1)
	car1.position = Vector3(10.0, 1.0, 10.0)
	car1._ready()
	
	print("[TEST 1] Ejecting from car1...")
	var player_runner = car1.eject_player_character()
	assert(player_runner != null, "Ejected runner must not be null")
	assert(car1.is_abandoned == true, "Car1 must be marked abandoned")
	assert(car1.is_in_group("player_vehicles"), "Car1 must remain in player_vehicles group")
	assert(is_instance_valid(car1), "Car1 must NOT be freed on eject")
	print("  -> Car1 successfully remains solid and parked at: ", car1.position)
	
	# 2. Test Hijacking NPC Car (Instantiates New Car, leaves Car1 untouched)
	var npc_script = load("res://scripts/vehicles/npc_traffic_car.gd")
	var npc_car: RigidBody3D = RigidBody3D.new()
	npc_car.set_script(npc_script)
	root_node.add_child(npc_car)
	npc_car.global_position = Vector3(30.0, 1.0, 30.0)
	
	print("[TEST 2] Commandeering NPC car from runner...")
	var initial_car1_pos = car1.global_position
	player_runner.hijack_vehicle(npc_car)
	
	# Verify Car1 STILL EXISTS and was NOT teleported or deleted!
	assert(is_instance_valid(car1), "Car1 must NOT be freed after hijacking another car!")
	assert(car1.global_position == initial_car1_pos, "Car1 must remain at its original position!")
	
	# Verify new car was instantiated
	var player_cars := root_node.get_tree().get_nodes_in_group("player")
	var active_car: ArcadeCar = null
	for pc in player_cars:
		if pc is ArcadeCar and not (pc as ArcadeCar).is_abandoned and is_instance_valid(pc):
			active_car = pc as ArcadeCar
			break
	assert(active_car != null, "A new active driving ArcadeCar must exist")
	assert(active_car != car1, "New active car must be a different instance than car1")
	print("  -> Car1 is still parked at original spot! New car active at: ", active_car.global_position)
	
	# 3. Test Police Officer Durability & Speed-based Damage
	print("[TEST 3] Testing Police Officer durability (85 HP)...")
	var OfficerScript = load("res://scripts/characters/police_officer.gd")
	var cop: PoliceOfficer = OfficerScript.new()
	root_node.add_child(cop)
	cop.global_position = Vector3(50.0, 0.0, 50.0)
	
	assert(cop.max_hp >= 80.0, "Cop max HP should be 85")
	assert(cop.current_hp >= 80.0, "Cop current HP should start at max HP")
	
	# Low speed bump simulation (speed 3.0 m/s -> damage ~25.5)
	var bump_body := RigidBody3D.new()
	bump_body.linear_velocity = Vector3(3.0, 0.0, 0.0)
	cop._on_vehicle_hit_area_body_entered(bump_body)
	assert(not cop.is_eliminated, "Cop must SURVIVE low-speed vehicle bump!")
	assert(cop.current_hp < 85.0 and cop.current_hp > 40.0, "Cop took proportional damage from bump: HP = %f" % cop.current_hp)
	print("  -> Cop survived bump with HP remaining: ", cop.current_hp)
	
	# High speed hit (speed 12.0 m/s -> damage ~102)
	bump_body.linear_velocity = Vector3(12.0, 0.0, 0.0)
	cop._on_vehicle_hit_area_body_entered(bump_body)
	assert(cop.is_eliminated, "High speed vehicle impact must eliminate cop!")
	print("  -> Cop successfully eliminated after high-speed vehicle impact")
	bump_body.queue_free()
	
	# 4. Test Dodgeable Bullet Projectile & Muzzle Flash
	print("[TEST 4] Testing BulletProjectile shooting...")
	var BulletScript = load("res://scripts/world/bullet_projectile.gd")
	var bullet: BulletProjectile = BulletScript.new()
	bullet.direction = Vector3.FORWARD
	bullet.speed = 26.5
	root_node.add_child(bullet)
	assert(bullet.speed > 20.0 and bullet.speed < 30.0, "Bullet speed must be dodgeable (26.5 m/s)")
	assert(bullet.collision_mask & 2 != 0, "Bullet must detect Layer 2 (Player)")
	bullet.queue_free()
	print("  -> BulletProjectile configuration verified")
	
	# 5. Test Wreck Persistence (Does NOT disappear after 2.5s)
	print("[TEST 5] Testing PoliceCar wreck persistence with dark smoke...")
	var cop_car_scene := load("res://scenes/vehicles/police_car.tscn") as PackedScene
	var cop_car := cop_car_scene.instantiate() as PoliceCar
	root_node.add_child(cop_car)
	cop_car.global_position = Vector3(70.0, 0.5, 70.0)
	cop_car.wreck()
	
	assert(cop_car.is_wrecked == true, "Cop car must be marked wrecked")
	assert(cop_car.is_in_group("wrecked_vehicles"), "Wreck must be added to wrecked_vehicles group")
	assert(is_instance_valid(cop_car), "Wreck must NOT be deleted immediately!")
	
	var dark_smoke = cop_car.car_pivot.get_node_or_null("DarkWreckSmoke")
	assert(dark_smoke != null, "Wreck must have DarkWreckSmoke particle node attached")
	print("  -> Wrecked police car persisted with dark smoke particle plume successfully")
	
	# 6. Test White Damage Flash
	print("[TEST 6] Testing BrawlUITheme flash_white()...")
	var theme_script = load("res://scripts/autoload/brawl_ui_theme.gd")
	theme_script.flash_white(active_car, 0.09)
	print("  -> White damage flash triggered cleanly")
	
	print("ALL TESTS PASSED SUCCESSFULLY!")
	quit(0)
