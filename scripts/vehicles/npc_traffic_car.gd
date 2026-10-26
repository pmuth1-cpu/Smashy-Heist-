class_name NPCTrafficCar
extends RigidBody3D

## Civilian NPC Road Traffic Vehicle for Smashy Heist: Daily Getaway.
## Features:
## - 6 Civilian Vehicle Types (Yellow Taxi, City Bus, Pizza Van, Dump Truck, Ambulance, Fuel Tanker)
## - Lane-following along road grid (+3.0m right-hand lane offset, 14.0 m/s cruise speed)
## - Forward 6.5m RayCast for automatic braking and hazard light flashing
## - Intersection turning decisions (65% straight, 20% right, 15% left)
## - Panic ragdoll state on impact (+100 score)
## - Ambulance drops +30 HP Medkit; Fuel Tanker triggers 12m chain-reaction explosion

signal traffic_crashed(car: NPCTrafficCar, rammer: Node3D)
signal fuel_tanker_exploded(pos: Vector3, radius: float)

enum NPCType {
	YELLOW_TAXI = 0,
	CITY_BUS = 1,
	PIZZA_DELIVERY_VAN = 2,
	DUMP_TRUCK = 3,
	AMBULANCE_VAN = 4,
	FUEL_TANKER_SEMI = 5
}

@export var car_id: String = "":
	set(val):
		car_id = val
		if is_inside_tree() and car_pivot:
			_apply_car_id_profile()

@export var npc_type: int = 0
@export var cruise_speed: float = 11.5
@export var lane_direction: Vector3 = Vector3(0, 0, 1)

var car_pivot: Node3D = null
var forward_ray: RayCast3D = null
var visual_model: Node3D = null
var npc_trail: GPUParticles3D = null

var is_panicking: bool = false
var panic_timer: float = 0.0
var is_braking: bool = false
var has_exploded: bool = false
var has_dropped_medkit: bool = false

var _last_intersection_chunk: Vector2i = Vector2i(999999, 999999)
var _hazard_flash_timer: float = 0.0
var _hazard_state: bool = false
var _hazard_lights: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("npc_traffic")
	collision_layer = 16 # Layer 5: SmashProps
	collision_mask = 1 | 2 | 4 | 8 | 16 # Ground, PlayerCar, PoliceCar, Buildings, SmashProps
	
	mass = 4.0 if npc_type in [NPCType.CITY_BUS, NPCType.DUMP_TRUCK, NPCType.FUEL_TANKER_SEMI] else 2.5
	gravity_scale = 1.6
	
	# Strict vehicle angular stability (no top/marble spinning)
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true
	angular_damp = 15.0
	
	# Create physics collision shape if not already present or configure existing BoxShape3D
	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs == null:
		cs = CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		if npc_type in [NPCType.CITY_BUS, NPCType.DUMP_TRUCK, NPCType.FUEL_TANKER_SEMI]:
			box.size = Vector3(1.8, 1.3, 4.4)
		else:
			box.size = Vector3(1.5, 0.85, 2.7)
		cs.shape = box
		add_child(cs)
	elif cs.shape is BoxShape3D:
		var bs := cs.shape as BoxShape3D
		if npc_type in [NPCType.CITY_BUS, NPCType.DUMP_TRUCK, NPCType.FUEL_TANKER_SEMI]:
			bs.size = Vector3(1.8, 1.3, 4.4)
		else:
			bs.size = Vector3(1.5, 0.85, 2.7)
	
	# Create CarPivot if not already present
	car_pivot = get_node_or_null("CarPivot") as Node3D
	if car_pivot == null:
		car_pivot = Node3D.new()
		car_pivot.name = "CarPivot"
		add_child(car_pivot)
	
	# Forward RayCast for braking (length 6.5m)
	forward_ray = get_node_or_null("ForwardRay") as RayCast3D
	if forward_ray == null:
		forward_ray = RayCast3D.new()
		forward_ray.name = "ForwardRay"
		forward_ray.target_position = Vector3(0.0, 0.2, -6.5)
		forward_ray.collision_mask = 2 | 4 | 8 | 16 # Detect Player, Police, Buildings, other NPCs
		forward_ray.enabled = true
		car_pivot.add_child(forward_ray)
	
	if not car_id.is_empty():
		_apply_car_id_profile()
	else:
		_build_visuals()
	_align_with_direction(0.0, true)
	
	# Connect body collisions
	contact_monitor = true
	max_contacts_reported = 4
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _apply_car_id_profile() -> void:
	if car_id.is_empty():
		return
	
	var vdb = null
	if is_inside_tree():
		vdb = get_node_or_null("/root/VehicleDatabase")
	elif Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st and st.root:
			vdb = st.root.get_node_or_null("VehicleDatabase")
	
	if vdb and vdb.has_car(car_id):
		var cinfo: Dictionary = vdb.get_car(car_id)
		var stats = vdb.get_car_stats(car_id)
		if stats:
			mass = stats.mass_weight
			cruise_speed = clampf(stats.max_speed * 0.52, 9.5, 14.5)
		
		var cat: String = String(cinfo.get("category", "")).to_lower()
		var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
		if cs and cs.shape is BoxShape3D:
			var bs := cs.shape as BoxShape3D
			if cat in ["truck", "heavy", "bus", "tank", "drill"]:
				bs.size = Vector3(1.8, 1.3, 4.4)
			elif cat in ["kart", "compact", "micro", "trike"]:
				bs.size = Vector3(1.2, 0.8, 2.0)
			else:
				bs.size = Vector3(1.5, 0.85, 2.7)
	
	_build_visuals()

func _build_visuals() -> void:
	if visual_model and is_instance_valid(visual_model):
		visual_model.queue_free()
		visual_model = null
	if npc_trail and is_instance_valid(npc_trail):
		npc_trail.queue_free()
		npc_trail = null
	
	if not car_pivot:
		return
	
	for child in car_pivot.get_children():
		if child != forward_ray:
			child.queue_free()
	
	var vab = null
	if is_inside_tree():
		vab = get_node_or_null("/root/VoxelAssetBuilder")
	elif Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st and st.root:
			vab = st.root.get_node_or_null("VoxelAssetBuilder")
	
	if not car_id.is_empty() and vab and vab.has_method("build_player_car_visuals"):
		visual_model = vab.build_player_car_visuals(car_id)
		visual_model.name = "VoxelCarVisual"
		visual_model.position = Vector3(0.0, 0.35, 0.0)
		car_pivot.add_child(visual_model)
		_setup_npc_trail(car_id)
	elif vab and vab.has_method("build_npc_traffic_visuals"):
		visual_model = vab.build_npc_traffic_visuals(npc_type)
		car_pivot.add_child(visual_model)
	
	# Collect hazard lights for flashing
	_hazard_lights.clear()
	if visual_model:
		for node in visual_model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi and mi.material_override and mi.material_override is StandardMaterial3D:
				var sm := mi.material_override as StandardMaterial3D
				if sm.emission_enabled and (sm.emission.r > 0.8 and sm.emission.g > 0.4 and sm.emission.b < 0.2):
					_hazard_lights.append(mi)

func _setup_npc_trail(cid: String) -> void:
	if not (cid in ["fire_dragon", "dark_matter_phantom", "ufo_flying_saucer", "cosmic_hyper_star"]):
		return
	
	npc_trail = GPUParticles3D.new()
	npc_trail.name = "NPCTrail"
	npc_trail.amount = 24
	npc_trail.lifetime = 0.5
	
	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p_mat.emission_box_extents = Vector3(0.35, 0.08, 0.2)
	p_mat.spread = 20.0
	p_mat.direction = Vector3(0.0, 0.2, 1.0)
	p_mat.initial_velocity_min = 2.5
	p_mat.initial_velocity_max = 5.0
	
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	match cid:
		"fire_dragon":
			p_mat.color = Color("ff793f")
			draw_mat.albedo_color = Color("ff793f")
			draw_mat.emission_enabled = true
			draw_mat.emission = Color("ff793f")
		"dark_matter_phantom":
			p_mat.color = Color("9b59b6")
			draw_mat.albedo_color = Color("9b59b6")
			draw_mat.emission_enabled = true
			draw_mat.emission = Color("9b59b6")
		"ufo_flying_saucer":
			p_mat.color = Color("00b894")
			draw_mat.albedo_color = Color("00b894")
			draw_mat.emission_enabled = true
			draw_mat.emission = Color("00b894")
		"cosmic_hyper_star":
			p_mat.color = Color("fd79a8")
			draw_mat.albedo_color = Color("fd79a8")
			draw_mat.emission_enabled = true
			draw_mat.emission = Color("fd79a8")
	
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 0.14, 0.14)
	box.material = draw_mat
	npc_trail.process_material = p_mat
	npc_trail.draw_pass_1 = box
	npc_trail.position = Vector3(0.0, 0.25, 1.2)
	car_pivot.add_child(npc_trail)

var was_crashed: bool = false
var despawn_timer: float = 10.0

## Triggered when police sirens or high-speed chases pass nearby (Escape Road 3 emergent pileups)
func trigger_siren_panic(threat: Node3D = null) -> void:
	if is_panicking or was_crashed:
		return
	is_panicking = true
	panic_timer = randf_range(2.2, 4.0)
	
	# 50% chance: emergency hard braking with hazards
	# 50% chance: swerve toward road shoulder (clean steering, no torque spinning)
	if randf() < 0.5:
		is_braking = true
		linear_velocity *= 0.35
	else:
		is_braking = false
		var swerve_axis: float = 1.0 if randf() < 0.5 else -1.0
		if threat and is_instance_valid(threat):
			var to_threat: Vector3 = threat.global_position - global_position
			var perp := Vector3(-to_threat.z, 0.0, to_threat.x).normalized()
			lane_direction = (lane_direction * 0.7 + perp * 0.7).normalized()
		else:
			lane_direction = (lane_direction + Vector3(swerve_axis * 0.7, 0.0, 0.0)).normalized()

func _physics_process(delta: float) -> void:
	# Enforce zero physics angular spin
	angular_velocity = Vector3.ZERO
	
	if was_crashed:
		despawn_timer -= delta
		if despawn_timer <= 0.0:
			queue_free()
			return
	
	if is_panicking:
		panic_timer -= delta
		_flash_hazard_lights(delta, 0.12)
		_align_with_direction(delta, false)
		
		if is_braking:
			# Emergency brake to a halt
			linear_velocity = linear_velocity.move_toward(Vector3(0.0, linear_velocity.y, 0.0), delta * 16.0)
		else:
			# Erratic swerving drive
			var target_vel := lane_direction.normalized() * (cruise_speed * 0.7)
			linear_velocity.x = move_toward(linear_velocity.x, target_vel.x, delta * 12.0)
			linear_velocity.z = move_toward(linear_velocity.z, target_vel.z, delta * 12.0)
		
		if panic_timer <= 0.0:
			is_panicking = false
			is_braking = false
			_snap_to_nearest_road_direction()
		return
	
	# Align vehicle body smoothly with movement direction
	_align_with_direction(delta, false)
	
	# Raycast obstacle avoidance
	is_braking = false
	if forward_ray and forward_ray.is_colliding():
		is_braking = true
		_flash_hazard_lights(delta, 0.25)
	
	# Drive along lane
	var target_vel: Vector3
	if is_braking:
		target_vel = Vector3(0.0, linear_velocity.y, 0.0)
		linear_velocity = linear_velocity.move_toward(target_vel, delta * 24.0)
	else:
		target_vel = lane_direction.normalized() * cruise_speed
		linear_velocity.x = move_toward(linear_velocity.x, target_vel.x, delta * 18.0)
		linear_velocity.z = move_toward(linear_velocity.z, target_vel.z, delta * 18.0)
	
	# Check for chunk intersection decisions (every 48 meters)
	_check_intersection()

func _align_with_direction(delta: float = 0.0, immediate: bool = false) -> void:
	if lane_direction.is_zero_approx():
		return
	var target_rot_y := atan2(lane_direction.x, lane_direction.z) + PI
	if immediate or delta <= 0.0:
		rotation.y = target_rot_y
	else:
		rotation.y = lerp_angle(rotation.y, target_rot_y, clampf(12.0 * delta, 0.05, 0.8))
	if car_pivot:
		car_pivot.rotation = Vector3.ZERO

func _check_intersection() -> void:
	# Intersection is at (chunk_x * 48 + 24, chunk_z * 48 + 24)
	var chunk_coord := Vector2i(
		int(floor(global_position.x / 48.0)),
		int(floor(global_position.z / 48.0))
	)
	var center_x := chunk_coord.x * 48.0 + 24.0
	var center_z := chunk_coord.y * 48.0 + 24.0
	var dist_to_center := Vector2(global_position.x - center_x, global_position.z - center_z).length()
	
	if dist_to_center < 3.2 and chunk_coord != _last_intersection_chunk:
		_last_intersection_chunk = chunk_coord
		_make_intersection_turn()

func _make_intersection_turn() -> void:
	var roll := randf()
	if roll < 0.65:
		# Continue straight
		pass
	elif roll < 0.85:
		# Turn right (90 deg clockwise)
		lane_direction = Vector3(-lane_direction.z, 0.0, lane_direction.x)
	else:
		# Turn left (90 deg counter-clockwise)
		lane_direction = Vector3(lane_direction.z, 0.0, -lane_direction.x)

func _snap_to_nearest_road_direction() -> void:
	if absf(lane_direction.x) > absf(lane_direction.z):
		lane_direction = Vector3(signf(lane_direction.x), 0.0, 0.0)
	else:
		lane_direction = Vector3(0.0, 0.0, signf(lane_direction.z if lane_direction.z != 0 else 1.0))

func _flash_hazard_lights(delta: float, rate: float) -> void:
	_hazard_flash_timer += delta
	if _hazard_flash_timer >= rate:
		_hazard_flash_timer = 0.0
		_hazard_state = not _hazard_state
		for mi in _hazard_lights:
			if is_instance_valid(mi) and mi.material_override:
				(mi.material_override as StandardMaterial3D).emission_energy_multiplier = 3.5 if _hazard_state else 0.2

func _on_body_entered(body: Node) -> void:
	# Ignore ground
	if body is StaticBody3D and body.collision_layer == 1:
		return
	
	# If rammed hard by player car or police car, take hit
	var rel_vel: Vector3 = linear_velocity
	if body is RigidBody3D:
		rel_vel -= (body as RigidBody3D).linear_velocity
	
	if rel_vel.length() > 4.0:
		take_traffic_hit(body, rel_vel)

## External method called when rammed or smashed
func take_traffic_hit(rammer: Node3D, impact_velocity: Vector3 = Vector3.ZERO) -> void:
	if was_crashed and not (npc_type == NPCType.FUEL_TANKER_SEMI and not has_exploded):
		return
	
	was_crashed = true
	despawn_timer = 10.0
	is_panicking = true
	panic_timer = 3.0
	if has_node("/root/BrawlUITheme"):
		get_node("/root/BrawlUITheme").flash_white(self, 0.09)
	
	# Apply launch impulse away from impact without spinning like a top
	var launch_dir := impact_velocity.normalized() if not impact_velocity.is_zero_approx() else Vector3(randf_range(-1, 1), 0.3, randf_range(-1, 1)).normalized()
	apply_central_impulse(launch_dir * 12.0 + Vector3.UP * 3.0)
	angular_velocity = Vector3.ZERO

## Applies radial physical explosion knockback to the traffic car
func apply_knockback(dir: Vector3, force: float = 24.0) -> void:
	var launch_dir := dir.normalized()
	launch_dir.y = maxf(launch_dir.y, 0.45)
	launch_dir = launch_dir.normalized()
	apply_central_impulse(launch_dir * (force * mass))
	was_crashed = true
	despawn_timer = 10.0
	is_panicking = true
	panic_timer = 3.0

func take_damage(_amount: float) -> void:
	if has_node("/root/BrawlUITheme"):
		get_node("/root/BrawlUITheme").flash_white(self, 0.09)
	take_traffic_hit(self, Vector3(randf_range(-1, 1), 0.2, randf_range(-1, 1)).normalized() * 8.0)
	
	# Award +100 Traffic Smash Points
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		if wm and wm.has_method("add_score"):
			wm.add_score(100)
	
	# 1. AMBULANCE_VAN / PARAMEDIC RAPID: drops glowing green +30 HP Medkit
	if (npc_type == NPCType.AMBULANCE_VAN or car_id == "paramedic_rapid") and not has_dropped_medkit:
		has_dropped_medkit = true
		_spawn_medkit()
	
	# 2. FUEL_TANKER_SEMI / TANKER: triggers 12m mega-explosion
	if (npc_type == NPCType.FUEL_TANKER_SEMI or car_id in ["tanker", "fuel_tanker", "fuel_tanker_semi"]) and not has_exploded:
		has_exploded = true
		_trigger_mega_explosion()

## Escape Road 3 Mechanic: Hijacked by on-foot player
func get_hijacked() -> void:
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_ui_click"):
			sfx.play_ui_click()
	queue_free()

func _spawn_medkit() -> void:
	var medkit := Area3D.new()
	medkit.name = "MedkitPickup"
	medkit.collision_layer = 0
	medkit.collision_mask = 2 # PlayerCar
	medkit.position = global_position + Vector3(0.0, 0.8, 0.0)
	
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 1.8, 1.8)
	cs.shape = box
	medkit.add_child(cs)
	
	# Green cross voxel visuals
	var v_node := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2ecc71")
	mat.emission_enabled = true
	mat.emission = Color("2ecc71")
	mat.emission_energy_multiplier = 2.4
	
	var m1 := MeshInstance3D.new()
	var b1 := BoxMesh.new()
	b1.size = Vector3(0.8, 0.28, 0.28)
	m1.mesh = b1
	m1.material_override = mat
	v_node.add_child(m1)
	
	var m2 := MeshInstance3D.new()
	var b2 := BoxMesh.new()
	b2.size = Vector3(0.28, 0.8, 0.28)
	m2.mesh = b2
	m2.material_override = mat
	v_node.add_child(m2)
	
	medkit.add_child(v_node)
	
	medkit.body_entered.connect(func(body: Node3D):
		if body.has_method("heal") or "health" in body or body.get_parent().has_method("heal"):
			var target = body if body.has_method("heal") else body.get_parent()
			if target and target.has_method("heal"):
				target.heal(30.0)
			elif "health" in target:
				target.health = minf(float(target.max_health if "max_health" in target else 100.0), float(target.health) + 30.0)
			medkit.queue_free()
	)
	
	get_parent().add_child(medkit)

func _trigger_mega_explosion() -> void:
	fuel_tanker_exploded.emit(global_position, 12.0)
	
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		wm.hit_stop(0.065)
	
	# Blast visuals: Expanding orange/yellow fireball
	var blast_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.2
	sphere.height = 2.4
	blast_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("e67e22")
	mat.emission_enabled = true
	mat.emission = Color("f39c12")
	mat.emission_energy_multiplier = 4.0
	blast_mesh.material_override = mat
	blast_mesh.position = global_position + Vector3.UP * 0.8
	get_parent().add_child(blast_mesh)
	
	# Tween expand and fade
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(blast_mesh, "scale", Vector3(10.0, 10.0, 10.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(blast_mesh, "transparency", 1.0, 0.45)
	tween.chain().tween_callback(blast_mesh.queue_free)
	
	# Blast Physics: 12-meter query
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var blast_sphere := SphereShape3D.new()
	blast_sphere.radius = 12.0
	query.shape = blast_sphere
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 2 | 4 | 8 | 16 # Player, Police, Buildings, NPCs
	
	var results := space.intersect_shape(query, 32)
	for hit in results:
		var collider: Object = hit.get("collider")
		if collider is RigidBody3D and collider != self:
			var rb := collider as RigidBody3D
			var dir := (rb.global_position - global_position).normalized() + Vector3.UP * 0.5
			var dist := (rb.global_position - global_position).length()
			var force := clampf(1.0 - (dist / 12.0), 0.2, 1.0) * 32.0
			rb.apply_central_impulse(dir * force)
			if rb.has_method("take_damage"):
				rb.take_damage(60.0)
		elif collider is StaticBody3D and collider.has_method("damage_building"):
			collider.damage_building(50.0)
