class_name TrafficManager
extends Node3D

## Civilian NPC Road Traffic Manager for Smashy Heist: Daily Getaway.
## Coordinates lane-following NPC civilian cars across active city chunks:
## - Spawns up to 10 active vehicles (Taxis, Buses, Pizza Vans, Dump Trucks, Ambulances, Tankers)
## - Keeps right-hand lane discipline (+3.0m offset from center line)
## - High-Speed Near-Miss Detection (< 2.4m at > 10 m/s awards +50 pts)
## - Manages recycling and despawning beyond 95m

signal near_miss_achieved(car: NPCTrafficCar, bonus: int)

const MAX_ACTIVE_TRAFFIC: int = 36
const DESPAWN_DISTANCE: float = 95.0
const NEAR_MISS_DISTANCE: float = 2.4
const MIN_NEAR_MISS_SPEED: float = 10.0

@export var target_player: Node3D = null

var _traffic_scene: PackedScene = preload("res://scenes/vehicles/npc_traffic_car.tscn")
var _active_cars: Array[NPCTrafficCar] = []
var _spawn_cooldown: float = 0.0
var _cash_truck_timer: float = 30.0
var _near_miss_cooldowns: Dictionary = {} # car -> float

func _ready() -> void:
	# Locate player car if not explicitly assigned
	if target_player == null and get_parent():
		target_player = get_parent().find_child("ArcadeCar", true, false)
	
	# Pre-populate roads with initial civilian traffic wave
	call_deferred("_prepopulate_traffic")

func _prepopulate_traffic() -> void:
	if not _traffic_scene:
		return
	if target_player == null or not is_instance_valid(target_player):
		if get_parent():
			target_player = get_parent().find_child("ArcadeCar", true, false)
	if target_player == null or not is_instance_valid(target_player):
		return
	for i in range(22):
		_try_spawn_traffic_car(true)

func _process(delta: float) -> void:
	# Dynamically target active player (on-foot runner or vehicle)
	if is_inside_tree():
		var runners := get_tree().get_nodes_in_group("player_character")
		var active_runner: Node3D = null
		for r in runners:
			if is_instance_valid(r) and not r.is_queued_for_deletion():
				active_runner = r as Node3D
				break
		if active_runner:
			target_player = active_runner
		elif target_player == null or not is_instance_valid(target_player) or (target_player is ArcadeCar and (target_player as ArcadeCar).is_abandoned):
			var cars := get_tree().get_nodes_in_group("player")
			for c in cars:
				if c is ArcadeCar and is_instance_valid(c) and not c.is_queued_for_deletion() and not c.is_abandoned:
					target_player = c as Node3D
					break
			if target_player == null and get_parent():
				target_player = get_parent().find_child("ArcadeCar", true, false)
	
	if target_player == null or not is_instance_valid(target_player):
		return
	
	# Update near-miss cooldowns
	for c in _near_miss_cooldowns.keys():
		_near_miss_cooldowns[c] -= delta
		if _near_miss_cooldowns[c] <= 0.0:
			_near_miss_cooldowns.erase(c)
	
	# Clean invalid or distant cars
	_cleanup_distant_cars()
	
	# Check near misses
	_check_near_misses()
	
	# Spawn cash truck piñata every 30s
	_cash_truck_timer -= delta
	if _cash_truck_timer <= 0.0:
		_cash_truck_timer = 30.0
		spawn_cash_truck()
	
	# Spawn new cars rapidly if below max limit
	_spawn_cooldown -= delta
	if _spawn_cooldown <= 0.0 and _active_cars.size() < MAX_ACTIVE_TRAFFIC:
		_spawn_cooldown = randf_range(0.20, 0.45)
		_try_spawn_traffic_car(false)

func _cleanup_distant_cars() -> void:
	var player_pos: Vector3 = target_player.global_position
	var to_remove: Array[NPCTrafficCar] = []
	
	for car in _active_cars:
		if not is_instance_valid(car):
			to_remove.append(car)
			continue
		
		var dist := car.global_position.distance_to(player_pos)
		if dist > DESPAWN_DISTANCE:
			to_remove.append(car)
			car.queue_free()
	
	for car in to_remove:
		_active_cars.erase(car)
		_near_miss_cooldowns.erase(car)

func _check_near_misses() -> void:
	var player_pos: Vector3 = target_player.global_position
	var player_vel: Vector3 = Vector3.ZERO
	if target_player is ArcadeCar and (target_player as ArcadeCar).physics_sphere:
		player_vel = (target_player as ArcadeCar).physics_sphere.linear_velocity
	elif target_player is RigidBody3D:
		player_vel = (target_player as RigidBody3D).linear_velocity
	
	var player_speed := player_vel.length()
	if player_speed < MIN_NEAR_MISS_SPEED:
		return
	
	for car in _active_cars:
		if not is_instance_valid(car) or car.is_panicking:
			continue
		if _near_miss_cooldowns.has(car):
			continue
		
		var dist := car.global_position.distance_to(player_pos)
		if dist <= NEAR_MISS_DISTANCE and dist >= 0.8: # Close proximity without crashing
			_near_miss_cooldowns[car] = 2.0
			_trigger_near_miss(car)

func _trigger_near_miss(car: NPCTrafficCar) -> void:
	near_miss_achieved.emit(car, 75)
	
	# Award +75 Near-Miss Points
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		if wm and wm.has_method("add_score"):
			wm.add_score(75)
	
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		sfx.play_drift_boost()
	
	# Show notification & 3D floating text on TouchHUD
	var hud: TouchHUD = null
	if get_parent():
		hud = get_parent().find_child("TouchHUD", true, false) as TouchHUD
	if not hud and get_tree() and get_tree().root:
		hud = get_tree().root.find_child("TouchHUD", true, false) as TouchHUD
	
	if hud and hud.has_method("spawn_floating_text"):
		hud.spawn_floating_text(car.global_position, "⚡ +75 CLOSE CALL!", Color("fbc531"), 1.1)
	elif hud and "loot_banner" in hud and hud.loot_banner:
		hud.loot_banner.text = "⚡ +75 CLOSE CALL!"
		hud.loot_banner.visible = true
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(hud) and hud.loot_banner and hud.loot_banner.text == "⚡ +75 CLOSE CALL!":
				hud.loot_banner.visible = false
		)

func _try_spawn_traffic_car(is_initial: bool = false) -> void:
	if not _traffic_scene:
		return
	
	var player_pos: Vector3 = target_player.global_position
	var chunk_x := int(floor(player_pos.x / 48.0))
	var chunk_z := int(floor(player_pos.z / 48.0))
	
	# Pick a nearby road chunk (1-2 chunks ahead or sideways)
	var offset_x: int = [-2, -1, 0, 1, 2].pick_random()
	var offset_z: int = [-2, -1, 0, 1, 2].pick_random()
	if offset_x == 0 and offset_z == 0:
		offset_z = 1
	
	var spawn_chunk := Vector2i(chunk_x + offset_x, chunk_z + offset_z)
	var road_axis: int = randi() % 2 # 0: X-road, 1: Z-road
	
	var spawn_pos: Vector3
	var dir: Vector3
	
	if road_axis == 0:
		# Driving along X axis at Z = chunk_z * 48 + 24
		var center_z: float = spawn_chunk.y * 48.0 + 24.0
		var going_east: bool = (randf() > 0.5)
		dir = Vector3(1.0 if going_east else -1.0, 0.0, 0.0)
		var lane_offset_z: float = 3.0 if going_east else -3.0 # Right-hand lane
		spawn_pos = Vector3(
			spawn_chunk.x * 48.0 + randf_range(6.0, 42.0),
			0.6,
			center_z + lane_offset_z
		)
	else:
		# Driving along Z axis at X = chunk_x * 48 + 24
		var center_x: float = spawn_chunk.x * 48.0 + 24.0
		var going_south: bool = (randf() > 0.5)
		dir = Vector3(0.0, 0.0, 1.0 if going_south else -1.0)
		var lane_offset_x: float = -3.0 if going_south else 3.0 # Right-hand lane
		spawn_pos = Vector3(
			center_x + lane_offset_x,
			0.6,
			spawn_chunk.y * 48.0 + randf_range(6.0, 42.0)
		)
	
	# Avoid spawning directly on player (< 14m initial, < 22m continuous) or out of bounds (> 88m)
	var spawn_dist := spawn_pos.distance_to(player_pos)
	var min_dist: float = 10.0 if is_initial else 16.0
	if spawn_dist < min_dist or spawn_dist > 88.0:
		return
	
	# Separation check to prevent overlapping spawns
	for c in _active_cars:
		if is_instance_valid(c) and c.global_position.distance_to(spawn_pos) < 4.5:
			return
	
	var car := _traffic_scene.instantiate() as NPCTrafficCar
	car.position = spawn_pos
	car.lane_direction = dir
	car.npc_type = randi() % 6 # Random civilian type 0 to 5 fallback
	
	# Spawn from all 100 fleet cars across Common, Rare, Epic, Legendary, and Mythic tiers!
	var vdb = null
	if is_inside_tree():
		vdb = get_node_or_null("/root/VehicleDatabase")
	elif Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st and st.root:
			vdb = st.root.get_node_or_null("VehicleDatabase")
	
	if vdb and vdb.has_method("get_common_cars"):
		var roll := randf()
		var chosen_pool: Array[Dictionary] = []
		if roll < 0.40:
			chosen_pool = vdb.get_common_cars()
		elif roll < 0.68:
			chosen_pool = vdb.get_rare_cars()
		elif roll < 0.86:
			chosen_pool = vdb.get_epic_cars()
		elif roll < 0.96:
			chosen_pool = vdb.get_legendary_cars()
		else:
			chosen_pool = vdb.get_mythic_cars()
		
		if chosen_pool.is_empty():
			chosen_pool = vdb.get_common_cars()
		
		if not chosen_pool.is_empty():
			var picked: Dictionary = chosen_pool.pick_random()
			car.car_id = String(picked.get("id", ""))
	
	add_child(car)
	_active_cars.append(car)

const CashTruckPinataScript = preload("res://scripts/vehicles/cash_truck_pinata.gd")

## Spawns the golden armored cash truck piñata
func spawn_cash_truck() -> NPCTrafficCar:
	if not target_player:
		return null
	
	var player_pos: Vector3 = target_player.global_position
	var chunk_x := int(floor(player_pos.x / 48.0))
	var chunk_z := int(floor(player_pos.z / 48.0))
	
	var offset_x: int = [1, -1].pick_random()
	var offset_z: int = [1, -1].pick_random()
	var spawn_chunk := Vector2i(chunk_x + offset_x, chunk_z + offset_z)
	
	var center_z: float = spawn_chunk.y * 48.0 + 24.0
	var spawn_pos: Vector3 = Vector3(spawn_chunk.x * 48.0 + 24.0, 0.6, center_z + 3.0)
	var dir: Vector3 = Vector3(1.0, 0.0, 0.0)
	
	var truck: NPCTrafficCar = CashTruckPinataScript.new()
	truck.position = spawn_pos
	truck.lane_direction = dir
	add_child(truck)
	_active_cars.append(truck)
	return truck
