class_name KartItemSystem
extends Node3D

## 8-Weapon Kart Item & Position-Weighted Roulette System for Smashy Heist: Kart GP.
## Features:
## - Position-Weighted Rubber-Band Item Selection (1st to 6th rank tables)
## - 1.6s Roulette Roll with 0.6s early-tap fast stop
## - 8 Physical 3D Weapons & Hazards:
##   1. GREEN_TIRE (Bounces 4x off walls, spins out targets)
##   2. RED_HOMING_MISSILE (Tracks rival ahead along curve, launches into backflip)
##   3. BLUE_LEADER_DRONE (75 m/s overhead flight to 1st place, plasma blast)
##   4. OIL_SLICK (Hazard cone + puddle, 720 spinout & 55% slowdown)
##   5. TRIPLE_NITRO (3 charges of 1.5s 1.5x boost with off-road immunity)
##   6. EMP_LIGHTNING (Strikes all leaders, shrinks to 0.55 scale with 0.7x speed)
##   7. GOLD_STAR (7.0s invincibility, +40% speed, off-road immunity, flip ram)
##   8. FAKE_BOX (Decoy Question Box that detonates on contact)

enum KartItem {
	NONE = 0,
	GREEN_TIRE = 1,
	RED_HOMING_MISSILE = 2,
	BLUE_LEADER_DRONE = 3,
	OIL_SLICK = 4,
	TRIPLE_NITRO = 5,
	EMP_LIGHTNING = 6,
	GOLD_STAR = 7,
	FAKE_BOX = 8
}

const ITEM_NAMES: Dictionary = {
	0: "NONE",
	1: "GREEN TIRE",
	2: "RED MISSILE",
	3: "BLUE DRONE",
	4: "OIL SLICK",
	5: "TRIPLE NITRO",
	6: "EMP LIGHTNING",
	7: "GOLD STAR",
	8: "FAKE BOX"
}

const ITEM_ICONS: Dictionary = {
	0: "",
	1: "res://assets/kart/kart_item_green_tire.png",
	2: "res://assets/kart/kart_item_red_missile.png",
	3: "res://assets/kart/kart_item_blue_drone.png",
	4: "res://assets/kart/kart_item_oil_slick.png",
	5: "res://assets/kart/kart_item_triple_nitro.png",
	6: "res://assets/kart/kart_item_emp_lightning.png",
	7: "res://assets/kart/kart_item_gold_star.png",
	8: "res://assets/kart/kart_item_fake_box.png"
}

signal roulette_started()
signal roulette_ticked(display_item: KartItem)
signal roulette_finished(item: KartItem, count: int)
signal item_used(item: KartItem, remaining_charges: int)
signal incoming_warning_triggered(warning_type: String)

var car: ArcadeCar = null

var current_item: KartItem = KartItem.NONE
var item_charges: int = 0

var is_roulette_active: bool = false
var roulette_timer: float = 0.0
var roulette_can_fast_stop: bool = false
var _roulette_target_item: KartItem = KartItem.NONE
var _roulette_tick_timer: float = 0.0

var gold_star_timer: float = 0.0
var emp_shrunk_timer: float = 0.0

var _star_aura_mesh: MeshInstance3D = null

func _ready() -> void:
	if get_parent() is ArcadeCar:
		car = get_parent() as ArcadeCar

func _process(delta: float) -> void:
	# Process Roulette Spinning
	if is_roulette_active:
		roulette_timer += delta
		_roulette_tick_timer += delta
		if _roulette_tick_timer >= 0.08:
			_roulette_tick_timer = 0.0
			var random_disp: KartItem = randi_range(1, 8) as KartItem
			roulette_ticked.emit(random_disp)
		
		if roulette_timer >= 0.6:
			roulette_can_fast_stop = true
		
		if roulette_timer >= 1.6:
			_complete_roulette()
	
	# Process Gold Star Duration
	if gold_star_timer > 0.0:
		gold_star_timer -= delta
		_update_star_aura(delta)
		if gold_star_timer <= 0.0:
			_clear_star_aura()
	
	# Process EMP Shrunk Duration
	if emp_shrunk_timer > 0.0:
		emp_shrunk_timer -= delta
		if emp_shrunk_timer <= 0.0:
			_restore_from_emp()

## 1. Position-Weighted Rubber-Band Roulette
func start_item_roulette(current_rank: int = 1) -> void:
	if is_roulette_active or current_item != KartItem.NONE:
		return
	
	is_roulette_active = true
	roulette_timer = 0.0
	roulette_can_fast_stop = false
	_roulette_tick_timer = 0.0
	
	_roulette_target_item = _roll_weighted_item(current_rank)
	roulette_started.emit()

func fast_stop_roulette() -> void:
	if is_roulette_active and roulette_can_fast_stop:
		_complete_roulette()

func _complete_roulette() -> void:
	if not is_roulette_active:
		return
	is_roulette_active = false
	current_item = _roulette_target_item
	item_charges = 3 if current_item == KartItem.TRIPLE_NITRO else 1
	
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_ui_click"):
			sfx.play_ui_click()
	
	roulette_finished.emit(current_item, item_charges)

func _roll_weighted_item(rank: int) -> KartItem:
	var roll := randf() * 100.0
	match rank:
		1:
			# 1st Place: 40% OIL_SLICK, 35% GREEN_TIRE, 25% FAKE_BOX
			if roll < 40.0:
				return KartItem.OIL_SLICK
			elif roll < 75.0:
				return KartItem.GREEN_TIRE
			else:
				return KartItem.FAKE_BOX
		2, 3:
			# 2nd-3rd Place: 30% RED_HOMING_MISSILE, 25% GREEN_TIRE, 25% TRIPLE_NITRO, 10% OIL_SLICK, 10% FAKE_BOX
			if roll < 30.0:
				return KartItem.RED_HOMING_MISSILE
			elif roll < 55.0:
				return KartItem.GREEN_TIRE
			elif roll < 80.0:
				return KartItem.TRIPLE_NITRO
			elif roll < 90.0:
				return KartItem.OIL_SLICK
			else:
				return KartItem.FAKE_BOX
		4, 5:
			# 4th-5th Place: 30% RED_HOMING_MISSILE, 30% TRIPLE_NITRO, 20% BLUE_LEADER_DRONE, 10% GOLD_STAR, 10% EMP_LIGHTNING
			if roll < 30.0:
				return KartItem.RED_HOMING_MISSILE
			elif roll < 60.0:
				return KartItem.TRIPLE_NITRO
			elif roll < 80.0:
				return KartItem.BLUE_LEADER_DRONE
			elif roll < 90.0:
				return KartItem.GOLD_STAR
			else:
				return KartItem.EMP_LIGHTNING
		_:
			# 6th Place: 35% GOLD_STAR, 30% EMP_LIGHTNING, 25% BLUE_LEADER_DRONE, 10% TRIPLE_NITRO
			if roll < 35.0:
				return KartItem.GOLD_STAR
			elif roll < 65.0:
				return KartItem.EMP_LIGHTNING
			elif roll < 90.0:
				return KartItem.BLUE_LEADER_DRONE
			else:
				return KartItem.TRIPLE_NITRO

## 2. Trigger Held Weapon
func use_item() -> void:
	if is_roulette_active:
		fast_stop_roulette()
		return
	
	if current_item == KartItem.NONE or item_charges <= 0:
		return
	
	var item_to_use := current_item
	
	match item_to_use:
		KartItem.GREEN_TIRE:
			_fire_green_tire()
			item_charges -= 1
		KartItem.RED_HOMING_MISSILE:
			_fire_red_missile()
			item_charges -= 1
		KartItem.BLUE_LEADER_DRONE:
			_launch_blue_drone()
			item_charges -= 1
		KartItem.OIL_SLICK:
			_drop_oil_slick()
			item_charges -= 1
		KartItem.TRIPLE_NITRO:
			_activate_nitro_boost()
			item_charges -= 1
		KartItem.EMP_LIGHTNING:
			_cast_emp_lightning()
			item_charges -= 1
		KartItem.GOLD_STAR:
			_activate_gold_star()
			item_charges -= 1
		KartItem.FAKE_BOX:
			_drop_fake_box()
			item_charges -= 1
	
	if item_charges <= 0:
		current_item = KartItem.NONE
	
	item_used.emit(item_to_use, item_charges)

## --- 8 WEAPONS IMPLEMENTATION ---

# 1. GREEN TIRE
func _fire_green_tire() -> void:
	if not car:
		return
	var tire := Node3D.new()
	tire.name = "KartGreenTireProjectile"
	
	# Mesh
	var mi := MeshInstance3D.new()
	var cmesh := CylinderMesh.new()
	cmesh.top_radius = 0.55
	cmesh.bottom_radius = 0.55
	cmesh.height = 0.4
	mi.mesh = cmesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2ecc71")
	mat.metallic = 0.4
	mi.material_override = mat
	mi.rotation_degrees.z = 90
	tire.add_child(mi)
	
	# Forward or backward based on reverse input
	var fwd_dir: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	if car.is_reversing:
		fwd_dir = -fwd_dir
	
	tire.global_position = car.car_pivot.global_position + fwd_dir * 2.2 + Vector3(0, 0.4, 0)
	
	var root_world = get_tree().current_scene
	root_world.add_child(tire)
	
	# Scripted velocity and 4x wall bounce
	var vel: Vector3 = fwd_dir * 52.0
	var bounces_left: int = 4
	var shooter: ArcadeCar = car
	
	var timer := 0.0
	var p_func = func(d: float):
		timer += d
		if not is_instance_valid(tire):
			return
		
		tire.global_position += vel * d
		tire.rotation.y += d * 20.0
		
		# Check collisions with walls (Layer 4)
		var space := tire.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(tire.global_position, tire.global_position + vel.normalized() * 1.5, 8)
		var res := space.intersect_ray(q)
		if res and res.has("normal"):
			vel = vel.bounce(res["normal"]).normalized() * 52.0
			bounces_left -= 1
			if bounces_left <= 0:
				tire.queue_free()
				return
		
		# Check hitting cars
		if timer > 0.2:
			var all_cars = get_tree().get_nodes_in_group("arcade_cars")
			for other in all_cars:
				if is_instance_valid(other) and other is ArcadeCar and other != shooter:
					if tire.global_position.distance_to(other.global_position) < 2.4:
						if other.has_method("spin_out"):
							other.spin_out(1.4)
						tire.queue_free()
						return
		
		if timer >= 6.0:
			tire.queue_free()
	
	tire.set_process(true)
	tire.tree_exiting.connect(func(): pass)
	# Process via helper node or loop
	var runner := Node.new()
	tire.add_child(runner)
	runner.set_process(true)
	runner.name = "TirePhysicsRunner"
	runner.script = GDScript.new()
	runner.script.source_code = """extends Node
var update_fn: Callable
func _process(d):
	if update_fn.is_valid():
		update_fn.call(d)
"""
	runner.script.reload()
	runner.set("update_fn", p_func)

# 2. RED HOMING MISSILE
func _fire_red_missile() -> void:
	if not car:
		return
	
	# Target racer in (my_rank - 1)
	var my_rank: int = int(car.get_meta("kart_race_rank", 2))
	var target_rank: int = maxi(1, my_rank - 1)
	var target_car: ArcadeCar = _find_car_at_rank(target_rank)
	if target_car == car or not target_car:
		target_car = _find_car_ahead(car)
	
	var missile := Node3D.new()
	missile.name = "KartRedMissile"
	
	var mmesh := BoxMesh.new()
	mmesh.size = Vector3(0.5, 0.5, 1.4)
	var mi := MeshInstance3D.new()
	mi.mesh = mmesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("e74c3c")
	mat.emission_enabled = true
	mat.emission = Color("ff4757")
	mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	missile.add_child(mi)
	
	var fwd := -car.car_pivot.global_transform.basis.z.normalized()
	missile.global_position = car.car_pivot.global_position + fwd * 2.5 + Vector3(0, 0.6, 0)
	get_tree().current_scene.add_child(missile)
	
	# Notify target car of incoming missile
	if target_car and target_car.has_node("KartItemSystem"):
		target_car.get_node("KartItemSystem").incoming_warning_triggered.emit("RED_MISSILE")
	
	var m_timer := 0.0
	var missile_loop = func(d: float):
		m_timer += d
		if not is_instance_valid(missile):
			return
		
		var t_pos: Vector3 = target_car.global_position + Vector3(0, 0.5, 0) if is_instance_valid(target_car) else (missile.global_position + fwd * 10.0)
		var dir := (t_pos - missile.global_position).normalized()
		missile.global_position += dir * 55.0 * d
		if dir.length_squared() > 0.01:
			missile.look_at(missile.global_position + dir, Vector3.UP)
		
		if is_instance_valid(target_car) and missile.global_position.distance_to(target_car.global_position) < 2.5:
			if target_car.has_method("blast_flip"):
				target_car.blast_flip()
			missile.queue_free()
			return
		
		if m_timer >= 6.0:
			missile.queue_free()
	
	var runner := Node.new()
	missile.add_child(runner)
	runner.script = GDScript.new()
	runner.script.source_code = """extends Node
var fn: Callable
func _process(d):
	if fn.is_valid(): fn.call(d)
"""
	runner.script.reload()
	runner.set("fn", missile_loop)

# 3. BLUE LEADER DRONE
func _launch_blue_drone() -> void:
	var leader := _find_car_at_rank(1)
	if not leader:
		leader = _find_car_ahead(car)
	
	var drone := Node3D.new()
	drone.name = "KartBlueLeaderDrone"
	
	var dmesh := CylinderMesh.new()
	dmesh.top_radius = 1.0
	dmesh.bottom_radius = 1.0
	dmesh.height = 0.3
	var mi := MeshInstance3D.new()
	mi.mesh = dmesh
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color("00d2d3")
	dmat.emission_enabled = true
	dmat.emission = Color("54a0ff")
	dmat.emission_energy_multiplier = 2.5
	mi.material_override = dmat
	drone.add_child(mi)
	
	drone.global_position = car.global_position + Vector3(0, 6.0, 0)
	get_tree().current_scene.add_child(drone)
	
	var hover_timer := 0.0
	var is_hovering := false
	
	var drone_loop = func(d: float):
		if not is_instance_valid(drone):
			return
		
		if not is_instance_valid(leader):
			drone.queue_free()
			return
		
		var l_target := leader.global_position + Vector3(0, 5.5, 0)
		var dist_to_leader := drone.global_position.distance_to(l_target)
		
		if not is_hovering:
			var dir := (l_target - drone.global_position).normalized()
			drone.global_position += dir * 75.0 * d
			drone.rotation.y += d * 15.0
			
			if dist_to_leader < 3.0:
				is_hovering = true
				hover_timer = 0.7
				# Warn leader
				if leader.has_node("KartItemSystem"):
					leader.get_node("KartItemSystem").incoming_warning_triggered.emit("BLUE_DRONE")
		else:
			drone.global_position = l_target
			drone.rotation.y += d * 30.0
			hover_timer -= d
			if hover_timer <= 0.0:
				# Detonate 9-meter Plasma Dome
				if leader.has_method("blast_flip"):
					leader.blast_flip(true)
				drone.queue_free()
	
	var runner := Node.new()
	drone.add_child(runner)
	runner.script = GDScript.new()
	runner.script.source_code = """extends Node
var fn: Callable
func _process(d):
	if fn.is_valid(): fn.call(d)
"""
	runner.script.reload()
	runner.set("fn", drone_loop)

# 4. OIL SLICK
func _drop_oil_slick() -> void:
	if not car:
		return
	var hazard := Area3D.new()
	hazard.name = "KartOilSlickHazard"
	hazard.collision_layer = 16
	hazard.collision_mask = 2 | 4
	
	var pmesh := CylinderMesh.new()
	pmesh.top_radius = 2.2
	pmesh.bottom_radius = 2.2
	pmesh.height = 0.05
	var mi := MeshInstance3D.new()
	mi.mesh = pmesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2c1c38") # Glossy purple-black
	mat.roughness = 0.05
	mat.metallic = 0.8
	mi.material_override = mat
	hazard.add_child(mi)
	
	var cshape := CollisionShape3D.new()
	var s_cyl := CylinderShape3D.new()
	s_cyl.radius = 2.2
	s_cyl.height = 0.5
	cshape.shape = s_cyl
	hazard.add_child(cshape)
	
	var drop_pos: Vector3 = car.car_pivot.global_position + car.car_pivot.global_transform.basis.z * 3.5
	hazard.global_position = Vector3(drop_pos.x, 0.04, drop_pos.z)
	get_tree().current_scene.add_child(hazard)
	
	hazard.body_entered.connect(func(body: Node):
		var target: ArcadeCar = null
		if body is ArcadeCar: target = body as ArcadeCar
		elif body.owner is ArcadeCar: target = body.owner as ArcadeCar
		if target and target.has_method("spin_out"):
			target.spin_out(1.3, 0.45)
			hazard.queue_free()
	)

# 5. TRIPLE NITRO
func _activate_nitro_boost() -> void:
	if not car:
		return
	if car.has_method("apply_kart_boost"):
		car.apply_kart_boost(1.5, 1.5)
	elif "drift_boost_time" in car:
		car.drift_boost_multiplier = 1.5
		car.drift_boost_time = 1.5
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_nitro_boost()

# 6. EMP LIGHTNING
func _cast_emp_lightning() -> void:
	var my_rank: int = int(car.get_meta("kart_race_rank", 6))
	var all_cars = get_tree().get_nodes_in_group("arcade_cars")
	
	# Flash TouchHUD screen cyan
	var hud = get_tree().root.find_child("TouchHUD", true, false)
	if hud and hud.has_method("flash_emp_screen"):
		hud.flash_emp_screen()
	
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_emp_blast"):
			sfx.play_emp_blast()
	
	for other in all_cars:
		if is_instance_valid(other) and other is ArcadeCar and other != car:
			var other_rank: int = int(other.get_meta("kart_race_rank", 1))
			if other_rank < my_rank:
				# Strike other racer
				_spawn_lightning_bolt_at(other.global_position)
				if other.has_node("KartItemSystem"):
					other.get_node("KartItemSystem").apply_emp_shrink(5.0)

func _spawn_lightning_bolt_at(pos: Vector3) -> void:
	var bolt := MeshInstance3D.new()
	var bmesh := CylinderMesh.new()
	bmesh.top_radius = 0.4
	bmesh.bottom_radius = 0.4
	bmesh.height = 30.0
	bolt.mesh = bmesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("00d2d3")
	bolt.material_override = mat
	bolt.global_position = pos + Vector3(0, 15.0, 0)
	get_tree().current_scene.add_child(bolt)
	
	var tw := bolt.create_tween()
	tw.tween_property(bolt, "scale", Vector3(2.5, 1.0, 2.5), 0.1)
	tw.tween_property(bolt, "scale", Vector3.ZERO, 0.25)
	tw.tween_callback(bolt.queue_free)

func apply_emp_shrink(duration: float = 5.0) -> void:
	if is_gold_star_active():
		return
	emp_shrunk_timer = duration
	if car and car.car_pivot:
		var tw := car.create_tween()
		tw.tween_property(car.car_pivot, "scale", Vector3(0.55, 0.55, 0.55), 0.2)
	if car and car.has_method("spin_out"):
		car.spin_out(0.6, 0.70)

func _restore_from_emp() -> void:
	if car and car.car_pivot:
		var tw := car.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(car.car_pivot, "scale", Vector3.ONE, 0.3)

# 7. GOLD STAR
func _activate_gold_star() -> void:
	gold_star_timer = 7.0
	_create_star_aura()
	if car and car.has_method("apply_kart_boost"):
		car.apply_kart_boost(1.4, 7.0)
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_powerup_pickup"):
			sfx.play_powerup_pickup()

func is_gold_star_active() -> bool:
	return gold_star_timer > 0.0

func _create_star_aura() -> void:
	if not car or not car.car_pivot:
		return
	if not _star_aura_mesh:
		_star_aura_mesh = MeshInstance3D.new()
		var smesh := SphereMesh.new()
		smesh.radius = 2.4
		smesh.height = 4.8
		_star_aura_mesh.mesh = smesh
		var smat := StandardMaterial3D.new()
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.albedo_color = Color(1.0, 0.9, 0.1, 0.45)
		_star_aura_mesh.material_override = smat
		car.car_pivot.add_child(_star_aura_mesh)
	_star_aura_mesh.visible = true

func _update_star_aura(delta: float) -> void:
	if _star_aura_mesh and _star_aura_mesh.material_override is StandardMaterial3D:
		var hue: float = fposmod(gold_star_timer * 4.0, 1.0)
		var col := Color.from_hsv(hue, 0.9, 1.0, 0.45)
		(_star_aura_mesh.material_override as StandardMaterial3D).albedo_color = col
	
	# Check contact with rivals -> flip them!
	if car:
		var all_cars = get_tree().get_nodes_in_group("arcade_cars")
		for other in all_cars:
			if is_instance_valid(other) and other is ArcadeCar and other != car:
				if car.global_position.distance_to(other.global_position) < 3.2:
					if other.has_method("blast_flip"):
						other.blast_flip()

func _clear_star_aura() -> void:
	if _star_aura_mesh:
		_star_aura_mesh.visible = false

# 8. FAKE BOX
func _drop_fake_box() -> void:
	if not car:
		return
	var fake_box := Area3D.new()
	fake_box.name = "KartFakeBoxHazard"
	fake_box.collision_layer = 16
	fake_box.collision_mask = 2 | 4
	
	var mi := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(1.3, 1.3, 1.3)
	mi.mesh = bmesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("c0392b") # Crimson red
	mat.roughness = 0.2
	mat.emission_enabled = true
	mat.emission = Color("e74c3c")
	mat.emission_energy_multiplier = 1.4
	mi.material_override = mat
	fake_box.add_child(mi)
	
	# Upside-down '?' label
	var qlbl := Label3D.new()
	qlbl.text = "¿"
	qlbl.font_size = 96
	qlbl.modulate = Color.WHITE
	qlbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fake_box.add_child(qlbl)
	
	var cshape := CollisionShape3D.new()
	var b_col := BoxShape3D.new()
	b_col.size = Vector3(1.5, 1.5, 1.5)
	cshape.shape = b_col
	fake_box.add_child(cshape)
	
	var drop_pos: Vector3 = car.car_pivot.global_position + car.car_pivot.global_transform.basis.z * 3.5
	fake_box.global_position = Vector3(drop_pos.x, 0.7, drop_pos.z)
	get_tree().current_scene.add_child(fake_box)
	
	fake_box.body_entered.connect(func(body: Node):
		var target: ArcadeCar = null
		if body is ArcadeCar: target = body as ArcadeCar
		elif body.owner is ArcadeCar: target = body.owner as ArcadeCar
		if target and target.has_method("blast_flip"):
			target.blast_flip()
			fake_box.queue_free()
	)

## Helper queries
func _find_car_at_rank(target_rank: int) -> ArcadeCar:
	var all_cars = get_tree().get_nodes_in_group("arcade_cars")
	for c in all_cars:
		if is_instance_valid(c) and c is ArcadeCar:
			if int(c.get_meta("kart_race_rank", 0)) == target_rank:
				return c as ArcadeCar
	return null

func _find_car_ahead(my_c: ArcadeCar) -> ArcadeCar:
	var all_cars = get_tree().get_nodes_in_group("arcade_cars")
	var best_dist: float = 999999.0
	var best_car: ArcadeCar = null
	for c in all_cars:
		if is_instance_valid(c) and c is ArcadeCar and c != my_c:
			var d := my_c.global_position.distance_to(c.global_position)
			if d < best_dist:
				best_dist = d
				best_car = c as ArcadeCar
	return best_car
