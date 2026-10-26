class_name FlamingStuntRing
extends Node3D

## Phase 10: Flaming Stunt Rings
## Spawns glowing orange TorusMesh rings above bridge jumps and park fountain ramps.
## Driving through triggers a 0.4s slow-mo barrel-roll/pitch spin, awards +500 points,
## refills 100% of the active gadget cooldown, and grants a 2.0s nitro burst.

signal ring_passed(car: ArcadeCar)

var is_active: bool = true
var _cooldown_timer: float = 0.0

@onready var torus_mesh: MeshInstance3D = get_node_or_null("TorusMesh")
@onready var trigger_area: Area3D = get_node_or_null("TriggerArea")

func _ready() -> void:
	add_to_group("stunt_rings")
	_build_visuals_if_missing()
	_setup_trigger_area()

func _build_visuals_if_missing() -> void:
	if not torus_mesh:
		torus_mesh = MeshInstance3D.new()
		torus_mesh.name = "TorusMesh"
		var torus := TorusMesh.new()
		torus.inner_radius = 2.8
		torus.outer_radius = 3.2
		torus.rings = 24
		torus.ring_segments = 16
		torus_mesh.mesh = torus
		
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("ff6b1a")
		mat.emission_enabled = true
		mat.emission = Color("ff9f43")
		mat.emission_energy_multiplier = 4.0
		mat.roughness = 0.2
		torus_mesh.material_override = mat
		add_child(torus_mesh)
	
	# Stand vertically like an aerial ring
	torus_mesh.rotation_degrees.x = 90.0
	
	# Add flame particle ring effect
	var fire_particles := GPUParticles3D.new()
	fire_particles.name = "FireParticles"
	fire_particles.amount = 32
	fire_particles.lifetime = 0.6
	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	p_mat.emission_ring_radius = 3.0
	p_mat.emission_ring_inner_radius = 2.8
	p_mat.direction = Vector3.UP
	p_mat.initial_velocity_min = 1.0
	p_mat.initial_velocity_max = 2.5
	p_mat.color = Color("ff9f43")
	fire_particles.process_material = p_mat
	
	var pass_mesh := SphereMesh.new()
	pass_mesh.radius = 0.18
	pass_mesh.height = 0.36
	var fire_box_mat := StandardMaterial3D.new()
	fire_box_mat.albedo_color = Color("ff5e3a")
	fire_box_mat.emission_enabled = true
	fire_box_mat.emission = Color("ff9f43")
	fire_box_mat.emission_energy_multiplier = 3.0
	pass_mesh.material = fire_box_mat
	fire_particles.draw_pass_1 = pass_mesh
	add_child(fire_particles)

func _setup_trigger_area() -> void:
	if not trigger_area:
		trigger_area = Area3D.new()
		trigger_area.name = "TriggerArea"
		trigger_area.collision_layer = 0
		trigger_area.collision_mask = 2 # PlayerCar
		
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 3.2
		cyl.height = 1.8
		cs.shape = cyl
		cs.rotation_degrees.x = 90.0
		trigger_area.add_child(cs)
		add_child(trigger_area)
	
	if not trigger_area.body_entered.is_connected(_on_body_entered):
		trigger_area.body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			is_active = true
			if torus_mesh and torus_mesh.material_override:
				(torus_mesh.material_override as StandardMaterial3D).emission_energy_multiplier = 4.0

func _on_body_entered(body: Node) -> void:
	if not is_active:
		return
	
	var car: ArcadeCar = null
	if body.get_parent() and body.get_parent() is ArcadeCar:
		car = body.get_parent() as ArcadeCar
	elif body is ArcadeCar:
		car = body as ArcadeCar
	
	if car and is_instance_valid(car):
		trigger_stunt(car)

## Triggers the stunt ring rewards & cinematic slow-mo rotation
func trigger_stunt(car: ArcadeCar) -> void:
	is_active = false
	_cooldown_timer = 3.0
	
	if torus_mesh and torus_mesh.material_override:
		(torus_mesh.material_override as StandardMaterial3D).emission_energy_multiplier = 0.8
	
	# 0.4s slow-mo cinematic barrel-roll/pitch spin on CarPivot
	if car.car_pivot:
		var tw := car.create_tween()
		tw.tween_property(car.car_pivot, "rotation:z", car.car_pivot.rotation.z + TAU, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Refill 100% of Car Gadget cooldown
	if "gadget_system" in car and car.gadget_system:
		car.gadget_system.cooldown = 0.0
		car.gadget_system.cooldown_updated.emit(0.0, car.gadget_system.get_effective_max_cooldown())
	
	var hud := get_tree().root.find_child("TouchHUD", true, false)
	if hud and "gadget_cooldown" in hud:
		hud.gadget_cooldown = 0.0
		if "cooldown_overlay" in hud and hud.cooldown_overlay:
			hud.cooldown_overlay.visible = false
		if "gadget_button" in hud and hud.gadget_button:
			hud.gadget_button.disabled = false
	
	# Grant 2.0s Nitro burst
	car.apply_powerup(0, 2.0)
	
	# Award +500 Stunt Ring Points
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		if wm and wm.has_method("add_score"):
			wm.add_score(500)
	
	# Procedural Audio & Floating text
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_star_up()
	
	if hud and hud.has_method("spawn_floating_text"):
		hud.spawn_floating_text(global_position + Vector3.UP * 1.0, "+500 STUNT RING!", Color("ff9f43"), 1.3)
	
	ring_passed.emit(car)
