class_name PoliceSpawner
extends Node3D

## Perimeter Wave Spawner & Tactical Roadblock Coordinator.
## Manages police unit density, perimeter wave spawning, distance culling, and roadblock placement.

const PoliceCarScene: PackedScene = preload("res://scenes/vehicles/police_car.tscn")
const SmashPropScene: PackedScene = preload("res://scenes/props/smash_prop.tscn")
const SpikeStripScript = preload("res://scripts/props/spike_strip.gd")
const TrapMineScript = preload("res://scripts/props/trap_mine.gd")

var _spawn_timer: float = 0.0
var _roadblock_timer: float = 0.0
var _cached_player: Node3D = null

const SPAWN_INTERVAL: float = 2.0
const ROADBLOCK_INTERVAL: float = 12.0
const CULL_DISTANCE: float = 90.0
const MIN_SPAWN_DIST: float = 46.0
const MAX_SPAWN_DIST: float = 62.0

func _physics_process(delta: float) -> void:
	if not has_node("/root/WantedManager"):
		return
	
	var wm = get_node("/root/WantedManager")
	if not wm.is_run_active:
		return
	
	if not _cached_player or not is_instance_valid(_cached_player) or _cached_player.is_queued_for_deletion() or (_cached_player is ArcadeCar and (_cached_player as ArcadeCar).is_abandoned):
		_cached_player = _find_player()
	
	if not _cached_player or not is_instance_valid(_cached_player):
		return
	
	var player_pos: Vector3 = _cached_player.global_position
	if _cached_player is ArcadeCar and (_cached_player as ArcadeCar).car_pivot:
		player_pos = (_cached_player as ArcadeCar).car_pivot.global_position
	
	# 1. Periodic Wave Spawning (every 2.0s)
	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		_cull_distant_police(player_pos)
		_try_spawn_wave(player_pos, wm)
	
	# 2. Roadblocks (Wanted Level >= 2, every 12.0s)
	if wm.wanted_stars >= 2:
		_roadblock_timer += delta
		if _roadblock_timer >= ROADBLOCK_INTERVAL:
			_roadblock_timer = 0.0
			_try_spawn_roadblock(player_pos)

func _cull_distant_police(player_pos: Vector3) -> void:
	var units := get_tree().get_nodes_in_group("police_units")
	for unit in units:
		if is_instance_valid(unit) and unit is Node3D:
			var unit_3d := unit as Node3D
			var pos: Vector3 = unit_3d.global_position
			if unit is PoliceCar and (unit as PoliceCar).physics_sphere:
				pos = (unit as PoliceCar).physics_sphere.global_position
			if pos.distance_to(player_pos) > CULL_DISTANCE:
				unit.queue_free()

func _get_player_velocity() -> Vector3:
	if not _cached_player or not is_instance_valid(_cached_player):
		return Vector3.ZERO
	if _cached_player is ArcadeCar:
		var ac := _cached_player as ArcadeCar
		if ac.physics_sphere:
			return ac.physics_sphere.linear_velocity
	elif "velocity" in _cached_player:
		return _cached_player.velocity
	elif "linear_velocity" in _cached_player:
		return _cached_player.linear_velocity
	return Vector3.ZERO

func _get_player_heading() -> Vector3:
	if not _cached_player or not is_instance_valid(_cached_player):
		return Vector3.FORWARD
	var p_vel: Vector3 = _get_player_velocity()
	if p_vel.length() > 2.0:
		return p_vel.normalized()
	if _cached_player is ArcadeCar:
		var ac := _cached_player as ArcadeCar
		if ac.car_pivot:
			return -ac.car_pivot.global_transform.basis.z.normalized()
	return -_cached_player.global_transform.basis.z.normalized()

func _try_spawn_wave(player_pos: Vector3, wm: Variant) -> void:
	var active_units := get_tree().get_nodes_in_group("police_units")
	if active_units.size() >= wm.max_active_units:
		return
	
	var player_vel: Vector3 = _get_player_velocity()
	var player_heading: Vector3 = _get_player_heading()
	
	# Attempt candidate positions
	for attempt in range(5):
		var angle_offset: float = 0.0
		if randf() < 0.60:
			# 60% biased within 90-degree forward cone (-45° to +45°)
			angle_offset = randf_range(-PI * 0.25, PI * 0.25)
		else:
			# 40% flanking or rear
			angle_offset = randf_range(PI * 0.25, PI * 0.85) * (-1.0 if randf() < 0.5 else 1.0)
		
		var base_angle: float = atan2(player_heading.x, player_heading.z)
		var final_angle: float = base_angle + angle_offset
		var dist: float = randf_range(MIN_SPAWN_DIST, MAX_SPAWN_DIST)
		var candidate: Vector3 = player_pos + Vector3(sin(final_angle), 0.0, cos(final_angle)) * dist
		
		var spawn_pos: Vector3 = _validate_spawn_position(candidate)
		if spawn_pos != Vector3.INF:
			_spawn_police_car(spawn_pos, player_pos, wm.wanted_stars)
			break

func _validate_spawn_position(pos: Vector3) -> Vector3:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	# Cast ray downwards through Layer 1 (Ground) and Layer 4 (Buildings)
	var ray := PhysicsRayQueryParameters3D.create(
		pos + Vector3(0, 25, 0),
		pos + Vector3(0, -6, 0),
		1 | 8 # Layers 1 and 4
	)
	var hit: Dictionary = space_state.intersect_ray(ray)
	if hit and hit.has("collider"):
		var col: Object = hit["collider"]
		if col is CollisionObject3D:
			var c_obj := col as CollisionObject3D
			# Reject if hitting a building (Layer 4)
			if c_obj.get_collision_layer_value(4):
				return Vector3.INF
			# Reject if below canal level (water hazard)
			var hit_pos: Vector3 = hit["position"]
			if hit_pos.y < -0.3:
				return Vector3.INF
			return hit_pos
	return Vector3.INF

func _spawn_police_car(pos: Vector3, player_pos: Vector3, stars: int) -> PoliceCar:
	var car := PoliceCarScene.instantiate() as PoliceCar
	
	# Select type by heat level
	var type: PoliceCar.PoliceType = PoliceCar.PoliceType.PATROL_CRUISER
	var roll: float = randf()
	match stars:
		1:
			type = PoliceCar.PoliceType.PATROL_CRUISER
		2:
			type = PoliceCar.PoliceType.INTERCEPTOR_MUSCLE if roll > 0.6 else PoliceCar.PoliceType.PATROL_CRUISER
		3:
			if roll < 0.35:
				type = PoliceCar.PoliceType.PATROL_CRUISER
			elif roll < 0.70:
				type = PoliceCar.PoliceType.INTERCEPTOR_MUSCLE
			else:
				type = PoliceCar.PoliceType.SWAT_VAN
		4:
			if roll < 0.20:
				type = PoliceCar.PoliceType.PATROL_CRUISER
			elif roll < 0.55:
				type = PoliceCar.PoliceType.INTERCEPTOR_MUSCLE
			else:
				type = PoliceCar.PoliceType.SWAT_VAN
		_:
			if roll < 0.30:
				type = PoliceCar.PoliceType.INTERCEPTOR_MUSCLE
			elif roll < 0.65:
				type = PoliceCar.PoliceType.SWAT_VAN
			else:
				type = PoliceCar.PoliceType.RHINO_TANK
	
	car.police_type = type
	car.position = pos + Vector3(0, 0.6, 0)
	
	# Look towards player
	var look_dir: Vector3 = player_pos - pos
	look_dir.y = 0.0
	if look_dir.length() > 0.1:
		car.transform.basis = Basis.looking_at(look_dir.normalized(), Vector3.UP)
	
	add_child(car)
	if car.physics_sphere:
		car.physics_sphere.global_position = pos + Vector3(0, 0.6, 0)
		
		# Escape Road 3 Momentum: police spawn hot on the gas with initial forward pursuit speed
		var p_vel: Vector3 = _get_player_velocity()
		var p_spd: float = p_vel.length()
		if p_spd > 4.0:
			var f_dir: Vector3 = look_dir.normalized()
			if look_dir.dot(p_vel) > -0.2:
				# Rear or flanking pursuit: spawn at or above player speed so they actively catch up
				var launch_spd: float = clampf(p_spd * randf_range(0.95, 1.15), 14.0, 25.0)
				car.physics_sphere.linear_velocity = f_dir * launch_spd
			else:
				# Forward interceptor: spawn charging into the intersection
				var intercept_spd: float = randf_range(13.0, 18.0)
				car.physics_sphere.linear_velocity = f_dir * intercept_spd
	
	return car

func _try_spawn_roadblock(player_pos: Vector3) -> void:
	var player_vel: Vector3 = _get_player_velocity()
	var heading: Vector3 = _get_player_heading()
	
	var raw_ahead: Vector3 = player_pos + heading * 46.0
	
	# Align to nearest city grid road axis (roads centered at 24 + 48*N)
	var is_north_south: bool = absf(heading.z) >= absf(heading.x)
	var roadblock_center: Vector3 = raw_ahead
	
	if is_north_south:
		# North-South road: snap X to road center
		var chunk_x: float = floorf(raw_ahead.x / 48.0) * 48.0 + 24.0
		roadblock_center.x = chunk_x
	else:
		# East-West road: snap Z to road center
		var chunk_z: float = floorf(raw_ahead.z / 48.0) * 48.0 + 24.0
		roadblock_center.z = chunk_z
	
	var valid_pos: Vector3 = _validate_spawn_position(roadblock_center)
	if valid_pos == Vector3.INF:
		return
	roadblock_center.y = valid_pos.y
	
	# Roadblock vehicle types scale with wanted level (Escape Road 3)
	var wm = get_node_or_null("/root/WantedManager")
	var stars: int = wm.wanted_stars if (wm and "wanted_stars" in wm) else 2
	var cop1_type: PoliceCar.PoliceType = PoliceCar.PoliceType.PATROL_CRUISER
	var cop2_type: PoliceCar.PoliceType = PoliceCar.PoliceType.PATROL_CRUISER
	if stars >= 4:
		cop1_type = PoliceCar.PoliceType.SWAT_VAN
		cop2_type = PoliceCar.PoliceType.SWAT_VAN
	elif stars >= 3:
		cop1_type = PoliceCar.PoliceType.SWAT_VAN if randf() < 0.6 else PoliceCar.PoliceType.PATROL_CRUISER
		cop2_type = PoliceCar.PoliceType.PATROL_CRUISER
	
	# Spawn 2 parked barricade vehicles nose-to-nose
	var cop1 := PoliceCarScene.instantiate() as PoliceCar
	cop1.police_type = cop1_type
	cop1.is_parked = true
	
	var cop2 := PoliceCarScene.instantiate() as PoliceCar
	cop2.police_type = cop2_type
	cop2.is_parked = true
	
	if is_north_south:
		# Roadblock spans across X
		cop1.position = roadblock_center + Vector3(-2.8, 0.6, 0.0)
		cop1.rotation_degrees = Vector3(0, 90, 0)
		cop2.position = roadblock_center + Vector3(2.8, 0.6, 0.0)
		cop2.rotation_degrees = Vector3(0, -90, 0)
	else:
		# Roadblock spans across Z
		cop1.position = roadblock_center + Vector3(0.0, 0.6, -2.8)
		cop1.rotation_degrees = Vector3(0, 0, 0)
		cop2.position = roadblock_center + Vector3(0.0, 0.6, 2.8)
		cop2.rotation_degrees = Vector3(0, 180, 0)
	
	add_child(cop1)
	add_child(cop2)
	if cop1.physics_sphere:
		cop1.physics_sphere.global_position = cop1.position
	if cop2.physics_sphere:
		cop2.physics_sphere.global_position = cop2.position
	
	# Spawn 3 SmashProp obstacles flanking the roadblock (wooden fences or explosive barrels at 4+ stars)
	for i in range(3):
		var prop := SmashPropScene.instantiate() as SmashProp
		if stars >= 4 and i != 1:
			prop.prop_type = SmashProp.PropType.EXPLOSIVE_BARREL
		else:
			prop.prop_type = SmashProp.PropType.FENCE
		
		if is_north_south:
			prop.position = roadblock_center + Vector3(-4.8 + float(i) * 4.8, 0.0, 0.0)
			prop.rotation_degrees = Vector3(0, 0, 0)
		else:
			prop.position = roadblock_center + Vector3(0.0, 0.0, -4.8 + float(i) * 4.8)
			prop.rotation_degrees = Vector3(0, 90, 0)
		add_child(prop)
	
	# Escape Road 3 Mechanic: Deploy Spike Strip across the road at Stars >= 3
	if stars >= 3:
		var spike: Area3D = SpikeStripScript.new()
		spike.position = roadblock_center + (Vector3(0.0, 0.1, -2.5) if is_north_south else Vector3(-2.5, 0.1, 0.0))
		if not is_north_south:
			spike.rotation_degrees = Vector3(0, 90, 0)
		add_child(spike)
	
	# Escape Road 3 Mechanic: Deploy Trap Mine on road shoulder at Stars >= 4
	if stars >= 4:
		var mine: Area3D = TrapMineScript.new()
		mine.position = roadblock_center + (Vector3(randf_range(-3.5, 3.5), 0.1, 3.2) if is_north_south else Vector3(3.2, 0.1, randf_range(-3.5, 3.5)))
		add_child(mine)
	
	# Spawn 2 Police Officers on foot guarding the roadblock!
	var OfficerScript = load("res://scripts/characters/police_officer.gd")
	if OfficerScript:
		for j in range(2):
			var off: CharacterBody3D = OfficerScript.new()
			var off_offset: Vector3 = Vector3(-3.5 if j == 0 else 3.5, 0.1, 1.2) if is_north_south else Vector3(1.2, 0.1, -3.5 if j == 0 else 3.5)
			add_child(off)
			off.global_position = roadblock_center + off_offset

func _find_player() -> Node3D:
	var runners := get_tree().get_nodes_in_group("player_character")
	for r in runners:
		if is_instance_valid(r) and not r.is_queued_for_deletion():
			return r as Node3D
	var player_nodes := get_tree().get_nodes_in_group("player")
	for p in player_nodes:
		if is_instance_valid(p) and not p.is_queued_for_deletion() and p is ArcadeCar and not (p as ArcadeCar).is_abandoned:
			return p as Node3D
	for p in player_nodes:
		if is_instance_valid(p) and not p.is_queued_for_deletion() and p is ArcadeCar:
			return p as Node3D
	return get_tree().root.find_child("ArcadeCar", true, false) as Node3D
