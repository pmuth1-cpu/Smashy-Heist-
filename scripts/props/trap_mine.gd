class_name TrapMine
extends Area3D

const ExplosionFX = preload("res://scripts/world/explosion_fx.gd")

## Police Tactical Landmine Hazard (Escape Road 3)
## Proximity mine that beeps on contact and detonates with a massive explosive blast wave.

var is_detonating: bool = false
var visual_model: Node3D = null
var _blink_timer: float = 0.0

func _ready() -> void:
	add_to_group("police_hazards")
	collision_layer = 16 # Layer 5 SmashProps
	collision_mask = 2 | 4 | 8 | 16 # PlayerCar, Police, Buildings, NPCs/Character
	
	# Proximity cylinder shape (radius 1.6m)
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.6
	cyl.height = 0.8
	cs.shape = cyl
	cs.position = Vector3(0.0, 0.4, 0.0)
	add_child(cs)
	
	# Build 3D visual from VoxelAssetBuilder
	var vab = get_node_or_null("/root/VoxelAssetBuilder")
	if vab and vab.has_method("build_trap_mine_visual"):
		visual_model = vab.build_trap_mine_visual()
		add_child(visual_model)
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_detonating:
		return
	_blink_timer += delta
	var beacon = find_child("MineBeacon", true, false) as OmniLight3D
	if beacon:
		beacon.visible = fmod(_blink_timer, 0.40) < 0.20

func _on_body_entered(body: Node3D) -> void:
	if is_detonating:
		return
	
	# Ignore ground static body
	if body is StaticBody3D and body.collision_layer == 1:
		return
	
	is_detonating = true
	_arm_and_detonate()

func _arm_and_detonate() -> void:
	# Rapid warning flash before explosion
	var beacon = find_child("MineBeacon", true, false) as OmniLight3D
	if beacon:
		beacon.light_color = Color("ff4757")
		beacon.light_energy = 5.0
		beacon.visible = true
	
	# 0.22s dramatic delay
	await get_tree().create_timer(0.22).timeout
	if not is_inside_tree():
		return
	
	_explode()

func _explode() -> void:
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		sfx.play_explosion()
	
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		if wm.has_method("hit_stop"):
			wm.hit_stop(0.06)
	
	# Screen trauma
	var cam_rig = get_tree().root.find_child("CameraRig", true, false)
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.65)
	
	# High-Impact Explosion FX
	if is_inside_tree() and get_parent():
		ExplosionFX.spawn(get_parent(), global_position, 1.45, true)
	
	# Blast Physics: 9.0m query
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var blast_sphere := SphereShape3D.new()
	blast_sphere.radius = 9.0
	query.shape = blast_sphere
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 2 | 4 | 8 | 16
	
	var results := space.intersect_shape(query, 32)
	for hit in results:
		var collider: Object = hit.get("collider")
		if collider is RigidBody3D:
			var rb := collider as RigidBody3D
			var dir := (rb.global_position - global_position).normalized()
			dir.y = maxf(dir.y, 0.55)
			dir = dir.normalized()
			var dist := (rb.global_position - global_position).length()
			var factor := clampf(1.0 - (dist / 9.0), 0.25, 1.0)
			
			var parent_node = rb.get_parent()
			if parent_node and parent_node.has_method("apply_knockback"):
				parent_node.apply_knockback(dir, 34.0 * factor)
			elif rb.has_method("apply_knockback"):
				rb.apply_knockback(dir, 34.0 * factor)
			else:
				rb.apply_central_impulse(dir * (36.0 * factor * rb.mass))
				rb.apply_torque_impulse(Vector3(randf_range(-14, 14), randf_range(-14, 14), randf_range(-14, 14)))
			
			if rb.has_method("take_damage"):
				rb.take_damage(65.0 * factor)
			elif parent_node and parent_node.has_method("take_damage"):
				parent_node.take_damage(65.0 * factor)
		elif collider is CharacterBody3D:
			var char_body := collider as CharacterBody3D
			var dir := (char_body.global_position - global_position).normalized()
			dir.y = maxf(dir.y, 0.5)
			dir = dir.normalized()
			var dist := (char_body.global_position - global_position).length()
			var factor := clampf(1.0 - (dist / 9.0), 0.25, 1.0)
			
			if char_body.has_method("apply_knockback"):
				char_body.apply_knockback(dir, 22.0 * factor)
			else:
				char_body.velocity += dir * (20.0 * factor)
			
			if char_body.has_method("take_damage"):
				char_body.take_damage(50.0 * factor)
	
	queue_free()
