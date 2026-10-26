class_name PoliceOfficer
extends CharacterBody3D

## On-Foot Police Officer enemy for Smashy Heist / Escape Road 3.
## Spawns when police cruisers stop, crash, or at roadblocks.
## Pursues the player, fires sidearm pistol at player car / runner,
## and can be run over and eliminated by vehicles for cash & score bonuses!

signal officer_eliminated(officer: PoliceOfficer)

@export var run_speed: float = 7.5
@export var shoot_interval: float = 1.4
@export var bullet_damage: float = 5.0
@export var max_range: float = 22.0
@export var min_shoot_dist: float = 3.5

@export var max_hp: float = 85.0
var current_hp: float = 85.0
var is_eliminated: bool = false
var _shoot_timer: float = 0.0
var _anim_time: float = 0.0

var _invuln_timer: float = 0.0
var _dodge_cooldown: float = 0.0
var _is_dodging: bool = false
var _dodge_timer: float = 0.0

var visual_model: Node3D = null
var leg_l: Node3D = null
var leg_r: Node3D = null
var torso: Node3D = null
var _pistol_mesh: MeshInstance3D = null

const GRAVITY: float = 20.0
const DESPAWN_DIST: float = 85.0

func _ready() -> void:
	add_to_group("police_units")
	add_to_group("police_officers")
	
	# Layer 4 (Police / Enemies)
	collision_layer = 4
	# Collides with Ground (1), Player (2), Buildings (8), Traffic/Props (16)
	collision_mask = 1 | 2 | 8 | 16
	
	floor_snap_length = 0.4
	floor_constant_speed = true
	floor_stop_on_slope = true
	
	# Add Capsule Collision Shape
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 0.88
	cs.shape = cap
	cs.position = Vector3(0.0, 0.44, 0.0)
	add_child(cs)
	
	# Build 3D Voxel Model
	_build_officer_visuals()
	
	# Hitbox Area to detect vehicles running over the officer
	var hit_area := Area3D.new()
	hit_area.name = "VehicleHitArea"
	hit_area.collision_layer = 0
	hit_area.collision_mask = 2 | 4 | 16 # Detects Player (2), Police vehicles (4), Traffic (16)
	var hit_cs := CollisionShape3D.new()
	var hit_sphere := SphereShape3D.new()
	hit_sphere.radius = 0.65
	hit_cs.shape = hit_sphere
	hit_cs.position = Vector3(0.0, 0.45, 0.0)
	hit_area.add_child(hit_cs)
	add_child(hit_area)
	hit_area.body_entered.connect(_on_vehicle_hit_area_body_entered)

func _build_officer_visuals() -> void:
	var vab = get_node_or_null("/root/VoxelAssetBuilder")
	if vab and vab.has_method("build_police_officer"):
		visual_model = vab.build_police_officer()
		add_child(visual_model)
		leg_l = visual_model.find_child("Leg_L", true, false)
		leg_r = visual_model.find_child("Leg_R", true, false)
		torso = visual_model.find_child("Torso", true, false)
	
	# Add Service Pistol in right hand
	_pistol_mesh = MeshInstance3D.new()
	var p_box := BoxMesh.new()
	p_box.size = Vector3(0.06, 0.09, 0.22)
	_pistol_mesh.mesh = p_box
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color("1e272e")
	p_mat.metallic = 0.8
	p_mat.roughness = 0.25
	_pistol_mesh.material_override = p_mat
	_pistol_mesh.position = Vector3(0.24, 0.48, -0.22)
	add_child(_pistol_mesh)

func _physics_process(delta: float) -> void:
	if is_eliminated:
		return
	
	if _invuln_timer > 0.0:
		_invuln_timer -= delta
	if _dodge_cooldown > 0.0:
		_dodge_cooldown -= delta
	
	# If currently performing an evasive dive roll, continue evasion trajectory
	if _is_dodging:
		_dodge_timer -= delta
		if _dodge_timer <= 0.0:
			_is_dodging = false
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	
	# 1. Locate active player target (ArcadeCar or PlayerCharacter)
	var target = _find_active_player()
	if not target or not is_instance_valid(target):
		return
	
	var target_pos: Vector3 = target.global_position
	if "car_pivot" in target and target.car_pivot:
		target_pos = target.car_pivot.global_position
	
	var dist_to_target: float = global_position.distance_to(target_pos)
	
	# Distance culling
	if dist_to_target > DESPAWN_DIST:
		queue_free()
		return
	
	# Tactical Combat Evasion: Detect oncoming speeding vehicles heading directly at officer
	if _dodge_cooldown <= 0.0 and target is ArcadeCar:
		var ac := target as ArcadeCar
		if ac.physics_sphere:
			var car_vel: Vector3 = ac.physics_sphere.linear_velocity
			var car_spd: float = car_vel.length()
			if car_spd > 5.5 and dist_to_target < 9.0 and dist_to_target > 1.2:
				var to_cop: Vector3 = (global_position - target_pos).normalized()
				if car_vel.normalized().dot(to_cop) > 0.60:
					_execute_tactical_dodge(car_vel.normalized())
					return
	
	# 2. Facing / Aiming Direction
	var flat_tgt := Vector3(target_pos.x, global_position.y, target_pos.z)
	var to_target := (flat_tgt - global_position).normalized()
	if to_target.length_squared() > 0.01:
		var target_rot_y: float = atan2(to_target.x, to_target.z)
		rotation.y = lerp_angle(rotation.y, target_rot_y + PI, delta * 8.0)
	
	# 3. Pursue Player
	var forward_dir := -global_transform.basis.z.normalized()
	if dist_to_target > min_shoot_dist:
		velocity.x = forward_dir.x * run_speed
		velocity.z = forward_dir.z * run_speed
		_anim_time += delta
		if leg_l and leg_r:
			leg_l.rotation.x = sin(_anim_time * 12.0) * 0.65
			leg_r.rotation.x = -sin(_anim_time * 12.0) * 0.65
	else:
		# Within point blank, hold position and shoot
		velocity.x = move_toward(velocity.x, 0.0, delta * 15.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 15.0)
		if leg_l and leg_r:
			leg_l.rotation.x = 0.0
			leg_r.rotation.x = 0.0
	
	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	
	# 4. Fire Service Weapon at Player Car / Runner
	if dist_to_target <= max_range and dist_to_target >= min_shoot_dist:
		_shoot_timer += delta
		if _shoot_timer >= shoot_interval:
			_shoot_timer = 0.0
			_fire_handgun(target, target_pos)

## Performs high-speed tactical combat dive sideways to evade vehicle collision
func _execute_tactical_dodge(incoming_heading: Vector3) -> void:
	_is_dodging = true
	_dodge_timer = 0.45
	_dodge_cooldown = randf_range(2.0, 3.5)
	_invuln_timer = 0.40
	
	var evade_side: float = 1.0 if randf() < 0.5 else -1.0
	var side_dir: Vector3 = incoming_heading.cross(Vector3.UP).normalized() * evade_side
	velocity = (side_dir * 13.5) + Vector3.UP * 2.8
	
	if visual_model:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(visual_model, "rotation:z", PI * 2.0 * evade_side, 0.42)
		tw.tween_property(visual_model, "position:y", 0.18, 0.21)
		tw.chain().tween_property(visual_model, "position:y", 0.0, 0.21)

func _find_active_player() -> Node3D:
	# Prioritize PlayerCharacter on foot
	var runners := get_tree().get_nodes_in_group("player_character")
	for r in runners:
		if is_instance_valid(r) and not r.is_queued_for_deletion():
			return r
	
	# Fallback to active driving ArcadeCar
	var cars := get_tree().get_nodes_in_group("player")
	for c in cars:
		if is_instance_valid(c) and not c.is_queued_for_deletion() and c is ArcadeCar and not (c as ArcadeCar).is_abandoned:
			return c
	return null

## Fires a dodgeable single bullet grain with glowing trail, fiery muzzle flash, and slight aim spread
func _fire_handgun(target: Node3D, target_pos: Vector3) -> void:
	if not is_inside_tree() or is_eliminated:
		return
	
	var forward_dir := -global_transform.basis.z.normalized()
	var muzzle_pos: Vector3 = global_position + Vector3(0.24, 0.52, 0.0) + (forward_dir * 0.42)
	
	# Gunshot Sound FX
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_gunshot"):
			sfx.play_gunshot()
	
	# 1. Fiery Muzzle Flash Light
	var flash := OmniLight3D.new()
	flash.light_color = Color("f39c12")
	flash.light_energy = 5.0
	flash.omni_range = 3.5
	flash.position = muzzle_pos
	get_parent().add_child(flash)
	
	# 2. Fiery Muzzle Flame Mesh Burst
	var flame := MeshInstance3D.new()
	var flame_sphere := SphereMesh.new()
	flame_sphere.radius = 0.12
	flame_sphere.height = 0.26
	flame.mesh = flame_sphere
	var f_mat := StandardMaterial3D.new()
	f_mat.albedo_color = Color("ff793f")
	f_mat.emission_enabled = true
	f_mat.emission = Color("ff5252")
	f_mat.emission_energy_multiplier = 4.5
	flame.material_override = f_mat
	flame.position = muzzle_pos
	flame.scale = Vector3(1.0, 1.0, 1.5)
	get_parent().add_child(flame)
	
	var tw := create_tween().set_parallel(true)
	tw.tween_property(flame, "scale", Vector3(2.2, 2.2, 2.8), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(flame, "transparency", 1.0, 0.07)
	tw.chain().tween_callback(func():
		if is_instance_valid(flash): flash.queue_free()
		if is_instance_valid(flame): flame.queue_free()
	)
	
	# 3. Instantiate Dodgeable Physical Bullet Grain Projectile
	var BulletScript = load("res://scripts/world/bullet_projectile.gd")
	if not BulletScript:
		return
	
	var bullet: Area3D = BulletScript.new()
	var aim_tgt: Vector3 = target_pos + Vector3(0.0, 0.35, 0.0)
	var raw_dir := (aim_tgt - muzzle_pos).normalized()
	
	# Human inaccuracy spread: ±2.5° angle variation so bullet is not robotic laser
	var spread := Vector3(randf_range(-0.045, 0.045), randf_range(-0.025, 0.035), randf_range(-0.045, 0.045))
	var bullet_dir := (raw_dir + spread).normalized()
	
	bullet.direction = bullet_dir
	bullet.speed = 26.5 # Dodgeable projectile speed (can swerve or move away)
	bullet.damage = bullet_damage
	bullet.shooter = self
	
	var p_parent: Node = get_parent() if get_parent() else (get_tree().root if get_tree() else null)
	if p_parent:
		p_parent.add_child(bullet)
		bullet.global_position = muzzle_pos
		bullet.look_at(muzzle_pos + bullet_dir, Vector3.UP)

## Vehicle running over the officer on foot - takes proportional speed damage rather than instant death!
func _on_vehicle_hit_area_body_entered(body: Node) -> void:
	if is_eliminated:
		return
	
	var hitting_vehicle: Node = null
	if body is RigidBody3D:
		hitting_vehicle = body
	elif body.get_parent() and body.get_parent() is ArcadeCar:
		hitting_vehicle = body.get_parent()
	elif body is ArcadeCar:
		hitting_vehicle = body
	
	if hitting_vehicle:
		var speed: float = 0.0
		var vel: Vector3 = Vector3.ZERO
		if hitting_vehicle is RigidBody3D:
			vel = (hitting_vehicle as RigidBody3D).linear_velocity
			speed = vel.length()
		elif hitting_vehicle is ArcadeCar and (hitting_vehicle as ArcadeCar).physics_sphere:
			vel = (hitting_vehicle as ArcadeCar).physics_sphere.linear_velocity
			speed = vel.length()
		
		# Low-speed bump (< 2.0 m/s) does not hurt officer
		if speed >= 2.0:
			# Invulnerability grace protects against rapid low/medium grazes, but high-speed direct ram (> 9.0 m/s) breaks through
			if _invuln_timer > 0.0 and speed < 9.0:
				return
			var knock_dir := (vel.normalized() + Vector3.UP * 0.45).normalized()
			var hit_dmg: float = speed * 8.5 # High-speed ram (>10 m/s) eliminates cop; lower speed deals proportional damage
			velocity = knock_dir * clampf(speed * 1.6, 3.5, 16.0)
			take_damage(hit_dmg)
			if current_hp <= 0.0:
				eliminate("💥 COP RUN OVER!", knock_dir)
			else:
				# Non-lethal hit: Stumble & Roll Recovery with invulnerability grace!
				_invuln_timer = 0.65
				if visual_model:
					var r_tw := create_tween()
					r_tw.tween_property(visual_model, "rotation:x", 0.7, 0.14)
					r_tw.tween_property(visual_model, "rotation:x", 0.0, 0.22)
				if has_node("/root/SoundFX"):
					var sfx = get_node("/root/SoundFX")
					if sfx.has_method("play_ui_click"):
						sfx.play_ui_click()

func take_damage(amount: float) -> void:
	if is_eliminated:
		return
	current_hp -= amount
	if has_node("/root/BrawlUITheme"):
		get_node("/root/BrawlUITheme").flash_white(visual_model if visual_model else self, 0.09)
	if current_hp <= 0.0:
		eliminate("💀 COP DOWN!", Vector3.UP)

## Eliminates officer with cartoon ragdoll spin, cash drop, and floating notification
func eliminate(reason: String, knockback_dir: Vector3 = Vector3.UP) -> void:
	if is_eliminated:
		return
	is_eliminated = true
	officer_eliminated.emit(self)
	
	# Disable collisions
	collision_layer = 0
	collision_mask = 0
	
	# Sound FX
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_ui_click"):
			sfx.play_ui_click()
	
	# Floating notification & Rewards
	if is_inside_tree():
		var hud = get_tree().root.find_child("TouchHUD", true, false)
		if hud and hud.has_method("spawn_floating_text"):
			hud.spawn_floating_text(global_position + Vector3.UP * 1.4, "+$100 " + reason, Color("f1c40f"), 1.3)
	
	# Award Cash & Score
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").add_cash(100)
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		if wm.has_method("add_score"):
			wm.add_score(150)
	
	# Cartoon Ragdoll Launch & Spin
	var tw := create_tween().set_parallel(true)
	var fling_pos := global_position + knockback_dir.normalized() * 5.0 + Vector3.UP * 4.0
	tw.tween_property(self, "global_position", fling_pos, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation:x", randf_range(6.0, 14.0), 0.65)
	tw.tween_property(self, "rotation:y", randf_range(6.0, 14.0), 0.65)
	tw.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.65)
	tw.chain().tween_callback(queue_free)
