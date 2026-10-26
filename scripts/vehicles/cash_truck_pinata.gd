class_name CashTruckPinata
extends NPCTrafficCar

## Phase 10: Gold Bullion Armored Convoy ("CashTruckPinata")
## High-visibility armored cash truck painted metallic gold with a pulsing "💰 RAM ME!" billboard.
## Each time the player rams it, it bursts out 6 glowing physical gold coin blocks.

signal coins_burst(count: int, origin: Vector3)

var pinata_hits_remaining: int = 5
var _ram_cooldown: float = 0.0
var _billboard_label: Label3D = null

func _ready() -> void:
	npc_type = NPCType.DUMP_TRUCK # Chunky armored truck base
	super._ready()
	add_to_group("cash_truck_pinata")
	_apply_gold_pinata_visuals()
	_setup_ram_me_billboard()

func _apply_gold_pinata_visuals() -> void:
	# Bright gleaming metallic gold paint
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color("f1c40f") # Bright Gold
	gold_mat.metallic = 0.95
	gold_mat.roughness = 0.18
	gold_mat.emission_enabled = true
	gold_mat.emission = Color("f39c12")
	gold_mat.emission_energy_multiplier = 1.2
	
	for child in get_children():
		if child is Node3D and child.name == "VoxelNPCVisual":
			for part in child.get_children():
				if part is MeshInstance3D:
					part.material_override = gold_mat
		elif child is MeshInstance3D:
			child.material_override = gold_mat

func _setup_ram_me_billboard() -> void:
	_billboard_label = Label3D.new()
	_billboard_label.name = "RamMeBillboard"
	_billboard_label.text = "💰 RAM ME!"
	_billboard_label.font_size = 40
	_billboard_label.outline_size = 10
	_billboard_label.outline_modulate = Color("0d1117")
	_billboard_label.modulate = Color("f1c40f")
	_billboard_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_billboard_label.no_depth_test = true
	_billboard_label.position = Vector3(0.0, 3.2, 0.0)
	add_child(_billboard_label)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if _ram_cooldown > 0.0:
		_ram_cooldown -= delta
	
	# Pulse billboard scale
	if _billboard_label:
		var pulse: float = 1.0 + 0.18 * sin(Time.get_ticks_msec() * 0.007)
		_billboard_label.scale = Vector3(pulse, pulse, pulse)

func take_traffic_hit(rammer: Node3D, impact_velocity: Vector3 = Vector3.ZERO) -> void:
	if _ram_cooldown > 0.0:
		return
	_ram_cooldown = 0.6
	
	is_panicking = true
	panic_timer = 2.5
	traffic_crashed.emit(self, rammer)
	
	# Impulse
	var launch_dir := impact_velocity.normalized() if not impact_velocity.is_zero_approx() else Vector3(randf_range(-1, 1), 0.6, randf_range(-1, 1)).normalized()
	apply_central_impulse(launch_dir * 14.0 + Vector3.UP * 5.0)
	
	# Burst 6 physical glowing gold coins
	burst_gold_coins(6)
	
	pinata_hits_remaining -= 1
	if pinata_hits_remaining <= 0:
		_explode_pinata()

func burst_gold_coins(coin_count: int = 6) -> void:
	coins_burst.emit(coin_count, global_position)
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_smash_hit()
	
	var hud := get_tree().root.find_child("TouchHUD", true, false)
	if hud and hud.has_method("spawn_floating_text"):
		hud.spawn_floating_text(global_position + Vector3.UP * 1.5, "💰 COIN BURST!", Color("f1c40f"), 1.25)
	
	for i in range(coin_count):
		_spawn_single_coin()

func _spawn_single_coin() -> void:
	var coin := Area3D.new()
	coin.name = "GoldCoin"
	coin.add_to_group("gold_coins")
	coin.collision_layer = 0
	coin.collision_mask = 2 # PlayerCar
	
	# Visual gold block
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.55, 0.55)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("f1c40f")
	mat.metallic = 0.95
	mat.roughness = 0.15
	mat.emission_enabled = true
	mat.emission = Color("f39c12")
	mat.emission_energy_multiplier = 3.5
	mi.material_override = mat
	coin.add_child(mi)
	
	# Collider
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.65
	cs.shape = sph
	coin.add_child(cs)
	
	var spawn_pos: Vector3 = global_position + Vector3.UP * 1.2
	
	# Parent to world scene
	if get_parent():
		get_parent().add_child(coin)
	elif get_tree() and get_tree().root:
		get_tree().root.add_child(coin)
	
	coin.global_position = spawn_pos
	
	# Arc trajectory
	var arc_dir := Vector3(randf_range(-3.5, 3.5), randf_range(3.0, 5.5), randf_range(-3.5, 3.5))
	var target_pos := spawn_pos + arc_dir
	target_pos.y = maxf(0.35, target_pos.y * 0.2)
	
	var tw := coin.create_tween()
	tw.tween_property(coin, "global_position", target_pos, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Collection logic
	var collected: Dictionary = {"done": false}
	var collect_coin = func():
		if collected["done"]:
			return
		collected["done"] = true
		
		if has_node("/root/SaveManager"):
			var sm = get_node("/root/SaveManager")
			if sm and sm.has_method("add_cash"):
				sm.add_cash(25)
		
		if has_node("/root/WantedManager"):
			var wm = get_node("/root/WantedManager")
			if wm and wm.has_method("add_score"):
				wm.add_score(150)
		
		if has_node("/root/SoundFX"):
			get_node("/root/SoundFX").play_ui_click()
		
		var h = get_tree().root.find_child("TouchHUD", true, false)
		if h and h.has_method("spawn_floating_text"):
			h.spawn_floating_text(coin.global_position, "+25 💵", Color("f1c40f"), 1.0)
		
		coin.queue_free()
	
	coin.body_entered.connect(func(body: Node):
		if body is RigidBody3D or body is ArcadeCar or (body.owner and body.owner is ArcadeCar):
			collect_coin.call()
	)
	
	# Auto despawn after 14 seconds if uncollected
	var despawn_timer := get_tree().create_timer(14.0)
	despawn_timer.timeout.connect(func():
		if is_instance_valid(coin):
			coin.queue_free()
	)

func _explode_pinata() -> void:
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_explosion()
	
	# Final mega coin burst
	burst_gold_coins(10)
	
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tween.tween_callback(queue_free)
