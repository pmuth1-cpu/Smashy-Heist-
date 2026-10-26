class_name PoliceCar
extends Node3D

const ExplosionFX = preload("res://scripts/world/explosion_fx.gd")

## Sphere-Car Police AI with Predictive Pursuit, 3-Ray Avoidance, and Chain Explosions.

enum PoliceType {
	PATROL_CRUISER,
	INTERCEPTOR_MUSCLE,
	SWAT_VAN,
	RHINO_TANK
}

@export var police_type: PoliceType = PoliceType.PATROL_CRUISER:
	set(val):
		police_type = val
		if is_inside_tree():
			_apply_type_config()

@export var is_parked: bool = false

var speed: float = 29.5
var turn_speed: float = 4.0
var max_hp: float = 100.0
var hp: float = 100.0
var mass: float = 1.8
var is_wrecked: bool = false
var is_frozen: bool = false
var _frozen_timer: float = 0.0
var _ice_block: MeshInstance3D = null

@onready var physics_sphere: RigidBody3D = $PhysicsSphere
@onready var car_pivot: Node3D = $CarPivot
@onready var chassis_mesh: MeshInstance3D = $CarPivot/ChassisMesh
@onready var siren_bar: Node3D = $CarPivot/SirenBar
@onready var red_light: OmniLight3D = $CarPivot/SirenBar/RedLight
@onready var blue_light: OmniLight3D = $CarPivot/SirenBar/BlueLight
@onready var ground_ray: RayCast3D = $CarPivot/GroundRay
@onready var ray_center: RayCast3D = $CarPivot/RayCenter
@onready var ray_left: RayCast3D = $CarPivot/RayLeft
@onready var ray_right: RayCast3D = $CarPivot/RayRight
@onready var smoke_trail: GPUParticles3D = $CarPivot/SmokeTrail
@onready var explosion_particles: GPUParticles3D = $CarPivot/ExplosionParticles

var _siren_timer: float = 0.0
var _stuck_timer: float = 0.0
var _reverse_timer: float = 0.0
var _previous_velocity: Vector3 = Vector3.ZERO
var _cached_player: ArcadeCar = null
var target_override: Node3D = null

# Escape Road 3 pursuit mechanics: Ram burst, disembark officers, and tank rocket attacks
var is_ramming: bool = false
var _traffic_alert_timer: float = 0.0
var _has_disembarked_officers: bool = false
var _tank_rocket_timer: float = 0.0
var officers_inside: int = 2
var despawn_timer: float = 10.0

const PIVOT_OFFSET_Y: float = -0.45

func _ready() -> void:
	add_to_group("police_units")
	_apply_type_config()
	
	car_pivot.top_level = true
	car_pivot.global_position = physics_sphere.global_position + Vector3(0, PIVOT_OFFSET_Y, 0)
	car_pivot.global_rotation = global_rotation
	
	if not physics_sphere.body_entered.is_connected(_on_physics_sphere_body_entered):
		physics_sphere.body_entered.connect(_on_physics_sphere_body_entered)
	smoke_trail.emitting = false
	explosion_particles.emitting = false

func _apply_type_config() -> void:
	match police_type:
		PoliceType.PATROL_CRUISER:
			speed = 21.5
			turn_speed = 3.4
			mass = 1.8
			max_hp = 200.0
			_setup_mesh(Vector3(1.1, 0.6, 2.2), Color(0.12, 0.12, 0.14), Color(0.95, 0.95, 0.95))
		PoliceType.INTERCEPTOR_MUSCLE:
			speed = 24.5
			turn_speed = 3.8
			mass = 2.0
			max_hp = 180.0
			_setup_mesh(Vector3(1.15, 0.52, 2.3), Color(0.08, 0.18, 0.42), Color(0.85, 0.85, 0.9))
		PoliceType.SWAT_VAN:
			speed = 18.5
			turn_speed = 2.8
			mass = 4.2
			max_hp = 320.0
			_setup_mesh(Vector3(1.4, 1.0, 2.6), Color(0.10, 0.14, 0.22), Color(0.2, 0.25, 0.35))
		PoliceType.RHINO_TANK:
			speed = 15.5
			turn_speed = 2.2
			mass = 8.0
			max_hp = 600.0
			_setup_mesh(Vector3(1.7, 0.85, 2.9), Color(0.28, 0.32, 0.18), Color(0.22, 0.25, 0.15))
	
	hp = max_hp
	if physics_sphere:
		physics_sphere.mass = mass
		var cs = physics_sphere.get_node_or_null("CollisionShape3D")
		if cs and cs.shape is SphereShape3D:
			var s := cs.shape as SphereShape3D
			match police_type:
				PoliceType.PATROL_CRUISER: s.radius = 0.95
				PoliceType.INTERCEPTOR_MUSCLE: s.radius = 0.95
				PoliceType.SWAT_VAN: s.radius = 1.25
				PoliceType.RHINO_TANK: s.radius = 1.45

func _setup_mesh(size: Vector3, primary_color: Color, roof_color: Color) -> void:
	if not chassis_mesh:
		return
	
	# Clear previous roof mesh / children if any
	for child in chassis_mesh.get_children():
		child.queue_free()
	
	var vab = get_node_or_null("/root/VoxelAssetBuilder")
	if vab and vab.has_method("build_police_car_visuals"):
		chassis_mesh.mesh = null
		if siren_bar:
			siren_bar.visible = false
		var p_model: Node3D = vab.build_police_car_visuals(police_type)
		p_model.name = "VoxelPoliceModel"
		chassis_mesh.position = Vector3(0.0, 0.0, 0.0)
		chassis_mesh.add_child(p_model)
	else:
		var box := BoxMesh.new()
		box.size = size
		var mat := StandardMaterial3D.new()
		mat.albedo_color = primary_color
		mat.roughness = 0.35
		box.material = mat
		chassis_mesh.mesh = box
		chassis_mesh.position = Vector3(0.0, size.y * 0.5 + 0.05, 0.0)
		
		# Adjust siren position on top of chassis
		if siren_bar:
			siren_bar.position = Vector3(0.0, size.y + 0.15, 0.0)
			siren_bar.visible = true
		
		var roof := MeshInstance3D.new()
		var r_box := BoxMesh.new()
		r_box.size = Vector3(size.x * 0.85, size.y * 0.45, size.z * 0.45)
		var r_mat := StandardMaterial3D.new()
		r_mat.albedo_color = roof_color
		r_mat.roughness = 0.3
		r_box.material = r_mat
		roof.mesh = r_box
		roof.position = Vector3(0.0, size.y * 0.45, -0.1)
		chassis_mesh.add_child(roof)

func _process(delta: float) -> void:
	# Alternate siren light every 0.15s
	if not is_wrecked:
		_siren_timer += delta
		var is_red: bool = fmod(_siren_timer, 0.30) < 0.15
		if red_light:
			red_light.visible = is_red
		if blue_light:
			blue_light.visible = not is_red

func _physics_process(delta: float) -> void:
	if is_wrecked:
		car_pivot.global_position = physics_sphere.global_position + Vector3(0, PIVOT_OFFSET_Y, 0)
		despawn_timer -= delta
		if despawn_timer <= 0.0:
			queue_free()
		return
	
	if is_frozen:
		_frozen_timer -= delta
		if physics_sphere:
			physics_sphere.linear_velocity = physics_sphere.linear_velocity.move_toward(Vector3.ZERO, delta * 30.0)
		if _frozen_timer <= 0.0:
			is_frozen = false
			if _ice_block and is_instance_valid(_ice_block):
				_ice_block.queue_free()
				_ice_block = null
		car_pivot.global_position = physics_sphere.global_position + Vector3(0, PIVOT_OFFSET_Y, 0)
		return

	# Fell into water canal check
	if physics_sphere.global_position.y < -1.5:
		wreck()
		return
	
	# 1. Sync CarPivot position
	car_pivot.global_position = physics_sphere.global_position + Vector3(0, PIVOT_OFFSET_Y, 0)
	
	# Check smoke trail
	smoke_trail.emitting = (hp < max_hp * 0.5)
	
	# If parked as roadblock, only maintain position and do not pursue
	if is_parked:
		_previous_velocity = physics_sphere.linear_velocity
		return
	
	# 2. Locate active player target (PlayerCharacter on foot, or ArcadeCar in vehicle)
	var current_target: Node3D = target_override if (target_override and is_instance_valid(target_override) and not target_override.is_queued_for_deletion()) else null
	if current_target is ArcadeCar and (current_target as ArcadeCar).is_abandoned:
		current_target = null
		target_override = null
	
	if not current_target:
		# Escape Road 3 Mechanic: Prioritize targeting the on-foot runner if player jumped out of car!
		var runners := get_tree().get_nodes_in_group("player_character")
		for r in runners:
			if is_instance_valid(r) and not r.is_queued_for_deletion():
				current_target = r
				break
		if not current_target:
			if not _cached_player or not is_instance_valid(_cached_player) or _cached_player.is_queued_for_deletion() or _cached_player.is_abandoned:
				_cached_player = _find_player()
			current_target = _cached_player
	
	if not current_target or not is_instance_valid(current_target):
		_previous_velocity = physics_sphere.linear_velocity
		return
	
	var is_target_on_foot: bool = current_target is PlayerCharacter or current_target.is_in_group("player_character")
	var player_pos: Vector3 = current_target.global_position
	var player_velocity: Vector3 = Vector3.ZERO
	if is_target_on_foot:
		player_pos = current_target.global_position
		if "velocity" in current_target:
			player_velocity = current_target.velocity
	else:
		player_pos = current_target.car_pivot.global_position if ("car_pivot" in current_target and current_target.car_pivot) else current_target.global_position
		player_velocity = current_target.physics_sphere.linear_velocity if ("physics_sphere" in current_target and current_target.physics_sphere) else Vector3.ZERO
	
	# Predictive intercept point
	var dist_to_player: float = car_pivot.global_position.distance_to(player_pos)
	var lead_time: float = clampf(dist_to_player / 32.0, 0.15, 1.1)
	var intercept_point: Vector3 = player_pos + player_velocity * lead_time
	
	# If pursuing an on-foot player and within close range, officers jump off to pursue on foot!
	if is_target_on_foot and dist_to_player <= 6.5 and officers_inside > 0 and police_type != PoliceType.RHINO_TANK:
		disembark_all_officers()
	
	# Escape Road 3 Mechanic: Ram Burst & PIT Maneuver when within striking range
	is_ramming = false
	var local_target: Vector3 = car_pivot.to_local(intercept_point)
	# Ram burst only triggers during mid-range closing phase (9m to 15m), NOT when already near player
	if dist_to_player >= 9.0 and dist_to_player <= 15.0 and local_target.z < -1.0:
		is_ramming = true
		# PIT maneuver: bias intercept point slightly toward player's rear quarter panel
		var pit_offset: float = signf(local_target.x) * 0.85 if absf(local_target.x) > 0.3 else (0.8 if posmod(get_instance_id(), 2) == 0 else -0.8)
		local_target.x += pit_offset
	
	# 3. Steering Calculation
	var steer_angle: float = atan2(-local_target.x, -local_target.z)
	var desired_steer: float = clampf(steer_angle * (1.9 if is_ramming else 1.6), -1.0, 1.0)
	
	# Escape Road 3 Mechanic: Swarm Lateral Separation (prevent single-file clumping, pincer flanking)
	var cops := get_tree().get_nodes_in_group("police_units")
	for cop in cops:
		if cop != self and is_instance_valid(cop) and cop is PoliceCar:
			var peer := cop as PoliceCar
			if not peer.is_wrecked and not peer.is_parked and peer.car_pivot:
				var to_peer := car_pivot.to_local(peer.car_pivot.global_position)
				var peer_dist := to_peer.length()
				if peer_dist < 4.2 and peer_dist > 0.1:
					var push_side: float = -signf(to_peer.x) if absf(to_peer.x) > 0.2 else (1.0 if get_instance_id() > peer.get_instance_id() else -1.0)
					desired_steer = clampf(desired_steer + push_side * 0.45 * (1.0 - peer_dist / 4.2), -1.0, 1.0)
	
	# 4. Raycast Avoidance (Layer 4 Buildings)
	var is_center_hit: bool = ray_center.is_colliding()
	var is_left_hit: bool = ray_left.is_colliding()
	var is_right_hit: bool = ray_right.is_colliding()
	
	if is_center_hit:
		if is_left_hit and not is_right_hit:
			desired_steer = -1.0 # Steer right
		elif is_right_hit and not is_left_hit:
			desired_steer = 1.0 # Steer left
		else:
			# Override steering away from normal
			var normal: Vector3 = ray_center.get_collision_normal()
			var local_norm: Vector3 = car_pivot.global_basis.inverse() * normal
			desired_steer = 1.0 if local_norm.x >= 0.0 else -1.0
	elif is_left_hit:
		desired_steer = -1.0 # Steer right
	elif is_right_hit:
		desired_steer = 1.0 # Steer left
	
	# 5. Stuck detection against walls
	var current_speed: float = physics_sphere.linear_velocity.length()
	if current_speed < 1.2:
		_stuck_timer += delta
		if _stuck_timer >= 0.5:
			_reverse_timer = 0.6
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0
	
	if _reverse_timer > 0.0:
		_reverse_timer -= delta
		desired_steer = -desired_steer # Steer opposite when backing up
	
	# Apply steering
	car_pivot.rotation.y += desired_steer * turn_speed * delta
	
	# Tilt chassis mesh on turns
	var target_tilt: float = desired_steer * 0.12
	chassis_mesh.rotation.z = lerpf(chassis_mesh.rotation.z, target_tilt, 8.0 * delta)
	
	# 6. Apply Propulsion & Grip
	var is_grounded: bool = ground_ray.is_colliding()
	if is_grounded:
		var forward_dir: Vector3 = -car_pivot.global_transform.basis.z.normalized()
		var right_dir: Vector3 = car_pivot.global_transform.basis.x.normalized()
		
		if _reverse_timer > 0.0:
			var rev_force: Vector3 = -forward_dir * (speed * 0.6 * physics_sphere.mass * 8.0)
			physics_sphere.apply_central_force(rev_force)
		else:
			var current_forward_speed: float = physics_sphere.linear_velocity.dot(forward_dir)
			var player_speed: float = player_velocity.length()
			
			# Dynamic speed scaling: Cop slows down when getting close to player
			var effective_speed: float = speed * (1.20 if is_ramming else 1.0)
			if dist_to_player < 8.5:
				if dist_to_player < 4.5:
					# Right behind or alongside: bracket/match player speed so player can outmaneuver
					var match_target: float = clampf(player_speed * 0.95, 6.0, speed * 0.82)
					effective_speed = minf(effective_speed, match_target)
				else:
					# Transitional closing range (4.5m to 8.5m): decelerate smoothly towards player speed
					var close_factor: float = (dist_to_player - 4.5) / 4.0
					var near_speed: float = lerpf(clampf(player_speed * 0.98, 7.0, speed * 0.85), speed, close_factor)
					effective_speed = minf(effective_speed, near_speed)
			
			if current_forward_speed < effective_speed:
				var force_ratio: float = clampf(1.0 - (current_forward_speed / effective_speed), 0.0, 1.0)
				var accel_multiplier: float = 1.3 if is_ramming else 1.0
				var accel_force: Vector3 = forward_dir * (speed * 8.5 * physics_sphere.mass * force_ratio * accel_multiplier)
				physics_sphere.apply_central_force(accel_force)
			elif dist_to_player < 8.5 and current_forward_speed > effective_speed + 0.5:
				# Active braking when approaching player too fast to prevent runaway ramming
				var brake_amount: float = clampf((current_forward_speed - effective_speed) / 4.0, 0.2, 1.0)
				var brake_force: Vector3 = -forward_dir * (speed * 6.0 * physics_sphere.mass * brake_amount)
				physics_sphere.apply_central_force(brake_force)
		
		# Lateral drift grip damping to prevent continuous ice-like spinning
		var lateral_speed: float = physics_sphere.linear_velocity.dot(right_dir)
		var lateral_damping: Vector3 = -right_dir * (lateral_speed * 18.0 * physics_sphere.mass)
		physics_sphere.apply_central_force(lateral_damping)
	
	# Siren alert: nearby civilian NPC traffic panics and pulls over or swerves (Emergent pileups)
	_traffic_alert_timer += delta
	if _traffic_alert_timer >= 0.25:
		_traffic_alert_timer = 0.0
		var npcs := get_tree().get_nodes_in_group("npc_traffic")
		for npc in npcs:
			if is_instance_valid(npc) and npc is NPCTrafficCar:
				var npc_car := npc as NPCTrafficCar
				if not npc_car.is_panicking and car_pivot.global_position.distance_to(npc_car.global_position) < 16.0:
					npc_car.trigger_siren_panic(self)
	
	# Escape Road 3 Mechanic: Police Officers disembark on foot when stopped or near player!
	var cur_cop_speed: float = physics_sphere.linear_velocity.length()
	if dist_to_player < 14.0 and cur_cop_speed < 4.5 and not is_wrecked and not _has_disembarked_officers and not is_parked:
		_disembark_officers(2 if police_type == PoliceType.SWAT_VAN else 1)
	
	# Rhino tank turret tracking & Explosive Rocket Firing
	if police_type == PoliceType.RHINO_TANK and current_target and is_instance_valid(current_target) and not is_wrecked:
		var turret := chassis_mesh.find_child("TurretPivot", true, false) as Node3D
		if turret and is_instance_valid(turret):
			var local_tgt: Vector3 = turret.to_local(player_pos)
			local_tgt.y = 0.0
			if local_tgt.length_squared() > 0.04:
				var desired_ang: float = atan2(local_tgt.x, -local_tgt.z)
				turret.rotation.y = lerp_angle(turret.rotation.y, turret.rotation.y + desired_ang, 5.0 * delta)
		
		# Shoot explosive rocket every 3.8s when within range
		_tank_rocket_timer += delta
		if _tank_rocket_timer >= 3.8 and dist_to_player <= 32.0 and dist_to_player >= 5.0:
			_tank_rocket_timer = 0.0
			_fire_rhino_rocket(player_pos)
	
	# Police wheel animation
	var forward_v: Vector3 = -car_pivot.global_transform.basis.z.normalized()
	var f_spd: float = physics_sphere.linear_velocity.dot(forward_v)
	if absf(f_spd) > 0.1:
		var p_spin: float = f_spd * delta * 5.0
		for i in range(4):
			var w := chassis_mesh.find_child("Wheel_%d" % i, true, false) as Node3D
			if w and is_instance_valid(w):
				w.rotation.x += p_spin
	
	_previous_velocity = physics_sphere.linear_velocity

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

func take_damage(amount: float) -> void:
	if is_wrecked:
		return
	
	hp = maxf(0.0, hp - amount)
	if has_node("/root/BrawlUITheme"):
		get_node("/root/BrawlUITheme").flash_white(car_pivot if car_pivot else self, 0.09)
	if hp <= 0.0:
		wreck()

func wreck(custom_impulse: Vector3 = Vector3.ZERO) -> void:
	if is_wrecked:
		return
	is_wrecked = true
	
	# Transition from active police pursuers to persistent world wreckage
	remove_from_group("police_units")
	add_to_group("wrecked_vehicles")
	
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		wm.register_cop_wrecked()
	
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		sfx.play_explosion()
	
	# High-impact Valorant-style debris & liquid splash explosion FX (no circles)
	var p_parent: Node = get_parent() if get_parent() else (get_tree().root if get_tree() else null)
	if p_parent:
		ExplosionFX.spawn_splash(p_parent, car_pivot.global_position, 1.35)
	
	despawn_timer = 10.0
	
	var hud = get_tree().root.find_child("TouchHUD", true, false)
	if hud and hud.has_method("spawn_floating_text"):
		hud.spawn_floating_text(car_pivot.global_position, "💥 +250 WRECKED!", Color("ff4757"), 1.25)
	
	# Screen trauma
	var cam_rig = get_tree().root.find_child("CameraRig", true, false)
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.45)
	
	# Turn charred black
	var charred_mat := StandardMaterial3D.new()
	charred_mat.albedo_color = Color(0.10, 0.10, 0.10)
	charred_mat.roughness = 0.95
	chassis_mesh.material_override = charred_mat
	for child in chassis_mesh.get_children():
		if child is MeshInstance3D:
			child.material_override = charred_mat
	
	# Turn off sirens
	if red_light:
		red_light.visible = false
	if blue_light:
		blue_light.visible = false
	if smoke_trail:
		smoke_trail.emitting = false
	
	# Explosion particle burst
	if explosion_particles:
		explosion_particles.emitting = true
	
	# Persistent Dense Dark Smoke Plume billowing upwards
	var dark_smoke := GPUParticles3D.new()
	dark_smoke.name = "DarkWreckSmoke"
	dark_smoke.amount = 26
	dark_smoke.lifetime = 2.5
	dark_smoke.explosiveness = 0.05
	dark_smoke.randomness = 0.25
	
	var p_mat := ParticleProcessMaterial.new()
	p_mat.direction = Vector3(0.0, 1.0, 0.0)
	p_mat.spread = 24.0
	p_mat.initial_velocity_min = 1.6
	p_mat.initial_velocity_max = 3.4
	p_mat.gravity = Vector3(0.0, 1.4, 0.0)
	p_mat.scale_min = 0.35
	p_mat.scale_max = 1.15
	p_mat.color = Color(0.05, 0.05, 0.05, 0.88)
	dark_smoke.process_material = p_mat
	
	var s_mesh := SphereMesh.new()
	s_mesh.radius = 0.32
	s_mesh.height = 0.64
	var sm_mat := StandardMaterial3D.new()
	sm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm_mat.albedo_color = Color(0.05, 0.05, 0.05, 0.82)
	s_mesh.material = sm_mat
	dark_smoke.draw_pass_1 = s_mesh
	
	dark_smoke.position = Vector3(0.0, 0.45, 0.0)
	car_pivot.add_child(dark_smoke)
	dark_smoke.emitting = true
	
	# Launch upward with torque and high friction damping to settle on the road as solid obstacle
	if physics_sphere:
		physics_sphere.linear_damp = 3.5
		physics_sphere.angular_damp = 5.0
		physics_sphere.apply_central_impulse(Vector3(
			randf_range(-3.0, 3.0),
			13.0,
			randf_range(-3.0, 3.0)
		) * physics_sphere.mass)
		physics_sphere.angular_velocity = Vector3(
			randf_range(-10.0, 10.0),
			randf_range(-10.0, 10.0),
			randf_range(-10.0, 10.0)
		)
	
	# Disembark surviving officers from wreck
	if officers_inside > 0 and police_type != PoliceType.RHINO_TANK:
		disembark_all_officers()
	
	# Chain-reaction blast impulse to nearby police and smash props
	_apply_chain_explosion()
	
	# Keep up to 40 persistent charred smoking wrecks in the world
	var wrecks := get_tree().get_nodes_in_group("wrecked_vehicles")
	if wrecks.size() > 40:
		var oldest = wrecks[0]
		if is_instance_valid(oldest) and oldest != self and oldest is Node:
			oldest.queue_free()

func _apply_chain_explosion() -> void:
	var blast_pos: Vector3 = car_pivot.global_position
	var blast_radius: float = 6.5
	var blast_force: float = 24.0
	
	# Query police units
	var cops := get_tree().get_nodes_in_group("police_units")
	for cop in cops:
		if cop != self and is_instance_valid(cop) and cop is PoliceCar:
			var cop_car := cop as PoliceCar
			if not cop_car.is_wrecked:
				var dist: float = blast_pos.distance_to(cop_car.physics_sphere.global_position)
				if dist <= blast_radius:
					var dir: Vector3 = (cop_car.physics_sphere.global_position - blast_pos)
					dir.y += 0.5
					dir = dir.normalized()
					var factor: float = clampf(1.0 - (dist / blast_radius), 0.3, 1.0)
					cop_car.physics_sphere.apply_central_impulse(dir * (blast_force * factor * cop_car.physics_sphere.mass))
					# Deal explosive damage to trigger chain explosion
					cop_car.take_damage(65.0 * factor)
	
	# Query props
	var props := get_tree().get_nodes_in_group("smash_props")
	for prop in props:
		if is_instance_valid(prop) and prop is RigidBody3D:
			var rb := prop as RigidBody3D
			var dist: float = blast_pos.distance_to(rb.global_position)
			if dist <= blast_radius:
				var dir: Vector3 = (rb.global_position - blast_pos)
				dir.y += 0.5
				dir = dir.normalized()
				var factor: float = clampf(1.0 - (dist / blast_radius), 0.3, 1.0)
				rb.freeze = false
				rb.apply_central_impulse(dir * (blast_force * factor * rb.mass))

func _on_physics_sphere_body_entered(body: Node) -> void:
	if is_wrecked:
		return
	
	var impact_speed: float = _previous_velocity.length()
	if body is RigidBody3D:
		impact_speed = (_previous_velocity - (body as RigidBody3D).linear_velocity).length()
	
	var is_ground: bool = (body.name == "Ground") or (body is CollisionObject3D and (body as CollisionObject3D).get_collision_layer_value(1))
	if not is_ground and impact_speed > 11.0:
		var dmg: float = clampf((impact_speed - 10.0) * 2.0, 4.0, 24.0)
		take_damage(dmg)

## Freezes the police car in solid ice for active gadget attacks
func freeze(duration: float = 4.0) -> void:
	if is_wrecked:
		return
	is_frozen = true
	_frozen_timer = duration
	if physics_sphere:
		physics_sphere.linear_velocity = Vector3.ZERO
		physics_sphere.angular_velocity = Vector3.ZERO
	if not _ice_block or not is_instance_valid(_ice_block):
		_ice_block = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.4, 1.8, 3.8)
		_ice_block.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.8, 1.0, 0.7)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.1
		mat.emission_enabled = true
		mat.emission = Color("74b9ff")
		mat.emission_energy_multiplier = 1.0
		_ice_block.material_override = mat
		_ice_block.position = Vector3(0.0, 0.5, 0.0)
		car_pivot.add_child(_ice_block)

## Returns true if the police car has no officers inside and can be commandeered
func can_be_hijacked() -> bool:
	return officers_inside == 0 and not is_wrecked

## Forces all remaining officers inside the vehicle to jump off and pursue on foot
func disembark_all_officers() -> void:
	_disembark_officers(officers_inside)

## Disembarks police officers on foot to pursue and shoot at player
func _disembark_officers(count: int = 2) -> void:
	if officers_inside <= 0:
		return
	
	var actual_count: int = mini(count, officers_inside)
	officers_inside = maxi(0, officers_inside - actual_count)
	if officers_inside == 0:
		_has_disembarked_officers = true
	
	var OfficerScript = load("res://scripts/characters/police_officer.gd")
	if not OfficerScript:
		return
	
	for i in range(actual_count):
		var officer: CharacterBody3D = OfficerScript.new()
		var side_offset: float = -1.6 if i == 0 else 1.6
		var spawn_pos: Vector3 = car_pivot.global_position + (car_pivot.global_transform.basis.x * side_offset) + Vector3.UP * 0.2
		var p_parent: Node = get_parent() if get_parent() else (get_tree().root if get_tree() else null)
		if p_parent:
			p_parent.add_child(officer)
			officer.global_position = spawn_pos
		
		# Notification
		var hud = get_tree().root.find_child("TouchHUD", true, false)
		if hud and hud.has_method("spawn_floating_text") and i == 0:
			hud.spawn_floating_text(spawn_pos + Vector3.UP * 1.5, "👮 %d POLICE JUMPED OUT!" % actual_count, Color("00d2d3"), 1.25)

## Applies radial physical explosion knockback to the police car
func apply_knockback(dir: Vector3, force: float = 24.0) -> void:
	if not physics_sphere:
		return
	var launch_dir := dir.normalized()
	launch_dir.y = maxf(launch_dir.y, 0.45)
	launch_dir = launch_dir.normalized()
	physics_sphere.apply_central_impulse(launch_dir * (force * physics_sphere.mass))
	var rand_torque := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (force * 0.4)
	physics_sphere.apply_torque_impulse(rand_torque)

## Fires explosive rocket from Rhino Tank turret
func _fire_rhino_rocket(target_pos: Vector3) -> void:
	if not is_inside_tree() or is_wrecked:
		return
	var RocketScript = load("res://scripts/world/explosive_rocket.gd")
	if not RocketScript:
		return
	
	var rocket: Area3D = RocketScript.new()
	var spawn_pos: Vector3 = car_pivot.global_position + Vector3(0.0, 0.9, 0.0) + (-car_pivot.global_transform.basis.z * 1.8)
	var aim_dir: Vector3 = (target_pos - spawn_pos).normalized()
	aim_dir.y = clampf(aim_dir.y, -0.2, 0.2)
	aim_dir = aim_dir.normalized()
	
	rocket.direction = aim_dir
	rocket.shooter = self
	
	var p_parent: Node = get_parent() if get_parent() else (get_tree().root if get_tree() else null)
	if p_parent:
		p_parent.add_child(rocket)
		rocket.global_position = spawn_pos
		rocket.look_at(spawn_pos + aim_dir, Vector3.UP)
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_explosion()
