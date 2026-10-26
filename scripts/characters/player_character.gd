class_name PlayerCharacter
extends CharacterBody3D

## On-Foot Getaway Robber Character for Smashy Heist / Escape Road 3.
## Controls like a getaway car with A and D steering and automatic forward run.
## Smoothly glides over curbs and small obstacles without needing to jump,
## swims across water canals, and hijacks any nearby NPC or police vehicle.
## Features a 3D guide arrow pointing to the nearest vehicle to hijack.
## Note: On foot, the player is immune to "surrounded" busts; only vehicle drivers can be boxed in!

signal character_busted(reason: String)
signal vehicle_entered(vehicle: Node3D)

@export var run_speed: float = 10.5
@export var swim_speed: float = 5.5
@export var turn_speed: float = 5.2 # rad/sec
@export var max_hp: float = 100.0

var current_hp: float = 100.0
var is_swimming: bool = false
var steer_input: float = 0.0
var is_reversing: bool = false

var visual_model: Node3D = null
var leg_l: Node3D = null
var leg_r: Node3D = null
var arm_l: Node3D = null
var arm_r: Node3D = null

var _anim_time: float = 0.0
var _nearby_vehicle: Node3D = null
var _interaction_label: Label3D = null
var _guide_arrow: Node3D = null
var _pathway_container: Node3D = null
var _pathway_arrows: Array[MeshInstance3D] = []
var _target_car_beacon: Node3D = null
var _eject_grace_timer: float = 0.55

const GRAVITY: float = 22.0

func _ready() -> void:
	add_to_group("player")
	add_to_group("player_character")
	
	# Load persistent health if available (player cannot restore health across vehicles)
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		if wm and "player_persistent_hp" in wm:
			current_hp = clampf(wm.player_persistent_hp, 10.0, max_hp)
		else:
			current_hp = max_hp
	else:
		current_hp = max_hp
	
	# Add Capsule Collision
	if get_node_or_null("CollisionShape3D") == null:
		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		var cap := CapsuleShape3D.new()
		cap.radius = 0.28
		cap.height = 0.88
		cs.shape = cap
		cs.position = Vector3(0.0, 0.44, 0.0)
		add_child(cs)
	
	# Collision layers: Layer 2 (Player)
	collision_layer = 2
	# Collides with Ground (1) and Buildings (8). Small props (16) are bypassed so player runs smoothly through small obstacles!
	collision_mask = 1 | 8
	
	floor_snap_length = 0.45
	floor_constant_speed = true
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(60.0)
	
	# Build 3D Voxel Visuals
	var vab = get_node_or_null("/root/VoxelAssetBuilder")
	if vab and vab.has_method("build_player_character_visuals"):
		visual_model = vab.build_player_character_visuals()
		add_child(visual_model)
		leg_l = visual_model.find_child("Leg_L", true, false)
		leg_r = visual_model.find_child("Leg_R", true, false)
		arm_l = visual_model.find_child("Arm_L", true, false)
		arm_r = visual_model.find_child("Arm_R", true, false)
	
	# Hijack 3D Prompt Label
	_interaction_label = Label3D.new()
	_interaction_label.name = "HijackPrompt"
	_interaction_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_interaction_label.position = Vector3(0.0, 1.45, 0.0)
	_interaction_label.font_size = 28
	_interaction_label.outline_size = 8
	_interaction_label.modulate = Color("f1c40f") # Bright Golden Yellow
	_interaction_label.outline_modulate = Color("1e272e")
	_interaction_label.visible = false
	add_child(_interaction_label)
	
	# 3D Guide Arrow pointing to the nearest drivable vehicle
	_guide_arrow = Node3D.new()
	_guide_arrow.name = "GuideArrow"
	_guide_arrow.position = Vector3(0.0, 1.25, 0.0)
	var arrow_mesh := PrismMesh.new()
	arrow_mesh.size = Vector3(0.28, 0.38, 0.14)
	var arrow_inst := MeshInstance3D.new()
	arrow_inst.mesh = arrow_mesh
	arrow_inst.rotation.x = deg_to_rad(-90.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("f1c40f")
	mat.emission_enabled = true
	mat.emission = Color("f39c12")
	mat.emission_energy_multiplier = 2.0
	arrow_inst.material_override = mat
	_guide_arrow.add_child(arrow_inst)
	add_child(_guide_arrow)

func _physics_process(delta: float) -> void:
	# 1. Canal Water Check
	if global_position.y < -0.35:
		is_swimming = true
	else:
		is_swimming = false
	
	# 2. Car-like Steering with A & D (or TouchHUD steer zones)
	var cur_steer: float = steer_input
	var kb_steer: float = Input.get_axis("steer_left", "steer_right")
	if absf(kb_steer) > 0.01:
		cur_steer = kb_steer
	
	if absf(cur_steer) > 0.01:
		rotation.y += -cur_steer * turn_speed * delta
	
	# 3. Throttle / Speed (Auto-run forward like a getaway car)
	var forward_dir := -global_transform.basis.z.normalized()
	var speed: float = run_speed
	if is_swimming:
		speed = swim_speed
	elif is_reversing or Input.is_action_pressed("reverse_brake") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		speed = -3.8
	elif Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		speed = 13.5
	
	if is_swimming:
		# Floating on water surface
		velocity.y = move_toward(velocity.y, 0.0, delta * 12.0)
		global_position.y = lerpf(global_position.y, -0.28, delta * 6.0)
		var target_vel := forward_dir * speed
		velocity.x = move_toward(velocity.x, target_vel.x, delta * 14.0)
		velocity.z = move_toward(velocity.z, target_vel.z, delta * 14.0)
		# Vault/climb out of canal when swimming against river bank
		if is_on_wall():
			velocity.y = 5.0
	else:
		# Gravity
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity.y = 0.0
		
		var target_vel := forward_dir * speed
		velocity.x = move_toward(velocity.x, target_vel.x, delta * 32.0)
		velocity.z = move_toward(velocity.z, target_vel.z, delta * 32.0)
		
		# Smooth Auto Step-Up over curbs and low obstacles (no jump needed!)
		if is_on_wall() and is_on_floor() and speed > 0.0 and is_inside_tree() and get_world_3d():
			var space := get_world_3d().direct_space_state
			if space:
				var step_origin := global_position + Vector3(0.0, 0.45, 0.0)
				var step_target := step_origin + forward_dir * 0.45
				var query := PhysicsRayQueryParameters3D.create(step_origin, step_target, 1 | 8)
				var res := space.intersect_ray(query)
				if res.is_empty():
					global_position.y += 0.22
	
	move_and_slide()
	
	# 4. Smash nearby small props on contact
	_smash_nearby_props()
	
	# 5. Visual Model Orientation & Animation
	# Model faces -Z locally (face/mask at -Z, duffel bag at +Z).
	if visual_model:
		visual_model.rotation.y = 0.0
		visual_model.rotation.z = lerpf(visual_model.rotation.z, -cur_steer * 0.16, 12.0 * delta)
	
	var horiz_vel := Vector2(velocity.x, velocity.z)
	var horiz_speed := horiz_vel.length()
	if horiz_speed > 0.4:
		_anim_time += delta * (15.0 if not is_swimming else 7.5)
		var swing := sin(_anim_time) * 0.65
		if leg_l: leg_l.rotation.x = swing
		if leg_r: leg_r.rotation.x = -swing
		if arm_l: arm_l.rotation.x = -swing
		if arm_r: arm_r.rotation.x = swing
		if visual_model:
			visual_model.position.y = absf(sin(_anim_time * 2.0)) * 0.06
	else:
		# Idle pose
		if leg_l: leg_l.rotation.x = lerpf(leg_l.rotation.x, 0.0, 10.0 * delta)
		if leg_r: leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.0, 10.0 * delta)
		if arm_l: arm_l.rotation.x = lerpf(arm_l.rotation.x, 0.0, 10.0 * delta)
		if arm_r: arm_r.rotation.x = lerpf(arm_r.rotation.x, 0.0, 10.0 * delta)
		if visual_model:
			visual_model.position.y = lerpf(visual_model.position.y, 0.0, 10.0 * delta)
	
	# 6. Orient 3D Guide Arrow towards the nearest car
	_update_guide_arrow(delta)
	
	if _eject_grace_timer > 0.0:
		_eject_grace_timer -= delta
		_nearby_vehicle = null
		if _interaction_label:
			_interaction_label.visible = false
	else:
		# 7. Proximity Check for Hijacking Nearby Vehicles
		_scan_for_hijack_targets()
		
		# 8. Handle Hijack Action (SPACE or E or contact proximity)
		if _nearby_vehicle and is_instance_valid(_nearby_vehicle):
			var v_pos: Vector3 = (_nearby_vehicle as Node3D).global_position
			if _nearby_vehicle is PoliceCar and (_nearby_vehicle as PoliceCar).physics_sphere:
				v_pos = (_nearby_vehicle as PoliceCar).physics_sphere.global_position
			var wants_hijack: bool = Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_F) or global_position.distance_to(v_pos) < 1.45
			if wants_hijack:
				hijack_vehicle(_nearby_vehicle)

func _update_guide_arrow(delta: float) -> void:
	if not _guide_arrow:
		return
	
	var nearest_veh = get_nearest_vehicle()
	if nearest_veh and is_instance_valid(nearest_veh):
		var tpos: Vector3 = (nearest_veh as Node3D).global_position
		if nearest_veh is PoliceCar and (nearest_veh as PoliceCar).physics_sphere:
			tpos = (nearest_veh as PoliceCar).physics_sphere.global_position
		elif nearest_veh is ArcadeCar and (nearest_veh as ArcadeCar).car_pivot:
			tpos = (nearest_veh as ArcadeCar).car_pivot.global_position
		
		var target_flat := Vector3(tpos.x, _guide_arrow.global_position.y, tpos.z)
		if _guide_arrow.global_position.distance_squared_to(target_flat) > 0.05:
			_guide_arrow.look_at(target_flat, Vector3.UP)
		
		_guide_arrow.position.y = 1.25 + absf(sin(_anim_time * 2.5)) * 0.08
		_guide_arrow.visible = true
		
		# Ground pathway of arrows leading from player all the way to target car
		_update_pathway_arrows(tpos, delta)
	else:
		_guide_arrow.visible = false
		_clear_pathway_arrows()

func _update_pathway_arrows(target_pos: Vector3, delta: float) -> void:
	if not is_inside_tree() or is_dead:
		_clear_pathway_arrows()
		return
	
	if not _pathway_container or not is_instance_valid(_pathway_container):
		_pathway_container = Node3D.new()
		_pathway_container.name = "DrivableCarPathwayContainer"
		var p_parent: Node = get_parent() if get_parent() else get_tree().root
		p_parent.add_child(_pathway_container)
	
	var from_pos := global_position
	var to_pos := target_pos
	var flat_vec := Vector3(to_pos.x - from_pos.x, 0.0, to_pos.z - from_pos.z)
	var dist := flat_vec.length()
	
	# If very close, don't clutter ground
	if dist < 1.8:
		for a in _pathway_arrows:
			if is_instance_valid(a):
				a.visible = false
		if _target_car_beacon and is_instance_valid(_target_car_beacon):
			_target_car_beacon.visible = false
		return
	
	# Spacing between ground arrows: ~2.2 meters
	var spacing: float = 2.2
	var needed_count: int = clampi(int(dist / spacing), 1, 28)
	
	# Ensure arrow mesh pool
	while _pathway_arrows.size() < needed_count:
		var arr := MeshInstance3D.new()
		var p_mesh := PrismMesh.new()
		p_mesh.size = Vector3(0.5, 0.75, 0.06)
		arr.mesh = p_mesh
		arr.rotation_degrees.x = -90.0 # Lay flat on ground pointing forward
		
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("f1c40f")
		mat.emission_enabled = true
		mat.emission = Color("f39c12")
		mat.emission_energy_multiplier = 3.0
		arr.material_override = mat
		
		_pathway_container.add_child(arr)
		_pathway_arrows.append(arr)
	
	var dir_norm := flat_vec.normalized()
	
	for i in range(_pathway_arrows.size()):
		var arr := _pathway_arrows[i]
		if not is_instance_valid(arr):
			continue
		if i >= needed_count:
			arr.visible = false
			continue
		
		arr.visible = true
		var t_ratio: float = float(i + 1) / float(needed_count + 1)
		var arrow_pos: Vector3 = from_pos.lerp(to_pos, t_ratio)
		arrow_pos.y = maxf(arrow_pos.y, 0.12)
		arr.global_position = arrow_pos
		
		# Orient pointing towards destination car
		var look_target := arrow_pos + dir_norm * 2.0
		look_target.y = arrow_pos.y
		arr.look_at(look_target, Vector3.UP)
		arr.rotate_object_local(Vector3.RIGHT, deg_to_rad(-90.0))
		
		# Animated forward flowing pulse wave
		var wave: float = sin(_anim_time * 7.0 - float(i) * 0.75)
		var scale_factor: float = 1.0 + 0.35 * maxf(0.0, wave)
		arr.scale = Vector3(scale_factor, scale_factor, scale_factor)
	
	# Destination Car Beacon
	if not _target_car_beacon or not is_instance_valid(_target_car_beacon):
		_target_car_beacon = Node3D.new()
		_target_car_beacon.name = "TargetCarBeacon"
		
		var diamond := MeshInstance3D.new()
		var d_mesh := PrismMesh.new()
		d_mesh.size = Vector3(0.7, 0.9, 0.7)
		diamond.mesh = d_mesh
		diamond.rotation_degrees.x = 180.0 # inverted diamond pointing down at roof
		
		var b_mat := StandardMaterial3D.new()
		b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		b_mat.albedo_color = Color("2ecc71")
		b_mat.emission_enabled = true
		b_mat.emission = Color("2ecc71")
		b_mat.emission_energy_multiplier = 3.5
		diamond.material_override = b_mat
		_target_car_beacon.add_child(diamond)
		
		var lbl := Label3D.new()
		lbl.text = "⚡ GETAWAY CAR"
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3(0, 0.85, 0)
		lbl.font_size = 24
		lbl.outline_size = 8
		lbl.modulate = Color("2ecc71")
		lbl.outline_modulate = Color("1e272e")
		_target_car_beacon.add_child(lbl)
		
		_pathway_container.add_child(_target_car_beacon)
	
	_target_car_beacon.visible = true
	var beacon_y: float = to_pos.y + 2.0 + sin(_anim_time * 3.5) * 0.2
	_target_car_beacon.global_position = Vector3(to_pos.x, beacon_y, to_pos.z)
	_target_car_beacon.rotate_y(delta * 2.5)

func _clear_pathway_arrows() -> void:
	for arr in _pathway_arrows:
		if is_instance_valid(arr):
			arr.queue_free()
	_pathway_arrows.clear()
	
	if _target_car_beacon and is_instance_valid(_target_car_beacon):
		if _target_car_beacon.get_parent():
			_target_car_beacon.get_parent().remove_child(_target_car_beacon)
		_target_car_beacon.queue_free()
		_target_car_beacon = null
	
	if _pathway_container and is_instance_valid(_pathway_container):
		if _pathway_container.get_parent():
			_pathway_container.get_parent().remove_child(_pathway_container)
		_pathway_container.queue_free()
		_pathway_container = null

## Finds the closest drivable vehicle (Civilian NPC, Police Car with 0 officers, or Abandoned Getaway Car)
func get_nearest_vehicle() -> Node3D:
	var closest_node: Node3D = null
	var min_dist: float = 999999.0
	
	# Check NPC Traffic (Civilian cars are always drivable)
	for npc in get_tree().get_nodes_in_group("npc_traffic"):
		if is_instance_valid(npc) and npc is Node3D and not (npc as Node3D).is_queued_for_deletion():
			var d := global_position.distance_to((npc as Node3D).global_position)
			if d < min_dist:
				min_dist = d
				closest_node = npc as Node3D
	
	# Check Police Cars - ONLY IF 0 officers inside!
	for cop in get_tree().get_nodes_in_group("police_units"):
		if is_instance_valid(cop) and cop is PoliceCar and not (cop as PoliceCar).is_wrecked:
			var pc := cop as PoliceCar
			if pc.officers_inside == 0:
				var pos := pc.physics_sphere.global_position if pc.physics_sphere else pc.global_position
				var d := global_position.distance_to(pos)
				if d < min_dist:
					min_dist = d
					closest_node = pc
	
	# Check Player Vehicles (e.g. abandoned car)
	for car in get_tree().get_nodes_in_group("player_vehicles"):
		if is_instance_valid(car) and car is ArcadeCar and not (car as ArcadeCar).is_queued_for_deletion():
			var ac := car as ArcadeCar
			if ac.current_hp > 0.0:
				var pos := ac.car_pivot.global_position if ac.car_pivot else ac.global_position
				var d := global_position.distance_to(pos)
				if d < min_dist:
					min_dist = d
					closest_node = ac
	
	return closest_node

func get_nearby_vehicle() -> Node3D:
	return _nearby_vehicle

func hijack_nearby() -> void:
	if _nearby_vehicle and is_instance_valid(_nearby_vehicle):
		hijack_vehicle(_nearby_vehicle)
	else:
		var nearest = get_nearest_vehicle()
		if nearest and is_instance_valid(nearest):
			var pos: Vector3 = nearest.global_position
			if nearest is PoliceCar and (nearest as PoliceCar).physics_sphere:
				pos = (nearest as PoliceCar).physics_sphere.global_position
			if global_position.distance_to(pos) <= 4.5:
				hijack_vehicle(nearest)

func _smash_nearby_props() -> void:
	if not is_inside_tree() or not get_world_3d():
		return
	var space := get_world_3d().direct_space_state
	if not space:
		return
	
	var shape := SphereShape3D.new()
	shape.radius = 0.75
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = global_transform
	params.collision_mask = 16
	var results := space.intersect_shape(params, 8)
	for hit in results:
		var col = hit.get("collider")
		if col and is_instance_valid(col) and col is SmashProp:
			var sp := col as SmashProp
			if not sp._is_smashed:
				sp._smash(self)

func _scan_for_hijack_targets() -> void:
	_nearby_vehicle = null
	if not is_inside_tree() or not get_tree():
		return
	var candidate_dist: float = 3.6
	
	# 1. Query NPC Traffic Cars
	var npcs := get_tree().get_nodes_in_group("npc_traffic")
	for npc in npcs:
		if is_instance_valid(npc) and npc is Node3D and not (npc as Node3D).is_queued_for_deletion():
			var d := global_position.distance_to((npc as Node3D).global_position)
			if d < candidate_dist:
				candidate_dist = d
				_nearby_vehicle = npc as Node3D
	
	# 2. Query Police Cars (players can drive police cruisers too!)
	var cops := get_tree().get_nodes_in_group("police_units")
	for cop in cops:
		if is_instance_valid(cop) and cop is PoliceCar and not (cop as PoliceCar).is_wrecked:
			var pc := cop as PoliceCar
			var pos := pc.physics_sphere.global_position if pc.physics_sphere else pc.global_position
			var d := global_position.distance_to(pos)
			if d < candidate_dist:
				candidate_dist = d
				_nearby_vehicle = pc
	
	# 3. Query Player ArcadeCars (e.g. abandoned car)
	var cars := get_tree().get_nodes_in_group("player_vehicles")
	for car in cars:
		if is_instance_valid(car) and car is ArcadeCar and not (car as ArcadeCar).is_queued_for_deletion():
			var ac := car as ArcadeCar
			if ac.current_hp > 0.0:
				var pos := ac.car_pivot.global_position if ac.car_pivot else ac.global_position
				var d := global_position.distance_to(pos)
				if d < candidate_dist:
					candidate_dist = d
					_nearby_vehicle = ac
	
	# Update 3D Prompt Billboard
	if _nearby_vehicle and is_instance_valid(_nearby_vehicle):
		var v_name := "CAR"
		if _nearby_vehicle is NPCTrafficCar:
			var npc := _nearby_vehicle as NPCTrafficCar
			if not npc.car_id.is_empty():
				var vdb = get_node_or_null("/root/VehicleDatabase")
				if vdb and vdb.has_car(npc.car_id):
					v_name = String(vdb.get_car(npc.car_id).get("name", "VEHICLE"))
				else:
					v_name = npc.car_id.replace("_", " ").to_upper()
			else:
				var npc_type = npc.npc_type
				match npc_type:
					0: v_name = "TAXI"
					1: v_name = "CITY BUS"
					2: v_name = "PIZZA VAN"
					3: v_name = "DUMP TRUCK"
					4: v_name = "AMBULANCE"
					5: v_name = "FUEL TANKER"
			_interaction_label.text = "⚡ PRESS [SPACE] TO HIJACK %s" % v_name
			_interaction_label.modulate = Color("f1c40f")
			_interaction_label.visible = true
		elif _nearby_vehicle is PoliceCar:
			var pc := _nearby_vehicle as PoliceCar
			match pc.police_type:
				1: v_name = "POLICE INTERCEPTOR"
				2: v_name = "SWAT VAN"
				3: v_name = "RHINO TANK"
				_: v_name = "POLICE CRUISER"
			if pc.officers_inside > 0:
				_interaction_label.text = "⛔ %d POLICE INSIDE (CANNOT DRIVE!)" % pc.officers_inside
				_interaction_label.modulate = Color("ff4757")
				_interaction_label.visible = true
			else:
				_interaction_label.text = "⚡ PRESS [SPACE] TO DRIVE EMPTY %s" % v_name
				_interaction_label.modulate = Color("2ecc71")
				_interaction_label.visible = true
		elif _nearby_vehicle is ArcadeCar:
			var ac := _nearby_vehicle as ArcadeCar
			v_name = "GETAWAY CAR"
			var vdb = get_node_or_null("/root/VehicleDatabase")
			if vdb and vdb.has_car(ac.car_id):
				v_name = String(vdb.get_car(ac.car_id).get("name", "GETAWAY CAR"))
			elif ac.stats and not ac.stats.car_id.is_empty() and vdb and vdb.has_car(ac.stats.car_id):
				v_name = String(vdb.get_car(ac.stats.car_id).get("name", "GETAWAY CAR"))
			_interaction_label.text = "⚡ PRESS [SPACE] TO ENTER %s" % v_name
			_interaction_label.modulate = Color("f1c40f")
			_interaction_label.visible = true
	else:
		_interaction_label.visible = false

## Hijacks or enters the target vehicle and transitions player driving control
func enter_vehicle(veh: Node3D) -> void:
	hijack_vehicle(veh)

func hijack_vehicle(veh: Node3D) -> void:
	if not is_instance_valid(veh):
		return
	
	# Police vehicles can ONLY be entered when there are NO officers inside!
	if veh is PoliceCar:
		var pc := veh as PoliceCar
		if pc.officers_inside > 0:
			var hud = get_tree().root.find_child("TouchHUD", true, false)
			if hud and hud.has_method("spawn_floating_text"):
				hud.spawn_floating_text(pc.car_pivot.global_position + Vector3.UP * 1.5, "⛔ %d POLICE INSIDE! CANNOT DRIVE" % pc.officers_inside, Color("ff4757"), 1.5)
			if has_node("/root/SoundFX"):
				var sfx = get_node("/root/SoundFX")
				if sfx.has_method("play_ui_click"):
					sfx.play_ui_click()
			return
	
	_clear_pathway_arrows()
	
	# Preserve persistent on-foot health (entering a vehicle does not restore player health!)
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		if wm and "player_persistent_hp" in wm:
			wm.player_persistent_hp = current_hp
	
	vehicle_entered.emit(veh)
	
	# Floating notification
	var hud = get_tree().root.find_child("TouchHUD", true, false)
	if hud and hud.has_method("spawn_floating_text"):
		hud.spawn_floating_text(global_position + Vector3.UP, "🚗 HIJACKED!", Color("fbc531"), 1.3)
	
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_drift_boost"):
			sfx.play_drift_boost()
	
	var cam_rig = get_tree().root.find_child("CameraRig", true, false)
	var hud_node = get_tree().root.find_child("TouchHUD", true, false)
	var city_gen = get_tree().root.find_child("CityGenerator", true, false)
	var traf_mgr = get_tree().root.find_child("TrafficManager", true, false)
	
	if veh is ArcadeCar:
		var ac := veh as ArcadeCar
		ac.is_abandoned = false
		ac.input_enabled = true
		ac.driving_forces_frozen = false
		ac.visible = true
		
		# Make sure car profile is fully active
		if not ac.car_id.is_empty() and ac.has_method("set_car_profile"):
			ac.set_car_profile(ac.car_id)
		
		var car_name: String = "GETAWAY CAR"
		var car_col: Color = Color("fbc531")
		var vdb = get_node_or_null("/root/VehicleDatabase")
		if vdb and vdb.has_car(ac.car_id):
			var c_info: Dictionary = vdb.get_car(ac.car_id)
			car_name = String(c_info.get("name", "GETAWAY CAR"))
			car_col = c_info.get("rarity_color", Color("fbc531"))
		
		if hud_node:
			if "target_car" in hud_node:
				hud_node.target_car = ac
			if hud_node.has_method("_refresh_gadget_info"):
				hud_node._refresh_gadget_info()
			if "_display_hp" in hud_node:
				hud_node._display_hp = ac.current_hp
			if hud_node.has_method("spawn_floating_text"):
				hud_node.spawn_floating_text(ac.global_position + Vector3.UP * 1.5, "🚗 DRIVING %s!" % car_name, car_col, 1.4)
		
		if cam_rig:
			cam_rig.target = ac.car_pivot if ac.car_pivot else ac
			cam_rig.follow_speed = 7.0
		if city_gen:
			city_gen.target_player = ac.car_pivot if ac.car_pivot else ac
		if traf_mgr:
			traf_mgr.target_player = ac
		
		# Retarget police to vehicle
		var cops := get_tree().get_nodes_in_group("police_units")
		for cop in cops:
			if is_instance_valid(cop):
				if cop is PoliceCar:
					(cop as PoliceCar).target_override = ac
				elif cop is PoliceHeli:
					(cop as PoliceHeli).target_override = ac
	else:
		# Commandeering NPC or Police car: Instantiate a brand new ArcadeCar so previous cars stay in world!
		var car_scene := load("res://scenes/vehicles/arcade_car.tscn") as PackedScene
		if not car_scene:
			return
		
		var spawn_pos := Vector3.ZERO
		var spawn_rot := Basis.IDENTITY
		var spawn_vel := Vector3.ZERO
		var npc_type: int = -1
		var police_type: int = -1
		var fleet_id: String = ""
		if veh is NPCTrafficCar:
			var npc := veh as NPCTrafficCar
			fleet_id = npc.car_id
			npc_type = npc.npc_type
			spawn_pos = npc.global_position
			spawn_rot = npc.global_transform.basis
			spawn_vel = npc.linear_velocity * 1.05
			npc.queue_free()
		elif veh is PoliceCar:
			var cop := veh as PoliceCar
			police_type = cop.police_type
			spawn_pos = cop.physics_sphere.global_position if cop.physics_sphere else cop.global_position
			spawn_rot = cop.car_pivot.global_transform.basis if cop.car_pivot else cop.global_transform.basis
			spawn_vel = cop.physics_sphere.linear_velocity if cop.physics_sphere else Vector3.ZERO
			cop.queue_free()
		
		var new_car := car_scene.instantiate() as ArcadeCar
		if not fleet_id.is_empty():
			new_car.car_id = fleet_id
		elif police_type >= 0:
			match police_type:
				1: new_car.car_id = "interceptor_pursuit"
				2: new_car.car_id = "swat_enforcer_van"
				3: new_car.car_id = "bat_vigilante_tank"
				_: new_car.car_id = "patrol_cruiser"
		elif npc_type >= 0:
			match npc_type:
				0: new_car.car_id = "yellow_taxi_cab"
				1: new_car.car_id = "metro_transit_bus"
				2: new_car.car_id = "pizza_delivery_van"
				3: new_car.car_id = "garbage_compactor"
				4: new_car.car_id = "paramedic_rapid"
				5: new_car.car_id = "tanker"
				_: new_car.car_id = "yellow_taxi_cab"
		new_car.is_abandoned = false
		
		var world_parent: Node = get_tree().current_scene if (get_tree() and get_tree().current_scene) else (get_parent() if get_parent() else get_tree().root)
		world_parent.add_child(new_car)
		
		new_car.reset_car_state(spawn_pos, spawn_rot, spawn_vel, npc_type, police_type, fleet_id)
		
		var v_title: String = "VEHICLE"
		var v_col: Color = Color("fbc531")
		var vdb = get_node_or_null("/root/VehicleDatabase")
		if not fleet_id.is_empty() and vdb and vdb.has_car(fleet_id):
			var c_info: Dictionary = vdb.get_car(fleet_id)
			v_title = String(c_info.get("name", "VEHICLE"))
			v_col = c_info.get("rarity_color", Color("fbc531"))
		if hud_node and hud_node.has_method("spawn_floating_text"):
			hud_node.spawn_floating_text(spawn_pos + Vector3.UP * 1.5, "🚗 HIJACKED %s!" % v_title, v_col, 1.35)
		
		if cam_rig:
			cam_rig.target = new_car.car_pivot if new_car.car_pivot else new_car
			cam_rig.follow_speed = 7.0
		if hud_node:
			if "target_car" in hud_node:
				hud_node.target_car = new_car
			if hud_node.has_method("_refresh_gadget_info"):
				hud_node._refresh_gadget_info()
			if "_display_hp" in hud_node:
				hud_node._display_hp = new_car.current_hp
		if city_gen:
			city_gen.target_player = new_car.car_pivot if new_car.car_pivot else new_car
		if traf_mgr:
			traf_mgr.target_player = new_car
		
		# Retarget all police units to new commandeered car
		var cops := get_tree().get_nodes_in_group("police_units")
		for cp in cops:
			if is_instance_valid(cp):
				if cp is PoliceCar:
					(cp as PoliceCar).target_override = new_car
				elif cp is PoliceHeli:
					(cp as PoliceHeli).target_override = new_car
	
	queue_free()

func take_damage(amount: float) -> void:
	current_hp = maxf(0.0, current_hp - amount)
	if has_node("/root/BrawlUITheme"):
		get_node("/root/BrawlUITheme").flash_white(visual_model if visual_model else self, 0.09)
	
	# Update persistent health tracker
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		if wm and "player_persistent_hp" in wm:
			wm.player_persistent_hp = current_hp
	
	# Damage screen shake
	var cam_rig = get_tree().root.find_child("CameraRig", true, false)
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.35)
	
	if current_hp <= 0.0:
		_die_on_foot()

## Applies physical blast impulse to the on-foot fugitive
func apply_knockback(dir: Vector3, force: float = 18.0) -> void:
	var k_dir := dir.normalized()
	k_dir.y = maxf(k_dir.y, 0.45)
	k_dir = k_dir.normalized()
	velocity += k_dir * force

var is_dead: bool = false

func _die_on_foot() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 1 # Keep ground contact only
	
	# Collapse backward onto pavement like GTA/Brawl Stars death
	if visual_model:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(visual_model, "rotation:x", deg_to_rad(-85.0), 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(visual_model, "position:y", 0.08, 0.35)
	
	if _guide_arrow:
		_guide_arrow.visible = false
	if _interaction_label:
		_interaction_label.visible = false
	_clear_pathway_arrows()
	
	# Point CameraRig explicitly at this fallen character
	var cam_rig = get_tree().root.find_child("CameraRig", true, false)
	if cam_rig:
		cam_rig.target = self
	
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		wm.last_wasted_target = self
		wm.trigger_busted("WASTED ON FOOT!")
