class_name BossEscapeMode
extends Node3D

## Mode 3: "Escape the Mega-Boss" for Smashy Heist: Daily Getaway.
## Controls alternating epic battles against:
## 1. BOSS A: "STEAMPUNK SPIDER MECH"
##    - Slow, heavy lumbering mechanical gait with dynamic multi-axis procedural animations.
##    - Attacks: High-energy sweeping Laser beam, Steampunk Rocket salvo, and devastating Jump From Above (Sky Jump & Meteor Drop Slam).
##    - Vulnerability: Cataclysmic drop slam stuns the boss for 3.0s, exposing its boiler core to 1.5x Critical Damage!
## 2. BOSS B: "GOLIATH LASER CHOPPER" (Air gunship with sweeping magenta laser & EMP barrel vulnerability)
## 3. BOSS C: "MECHA-CRUSHER DOZER" (Rebalanced ground juggernaut with spiked roller, fair charge speed & hazard vulnerability)

signal boss_spawned(boss_name: String, max_hp: float)
signal boss_damaged(current_hp: float, max_hp: float)
signal boss_defeated(boss_name: String, defeated_count: int)

enum BossType {
	SPIDER_ROBOT = 0,
	GOLIATH_CHOPPER = 1,
	MECHA_DOZER = 2
}

enum SpiderAttackState {
	PURSUIT = 0,
	LASER_TELEGRAPH = 1,
	LASER_FIRING = 2,
	ROCKET_TELEGRAPH = 3,
	ROCKET_FIRING = 4,
	SKY_JUMP_CROUCH = 5,
	SKY_JUMP_AIRBORNE = 6,
	SKY_JUMP_FALLING = 7,
	STUNNED = 8
}

var is_boss_mode: bool = false
var player_car: ArcadeCar = null

var current_boss_type: BossType = BossType.SPIDER_ROBOT
var boss_node: Node3D = null
var boss_hp: float = 900.0
var boss_max_hp: float = 900.0
var boss_name: String = "STEAMPUNK SPIDER MECH"

var bosses_defeated: int = 0
var breather_timer: float = 0.0

# Shared state
var _attack_timer: float = 0.0
var _is_charging: bool = false
var _charge_timer: float = 0.0
var _charge_dir: Vector3 = Vector3.ZERO
var _is_telegraphing: bool = false
var _is_stunned: bool = false
var _stun_timer: float = 0.0

# Steampunk Spider Robot state
var _spider_body: RigidBody3D = null
var _spider_pivot: Node3D = null
var _spider_model: Node3D = null
var _spider_eye_light: OmniLight3D = null
var _spider_walk_time: float = 0.0
var _spider_hit_cooldown: float = 0.0
var _spider_attack_timer: float = 0.0
var _spider_attack_phase: int = 0 # 0: Laser, 1: Rockets, 2: Sky Jump
var _spider_state: SpiderAttackState = SpiderAttackState.PURSUIT
var _state_timer: float = 0.0

# Laser components
var _spider_laser_beam: MeshInstance3D = null
var _spider_laser_core: MeshInstance3D = null
var _spider_aim_line: MeshInstance3D = null
var _laser_hit_cooldown: float = 0.0
var _laser_sweep_angle: float = 0.0

# Rocket components
var _active_boss_rockets: Array[Node3D] = []
var _rockets_fired_in_salvo: int = 0
var _rocket_sub_timer: float = 0.0

# Sky Jump & Drop components
var _spider_telegraph_marker: MeshInstance3D = null
var _sky_target_pos: Vector3 = Vector3.ZERO
var _leap_target: Vector3 = Vector3.ZERO # compatibility
var _active_mines: Array[Node3D] = []

# Mecha Dozer state
var _dozer_body: RigidBody3D = null
var _dozer_roller: MeshInstance3D = null
var _dozer_laser: MeshInstance3D = null
var _dozer_hit_cooldown: float = 0.0

# Goliath Chopper state
var _chopper_mesh: Node3D = null
var _chopper_rotor1: Node3D = null
var _chopper_rotor2: Node3D = null
var _chopper_laser: MeshInstance3D = null
var _missile_drop_timer: float = 0.0
var _dropped_emp_barrel: Node3D = null

func _ready() -> void:
	pass

func _get_hud() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().root.find_child("TouchHUD", true, false)
	return null

func _get_camera_rig() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().root.find_child("CameraRig", true, false)
	return null

func start_boss_mode(car: ArcadeCar, starting_type: int = -1) -> void:
	is_boss_mode = true
	player_car = car
	bosses_defeated = 0
	if starting_type >= 0:
		current_boss_type = starting_type as BossType
	else:
		current_boss_type = BossType.SPIDER_ROBOT
	_clean_boss()
	_spawn_current_boss()

func stop_boss_mode() -> void:
	is_boss_mode = false
	_clean_boss()
	
	var hud = _get_hud()
	if hud and hud.has_method("hide_boss_health"):
		hud.hide_boss_health()

func _clean_boss() -> void:
	if boss_node and is_instance_valid(boss_node):
		boss_node.queue_free()
		boss_node = null
	if _dropped_emp_barrel and is_instance_valid(_dropped_emp_barrel):
		_dropped_emp_barrel.queue_free()
		_dropped_emp_barrel = null
	if _spider_telegraph_marker and is_instance_valid(_spider_telegraph_marker):
		_spider_telegraph_marker.queue_free()
		_spider_telegraph_marker = null
	
	for r in _active_boss_rockets:
		if is_instance_valid(r):
			r.queue_free()
	_active_boss_rockets.clear()
	
	for mine in _active_mines:
		if is_instance_valid(mine):
			mine.queue_free()
	_active_mines.clear()
	
	_spider_body = null
	_spider_pivot = null
	_spider_model = null
	_spider_eye_light = null
	_spider_laser_beam = null
	_spider_laser_core = null
	_spider_aim_line = null
	
	_dozer_body = null
	_dozer_roller = null
	_dozer_laser = null
	_chopper_mesh = null
	_chopper_rotor1 = null
	_chopper_rotor2 = null
	_chopper_laser = null
	
	_is_charging = false
	_is_telegraphing = false
	_is_stunned = false
	_spider_state = SpiderAttackState.PURSUIT
	_spider_hit_cooldown = 0.0
	_dozer_hit_cooldown = 0.0

# ==============================================================================
# BOSS SPAWNING
# ==============================================================================

func _spawn_current_boss() -> void:
	if not player_car:
		return
	
	_clean_boss()
	var p_pos: Vector3 = player_car.car_pivot.global_position if player_car.car_pivot else player_car.global_position
	var fwd: Vector3 = -player_car.car_pivot.global_transform.basis.z.normalized() if player_car.car_pivot else Vector3.FORWARD
	
	match current_boss_type:
		BossType.SPIDER_ROBOT:
			boss_name = "STEAMPUNK SPIDER MECH"
			boss_max_hp = 900.0
			boss_hp = 900.0
			_spawn_spider_robot(p_pos - fwd * 36.0)
		BossType.GOLIATH_CHOPPER:
			boss_name = "GOLIATH LASER CHOPPER"
			boss_max_hp = 1000.0
			boss_hp = 1000.0
			_spawn_goliath_chopper(p_pos + Vector3(0.0, 18.0, 0.0) - fwd * 25.0)
		BossType.MECHA_DOZER:
			boss_name = "MECHA-CRUSHER DOZER"
			boss_max_hp = 1000.0
			boss_hp = 1000.0
			_spawn_mecha_dozer(p_pos - fwd * 45.0)
	
	boss_spawned.emit(boss_name, boss_max_hp)
	
	var hud = _get_hud()
	if hud and hud.has_method("set_boss_health"):
		hud.set_boss_health(boss_name, boss_hp, boss_max_hp)

func _spawn_spider_robot(spawn_pos: Vector3) -> void:
	boss_node = Node3D.new()
	boss_node.name = "SteampunkSpiderRobot"
	add_child(boss_node)
	
	# 1. Physics Body
	_spider_body = RigidBody3D.new()
	_spider_body.name = "PhysicsSphere"
	_spider_body.collision_layer = 4 # Police / Enemy
	_spider_body.collision_mask = 31 # Ground, Player, Police, Buildings, Props
	_spider_body.mass = 24.0
	_spider_body.gravity_scale = 3.2
	_spider_body.linear_damp = 1.6
	_spider_body.angular_damp = 4.0
	boss_node.add_child(_spider_body)
	
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.1
	cs.shape = sphere
	_spider_body.add_child(cs)
	_spider_body.global_position = spawn_pos + Vector3(0.0, 2.0, 0.0)
	
	# 2. Visual Pivot
	_spider_pivot = Node3D.new()
	_spider_pivot.name = "Pivot"
	boss_node.add_child(_spider_pivot)
	_spider_pivot.global_position = spawn_pos
	
	# Load 3D GLB Model
	var scn: PackedScene = load("res://assets/models/bosses/steampunk_spider_robot.glb") as PackedScene
	if scn:
		_spider_model = scn.instantiate() as Node3D
		_spider_model.name = "SpiderMesh"
		_spider_model.scale = Vector3.ONE * 0.0105
		_spider_model.rotation.y = PI
		_spider_model.position = Vector3(0.0, 2.15, 0.0)
		_spider_pivot.add_child(_spider_model)
	
	# 3. Glowing Sensor Light (Emerald Green -> Crimson telegraph -> Amber stun)
	_spider_eye_light = OmniLight3D.new()
	_spider_eye_light.name = "EyeSensorLight"
	_spider_eye_light.light_color = Color("2ecc71") # Emerald Green
	_spider_eye_light.light_energy = 4.5
	_spider_eye_light.omni_range = 10.0
	_spider_eye_light.position = Vector3(0.0, 2.0, -2.3)
	_spider_pivot.add_child(_spider_eye_light)
	
	# 4. Steampunk Exhaust Chimneys
	for x_off in [-0.85, 0.85]:
		var chimney := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.16
		cyl.bottom_radius = 0.20
		cyl.height = 1.1
		chimney.mesh = cyl
		var c_mat := StandardMaterial3D.new()
		c_mat.albedo_color = Color("2d3436")
		c_mat.metallic = 0.85
		c_mat.roughness = 0.3
		chimney.material_override = c_mat
		chimney.position = Vector3(x_off, 2.6, 1.2)
		_spider_pivot.add_child(chimney)
	
	# 5. Aiming Telegraph Laser Ray (Thin red beam)
	_spider_aim_line = MeshInstance3D.new()
	_spider_aim_line.name = "AimLaser"
	var aim_mesh := BoxMesh.new()
	aim_mesh.size = Vector3(0.05, 0.05, 50.0)
	_spider_aim_line.mesh = aim_mesh
	var aim_mat := StandardMaterial3D.new()
	aim_mat.albedo_color = Color("e74c3c")
	aim_mat.emission_enabled = true
	aim_mat.emission = Color("ff7675")
	aim_mat.emission_energy_multiplier = 4.0
	_spider_aim_line.material_override = aim_mat
	_spider_aim_line.position = Vector3(0.0, 2.0, -25.0)
	_spider_aim_line.visible = false
	_spider_pivot.add_child(_spider_aim_line)
	
	# 6. Firing Laser Beam (Outer cyan laser + inner white core)
	_spider_laser_beam = MeshInstance3D.new()
	_spider_laser_beam.name = "FiringLaserBeam"
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.32
	beam_mesh.bottom_radius = 0.32
	beam_mesh.height = 55.0
	_spider_laser_beam.mesh = beam_mesh
	_spider_laser_beam.rotation.x = deg_to_rad(90.0)
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color("00d2d3")
	beam_mat.emission_enabled = true
	beam_mat.emission = Color("00d2d3")
	beam_mat.emission_energy_multiplier = 4.5
	_spider_laser_beam.material_override = beam_mat
	_spider_laser_beam.position = Vector3(0.0, 2.0, -27.5)
	_spider_laser_beam.visible = false
	_spider_pivot.add_child(_spider_laser_beam)
	
	_spider_laser_core = MeshInstance3D.new()
	_spider_laser_core.name = "LaserCore"
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.12
	core_mesh.bottom_radius = 0.12
	core_mesh.height = 55.0
	_spider_laser_core.mesh = core_mesh
	_spider_laser_core.rotation.x = deg_to_rad(90.0)
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color("ffffff")
	core_mat.emission_enabled = true
	core_mat.emission = Color("ffffff")
	core_mat.emission_energy_multiplier = 6.0
	_spider_laser_core.material_override = core_mat
	_spider_laser_core.position = Vector3(0.0, 2.0, -27.5)
	_spider_laser_core.visible = false
	_spider_pivot.add_child(_spider_laser_core)
	
	# 7. Jump From Above Ground Target Reticle (Concentric pulsing hazard rings)
	_spider_telegraph_marker = MeshInstance3D.new()
	_spider_telegraph_marker.name = "SkyJumpReticle"
	var t_torus := TorusMesh.new()
	t_torus.inner_radius = 4.0
	t_torus.outer_radius = 5.2
	_spider_telegraph_marker.mesh = t_torus
	var t_mat := StandardMaterial3D.new()
	t_mat.albedo_color = Color("d63031")
	t_mat.emission_enabled = true
	t_mat.emission = Color("e74c3c")
	t_mat.emission_energy_multiplier = 5.0
	_spider_telegraph_marker.material_override = t_mat
	_spider_telegraph_marker.visible = false
	add_child(_spider_telegraph_marker)
	
	# Inner Ring
	var inner_torus := MeshInstance3D.new()
	var it_mesh := TorusMesh.new()
	it_mesh.inner_radius = 1.8
	it_mesh.outer_radius = 2.4
	inner_torus.mesh = it_mesh
	inner_torus.material_override = t_mat
	_spider_telegraph_marker.add_child(inner_torus)
	
	_spider_walk_time = 0.0
	_spider_hit_cooldown = 0.0
	_spider_attack_timer = 0.0
	_spider_attack_phase = 0
	_spider_state = SpiderAttackState.PURSUIT
	_state_timer = 0.0
	_laser_hit_cooldown = 0.0
	_is_telegraphing = false
	_is_charging = false
	_is_stunned = false

func _spawn_mecha_dozer(spawn_pos: Vector3) -> void:
	boss_node = Node3D.new()
	boss_node.name = "MechaCrusherDozer"
	add_child(boss_node)
	
	_dozer_body = RigidBody3D.new()
	_dozer_body.name = "PhysicsSphere"
	_dozer_body.collision_layer = 4
	_dozer_body.collision_mask = 31
	_dozer_body.mass = 18.0
	_dozer_body.gravity_scale = 3.5
	_dozer_body.linear_damp = 1.2
	_dozer_body.angular_damp = 4.0
	boss_node.add_child(_dozer_body)
	
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	cs.shape = sphere
	_dozer_body.add_child(cs)
	_dozer_body.global_position = spawn_pos + Vector3(0.0, 1.4, 0.0)
	
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	boss_node.add_child(pivot)
	
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.4, 1.6, 5.2)
	body.mesh = bm
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = Color("1e272e")
	b_mat.roughness = 0.4
	body.material_override = b_mat
	body.position = Vector3(0.0, 1.0, 0.0)
	pivot.add_child(body)
	
	var armor := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(3.5, 0.8, 4.8)
	armor.mesh = am
	var a_mat := StandardMaterial3D.new()
	a_mat.albedo_color = Color("c0392b")
	a_mat.metallic = 0.5
	armor.material_override = a_mat
	armor.position = Vector3(0.0, 1.2, 0.0)
	pivot.add_child(armor)
	
	_dozer_roller = MeshInstance3D.new()
	var r_cyl := CylinderMesh.new()
	r_cyl.top_radius = 1.1
	r_cyl.bottom_radius = 1.1
	r_cyl.height = 3.6
	r_cyl.radial_segments = 16
	_dozer_roller.mesh = r_cyl
	var r_mat := StandardMaterial3D.new()
	r_mat.albedo_color = Color("718093")
	r_mat.metallic = 0.8
	_dozer_roller.material_override = r_mat
	_dozer_roller.position = Vector3(0.0, 0.9, -3.2)
	_dozer_roller.rotation_degrees = Vector3(0, 0, 90)
	pivot.add_child(_dozer_roller)
	
	for i in range(8):
		var spike := MeshInstance3D.new()
		var sp_mesh := BoxMesh.new()
		sp_mesh.size = Vector3(0.3, 0.4, 0.3)
		spike.mesh = sp_mesh
		var sp_mat := StandardMaterial3D.new()
		sp_mat.albedo_color = Color("e74c3c")
		sp_mat.emission_enabled = true
		sp_mat.emission = Color("e74c3c")
		sp_mat.emission_energy_multiplier = 2.0
		spike.material_override = sp_mat
		var ang: float = float(i) * (TAU / 8.0)
		spike.position = Vector3(randf_range(-1.4, 1.4), cos(ang) * 1.15, sin(ang) * 1.15)
		_dozer_roller.add_child(spike)
	
	_dozer_laser = MeshInstance3D.new()
	var l_box := BoxMesh.new()
	l_box.size = Vector3(0.08, 0.08, 45.0)
	_dozer_laser.mesh = l_box
	var l_mat := StandardMaterial3D.new()
	l_mat.albedo_color = Color("ff0000")
	l_mat.emission_enabled = true
	l_mat.emission = Color("ff0000")
	l_mat.emission_energy_multiplier = 3.5
	_dozer_laser.material_override = l_mat
	_dozer_laser.position = Vector3(0.0, 1.2, -24.0)
	_dozer_laser.visible = false
	pivot.add_child(_dozer_laser)
	
	_attack_timer = 0.0
	_is_charging = false
	_is_telegraphing = false
	_is_stunned = false
	_dozer_hit_cooldown = 0.0

func _spawn_goliath_chopper(spawn_pos: Vector3) -> void:
	boss_node = Node3D.new()
	boss_node.name = "GoliathLaserChopper"
	add_child(boss_node)
	boss_node.global_position = spawn_pos
	
	_chopper_mesh = Node3D.new()
	_chopper_mesh.name = "Fuselage"
	boss_node.add_child(_chopper_mesh)
	
	var fuse := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(3.6, 2.4, 9.2)
	fuse.mesh = fm
	var f_mat := StandardMaterial3D.new()
	f_mat.albedo_color = Color("2f3640")
	f_mat.metallic = 0.5
	fuse.material_override = f_mat
	fuse.position = Vector3(0.0, 0.0, 0.0)
	_chopper_mesh.add_child(fuse)
	
	var glass := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(2.8, 1.4, 2.2)
	glass.mesh = gm
	var g_mat := StandardMaterial3D.new()
	g_mat.albedo_color = Color("8c7ae6")
	glass.material_override = g_mat
	glass.position = Vector3(0.0, 0.4, -3.8)
	_chopper_mesh.add_child(glass)
	
	_chopper_rotor1 = Node3D.new()
	_chopper_rotor1.position = Vector3(0.0, 1.6, -2.6)
	_chopper_mesh.add_child(_chopper_rotor1)
	var b1 := MeshInstance3D.new()
	var b1_box := BoxMesh.new()
	b1_box.size = Vector3(10.0, 0.08, 0.45)
	b1.mesh = b1_box
	var r_mat := StandardMaterial3D.new()
	r_mat.albedo_color = Color("1e272e")
	b1.material_override = r_mat
	_chopper_rotor1.add_child(b1)
	
	_chopper_rotor2 = Node3D.new()
	_chopper_rotor2.position = Vector3(0.0, 2.0, 2.8)
	_chopper_mesh.add_child(_chopper_rotor2)
	var b2 := MeshInstance3D.new()
	b2.mesh = b1_box
	b2.material_override = r_mat
	_chopper_rotor2.add_child(b2)
	
	_chopper_laser = MeshInstance3D.new()
	var cl_box := BoxMesh.new()
	cl_box.size = Vector3(0.14, 22.0, 0.14)
	_chopper_laser.mesh = cl_box
	var cl_mat := StandardMaterial3D.new()
	cl_mat.albedo_color = Color("e056fd")
	cl_mat.emission_enabled = true
	cl_mat.emission = Color("e056fd")
	cl_mat.emission_energy_multiplier = 4.0
	_chopper_laser.material_override = cl_mat
	_chopper_laser.position = Vector3(0.0, -10.0, 0.0)
	_chopper_mesh.add_child(_chopper_laser)
	
	_missile_drop_timer = 0.0

# ==============================================================================
# BOSS DAMAGE & DEFEAT
# ==============================================================================

func damage_boss(amount: float) -> void:
	if boss_hp <= 0.0:
		return
	
	# 1.5x Critical damage bonus when boss is stunned from the failed Sky Jump!
	var final_dmg: float = amount
	if _is_stunned:
		final_dmg *= 1.5
	
	boss_hp = maxf(0.0, boss_hp - final_dmg)
	boss_damaged.emit(boss_hp, boss_max_hp)
	
	var hud = _get_hud()
	if hud:
		if hud.has_method("set_boss_health"):
			hud.set_boss_health(boss_name, boss_hp, boss_max_hp)
		if hud.has_method("spawn_floating_text") and boss_node:
			var hit_pos: Vector3 = boss_node.global_position + Vector3.UP * 2.5
			if _is_stunned:
				hud.spawn_floating_text(hit_pos, "💥 CRITICAL! -%d" % int(final_dmg), Color("f1c40f"), 1.2)
			else:
				hud.spawn_floating_text(hit_pos, "-%d" % int(final_dmg), Color("ff7675"), 0.9)
	
	var cam_rig = _get_camera_rig()
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.45)
	
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_smash_hit"):
			sfx.play_smash_hit()
	
	if boss_hp <= 0.0:
		_on_boss_defeated()

func apply_hazard_damage(amount: float) -> void:
	damage_boss(amount)

func _on_boss_defeated() -> void:
	bosses_defeated += 1
	boss_defeated.emit(boss_name, bosses_defeated)
	
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_explosion"):
			sfx.play_explosion()
	
	var cam_rig = _get_camera_rig()
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(1.0)
	
	# Rewards: +3,000 Score, +150 Cash
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		if not wm.is_run_active:
			wm.is_run_active = true
		wm.add_prop_score(3000)
	
	if has_node("/root/SaveManager"):
		var sm: SaveManagerClass = get_node("/root/SaveManager") as SaveManagerClass
		sm.add_cash(150)
	
	var hud = _get_hud()
	if hud and hud.has_method("hide_boss_health"):
		hud.hide_boss_health()
	if hud and hud.has_method("spawn_floating_text") and player_car:
		var p_pos = player_car.global_position
		hud.spawn_floating_text(p_pos + Vector3.UP * 2.0, "🏆 %s DESTROYED!" % boss_name, Color("f1c40f"), 2.5)
	
	breather_timer = 10.0
	_clean_boss()
	
	# Rotation: Spider -> Chopper -> Spider
	if current_boss_type == BossType.SPIDER_ROBOT:
		current_boss_type = BossType.GOLIATH_CHOPPER
	elif current_boss_type == BossType.GOLIATH_CHOPPER:
		current_boss_type = BossType.SPIDER_ROBOT
	else:
		current_boss_type = BossType.SPIDER_ROBOT

# ==============================================================================
# PROCESS LOOPS
# ==============================================================================

func _physics_process(delta: float) -> void:
	if not is_boss_mode or not player_car:
		return
	
	if breather_timer > 0.0:
		breather_timer -= delta
		if breather_timer <= 0.0:
			_spawn_current_boss()
		return
	
	if not boss_node or not is_instance_valid(boss_node):
		return
	
	var p_pos: Vector3 = player_car.car_pivot.global_position if player_car.car_pivot else player_car.global_position
	
	match current_boss_type:
		BossType.SPIDER_ROBOT:
			_process_spider_robot(delta, p_pos)
		BossType.GOLIATH_CHOPPER:
			_process_goliath_chopper(delta, p_pos)
		BossType.MECHA_DOZER:
			_process_mecha_dozer(delta, p_pos)

# ==============================================================================
# STEAMPUNK SPIDER ROBOT: SLOW LUMBERING, RICH ANIMATIONS & 3 ICONIC ATTACKS
# ==============================================================================

func _process_spider_robot(delta: float, p_pos: Vector3) -> void:
	if not _spider_body or not is_instance_valid(_spider_body):
		return
	
	# Synchronize visual pivot with physics sphere
	if _spider_pivot:
		_spider_pivot.global_position = _spider_body.global_position - Vector3(0.0, 1.8, 0.0)
	
	# Process active homing rockets
	_process_boss_rockets(delta)
	
	# Cooldowns
	if _spider_hit_cooldown > 0.0:
		_spider_hit_cooldown -= delta
	if _laser_hit_cooldown > 0.0:
		_laser_hit_cooldown -= delta
	
	# Water Canal Hazard Check (-300 HP and stuns)
	if _spider_body.global_position.y < -0.6:
		damage_boss(300.0)
		_spider_body.global_position.y = 1.8
		_spider_body.linear_velocity = Vector3.ZERO
		_enter_spider_stun(3.5)
		return
	
	var to_player: Vector3 = (p_pos - _spider_body.global_position)
	to_player.y = 0.0
	var dist: float = to_player.length()
	var dir: Vector3 = to_player.normalized()
	
	# Contact check with player car (fair contact damage with 1.4s cooldown)
	if dist < 4.2 and _spider_hit_cooldown <= 0.0 and not _is_stunned and _spider_state == SpiderAttackState.PURSUIT:
		_spider_hit_cooldown = 1.4
		player_car.take_damage(20.0)
		var cam_rig = _get_camera_rig()
		if cam_rig and cam_rig.has_method("add_trauma"):
			cam_rig.add_trauma(0.55)
		if player_car.has_method("apply_knockback"):
			player_car.apply_knockback(dir, 16.0)
		elif player_car.physics_sphere:
			player_car.physics_sphere.apply_central_impulse(dir * (16.0 * player_car.physics_sphere.mass))
	
	# =========================================================================
	# STATE MACHINE FOR SLOW MOVEMENT, ANIMATIONS & ATTACKS
	# =========================================================================
	match _spider_state:
		# ---------------------------------------------------------------------
		# 1. PURSUIT (Lumbering slow scuttle walk with dynamic heavy animation)
		# ---------------------------------------------------------------------
		SpiderAttackState.PURSUIT:
			_is_telegraphing = false
			_is_charging = false
			_is_stunned = false
			
			if _spider_aim_line: _spider_aim_line.visible = false
			if _spider_laser_beam: _spider_laser_beam.visible = false
			if _spider_laser_core: _spider_laser_core.visible = false
			if _spider_telegraph_marker: _spider_telegraph_marker.visible = false
			
			if _spider_eye_light:
				_spider_eye_light.light_color = Color("2ecc71") # Emerald Green
				_spider_eye_light.light_energy = 4.5
			
			# Face toward player
			if _spider_pivot and dist > 0.1:
				_spider_pivot.rotation.y = lerp_angle(_spider_pivot.rotation.y, atan2(-dir.x, -dir.z), 3.0 * delta)
			
			# SLOW, HEAVY LUMBERING FORCE (~8.5 - 9.5 m/s)
			var cur_vel := _spider_body.linear_velocity
			var horiz_speed := Vector2(cur_vel.x, cur_vel.z).length()
			var pursuit_force: Vector3 = dir * (8.5 * _spider_body.mass * 4.0)
			_spider_body.apply_central_force(pursuit_force)
			
			# HEAVY MECHANICAL PROCEDURAL GAIT ANIMATION
			if horiz_speed > 0.8:
				_spider_walk_time += delta * (horiz_speed * 0.35)
				if _spider_model:
					# Heavy body heave (up/down stomping)
					_spider_model.position.y = 2.15 + absf(sin(_spider_walk_time * 2.5)) * 0.32
					# Heavy mechanical roll side-to-side
					_spider_model.rotation.z = sin(_spider_walk_time * 2.5) * 0.12
					# Forward/backward pitch lumber
					_spider_model.rotation.x = sin(_spider_walk_time * 2.5) * 0.08
					# Subtle mechanical yaw sway
					_spider_model.rotation.y = PI + sin(_spider_walk_time * 1.25) * 0.05
			else:
				if _spider_model:
					_spider_model.position.y = move_toward(_spider_model.position.y, 2.15, delta * 3.0)
					_spider_model.rotation.z = move_toward(_spider_model.rotation.z, 0.0, delta * 3.0)
					_spider_model.rotation.x = move_toward(_spider_model.rotation.x, 0.0, delta * 3.0)
					_spider_model.rotation.y = PI
			
			# Attack Trigger Scheduling (Every 5.5s chooses next attack in cycle)
			_spider_attack_timer += delta
			if _spider_attack_timer >= 5.5:
				_spider_attack_timer = 0.0
				match _spider_attack_phase:
					0:
						_start_laser_telegraph(p_pos, dir)
						_spider_attack_phase = 1
					1:
						_start_rocket_telegraph(p_pos)
						_spider_attack_phase = 2
					2:
						_start_sky_jump(p_pos)
						_spider_attack_phase = 0
		
		# ---------------------------------------------------------------------
		# 2. LASER TELEGRAPH (Rearing up, charging aiming line)
		# ---------------------------------------------------------------------
		SpiderAttackState.LASER_TELEGRAPH:
			_state_timer -= delta
			_is_telegraphing = true
			
			# Stop horizontal movement while aiming
			_spider_body.linear_velocity.x = move_toward(_spider_body.linear_velocity.x, 0.0, delta * 15.0)
			_spider_body.linear_velocity.z = move_toward(_spider_body.linear_velocity.z, 0.0, delta * 15.0)
			
			# Rearing up animation: front pitches back and elevates with charging vibration
			if _spider_model:
				_spider_model.position.y = 2.45
				_spider_model.rotation.x = -deg_to_rad(15.0)
				_spider_model.rotation.z = sin(Time.get_ticks_msec() * 0.06) * 0.04 # High frequency vibration
			
			# Aim at player
			if _spider_pivot and dist > 0.1:
				_spider_pivot.rotation.y = lerp_angle(_spider_pivot.rotation.y, atan2(-dir.x, -dir.z), 5.0 * delta)
			
			if _spider_aim_line:
				_spider_aim_line.visible = true
			if _spider_eye_light:
				_spider_eye_light.light_color = Color("00d2d3")
				_spider_eye_light.light_energy = 7.0
			
			if _state_timer <= 0.0:
				_start_laser_firing()
		
		# ---------------------------------------------------------------------
		# 3. LASER FIRING (High-energy cyan laser sweeping across road)
		# ---------------------------------------------------------------------
		SpiderAttackState.LASER_FIRING:
			_state_timer -= delta
			
			# Sweeping beam oscillation animation
			_laser_sweep_angle = sin((2.2 - _state_timer) * 3.5) * 0.35
			if _spider_laser_beam:
				_spider_laser_beam.visible = true
				_spider_laser_beam.rotation.y = _laser_sweep_angle
			if _spider_laser_core:
				_spider_laser_core.visible = true
				_spider_laser_core.rotation.y = _laser_sweep_angle
			if _spider_aim_line:
				_spider_aim_line.visible = false
			
			# Model tracks slightly with laser sweep
			if _spider_model:
				_spider_model.rotation.y = PI + _laser_sweep_angle * 0.5
			
			# Laser Collision Test with Player Car
			_test_laser_beam_collision(p_pos)
			
			if _state_timer <= 0.0:
				if _spider_laser_beam: _spider_laser_beam.visible = false
				if _spider_laser_core: _spider_laser_core.visible = false
				_spider_state = SpiderAttackState.PURSUIT
		
		# ---------------------------------------------------------------------
		# 4. ROCKET TELEGRAPH (Hunching forward, chimneys smoking)
		# ---------------------------------------------------------------------
		SpiderAttackState.ROCKET_TELEGRAPH:
			_state_timer -= delta
			_is_telegraphing = true
			
			# Crouch forward animation
			if _spider_model:
				_spider_model.position.y = 1.9
				_spider_model.rotation.x = deg_to_rad(14.0)
				_spider_model.rotation.z = 0.0
			
			if _spider_eye_light:
				_spider_eye_light.light_color = Color("e67e22") # Amber warning
				_spider_eye_light.light_energy = 6.0
			
			if _state_timer <= 0.0:
				_start_rocket_salvo()
		
		# ---------------------------------------------------------------------
		# 5. ROCKET FIRING (Firing 3 tracking steampunk homing missiles)
		# ---------------------------------------------------------------------
		SpiderAttackState.ROCKET_FIRING:
			_rocket_sub_timer += delta
			# Fire one rocket every 0.35s up to 3 rockets
			if _rocket_sub_timer >= 0.35 and _rockets_fired_in_salvo < 3:
				_rocket_sub_timer = 0.0
				_fire_single_boss_rocket(_rockets_fired_in_salvo, p_pos)
				_rockets_fired_in_salvo += 1
				
				# Recoil animation
				if _spider_model:
					var recoil_dir: float = 1.0 if (_rockets_fired_in_salvo % 2 == 1) else -1.0
					_spider_model.rotation.z = recoil_dir * 0.09
			
			_state_timer -= delta
			if _state_timer <= 0.0 and _rockets_fired_in_salvo >= 3:
				_spider_state = SpiderAttackState.PURSUIT
		
		# ---------------------------------------------------------------------
		# 6. SKY JUMP CROUCH (Wind-up before launching into the sky)
		# ---------------------------------------------------------------------
		SpiderAttackState.SKY_JUMP_CROUCH:
			_state_timer -= delta
			_is_telegraphing = true
			
			# Deep compression crouch animation
			if _spider_model:
				_spider_model.position.y = 1.3
				_spider_model.rotation.x = deg_to_rad(22.0)
			
			if _spider_eye_light:
				_spider_eye_light.light_color = Color("d63031") # Red alert
				_spider_eye_light.light_energy = 8.0
			
			if _state_timer <= 0.0:
				_launch_sky_jump(p_pos)
		
		# ---------------------------------------------------------------------
		# 7. SKY JUMP AIRBORNE (High in the sky, tracking landing reticle)
		# ---------------------------------------------------------------------
		SpiderAttackState.SKY_JUMP_AIRBORNE:
			_state_timer -= delta
			_is_charging = true
			
			# Track reticle ahead of player on road
			var p_vel: Vector3 = player_car.physics_sphere.linear_velocity if player_car.physics_sphere else Vector3.ZERO
			_sky_target_pos = p_pos + p_vel.normalized() * minf(p_vel.length() * 0.9, 14.0)
			_leap_target = _sky_target_pos
			
			if _spider_telegraph_marker:
				_spider_telegraph_marker.global_position = Vector3(_sky_target_pos.x, 0.15, _sky_target_pos.z)
				_spider_telegraph_marker.visible = true
				_spider_telegraph_marker.rotation.y += delta * 4.0 # Pulsing spinning reticle
			
			# Hover high at Y = 36m above target
			_spider_body.global_position.x = _sky_target_pos.x
			_spider_body.global_position.z = _sky_target_pos.z
			_spider_body.linear_velocity = Vector3.ZERO
			
			if _state_timer <= 0.0:
				# Begin Meteor Drop
				_spider_state = SpiderAttackState.SKY_JUMP_FALLING
				_spider_body.linear_velocity = Vector3(0.0, -65.0, 0.0) # Meteor plunge
		
		# ---------------------------------------------------------------------
		# 8. SKY JUMP METEOR PLUNGE & GROUND SLAM
		# ---------------------------------------------------------------------
		SpiderAttackState.SKY_JUMP_FALLING:
			if _spider_body.global_position.y <= 2.2:
				_execute_ground_slam_impact(p_pos)
		
		# ---------------------------------------------------------------------
		# 9. STUNNED (Gears jammed, steam venting, exposed to 1.5x damage!)
		# ---------------------------------------------------------------------
		SpiderAttackState.STUNNED:
			_stun_timer -= delta
			_is_stunned = true
			
			# Stun failure pose: body tilted sideways and sagging
			if _spider_model:
				_spider_model.position.y = 1.45
				_spider_model.rotation.z = deg_to_rad(18.0)
				_spider_model.rotation.x = deg_to_rad(-8.0)
			
			if _spider_eye_light:
				_spider_eye_light.light_color = Color("f39c12")
				_spider_eye_light.light_energy = 2.0 + sin(Time.get_ticks_msec() * 0.02) * 1.5
			
			if _stun_timer <= 0.0:
				_is_stunned = false
				_spider_state = SpiderAttackState.PURSUIT

# ==============================================================================
# ATTACK EXECUTION & WEAPON SYSTEMS
# ==============================================================================

func _start_laser_telegraph(p_pos: Vector3, dir: Vector3) -> void:
	_spider_state = SpiderAttackState.LASER_TELEGRAPH
	_state_timer = 1.2
	_is_telegraphing = true
	if _spider_aim_line:
		_spider_aim_line.visible = true
	if _spider_model:
		_spider_model.position.y = 2.45
		_spider_model.rotation.x = -deg_to_rad(15.0)
	if _spider_eye_light:
		_spider_eye_light.light_color = Color("00d2d3")
		_spider_eye_light.light_energy = 7.0
	
	var hud = _get_hud()
	if hud and hud.has_method("spawn_floating_text"):
		hud.spawn_floating_text(_spider_body.global_position + Vector3.UP * 3.0, "⚠️ SPIDER LASER CHARGING!", Color("00d2d3"), 1.2)

func _start_laser_firing() -> void:
	_spider_state = SpiderAttackState.LASER_FIRING
	_state_timer = 2.2
	_laser_sweep_angle = 0.0
	_is_telegraphing = false
	if _spider_aim_line:
		_spider_aim_line.visible = false
	if _spider_laser_beam:
		_spider_laser_beam.visible = true
	if _spider_laser_core:
		_spider_laser_core.visible = true
	
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_drift_boost"):
			sfx.play_drift_boost()

func _test_laser_beam_collision(p_pos: Vector3) -> void:
	if not _spider_pivot or not player_car:
		return
	
	var laser_origin: Vector3 = _spider_pivot.global_position + Vector3(0.0, 2.0, 0.0)
	var sweep_rot := Basis(Vector3.UP, _laser_sweep_angle)
	var laser_fwd: Vector3 = (-_spider_pivot.global_transform.basis.z * sweep_rot).normalized()
	
	var to_car: Vector3 = p_pos - laser_origin
	var proj: float = to_car.dot(laser_fwd)
	
	if proj > 0.5 and proj < 52.0:
		var closest_pt: Vector3 = laser_origin + laser_fwd * proj
		var beam_dist: float = (p_pos - closest_pt).length()
		
		# Car hit by laser beam
		if beam_dist < 2.5 and _laser_hit_cooldown <= 0.0:
			_laser_hit_cooldown = 0.55
			player_car.take_damage(14.0)
			
			var cam_rig = _get_camera_rig()
			if cam_rig and cam_rig.has_method("add_trauma"):
				cam_rig.add_trauma(0.4)
			
			var hud = _get_hud()
			if hud and hud.has_method("spawn_floating_text"):
				hud.spawn_floating_text(p_pos + Vector3.UP * 1.5, "⚡ LASER BURN!", Color("00d2d3"), 0.8)

func _start_rocket_telegraph(p_pos: Vector3) -> void:
	_spider_state = SpiderAttackState.ROCKET_TELEGRAPH
	_state_timer = 0.8
	_is_telegraphing = true
	if _spider_model:
		_spider_model.position.y = 1.9
		_spider_model.rotation.x = deg_to_rad(14.0)
	if _spider_eye_light:
		_spider_eye_light.light_color = Color("e67e22")
		_spider_eye_light.light_energy = 6.0
	
	var hud = _get_hud()
	if hud and hud.has_method("spawn_floating_text"):
		hud.spawn_floating_text(_spider_body.global_position + Vector3.UP * 3.0, "⚠️ INCOMING ROCKET SALVO!", Color("e67e22"), 1.2)

func _start_rocket_salvo() -> void:
	_spider_state = SpiderAttackState.ROCKET_FIRING
	_state_timer = 1.3
	_rockets_fired_in_salvo = 0
	_rocket_sub_timer = 0.35 # Fire first rocket immediately

func _fire_single_boss_rocket(idx: int, p_pos: Vector3) -> void:
	if not _spider_pivot:
		return
	
	var x_offset: float = -0.85 if (idx == 0) else (0.85 if idx == 1 else 0.0)
	var spawn_pt: Vector3 = _spider_pivot.global_position + Vector3(x_offset, 3.2, 1.2)
	
	var rocket := Node3D.new()
	rocket.name = "SteampunkBossRocket_%d" % idx
	add_child(rocket)
	rocket.global_position = spawn_pt
	_active_boss_rockets.append(rocket)
	
	# Brass Rocket Mesh
	var r_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.14
	cyl.bottom_radius = 0.14
	cyl.height = 1.1
	r_mesh.mesh = cyl
	r_mesh.rotation.x = deg_to_rad(90.0)
	var r_mat := StandardMaterial3D.new()
	r_mat.albedo_color = Color("d35400") # Dark brass
	r_mat.metallic = 0.8
	r_mesh.material_override = r_mat
	rocket.add_child(r_mesh)
	
	# Orange Glowing Warhead Tip
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.16
	cone.height = 0.4
	tip.mesh = cone
	tip.rotation.x = deg_to_rad(90.0)
	tip.position = Vector3(0.0, 0.0, -0.7)
	var t_mat := StandardMaterial3D.new()
	t_mat.albedo_color = Color("e67e22")
	t_mat.emission_enabled = true
	t_mat.emission = Color("e67e22")
	t_mat.emission_energy_multiplier = 3.5
	tip.material_override = t_mat
	rocket.add_child(tip)
	
	# Flame Glow
	var flame := OmniLight3D.new()
	flame.light_color = Color("f39c12")
	flame.light_energy = 3.0
	flame.omni_range = 4.0
	flame.position = Vector3(0.0, 0.0, 0.6)
	rocket.add_child(flame)
	
	# Initial upward arc velocity
	var launch_vel: Vector3 = Vector3(randf_range(-3.0, 3.0), 16.0, randf_range(-3.0, 3.0))
	rocket.set_meta("velocity", launch_vel)
	rocket.set_meta("lifetime", 4.5)
	
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_gunshot"):
			sfx.play_gunshot()

func _process_boss_rockets(delta: float) -> void:
	if not player_car:
		return
	
	var p_pos: Vector3 = player_car.car_pivot.global_position if player_car.car_pivot else player_car.global_position
	var to_remove: Array[Node3D] = []
	
	for r in _active_boss_rockets:
		if not is_instance_valid(r):
			to_remove.append(r)
			continue
		
		var ltime: float = float(r.get_meta("lifetime", 4.5)) - delta
		r.set_meta("lifetime", ltime)
		if ltime <= 0.0:
			_detonate_boss_rocket(r, false)
			to_remove.append(r)
			continue
		
		var vel: Vector3 = r.get_meta("velocity", Vector3.ZERO)
		
		# Homing steering towards player road position
		var to_target: Vector3 = (p_pos - r.global_position).normalized()
		vel = vel.lerp(to_target * 25.0, 2.2 * delta)
		r.set_meta("velocity", vel)
		
		r.global_position += vel * delta
		if vel.length() > 0.1:
			r.look_at(r.global_position + vel, Vector3.UP)
		
		# Collision check with player or ground
		var dist_to_player: float = r.global_position.distance_to(p_pos)
		if dist_to_player < 2.6:
			_detonate_boss_rocket(r, true)
			to_remove.append(r)
		elif r.global_position.y <= 0.3:
			_detonate_boss_rocket(r, dist_to_player < 5.0)
			to_remove.append(r)
	
	for r in to_remove:
		_active_boss_rockets.erase(r)

func _detonate_boss_rocket(rocket: Node3D, hit_player: bool) -> void:
	if not is_instance_valid(rocket):
		return
	
	var blast_pos: Vector3 = rocket.global_position
	rocket.queue_free()
	
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_explosion"):
			sfx.play_explosion()
	
	if hit_player and player_car:
		player_car.take_damage(18.0)
		var cam_rig = _get_camera_rig()
		if cam_rig and cam_rig.has_method("add_trauma"):
			cam_rig.add_trauma(0.5)

func _start_sky_jump(p_pos: Vector3) -> void:
	_spider_state = SpiderAttackState.SKY_JUMP_CROUCH
	_state_timer = 1.2
	_is_telegraphing = true
	if _spider_model:
		_spider_model.position.y = 1.3
		_spider_model.rotation.x = deg_to_rad(22.0)
	if _spider_eye_light:
		_spider_eye_light.light_color = Color("d63031")
		_spider_eye_light.light_energy = 8.0
	
	var hud = _get_hud()
	if hud and hud.has_method("spawn_floating_text"):
		hud.spawn_floating_text(_spider_body.global_position + Vector3.UP * 3.0, "⚠️ SPIDER LEAPING HIGH ABOVE!", Color("d63031"), 1.4)
	
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_drift_boost"):
			sfx.play_drift_boost()

func _launch_sky_jump(p_pos: Vector3) -> void:
	_spider_state = SpiderAttackState.SKY_JUMP_AIRBORNE
	_state_timer = 1.4
	_is_telegraphing = false
	_is_charging = true
	
	# Blast straight into the sky
	_spider_body.global_position.y = 36.0
	_spider_body.linear_velocity = Vector3.ZERO
	
	if _spider_telegraph_marker:
		_spider_telegraph_marker.visible = true

func _execute_ground_slam_impact(p_pos: Vector3) -> void:
	_spider_body.global_position.y = 1.8
	_spider_body.linear_velocity = Vector3.ZERO
	
	if _spider_telegraph_marker:
		_spider_telegraph_marker.visible = false
	
	# Impact Sound & Screen Trauma
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_bass_impact"):
			sfx.play_bass_impact()
		if sfx.has_method("play_explosion"):
			sfx.play_explosion()
	
	var cam_rig = _get_camera_rig()
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.9)
	
	# Check if player car caught in ground zero blast (5.5m)
	var dist_to_slam: float = _spider_body.global_position.distance_to(p_pos)
	if dist_to_slam <= 5.5 and player_car:
		player_car.take_damage(28.0)
		var knock_dir: Vector3 = (p_pos - _spider_body.global_position).normalized()
		knock_dir.y = 0.5
		if player_car.has_method("apply_knockback"):
			player_car.apply_knockback(knock_dir, 24.0)
		elif player_car.physics_sphere:
			player_car.physics_sphere.apply_central_impulse(knock_dir * (24.0 * player_car.physics_sphere.mass))
	
	# LANDING STUN: Buckles hydraulics and exposes boiler core to 1.5x critical damage!
	_enter_spider_stun(3.0)

func _enter_spider_stun(duration: float) -> void:
	_spider_state = SpiderAttackState.STUNNED
	_is_stunned = true
	_stun_timer = duration
	_is_charging = false
	_is_telegraphing = false
	
	if _spider_telegraph_marker: _spider_telegraph_marker.visible = false
	if _spider_laser_beam: _spider_laser_beam.visible = false
	if _spider_laser_core: _spider_laser_core.visible = false
	if _spider_aim_line: _spider_aim_line.visible = false
	
	var hud = _get_hud()
	if hud and hud.has_method("spawn_floating_text"):
		hud.spawn_floating_text(_spider_body.global_position + Vector3.UP * 3.0, "💥 BOSS STUNNED! RAM NOW FOR 1.5x CRIT!", Color("f1c40f"), 2.2)

func _spawn_spider_web_mines(p_pos: Vector3) -> void:
	if not player_car:
		return
	
	var fwd: Vector3 = -player_car.car_pivot.global_transform.basis.z.normalized() if player_car.car_pivot else Vector3.FORWARD
	var right: Vector3 = player_car.car_pivot.global_transform.basis.x.normalized() if player_car.car_pivot else Vector3.RIGHT
	
	for sign_val in [-1.0, 1.0]:
		var mine_pos: Vector3 = p_pos + fwd * randf_range(18.0, 26.0) + right * (sign_val * randf_range(3.5, 6.0))
		mine_pos.y = 0.2
		
		var mine := Node3D.new()
		mine.name = "ClockworkMine"
		add_child(mine)
		mine.global_position = mine_pos
		_active_mines.append(mine)
		
		var ring := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 1.3
		tm.bottom_radius = 1.4
		tm.height = 0.15
		ring.mesh = tm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("e67e22")
		mat.emission_enabled = true
		mat.emission = Color("e67e22")
		mat.emission_energy_multiplier = 3.0
		ring.material_override = mat
		mine.add_child(ring)
		
		var area := Area3D.new()
		area.name = "Area3D"
		area.collision_layer = 0
		area.collision_mask = 2
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 1.6
		cs.shape = sph
		area.add_child(cs)
		mine.add_child(area)
		
		area.body_entered.connect(func(body: Node3D):
			if is_instance_valid(player_car) and (body == player_car or body == player_car.physics_sphere or body.get_parent() == player_car):
				player_car.take_damage(12.0)
				if player_car.has_method("puncture_tires"):
					player_car.puncture_tires(1.5)
				if has_node("/root/SoundFX"):
					var sfx = get_node("/root/SoundFX")
					if sfx.has_method("play_spike_puncture"):
						sfx.play_spike_puncture()
				if is_instance_valid(mine):
					_active_mines.erase(mine)
					mine.queue_free()
		)
		
		if is_inside_tree() and get_tree():
			get_tree().create_timer(8.0).timeout.connect(func():
				if is_instance_valid(mine):
					_active_mines.erase(mine)
					mine.queue_free()
			)

# ==============================================================================
# MECHA DOZER (REBALANCED GROUND JUGGERNAUT)
# ==============================================================================

func _process_mecha_dozer(delta: float, p_pos: Vector3) -> void:
	if not _dozer_body or not is_instance_valid(_dozer_body):
		return
	
	var pivot: Node3D = boss_node.get_node_or_null("Pivot")
	if pivot:
		pivot.global_position = _dozer_body.global_position - Vector3(0.0, 1.4, 0.0)
	
	if _dozer_roller:
		_dozer_roller.rotation.x += delta * 12.0
	
	if _dozer_hit_cooldown > 0.0:
		_dozer_hit_cooldown -= delta
	
	if _is_stunned:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			_is_stunned = false
		return
	
	if _dozer_body.global_position.y < -0.6:
		damage_boss(250.0)
		_dozer_body.global_position.y = 1.5
		_is_stunned = true
		_stun_timer = 3.0
		return
	
	_attack_timer += delta
	var to_player: Vector3 = (p_pos - _dozer_body.global_position)
	to_player.y = 0.0
	var dist: float = to_player.length()
	var dir: Vector3 = to_player.normalized()
	
	if _attack_timer >= 5.8 and _attack_timer < 7.0 and not _is_charging:
		_is_telegraphing = true
		if _dozer_laser:
			_dozer_laser.visible = true
		if pivot and dist > 0.1:
			pivot.rotation.y = lerp_angle(pivot.rotation.y, atan2(-dir.x, -dir.z), 12.0 * delta)
	
	elif _attack_timer >= 7.0 and not _is_charging:
		_is_telegraphing = false
		if _dozer_laser:
			_dozer_laser.visible = false
		_is_charging = true
		_charge_timer = 1.8
		_charge_dir = dir
		_attack_timer = 0.0
	
	if _is_charging:
		_charge_timer -= delta
		var charge_force: Vector3 = _charge_dir * (32.0 * _dozer_body.mass * 7.0)
		_dozer_body.apply_central_force(charge_force)
		
		if dist < 4.0 and _dozer_hit_cooldown <= 0.0:
			_dozer_hit_cooldown = 1.5
			player_car.take_damage(25.0)
			var cam_rig = _get_camera_rig()
			if cam_rig and cam_rig.has_method("add_trauma"):
				cam_rig.add_trauma(0.7)
			if player_car.has_method("apply_knockback"):
				player_car.apply_knockback(dir, 20.0)
		
		if _charge_timer <= 0.0:
			_is_charging = false
	
	elif not _is_telegraphing:
		if pivot and dist > 0.1:
			pivot.rotation.y = lerp_angle(pivot.rotation.y, atan2(-dir.x, -dir.z), 4.5 * delta)
		var pursuit_force: Vector3 = dir * (22.0 * _dozer_body.mass * 5.5)
		_dozer_body.apply_central_force(pursuit_force)

# ==============================================================================
# GOLIATH LASER CHOPPER
# ==============================================================================

func _process_goliath_chopper(delta: float, p_pos: Vector3) -> void:
	if _chopper_rotor1:
		_chopper_rotor1.rotation.y += delta * 30.0
	if _chopper_rotor2:
		_chopper_rotor2.rotation.y -= delta * 30.0
	
	var target_pos: Vector3 = Vector3(p_pos.x, 18.0, p_pos.z)
	boss_node.global_position = boss_node.global_position.lerp(target_pos, 2.5 * delta)
	
	if _chopper_laser:
		var sweep: float = sin(Time.get_ticks_msec() * 0.003) * 0.35
		_chopper_laser.rotation.z = sweep
	
	_missile_drop_timer += delta
	if _missile_drop_timer >= 8.0:
		_missile_drop_timer = 0.0
		_drop_emp_hazard(p_pos)

func _drop_emp_barrel() -> void:
	var p_pos: Vector3 = player_car.global_position if (player_car and is_instance_valid(player_car)) else Vector3.ZERO
	_drop_emp_hazard(p_pos)

func _drop_emp_hazard(p_pos: Vector3) -> void:
	if _dropped_emp_barrel and is_instance_valid(_dropped_emp_barrel):
		_dropped_emp_barrel.queue_free()
	
	_dropped_emp_barrel = Node3D.new()
	_dropped_emp_barrel.name = "EMPBarrel"
	add_child(_dropped_emp_barrel)
	_dropped_emp_barrel.global_position = p_pos + Vector3(randf_range(-6, 6), 0.5, randf_range(-6, 6))
	
	var barrel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.65
	cyl.bottom_radius = 0.65
	cyl.height = 1.3
	barrel.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("00d2d3")
	mat.emission_enabled = true
	mat.emission = Color("00d2d3")
	mat.emission_energy_multiplier = 3.2
	barrel.material_override = mat
	_dropped_emp_barrel.add_child(barrel)
	
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.8
	cs.shape = sph
	area.add_child(cs)
	_dropped_emp_barrel.add_child(area)
	
	area.body_entered.connect(func(body: Node3D):
		if body is RigidBody3D and (body == player_car.physics_sphere or body.get_parent() is ArcadeCar):
			damage_boss(340.0)
			if _dropped_emp_barrel and is_instance_valid(_dropped_emp_barrel):
				_dropped_emp_barrel.queue_free()
				_dropped_emp_barrel = null
	)
