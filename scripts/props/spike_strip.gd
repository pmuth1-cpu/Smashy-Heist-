class_name SpikeStrip
extends Area3D

## Police Tactical Spike Strip (Escape Road 3 Hazard)
## Punctures player tires on contact, cutting top speed by 40% and inducing wild fishtailing.

var is_triggered: bool = false
var visual_model: Node3D = null

func _ready() -> void:
	add_to_group("police_hazards")
	collision_layer = 16 # Layer 5 SmashProps
	collision_mask = 2 | 4 # PlayerCar (2), PoliceCar (4)
	
	# Add collision box shape (3.6m wide across lane)
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(3.6, 0.4, 0.6)
	cs.shape = box
	cs.position = Vector3(0.0, 0.2, 0.0)
	add_child(cs)
	
	# Build 3D visual from VoxelAssetBuilder
	var vab = get_node_or_null("/root/VoxelAssetBuilder")
	if vab and vab.has_method("build_spike_strip_visual"):
		visual_model = vab.build_spike_strip_visual()
		add_child(visual_model)
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if is_triggered:
		return
	
	var car: ArcadeCar = null
	if body is ArcadeCar:
		car = body as ArcadeCar
	elif body.get_parent() is ArcadeCar:
		car = body.get_parent() as ArcadeCar
	elif "physics_sphere" in body:
		var candidate = body.get_parent()
		if candidate and candidate is ArcadeCar:
			car = candidate as ArcadeCar
	
	if car and not car.driving_forces_frozen:
		is_triggered = true
		_puncture_car(car)

func _puncture_car(car: ArcadeCar) -> void:
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_spike_puncture"):
			sfx.play_spike_puncture()
	
	# Screen trauma shake
	var cam_rig = get_tree().root.find_child("CameraRig", true, false)
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.55)
	
	# HUD Notification
	var hud = get_tree().root.find_child("TouchHUD", true, false)
	if hud and hud.has_method("spawn_floating_text"):
		hud.spawn_floating_text(global_position + Vector3.UP, "⚠️ TIRES PUNCTURED!", Color("ff4757"), 1.3)
	
	# Apply tire puncture effect on ArcadeCar
	if car.has_method("puncture_tires"):
		car.puncture_tires(3.5)
	else:
		car.take_damage(20.0)
		if car.physics_sphere:
			car.physics_sphere.apply_torque_impulse(Vector3(0, randf_range(-18.0, 18.0), 0))
	
	# Fade and despawn strip
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
	tween.tween_callback(queue_free)
