class_name CameraRig
extends Node3D

@export var target: Node3D
@export var follow_speed: float = 7.0
@export var max_lookahead: float = 5.5
@export var lookahead_speed_factor: float = 0.16

enum CameraPreset {
	STANDARD = 0,
	WIDE = 1,
	ACTION_ZOOM = 2
}
@export var camera_preset: CameraPreset = CameraPreset.STANDARD

const PRESET_OFFSETS: Dictionary = {
	CameraPreset.STANDARD: Vector3(12.61, 16.06, 12.61), # 24m distance at pitch -42, yaw 45
	CameraPreset.WIDE: Vector3(15.76, 20.07, 15.76),     # 30m distance
	CameraPreset.ACTION_ZOOM: Vector3(9.46, 12.04, 9.46) # 18m distance
}

const PRESET_FOVS: Dictionary = {
	CameraPreset.STANDARD: 32.0,
	CameraPreset.WIDE: 34.0,
	CameraPreset.ACTION_ZOOM: 30.0
}

@export var trauma_decay: float = 1.6
@export var max_pos_shake: Vector3 = Vector3(0.4, 0.3, 0.4)
@export var max_rot_shake: Vector3 = Vector3(0.03, 0.03, 0.03)

@export var mode: String = "FOLLOW":
	set(val):
		var prev := mode
		mode = val
		if mode == "CUTSCENE_ORBIT" and prev != "CUTSCENE_ORBIT":
			_start_cutscene_orbit()
		elif mode == "KART_CHASE" and prev != "KART_CHASE":
			_start_kart_chase()
		elif mode == "FOLLOW" and prev != "FOLLOW":
			_reset_to_follow()

var trauma: float = 0.0
var _noise: FastNoiseLite
var _noise_time: float = 0.0
var _last_target_pos: Vector3 = Vector3.ZERO
var _target_velocity: Vector3 = Vector3.ZERO

# Cutscene Orbit Parameters
var orbit_angle: float = 0.0
var orbit_speed: float = 0.45 # 0.45 rad/s
var orbit_distance: float = 8.5 # 8.5 meters
var orbit_pitch_deg: float = -22.0 # -22 degrees
var _current_orbit_dist: float = 8.5
var _current_pitch_deg: float = -22.0
var _swoop_tween: Tween = null

# Building Occlusion Transparency (Escape Road 3)
var _occluding_bodies: Array[Node] = []
var _occlusion_timer: float = 0.0

@onready var shake_offset: Marker3D = $ShakeOffset
@onready var camera: Camera3D = $ShakeOffset/Camera3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.8
	_noise.seed = randi()
	
	if target and is_instance_valid(target):
		global_position = target.global_position
		_last_target_pos = target.global_position

func _physics_process(delta: float) -> void:
	if not target or not is_instance_valid(target):
		return
	
	if mode == "CUTSCENE_ORBIT":
		global_position = target.global_position
		return
	elif mode == "KART_CHASE":
		_physics_process_kart_chase(delta)
		return
	
	var current_target_pos := target.global_position
	var parent_node = target.get_parent()
	if parent_node and "physics_sphere" in parent_node and parent_node.physics_sphere:
		_target_velocity = parent_node.physics_sphere.linear_velocity
	elif target is RigidBody3D:
		_target_velocity = target.linear_velocity
	else:
		_target_velocity = (current_target_pos - _last_target_pos) / maxf(delta, 0.0001)
	
	_last_target_pos = current_target_pos
	
	# Horizontal velocity look-ahead offset up to max_lookahead
	var horizontal_vel := Vector3(_target_velocity.x, 0.0, _target_velocity.z)
	var lookahead_dist := clampf(horizontal_vel.length() * lookahead_speed_factor, 0.0, max_lookahead)
	var lookahead := Vector3.ZERO
	if horizontal_vel.length() > 0.5:
		lookahead = horizontal_vel.normalized() * lookahead_dist
	
	var desired_pos := current_target_pos + lookahead
	global_position = global_position.lerp(desired_pos, follow_speed * delta)

func _process(delta: float) -> void:
	var eff_dt: float = delta
	if Engine.time_scale > 0.001 and Engine.time_scale < 0.9:
		eff_dt = delta / Engine.time_scale
	
	if mode == "CUTSCENE_ORBIT":
		_process_cutscene_orbit(eff_dt)
	elif mode == "KART_CHASE":
		_process_kart_chase(eff_dt)
	
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - trauma_decay * eff_dt)
		var shake := trauma * trauma
		_noise_time += eff_dt * 50.0
		
		shake_offset.position.x = max_pos_shake.x * _noise.get_noise_2d(10.0, _noise_time) * shake
		shake_offset.position.y = max_pos_shake.y * _noise.get_noise_2d(20.0, _noise_time) * shake
		shake_offset.position.z = max_pos_shake.z * _noise.get_noise_2d(30.0, _noise_time) * shake
		
		shake_offset.rotation.x = max_rot_shake.x * _noise.get_noise_2d(40.0, _noise_time) * shake
		shake_offset.rotation.y = max_rot_shake.y * _noise.get_noise_2d(50.0, _noise_time) * shake
		shake_offset.rotation.z = max_rot_shake.z * _noise.get_noise_2d(60.0, _noise_time) * shake
	else:
		shake_offset.position = Vector3.ZERO
		shake_offset.rotation = Vector3.ZERO
	
	if mode == "FOLLOW":
		# Dynamic Speed FOV: lerp between 34.0 (normal cruising) and 44.0 (Drift Boost / Nitro Overdrive)
		var is_speed_boost: bool = false
		if target and is_instance_valid(target):
			var p_car = target.get_parent() if (target.get_parent() and target.get_parent() is ArcadeCar) else (target as ArcadeCar)
			if p_car:
				if ("drift_boost_time" in p_car and p_car.drift_boost_time > 0.0) or \
				   ("active_powerup" in p_car and p_car.active_powerup == 0 and p_car.powerup_time_remaining > 0.0) or \
				   ("is_speed_boosting" in p_car and p_car.is_speed_boosting):
					is_speed_boost = true
			if not is_speed_boost and _target_velocity.length() > 22.0:
				is_speed_boost = true
		
		var is_on_foot: bool = false
		if target and is_instance_valid(target):
			is_on_foot = target.is_in_group("player_character") or (target.get_parent() and target.get_parent().is_in_group("player_character"))
		
		# 16:9 Landscape Camera: Smooth glide closer when on foot, or use selected preset offset
		var base_offset: Vector3 = PRESET_OFFSETS.get(camera_preset, Vector3(12.61, 16.06, 12.61))
		var base_fov: float = PRESET_FOVS.get(camera_preset, 32.0)
		var target_cam_offset: Vector3 = Vector3(7.5, 10.6, 7.5) if is_on_foot else base_offset
		if camera:
			camera.position = camera.position.lerp(target_cam_offset, 3.5 * delta)
			var target_fov: float = 38.0 if is_on_foot else ((base_fov + 10.0) if is_speed_boost else base_fov)
			camera.fov = lerpf(camera.fov, target_fov, 4.0 * delta)
		
		_check_building_occlusion(eff_dt)

## Toggles through camera distance presets (Standard 24m -> Wide 30m -> Action Zoom 18m)
func toggle_camera_distance() -> String:
	camera_preset = ((int(camera_preset) + 1) % 3) as CameraPreset
	return get_camera_preset_name()

## Returns display name of active camera preset
func get_camera_preset_name() -> String:
	match camera_preset:
		CameraPreset.STANDARD:
			return "STANDARD (24M)"
		CameraPreset.WIDE:
			return "WIDE (30M)"
		CameraPreset.ACTION_ZOOM:
			return "ACTION ZOOM (18M)"
		_:
			return "STANDARD (24M)"

func _process_cutscene_orbit(dt: float) -> void:
	if not target or not is_instance_valid(target) or not camera:
		return
	
	global_position = target.global_position
	orbit_angle += orbit_speed * dt
	
	var pitch_rad: float = deg_to_rad(-_current_pitch_deg) # Elevation angle above ground
	var r_horiz: float = _current_orbit_dist * cos(pitch_rad)
	var cam_y: float = _current_orbit_dist * sin(pitch_rad)
	var cam_x: float = cos(orbit_angle) * r_horiz
	var cam_z: float = sin(orbit_angle) * r_horiz
	
	camera.position = Vector3(cam_x, cam_y, cam_z)
	camera.look_at(global_position, Vector3.UP)
	camera.fov = lerpf(camera.fov, 38.0, 4.0 * dt)

func _start_cutscene_orbit() -> void:
	if not camera:
		return
	var orig_cam_pos := camera.position
	var start_dist: float = orig_cam_pos.length()
	var horiz_dist: float = Vector2(orig_cam_pos.x, orig_cam_pos.z).length()
	var start_pitch: float = -rad_to_deg(atan2(orig_cam_pos.y, maxf(horiz_dist, 0.001)))
	
	if horiz_dist > 0.01:
		orbit_angle = atan2(orig_cam_pos.z, orig_cam_pos.x)
	
	_current_orbit_dist = start_dist
	_current_pitch_deg = start_pitch
	
	if _swoop_tween and _swoop_tween.is_valid():
		_swoop_tween.kill()
	
	_swoop_tween = create_tween()
	_swoop_tween.set_ignore_time_scale(true)
	_swoop_tween.parallel().tween_property(self, "_current_orbit_dist", orbit_distance, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_swoop_tween.parallel().tween_property(self, "_current_pitch_deg", orbit_pitch_deg, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Switches camera rig into cutscene orbit around specified pivot
func switch_to_cutscene_orbit(pivot: Node3D = null) -> void:
	if pivot and is_instance_valid(pivot):
		target = pivot
	mode = "CUTSCENE_ORBIT"

## Add trauma for rotational/positional camera shake (e.g. from collisions).
func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

## Escape Road 3 Mechanic: Dynamic line-of-sight raycast fade for occluding buildings
func _check_building_occlusion(delta: float) -> void:
	if not target or not is_instance_valid(target) or not camera or not is_inside_tree():
		return
	
	_occlusion_timer += delta
	if _occlusion_timer < 0.06:
		return
	_occlusion_timer = 0.0
	
	var world_3d := get_world_3d()
	if not world_3d:
		return
	var space := world_3d.direct_space_state
	if not space:
		return
	
	var from_pos: Vector3 = camera.global_position
	var to_pos: Vector3 = target.global_position + Vector3(0, 0.6, 0)
	
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = 8 # Layer 4: Buildings
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var hit := space.intersect_ray(query)
	var new_occluder: Node = null
	if not hit.is_empty():
		new_occluder = hit.get("collider")
	
	# Restore previously occluding bodies
	var remaining: Array[Node] = []
	for old_body in _occluding_bodies:
		if is_instance_valid(old_body):
			if old_body != new_occluder:
				_set_building_transparency(old_body, 1.0)
			else:
				remaining.append(old_body)
	
	_occluding_bodies = remaining
	if new_occluder and is_instance_valid(new_occluder) and not _occluding_bodies.has(new_occluder):
		_occluding_bodies.append(new_occluder)
		_set_building_transparency(new_occluder, 0.28)

func _set_building_transparency(node: Node, target_alpha: float) -> void:
	if not is_instance_valid(node):
		return
	var mesh_instances := node.find_children("*", "MeshInstance3D", true, false)
	for mi in mesh_instances:
		if mi is MeshInstance3D:
			if not mi.material_override:
				if mi.mesh and mi.mesh.material and mi.mesh.material is StandardMaterial3D:
					mi.material_override = (mi.mesh.material as StandardMaterial3D).duplicate()
				else:
					continue
			
			if mi.material_override is StandardMaterial3D:
				var sm := mi.material_override as StandardMaterial3D
				if target_alpha < 0.99:
					sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					sm.albedo_color.a = target_alpha
				else:
					sm.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					sm.albedo_color.a = 1.0

# ==============================================================================
# 3RD PERSON BACK CHASE CAMERA (Smashy Kart GP)
# ==============================================================================

var _kart_cam_yaw: float = 0.0
var _kart_cam_initialized: bool = false

func _start_kart_chase() -> void:
	_kart_cam_initialized = false
	if target and is_instance_valid(target):
		_kart_cam_yaw = target.global_rotation.y
		global_position = target.global_position
		if camera:
			camera.fov = 58.0

func _physics_process_kart_chase(delta: float) -> void:
	if not target or not is_instance_valid(target):
		return
	
	var target_pos := target.global_position
	var target_yaw := target.global_rotation.y
	
	if not _kart_cam_initialized:
		_kart_cam_initialized = true
		_kart_cam_yaw = target_yaw
		global_position = target_pos
	
	# Snappy position follow directly with target car
	global_position = global_position.lerp(target_pos, 14.0 * delta)
	
	# Smoothly track car orientation
	_kart_cam_yaw = lerp_angle(_kart_cam_yaw, target_yaw, 8.5 * delta)

func _process_kart_chase(dt: float) -> void:
	if not target or not is_instance_valid(target) or not camera:
		return
	
	var speed: float = 0.0
	var p_car = target.get_parent() if (target.get_parent() and target.get_parent() is ArcadeCar) else (target as ArcadeCar)
	if p_car and "physics_sphere" in p_car and p_car.physics_sphere:
		speed = p_car.physics_sphere.linear_velocity.length()
	
	# 3rd Person Back View: 6.4m behind car, 2.45m up
	var dist: float = 6.4 + minf(speed * 0.05, 1.5)
	var height: float = 2.45
	
	var rot_basis := Basis(Vector3.UP, _kart_cam_yaw)
	var back_dir := rot_basis.z.normalized() # In Godot, -Z is forward, so +Z is backward
	var fwd_dir := -back_dir
	
	var desired_cam_world := global_position + back_dir * dist + Vector3(0.0, height, 0.0)
	var look_at_target := global_position + fwd_dir * 4.5 + Vector3(0.0, 0.95, 0.0)
	
	camera.global_position = desired_cam_world
	camera.look_at(look_at_target, Vector3.UP)
	
	# Dynamic Speed FOV: 58.0 up to 72.0 during nitro or speed boost
	var is_speed_boost: bool = false
	if p_car:
		if ("drift_boost_time" in p_car and p_car.drift_boost_time > 0.0) or \
		   ("active_powerup" in p_car and p_car.active_powerup == 0 and p_car.powerup_time_remaining > 0.0) or \
		   ("is_speed_boosting" in p_car and p_car.is_speed_boosting):
			is_speed_boost = true
	
	var target_fov: float = 70.0 if is_speed_boost else (58.0 + minf(speed * 0.35, 7.0))
	camera.fov = lerpf(camera.fov, target_fov, 4.0 * dt)

func _reset_to_follow() -> void:
	_kart_cam_initialized = false
	if camera:
		camera.position = PRESET_OFFSETS.get(camera_preset, Vector3(12.61, 16.06, 12.61))
		camera.rotation_degrees = Vector3(-42.0, 45.0, 0.0)
		camera.fov = PRESET_FOVS.get(camera_preset, 32.0)

