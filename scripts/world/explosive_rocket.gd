class_name ExplosiveRocket
extends Area3D

const ExplosionFX = preload("res://scripts/world/explosion_fx.gd")

## High-Velocity Explosive Rocket fired by Tank vehicles.
## Blasts forward, tracks trajectory, and detonates violently on impact with
## terrain, buildings, police cars, and enemies with heavy radial knockback.

@export var speed: float = 40.0
@export var damage: float = 160.0
@export var blast_radius: float = 7.0
@export var blast_impulse: float = 28.0

var direction: Vector3 = Vector3.FORWARD
var shooter: Node = null
var _lifetime: float = 3.5
var _is_detonated: bool = false

var _trail_particles: GPUParticles3D = null
var _mesh_inst: Node3D = null

func _ready() -> void:
	collision_layer = 0
	# Mask 1 (Ground), 2 (Player), 4 (Police), 8 (Buildings), 16 (Props/Traffic)
	collision_mask = 1 | 2 | 4 | 8 | 16
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	_build_visuals()

func _build_visuals() -> void:
	_mesh_inst = Node3D.new()
	_mesh_inst.name = "RocketMesh"
	add_child(_mesh_inst)
	
	# 1. Main Missile Body (Cylinder)
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.12
	cyl.height = 0.9
	body.mesh = cyl
	body.rotation.x = deg_to_rad(90.0)
	
	var mat_body := StandardMaterial3D.new()
	mat_body.albedo_color = Color("2d3436") # Dark charcoal military coating
	mat_body.roughness = 0.3
	body.material_override = mat_body
	_mesh_inst.add_child(body)
	
	# 2. Explosive Warhead (Cone)
	var cone := MeshInstance3D.new()
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 0.14
	cone_mesh.height = 0.35
	cone.mesh = cone_mesh
	cone.rotation.x = deg_to_rad(90.0)
	cone.position = Vector3(0, 0, -0.6)
	
	var mat_warhead := StandardMaterial3D.new()
	mat_warhead.albedo_color = Color("d63031") # Red explosive hazard tip
	mat_warhead.emission_enabled = true
	mat_warhead.emission = Color("e17055")
	mat_warhead.emission_energy_multiplier = 1.8
	cone.material_override = mat_warhead
	_mesh_inst.add_child(cone)
	
	# 3. Stabilizing Fins
	for i in range(4):
		var fin := MeshInstance3D.new()
		var fin_mesh := BoxMesh.new()
		fin_mesh.size = Vector3(0.04, 0.22, 0.18)
		fin.mesh = fin_mesh
		fin.rotation.z = deg_to_rad(float(i) * 90.0)
		fin.position = Vector3(0, 0, 0.35)
		fin.material_override = mat_body
		_mesh_inst.add_child(fin)
	
	# 4. Engine Flame Glow
	var flame := OmniLight3D.new()
	flame.light_color = Color("fdcb6e")
	flame.light_energy = 3.5
	flame.omni_range = 3.0
	flame.position = Vector3(0, 0, 0.5)
	add_child(flame)
	
	# 5. Collision Shape
	var cs := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.4
	cs.shape = sphere_shape
	add_child(cs)

func _physics_process(delta: float) -> void:
	if _is_detonated:
		return
	
	_lifetime -= delta
	if _lifetime <= 0.0:
		detonate()
		return
	
	# Move in forward heading
	var step: Vector3 = direction * speed * delta
	global_position += step

func _on_body_entered(body: Node) -> void:
	if _is_detonated or body == shooter or (shooter and body == shooter.get_parent()):
		return
	detonate()

func _on_area_entered(area: Area3D) -> void:
	if _is_detonated or area == shooter or (shooter and area == shooter.get_parent()):
		return
	detonate()

## Detonates the rocket with a massive fiery explosion, radial damage, and blast shockwave
func detonate() -> void:
	if _is_detonated:
		return
	_is_detonated = true
	
	var blast_pos: Vector3 = global_position
	
	# Hide missile body
	if _mesh_inst and is_instance_valid(_mesh_inst):
		_mesh_inst.visible = false
	
	# Sound Effect
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_explosion"):
			sfx.play_explosion()
	
	# Screen Trauma
	if is_inside_tree():
		var cam_rig = get_tree().root.find_child("CameraRig", true, false)
		if cam_rig and cam_rig.has_method("add_trauma"):
			cam_rig.add_trauma(0.65)
	
	# Floating notification
	if is_inside_tree():
		var hud = get_tree().root.find_child("TouchHUD", true, false)
		if hud and hud.has_method("spawn_floating_text"):
			hud.spawn_floating_text(blast_pos + Vector3.UP * 1.5, "💥 ROCKET BLAST!", Color("e17055"), 1.25)
	
	# Visual Explosion FX
	if is_inside_tree() and get_parent():
		ExplosionFX.spawn(get_parent(), blast_pos, 1.35, true)
	else:
		_spawn_blast_visuals(blast_pos)
	
	# Apply Radial Damage & Blast Impulses
	_apply_blast_damage_and_forces(blast_pos)
	
	# Cleanup
	get_tree().create_timer(0.6).timeout.connect(queue_free)

func _spawn_blast_visuals(pos: Vector3) -> void:
	if not is_inside_tree():
		return
	
	# 1. Fireball Sphere
	var fireball := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.2
	sph.height = 2.4
	fireball.mesh = sph
	
	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color = Color("e17055")
	fire_mat.emission_enabled = true
	fire_mat.emission = Color("f39c12")
	fire_mat.emission_energy_multiplier = 4.0
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fireball.material_override = fire_mat
	fireball.position = pos
	get_parent().add_child(fireball)
	
	# 2. Flash Light
	var light := OmniLight3D.new()
	light.light_color = Color("f39c12")
	light.light_energy = 8.0
	light.omni_range = 10.0
	light.position = pos
	get_parent().add_child(light)
	
	# Animate fireball expansion and fade
	var tw := create_tween().set_parallel(true)
	tw.tween_property(fireball, "scale", Vector3(3.8, 3.8, 3.8), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(fireball, "transparency", 1.0, 0.35)
	tw.tween_property(light, "light_energy", 0.0, 0.35)
	tw.chain().tween_callback(func():
		if is_instance_valid(fireball): fireball.queue_free()
		if is_instance_valid(light): light.queue_free()
	)

func _apply_blast_damage_and_forces(pos: Vector3) -> void:
	if not is_inside_tree():
		return
	
	# 1. Damage Police Cars
	var cops := get_tree().get_nodes_in_group("police_units")
	for cop in cops:
		if is_instance_valid(cop) and cop is PoliceCar and not (cop as PoliceCar).is_wrecked:
			var pc := cop as PoliceCar
			var cop_pos: Vector3 = pc.physics_sphere.global_position if pc.physics_sphere else pc.global_position
			var dist := pos.distance_to(cop_pos)
			if dist <= blast_radius:
				var factor: float = clampf(1.0 - (dist / blast_radius), 0.25, 1.0)
				pc.take_damage(damage * factor)
				var push_dir: Vector3 = (cop_pos - pos).normalized()
				push_dir.y += 0.45
				push_dir = push_dir.normalized()
				if pc.has_method("apply_knockback"):
					pc.apply_knockback(push_dir, blast_impulse * factor)
				elif pc.physics_sphere:
					pc.physics_sphere.apply_central_impulse(push_dir * (blast_impulse * factor * pc.physics_sphere.mass))
	
	# 2. Damage Police Officers on foot
	var officers := get_tree().get_nodes_in_group("police_officers")
	for off in officers:
		if is_instance_valid(off) and off is Node3D and not (off as Node3D).is_queued_for_deletion():
			var off_pos: Vector3 = (off as Node3D).global_position
			var dist := pos.distance_to(off_pos)
			if dist <= blast_radius:
				if off.has_method("eliminate"):
					var blast_dir: Vector3 = (off_pos - pos).normalized()
					off.eliminate("💥 ROCKET DETONATION!", blast_dir)
				elif off.has_method("take_damage"):
					off.take_damage(damage)
	
	# 3. Damage NPC Traffic
	var npcs := get_tree().get_nodes_in_group("npc_traffic")
	for npc in npcs:
		if is_instance_valid(npc) and npc is RigidBody3D:
			var rb := npc as RigidBody3D
			var dist := pos.distance_to(rb.global_position)
			if dist <= blast_radius:
				var factor: float = clampf(1.0 - (dist / blast_radius), 0.25, 1.0)
				var push_dir: Vector3 = (rb.global_position - pos).normalized()
				push_dir.y += 0.4
				push_dir = push_dir.normalized()
				if rb.has_method("apply_knockback"):
					rb.apply_knockback(push_dir, blast_impulse * factor)
				else:
					rb.apply_central_impulse(push_dir * (blast_impulse * factor * rb.mass))
				if rb.has_method("take_damage"):
					rb.take_damage(damage * factor)
	
	# 4. Damage Boss
	var boss_mode = get_tree().root.find_child("BossEscapeMode", true, false)
	if boss_mode and boss_mode.is_boss_mode and boss_mode.boss_node and is_instance_valid(boss_mode.boss_node):
		var b_pos: Vector3 = boss_mode.boss_node.global_position
		if boss_mode._spider_body and is_instance_valid(boss_mode._spider_body):
			b_pos = boss_mode._spider_body.global_position
		var b_dist := pos.distance_to(b_pos)
		if b_dist <= blast_radius + 2.5:
			var factor: float = clampf(1.0 - (b_dist / (blast_radius + 2.5)), 0.35, 1.0)
			boss_mode.damage_boss(damage * factor)
	
	# 5. Damage Smash Props
	var props := get_tree().get_nodes_in_group("smash_props")
	for prop in props:
		if is_instance_valid(prop) and prop is Node3D:
			var p3d := prop as Node3D
			var dist := pos.distance_to(p3d.global_position)
			if dist <= blast_radius:
				if prop.has_method("_smash"):
					prop._smash(self)
				elif prop is RigidBody3D:
					var rb := prop as RigidBody3D
					rb.freeze = false
					var push_dir := (rb.global_position - pos).normalized() + Vector3.UP * 0.35
					rb.apply_central_impulse(push_dir.normalized() * (blast_impulse * rb.mass))
	
	# 5. Damage Player Vehicle or On-Foot Fugitive (e.g. from Police Rhino Tank blast)
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p != shooter and (shooter == null or p != shooter.get_parent()):
			var p_pos: Vector3 = (p as Node3D).global_position
			if "car_pivot" in p and p.car_pivot:
				p_pos = p.car_pivot.global_position
			var dist := pos.distance_to(p_pos)
			if dist <= blast_radius:
				var factor: float = clampf(1.0 - (dist / blast_radius), 0.25, 1.0)
				if p.has_method("take_damage"):
					p.take_damage(damage * 0.45 * factor)
				var push_dir: Vector3 = (p_pos - pos).normalized()
				push_dir.y += 0.45
				push_dir = push_dir.normalized()
				if p.has_method("apply_knockback"):
					p.apply_knockback(push_dir, blast_impulse * 1.15 * factor)
				elif "physics_sphere" in p and p.physics_sphere:
					p.physics_sphere.apply_central_impulse(push_dir * (blast_impulse * factor * p.physics_sphere.mass))
	
	var runners := get_tree().get_nodes_in_group("player_character")
	for r in runners:
		if is_instance_valid(r) and r != shooter and not (r as Node3D).is_queued_for_deletion():
			var r_pos: Vector3 = (r as Node3D).global_position
			var dist := pos.distance_to(r_pos)
			if dist <= blast_radius:
				var factor: float = clampf(1.0 - (dist / blast_radius), 0.25, 1.0)
				if r.has_method("take_damage"):
					r.take_damage(damage * 0.35 * factor)
				var push_dir: Vector3 = (r_pos - pos).normalized()
				push_dir.y += 0.5
				push_dir = push_dir.normalized()
				if r.has_method("apply_knockback"):
					r.apply_knockback(push_dir, blast_impulse * 0.85 * factor)
				elif "velocity" in r:
					r.velocity += push_dir * (blast_impulse * 0.85 * factor)
