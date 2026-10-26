class_name PoliceHeli
extends Node3D

## Police Support Helicopter for 4-Star & 5-Star Wanted Escalation.
## Follows above the player and calls in aerial warning strikes with radial shockwaves.

@onready var fuselage: MeshInstance3D = $Fuselage
@onready var main_rotor: MeshInstance3D = $Fuselage/MainRotor
@onready var tail_rotor: MeshInstance3D = $Fuselage/TailRotor
@onready var spot_light: SpotLight3D = $SpotLight3D

var _strike_timer: float = 0.0
var _bob_timer: float = 0.0
var _cached_player: ArcadeCar = null
var target_override: Node3D = null

const ATTACK_INTERVAL: float = 4.5
const WARNING_DELAY: float = 1.4
const HOVER_HEIGHT: float = 16.0
const STRIKE_AHEAD_DIST: float = 14.0
const STRIKE_RADIUS: float = 4.5

func _ready() -> void:
	visible = false

func _process(delta: float) -> void:
	# Active only when 4+ stars and run is active
	var is_active: bool = false
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		is_active = wm.is_run_active and wm.wanted_stars >= 4
	
	if not is_active:
		if visible:
			visible = false
		return
	
	if not visible:
		visible = true
		_strike_timer = 2.0 # Initial grace period before first airstrike
	
	# Spin rotors
	if main_rotor:
		main_rotor.rotation.y += delta * 32.0
	if tail_rotor:
		tail_rotor.rotation.x += delta * 45.0
	
	_bob_timer += delta
	
	# Find player or target_override
	var current_target: Node3D = target_override if (target_override and is_instance_valid(target_override) and not target_override.is_queued_for_deletion()) else null
	if current_target is ArcadeCar and (current_target as ArcadeCar).is_abandoned:
		current_target = null
		target_override = null
	
	if not current_target:
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
		return
	
	var player_pos: Vector3 = current_target.car_pivot.global_position if ("car_pivot" in current_target and current_target.car_pivot) else current_target.global_position
	var player_vel: Vector3 = current_target.physics_sphere.linear_velocity if ("physics_sphere" in current_target and current_target.physics_sphere) else Vector3.ZERO

	
	# Hover position with sine-wave bob
	var bob_offset: float = sin(_bob_timer * 2.2) * 1.1
	var desired_pos: Vector3 = player_pos + Vector3(0.0, HOVER_HEIGHT + bob_offset, 0.0)
	# Slight trail offset behind velocity
	if player_vel.length() > 2.0:
		desired_pos -= player_vel.normalized() * 3.5
	
	global_position = global_position.lerp(desired_pos, delta * 3.2)
	
	# Point searchlight towards player
	if spot_light:
		var light_dir: Vector3 = player_pos - spot_light.global_position
		if light_dir.length() > 0.1:
			var light_up: Vector3 = Vector3.UP if absf(light_dir.normalized().y) < 0.95 else Vector3.FORWARD
			spot_light.look_at(player_pos, light_up)
	
	# Look towards player motion
	var look_target: Vector3 = player_pos + player_vel * 0.5
	var dir_h: Vector3 = look_target - global_position
	dir_h.y = 0.0
	if dir_h.length() > 0.5:
		var target_basis: Basis = Basis.looking_at(dir_h.normalized(), Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(target_basis, delta * 2.5)
	
	# Aerial Strike Countdown
	_strike_timer += delta
	if _strike_timer >= ATTACK_INTERVAL:
		_strike_timer = 0.0
		_call_air_strike(player_pos, player_vel)

func _call_air_strike(player_pos: Vector3, player_vel: Vector3) -> void:
	var forward: Vector3 = player_vel.normalized() if player_vel.length() > 3.0 else -_cached_player.car_pivot.global_transform.basis.z.normalized()
	var strike_target: Vector3 = player_pos + forward * STRIKE_AHEAD_DIST
	
	# Raycast to ground
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ray_query := PhysicsRayQueryParameters3D.create(
		strike_target + Vector3(0, 20, 0),
		strike_target + Vector3(0, -10, 0),
		1 # Ground layer
	)
	var result: Dictionary = space_state.intersect_ray(ray_query)
	var ground_y: float = 0.05
	if result:
		ground_y = (result["position"] as Vector3).y + 0.05
	strike_target.y = ground_y
	
	_spawn_strike_indicator(strike_target)

func _spawn_strike_indicator(target_pos: Vector3) -> void:
	var marker := Node3D.new()
	marker.name = "AirstrikeMarker"
	marker.position = target_pos
	
	# Warning ring mesh (red glowing circle)
	var ring_mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = STRIKE_RADIUS - 0.25
	torus.outer_radius = STRIKE_RADIUS
	torus.rings = 24
	torus.ring_segments = 12
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.15, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.1)
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = mat
	ring_mesh.mesh = torus
	ring_mesh.position = Vector3(0.0, 0.05, 0.0)
	marker.add_child(ring_mesh)
	
	# Center warning spotlight/beacon
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.2, 0.1)
	light.light_energy = 5.0
	light.omni_range = STRIKE_RADIUS * 1.5
	marker.add_child(light)
	
	get_parent().add_child(marker)
	
	# Pulse animation and detonation countdown
	var tween := marker.create_tween()
	tween.tween_property(ring_mesh, "scale", Vector3(1.15, 1.0, 1.15), 0.35).set_trans(Tween.TRANS_SINE)
	tween.tween_property(ring_mesh, "scale", Vector3(0.9, 1.0, 0.9), 0.35).set_trans(Tween.TRANS_SINE)
	tween.tween_property(ring_mesh, "scale", Vector3(1.2, 1.0, 1.2), 0.35).set_trans(Tween.TRANS_SINE)
	tween.tween_property(ring_mesh, "scale", Vector3(1.0, 1.0, 1.0), 0.35).set_trans(Tween.TRANS_SINE)
	
	# Detonate after WARNING_DELAY
	get_tree().create_timer(WARNING_DELAY).timeout.connect(func():
		if is_instance_valid(marker):
			_detonate_strike(target_pos)
			marker.queue_free()
	)

func _detonate_strike(pos: Vector3) -> void:
	# Blast particle burst
	var particles := GPUParticles3D.new()
	var p_mat := ParticleProcessMaterial.new()
	p_mat.direction = Vector3(0, 1, 0)
	p_mat.spread = 75.0
	p_mat.initial_velocity_min = 8.0
	p_mat.initial_velocity_max = 16.0
	p_mat.gravity = Vector3(0, -9.8, 0)
	p_mat.scale_min = 0.25
	p_mat.scale_max = 0.7
	p_mat.color = Color(1.0, 0.35, 0.1, 1.0)
	particles.process_material = p_mat
	
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(0.3, 0.3, 0.3)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.4, 0.1)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_mesh.material = m
	particles.draw_pass_1 = b_mesh
	
	particles.amount = 40
	particles.lifetime = 0.9
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.position = pos + Vector3(0, 0.4, 0)
	get_parent().add_child(particles)
	particles.emitting = true
	
	# Screen trauma
	var cam_rig = get_tree().root.find_child("CameraRig", true, false)
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.55)
	
	# Radial impulse to physics bodies within STRIKE_RADIUS
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var shape_query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = STRIKE_RADIUS
	shape_query.shape = sphere
	shape_query.transform = Transform3D(Basis(), pos)
	shape_query.collision_mask = 31 # All cars, props, units
	
	var hits := space_state.intersect_shape(shape_query, 32)
	for hit in hits:
		var collider: Object = hit.get("collider")
		if collider and collider is RigidBody3D:
			var rb := collider as RigidBody3D
			var dir: Vector3 = (rb.global_position - pos)
			dir.y += 0.65
			dir = dir.normalized()
			var dist: float = pos.distance_to(rb.global_position)
			var factor: float = clampf(1.0 - (dist / STRIKE_RADIUS), 0.25, 1.0)
			rb.apply_central_impulse(dir * (30.0 * factor * rb.mass))
			
			# If police car, damage it
			var cop = rb.get_parent() if rb.get_parent() is PoliceCar else null
			if cop and cop is PoliceCar:
				(cop as PoliceCar).take_damage(60.0 * factor)
			
			# If player car, damage player
			if rb.get_parent() and rb.get_parent() is ArcadeCar:
				var player_car := rb.get_parent() as ArcadeCar
				if player_car.has_method("take_damage"):
					player_car.take_damage(35.0 * factor)
	
	# Auto cleanup particles
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

func _find_player() -> ArcadeCar:
	var player_nodes := get_tree().get_nodes_in_group("player")
	for p in player_nodes:
		if is_instance_valid(p) and not p.is_queued_for_deletion() and p is ArcadeCar and not (p as ArcadeCar).is_abandoned:
			return p as ArcadeCar
	for p in player_nodes:
		if is_instance_valid(p) and not p.is_queued_for_deletion() and p is ArcadeCar:
			return p as ArcadeCar
	return get_tree().root.find_child("ArcadeCar", true, false) as ArcadeCar
