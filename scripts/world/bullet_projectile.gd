class_name BulletProjectile
extends Area3D

## Single Bullet Grain Projectile for Police Foot Officers.
## Travels straight through the air with a glowing bullet grain,
## visible golden trail, and sparks. Can be dodged by moving away.
## Deals damage and triggers an arcade white damage flash on hit.

@export var speed: float = 27.0
@export var damage: float = 5.0
@export var lifetime: float = 2.2

var direction: Vector3 = Vector3.FORWARD
var shooter: Node = null
var _time_alive: float = 0.0
var _is_impacted: bool = false

var _grain_mesh: MeshInstance3D = null
var _trail_mesh: MeshInstance3D = null

func _ready() -> void:
	collision_layer = 0
	# Mask 1 (Ground), 2 (Player vehicle/character), 8 (Buildings), 16 (NPC traffic/Props)
	collision_mask = 1 | 2 | 8 | 16
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	_build_bullet_visuals()

func _build_bullet_visuals() -> void:
	# 1. Glowing Bullet Grain (Capsule / Cylinder)
	_grain_mesh = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.05
	cap.height = 0.22
	_grain_mesh.mesh = cap
	_grain_mesh.rotation.x = deg_to_rad(90.0)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("f1c40f") # Bright golden yellow
	mat.emission_enabled = true
	mat.emission = Color("ffa502")
	mat.emission_energy_multiplier = 4.5
	_grain_mesh.material_override = mat
	add_child(_grain_mesh)
	
	# 2. Glowing Trail Beam behind the bullet grain
	_trail_mesh = MeshInstance3D.new()
	var trail_cyl := CylinderMesh.new()
	trail_cyl.top_radius = 0.015
	trail_cyl.bottom_radius = 0.04
	trail_cyl.height = 0.85
	_trail_mesh.mesh = trail_cyl
	_trail_mesh.rotation.x = deg_to_rad(90.0)
	_trail_mesh.position = Vector3(0.0, 0.0, 0.45)
	
	var trail_mat := StandardMaterial3D.new()
	trail_mat.albedo_color = Color("ffa502")
	trail_mat.emission_enabled = true
	trail_mat.emission = Color("ff793f")
	trail_mat.emission_energy_multiplier = 3.0
	trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_mat.albedo_color.a = 0.65
	_trail_mesh.material_override = trail_mat
	add_child(_trail_mesh)
	
	# 3. Subtle Point Light
	var light := OmniLight3D.new()
	light.light_color = Color("f1c40f")
	light.light_energy = 2.0
	light.omni_range = 2.0
	add_child(light)
	
	# 4. Collision Shape
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.22
	cs.shape = sph
	add_child(cs)

func _physics_process(delta: float) -> void:
	if _is_impacted:
		return
	
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()
		return
	
	# Move straight forward
	global_position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	if _is_impacted or body == shooter or (shooter and body == shooter.get_parent()):
		return
	_impact(body)

func _on_area_entered(area: Area3D) -> void:
	if _is_impacted or area == shooter or (shooter and area == shooter.get_parent()):
		return
	_impact(area)

func _impact(hit_target: Node) -> void:
	if _is_impacted:
		return
	_is_impacted = true
	
	var hit_pos: Vector3 = global_position
	
	# Apply damage and white flash to hit target
	if hit_target:
		if hit_target.has_method("take_damage"):
			hit_target.take_damage(damage)
		elif hit_target.get_parent() and hit_target.get_parent().has_method("take_damage"):
			hit_target.get_parent().take_damage(damage)
		
		# White damage flash
		var target_node: Node3D = hit_target as Node3D
		if not target_node and hit_target.get_parent() is Node3D:
			target_node = hit_target.get_parent() as Node3D
		if target_node and has_node("/root/BrawlUITheme"):
			get_node("/root/BrawlUITheme").flash_white(target_node, 0.09)
	
	# Small camera shake if player was hit
	if hit_target and (hit_target.is_in_group("player") or hit_target.is_in_group("player_character")):
		if is_inside_tree():
			var cam_rig = get_tree().root.find_child("CameraRig", true, false)
			if cam_rig and cam_rig.has_method("add_trauma"):
				cam_rig.add_trauma(0.16)
	
	# Spawn impact spark puff
	_spawn_impact_sparks(hit_pos)
	queue_free()

func _spawn_impact_sparks(pos: Vector3) -> void:
	if not is_inside_tree():
		return
	var spark := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.12
	sph.height = 0.24
	spark.mesh = sph
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("f1c40f")
	mat.emission_enabled = true
	mat.emission = Color("ffa502")
	mat.emission_energy_multiplier = 4.0
	spark.material_override = mat
	spark.position = pos
	
	var p_node: Node = get_parent() if get_parent() else (get_tree().root if get_tree() else null)
	if p_node:
		p_node.add_child(spark)
		var tw := spark.create_tween()
		tw.tween_property(spark, "scale", Vector3(2.5, 2.5, 2.5), 0.10)
		tw.parallel().tween_property(spark, "transparency", 1.0, 0.10)
		tw.tween_callback(spark.queue_free)
