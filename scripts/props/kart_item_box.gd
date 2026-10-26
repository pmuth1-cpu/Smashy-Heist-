class_name KartItemBox
extends Area3D

## 3D Rainbow Crystal Question Item Box for Smashy Kart Grand Prix.
## Floats, rotates with a rainbow iridescent shine and glowing ground ring.
## When collected by a racer, awards a position-weighted item and respawns after 3 seconds.

signal item_box_collected(by_car: ArcadeCar)

@export var respawn_time: float = 3.0

var _is_available: bool = true
var _respawn_timer: float = 0.0

var _cube_pivot: Node3D = null
var _crystal_mesh: MeshInstance3D = null
var _inner_question_mesh: Label3D = null
var _ground_ring: MeshInstance3D = null
var _collision_shape: CollisionShape3D = null
var _rainbow_time: float = 0.0

func _ready() -> void:
	collision_layer = 16 # SmashProps layer
	collision_mask = 2 | 4 # PlayerCar & Police/Rivals
	add_to_group("kart_item_boxes")
	
	_build_visuals()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _build_visuals() -> void:
	_collision_shape = CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.6, 1.6, 1.6)
	_collision_shape.shape = box_shape
	_collision_shape.position = Vector3(0, 1.0, 0)
	add_child(_collision_shape)
	
	_cube_pivot = Node3D.new()
	_cube_pivot.name = "CubePivot"
	_cube_pivot.position = Vector3(0, 1.1, 0)
	add_child(_cube_pivot)
	
	# Rainbow Translucent Crystal Outer Box
	_crystal_mesh = MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(1.3, 1.3, 1.3)
	_crystal_mesh.mesh = bmesh
	
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.9, 0.2, 0.65)
	mat.roughness = 0.1
	mat.metallic = 0.4
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.8, 0.1)
	mat.emission_energy_multiplier = 0.8
	_crystal_mesh.material_override = mat
	_cube_pivot.add_child(_crystal_mesh)
	
	# Floating 3D Question Mark
	_inner_question_mesh = Label3D.new()
	_inner_question_mesh.text = "?"
	_inner_question_mesh.font_size = 96
	_inner_question_mesh.outline_size = 24
	_inner_question_mesh.modulate = Color.WHITE
	_inner_question_mesh.outline_modulate = Color("1e272e")
	_inner_question_mesh.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_inner_question_mesh.position = Vector3(0, 0, 0)
	_cube_pivot.add_child(_inner_question_mesh)
	
	# Glowing Rainbow Ground Ring
	_ground_ring = MeshInstance3D.new()
	var rmesh := TorusMesh.new()
	rmesh.inner_radius = 0.8
	rmesh.outer_radius = 1.0
	_ground_ring.mesh = rmesh
	_ground_ring.position = Vector3(0, 0.08, 0)
	
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color("f1c40f")
	_ground_ring.material_override = rmat
	add_child(_ground_ring)

func _process(delta: float) -> void:
	if not _is_available:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn_box()
		return
	
	_rainbow_time += delta * 2.0
	if _cube_pivot:
		_cube_pivot.rotation.y += delta * 2.2
		_cube_pivot.rotation.x = sin(_rainbow_time) * 0.2
		_cube_pivot.position.y = 1.1 + sin(_rainbow_time * 1.5) * 0.15
	
	# Shift Rainbow Color
	if _crystal_mesh and _crystal_mesh.material_override is StandardMaterial3D:
		var cmat := _crystal_mesh.material_override as StandardMaterial3D
		var hue := fposmod(_rainbow_time * 0.2, 1.0)
		var rainbow_col := Color.from_hsv(hue, 0.85, 1.0, 0.70)
		cmat.albedo_color = rainbow_col
		cmat.emission = rainbow_col
		if _ground_ring and _ground_ring.material_override is StandardMaterial3D:
			(_ground_ring.material_override as StandardMaterial3D).albedo_color = rainbow_col

func _on_body_entered(body: Node) -> void:
	_handle_pickup(body)

func _on_area_entered(area: Area3D) -> void:
	var parent_node := area.get_parent()
	if parent_node:
		_handle_pickup(parent_node)

func _handle_pickup(node: Node) -> void:
	if not _is_available:
		return
	
	# Find ArcadeCar
	var car: ArcadeCar = null
	if node is ArcadeCar:
		car = node as ArcadeCar
	elif node.get_parent() is ArcadeCar:
		car = node.get_parent() as ArcadeCar
	elif node.owner is ArcadeCar:
		car = node.owner as ArcadeCar
	
	if not car:
		# Check if body has a physics_sphere child whose owner is ArcadeCar
		if node is RigidBody3D and node.owner is ArcadeCar:
			car = node.owner as ArcadeCar
	
	if not car or car.is_abandoned:
		return
	
	_collect(car)

func _collect(car: ArcadeCar) -> void:
	_is_available = false
	_respawn_timer = respawn_time
	
	# Play Sound
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_powerup_pickup"):
			sfx.play_powerup_pickup()
		elif sfx.has_method("play_ui_click"):
			sfx.play_ui_click()
	
	# Burst Shards FX
	_spawn_rainbow_burst()
	
	# Hide Visuals & Collision
	if _cube_pivot:
		_cube_pivot.visible = false
	if _ground_ring:
		_ground_ring.visible = false
	if _collision_shape:
		_collision_shape.set_deferred("disabled", true)
	
	# Trigger Kart Item Roulette on car
	var kis: Node = car.get_node_or_null("KartItemSystem")
	if not kis:
		for child in car.get_children():
			if child is KartItemSystem:
				kis = child
				break
	if kis and kis.has_method("start_item_roulette"):
		var rank: int = 1
		if car.has_meta("kart_race_rank"):
			rank = int(car.get_meta("kart_race_rank"))
		kis.start_item_roulette(rank)
	elif car.has_method("start_kart_roulette"):
		car.start_kart_roulette()
	
	item_box_collected.emit(car)

func _respawn_box() -> void:
	_is_available = true
	if _cube_pivot:
		_cube_pivot.visible = true
		_cube_pivot.scale = Vector3.ZERO
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_cube_pivot, "scale", Vector3.ONE, 0.4)
	if _ground_ring:
		_ground_ring.visible = true
	if _collision_shape:
		_collision_shape.disabled = false

func _spawn_rainbow_burst() -> void:
	if not get_parent():
		return
	var burst := Node3D.new()
	get_parent().add_child(burst)
	burst.global_position = global_position + Vector3(0, 1.1, 0)
	
	var shard_mesh := BoxMesh.new()
	shard_mesh.size = Vector3(0.18, 0.18, 0.18)
	
	var tw := burst.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in range(12):
		var shard := MeshInstance3D.new()
		shard.mesh = shard_mesh
		var smat := StandardMaterial3D.new()
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.albedo_color = Color.from_hsv(float(i) / 12.0, 0.9, 1.0)
		shard.material_override = smat
		burst.add_child(shard)
		
		var phi := randf() * TAU
		var theta := randf() * PI
		var dir := Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi)).normalized()
		var target_pos := dir * randf_range(1.5, 3.2)
		tw.tween_property(shard, "position", target_pos, 0.45)
		tw.tween_property(shard, "scale", Vector3.ZERO, 0.45)
	
	tw.chain().tween_callback(burst.queue_free)
