class_name ArcadeCar
extends Node3D

const ExplosionFX = preload("res://scripts/world/explosion_fx.gd")

## Emitted when the car collides with an obstacle or other vehicle at high velocity.
signal crashed_into_object(impact_force: float, collider: Object)
signal powerup_applied(powerup_type: int, duration: float)

@export var stats: CarStats = null
@export var input_enabled: bool = true
@export var max_hp: float = 180.0

@export var peer_owner_id: int = 1
@export var is_ai_rival: bool = false
@export var driver_name: String = "Player 1"
@export var match_score: int = 0:
	set(val):
		match_score = val
		update_nameplate()

var is_holding_loot: bool = false:
	set(val):
		is_holding_loot = val
		update_nameplate()

var current_hp: float = 180.0
var car_id: String = "default_coupe"
var busted_progress: float = 0.0
var _damage_grace_timer: float = 0.0
var is_surrounded_alert: bool = false

## Network-ready input state
var steer_input: float = 0.0:
	set(value):
		steer_input = clampf(value, -1.0, 1.0)
var is_reversing: bool = false

@onready var physics_sphere: RigidBody3D = $PhysicsSphere
@onready var car_pivot: Node3D = $CarPivot
@onready var body_mesh: MeshInstance3D = $CarPivot/BodyMesh
@onready var windshield_mesh: MeshInstance3D = $CarPivot/WindshieldMesh
@onready var ground_ray: RayCast3D = $CarPivot/GroundRay
@onready var drift_smoke_left: GPUParticles3D = $CarPivot/DriftSmokeLeft
@onready var drift_smoke_right: GPUParticles3D = $CarPivot/DriftSmokeRight
@onready var busted_indicator: MeshInstance3D = $CarPivot/BustedIndicator
@onready var damage_smoke: GPUParticles3D = $CarPivot/DamageSmoke
@onready var ray_center: RayCast3D = $CarPivot.get_node_or_null("RayCenter")
@onready var ray_left: RayCast3D = $CarPivot.get_node_or_null("RayLeft")
@onready var ray_right: RayCast3D = $CarPivot.get_node_or_null("RayRight")
@onready var nameplate: Label3D = $CarPivot.get_node_or_null("Nameplate")
@onready var synchronizer: MultiplayerSynchronizer = get_node_or_null("MultiplayerSynchronizer")

var voxel_model: Node3D = null
var active_powerup: int = -1
var powerup_time_remaining: float = 0.0
var titan_shield_mesh: MeshInstance3D = null
var _oil_drop_timer: float = 0.0

# Phase 10: 2-Stage Drift Boost & Gadget System
var gadget_system: Node3D = null
var drift_hold_time: float = 0.0
var drift_charge_stage: int = 0
var drift_boost_time: float = 0.0
var drift_boost_multiplier: float = 1.0
var _drift_glow: MeshInstance3D = null

# Mythic Tier Signature Particle Trails
var mythic_trail: GPUParticles3D = null
var mythic_trail_aux: GPUParticles3D = null
var current_mythic_car_id: String = ""

# Phase 12: 3-Slot Visual Gear Loadout & Buffs
var equipped_gear_loadout: Dictionary = {}
var gear_ram_knockback_bonus: float = 0.0
var gear_damage_reduction: float = 0.0

var is_speed_boosting: bool:
	get:
		return drift_boost_time > 0.0 or (active_powerup == 0 and powerup_time_remaining > 0.0)

var current_run_ghost_frames: Array[Dictionary] = []
var _ghost_sample_timer: float = 0.0
var driving_forces_frozen: bool = false

# Escape Road 3 Mechanics: On-foot ejection, off-road grass slowdown, and spike puncture
var is_abandoned: bool = false
var is_on_grass: bool = false
var is_punctured: bool = false
var is_in_kart_offroad: bool = false
var slipstream_timer: float = 0.0
var wrong_way_timer: float = 0.0
var puncture_timer: float = 0.0
var current_npc_type: int = -1

var _previous_velocity: Vector3 = Vector3.ZERO
var _was_grounded: bool = false
var _target_pitch: float = 0.0

var _ai_stuck_timer: float = 0.0
var _ai_reverse_timer: float = 0.0

const CRASH_VELOCITY_THRESHOLD: float = 8.0
const PIVOT_OFFSET_Y: float = -0.45

# Standardized Equalized Racing Parameters for Smashy Kart Grand Prix
# (Normal Mode uses unique vehicle stats; Kart Mode uses balanced constant parameters for all cars)
const KART_BASE_MAX_SPEED: float = 17.5
const KART_BASE_ACCELERATION: float = 18.0
const KART_BASE_REVERSE_ACCEL: float = 10.0
const KART_BASE_TURN_SPEED: float = 2.45
const KART_BASE_DRIFT_GRIP: float = 0.90

func has_local_authority() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return peer_owner_id == 1
	return is_multiplayer_authority()

func _ready() -> void:
	add_to_group("player")
	add_to_group("player_vehicles")
	current_hp = max_hp
	
	if multiplayer.has_multiplayer_peer():
		set_multiplayer_authority(peer_owner_id)
		if synchronizer:
			synchronizer.set_multiplayer_authority(peer_owner_id)
	
	# Load equipped car stats from SaveManager for local human player
	var is_local_human: bool = not is_ai_rival and not is_abandoned and car_id.is_empty() and (peer_owner_id == 1 or (multiplayer.has_multiplayer_peer() and peer_owner_id == multiplayer.get_unique_id()))
	if is_local_human:
		if has_node("/root/SaveManager"):
			var sm = get_node("/root/SaveManager")
			var vdb = get_node_or_null("/root/VehicleDatabase")
			if vdb and vdb.has_car(sm.equipped_car_id):
				stats = vdb.get_car_stats(sm.equipped_car_id)
			else:
				var stats_path: String = sm.get_equipped_car_stats_path()
				if ResourceLoader.exists(stats_path):
					stats = load(stats_path) as CarStats
			car_id = sm.equipped_car_id
			_apply_car_visuals(sm.equipped_car_id)
			if not sm.car_equipped.is_connected(_on_car_equipped):
				sm.car_equipped.connect(_on_car_equipped)
	else:
		var target_id: String = car_id
		if target_id.is_empty() and stats and not stats.car_id.is_empty():
			target_id = stats.car_id
		if target_id.is_empty():
			target_id = "default_coupe"
		car_id = target_id
		
		# If stats haven't been loaded for this car yet, load them from VehicleDatabase
		if stats == null or stats.car_id != target_id:
			var vdb = get_node_or_null("/root/VehicleDatabase")
			if vdb and vdb.has_car(target_id):
				stats = vdb.get_car_stats(target_id)
			elif ResourceLoader.exists("res://resources/vehicles/%s.tres" % target_id):
				stats = load("res://resources/vehicles/%s.tres" % target_id) as CarStats
		
		_apply_car_visuals(target_id)
	
	if stats == null:
		stats = CarStats.new()
	
	if stats and stats.max_hp > 0.0:
		max_hp = stats.max_hp
	current_hp = max_hp
	
	physics_sphere.mass = stats.mass_weight
	var cs = physics_sphere.get_node_or_null("CollisionShape3D")
	if cs and cs.shape is SphereShape3D:
		(cs.shape as SphereShape3D).radius = 0.95
	
	if not physics_sphere.body_entered.is_connected(_on_physics_sphere_body_entered):
		physics_sphere.body_entered.connect(_on_physics_sphere_body_entered)
	
	# Connect to WantedManager signals
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		if not wm.run_started.is_connected(_on_run_started):
			wm.run_started.connect(_on_run_started)
		if not wm.player_busted.is_connected(_on_player_busted):
			wm.player_busted.connect(_on_player_busted)
		if "perk_applied" in wm and not wm.perk_applied.is_connected(_on_perk_applied):
			wm.perk_applied.connect(_on_perk_applied)
	
	# Attach Phase 10 CarGadgetSystem
	var GadgetClass = load("res://scripts/vehicles/car_gadget_system.gd")
	if GadgetClass:
		gadget_system = GadgetClass.new()
		gadget_system.name = "CarGadgetSystem"
		add_child(gadget_system)
	
	# Initial position sync
	car_pivot.top_level = true
	car_pivot.global_position = physics_sphere.global_position + Vector3(0, PIVOT_OFFSET_Y, 0)
	car_pivot.global_rotation = global_rotation
	
	drift_smoke_left.emitting = false
	drift_smoke_right.emitting = false
	if damage_smoke:
		damage_smoke.emitting = false
	if busted_indicator:
		busted_indicator.visible = false
	
	update_nameplate()

var tank_rocket_cooldown: float = 0.0
var _eject_cooldown: float = 0.5

func _process(delta: float) -> void:
	if tank_rocket_cooldown > 0.0:
		tank_rocket_cooldown -= delta
	
	# Only capture raw input here if local authority and not AI rival
	if input_enabled and has_local_authority() and not is_ai_rival:
		if is_tank() and (Input.is_key_pressed(KEY_R) or Input.is_action_just_pressed("fire_rocket")):
			fire_tank_rocket()
		
		var hud_active: bool = get_tree().root.find_child("TouchHUD", true, false) != null
		if not hud_active:
			steer_input = Input.get_axis("steer_left", "steer_right")
			is_reversing = Input.is_action_pressed("reverse_brake")


func _physics_process(delta: float) -> void:
	if _eject_cooldown > 0.0:
		_eject_cooldown -= delta
	if _damage_grace_timer > 0.0:
		_damage_grace_timer -= delta
	
	# 1. Sync CarPivot position to PhysicsSphere + offset, and keep root global_position updated
	car_pivot.global_position = physics_sphere.global_position + Vector3(0, PIVOT_OFFSET_Y, 0)
	global_position = physics_sphere.global_position
	
	if driving_forces_frozen:
		if physics_sphere:
			physics_sphere.linear_velocity = Vector3.ZERO
			physics_sphere.angular_velocity = Vector3.ZERO
		return
	
	# Check run active status
	var is_run_active: bool = true
	var in_kart_mode: bool = has_node("/root/GameModeManager") and int(get_node("/root/GameModeManager").current_mode) == 3
	if in_kart_mode:
		var kart_mode := get_tree().root.find_child("SmashyKartMode", true, false)
		if kart_mode:
			is_run_active = kart_mode.is_race_active
		else:
			is_run_active = true
	elif has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		is_run_active = wm.is_run_active
	
	# AI steering loop for AI rivals (run on authority, but skip in kart mode since KartMode controls track curve steering)
	if is_ai_rival and has_local_authority() and not in_kart_mode:
		_process_ai_steering(delta)
	
	# Sample ghost frames every 0.2s for player 1
	if is_run_active and not is_ai_rival and peer_owner_id == 1 and not in_kart_mode:
		_ghost_sample_timer += delta
		if _ghost_sample_timer >= 0.2:
			_ghost_sample_timer -= 0.2
			if current_run_ghost_frames.size() < 900:
				var s_time: float = 0.0
				if has_node("/root/WantedManager"):
					s_time = get_node("/root/WantedManager").survival_time
				current_run_ghost_frames.append({
					"t": snappedf(s_time, 0.05),
					"x": snappedf(car_pivot.global_position.x, 0.01),
					"y": snappedf(car_pivot.global_position.y, 0.01),
					"z": snappedf(car_pivot.global_position.z, 0.01),
					"ry": snappedf(car_pivot.rotation.y, 0.01)
				})
	
	# Damage smoke check
	if damage_smoke:
		damage_smoke.emitting = (current_hp < 60.0)
	
	# 2. Check GroundRay collision
	var is_grounded: bool = ground_ray.is_colliding()
	
	# Detect landing after airborne for jump impact pitch
	if is_grounded and not _was_grounded:
		var impact_drop: float = clampf(absf(_previous_velocity.y) * 0.03, 0.0, 0.15)
		_target_pitch = -impact_drop
	_was_grounded = is_grounded
	
	var forward_dir: Vector3 = -car_pivot.global_transform.basis.z.normalized()
	var right_dir: Vector3 = car_pivot.global_transform.basis.x.normalized()
	var current_forward_speed: float = physics_sphere.linear_velocity.dot(forward_dir)
	var current_speed: float = physics_sphere.linear_velocity.length()
	
	# Escape Road 3 Off-Road Grass & Puncture Penalties
	var grass_drag: float = 1.0
	if in_kart_mode:
		var is_boosting: bool = drift_boost_time > 0.0 or (has_node("KartItemSystem") and get_node("KartItemSystem").is_gold_star_active())
		if is_boosting:
			grass_drag = 1.0
		elif is_in_kart_offroad:
			grass_drag = 0.62
	else:
		var chunk_px: float = fposmod(car_pivot.global_position.x, 48.0)
		var chunk_pz: float = fposmod(car_pivot.global_position.z, 48.0)
		var is_on_road: bool = (chunk_px >= 16.5 and chunk_px <= 31.5) or (chunk_pz >= 16.5 and chunk_pz <= 31.5)
		is_on_grass = not is_on_road
		grass_drag = 0.72 if is_on_grass else 1.0
	var puncture_drag: float = 0.60 if is_punctured else 1.0
	
	# Decay Drift Boost
	if drift_boost_time > 0.0:
		drift_boost_time -= delta
		if drift_boost_time <= 0.0:
			drift_boost_multiplier = 1.0
	
	# 3. Acceleration & braking forces (only if authority drives physics)
	if has_local_authority():
		if is_abandoned or not input_enabled:
			# Driver has jumped out! The car is NOT controlled by player anymore.
			steer_input = 0.0
			is_reversing = false
			if physics_sphere:
				if physics_sphere.linear_velocity.length() > 0.15:
					var brake_drag: Vector3 = -physics_sphere.linear_velocity * (9.0 * physics_sphere.mass)
					brake_drag.y = 0.0
					physics_sphere.apply_central_force(brake_drag)
				else:
					physics_sphere.linear_velocity = Vector3(0.0, physics_sphere.linear_velocity.y, 0.0)
					physics_sphere.angular_velocity = Vector3.ZERO
		elif is_grounded and is_run_active:
			# In Kart Mode: all cars have equalized constant speed and handling for fair, balanced arcade racing.
			# In Normal Mode: car speed, acceleration, and handling are based on individual vehicle stats.
			var base_max_speed: float = KART_BASE_MAX_SPEED if in_kart_mode else stats.max_speed
			var base_accel: float = KART_BASE_ACCELERATION if in_kart_mode else stats.acceleration
			var base_reverse: float = KART_BASE_REVERSE_ACCEL if in_kart_mode else stats.reverse_acceleration
			var base_turn_speed: float = KART_BASE_TURN_SPEED if in_kart_mode else stats.turn_speed
			var base_drift_grip: float = KART_BASE_DRIFT_GRIP if in_kart_mode else stats.drift_grip
			
			if is_reversing:
				var brake_mult: float = 3.0 if current_forward_speed > 1.0 else 1.0
				var reverse_force: Vector3 = -forward_dir * (base_reverse * brake_mult * physics_sphere.mass)
				physics_sphere.apply_central_force(reverse_force)
				_target_pitch = lerpf(_target_pitch, -0.06, 6.0 * delta)
			else:
				var nitro_mult: float = 1.4 if (active_powerup == 0 and powerup_time_remaining > 0.0) else 1.0
				var drift_mult: float = drift_boost_multiplier if drift_boost_time > 0.0 else 1.0
				var eff_max_speed: float = base_max_speed * nitro_mult * drift_mult * grass_drag * puncture_drag
				if current_forward_speed < eff_max_speed:
					var force_ratio: float = clampf(1.0 - (current_forward_speed / eff_max_speed), 0.0, 1.0)
					var boost_mult: float = (1.35 if (active_powerup == 0 and powerup_time_remaining > 0.0) else 1.0) * drift_mult
					var damp_comp: float = physics_sphere.linear_damp * current_forward_speed * physics_sphere.mass
					var drive_accel: float = base_accel * physics_sphere.mass * force_ratio
					var accel_force: Vector3 = forward_dir * ((drive_accel + damp_comp) * boost_mult * grass_drag)
					physics_sphere.apply_central_force(accel_force)
				elif current_forward_speed > eff_max_speed + 0.5:
					# Progressive engine governor braking force when exceeding eff_max_speed
					var overspeed_drag: float = (current_forward_speed - eff_max_speed) * 16.0 * physics_sphere.mass
					physics_sphere.apply_central_force(-forward_dir * overspeed_drag)
				_target_pitch = lerpf(_target_pitch, 0.04, 6.0 * delta)
			
			var lateral_speed: float = physics_sphere.linear_velocity.dot(right_dir)
			var grip_multiplier: float = 14.0 if (absf(steer_input) > 0.45 and current_speed > 6.0) else 26.0
			var lateral_damping_force: Vector3 = -right_dir * (lateral_speed * base_drift_grip * grip_multiplier * physics_sphere.mass)
			physics_sphere.apply_central_force(lateral_damping_force)
			
			# Tire puncture violent fishtailing
			if is_punctured:
				puncture_timer -= delta
				if puncture_timer <= 0.0:
					is_punctured = false
				elif current_speed > 4.0 and fmod(puncture_timer, 0.20) < delta:
					physics_sphere.apply_torque_impulse(Vector3(0, randf_range(-14.0, 14.0), 0) * physics_sphere.mass)
		elif not is_grounded:
			_target_pitch = lerpf(_target_pitch, 0.0, 4.0 * delta)
		
		# 4. Steering (ONLY when driver is in car)
		if is_run_active and not is_abandoned and input_enabled and absf(steer_input) > 0.01:
			var speed_factor: float = clampf(current_speed / 2.5, 0.45, 1.0)
			if current_speed > 16.0:
				speed_factor *= clampf(1.0 - (current_speed - 16.0) * 0.025, 0.75, 1.0)
			var base_turn: float = KART_BASE_TURN_SPEED if in_kart_mode else stats.turn_speed
			car_pivot.rotation.y += -steer_input * base_turn * speed_factor * delta
	
	# 5. BodyMesh tilt & pitch (interpolated locally)
	var target_tilt: float = -steer_input * stats.body_tilt_amount
	body_mesh.rotation.z = lerpf(body_mesh.rotation.z, target_tilt, 10.0 * delta)
	body_mesh.rotation.x = lerpf(body_mesh.rotation.x, _target_pitch, 8.0 * delta)
	if voxel_model:
		voxel_model.rotation.z = body_mesh.rotation.z
		voxel_model.rotation.x = body_mesh.rotation.x
		if absf(current_forward_speed) > 0.1:
			var spin_step: float = current_forward_speed * delta * 5.0
			for i in range(4):
				var wheel := voxel_model.get_node_or_null("Wheel_%d" % i)
				if wheel:
					wheel.rotation.x += spin_step
	
	# 6. Drift smoke particles & 2-Stage Drift Boost Charging
	var is_drifting: bool = is_grounded and absf(steer_input) > 0.2 and is_run_active
	if is_drifting and has_local_authority() and not is_ai_rival:
		if has_node("/root/ProgressionManager"):
			get_node("/root/ProgressionManager").add_drift_seconds(delta)
	
	if drift_smoke_left.emitting != is_drifting:
		drift_smoke_left.emitting = is_drifting
	if drift_smoke_right.emitting != is_drifting:
		drift_smoke_right.emitting = is_drifting
	
	if is_grounded and is_run_active and absf(steer_input) > 0.5:
		var charge_rate: float = 1.0
		if has_node("/root/WantedManager"):
			var wm = get_node("/root/WantedManager")
			if wm and wm.has_method("has_perk") and wm.has_perk("NITRO_DRIFT"):
				charge_rate = 1.4 # 40% faster charge
		drift_hold_time += delta * charge_rate
		
		if drift_hold_time >= 2.5:
			if drift_charge_stage < 3:
				drift_charge_stage = 3
				_pulse_car_mesh()
			_set_drift_sparks(Color("a55eea"), 3) # ELECTRIC PURPLE/MAGENTA
		elif drift_hold_time >= 1.75:
			if drift_charge_stage < 2:
				drift_charge_stage = 2
				_pulse_car_mesh()
			_set_drift_sparks(Color("ff9f43"), 2) # GOLDEN-ORANGE
		elif drift_hold_time >= 0.85:
			if drift_charge_stage < 1:
				drift_charge_stage = 1
			_set_drift_sparks(Color("00d2d3"), 1) # CYAN-BLUE
	else:
		if absf(steer_input) < 0.2 and drift_charge_stage > 0:
			_trigger_drift_boost(drift_charge_stage)
		if absf(steer_input) < 0.2 or not is_grounded:
			drift_hold_time = 0.0
			drift_charge_stage = 0
			_clear_drift_sparks()
	
	# Update Mythic Tier Signature Trails
	if mythic_trail and is_instance_valid(mythic_trail):
		var is_trail_active: bool = is_run_active and not is_abandoned and current_speed > 1.2
		if mythic_trail.emitting != is_trail_active:
			mythic_trail.emitting = is_trail_active
		if mythic_trail_aux and is_instance_valid(mythic_trail_aux):
			if mythic_trail_aux.emitting != is_trail_active:
				mythic_trail_aux.emitting = is_trail_active
		
		if is_trail_active and (is_speed_boosting or is_drifting):
			mythic_trail.speed_scale = 1.6
			if mythic_trail_aux and is_instance_valid(mythic_trail_aux):
				mythic_trail_aux.speed_scale = 1.6
		elif is_trail_active:
			mythic_trail.speed_scale = 1.0
			if mythic_trail_aux and is_instance_valid(mythic_trail_aux):
				mythic_trail_aux.speed_scale = 1.0
	
	# 7. BUSTED & SURROUNDED DETECTION (ONLY IF DRIVER IS IN CAR - NOT ABANDONED)
	if not is_abandoned and is_run_active and has_local_authority():
		var surrounding_cops: int = 0
		var is_boxed_in: bool = false
		var cops := get_tree().get_nodes_in_group("police_units")
		for cop in cops:
			if is_instance_valid(cop) and cop is PoliceCar:
				var cop_car := cop as PoliceCar
				if not cop_car.is_wrecked:
					var cop_pos: Vector3 = cop_car.physics_sphere.global_position if cop_car.physics_sphere else cop_car.global_position
					var dist := car_pivot.global_position.distance_to(cop_pos)
					if dist <= 6.5:
						surrounding_cops += 1
					if dist <= 4.2 and current_speed < 4.0:
						is_boxed_in = true
		
		# Register surrounding pressure with WantedManager (accelerates heat and star escalation)
		if has_node("/root/WantedManager"):
			var wm = get_node("/root/WantedManager")
			if wm and wm.has_method("register_surrounded_pressure"):
				wm.register_surrounded_pressure(delta, surrounding_cops)
		
		# Surrounded notification
		if surrounding_cops >= 2 and not is_surrounded_alert:
			is_surrounded_alert = true
			var hud = get_tree().root.find_child("TouchHUD", true, false)
			if hud and hud.has_method("spawn_floating_text"):
				hud.spawn_floating_text(car_pivot.global_position + Vector3.UP, "⚠️ SURROUNDED!", Color("ff4757"), 1.4)
		elif surrounding_cops < 2:
			is_surrounded_alert = false
		
		var busted_rate: float = 2.0
		if surrounding_cops >= 3:
			busted_rate = 1.2 # Faster arrest when 3+ cruisers surround player
		elif surrounding_cops >= 2:
			busted_rate = 1.6
		
		if has_node("/root/WantedManager"):
			var wm = get_node("/root/WantedManager")
			if wm and wm.has_method("has_perk") and wm.has_perk("SPIKED_FENDERS"):
				busted_rate *= 2.0 # Twice as long to arrest
		
		if is_boxed_in:
			busted_progress = minf(1.0, busted_progress + delta / busted_rate)
			# Spiked Fenders deal contact damage to cops boxing you in
			if has_node("/root/WantedManager"):
				var wm = get_node("/root/WantedManager")
				if wm and wm.has_method("has_perk") and wm.has_perk("SPIKED_FENDERS"):
					for cop in cops:
						if is_instance_valid(cop) and cop is PoliceCar:
							var pc := cop as PoliceCar
							if not pc.is_wrecked and car_pivot.global_position.distance_to(pc.global_position) <= 4.2:
								pc.take_damage(25.0 * delta)
		elif surrounding_cops >= 3 and current_speed < 7.0:
			# Slow/trapped while heavily surrounded also ticks up busted progress
			busted_progress = minf(1.0, busted_progress + delta / 4.5)
		else:
			busted_progress = move_toward(busted_progress, 0.0, delta * 1.5)
		
		# Nitro Overdrive arrest immunity
		if active_powerup == 0 and powerup_time_remaining > 0.0:
			busted_progress = 0.0
		
		# Update 3D Busted Indicator Visual
		if busted_indicator:
			if busted_progress > 0.01:
				busted_indicator.visible = true
				var indicator_scale: float = lerpf(0.6, 1.4, busted_progress)
				busted_indicator.scale = Vector3(indicator_scale, 1.0, indicator_scale)
				busted_indicator.rotation.y += delta * 6.0
			else:
				busted_indicator.visible = false
		
		# Trigger Arrested
		if busted_progress >= 1.0:
			var hot_loot := get_tree().root.find_child("HotLootMode", true, false)
			if hot_loot and hot_loot.is_hot_loot_mode:
				hot_loot.handle_car_busted(self, "BUSTED BY POLICE!")
			elif has_node("/root/WantedManager"):
				var wm = get_node("/root/WantedManager")
				wm.last_wasted_target = self
				wm.last_active_car = self
				wm.trigger_busted("BUSTED BY POLICE!")
		
		# Escape Road 3 Mechanic: Voluntary or Emergency Ejection onto Foot (Press Space or F on desktop or on-screen Action Button)
		# Note: Jumping off is strictly disabled in Kart Mode (races must be run inside karts)
		if not is_abandoned and not is_ai_rival and peer_owner_id == 1 and input_enabled and not in_kart_mode:
			var wants_eject: bool = _eject_cooldown <= 0.0 and (Input.is_key_pressed(KEY_F) or Input.is_key_pressed(KEY_SPACE) or (InputMap.has_action("jump") and Input.is_action_just_pressed("jump")))
			var emergency_eject: bool = current_hp <= 0.0
			var water_submerge: bool = physics_sphere and physics_sphere.global_position.y < -0.45
			if water_submerge:
				submerge_in_water()
			elif wants_eject or emergency_eject:
				eject_player_character()
		
		# Trigger Wrecked ONLY if player is still in car and not abandoned
		if current_hp <= 0.0 and not is_abandoned:
			var hot_loot := get_tree().root.find_child("HotLootMode", true, false)
			if hot_loot and hot_loot.is_hot_loot_mode:
				hot_loot.handle_car_busted(self, "WRECKED!")
			elif in_kart_mode:
				spin_out(1.2)
				current_hp = max_hp
			elif has_node("/root/WantedManager"):
				var wm = get_node("/root/WantedManager")
				wm.last_wasted_target = self
				wm.last_active_car = self
				wm.trigger_busted("WRECKED!")
	elif is_abandoned:
		# Abandoned car is inert and meaningless: reset any busted indicator and alert
		busted_progress = 0.0
		if busted_indicator:
			busted_indicator.visible = false
		is_surrounded_alert = false
	# Powerup lifecycle & active physics effects
	if powerup_time_remaining > 0.0:
		powerup_time_remaining -= delta
		
		# Titan Shield deflection
		if active_powerup == 3:
			var cops := get_tree().get_nodes_in_group("police_units")
			for cop in cops:
				if is_instance_valid(cop) and cop is PoliceCar:
					var pc := cop as PoliceCar
					if pc.physics_sphere and car_pivot.global_position.distance_to(pc.physics_sphere.global_position) < 3.4:
						var away_dir := (pc.physics_sphere.global_position - car_pivot.global_position).normalized()
						away_dir.y = 0.45
						pc.physics_sphere.apply_central_impulse(away_dir * (26.0 * pc.physics_sphere.mass))
						pc.take_damage(40.0)
		
		# Oil Slick dropper
		elif active_powerup == 2:
			_oil_drop_timer += delta
			if _oil_drop_timer >= 1.2:
				_oil_drop_timer = 0.0
				_drop_oil_slick()
		
		if powerup_time_remaining <= 0.0:
			active_powerup = -1
			_show_titan_shield(false)
	
	_previous_velocity = physics_sphere.linear_velocity

func _process_ai_steering(delta: float) -> void:
	var target_pos: Vector3 = Vector3(24.0, 0.6, 24.0)
	
	if is_holding_loot:
		# Evade police!
		var cops := get_tree().get_nodes_in_group("police_units")
		var closest_cop: Node3D = null
		var min_dist: float = 99999.0
		for cop in cops:
			if is_instance_valid(cop):
				var is_wr: bool = cop.has_method("is_wrecked") and cop.is_wrecked
				if not is_wr:
					var cpos: Vector3 = cop.global_position
					if "car_pivot" in cop and cop.car_pivot:
						cpos = cop.car_pivot.global_position
					var d := car_pivot.global_position.distance_to(cpos)
					if d < min_dist:
						min_dist = d
						closest_cop = cop
		if closest_cop and min_dist < 40.0:
			var cpos: Vector3 = closest_cop.global_position
			if "car_pivot" in closest_cop and closest_cop.car_pivot:
				cpos = closest_cop.car_pivot.global_position
			var evade_dir := (car_pivot.global_position - cpos).normalized()
			target_pos = car_pivot.global_position + evade_dir * 30.0
		else:
			var forward_dir := -car_pivot.global_transform.basis.z.normalized()
			target_pos = car_pivot.global_position + forward_dir * 25.0
	else:
		# Drive toward the Loot Bag holder!
		var hot_loot := get_tree().root.find_child("HotLootMode", true, false)
		if hot_loot and hot_loot.loot_holder_car and is_instance_valid(hot_loot.loot_holder_car) and hot_loot.loot_holder_car != self:
			var holder: Node3D = hot_loot.loot_holder_car
			var hpos: Vector3 = holder.car_pivot.global_position if "car_pivot" in holder and holder.car_pivot else holder.global_position
			var hvel: Vector3 = holder.physics_sphere.linear_velocity if "physics_sphere" in holder and holder.physics_sphere else Vector3.ZERO
			var dist := car_pivot.global_position.distance_to(hpos)
			var lead_time := clampf(dist / 28.0, 0.1, 1.2)
			target_pos = hpos + hvel * lead_time
		else:
			var forward_dir := -car_pivot.global_transform.basis.z.normalized()
			target_pos = car_pivot.global_position + forward_dir * 25.0
	
	var local_target := car_pivot.to_local(target_pos)
	var steer_angle := atan2(-local_target.x, -local_target.z)
	var desired_steer := clampf(steer_angle * 1.8, -1.0, 1.0)
	
	# 3-Ray Building Avoidance
	var is_center_hit: bool = ray_center != null and ray_center.is_colliding()
	var is_left_hit: bool = ray_left != null and ray_left.is_colliding()
	var is_right_hit: bool = ray_right != null and ray_right.is_colliding()
	
	if is_center_hit:
		if is_left_hit and not is_right_hit:
			desired_steer = -1.0
		elif is_right_hit and not is_left_hit:
			desired_steer = 1.0
		else:
			var norm := ray_center.get_collision_normal()
			var local_norm := car_pivot.global_basis.inverse() * norm
			desired_steer = 1.0 if local_norm.x >= 0.0 else -1.0
	elif is_left_hit:
		desired_steer = -1.0
	elif is_right_hit:
		desired_steer = 1.0
	
	# Stuck Detection against obstacles
	var cur_speed := physics_sphere.linear_velocity.length()
	if cur_speed < 1.4:
		_ai_stuck_timer += delta
		if _ai_stuck_timer >= 0.45:
			_ai_reverse_timer = 0.65
			_ai_stuck_timer = 0.0
	else:
		_ai_stuck_timer = 0.0
	
	if _ai_reverse_timer > 0.0:
		_ai_reverse_timer -= delta
		is_reversing = true
		desired_steer = -desired_steer
	else:
		is_reversing = false
	
	steer_input = desired_steer

func update_nameplate() -> void:
	if nameplate:
		if is_holding_loot:
			nameplate.modulate = Color(1.0, 0.85, 0.15)
			nameplate.text = "👑 %s\n%d PTS" % [driver_name, match_score]
		else:
			nameplate.modulate = Color(1.0, 1.0, 1.0)
			nameplate.text = "%s\n%d PTS" % [driver_name, match_score]

func take_damage(amount: float) -> void:
	if is_abandoned:
		# Abandoned car is meaningless: taking damage does not trigger busted
		return
	if active_powerup == 3 and powerup_time_remaining > 0.0:
		# Titan Shield blocks damage
		return
	var eff_amount: float = amount * (1.0 - gear_damage_reduction)
	current_hp = maxf(0.0, current_hp - eff_amount)
	if has_node("/root/BrawlUITheme"):
		get_node("/root/BrawlUITheme").flash_white(car_pivot if car_pivot else self, 0.09)
	if current_hp <= 0.0:
		var hot_loot := get_tree().root.find_child("HotLootMode", true, false)
		if hot_loot and hot_loot.is_hot_loot_mode:
			hot_loot.handle_car_busted(self, "WRECKED!")
		elif has_node("/root/WantedManager"):
			var wm = get_node("/root/WantedManager")
			wm.last_wasted_target = self
			wm.last_active_car = self
			wm.trigger_busted("WRECKED!")

## Heals vehicle HP (e.g. from Ambulance medkit or repair pick-up)
func heal(amount: float) -> void:
	current_hp = minf(max_hp, current_hp + amount)
	if damage_smoke:
		damage_smoke.emitting = (current_hp < 60.0)
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_ui_click"):
			sfx.play_ui_click()
	var hud = get_tree().root.find_child("TouchHUD", true, false)
	if hud and hud.has_method("spawn_floating_text"):
		hud.spawn_floating_text(car_pivot.global_position, "+%d HP REPAIRED!" % int(amount), Color("2ed573"), 1.2)
	
	# Spawn visual 3D healing plus symbols
	var world_node: Node = get_parent() if get_parent() else (get_tree().root if get_tree() else null)
	if world_node and car_pivot:
		var GadgetClass = load("res://scripts/vehicles/car_gadget_system.gd")
		if GadgetClass and GadgetClass.has_method("spawn_healing_plus_fx"):
			GadgetClass.spawn_healing_plus_fx(world_node, car_pivot.global_position)

## Applies radial physical explosion knockback to the car
func apply_knockback(dir: Vector3, force: float = 24.0) -> void:
	if not physics_sphere:
		return
	var launch_dir := dir.normalized()
	launch_dir.y = maxf(launch_dir.y, 0.45)
	launch_dir = launch_dir.normalized()
	physics_sphere.apply_central_impulse(launch_dir * (force * physics_sphere.mass))
	var rand_torque := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (force * 0.4)
	physics_sphere.apply_torque_impulse(rand_torque)

func _on_physics_sphere_body_entered(body: Node) -> void:
	var impact_speed: float = _previous_velocity.length()
	if body is RigidBody3D:
		impact_speed = (_previous_velocity - (body as RigidBody3D).linear_velocity).length()
	
	var is_ground: bool = (body.name == "Ground") or (body is CollisionObject3D and (body as CollisionObject3D).get_collision_layer_value(1))
	if is_ground:
		if absf(_previous_velocity.y) > 16.0:
			crashed_into_object.emit(impact_speed, body)
	else:
		if gadget_system and gadget_system.has_method("reduce_cooldown"):
			gadget_system.reduce_cooldown(1.0)
		
		if impact_speed > CRASH_VELOCITY_THRESHOLD and _damage_grace_timer <= 0.0:
			_damage_grace_timer = 0.25
			crashed_into_object.emit(impact_speed, body)
			var dmg: float = (impact_speed - 8.5) * 2.8
			dmg = clampf(dmg, 4.0, 32.0)
			
			# EXPLOSIVE BUMPER PERK: 50% less self-damage and mini-explosion against cops
			var cop_car: PoliceCar = null
			if body.get_parent() and body.get_parent() is PoliceCar:
				cop_car = body.get_parent() as PoliceCar
			elif body is PoliceCar:
				cop_car = body as PoliceCar
			
			if cop_car:
				if gear_ram_knockback_bonus > 0.0 and cop_car.physics_sphere:
					var push_dir := (cop_car.global_position - global_position).normalized()
					push_dir.y += 0.35
					cop_car.physics_sphere.apply_central_impulse(push_dir * (14.0 * (1.0 + gear_ram_knockback_bonus) * cop_car.physics_sphere.mass))
					cop_car.take_damage(25.0 * (1.0 + gear_ram_knockback_bonus))
				
				if has_node("/root/WantedManager"):
					var wm = get_node("/root/WantedManager")
					if wm and wm.has_method("has_perk") and wm.has_perk("EXPLOSIVE_BUMPER"):
						dmg *= 0.5
						cop_car.take_damage(50.0)
						if cop_car.physics_sphere:
							var push_dir := (cop_car.global_position - global_position).normalized()
							push_dir.y += 0.4
							cop_car.physics_sphere.apply_central_impulse(push_dir * (22.0 * cop_car.physics_sphere.mass))
			# Boss ram check (Reward player for offensive ramming, especially when boss is stunned!)
			var boss_escape = get_tree().root.find_child("BossEscapeMode", true, false)
			if boss_escape and boss_escape.is_boss_mode and boss_escape.boss_node:
				var is_boss_hit: bool = (body == boss_escape.boss_node or body.get_parent() == boss_escape.boss_node or boss_escape.boss_node.is_ancestor_of(body))
				if is_boss_hit:
					var b_dmg: float = 35.0
					if boss_escape._is_stunned:
						b_dmg = 120.0
					if active_powerup == 3: # Titan Shield
						b_dmg += 50.0
					boss_escape.damage_boss(b_dmg)
					dmg *= 0.3 # Reduced crash recoil for player when ramming boss
			
			# ZERO damage on walls, buildings, curbs, and static world structures
			var is_wall_or_static: bool = body is StaticBody3D or (body is CollisionObject3D and ((body as CollisionObject3D).get_collision_layer_value(4) or (body as CollisionObject3D).get_collision_layer_value(1)))
			if is_wall_or_static:
				dmg = 0.0
			
			if dmg > 0.0:
				take_damage(dmg)
	
	# Check for rival car ram in Hot Loot mode
	var hitting_car: ArcadeCar = null
	if body.get_parent() and body.get_parent() is ArcadeCar:
		hitting_car = body.get_parent() as ArcadeCar
	elif body is ArcadeCar:
		hitting_car = body as ArcadeCar
	
	if hitting_car and hitting_car != self:
		var hot_loot := get_tree().root.find_child("HotLootMode", true, false)
		if hot_loot and hot_loot.has_method("notify_car_collision"):
			hot_loot.notify_car_collision(self, hitting_car)

func _on_run_started(_seed_val: int, _mod_name: String) -> void:
	current_run_ghost_frames.clear()
	_ghost_sample_timer = 0.0
	driving_forces_frozen = false

## Freezes vehicle driving forces on arrest/cutscene
func freeze_driving_forces() -> void:
	driving_forces_frozen = true
	steer_input = 0.0
	is_reversing = false
	if physics_sphere:
		physics_sphere.linear_velocity = Vector3.ZERO
		physics_sphere.angular_velocity = Vector3.ZERO
	if drift_smoke_left:
		drift_smoke_left.emitting = false
	if drift_smoke_right:
		drift_smoke_right.emitting = false

func _on_player_busted(_reason: String, final_score: int, survival_seconds: float, cops_wrecked: int) -> void:
	if not is_ai_rival and peer_owner_id == 1:
		if has_node("/root/SaveManager"):
			var sm = get_node("/root/SaveManager")
			var is_daily: bool = true
			if has_node("/root/DailySeedManager"):
				var dsm = get_node("/root/DailySeedManager")
				is_daily = (dsm.current_mode == 0)
			sm.record_completed_run(final_score, survival_seconds, cops_wrecked, is_daily, current_run_ghost_frames)

func _on_car_equipped(car_id: String) -> void:
	if is_abandoned or is_ai_rival:
		return
	var vdb = null
	if is_inside_tree():
		vdb = get_node_or_null("/root/VehicleDatabase")
	elif Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st and st.root:
			vdb = st.root.get_node_or_null("VehicleDatabase")
	if vdb and vdb.has_car(car_id):
		stats = vdb.get_car_stats(car_id)
		if stats and stats.max_hp > 0.0:
			max_hp = stats.max_hp
			current_hp = max_hp
		if physics_sphere:
			physics_sphere.mass = stats.mass_weight
		_apply_car_visuals(car_id)
		return
	var stats_path: String = "res://resources/vehicles/%s.tres" % car_id
	if ResourceLoader.exists(stats_path):
		stats = load(stats_path) as CarStats
		if stats and stats.max_hp > 0.0:
			max_hp = stats.max_hp
			current_hp = max_hp
		if physics_sphere:
			physics_sphere.mass = stats.mass_weight
		_apply_car_visuals(car_id)

func _apply_car_visuals(car_id: String) -> void:
	if not body_mesh:
		return
	
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.35
	
	match car_id:
		"tuk_tuk_jet":
			mat.albedo_color = Color(1.0, 0.75, 0.08)
			body_mesh.scale = Vector3(0.85, 1.0, 0.85)
		"ice_cream_drifter":
			mat.albedo_color = Color(1.0, 0.55, 0.78)
			body_mesh.scale = Vector3(1.0, 1.05, 1.0)
		"armored_bulldozer":
			mat.albedo_color = Color(0.35, 0.45, 0.3)
			mat.roughness = 0.6
			body_mesh.scale = Vector3(1.25, 1.15, 1.15)
		"cyber_interceptor":
			mat.albedo_color = Color(0.0, 0.88, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.0, 0.4, 0.6)
			body_mesh.scale = Vector3(1.05, 0.82, 1.1)
		"monster_pickup":
			mat.albedo_color = Color(0.04, 0.74, 0.89)
			body_mesh.scale = Vector3(1.2, 1.25, 1.2)
		"gold_limo":
			mat.albedo_color = Color(0.9, 0.49, 0.13)
			body_mesh.scale = Vector3(1.0, 0.9, 1.4)
		"f1_street_kart":
			mat.albedo_color = Color(0.95, 0.77, 0.06)
			body_mesh.scale = Vector3(0.9, 0.75, 1.05)
		_: # default_coupe
			mat.albedo_color = Color(0.92, 0.18, 0.18)
			body_mesh.scale = Vector3.ONE
	
	body_mesh.set_surface_override_material(0, mat)
	
	if voxel_model:
		voxel_model.queue_free()
		voxel_model = null
	
	var existing_v = car_pivot.get_node_or_null("VoxelCarVisual")
	if existing_v:
		existing_v.queue_free()
	
	var vab = get_node_or_null("/root/VoxelAssetBuilder")
	if vab and vab.has_method("build_player_car_visuals"):
		body_mesh.visible = false
		if windshield_mesh:
			windshield_mesh.visible = false
		voxel_model = vab.build_player_car_visuals(car_id)
		voxel_model.name = "VoxelCarVisual"
		voxel_model.position = Vector3(0.0, 0.35, 0.0)
		car_pivot.add_child(voxel_model)
		
		# Phase 12: Attach visual gear loadout & apply stat buffs (only for player's active car)
		var active_loadout: Dictionary = equipped_gear_loadout
		if active_loadout.is_empty() and has_node("/root/SaveManager") and not is_ai_rival and not is_abandoned:
			var sm = get_node("/root/SaveManager")
			active_loadout = sm.equipped_loadout
		
		if vab and vab.has_method("attach_gear_loadout") and not active_loadout.is_empty():
			vab.attach_gear_loadout(car_pivot, active_loadout)
		
		_apply_gear_stats(active_loadout)
	else:
		body_mesh.visible = true
		if windshield_mesh:
			windshield_mesh.visible = true
	
	_setup_mythic_trail(car_id)

## Configures car stats, HP, mass, 3D model, and gadget system for a specific car ID from VehicleDatabase
func set_car_profile(new_car_id: String) -> void:
	car_id = new_car_id
	var vdb = null
	if is_inside_tree():
		vdb = get_node_or_null("/root/VehicleDatabase")
	elif Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st and st.root:
			vdb = st.root.get_node_or_null("VehicleDatabase")
	
	if vdb and vdb.has_car(new_car_id):
		stats = vdb.get_car_stats(new_car_id)
	else:
		stats = CarStats.new()
		stats.car_id = new_car_id
	
	if stats and stats.max_hp > 0.0:
		max_hp = stats.max_hp
	current_hp = max_hp
	
	if physics_sphere and stats:
		physics_sphere.mass = stats.mass_weight
	
	_apply_car_visuals(new_car_id)
	
	if gadget_system:
		gadget_system.gadget_name = ""
		gadget_system.cooldown = 0.0

func _apply_gear_stats(loadout: Dictionary) -> void:
	equipped_gear_loadout = loadout
	gear_ram_knockback_bonus = 0.0
	gear_damage_reduction = 0.0
	
	var armor_mod: String = String(loadout.get("armor_mod", ""))
	match armor_mod:
		"bumper_standard":
			max_hp = 195.0
			current_hp = minf(max_hp, current_hp + 15.0)
		"bumper_spiked":
			gear_ram_knockback_bonus = 0.35
		"armor_titanium":
			max_hp = 225.0
			current_hp = minf(max_hp, current_hp + 45.0)
			gear_damage_reduction = 0.25

func apply_powerup(type: int, duration: float = 6.0) -> void:
	active_powerup = type
	powerup_time_remaining = duration
	powerup_applied.emit(type, duration)
	
	match type:
		0: # NITRO_OVERDRIVE
			busted_progress = 0.0
		1: # EMP_SHOCKWAVE
			_trigger_emp_shockwave()
		2: # OIL_SLICK_DROPPER
			_oil_drop_timer = 0.0
		3: # TITAN_REPAIR_SHIELD
			current_hp = minf(max_hp, current_hp + 60.0)
			_show_titan_shield(true)

func activate_gadget() -> void:
	if has_node("/root/GameModeManager") and int(get_node("/root/GameModeManager").current_mode) == 3:
		# In Kart Grand Prix, individual vehicle gadgets are disabled in favor of gamemode items
		return
	if gadget_system and gadget_system.has_method("activate_gadget"):
		gadget_system.activate_gadget()
		return
	
	# Fallback if gadget_system is missing
	apply_powerup(0, 5.0)
	var forward_dir := -car_pivot.global_transform.basis.z.normalized()
	physics_sphere.apply_central_impulse(forward_dir * (18.0 * physics_sphere.mass))

func _on_perk_applied(perk_id: String) -> void:
	if perk_id == "MEGA_MAGNET":
		current_hp = minf(max_hp, current_hp + 50.0)

## Checks whether the current vehicle is a Tank, Armored Bulldozer, or Rhino Tank
func is_tank() -> bool:
	if current_npc_type == 5: # Fuel Tanker
		return true
	if stats and (stats.car_id == "tanker" or stats.car_id == "armored_bulldozer"):
		return true
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if sm and (sm.equipped_car_id == "tanker" or sm.equipped_car_id == "armored_bulldozer"):
			return true
	return false

## Fires an explosive rocket from the front of the tank
func fire_tank_rocket() -> void:
	if not is_tank() or tank_rocket_cooldown > 0.0 or is_abandoned:
		return
	tank_rocket_cooldown = 2.2
	
	var RocketScript = load("res://scripts/world/explosive_rocket.gd")
	if not RocketScript:
		return
	
	var rocket: Area3D = RocketScript.new()
	var forward_dir: Vector3 = -car_pivot.global_transform.basis.z.normalized()
	var spawn_pos: Vector3 = car_pivot.global_position + Vector3(0.0, 0.7, 0.0) + (forward_dir * 1.8)
	
	rocket.direction = forward_dir
	rocket.shooter = self
	
	var p_parent: Node = get_parent() if get_parent() else (get_tree().root if get_tree() else null)
	if p_parent:
		p_parent.add_child(rocket)
		rocket.global_position = spawn_pos
		rocket.look_at(spawn_pos + forward_dir, Vector3.UP)
	
	# Recoil impulse
	if physics_sphere:
		physics_sphere.apply_central_impulse(-forward_dir * (8.0 * physics_sphere.mass))
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_explosion()
	
	var hud = get_tree().root.find_child("TouchHUD", true, false)
	if hud and hud.has_method("spawn_floating_text"):
		hud.spawn_floating_text(spawn_pos + Vector3.UP, "🚀 ROCKET FIRED!", Color("ff9f43"), 1.0)

# ==============================================================================
# DRIFT BOOST CHARGING & SPARK HELPERS
# ==============================================================================

var current_spark_color: Color = Color.WHITE

func _set_drift_sparks(col: Color, stage: int) -> void:
	current_spark_color = col
	if drift_smoke_left and drift_smoke_left.process_material is ParticleProcessMaterial:
		(drift_smoke_left.process_material as ParticleProcessMaterial).color = col
	if drift_smoke_right and drift_smoke_right.process_material is ParticleProcessMaterial:
		(drift_smoke_right.process_material as ParticleProcessMaterial).color = col
	_show_drift_glow(col, stage)

func _clear_drift_sparks() -> void:
	current_spark_color = Color.WHITE
	if drift_smoke_left and drift_smoke_left.process_material is ParticleProcessMaterial:
		(drift_smoke_left.process_material as ParticleProcessMaterial).color = Color.WHITE
	if drift_smoke_right and drift_smoke_right.process_material is ParticleProcessMaterial:
		(drift_smoke_right.process_material as ParticleProcessMaterial).color = Color.WHITE
	_show_drift_glow(Color.TRANSPARENT, 0)

func _show_drift_glow(col: Color, stage: int) -> void:
	if stage == 0:
		if _drift_glow and is_instance_valid(_drift_glow):
			_drift_glow.visible = false
		return
	
	if not _drift_glow or not is_instance_valid(_drift_glow):
		_drift_glow = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.3
		cyl.bottom_radius = 1.5
		cyl.height = 0.05
		_drift_glow.mesh = cyl
		_drift_glow.position = Vector3(0.0, 0.05, 0.0)
		car_pivot.add_child(_drift_glow)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 3.5 if stage == 2 else 2.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.75
	_drift_glow.material_override = mat
	_drift_glow.visible = true

# ==============================================================================
# MYTHIC TIER PARTICLE TRAILS
# ==============================================================================

func _clear_mythic_trail() -> void:
	current_mythic_car_id = ""
	if mythic_trail and is_instance_valid(mythic_trail):
		mythic_trail.queue_free()
		mythic_trail = null
	if mythic_trail_aux and is_instance_valid(mythic_trail_aux):
		mythic_trail_aux.queue_free()
		mythic_trail_aux = null

func _setup_mythic_trail(car_id: String) -> void:
	_clear_mythic_trail()
	var is_mythic: bool = car_id in ["fire_dragon", "dark_matter_phantom", "ufo_flying_saucer", "cosmic_hyper_star"]
	if not is_mythic or not car_pivot:
		return
	
	current_mythic_car_id = car_id
	
	# Primary trail particles
	mythic_trail = GPUParticles3D.new()
	mythic_trail.name = "MythicTrail"
	mythic_trail.emitting = false
	
	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p_mat.emission_box_extents = Vector3(0.45, 0.08, 0.25)
	p_mat.spread = 24.0
	
	var draw_mesh: Mesh = null
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Secondary auxiliary trail particles
	mythic_trail_aux = GPUParticles3D.new()
	mythic_trail_aux.name = "MythicTrailAux"
	mythic_trail_aux.emitting = false
	var aux_mat := ParticleProcessMaterial.new()
	var aux_draw_mesh: Mesh = null
	var aux_draw_mat := StandardMaterial3D.new()
	aux_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aux_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	match car_id:
		"fire_dragon":
			# Blazing magma scorch & dragon flame trail
			mythic_trail.amount = 44
			mythic_trail.lifetime = 0.65
			p_mat.direction = Vector3(0.0, 0.35, 1.0)
			p_mat.initial_velocity_min = 4.2
			p_mat.initial_velocity_max = 8.5
			p_mat.gravity = Vector3(0.0, 2.2, 0.0)
			p_mat.scale_min = 0.22
			p_mat.scale_max = 0.55
			p_mat.color = Color("ff793f")
			
			var box := BoxMesh.new()
			box.size = Vector3(0.18, 0.18, 0.18)
			draw_mat.albedo_color = Color("ff793f")
			draw_mat.emission_enabled = true
			draw_mat.emission = Color("ff5722")
			draw_mat.emission_energy_multiplier = 3.0
			draw_mesh = box
			
			# Aux: yellow hot sparks & embers
			mythic_trail_aux.amount = 30
			mythic_trail_aux.lifetime = 0.45
			aux_mat.direction = Vector3(0.0, 0.8, 0.6)
			aux_mat.spread = 45.0
			aux_mat.initial_velocity_min = 5.0
			aux_mat.initial_velocity_max = 9.0
			aux_mat.gravity = Vector3(0.0, 3.5, 0.0)
			aux_mat.scale_min = 0.08
			aux_mat.scale_max = 0.16
			aux_mat.color = Color("fff200")
			var s_box := BoxMesh.new()
			s_box.size = Vector3(0.1, 0.1, 0.1)
			aux_draw_mat.albedo_color = Color("fff200")
			aux_draw_mat.emission_enabled = true
			aux_draw_mat.emission = Color("ffeb3b")
			aux_draw_mat.emission_energy_multiplier = 4.0
			aux_draw_mesh = s_box
			
			mythic_trail.position = Vector3(0.0, 0.25, 1.4)
			mythic_trail_aux.position = Vector3(0.0, 0.35, 1.5)
			
		"dark_matter_phantom":
			# Gravitational void rift / cosmic singularity purple ribbons
			mythic_trail.amount = 38
			mythic_trail.lifetime = 0.75
			p_mat.direction = Vector3(0.0, 0.5, 0.8)
			p_mat.initial_velocity_min = 3.0
			p_mat.initial_velocity_max = 6.2
			p_mat.gravity = Vector3(0.0, 2.8, 0.0)
			p_mat.scale_min = 0.25
			p_mat.scale_max = 0.65
			p_mat.color = Color("8e44ad")
			
			var sph := SphereMesh.new()
			sph.radius = 0.16
			sph.height = 0.32
			draw_mat.albedo_color = Color("9b59b6")
			draw_mat.emission_enabled = true
			draw_mat.emission = Color("9b59b6")
			draw_mat.emission_energy_multiplier = 3.2
			draw_mesh = sph
			
			# Aux: floating singularity motes & dark electric neon magenta sparks
			mythic_trail_aux.amount = 28
			mythic_trail_aux.lifetime = 0.85
			aux_mat.direction = Vector3(0.0, 1.0, 0.2)
			aux_mat.spread = 60.0
			aux_mat.initial_velocity_min = 2.0
			aux_mat.initial_velocity_max = 5.0
			aux_mat.gravity = Vector3(0.0, 1.8, 0.0)
			aux_mat.scale_min = 0.1
			aux_mat.scale_max = 0.22
			aux_mat.color = Color("e056fd")
			var a_sph := SphereMesh.new()
			a_sph.radius = 0.08
			a_sph.height = 0.16
			aux_draw_mat.albedo_color = Color("e056fd")
			aux_draw_mat.emission_enabled = true
			aux_draw_mat.emission = Color("e056fd")
			aux_draw_mat.emission_energy_multiplier = 4.5
			aux_draw_mesh = a_sph
			
			mythic_trail.position = Vector3(0.0, 0.3, 1.4)
			mythic_trail_aux.position = Vector3(0.0, 0.4, 1.2)
			
		"ufo_flying_saucer":
			# Emerald anti-gravity levitation field & radiant ion wake
			mythic_trail.amount = 36
			mythic_trail.lifetime = 0.6
			p_mat.direction = Vector3(0.0, -0.2, 0.9)
			p_mat.initial_velocity_min = 3.2
			p_mat.initial_velocity_max = 6.5
			p_mat.gravity = Vector3(0.0, -0.5, 0.0)
			p_mat.scale_min = 0.3
			p_mat.scale_max = 0.7
			p_mat.color = Color("00b894")
			
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.32
			cyl.bottom_radius = 0.32
			cyl.height = 0.03
			draw_mat.albedo_color = Color("2ecc71")
			draw_mat.emission_enabled = true
			draw_mat.emission = Color("2ecc71")
			draw_mat.emission_energy_multiplier = 3.5
			draw_mesh = cyl
			
			# Aux: hovering cyan-lime plasma ripples
			mythic_trail_aux.amount = 26
			mythic_trail_aux.lifetime = 0.5
			aux_mat.direction = Vector3(0.0, -0.5, 0.5)
			aux_mat.spread = 50.0
			aux_mat.initial_velocity_min = 2.5
			aux_mat.initial_velocity_max = 5.5
			aux_mat.gravity = Vector3(0.0, 0.0, 0.0)
			aux_mat.scale_min = 0.12
			aux_mat.scale_max = 0.28
			aux_mat.color = Color("00cec9")
			var a_box := BoxMesh.new()
			a_box.size = Vector3(0.12, 0.04, 0.12)
			aux_draw_mat.albedo_color = Color("55efc4")
			aux_draw_mat.emission_enabled = true
			aux_draw_mat.emission = Color("55efc4")
			aux_draw_mat.emission_energy_multiplier = 4.0
			aux_draw_mesh = a_box
			
			mythic_trail.position = Vector3(0.0, 0.12, 1.1)
			mythic_trail_aux.position = Vector3(0.0, 0.08, 0.6)
			
		"cosmic_hyper_star":
			# Supernova stardust lightspeed streak & stellar flares
			mythic_trail.amount = 52
			mythic_trail.lifetime = 0.6
			p_mat.direction = Vector3(0.0, 0.2, 1.0)
			p_mat.initial_velocity_min = 5.5
			p_mat.initial_velocity_max = 11.0
			p_mat.gravity = Vector3(0.0, 1.2, 0.0)
			p_mat.scale_min = 0.2
			p_mat.scale_max = 0.65
			p_mat.color = Color("fd79a8")
			
			var prism := PrismMesh.new()
			prism.size = Vector3(0.2, 0.2, 0.45)
			draw_mat.albedo_color = Color("fd79a8")
			draw_mat.emission_enabled = true
			draw_mat.emission = Color("e84393")
			draw_mat.emission_energy_multiplier = 3.5
			draw_mesh = prism
			
			# Aux: shimmering gold and diamond stardust sparks
			mythic_trail_aux.amount = 36
			mythic_trail_aux.lifetime = 0.7
			aux_mat.direction = Vector3(0.0, 0.6, 0.7)
			aux_mat.spread = 40.0
			aux_mat.initial_velocity_min = 4.0
			aux_mat.initial_velocity_max = 8.0
			aux_mat.gravity = Vector3(0.0, 1.5, 0.0)
			aux_mat.scale_min = 0.08
			aux_mat.scale_max = 0.18
			aux_mat.color = Color("ffeaa7")
			var a_prism := PrismMesh.new()
			a_prism.size = Vector3(0.12, 0.12, 0.12)
			aux_draw_mat.albedo_color = Color("ffffff")
			aux_draw_mat.emission_enabled = true
			aux_draw_mat.emission = Color("ffffff")
			aux_draw_mat.emission_energy_multiplier = 4.5
			aux_draw_mesh = a_prism
			
			mythic_trail.position = Vector3(0.0, 0.28, 1.45)
			mythic_trail_aux.position = Vector3(0.0, 0.35, 1.55)
	
	draw_mesh.material = draw_mat
	mythic_trail.process_material = p_mat
	mythic_trail.draw_pass_1 = draw_mesh
	car_pivot.add_child(mythic_trail)
	
	aux_draw_mesh.material = aux_draw_mat
	mythic_trail_aux.process_material = aux_mat
	mythic_trail_aux.draw_pass_1 = aux_draw_mesh
	car_pivot.add_child(mythic_trail_aux)

func _pulse_car_mesh() -> void:
	var tw := create_tween()
	tw.tween_property(car_pivot, "scale", Vector3(1.18, 1.18, 1.18), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(car_pivot, "scale", Vector3.ONE, 0.12)

func _trigger_drift_boost(stage: int) -> void:
	var bonus_dur: float = 0.0
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		if wm and wm.has_method("has_perk") and wm.has_perk("NITRO_DRIFT"):
			bonus_dur = 1.0
		if wm and wm.has_method("add_score"):
			wm.add_score(100)
	
	if stage == 1:
		drift_boost_multiplier = 1.35
		drift_boost_time = 1.2 + bonus_dur
	elif stage == 2:
		drift_boost_multiplier = 1.65
		drift_boost_time = 2.0 + bonus_dur
		_trigger_drift_shockwave()
	else:
		# Stage 3 Ultra Mini-Turbo
		drift_boost_multiplier = 1.75
		drift_boost_time = 2.6 + bonus_dur
		_trigger_drift_shockwave()
		var hud = get_tree().root.find_child("TouchHUD", true, false)
		if hud and hud.has_method("spawn_floating_text"):
			hud.spawn_floating_text(car_pivot.global_position + Vector3.UP, "⚡ ULTRA MINI-TURBO!", Color("a55eea"), 1.3)
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_drift_boost()
	
	var hud = get_tree().root.find_child("TouchHUD", true, false)
	if hud and hud.has_method("spawn_floating_text"):
		hud.spawn_floating_text(car_pivot.global_position, "+100 DRIFT BOOST!", Color("00d2d3") if stage == 1 else Color("ff9f43"), 1.2)

func _trigger_drift_shockwave() -> void:
	var origin: Vector3 = car_pivot.global_position
	var cops := get_tree().get_nodes_in_group("police_units")
	for cop in cops:
		if is_instance_valid(cop) and cop is PoliceCar:
			var pc := cop as PoliceCar
			if pc.physics_sphere and origin.distance_to(pc.physics_sphere.global_position) <= 4.5:
				var push_dir := (pc.physics_sphere.global_position - origin).normalized()
				push_dir.y += 0.2
				pc.physics_sphere.apply_central_impulse(push_dir * (5.0 * pc.physics_sphere.mass))

func _trigger_emp_shockwave() -> void:
	var cam_rig = get_tree().root.find_child("CameraRig", true, false)
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.6)
	
	var cops := get_tree().get_nodes_in_group("police_units")
	for cop in cops:
		if is_instance_valid(cop) and cop is PoliceCar:
			var pc := cop as PoliceCar
			if pc.physics_sphere:
				var dist: float = car_pivot.global_position.distance_to(pc.physics_sphere.global_position)
				if dist <= 18.0:
					var upward_dir: Vector3 = Vector3(randf_range(-4, 4), 18.0, randf_range(-4, 4)).normalized()
					pc.physics_sphere.apply_central_impulse(upward_dir * (22.0 * pc.physics_sphere.mass))
					pc.take_damage(60.0)

func _show_titan_shield(enable: bool) -> void:
	if enable:
		if not titan_shield_mesh:
			titan_shield_mesh = MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 1.8
			sphere.height = 3.6
			titan_shield_mesh.mesh = sphere
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.85, 0.1, 0.45)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.emission_enabled = true
			mat.emission = Color("f1c40f")
			mat.emission_energy_multiplier = 2.0
			titan_shield_mesh.material_override = mat
			car_pivot.add_child(titan_shield_mesh)
		titan_shield_mesh.visible = true
	elif titan_shield_mesh:
		titan_shield_mesh.visible = false

func _drop_oil_slick() -> void:
	var slick := Node3D.new()
	slick.name = "OilSlick"
	if get_parent():
		get_parent().add_child(slick)
	elif get_tree() and get_tree().root:
		get_tree().root.add_child(slick)
	
	var forward_dir := -car_pivot.global_transform.basis.z.normalized()
	slick.global_position = car_pivot.global_position - forward_dir * 1.8
	slick.global_position.y = 0.05
	
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.4
	cyl.bottom_radius = 1.4
	cyl.height = 0.04
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("111111")
	mat.metallic = 0.8
	mat.roughness = 0.1
	mi.material_override = mat
	slick.add_child(mi)
	
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 4 # Police
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.6
	cs.shape = sph
	area.add_child(cs)
	slick.add_child(area)
	
	area.body_entered.connect(func(body: Node3D):
		if body is RigidBody3D and body.get_parent() is PoliceCar:
			var pc := body.get_parent() as PoliceCar
			if pc and pc.car_pivot:
				pc.car_pivot.rotation.y += randf_range(2.0, 4.0)
				pc.take_damage(25.0)
	)
	var tw := get_tree().create_timer(10.0)
	tw.timeout.connect(func():
		if is_instance_valid(slick):
			slick.queue_free()
	)

## Escape Road 3 Mechanic: Punctures tires from police spike strips
func puncture_tires(duration: float = 3.5) -> void:
	is_punctured = true
	puncture_timer = duration
	take_damage(20.0)
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_spike_puncture"):
			sfx.play_spike_puncture()

## Escape Road 3 Mechanic: Ejects driver onto foot
func eject_player_character() -> Node3D:
	if is_abandoned:
		return null
	if has_node("/root/GameModeManager") and int(get_node("/root/GameModeManager").current_mode) == 3:
		# Jumping off / on-foot ejection is strictly disabled in Kart Grand Prix
		return null
	is_abandoned = true
	input_enabled = false
	_eject_cooldown = 0.5
	add_to_group("player_vehicles")
	
	if physics_sphere:
		physics_sphere.linear_velocity *= 0.05
		physics_sphere.angular_velocity = Vector3.ZERO
		physics_sphere.linear_damp = 3.5
		physics_sphere.angular_damp = 5.0
	
	var char_scene := load("res://scenes/characters/player_character.tscn") as PackedScene
	if not char_scene:
		return null
	var char_node := char_scene.instantiate() as Node3D
	if "_eject_grace_timer" in char_node:
		char_node._eject_grace_timer = 0.65
	# Preserve persistent on-foot health (player cannot restore health across vehicles)
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		if wm and "player_persistent_hp" in wm and "current_hp" in char_node:
			char_node.current_hp = clampf(wm.player_persistent_hp, 10.0, char_node.max_hp)
	
	var car_pos: Vector3 = car_pivot.global_position if (car_pivot and is_inside_tree()) else position
	var car_basis: Basis = car_pivot.global_transform.basis if (car_pivot and is_inside_tree()) else basis
	var is_in_water: bool = car_pos.y < -0.35 or (physics_sphere and physics_sphere.global_position.y < -0.35)
	var eject_pos := car_pos + (-car_basis.x * 1.6) + Vector3.UP * 0.4
	if is_in_water:
		eject_pos.y = -0.15 # Surface of canal water
	
	var p_node: Node = get_parent() if get_parent() else (get_tree().root if get_tree() else null)
	if p_node:
		p_node.add_child(char_node)
		char_node.global_position = eject_pos
	else:
		char_node.position = eject_pos
	char_node.rotation.y = car_pivot.rotation.y if car_pivot else rotation.y
	
	var left := -car_basis.x.normalized()
	var car_vel := physics_sphere.linear_velocity if physics_sphere else Vector3.ZERO
	if is_in_water:
		char_node.velocity = left * 2.5 + Vector3.UP * 2.0
		if "is_swimming" in char_node:
			char_node.is_swimming = true
	else:
		char_node.velocity = left * 5.0 + Vector3.UP * 5.5 + car_vel * 0.4
	
	# Retarget camera to follow on-foot character
	if get_tree() and get_tree().root:
		var cam_rig = get_tree().root.find_child("CameraRig", true, false)
		if cam_rig:
			cam_rig.target = char_node
			cam_rig.follow_speed = 9.0
		
		# Retarget CityGenerator and TrafficManager to center on running fugitive
		var city_gen = get_tree().root.find_child("CityGenerator", true, false)
		if city_gen:
			city_gen.target_player = char_node
		var traf_mgr = get_tree().root.find_child("TrafficManager", true, false)
		if traf_mgr:
			traf_mgr.target_player = char_node
	
	# Sound & notification
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_ui_click"):
			sfx.play_ui_click()
	
	# Clear any active surrounded state upon exiting vehicle (surrounded only applies in car)
	is_surrounded_alert = false
	busted_progress = 0.0
	if busted_indicator:
		busted_indicator.visible = false
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		if wm and wm.is_surrounded:
			wm.is_surrounded = false
			wm.surrounded_duration = 0.0
			wm.surrounded_heat_timer = 0.0
			wm.player_escaped_surround.emit()
	
	var hud = get_tree().root.find_child("TouchHUD", true, false) if (get_tree() and get_tree().root) else null
	if hud and hud.has_method("spawn_floating_text"):
		var text: String = "🏊 SWIMMING!" if is_in_water else "🏃 ON FOOT!"
		var col: Color = Color("00d2d3") if is_in_water else Color("2ed573")
		hud.spawn_floating_text(eject_pos + Vector3.UP, text, col, 1.25)
	
	# If vehicle is destroyed by damage (not in water), explode after 2.0s
	if current_hp <= 0.0 and not is_in_water and get_tree():
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_instance_valid(self):
				_explode_abandoned_car()
		)
	
	return char_node

## Escape Road 3: Car submerged in canal water. Engine cuts out, car sinks, player pops out swimming.
func submerge_in_water() -> void:
	if is_abandoned:
		return
	
	# Automatically eject player character onto water surface
	var swimmer = eject_player_character()
	
	is_abandoned = true
	input_enabled = false
	driving_forces_frozen = true
	
	# Water drag damping
	if physics_sphere:
		physics_sphere.linear_velocity *= 0.15
		physics_sphere.angular_velocity *= 0.1
	
	# Spawn water splash ring effect
	if is_inside_tree():
		var splash := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 2.2
		cyl.bottom_radius = 1.0
		cyl.height = 0.4
		splash.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.6, 1.0, 0.8)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var parent_node: Node = get_parent() if get_parent() else (get_tree().root if get_tree() else null)
		if parent_node:
			parent_node.add_child(splash)
			if car_pivot and is_inside_tree():
				splash.global_position = car_pivot.global_position + Vector3(0, 0.2, 0)
			var tw := create_tween()
			if tw:
				tw.tween_property(splash, "scale", Vector3(2.5, 1.5, 2.5), 0.45)
				tw.parallel().tween_property(splash, "transparency", 1.0, 0.45)
				tw.tween_callback(splash.queue_free)
			else:
				splash.queue_free()
	
	# Camera trauma
	if is_inside_tree():
		var cam_rig = get_tree().root.find_child("CameraRig", true, false)
		if cam_rig and cam_rig.has_method("add_trauma"):
			cam_rig.add_trauma(0.4)
	
	if swimmer and swimmer is PlayerCharacter:
		swimmer.is_swimming = true
		swimmer.global_position.y = -0.15

## Commandeers an NPC vehicle: transforms 3D visual model, stats, and car health
func adopt_npc_vehicle(npc_type: int) -> void:
	current_npc_type = npc_type
	_clear_mythic_trail()
	var vab = null
	if is_inside_tree():
		vab = get_node_or_null("/root/VoxelAssetBuilder")
	elif Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st and st.root:
			vab = st.root.get_node_or_null("VoxelAssetBuilder")
	
	if vab and vab.has_method("build_npc_traffic_visuals"):
		if voxel_model and is_instance_valid(voxel_model):
			voxel_model.queue_free()
			voxel_model = null
		if car_pivot:
			var existing_v = car_pivot.get_node_or_null("VoxelCarVisual")
			if existing_v:
				existing_v.queue_free()
		
		if body_mesh:
			body_mesh.visible = false
		if windshield_mesh:
			windshield_mesh.visible = false
		
		voxel_model = vab.build_npc_traffic_visuals(npc_type)
		voxel_model.name = "VoxelCarVisual"
		voxel_model.position = Vector3(0.0, 0.35, 0.0)
		if car_pivot:
			car_pivot.add_child(voxel_model)
	
	if not stats:
		stats = CarStats.new()
	
	var prev_ratio: float = current_hp / max_hp if max_hp > 0.0 else 0.55
	var v_name: String = "VEHICLE"
	match npc_type:
		0: # YELLOW_TAXI
			car_id = "yellow_taxi_cab"
			stats.car_id = "yellow_taxi_cab"
			stats.max_speed = 23.0
			stats.turn_speed = 3.6
			stats.drift_grip = 0.85
			max_hp = 180.0
			v_name = "TAXI"
		1: # CITY_BUS
			car_id = "metro_transit_bus"
			stats.car_id = "metro_transit_bus"
			stats.max_speed = 18.0
			stats.turn_speed = 2.4
			stats.drift_grip = 0.95
			if physics_sphere: physics_sphere.mass = 4.2
			max_hp = 260.0
			v_name = "CITY BUS"
		2: # PIZZA_DELIVERY_VAN
			car_id = "pizza_delivery_van"
			stats.car_id = "pizza_delivery_van"
			stats.max_speed = 24.5
			stats.turn_speed = 3.8
			stats.drift_grip = 0.80
			max_hp = 180.0
			v_name = "PIZZA VAN"
		3: # DUMP_TRUCK
			car_id = "garbage_compactor"
			stats.car_id = "garbage_compactor"
			stats.max_speed = 17.5
			stats.turn_speed = 2.5
			if physics_sphere: physics_sphere.mass = 4.5
			max_hp = 280.0
			v_name = "DUMP TRUCK"
		4: # AMBULANCE_VAN
			car_id = "paramedic_rapid"
			stats.car_id = "paramedic_rapid"
			stats.max_speed = 25.0
			stats.turn_speed = 3.5
			max_hp = 190.0
			v_name = "AMBULANCE"
		5: # FUEL_TANKER_SEMI
			car_id = "tanker"
			stats.car_id = "tanker"
			stats.max_speed = 16.5
			stats.turn_speed = 2.2
			if physics_sphere: physics_sphere.mass = 4.8
			max_hp = 250.0
			v_name = "FUEL TANKER"
		_:
			car_id = "yellow_taxi_cab"
			stats.car_id = "yellow_taxi_cab"
			max_hp = 180.0
	
	if gadget_system:
		gadget_system.gadget_name = ""
		gadget_system.cooldown = 0.0
	
	# Preserve damage ratio - player cannot fully restore vehicle health by swapping cars
	if prev_ratio >= 0.99:
		current_hp = max_hp
	else:
		current_hp = clampf(max_hp * prev_ratio, 75.0, max_hp * 0.75)
	
	if is_inside_tree():
		var hud = get_tree().root.find_child("TouchHUD", true, false)
		if hud:
			if hud.has_method("_refresh_gadget_info"):
				hud._refresh_gadget_info()
			if hud.has_method("spawn_floating_text") and car_pivot:
				hud.spawn_floating_text(car_pivot.global_position + Vector3.UP * 1.5, "🚗 DRIVING %s!" % v_name, Color("fbc531"), 1.25)

## Commandeers a Police vehicle: transforms 3D visual model, pursuit stats, and lights
func adopt_police_vehicle(police_type: int) -> void:
	current_npc_type = -1
	_clear_mythic_trail()
	var vab = null
	if is_inside_tree():
		vab = get_node_or_null("/root/VoxelAssetBuilder")
	elif Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st and st.root:
			vab = st.root.get_node_or_null("VoxelAssetBuilder")
	
	if vab and vab.has_method("build_police_car_visuals"):
		if voxel_model and is_instance_valid(voxel_model):
			voxel_model.queue_free()
			voxel_model = null
		if car_pivot:
			var existing_v = car_pivot.get_node_or_null("VoxelCarVisual")
			if existing_v:
				existing_v.queue_free()
		
		if body_mesh:
			body_mesh.visible = false
		if windshield_mesh:
			windshield_mesh.visible = false
		
		voxel_model = vab.build_police_car_visuals(police_type)
		voxel_model.name = "VoxelCarVisual"
		voxel_model.position = Vector3(0.0, 0.35, 0.0)
		if car_pivot:
			car_pivot.add_child(voxel_model)
	
	if not stats:
		stats = CarStats.new()
	
	var prev_ratio: float = current_hp / max_hp if max_hp > 0.0 else 0.55
	var v_name: String = "POLICE CRUISER"
	match police_type:
		1: # INTERCEPTOR_MUSCLE (Comfortable, high-speed agile pursuit)
			car_id = "interceptor_pursuit"
			stats.car_id = "interceptor_pursuit"
			stats.max_speed = 26.0
			stats.turn_speed = 3.8
			stats.drift_grip = 0.88
			max_hp = 250.0
			v_name = "POLICE INTERCEPTOR"
		2: # SWAT_VAN
			car_id = "swat_enforcer_van"
			stats.car_id = "swat_enforcer_van"
			stats.max_speed = 21.0
			stats.turn_speed = 3.0
			stats.drift_grip = 0.92
			if physics_sphere: physics_sphere.mass = 4.2
			max_hp = 360.0
			v_name = "SWAT VAN"
		3: # RHINO_TANK
			car_id = "bat_vigilante_tank"
			stats.car_id = "bat_vigilante_tank"
			stats.max_speed = 18.5
			stats.turn_speed = 2.4
			stats.drift_grip = 0.96
			if physics_sphere: physics_sphere.mass = 8.0
			max_hp = 600.0
			v_name = "RHINO TANK"
		_: # 0: PATROL_CRUISER
			car_id = "patrol_cruiser"
			stats.car_id = "patrol_cruiser"
			stats.max_speed = 23.5
			stats.turn_speed = 3.6
			stats.drift_grip = 0.88
			max_hp = 260.0
			v_name = "POLICE CRUISER"
	
	if gadget_system:
		gadget_system.gadget_name = ""
		gadget_system.cooldown = 0.0
	
	# Commandeered police car grants generous vehicle health (minimum 90% HP) so the player doesn't easily die
	current_hp = maxf(max_hp * 0.90, max_hp * prev_ratio)
	
	if is_inside_tree():
		var hud = get_tree().root.find_child("TouchHUD", true, false)
		if hud:
			if hud.has_method("_refresh_gadget_info"):
				hud._refresh_gadget_info()
			if hud.has_method("spawn_floating_text") and car_pivot:
				hud.spawn_floating_text(car_pivot.global_position + Vector3.UP * 1.5, "🚓 COMMANDEERED %s!" % v_name, Color("00a8ff"), 1.35)

## Resets player car when commandeering an NPC or Police vehicle or respawning
func reset_car_state(new_pos: Vector3, new_basis: Basis, initial_vel: Vector3 = Vector3.ZERO, npc_type: int = -1, police_type: int = -1, new_car_id: String = "") -> void:
	is_abandoned = false
	input_enabled = true
	driving_forces_frozen = false
	busted_progress = 0.0
	_eject_cooldown = 0.5
	
	if not new_car_id.is_empty():
		set_car_profile(new_car_id)
	elif police_type >= 0:
		adopt_police_vehicle(police_type)
	elif npc_type >= 0:
		adopt_npc_vehicle(npc_type)
	else:
		current_hp = minf(current_hp, max_hp * 0.70)
	
	if car_pivot:
		car_pivot.global_position = new_pos
		car_pivot.global_transform.basis = new_basis
	if physics_sphere:
		physics_sphere.global_position = new_pos
		physics_sphere.linear_velocity = initial_vel
		physics_sphere.angular_velocity = Vector3.ZERO
		physics_sphere.linear_damp = 1.6
		physics_sphere.angular_damp = 4.0
	
	if damage_smoke:
		damage_smoke.emitting = false
	
	visible = true

func _explode_abandoned_car() -> void:
	if not is_instance_valid(self):
		return
	_clear_mythic_trail()
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		sfx.play_explosion()
	
	# Blast impulse
	if physics_sphere:
		physics_sphere.linear_damp = 3.5
		physics_sphere.angular_damp = 5.0
		physics_sphere.apply_central_impulse(Vector3(0, 16.0, 0) * physics_sphere.mass)
	
	# Charred material
	var charred := StandardMaterial3D.new()
	charred.albedo_color = Color("111111")
	charred.roughness = 0.95
	if body_mesh:
		body_mesh.material_override = charred
	if voxel_model:
		for c in voxel_model.get_children():
			if c is MeshInstance3D:
				c.material_override = charred
	
	# Persistent Dense Dark Smoke Plume billowing upwards
	if car_pivot:
		var dark_smoke := GPUParticles3D.new()
		dark_smoke.name = "DarkWreckSmoke"
		dark_smoke.amount = 26
		dark_smoke.lifetime = 2.5
		dark_smoke.explosiveness = 0.05
		dark_smoke.randomness = 0.25
		
		var p_mat := ParticleProcessMaterial.new()
		p_mat.direction = Vector3(0.0, 1.0, 0.0)
		p_mat.spread = 24.0
		p_mat.initial_velocity_min = 1.6
		p_mat.initial_velocity_max = 3.4
		p_mat.gravity = Vector3(0.0, 1.4, 0.0)
		p_mat.scale_min = 0.35
		p_mat.scale_max = 1.15
		p_mat.color = Color(0.05, 0.05, 0.05, 0.88)
		dark_smoke.process_material = p_mat
		
		var s_mesh := SphereMesh.new()
		s_mesh.radius = 0.32
		s_mesh.height = 0.64
		var sm_mat := StandardMaterial3D.new()
		sm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm_mat.albedo_color = Color(0.05, 0.05, 0.05, 0.82)
		s_mesh.material = sm_mat
		dark_smoke.draw_pass_1 = s_mesh
		
	# Visual Explosion FX (Valorant-style directional splash burst)
	var blast_pos := car_pivot.global_position if car_pivot else global_position
	var world_parent: Node = get_parent() if get_parent() else (get_tree().root if get_tree() else null)
	if world_parent:
		ExplosionFX.spawn_splash(world_parent, blast_pos, 1.25)
	
	# Despawn wrecked/abandoned car after 10 seconds
	if get_tree():
		get_tree().create_timer(10.0, true, false, true).timeout.connect(func():
			if is_instance_valid(self) and is_abandoned:
				queue_free()
		)
	
	# Screen shake
	var cam_rig = get_tree().root.find_child("CameraRig", true, false)
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.5)

## Kart Mode Helpers & Combat Actions
func apply_kart_boost(multiplier: float, duration: float) -> void:
	drift_boost_multiplier = multiplier
	drift_boost_time = duration
	_pulse_car_mesh()

func spin_out(duration: float = 1.3, speed_factor: float = 0.45) -> void:
	if has_node("KartItemSystem") and get_node("KartItemSystem").is_gold_star_active():
		return
	if physics_sphere:
		physics_sphere.linear_velocity *= speed_factor
	if car_pivot:
		var tw := create_tween()
		tw.tween_property(car_pivot, "rotation:y", car_pivot.rotation.y + TAU * 2.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_tire_screech"):
			sfx.play_tire_screech()

func blast_flip(is_plasma: bool = false) -> void:
	if has_node("KartItemSystem") and get_node("KartItemSystem").is_gold_star_active():
		return
	if physics_sphere:
		var up_force: float = 28.0 if is_plasma else 18.0
		physics_sphere.linear_velocity = Vector3(physics_sphere.linear_velocity.x * 0.2, up_force, physics_sphere.linear_velocity.z * 0.2)
	if car_pivot:
		var tw := create_tween()
		tw.tween_property(car_pivot, "rotation:x", car_pivot.rotation.x + TAU, 0.75)
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_explosion"):
			sfx.play_explosion()
