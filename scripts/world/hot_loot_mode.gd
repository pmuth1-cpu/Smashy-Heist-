class_name HotLootMode
extends Node3D

## 4-Player "Hot Loot" Tag Mode Controller for Smashy Heist: Daily Getaway.
## Coordinates 90-second match countdown, golden LootBagMarker indicator,
## score accumulation, collision tag transfers, police targeting overrides,
## respawning, and 1st-to-4th place podium standings.

signal hot_loot_match_ended(standings: Array[Dictionary])
signal loot_holder_changed(new_holder: Node3D)

@export var is_hot_loot_mode: bool = false
@export var match_time_remaining: float = 90.0
@export var transfer_cooldown: float = 0.0

var loot_holder_car: Node3D = null
var loot_bag_marker: Node3D = null

var _score_accumulator: float = 0.0
var _respawn_timer: float = 0.0
var _respawn_car: ArcadeCar = null

func _ready() -> void:
	_create_loot_bag_marker()

func _create_loot_bag_marker() -> void:
	if loot_bag_marker:
		return
	
	loot_bag_marker = Node3D.new()
	loot_bag_marker.name = "LootBagMarker"
	add_child(loot_bag_marker)
	
	# Glowing golden cylinder crown mesh
	var mesh_inst := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.45
	cylinder.bottom_radius = 0.22
	cylinder.height = 0.45
	
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(1.0, 0.85, 0.1)
	gold_mat.metallic = 0.9
	gold_mat.roughness = 0.2
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(1.0, 0.75, 0.08)
	gold_mat.emission_energy_multiplier = 2.5
	mesh_inst.mesh = cylinder
	mesh_inst.material_override = gold_mat
	loot_bag_marker.add_child(mesh_inst)
	
	# Golden yellow OmniLight3D
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.88, 0.25)
	light.light_energy = 2.8
	light.omni_range = 7.0
	loot_bag_marker.add_child(light)
	
	loot_bag_marker.visible = false

func start_hot_loot_match(cars: Array[ArcadeCar]) -> void:
	is_hot_loot_mode = true
	match_time_remaining = 90.0
	transfer_cooldown = 0.0
	_score_accumulator = 0.0
	
	for car in cars:
		if is_instance_valid(car):
			car.match_score = 0
			car.is_holding_loot = false
	
	if not cars.is_empty():
		var initial_holder: ArcadeCar = cars[0]
		loot_holder_car = initial_holder
		initial_holder.is_holding_loot = true
		loot_holder_changed.emit(initial_holder)
		print("HotLootMode: Match started! Initial holder: %s" % initial_holder.driver_name)

func _process(delta: float) -> void:
	if not loot_bag_marker:
		return
	
	if is_hot_loot_mode and loot_holder_car and is_instance_valid(loot_holder_car):
		loot_bag_marker.visible = true
		var holder_pos: Vector3 = loot_holder_car.car_pivot.global_position if ("car_pivot" in loot_holder_car and loot_holder_car.car_pivot) else loot_holder_car.global_position
		loot_bag_marker.global_position = holder_pos + Vector3(0.0, 2.2, 0.0)
		loot_bag_marker.rotation.y += delta * 4.0
	else:
		loot_bag_marker.visible = false

func _physics_process(delta: float) -> void:
	if not is_hot_loot_mode:
		return
	
	if transfer_cooldown > 0.0:
		transfer_cooldown = maxf(0.0, transfer_cooldown - delta)
	
	# 1. Countdown match timer from 90.0 to 0.0
	match_time_remaining = maxf(0.0, match_time_remaining - delta)
	
	# 2. Award +100 points per second to loot_holder_car
	_score_accumulator += delta
	if _score_accumulator >= 1.0:
		_score_accumulator -= 1.0
		if loot_holder_car and is_instance_valid(loot_holder_car):
			if "match_score" in loot_holder_car:
				loot_holder_car.match_score += 100
	
	# 3. Direct all active PoliceCar AI units to target loot_holder_car's position and velocity!
	if loot_holder_car and is_instance_valid(loot_holder_car):
		var cops := get_tree().get_nodes_in_group("police_units")
		for cop in cops:
			if is_instance_valid(cop) and cop is PoliceCar:
				(cop as PoliceCar).target_override = loot_holder_car
		
		var heli := get_tree().root.find_child("PoliceHeli", true, false)
		if heli and is_instance_valid(heli) and heli is PoliceHeli:
			(heli as PoliceHeli).target_override = loot_holder_car
	
	# 4. Handle scheduled respawn
	if _respawn_car and is_instance_valid(_respawn_car):
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_execute_respawn(_respawn_car)
			_respawn_car = null
	
	# 5. Check match conclusion
	if match_time_remaining <= 0.0:
		end_hot_loot_match()

## Called when two ArcadeCars collide.
func notify_car_collision(car_a: ArcadeCar, car_b: ArcadeCar) -> void:
	if not is_hot_loot_mode or transfer_cooldown > 0.0:
		return
	if not loot_holder_car or not is_instance_valid(loot_holder_car):
		return
	
	if car_a == loot_holder_car and car_b != loot_holder_car:
		if multiplayer.has_multiplayer_peer():
			transfer_loot_bag.rpc(car_b.name)
		else:
			transfer_loot_bag(car_b.name)
	elif car_b == loot_holder_car and car_a != loot_holder_car:
		if multiplayer.has_multiplayer_peer():
			transfer_loot_bag.rpc(car_a.name)
		else:
			transfer_loot_bag(car_a.name)


@rpc("any_peer", "call_local", "reliable")
func transfer_loot_bag(new_holder_name: String) -> void:
	var tree := get_tree()
	var new_holder_node := tree.root.find_child(new_holder_name, true, false)
	if not new_holder_node or not (new_holder_node is ArcadeCar):
		return
	var new_holder: ArcadeCar = new_holder_node as ArcadeCar
	
	var prev_holder: ArcadeCar = loot_holder_car as ArcadeCar
	if prev_holder and is_instance_valid(prev_holder):
		prev_holder.is_holding_loot = false
		var knockback_dir: Vector3 = (prev_holder.global_position - new_holder.global_position).normalized()
		if knockback_dir.is_zero_approx():
			knockback_dir = Vector3(1.0, 0.0, 0.0)
		if prev_holder.physics_sphere:
			prev_holder.physics_sphere.apply_central_impulse(knockback_dir * 18.0)
	
	loot_holder_car = new_holder
	new_holder.is_holding_loot = true
	transfer_cooldown = 1.5
	
	var cam_rig = tree.root.find_child("CameraRig", true, false)
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.4)
	
	loot_holder_changed.emit(new_holder)
	print("HotLootMode: Loot Bag transferred to %s" % new_holder_name)


## Handles when a car gets wrecked or arrested.
func handle_car_busted(car: ArcadeCar, _reason: String) -> void:
	if not is_hot_loot_mode:
		return
	
	# Deduct 200 points
	car.match_score = maxi(0, car.match_score - 200)
	
	if car == loot_holder_car:
		car.is_holding_loot = false
		var rivals := get_tree().get_nodes_in_group("player")
		var nearest_rival: ArcadeCar = null
		var min_dist: float = 99999.0
		for r in rivals:
			if is_instance_valid(r) and r is ArcadeCar and r != car:
				var dist := car.global_position.distance_to(r.global_position)
				if dist < min_dist:
					min_dist = dist
					nearest_rival = r as ArcadeCar
		
		if nearest_rival:
			if multiplayer.has_multiplayer_peer():
				transfer_loot_bag.rpc(nearest_rival.name)
			else:
				transfer_loot_bag(nearest_rival.name)
		else:
			loot_holder_car = null

	
	# Respawn after 2.0s
	_respawn_car = car
	_respawn_timer = 2.0
	if car.physics_sphere:
		car.physics_sphere.linear_velocity = Vector3.ZERO
		car.physics_sphere.angular_velocity = Vector3.ZERO

func _execute_respawn(car: ArcadeCar) -> void:
	if not is_instance_valid(car):
		return
	
	car.current_hp = car.max_hp
	car.busted_progress = 0.0
	var respawn_pos := Vector3(24.0, 0.6, 24.0)
	car.global_position = respawn_pos
	if car.physics_sphere:
		car.physics_sphere.global_position = respawn_pos
		car.physics_sphere.linear_velocity = Vector3.ZERO
		car.physics_sphere.angular_velocity = Vector3.ZERO
	if car.car_pivot:
		car.car_pivot.global_position = respawn_pos + Vector3(0.0, -0.45, 0.0)
	print("HotLootMode: %s respawned after bust/wreck penalty." % car.name)

## Concludes the match and displays the 1st-to-4th Place Podium standings.
func end_hot_loot_match() -> void:
	is_hot_loot_mode = false
	var cars := get_tree().get_nodes_in_group("player")
	var standings: Array[Dictionary] = []
	for c in cars:
		if is_instance_valid(c) and c is ArcadeCar:
			standings.append({
				"name": c.driver_name,
				"score": c.match_score,
				"car": c
			})
	
	standings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["score"]) > int(b["score"])
	)
	
	for i in range(standings.size()):
		standings[i]["rank"] = i + 1
	
	hot_loot_match_ended.emit(standings)
	
	var summary = get_tree().root.find_child("RunSummaryPanel", true, false)
	if summary and summary.has_method("show_podium_standings"):
		summary.show_podium_standings(standings)
	
	print("HotLootMode: Match concluded! Winner: %s" % (standings[0]["name"] if not standings.is_empty() else "None"))
