class_name SmashProp
extends RigidBody3D

enum PropType {
	HYDRANT,
	FENCE,
	STREETLAMP,
	FRUIT_CRATE,
	EXPLOSIVE_BARREL,
	HAY_BALE,
	RUSTIC_FENCE,
	RAIL_GATE,
	PUMPKIN,
	PLANT
}

signal prop_smashed(prop: SmashProp, prop_type: PropType, hit_position: Vector3)

@export var prop_type: PropType = PropType.HYDRANT:
	set(value):
		prop_type = value
		if is_inside_tree():
			_apply_prop_style()

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var hit_detector: Area3D = $HitDetector
@onready var hit_shape: CollisionShape3D = $HitDetector/CollisionShape3D
@onready var debris_burst: GPUParticles3D = $DebrisBurst

var base_points: int = 150
var trauma_amount: float = 0.25
var _is_smashed: bool = false

func _ready() -> void:
	# Layer 5: SmashProps (16), collides with Ground (1), PlayerCar (2), PoliceCar (4)
	collision_layer = 16
	collision_mask = 7
	
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	
	hit_detector.collision_layer = 0
	hit_detector.collision_mask = 6 # Layers 2 (PlayerCar) and 3 (PoliceCar)
	hit_detector.body_entered.connect(_on_hit_detector_body_entered)
	
	_apply_prop_style()

func _apply_prop_style() -> void:
	if not collision_shape or not mesh_instance:
		return
	
	# Remove any existing extra accessory children from previous styles
	for child in mesh_instance.get_children():
		child.queue_free()
	
	match prop_type:
		PropType.HYDRANT:
			base_points = 150
			trauma_amount = 0.25
			mass = 1.2
			_setup_hydrant()
		PropType.FENCE:
			base_points = 50
			trauma_amount = 0.15
			mass = 0.8
			_setup_fence()
		PropType.STREETLAMP:
			base_points = 200
			trauma_amount = 0.30
			mass = 2.0
			_setup_streetlamp()
		PropType.FRUIT_CRATE:
			base_points = 100
			trauma_amount = 0.20
			mass = 0.6
			_setup_fruit_crate()
		PropType.EXPLOSIVE_BARREL:
			base_points = 350
			trauma_amount = 0.65
			mass = 1.5
			_setup_explosive_barrel()
		PropType.HAY_BALE:
			base_points = 200
			trauma_amount = 0.15
			mass = 0.6
			_setup_hay_bale()
		PropType.RUSTIC_FENCE:
			base_points = 75
			trauma_amount = 0.15
			mass = 0.8
			_setup_rustic_fence()
		PropType.RAIL_GATE:
			base_points = 150
			trauma_amount = 0.20
			mass = 0.7
			_setup_rail_gate()
		PropType.PUMPKIN:
			base_points = 120
			trauma_amount = 0.20
			mass = 0.5
			_setup_pumpkin()
		PropType.PLANT:
			base_points = 80
			trauma_amount = 0.15
			mass = 0.4
			_setup_plant()

func _setup_hydrant() -> void:
	# Body: Red hydrant cylinder
	var box_size = Vector3(0.55, 0.85, 0.55)
	_set_collider_size(box_size)
	
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.24
	cyl.height = 0.85
	var red_mat = StandardMaterial3D.new()
	red_mat.albedo_color = Color(0.92, 0.18, 0.18)
	red_mat.roughness = 0.4
	cyl.material = red_mat
	mesh_instance.mesh = cyl
	mesh_instance.position = Vector3(0.0, 0.425, 0.0)
	
	# Nozzle accessories
	var nozzle = MeshInstance3D.new()
	var n_box = BoxMesh.new()
	n_box.size = Vector3(0.7, 0.18, 0.18)
	var yellow_mat = StandardMaterial3D.new()
	yellow_mat.albedo_color = Color(0.95, 0.78, 0.15)
	n_box.material = yellow_mat
	nozzle.mesh = n_box
	nozzle.position = Vector3(0.0, 0.05, 0.0)
	mesh_instance.add_child(nozzle)
	
	# Cyan water geyser debris
	_setup_particles(Color(0.2, 0.75, 0.95, 0.8), Vector3(0, 1, 0), 18.0, 5.0, 8.5, 36)

func _setup_fence() -> void:
	var box_size = Vector3(2.4, 0.85, 0.25)
	_set_collider_size(box_size)
	
	var box = BoxMesh.new()
	box.size = box_size
	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.92, 0.90, 0.85) # White picket
	wood_mat.roughness = 0.6
	box.material = wood_mat
	mesh_instance.mesh = box
	mesh_instance.position = Vector3(0.0, 0.425, 0.0)
	
	# Wood splinters
	_setup_particles(Color(0.85, 0.78, 0.65, 0.9), Vector3(0, 0.8, 0.5), 35.0, 3.5, 6.0, 24)

func _setup_streetlamp() -> void:
	var box_size = Vector3(0.5, 4.2, 0.5)
	_set_collider_size(box_size)
	
	# Metal pole
	var pole = CylinderMesh.new()
	pole.top_radius = 0.1
	pole.bottom_radius = 0.14
	pole.height = 4.2
	var pole_mat = StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.35, 0.38, 0.42)
	pole_mat.metallic = 0.4
	pole_mat.roughness = 0.4
	pole.material = pole_mat
	mesh_instance.mesh = pole
	mesh_instance.position = Vector3(0.0, 2.1, 0.0)
	
	# Lamp fixture
	var lamp = MeshInstance3D.new()
	var l_box = BoxMesh.new()
	l_box.size = Vector3(0.7, 0.35, 0.7)
	var glow_mat = StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.95, 0.6)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.9, 0.4)
	glow_mat.emission_energy_multiplier = 2.0
	l_box.material = glow_mat
	lamp.mesh = l_box
	lamp.position = Vector3(0.0, 2.0, 0.0)
	mesh_instance.add_child(lamp)
	
	# Electric spark debris
	_setup_particles(Color(1.0, 0.92, 0.3, 0.95), Vector3(0, 0.5, 0), 45.0, 4.0, 7.5, 30)

func _setup_fruit_crate() -> void:
	var box_size = Vector3(1.1, 0.9, 1.1)
	_set_collider_size(box_size)
	
	var box = BoxMesh.new()
	box.size = box_size
	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.68, 0.48, 0.25)
	wood_mat.roughness = 0.7
	box.material = wood_mat
	mesh_instance.mesh = box
	mesh_instance.position = Vector3(0.0, 0.45, 0.0)
	
	# Fruit topping
	var fruit = MeshInstance3D.new()
	var f_box = BoxMesh.new()
	f_box.size = Vector3(0.9, 0.25, 0.9)
	var f_mat = StandardMaterial3D.new()
	f_mat.albedo_color = Color(0.95, 0.45, 0.1) # Orange/apples
	f_box.material = f_mat
	fruit.mesh = f_box
	fruit.position = Vector3(0.0, 0.45, 0.0)
	mesh_instance.add_child(fruit)
	
	# Fruit chunk particles
	_setup_particles(Color(0.95, 0.4, 0.1, 0.9), Vector3(0, 0.8, 0.2), 40.0, 3.5, 6.5, 28)

func _setup_explosive_barrel() -> void:
	var box_size = Vector3(0.85, 1.25, 0.85)
	_set_collider_size(box_size)
	
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.38
	cyl.bottom_radius = 0.38
	cyl.height = 1.25
	var red_mat = StandardMaterial3D.new()
	red_mat.albedo_color = Color(0.85, 0.18, 0.15) # Hazard Red
	red_mat.roughness = 0.4
	cyl.material = red_mat
	mesh_instance.mesh = cyl
	mesh_instance.position = Vector3(0.0, 0.625, 0.0)
	
	# Yellow hazard ring
	var ring = MeshInstance3D.new()
	var r_cyl = CylinderMesh.new()
	r_cyl.top_radius = 0.39
	r_cyl.bottom_radius = 0.39
	r_cyl.height = 0.3
	var yellow_mat = StandardMaterial3D.new()
	yellow_mat.albedo_color = Color(0.95, 0.80, 0.1)
	r_cyl.material = yellow_mat
	ring.mesh = r_cyl
	ring.position = Vector3(0.0, 0.0, 0.0)
	mesh_instance.add_child(ring)
	
	# Fireball and smoke burst
	_setup_particles(Color(1.0, 0.45, 0.1, 0.95), Vector3(0, 1, 0), 60.0, 6.0, 12.0, 48)

func _setup_hay_bale() -> void:
	var box_size = Vector3(1.3, 0.9, 1.8)
	_set_collider_size(box_size)
	
	var box = BoxMesh.new()
	box.size = box_size
	var straw_mat = StandardMaterial3D.new()
	straw_mat.albedo_color = Color("fed330") # Golden yellow straw
	straw_mat.roughness = 0.8
	box.material = straw_mat
	mesh_instance.mesh = box
	mesh_instance.position = Vector3(0.0, 0.45, 0.0)
	
	# Twine ties
	for tz in [-0.45, 0.45]:
		var twine = MeshInstance3D.new()
		var t_mesh = BoxMesh.new()
		t_mesh.size = Vector3(1.32, 0.92, 0.08)
		var t_mat = StandardMaterial3D.new()
		t_mat.albedo_color = Color("d2dae2")
		t_mesh.material = t_mat
		twine.mesh = t_mesh
		twine.position = Vector3(0.0, 0.0, tz)
		mesh_instance.add_child(twine)
	
	_setup_particles(Color("fed330"), Vector3(0, 1, 0), 45.0, 4.0, 7.5, 32)

func _setup_rustic_fence() -> void:
	var box_size = Vector3(2.6, 0.95, 0.25)
	_set_collider_size(box_size)
	
	var box = BoxMesh.new()
	box.size = Vector3(2.6, 0.22, 0.15)
	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color("8c5b36") # Weathered rustic timber
	wood_mat.roughness = 0.75
	box.material = wood_mat
	mesh_instance.mesh = box
	mesh_instance.position = Vector3(0.0, 0.65, 0.0)
	
	# Lower split rail
	var rail2 = MeshInstance3D.new()
	var r2_mesh = BoxMesh.new()
	r2_mesh.size = Vector3(2.6, 0.20, 0.15)
	r2_mesh.material = wood_mat
	rail2.mesh = r2_mesh
	rail2.position = Vector3(0.0, -0.32, 0.0)
	mesh_instance.add_child(rail2)
	
	# Fence vertical posts
	for px in [-1.15, 1.15]:
		var post = MeshInstance3D.new()
		var p_mesh = BoxMesh.new()
		p_mesh.size = Vector3(0.24, 1.05, 0.24)
		p_mesh.material = wood_mat
		post.mesh = p_mesh
		post.position = Vector3(px, -0.12, 0.0)
		mesh_instance.add_child(post)
	
	_setup_particles(Color("8c5b36"), Vector3(0, 1, 0), 30.0, 3.5, 6.0, 24)

func _setup_rail_gate() -> void:
	var box_size = Vector3(3.6, 0.9, 0.3)
	_set_collider_size(box_size)
	
	# Striped Barrier Arm
	var arm = BoxMesh.new()
	arm.size = Vector3(3.4, 0.22, 0.12)
	var white_mat = StandardMaterial3D.new()
	white_mat.albedo_color = Color("f5f6fa")
	arm.material = white_mat
	mesh_instance.mesh = arm
	mesh_instance.position = Vector3(0.0, 0.85, 0.0)
	
	# Red stripes on arm
	for rx in [-1.2, -0.4, 0.4, 1.2]:
		var stripe = MeshInstance3D.new()
		var s_mesh = BoxMesh.new()
		s_mesh.size = Vector3(0.35, 0.24, 0.14)
		var red_mat = StandardMaterial3D.new()
		red_mat.albedo_color = Color("e74c3c")
		s_mesh.material = red_mat
		stripe.mesh = s_mesh
		stripe.position = Vector3(rx, 0.0, 0.0)
		mesh_instance.add_child(stripe)
	
	# Pivot post
	var post = MeshInstance3D.new()
	var p_mesh = BoxMesh.new()
	p_mesh.size = Vector3(0.4, 1.2, 0.4)
	var post_mat = StandardMaterial3D.new()
	post_mat.albedo_color = Color("2f3542")
	p_mesh.material = post_mat
	post.mesh = p_mesh
	post.position = Vector3(1.7, -0.25, 0.0)
	mesh_instance.add_child(post)
	
	_setup_particles(Color("e74c3c"), Vector3(0, 1, 0), 40.0, 4.0, 7.0, 24)

func _setup_pumpkin() -> void:
	var box_size = Vector3(0.9, 0.75, 0.9)
	_set_collider_size(box_size)
	
	# Central round pumpkin body
	var body_sphere = SphereMesh.new()
	body_sphere.radius = 0.44
	body_sphere.height = 0.68
	var pumpkin_mat = StandardMaterial3D.new()
	pumpkin_mat.albedo_color = Color(0.96, 0.48, 0.08) # Rich ripe pumpkin orange
	pumpkin_mat.roughness = 0.55
	body_sphere.material = pumpkin_mat
	mesh_instance.mesh = body_sphere
	mesh_instance.position = Vector3(0.0, 0.35, 0.0)
	
	# Ribbed lobes around pumpkin circumference
	var lobe_mat = StandardMaterial3D.new()
	lobe_mat.albedo_color = Color(0.88, 0.42, 0.06)
	lobe_mat.roughness = 0.55
	for angle_deg in [0.0, 45.0, 90.0, 135.0]:
		var lobe = MeshInstance3D.new()
		var l_mesh = BoxMesh.new()
		l_mesh.size = Vector3(0.24, 0.62, 0.88)
		l_mesh.material = lobe_mat
		lobe.mesh = l_mesh
		lobe.rotation_degrees = Vector3(0, angle_deg, 0)
		mesh_instance.add_child(lobe)
	
	# Curly green pumpkin stem on top
	var stem = MeshInstance3D.new()
	var s_mesh = CylinderMesh.new()
	s_mesh.top_radius = 0.04
	s_mesh.bottom_radius = 0.07
	s_mesh.height = 0.26
	var stem_mat = StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.20, 0.65, 0.22) # Fresh green stem
	stem_mat.roughness = 0.7
	s_mesh.material = stem_mat
	stem.mesh = s_mesh
	stem.position = Vector3(0.0, 0.42, 0.0)
	stem.rotation_degrees = Vector3(12.0, 0.0, 15.0)
	mesh_instance.add_child(stem)
	
	# Orange pulp & pumpkin seed debris particles
	_setup_particles(Color(0.98, 0.55, 0.1, 0.95), Vector3(0, 1, 0), 45.0, 4.0, 8.0, 30)

func _setup_plant() -> void:
	var box_size = Vector3(0.8, 1.15, 0.8)
	_set_collider_size(box_size)
	
	# Terracotta ceramic planter pot at base
	var pot = CylinderMesh.new()
	pot.top_radius = 0.35
	pot.bottom_radius = 0.25
	pot.height = 0.52
	var pot_mat = StandardMaterial3D.new()
	pot_mat.albedo_color = Color(0.78, 0.36, 0.20) # Terracotta clay
	pot_mat.roughness = 0.65
	pot.material = pot_mat
	mesh_instance.mesh = pot
	mesh_instance.position = Vector3(0.0, 0.26, 0.0)
	
	# Lush green leafy bush crown
	var bush = MeshInstance3D.new()
	var b_mesh = SphereMesh.new()
	b_mesh.radius = 0.42
	b_mesh.height = 0.68
	var leaf_mat = StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.18, 0.74, 0.26) # Vibrant plant leaves
	leaf_mat.roughness = 0.5
	b_mesh.material = leaf_mat
	bush.mesh = b_mesh
	bush.position = Vector3(0.0, 0.48, 0.0)
	mesh_instance.add_child(bush)
	
	# Colorful top blossom petals / leaf cluster
	var flower = MeshInstance3D.new()
	var f_mesh = BoxMesh.new()
	f_mesh.size = Vector3(0.35, 0.15, 0.35)
	var flower_mat = StandardMaterial3D.new()
	flower_mat.albedo_color = Color(0.96, 0.26, 0.45) # Bright blossom
	flower_mat.roughness = 0.4
	f_mesh.material = flower_mat
	flower.mesh = f_mesh
	flower.position = Vector3(0.0, 0.80, 0.0)
	mesh_instance.add_child(flower)
	
	# Green leaves & terracotta clay fragments debris particles
	_setup_particles(Color(0.25, 0.75, 0.3, 0.95), Vector3(0, 1, 0), 40.0, 3.5, 7.5, 28)

func _set_collider_size(size: Vector3) -> void:
	if not collision_shape.shape:
		collision_shape.shape = BoxShape3D.new()
	var box = collision_shape.shape as BoxShape3D
	box.size = size
	collision_shape.position = Vector3(0.0, size.y * 0.5, 0.0)
	
	if not hit_shape.shape:
		hit_shape.shape = BoxShape3D.new()
	var hit_box = hit_shape.shape as BoxShape3D
	# Area3D slightly larger than physical prop to detect approach hits
	hit_box.size = size + Vector3(0.4, 0.4, 0.4)
	hit_shape.position = Vector3(0.0, size.y * 0.5, 0.0)

func _setup_particles(color: Color, dir: Vector3, spread: float, vel_min: float, vel_max: float, count: int) -> void:
	if not debris_burst:
		return
	
	debris_burst.amount = count
	debris_burst.one_shot = true
	debris_burst.explosiveness = 0.95
	debris_burst.lifetime = 0.8
	
	var p_mat = ParticleProcessMaterial.new()
	p_mat.direction = dir
	p_mat.spread = spread
	p_mat.initial_velocity_min = vel_min
	p_mat.initial_velocity_max = vel_max
	p_mat.gravity = Vector3(0, -9.8, 0)
	p_mat.scale_min = 0.15
	p_mat.scale_max = 0.4
	p_mat.color = color
	debris_burst.process_material = p_mat
	
	var draw_box = BoxMesh.new()
	draw_box.size = Vector3(0.18, 0.18, 0.18)
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_box.material = m
	debris_burst.draw_pass_1 = draw_box

func _on_hit_detector_body_entered(body: Node3D) -> void:
	if _is_smashed:
		return
	_smash(body)

func _smash(hitting_body: Node3D) -> void:
	_is_smashed = true
	
	# 1. Unfreeze prop so it enters dynamic rigid body physics!
	freeze = false
	
	# 2. Compute impulse from hitting vehicle
	var car_vel := Vector3(0, 0, -12.0)
	if hitting_body is RigidBody3D:
		car_vel = hitting_body.linear_velocity
	elif "physics_sphere" in hitting_body and hitting_body.physics_sphere:
		car_vel = hitting_body.physics_sphere.linear_velocity
	elif hitting_body.get_parent() and "physics_sphere" in hitting_body.get_parent():
		car_vel = hitting_body.get_parent().physics_sphere.linear_velocity
	
	var push_dir = (car_vel.normalized() + Vector3(0.0, 0.65, 0.0)).normalized()
	var push_speed = maxf(car_vel.length() * 0.85, 12.0)
	apply_central_impulse(push_dir * (push_speed * mass))
	
	# Random high-velocity tumbling spin
	angular_velocity = Vector3(
		randf_range(-16.0, 16.0),
		randf_range(-16.0, 16.0),
		randf_range(-16.0, 16.0)
	)
	
	# 3. Trigger DebrisBurst
	if debris_burst:
		debris_burst.emitting = true
	
	# 4. Explosive Barrel: Radial knockback impulse to nearby bodies
	if prop_type == PropType.EXPLOSIVE_BARREL:
		_trigger_barrel_explosion()
	
	# 5. Emit signal and notify MainGame for Camera Shake and Combo Score
	prop_smashed.emit(self, prop_type, global_position)
	
	if is_inside_tree() and get_tree() and get_tree().current_scene:
		var main_scene = get_tree().current_scene
		if main_scene.has_method("register_prop_smash"):
			main_scene.register_prop_smash(self, hitting_body)
	
	# Disable hit detector so it only scores once
	hit_detector.set_deferred("monitoring", false)
	hit_detector.set_deferred("monitorable", false)
	
	# 6. Auto-despawn with shrink tween after 2.5 seconds
	var tween = create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.7)
	tween.tween_callback(queue_free)

func _trigger_barrel_explosion() -> void:
	var explosion_radius := 9.0
	var explosion_force := 32.0
	
	var space_state = get_world_3d().direct_space_state
	var shape_query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = explosion_radius
	shape_query.shape = sphere
	shape_query.transform = global_transform
	shape_query.collision_mask = 31 # All physics bodies
	
	var hits = space_state.intersect_shape(shape_query, 32)
	for hit in hits:
		var collider = hit.get("collider")
		if collider and collider != self and collider is RigidBody3D:
			var dir = collider.global_position - global_position
			var dist = dir.length()
			if dist < 0.1:
				dir = Vector3(0, 1, 0)
			else:
				dir = (dir.normalized() + Vector3.UP * 0.45).normalized()
			
			var factor = clampf(1.0 - (dist / explosion_radius), 0.2, 1.0)
			collider.apply_central_impulse(dir * (explosion_force * factor * collider.mass))
			
			# Chain reaction: if another SmashProp barrel, trigger it!
			if collider is SmashProp and collider.prop_type == PropType.EXPLOSIVE_BARREL and not collider._is_smashed:
				collider._smash(self)
