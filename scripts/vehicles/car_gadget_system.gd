class_name CarGadgetSystem
extends Node3D

const ValorantSkillVFX = preload("res://scripts/world/valorant_skill_vfx.gd")

## Phase 10: Active Car Roof Weapons & Gadget Abilities
## Handles unique 7.0s cooldown vehicle abilities with prop/cop hit reduction,
## desktop keyboard inputs (Spacebar / Key E), and TouchHUD sync.

signal gadget_activated(car_id: String, gadget_title: String)
signal cooldown_updated(current_cooldown: float, max_cooldown: float)

@export var max_cooldown: float = 7.0
var cooldown: float = 0.0
var gadget_name: String = ""

var car: ArcadeCar = null

# Active Buff Trackers
var is_crusher_active: bool = false
var crusher_timer: float = 0.0
var original_car_scale: Vector3 = Vector3.ONE

var is_drs_active: bool = false
var drs_timer: float = 0.0
var original_max_speed: float = 30.0
var original_grip: float = 0.85

var decoy_timer: float = 0.0
var active_decoy: Node3D = null

func _ready() -> void:
	if get_parent() is ArcadeCar:
		car = get_parent() as ArcadeCar

func _unhandled_input(event: InputEvent) -> void:
	if not car or not car.has_local_authority() or not car.input_enabled:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_Q or event.keycode == KEY_SHIFT:
			activate_gadget()

func _process(delta: float) -> void:
	if cooldown > 0.0:
		cooldown = maxf(0.0, cooldown - delta)
		cooldown_updated.emit(cooldown, get_effective_max_cooldown())
	
	# Crusher Stomp timer
	if is_crusher_active:
		crusher_timer -= delta
		_process_crusher_contact()
		if crusher_timer <= 0.0:
			_end_crusher()
	
	# DRS Sonic Slipstream timer
	if is_drs_active:
		drs_timer -= delta
		if drs_timer <= 0.0:
			_end_drs()
	
	# Decoy Limo timer
	if decoy_timer > 0.0:
		decoy_timer -= delta
		if decoy_timer <= 0.0:
			_end_decoy()

func get_effective_max_cooldown() -> float:
	var cd: float = max_cooldown
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		if wm and wm.has_method("has_perk") and wm.has_perk("OVERCLOCKED_GADGET"):
			cd *= 0.65 # 35% reduction
	return cd

## Reduces cooldown on impact (e.g. smashed props or wrecked cops)
func reduce_cooldown(amount: float = 1.0) -> void:
	if cooldown > 0.0:
		cooldown = maxf(0.0, cooldown - amount)
		cooldown_updated.emit(cooldown, get_effective_max_cooldown())

func can_activate() -> bool:
	return cooldown <= 0.0 and car != null and car.current_hp > 0.0

## Triggers the active car roof gadget
func activate_gadget() -> bool:
	if not can_activate():
		return false
	
	cooldown = get_effective_max_cooldown()
	cooldown_updated.emit(cooldown, get_effective_max_cooldown())
	
	var car_id: String = _get_car_id()
	gadget_name = ""
	
	var vdb = null
	if is_inside_tree():
		vdb = get_node_or_null("/root/VehicleDatabase")
	elif Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st and st.root:
			vdb = st.root.get_node_or_null("VehicleDatabase")
	
	var gadget_id: String = ""
	if vdb and vdb.has_car(car_id):
		var cinfo: Dictionary = vdb.get_car(car_id)
		gadget_id = String(cinfo.get("gadget_id", ""))
		gadget_name = String(cinfo.get("gadget_name", ""))
	
	match gadget_id:
		"TWIN_ROCKETS":
			_activate_twin_rockets()
		"AFTERBURNER_LEAP":
			_activate_afterburner_leap()
		"SEISMIC_SLAM", "SEISMIC_MEGA_SLAM":
			_activate_seismic_slam()
		"BLIZZARD_BOMB":
			_activate_blizzard_bomb()
		"WARP_DASH":
			_activate_warp_dash()
		"CRUSHER_STOMP":
			_activate_crusher_stomp()
		"CASH_DECOY", "VIP_CASH_DECOY":
			_activate_cash_decoy()
		"DRS_SLIPSTREAM":
			_activate_drs_slipstream()
		"SMOKE_SCREEN":
			_activate_smoke_screen()
		"VTEC_OVERREV":
			_activate_vtec_boost()
		"HANDBRAKE_WHIP":
			_activate_handbrake_whip()
		"V8_ROAR":
			_activate_v8_roar()
		"BURNOUT_BLAST":
			_activate_burnout_blast()
		"MID_AIR_IMPULSE":
			_activate_dune_jump()
		"WINCH_PULL":
			_activate_winch_pull()
		"STEAM_WHISTLE":
			_activate_steam_whistle()
		"TRASH_DUMP":
			_activate_trash_dump()
		"MOLTEN_TAR":
			_activate_molten_tar()
		"SIREN_BURST":
			_activate_siren_burst()
		"DEFIB_ZAP":
			_activate_defib_zap()
		"TAXI_OVERDRIVE":
			_activate_taxi_overdrive()
		"STOP_SIGN_RAM":
			_activate_stop_sign_ram()
		"CHEESE_SLICK":
			_activate_cheese_slick()
		"CARDBOARD_DROP":
			_activate_cardboard_roadblock()
		"MAIL_CANNON":
			_activate_mail_cannon()
		"DUST_CLOUD":
			_activate_dust_cloud()
		"LUGGAGE_FLAIL":
			_activate_luggage_flail()
		"FORKLIFT_SLAM":
			_activate_forklift_lift()
		"ACROBATIC_SPIN":
			_activate_acrobatic_spin()
		"PEACE_SMOKE":
			_activate_peace_smoke()
		"SURF_PROJECTILE":
			_activate_surfboard_launch()
		"ITALIAN_JOB_SWERVE":
			_activate_italian_job_swerve()
		"HOT_SAUCE":
			_activate_hot_sauce()
		"SUGAR_RUSH":
			_activate_sugar_rush()
		"MUSTARD_SQUIRT":
			_activate_mustard_squirt()
		"LUGGAGE_EJECT":
			_activate_luggage_eject()
		"ELECTRO_ZIP":
			_activate_electro_zip()
		"APEX_DRIFT_SURGE":
			_activate_apex_surge()
		"TWIN_TURBO_BURST":
			_activate_twin_turbo()
		"HYDRAULIC_HOP":
			_activate_hydraulic_hop()
		"WHEELIE_STOMP":
			_activate_wheelie_stomp()
		"NITROUS_BURNOUT":
			_activate_nitrous_burnout()
		"BLOWER_SURGE":
			_activate_blower_surge()
		"SMOKE_VEIL":
			_activate_smoke_veil()
		"COIL_BOUNCE":
			_activate_coil_bounce()
		"ROOF_FLOODLIGHT":
			_activate_floodlight()
		"SNOW_PLOW_CLEAVE":
			_activate_snow_plow()
		"SLIME_TRAIL":
			_activate_slime_trail()
		"WET_CEMENT_SLICK":
			_activate_wet_cement()
		"BUCKET_SWIPE":
			_activate_bucket_swipe()
		"LOG_ROADBLOCK":
			_activate_log_drop()
		"HARPOON_HOOK":
			_activate_crane_hook()
		"HOMING_SPIKE":
			_activate_homing_spike()
		"HOSE_WATER_CANNON":
			_activate_water_cannon()
		"TINTED_EMP_JAMMER":
			_activate_emp_jammer()
		"VAULT_LOCKDOWN":
			_activate_vault_scatter()
		"PASSENGER_CHEER":
			_activate_upper_deck_horn()
		"HYDRAULIC_RAMP":
			_activate_tow_ramp()
		"ROCK_N_ROLL_BLAST":
			_activate_jukebox_blast()
		"TOMMY_GUN_BURST":
			_activate_tommy_gun()
		"LUNAR_JUMP":
			_activate_lunar_thruster()
		"BOILER_OVERPRESSURE":
			_activate_steam_ram()
		"TORPEDO_WAKE":
			_activate_torpedo_wake()
		"GYRO_SPIN":
			_activate_gyro_cyclone()
		"GOTHIC_FLAME":
			_activate_candelabra_flame()
		"ANTILAG_FLAME":
			_activate_antilag_flame()
		"SUPERCHARGED_DRIFT":
			_activate_supercharged_drift()
		"OPEN_PIPE_TRAIL":
			_activate_open_pipe_trail()
		"TORQUE_SMASH":
			_activate_torque_smash()
		"TURBO_SPOOL":
			_activate_turbo_spool()
		"SONIC_SCREAM":
			_activate_sonic_scream()
		"BULL_CHARGE_RAM":
			_activate_bull_charge()
		"SANDSTORM_BLIND":
			_activate_sandstorm_blind()
		"MUD_SPRAY_BLIND":
			_activate_mud_spray()
		"RAMMING_PROW":
			_activate_ramming_prow()
		"BOULDER_DUMP":
			_activate_boulder_dump()
		"ARMORED_SLAM":
			_activate_armored_slam()
		"FLASHBANG_BLAST":
			_activate_flashbang_blast()
		"FOAM_FIRE_BLIND":
			_activate_foam_cannon()
		"DUAL_WATER_JETS":
			_activate_water_jets()
		"TURRET_FIRE":
			_activate_turret_fire()
		"SILVER_ARROW_DASH":
			_activate_silver_arrow_dash()
		"LE_MANS_ROAR":
			_activate_le_mans_roar()
		"TIME_FIRE_LEAP":
			_activate_time_fire_leap()
		"VTOL_JET_THRUSTER":
			_activate_vtol_thruster()
		"QUANTUM_PHASE":
			_activate_quantum_phase()
		"TURBO_ANTILAG_BURST":
			_activate_turbo_antilag_burst()
		"SIDEPIPE_BLAST":
			_activate_sidepipe_blast()
		"PARACHUTE_AIRBRAKE":
			_activate_parachute_airbrake()
		"STEALTH_CLOAK":
			_activate_stealth_cloak()
		"MACH_HYPERDRIVE":
			_activate_mach_hyperdrive()
		"KERS_BOOST":
			_activate_kers_boost()
		"GRAVITON_REPULSOR":
			_activate_graviton_repulsor()
		"LASER_WALL_TRAIL":
			_activate_laser_wall_trail()
		"STEALTH_AFTERBURNER":
			_activate_stealth_afterburner()
		"SOLID_ROCKET_FIRE":
			_activate_solid_rocket_fire()
		"DRAGON_FLAME":
			_activate_dragon_flame()
		"SINGULARITY_VORTEX":
			_activate_singularity_vortex()
		"TRACTOR_BEAM_LIFT":
			_activate_tractor_beam_lift()
		"SUPERNOVA_BLAST":
			_activate_supernova_blast()
		_:
			match car_id:
				"default_coupe":
					gadget_name = "TWIN REAR ROCKETS"
					_activate_twin_rockets()
				"tuk_tuk_jet":
					gadget_name = "AFTERBURNER SKY-LEAP"
					_activate_afterburner_leap()
				"armored_bulldozer":
					gadget_name = "SEISMIC MEGA-SLAM"
					_activate_seismic_slam()
				"ice_cream_drifter":
					gadget_name = "FROSTY BLIZZARD BOMB"
					_activate_blizzard_bomb()
				"cyber_interceptor":
					gadget_name = "PHANTOM WARP DASH"
					_activate_warp_dash()
				"monster_pickup":
					gadget_name = "CRUSHER STOMP"
					_activate_crusher_stomp()
				"gold_limo":
					gadget_name = "VIP CASH MAGNET & DECOY"
					_activate_cash_decoy()
				"f1_street_kart":
					gadget_name = "DRS SONIC SLIPSTREAM"
					_activate_drs_slipstream()
				_:
					if gadget_name.is_empty():
						gadget_name = "NITRO OVERDRIVE"
					_activate_generic_boost()
	
	gadget_activated.emit(car_id, gadget_name)
	
	# Spawn Floating Combat Text on TouchHUD
	var hud = _find_hud()
	if hud and hud.has_method("spawn_floating_text") and car and car.car_pivot:
		var icon: String = _get_gadget_icon(gadget_id)
		var col: Color = _get_gadget_color(gadget_id)
		hud.spawn_floating_text(car.car_pivot.global_position, "%s %s!" % [icon, gadget_name], col, 1.3)
	
	# Camera trauma shake
	var cam_rig = get_tree().root.find_child("CameraRig", true, false)
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.55)
	
	return true

func _get_gadget_icon(gid: String) -> String:
	var g := gid.to_upper()
	if "DEFIB" in g or "HEAL" in g or "REPAIR" in g or "MEDKIT" in g:
		return "🩹"
	if "SIREN" in g or "POLICE" in g:
		return "🚨"
	if "LIGHT" in g or "FLASH" in g:
		return "💡"
	if "ROCKET" in g or "MISSILE" in g:
		return "🚀"
	if "LEAP" in g or "JUMP" in g or "HOP" in g or "BOUNCE" in g or "THRUSTER" in g:
		return "🦘"
	if "SLAM" in g or "RAM" in g or "STOMP" in g or "CRUSHER" in g or "BULL" in g:
		return "💥"
	if "BLIZZARD" in g or "ICE" in g or "FROST" in g:
		return "❄️"
	if "WARP" in g or "QUANTUM" in g or "PHASE" in g or "SINGULARITY" in g or "GRAVITON" in g:
		return "🌐"
	if "FLAME" in g or "FIRE" in g or "MOLTEN" in g or "DRAGON" in g or "ANTILAG" in g:
		return "🔥"
	if "CASH" in g or "COIN" in g or "VAULT" in g:
		return "💰"
	if "SAUCE" in g or "MUSTARD" in g or "SLIME" in g or "CHEESE" in g or "CEMENT" in g or "PAINT" in g:
		return "🎨"
	if "TRASH" in g or "CARDBOARD" in g or "BOULDER" in g or "LOG" in g or "ROADBLOCK" in g:
		return "📦"
	if "WATER" in g or "HOSE" in g or "TORPEDO" in g:
		return "🌊"
	if "GUN" in g or "TURRET" in g or "CANNON" in g or "SPIKE" in g:
		return "🎯"
	if "SMOKE" in g or "VEIL" in g or "DUST" in g or "SANDSTORM" in g:
		return "🌫️"
	if "CLOAK" in g or "STEALTH" in g:
		return "👻"
	if "ELECTRO" in g or "ZAP" in g or "EMP" in g:
		return "⚡"
	if "TURBO" in g or "V8" in g or "VTEC" in g or "BLOWER" in g or "KERS" in g or "MACH" in g or "SPEED" in g or "DRS" in g:
		return "🏎️"
	return "⚡"

func _get_gadget_color(gid: String) -> Color:
	var g := gid.to_upper()
	if "DEFIB" in g or "HEAL" in g or "REPAIR" in g:
		return Color("2ed573")
	if "SIREN" in g or "POLICE" in g or "GUN" in g or "TURRET" in g:
		return Color("ff4757")
	if "LIGHT" in g or "FLASH" in g or "CHEESE" in g or "MUSTARD" in g:
		return Color("ffa502")
	if "ROCKET" in g or "FLAME" in g or "FIRE" in g:
		return Color("ff6348")
	if "BLIZZARD" in g or "ICE" in g or "WATER" in g:
		return Color("70a1ff")
	if "WARP" in g or "QUANTUM" in g or "ELECTRO" in g or "ZAP" in g:
		return Color("00d2d3")
	if "CASH" in g or "GOLD" in g:
		return Color("f1c40f")
	if "TRASH" in g or "LOG" in g or "CARDBOARD" in g or "BOULDER" in g:
		return Color("eccc68")
	return Color("00d2d3")

func _get_car_id() -> String:
	if car and car.stats and not car.stats.car_id.is_empty():
		return car.stats.car_id
	if car and not car.car_id.is_empty():
		return car.car_id
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		return sm.equipped_car_id
	return "default_coupe"

func _find_hud() -> Node:
	if not get_tree() or not get_tree().root:
		return null
	return get_tree().root.find_child("TouchHUD", true, false)

# ==============================================================================
# 1. DEFAULT COUPE: TWIN REAR ROCKETS
# ==============================================================================
func _activate_twin_rockets() -> void:
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_drift_boost()
	
	# Find closest 2 cops
	var cops := get_tree().get_nodes_in_group("police_units")
	var valid_cops: Array[PoliceCar] = []
	for c in cops:
		if is_instance_valid(c) and c is PoliceCar and not (c as PoliceCar).is_wrecked:
			valid_cops.append(c as PoliceCar)
	
	# Sort by distance
	var p_pos: Vector3 = car.car_pivot.global_position
	valid_cops.sort_custom(func(a: PoliceCar, b: PoliceCar) -> bool:
		return p_pos.distance_squared_to(a.global_position) < p_pos.distance_squared_to(b.global_position)
	)
	
	for i in range(mini(2, valid_cops.size())):
		var target_cop: PoliceCar = valid_cops[i]
		_spawn_homing_missile(target_cop, i == 0)

func _get_world_node() -> Node:
	if get_tree() and get_tree().current_scene:
		return get_tree().current_scene
	if get_tree() and get_tree().root:
		return get_tree().root
	if get_parent() and get_parent().get_parent():
		return get_parent().get_parent()
	return get_parent() if get_parent() else self

func _add_to_world(node: Node3D) -> void:
	var p := _get_world_node()
	if p:
		p.add_child(node)

## Spawns stylized 3D "+" plus symbols and green healing aura for healing skills/medkits
static func spawn_healing_plus_fx(parent: Node, origin: Vector3) -> Node3D:
	if not parent or not is_instance_valid(parent):
		return null
	var root := Node3D.new()
	root.name = "HealingPlusFX"
	root.position = origin
	parent.add_child(root)
	
	# 1. Soft green ground aura ring
	var ring := MeshInstance3D.new()
	ring.name = "HealAuraRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.75
	torus.rings = 16
	torus.ring_segments = 14
	ring.mesh = torus
	var r_mat := StandardMaterial3D.new()
	r_mat.albedo_color = Color("2ed573")
	r_mat.emission_enabled = true
	r_mat.emission = Color("2ecc71")
	r_mat.emission_energy_multiplier = 3.0
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = r_mat
	ring.position.y = 0.08
	root.add_child(ring)
	
	# 2. Gentle green omni flash
	var flash := OmniLight3D.new()
	flash.name = "HealFlashLight"
	flash.light_color = Color("2ed573")
	flash.light_energy = 2.4
	flash.omni_range = 6.0
	root.add_child(flash)
	
	# 3. 5 floating 3D "+" plus symbols
	var plus_mat := StandardMaterial3D.new()
	plus_mat.albedo_color = Color("2ed573")
	plus_mat.emission_enabled = true
	plus_mat.emission = Color("2ecc71")
	plus_mat.emission_energy_multiplier = 4.0
	plus_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plus_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	var offsets = [
		Vector3(-0.65, 0.35, -0.4),
		Vector3(0.65, 0.45, -0.3),
		Vector3(-0.5, 0.30, 0.5),
		Vector3(0.55, 0.40, 0.6),
		Vector3(0.0, 0.65, 0.0)
	]
	
	for i in range(offsets.size()):
		var p_node := Node3D.new()
		p_node.name = "PlusSymbol_%d" % i
		p_node.position = offsets[i]
		root.add_child(p_node)
		
		# Horizontal bar of plus
		var h_mesh := MeshInstance3D.new()
		var h_box := BoxMesh.new()
		h_box.size = Vector3(0.32, 0.09, 0.08)
		h_mesh.mesh = h_box
		h_mesh.material_override = plus_mat
		p_node.add_child(h_mesh)
		
		# Vertical bar of plus
		var v_mesh := MeshInstance3D.new()
		var v_box := BoxMesh.new()
		v_box.size = Vector3(0.09, 0.32, 0.08)
		v_mesh.mesh = v_box
		v_mesh.material_override = plus_mat
		p_node.add_child(v_mesh)
		
		# Animate floating upward, rotating & scaling
		var tw := p_node.create_tween().set_parallel(true)
		var rise_h: float = randf_range(1.6, 2.3)
		tw.tween_property(p_node, "position:y", p_node.position.y + rise_h, 0.70).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p_node, "rotation:y", randf_range(-1.8, 1.8), 0.70)
		tw.tween_property(p_node, "scale", Vector3(1.2, 1.2, 1.2), 0.30)
		tw.chain().tween_property(p_node, "scale", Vector3.ZERO, 0.40)
	
	# Ring and flash animation
	var r_tw := root.create_tween().set_parallel(true)
	r_tw.tween_property(ring, "scale", Vector3(2.5, 1.0, 2.5), 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	r_tw.tween_property(ring, "transparency", 1.0, 0.50)
	r_tw.tween_property(flash, "light_energy", 0.0, 0.38)
	
	r_tw.chain().tween_interval(0.35)
	r_tw.chain().tween_callback(root.queue_free)
	return root

## Spawns dynamic glossy paint splatter on the road with organic droplets and skid hazard
static func spawn_paint_splat_fx(parent: Node, origin: Vector3, col: Color, splat_radius: float = 3.5, droplet_count: int = 14) -> Node3D:
	if not parent or not is_instance_valid(parent):
		return null
	var root := Node3D.new()
	root.name = "PaintSplatFX"
	root.position = origin
	parent.add_child(root)
	
	# Shared glossy wet paint material
	var paint_mat := StandardMaterial3D.new()
	paint_mat.albedo_color = col
	paint_mat.roughness = 0.12 # Glossy wet liquid look
	paint_mat.metallic = 0.10
	paint_mat.emission_enabled = true
	paint_mat.emission = col * 0.45
	paint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# 1. Central Glossy Paint Puddle
	var puddle := MeshInstance3D.new()
	puddle.name = "PaintPuddle"
	var cyl := CylinderMesh.new()
	cyl.top_radius = splat_radius * 0.36
	cyl.bottom_radius = splat_radius * 0.40
	cyl.height = 0.025
	puddle.mesh = cyl
	puddle.material_override = paint_mat
	puddle.position.y = 0.03
	puddle.scale = Vector3(0.1, 1.0, 0.1)
	root.add_child(puddle)
	
	var p_tw := puddle.create_tween()
	p_tw.tween_property(puddle, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 2. Organic Perimeter Splatter Splotches
	var splotch_count: int = 8
	for s in range(splotch_count):
		var angle: float = (float(s) / float(splotch_count)) * TAU + randf_range(-0.35, 0.35)
		var dist: float = randf_range(splat_radius * 0.45, splat_radius * 0.85)
		var splotch := MeshInstance3D.new()
		splotch.name = "SplatDot_%d" % s
		var dot_cyl := CylinderMesh.new()
		var s_radius: float = randf_range(0.20, 0.48)
		dot_cyl.top_radius = s_radius * 0.9
		dot_cyl.bottom_radius = s_radius
		dot_cyl.height = 0.02
		splotch.mesh = dot_cyl
		splotch.material_override = paint_mat
		splotch.position = Vector3(cos(angle) * dist, 0.025, sin(angle) * dist)
		splotch.scale = Vector3(0.05, 1.0, 0.05)
		root.add_child(splotch)
		
		var s_tw := splotch.create_tween()
		s_tw.tween_interval(randf_range(0.02, 0.08))
		s_tw.tween_property(splotch, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 3. Airborne Flying Paint Droplet Globules
	for d in range(droplet_count):
		var drop := MeshInstance3D.new()
		drop.name = "PaintDroplet_%d" % d
		var sph := SphereMesh.new()
		var d_size: float = randf_range(0.08, 0.15)
		sph.radius = d_size
		sph.height = d_size * 2.0
		drop.mesh = sph
		drop.material_override = paint_mat
		drop.position = Vector3(randf_range(-0.2, 0.2), 0.25, randf_range(-0.2, 0.2))
		root.add_child(drop)
		
		var d_angle: float = randf_range(0.0, TAU)
		var d_dist: float = randf_range(splat_radius * 0.5, splat_radius * 1.1)
		var target_pos := Vector3(cos(d_angle) * d_dist, 0.025, sin(d_angle) * d_dist)
		var peak_y: float = randf_range(0.8, 1.6)
		
		var d_tw := drop.create_tween()
		d_tw.tween_property(drop, "position:y", peak_y, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		d_tw.parallel().tween_property(drop, "position:x", target_pos.x, 0.36)
		d_tw.parallel().tween_property(drop, "position:z", target_pos.z, 0.36)
		d_tw.chain().tween_property(drop, "position:y", target_pos.y, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		d_tw.tween_callback(func():
			if is_instance_valid(drop):
				drop.scale = Vector3(1.5, 0.2, 1.5)
		)
	
	# 4. Skid Hazard Area
	var area := Area3D.new()
	area.name = "PaintHazardArea"
	area.collision_layer = 0
	area.collision_mask = 4 # Police
	var col_shape := CollisionShape3D.new()
	var sph_shape := SphereShape3D.new()
	sph_shape.radius = splat_radius
	col_shape.shape = sph_shape
	area.add_child(col_shape)
	root.add_child(area)
	
	area.body_entered.connect(func(body: Node3D):
		if body is RigidBody3D and body.get_parent() is PoliceCar:
			var pc := body.get_parent() as PoliceCar
			if pc and pc.car_pivot and not pc.is_wrecked:
				pc.car_pivot.rotation.y += randf_range(-2.5, 2.5)
				pc.take_damage(20.0)
	)
	
	# 5. Clean up after 5.0 seconds
	var cleanup_tw := root.create_tween()
	cleanup_tw.tween_interval(5.0)
	cleanup_tw.tween_property(paint_mat, "albedo_color:a", 0.0, 0.6)
	cleanup_tw.tween_callback(root.queue_free)
	return root

func _spawn_electric_zap_fx(origin: Vector3) -> void:
	var p_node := _get_world_node()
	var zap := Node3D.new()
	zap.name = "ElectricZapFX"
	zap.position = origin + Vector3.UP * 0.5
	p_node.add_child(zap)
	
	var light := OmniLight3D.new()
	light.name = "ZapLight"
	light.light_color = Color("00d2d3")
	light.light_energy = 4.5
	light.omni_range = 8.0
	zap.add_child(light)
	
	var tw := zap.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.24)
	tw.tween_callback(zap.queue_free)

func _spawn_homing_missile(target_cop: PoliceCar, left_side: bool) -> void:
	var missile := Node3D.new()
	missile.name = "HomingRocket"
	_add_to_world(missile)
	
	var side_offset := car.car_pivot.global_transform.basis.x * (0.8 if left_side else -0.8)
	var rear_offset := car.car_pivot.global_transform.basis.z * 1.5
	missile.global_position = car.car_pivot.global_position + side_offset + rear_offset + Vector3.UP * 0.6
	
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.15
	cyl.bottom_radius = 0.22
	cyl.height = 1.0
	mesh.mesh = cyl
	mesh.rotation_degrees.x = 90.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ff4757")
	mat.emission_enabled = true
	mat.emission = Color("ff6b81")
	mat.emission_energy_multiplier = 3.0
	mesh.material_override = mat
	missile.add_child(mesh)
	
	# Launch toward cop
	var tw := missile.create_tween()
	var hit_pos: Vector3 = target_cop.global_position + Vector3.UP * 0.5
	tw.tween_property(missile, "global_position", hit_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(target_cop) and not target_cop.is_wrecked:
			target_cop.wreck(Vector3.UP * 16.0)
		if has_node("/root/SoundFX"):
			get_node("/root/SoundFX").play_explosion()
		missile.queue_free()
	)

# ==============================================================================
# 2. TUK TUK JET: AFTERBURNER SKY-LEAP
# ==============================================================================
func _activate_afterburner_leap() -> void:
	if not car or not car.physics_sphere:
		return
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_drift_boost()
	
	# Launch 9 meters into air + forward boost
	var forward_dir: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var launch_force: Vector3 = Vector3.UP * (18.0 * car.physics_sphere.mass) + forward_dir * (16.0 * car.physics_sphere.mass)
	car.physics_sphere.apply_central_impulse(launch_force)
	
	# 2.5s Jet speed boost
	car.apply_powerup(0, 2.5)

# ==============================================================================
# 3. ARMORED BULLDOZER: SEISMIC MEGA-SLAM
# ==============================================================================
func _activate_seismic_slam() -> void:
	if not car or not car.physics_sphere or not car.car_pivot:
		return
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_smash_hit()
	
	# Front blade slam pitch punch
	var tw := car.create_tween()
	if car.body_mesh:
		tw.tween_property(car.body_mesh, "rotation:x", 0.45, 0.08)
		tw.chain().tween_property(car.body_mesh, "rotation:x", 0.0, 0.15)
	
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var p_node := _get_world_node()
	ValorantSkillVFX.spawn_earth_spikes_rupture(p_node, car.car_pivot.global_position, fwd, {
		"count": 6,
		"spacing": 2.4,
		"max_height": 2.8,
		"damage": 65.0
	})
	
	# 14m Golden Shockwave Ring Visual
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 1.0
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("f1c40f")
	mat.emission_enabled = true
	mat.emission = Color("f39c12")
	mat.emission_energy_multiplier = 4.0
	_add_to_world(ring)
	ring.global_position = car.car_pivot.global_position + Vector3(0.0, 0.2, 0.0)
	
	var ring_tw := ring.create_tween().set_parallel(true)
	ring_tw.tween_property(ring, "scale", Vector3(14.0, 1.0, 14.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tw.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	ring_tw.chain().tween_callback(ring.queue_free)
	
	# Flip all cops and NPCs within 14 meters
	var origin: Vector3 = car.car_pivot.global_position
	var cops := get_tree().get_nodes_in_group("police_units")
	for cop in cops:
		if is_instance_valid(cop) and cop is PoliceCar:
			var pc := cop as PoliceCar
			if pc.physics_sphere and origin.distance_to(pc.physics_sphere.global_position) <= 14.0:
				var away_dir := (pc.physics_sphere.global_position - origin).normalized()
				away_dir.y = 1.2
				pc.physics_sphere.apply_central_impulse(away_dir * (22.0 * pc.physics_sphere.mass))
				pc.car_pivot.rotation.z += PI # Flip upside down
				pc.take_damage(65.0)

# ==============================================================================
# 4. ICE CREAM DRIFTER: FROSTY BLIZZARD BOMB
# ==============================================================================
func _activate_blizzard_bomb() -> void:
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_ui_click()
	
	# Lob 3 bouncing ice cream scoops behind car
	var forward_dir: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	for i in range(3):
		_lob_ice_scoop(car.car_pivot.global_position - forward_dir * (2.0 + i * 2.5) + Vector3.RIGHT * (float(i - 1) * 2.0))

func _lob_ice_scoop(target_pos: Vector3) -> void:
	var scoop := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.9
	sphere.height = 1.8
	scoop.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("74b9ff")
	mat.emission_enabled = true
	mat.emission = Color("0984e3")
	_add_to_world(scoop)
	scoop.global_position = car.car_pivot.global_position + Vector3.UP * 1.5
	
	var tw := scoop.create_tween()
	tw.tween_property(scoop, "global_position", target_pos + Vector3.UP * 0.4, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		var p_node := _get_world_node()
		ValorantSkillVFX.spawn_crystal_ice_field(p_node, target_pos, {
			"radius": 3.8,
			"duration": 4.0,
			"spire_count": 5
		})
		# Freeze nearby cops
		var cops := get_tree().get_nodes_in_group("police_units")
		for cop in cops:
			if is_instance_valid(cop) and cop is PoliceCar:
				var pc := cop as PoliceCar
				if pc.global_position.distance_to(target_pos) <= 5.5:
					if pc.has_method("freeze"):
						pc.freeze(4.0)
		scoop.queue_free()
	)

# ==============================================================================
# 5. CYBER INTERCEPTOR: PHANTOM WARP DASH
# ==============================================================================
func _activate_warp_dash() -> void:
	if not car or not car.physics_sphere:
		return
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_drift_boost()
	
	var forward_dir: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var start_pos: Vector3 = car.physics_sphere.global_position
	var dest_pos: Vector3 = start_pos + forward_dir * 18.0
	
	# Lightning flash visual at origin
	_spawn_warp_flash(start_pos)
	
	# Teleport physics body
	car.physics_sphere.global_position = dest_pos
	car.car_pivot.global_position = dest_pos + Vector3(0, ArcadeCar.PIVOT_OFFSET_Y, 0)
	
	# Lightning flash visual at destination
	_spawn_warp_flash(dest_pos)
	
	# Stun nearby cops at destination
	var cops := get_tree().get_nodes_in_group("police_units")
	for cop in cops:
		if is_instance_valid(cop) and cop is PoliceCar:
			var pc := cop as PoliceCar
			if pc.global_position.distance_to(dest_pos) <= 8.0:
				pc.take_damage(40.0)
				if pc.physics_sphere:
					pc.physics_sphere.linear_velocity *= 0.1

func _spawn_warp_flash(pos: Vector3) -> void:
	var flash := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.8
	sph.height = 3.6
	flash.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("00d2d3")
	mat.emission_enabled = true
	mat.emission = Color("48dbfb")
	mat.emission_energy_multiplier = 5.0
	flash.material_override = mat
	_add_to_world(flash)
	flash.global_position = pos + Vector3.UP * 0.5
	
	var tw := flash.create_tween()
	tw.tween_property(flash, "scale", Vector3(3.0, 3.0, 3.0), 0.2)
	tw.chain().tween_callback(flash.queue_free)

# ==============================================================================
# 6. MONSTER PICKUP: CRUSHER STOMP
# ==============================================================================
func _activate_crusher_stomp() -> void:
	if not car:
		return
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_smash_hit()
	
	is_crusher_active = true
	crusher_timer = 4.0
	original_car_scale = car.car_pivot.scale
	
	# Grow 1.5x larger
	var tw := car.create_tween()
	tw.tween_property(car.car_pivot, "scale", original_car_scale * 1.5, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process_crusher_contact() -> void:
	if not car:
		return
	var origin: Vector3 = car.car_pivot.global_position
	var cops := get_tree().get_nodes_in_group("police_units")
	for cop in cops:
		if is_instance_valid(cop) and cop is PoliceCar:
			var pc := cop as PoliceCar
			if not pc.is_wrecked and origin.distance_to(pc.global_position) <= 4.2:
				pc.wreck(Vector3.UP * 18.0)
				if has_node("/root/SoundFX"):
					get_node("/root/SoundFX").play_explosion()

func _end_crusher() -> void:
	is_crusher_active = false
	if car and is_instance_valid(car):
		var tw := car.create_tween()
		tw.tween_property(car.car_pivot, "scale", original_car_scale, 0.2)

# ==============================================================================
# 7. GOLD LIMO: VIP CASH MAGNET & DECOY
# ==============================================================================
func _activate_cash_decoy() -> void:
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_star_up()
	
	decoy_timer = 4.5
	
	# Create holographic decoy limo at current position
	active_decoy = Node3D.new()
	active_decoy.name = "HologramDecoy"
	_add_to_world(active_decoy)
	active_decoy.global_position = car.car_pivot.global_position
	
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.2, 1.2, 5.0)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.1, 0.65)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color("f1c40f")
	mat.emission_energy_multiplier = 3.0
	mesh.material_override = mat
	active_decoy.add_child(mesh)
	
	# Lure cops to decoy
	var cops := get_tree().get_nodes_in_group("police_units")
	for cop in cops:
		if is_instance_valid(cop) and cop is PoliceCar:
			(cop as PoliceCar).target_override = active_decoy
	
	# Double score/combo
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		wm.combo_multiplier = maxi(wm.combo_multiplier, 2)

func _end_decoy() -> void:
	if active_decoy and is_instance_valid(active_decoy):
		active_decoy.queue_free()
		active_decoy = null
	
	# Restore cop targets
	var cops := get_tree().get_nodes_in_group("police_units")
	for cop in cops:
		if is_instance_valid(cop) and cop is PoliceCar:
			(cop as PoliceCar).target_override = null

# ==============================================================================
# 8. F1 STREET KART: DRS SONIC SLIPSTREAM
# ==============================================================================
func _activate_drs_slipstream() -> void:
	if not car or not car.stats:
		return
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_drift_boost()
	
	is_drs_active = true
	drs_timer = 3.5
	original_max_speed = car.stats.max_speed
	original_grip = car.stats.drift_grip
	
	# 2.0x top speed with razor sharp grip
	car.stats.max_speed = original_max_speed * 2.0
	car.stats.drift_grip = 0.98
	
	# Boost powerup
	car.apply_powerup(0, 3.5)

func _end_drs() -> void:
	is_drs_active = false
	if car and car.stats:
		car.stats.max_speed = original_max_speed
		car.stats.drift_grip = original_grip

# ==============================================================================
# GENERIC FALLBACK
# ==============================================================================
func _activate_generic_boost() -> void:
	if not car:
		return
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_drift_boost()
	car.apply_powerup(0, 5.0)
	var forward_dir: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(forward_dir * (20.0 * car.physics_sphere.mass))

# ==============================================================================
# COMMON TIER ABILITY IMPLEMENTATIONS
# ==============================================================================
func _activate_smoke_screen() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	_spawn_hazard_cloud(Color(0.1, 0.1, 0.1, 0.85), 10.0, 3.5)

func _activate_vtec_boost() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	car.apply_powerup(0, 2.5)
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (22.0 * car.physics_sphere.mass))

func _activate_handbrake_whip() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	car.car_pivot.rotate_y(PI)
	car.physics_sphere.linear_velocity = -car.physics_sphere.linear_velocity * 0.9

func _activate_v8_roar() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_explosion()
	_knockback_nearby_cops(12.0, 24.0)

func _activate_burnout_blast() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	_spawn_hazard_cloud(Color(0.85, 0.35, 0.1, 0.8), 8.0, 4.0)

func _activate_dune_jump() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(Vector3.UP * (14.0 * car.physics_sphere.mass) + fwd * (18.0 * car.physics_sphere.mass))

func _activate_winch_pull() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (28.0 * car.physics_sphere.mass))

func _activate_steam_whistle() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_explosion()
	_spawn_hazard_cloud(Color(0.9, 0.9, 0.9, 0.75), 14.0, 4.0)
	_knockback_nearby_cops(14.0, 20.0)

func _activate_trash_dump() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_crash_hard()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var p_node := _get_world_node()
	spawn_physical_obstacle(p_node, car.car_pivot.global_position - fwd * 2.0, "trash", 3)
	spawn_volumetric_smoke_cloud(p_node, car.car_pivot.global_position - fwd * 2.0, Color("4b6584"), 6.0, 3.5)

func _activate_molten_tar() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_smash_hit()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var p_node := _get_world_node()
	spawn_physical_obstacle(p_node, car.car_pivot.global_position - fwd * 1.8, "tar", 1)

func _activate_siren_burst() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	car.apply_powerup(0, 3.5)
	
	if car.car_pivot:
		var old_sr = car.car_pivot.get_node_or_null("PoliceSirenStrobeRig")
		if old_sr:
			old_sr.queue_free()
		
		var rig := Node3D.new()
		rig.name = "PoliceSirenStrobeRig"
		rig.position = Vector3(0.0, 0.72, 0.0)
		car.car_pivot.add_child(rig)
		
		var red_light := OmniLight3D.new()
		red_light.name = "SirenRedLight"
		red_light.light_color = Color("ff2222")
		red_light.light_energy = 5.5
		red_light.omni_range = 10.0
		red_light.position = Vector3(-0.35, 0.1, 0.0)
		rig.add_child(red_light)
		
		var blue_light := OmniLight3D.new()
		blue_light.name = "SirenBlueLight"
		blue_light.light_color = Color("0088ff")
		blue_light.light_energy = 5.5
		blue_light.omni_range = 10.0
		blue_light.position = Vector3(0.35, 0.1, 0.0)
		rig.add_child(blue_light)
		
		var tw := rig.create_tween()
		var cycles: int = 14
		for c in range(cycles):
			tw.tween_callback(func():
				if is_instance_valid(red_light) and is_instance_valid(blue_light):
					red_light.visible = true
					blue_light.visible = false
			)
			tw.tween_interval(0.12)
			tw.tween_callback(func():
				if is_instance_valid(red_light) and is_instance_valid(blue_light):
					red_light.visible = false
					blue_light.visible = true
			)
			tw.tween_interval(0.12)
		tw.tween_callback(rig.queue_free)

func _activate_defib_zap() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_star_up()
	car.heal(45.0)
	_knockback_nearby_cops(10.0, 20.0)
	var p_node := _get_world_node()
	if car.car_pivot:
		spawn_healing_plus_fx(p_node, car.car_pivot.global_position)
		_spawn_electric_zap_fx(car.car_pivot.global_position)

func _activate_taxi_overdrive() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_coin_pickup()
	car.apply_powerup(0, 3.0)

func _activate_stop_sign_ram() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_crash_hard()
	_knockback_nearby_cops(10.0, 28.0)

func _activate_cheese_slick() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var p_node := _get_world_node()
	spawn_paint_splat_fx(p_node, car.car_pivot.global_position - fwd * 1.5, Color("f39c12"), 4.0, 14)
	ValorantSkillVFX.spawn_liquid_puddle(p_node, car.car_pivot.global_position - fwd * 1.8, {
		"color": Color("f1c40f"),
		"radius": 3.4,
		"duration": 4.5,
		"viscosity_slow": 0.35,
		"damage_amount": 20.0
	})

func _activate_cardboard_roadblock() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_crash_hard()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var p_node := _get_world_node()
	spawn_physical_obstacle(p_node, car.car_pivot.global_position - fwd * 2.0, "cardboard", 3)

func _activate_mail_cannon() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	_spawn_mail_parcels(car.car_pivot.global_position + Vector3.UP * 0.6, fwd)

func _activate_dust_cloud() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var p_node := _get_world_node()
	ValorantSkillVFX.spawn_gas_smoke_dome(p_node, car.car_pivot.global_position, {
		"color": Color("eccc68"),
		"radius": 8.0,
		"duration": 4.0,
		"hazard_type": "sand"
	})

func _activate_luggage_flail() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_crash_hard()
	_knockback_nearby_cops(10.0, 25.0)

func _activate_forklift_lift() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_crash_hard()
	var center: Vector3 = car.car_pivot.global_position
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var cops := get_tree().get_nodes_in_group("police_units")
	for cop in cops:
		if is_instance_valid(cop) and cop is PoliceCar:
			var pc := cop as PoliceCar
			if pc.global_position.distance_to(center + fwd * 2.5) < 5.0:
				if pc.physics_sphere:
					pc.physics_sphere.apply_central_impulse(Vector3(0, 18.0, 0) * pc.physics_sphere.mass)
				pc.take_damage(45.0)

func _activate_acrobatic_spin() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var tw = car.create_tween()
	if tw:
		tw.tween_property(car.car_pivot, "rotation:y", car.car_pivot.rotation.y + TAU, 0.4)

func _activate_peace_smoke() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_star_up()
	var p_node := _get_world_node()
	ValorantSkillVFX.spawn_gas_smoke_dome(p_node, car.car_pivot.global_position, {
		"color": Color("a29bfe"),
		"radius": 8.5,
		"duration": 5.0,
		"hazard_type": "peace"
	})

func _activate_surfboard_launch() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	_spawn_spinning_surfboard(car.car_pivot.global_position + Vector3.UP * 0.5, fwd)

func _activate_italian_job_swerve() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var right: Vector3 = car.car_pivot.global_transform.basis.x.normalized()
	car.physics_sphere.apply_central_impulse((fwd * 0.5 + right * 0.866) * (20.0 * car.physics_sphere.mass))

func _activate_hot_sauce() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var p_node := _get_world_node()
	spawn_paint_splat_fx(p_node, car.car_pivot.global_position - fwd * 1.5, Color("e84118"), 4.2, 16)
	ValorantSkillVFX.spawn_liquid_puddle(p_node, car.car_pivot.global_position - fwd * 1.8, {
		"color": Color("eb2f06"),
		"radius": 3.6,
		"duration": 4.5,
		"is_boiling": true,
		"viscosity_slow": 0.4,
		"damage_amount": 35.0
	})

func _activate_sugar_rush() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_star_up()
	car.heal(25.0)
	car.apply_powerup(0, 3.5)
	var p_node := _get_world_node()
	spawn_healing_plus_fx(p_node, car.car_pivot.global_position)
	spawn_paint_splat_fx(p_node, car.car_pivot.global_position, Color("ff9ff3"), 3.5, 10)

func _activate_mustard_squirt() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var p_node := _get_world_node()
	spawn_paint_splat_fx(p_node, car.car_pivot.global_position - fwd * 1.5, Color("fbc531"), 4.0, 14)
	ValorantSkillVFX.spawn_liquid_puddle(p_node, car.car_pivot.global_position - fwd * 1.8, {
		"color": Color("f9ca24"),
		"radius": 3.2,
		"duration": 4.0,
		"viscosity_slow": 0.35,
		"damage_amount": 20.0
	})

func _activate_luggage_eject() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_crash_hard()
	_knockback_nearby_cops(8.0, 20.0)

func _activate_electro_zip() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (30.0 * car.physics_sphere.mass))

func _knockback_nearby_cops(radius: float, force: float) -> void:
	if not car or not car.car_pivot:
		return
	var center: Vector3 = car.car_pivot.global_position
	var cops := get_tree().get_nodes_in_group("police_units")
	for cop in cops:
		if is_instance_valid(cop) and cop is PoliceCar:
			var pc := cop as PoliceCar
			var d: float = pc.global_position.distance_to(center)
			if d <= radius and d > 0.1:
				var push_dir: Vector3 = (pc.global_position - center).normalized()
				push_dir.y = 0.25
				if pc.physics_sphere:
					pc.physics_sphere.apply_central_impulse(push_dir * (force * pc.physics_sphere.mass))
				pc.take_damage(25.0)

func _spawn_hazard_cloud(col: Color, radius: float, duration: float) -> void:
	if not car or not car.car_pivot:
		return
	var p_node := _get_world_node()
	ValorantSkillVFX.spawn_gas_smoke_dome(p_node, car.car_pivot.global_position, {
		"color": col,
		"radius": radius,
		"duration": duration,
		"hazard_type": "smoke"
	})

## Spawns Valorant-style billowing 3D volumetric smoke dome that blinds pursuing cops
static func spawn_volumetric_smoke_cloud(parent: Node, origin: Vector3, col: Color, radius: float = 6.0, duration: float = 4.0) -> Node3D:
	return ValorantSkillVFX.spawn_gas_smoke_dome(parent, origin, {
		"color": col,
		"radius": radius,
		"duration": duration,
		"hazard_type": "smoke"
	})

## Spawns physical obstacles (trash cans, cardboard boxes, boulders, logs, tar) behind the vehicle
static func spawn_physical_obstacle(parent: Node, origin: Vector3, obstacle_type: String, count: int = 3) -> Node3D:
	if not parent or not is_instance_valid(parent):
		return null
	var root := Node3D.new()
	root.name = "PhysicalObstacle_" + obstacle_type
	root.position = origin
	parent.add_child(root)
	
	match obstacle_type:
		"trash":
			var trash_mat := StandardMaterial3D.new()
			trash_mat.albedo_color = Color("2f3640")
			trash_mat.roughness = 0.7
			for i in range(count):
				var bin := Node3D.new()
				bin.name = "TrashBin_%d" % i
				bin.position = Vector3(randf_range(-1.2, 1.2), 0.35, randf_range(-0.8, 0.8))
				root.add_child(bin)
				
				var can_mesh := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.28
				cyl.bottom_radius = 0.24
				cyl.height = 0.7
				can_mesh.mesh = cyl
				can_mesh.material_override = trash_mat
				bin.add_child(can_mesh)
				
				var lid := MeshInstance3D.new()
				var lid_cyl := CylinderMesh.new()
				lid_cyl.top_radius = 0.31
				lid_cyl.bottom_radius = 0.31
				lid_cyl.height = 0.08
				lid.mesh = lid_cyl
				lid.position.y = 0.38
				lid.material_override = trash_mat
				bin.add_child(lid)
				
				var area := Area3D.new()
				area.collision_layer = 0
				area.collision_mask = 4
				var cs := CollisionShape3D.new()
				var sph := SphereShape3D.new()
				sph.radius = 0.65
				cs.shape = sph
				area.add_child(cs)
				bin.add_child(area)
				
				area.body_entered.connect(func(body: Node3D):
					if is_instance_valid(bin) and body is RigidBody3D and body.get_parent() is PoliceCar:
						var pc := body.get_parent() as PoliceCar
						if pc and not pc.is_wrecked:
							pc.take_damage(35.0)
							if pc.physics_sphere:
								pc.physics_sphere.apply_central_impulse(Vector3(randf_range(-4, 4), 6, randf_range(-4, 4)) * pc.physics_sphere.mass)
							if pc.car_pivot:
								pc.car_pivot.rotation.y += randf_range(-1.5, 1.5)
						_spawn_trash_scatter(bin.global_position, parent)
						bin.queue_free()
				)
		
		"cardboard":
			var box_mat := StandardMaterial3D.new()
			box_mat.albedo_color = Color("cda474")
			box_mat.roughness = 0.85
			for i in range(count):
				var box := Node3D.new()
				box.name = "CardboardBox_%d" % i
				box.position = Vector3(randf_range(-1.4, 1.4), 0.3, randf_range(-0.6, 0.6))
				box.rotation.y = randf_range(0.0, TAU)
				root.add_child(box)
				
				var box_mesh := MeshInstance3D.new()
				var b_mesh := BoxMesh.new()
				b_mesh.size = Vector3(0.55, 0.55, 0.55)
				box_mesh.mesh = b_mesh
				box_mesh.material_override = box_mat
				box.add_child(box_mesh)
				
				var area := Area3D.new()
				area.collision_layer = 0
				area.collision_mask = 4
				var cs := CollisionShape3D.new()
				var sph := SphereShape3D.new()
				sph.radius = 0.6
				cs.shape = sph
				area.add_child(cs)
				box.add_child(area)
				
				area.body_entered.connect(func(body: Node3D):
					if is_instance_valid(box) and body is RigidBody3D and body.get_parent() is PoliceCar:
						var pc := body.get_parent() as PoliceCar
						if pc and not pc.is_wrecked:
							pc.take_damage(25.0)
							if pc.car_pivot:
								pc.car_pivot.rotation.y += randf_range(-1.2, 1.2)
						box.queue_free()
				)

		"boulder":
			var rock_mat := StandardMaterial3D.new()
			rock_mat.albedo_color = Color("57606f")
			rock_mat.roughness = 0.9
			for i in range(mini(count, 2)):
				var rock := Node3D.new()
				rock.name = "RockBoulder_%d" % i
				rock.position = Vector3(randf_range(-1.0, 1.0), 0.45, randf_range(-0.5, 0.5))
				root.add_child(rock)
				
				var r_mesh := MeshInstance3D.new()
				var sph_mesh := SphereMesh.new()
				sph_mesh.radius = 0.45
				sph_mesh.height = 0.9
				r_mesh.mesh = sph_mesh
				r_mesh.material_override = rock_mat
				rock.add_child(r_mesh)
				
				var area := Area3D.new()
				area.collision_layer = 0
				area.collision_mask = 4
				var cs := CollisionShape3D.new()
				var sph := SphereShape3D.new()
				sph.radius = 0.75
				cs.shape = sph
				area.add_child(cs)
				rock.add_child(area)
				
				area.body_entered.connect(func(body: Node3D):
					if is_instance_valid(rock) and body is RigidBody3D and body.get_parent() is PoliceCar:
						var pc := body.get_parent() as PoliceCar
						if pc and not pc.is_wrecked:
							pc.take_damage(50.0)
							if pc.physics_sphere:
								pc.physics_sphere.apply_central_impulse(Vector3(0, 10, -8) * pc.physics_sphere.mass)
						rock.queue_free()
				)

		"log":
			var log_mat := StandardMaterial3D.new()
			log_mat.albedo_color = Color("795548")
			log_mat.roughness = 0.85
			var trunk := Node3D.new()
			trunk.name = "TreeLog"
			trunk.position = Vector3(0.0, 0.35, 0.0)
			root.add_child(trunk)
			
			var l_mesh := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.32
			cyl.bottom_radius = 0.32
			cyl.height = 3.6
			l_mesh.mesh = cyl
			l_mesh.rotation_degrees.z = 90.0
			l_mesh.material_override = log_mat
			trunk.add_child(l_mesh)
			
			var area := Area3D.new()
			area.collision_layer = 0
			area.collision_mask = 4
			var cs := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(3.8, 0.9, 0.9)
			cs.shape = box_shape
			area.add_child(cs)
			trunk.add_child(area)
			
			area.body_entered.connect(func(body: Node3D):
				if is_instance_valid(trunk) and body is RigidBody3D and body.get_parent() is PoliceCar:
					var pc := body.get_parent() as PoliceCar
					if pc and not pc.is_wrecked:
						pc.take_damage(40.0)
						if pc.physics_sphere:
							pc.physics_sphere.apply_central_impulse(Vector3(0, 8, 4) * pc.physics_sphere.mass)
			)

		"tar":
			root.queue_free()
			return ValorantSkillVFX.spawn_liquid_puddle(parent, origin, {
				"color": Color("1e272e"),
				"radius": 3.4,
				"duration": 5.5,
				"is_boiling": true,
				"viscosity_slow": 0.25,
				"damage_amount": 25.0
			})
	
	var tw := root.create_tween()
	tw.tween_interval(6.0)
	tw.tween_callback(root.queue_free)
	return root

static func _spawn_trash_scatter(pos: Vector3, parent: Node) -> void:
	if not parent or not is_instance_valid(parent): return
	var trash_mat := StandardMaterial3D.new()
	trash_mat.albedo_color = Color("57606f")
	for i in range(5):
		var piece := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.18, 0.18, 0.18)
		piece.mesh = box
		piece.material_override = trash_mat
		piece.position = pos + Vector3(randf_range(-0.3, 0.3), randf_range(0.2, 0.6), randf_range(-0.3, 0.3))
		parent.add_child(piece)
		
		var tw := piece.create_tween()
		var target := piece.position + Vector3(randf_range(-1.2, 1.2), -piece.position.y + 0.05, randf_range(-1.2, 1.2))
		tw.tween_property(piece, "position", target, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.5)
		tw.tween_property(trash_mat, "albedo_color:a", 0.0, 0.4)
		tw.tween_callback(piece.queue_free)

func _spawn_mail_parcels(origin: Vector3, forward: Vector3) -> void:
	var p_node := _get_world_node()
	var parcel_mat := StandardMaterial3D.new()
	parcel_mat.albedo_color = Color("f5f6fa")
	
	for i in range(3):
		var parcel := Node3D.new()
		parcel.name = "MailParcel_%d" % i
		var side_angle := (float(i) - 1.0) * 0.22
		var launch_dir := forward.rotated(Vector3.UP, side_angle).normalized()
		parcel.position = origin + launch_dir * 0.8
		p_node.add_child(parcel)
		
		var m_box := MeshInstance3D.new()
		var b_mesh := BoxMesh.new()
		b_mesh.size = Vector3(0.42, 0.28, 0.52)
		m_box.mesh = b_mesh
		m_box.material_override = parcel_mat
		parcel.add_child(m_box)
		
		var target_pos := parcel.position + launch_dir * 18.0
		var tw := parcel.create_tween()
		tw.tween_property(parcel, "position", target_pos, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(parcel, "rotation:y", parcel.rotation.y + TAU * 2.0, 0.42)
		tw.tween_callback(func():
			if is_instance_valid(parcel):
				var cops := get_tree().get_nodes_in_group("police_units")
				for cop in cops:
					if is_instance_valid(cop) and cop is PoliceCar:
						var pc := cop as PoliceCar
						if pc.global_position.distance_to(parcel.global_position) < 4.5:
							pc.take_damage(40.0)
							if pc.physics_sphere:
								pc.physics_sphere.apply_central_impulse(launch_dir * (12.0 * pc.physics_sphere.mass))
				parcel.queue_free()
		)

func _spawn_spinning_surfboard(origin: Vector3, forward: Vector3) -> void:
	var p_node := _get_world_node()
	var board := Node3D.new()
	board.name = "SpinningSurfboard"
	board.position = origin + forward * 0.8
	p_node.add_child(board)
	
	var b_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.35
	cyl.height = 1.8
	b_mesh.mesh = cyl
	b_mesh.scale = Vector3(0.25, 1.0, 0.85)
	b_mesh.rotation_degrees.z = 90.0
	var s_mat := StandardMaterial3D.new()
	s_mat.albedo_color = Color("00d2d3")
	s_mat.emission_enabled = true
	s_mat.emission = Color("00a8ff")
	s_mat.emission_energy_multiplier = 2.0
	b_mesh.material_override = s_mat
	board.add_child(b_mesh)
	
	var target_pos := board.position + forward * 22.0
	var tw := board.create_tween()
	tw.tween_property(board, "position", target_pos, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(board, "rotation:y", board.rotation.y + TAU * 4.0, 0.50)
	tw.tween_callback(func():
		if is_instance_valid(board):
			var cops := get_tree().get_nodes_in_group("police_units")
			for cop in cops:
				if is_instance_valid(cop) and cop is PoliceCar:
					var pc := cop as PoliceCar
					if pc.global_position.distance_to(board.global_position) < 5.0:
						pc.take_damage(50.0)
						if pc.physics_sphere:
							pc.physics_sphere.apply_central_impulse((forward + Vector3.UP * 0.4) * (16.0 * pc.physics_sphere.mass))
			board.queue_free()
	)

func _spawn_tommy_gun_burst(origin: Vector3, forward: Vector3) -> void:
	var p_node := _get_world_node()
	for i in range(8):
		var delay: float = float(i) * 0.035
		var t_timer := get_tree().create_timer(delay)
		t_timer.timeout.connect(func():
			if not is_instance_valid(p_node): return
			var tracer := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.05
			cyl.bottom_radius = 0.05
			cyl.height = 0.9
			tracer.mesh = cyl
			tracer.rotation_degrees.x = 90.0
			var t_mat := StandardMaterial3D.new()
			t_mat.albedo_color = Color("f1c40f")
			t_mat.emission_enabled = true
			t_mat.emission = Color("f39c12")
			t_mat.emission_energy_multiplier = 4.0
			tracer.material_override = t_mat
			
			var spread := Vector3(randf_range(-0.3, 0.3), randf_range(-0.15, 0.15), 0.0)
			var shoot_dir := (forward + spread * 0.1).normalized()
			tracer.position = origin + spread + shoot_dir * 1.0
			p_node.add_child(tracer)
			
			var target_pos := tracer.position + shoot_dir * 25.0
			var tw := tracer.create_tween()
			tw.tween_property(tracer, "position", target_pos, 0.18)
			tw.tween_callback(func():
				if is_instance_valid(tracer):
					tracer.queue_free()
			)
			
			var cops := get_tree().get_nodes_in_group("police_units")
			for cop in cops:
				if is_instance_valid(cop) and cop is PoliceCar:
					var pc := cop as PoliceCar
					if pc.global_position.distance_to(tracer.position + shoot_dir * 8.0) < 3.2:
						pc.take_damage(15.0)
						break
		)

# ==============================================================================
# RARE TIER GADGET HANDLERS (28 UNIQUE ABILITIES)
# ==============================================================================

func _activate_apex_surge() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	car.apply_powerup(0, 4.0)

func _activate_twin_turbo() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (25.0 * car.physics_sphere.mass))

func _activate_hydraulic_hop() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_star_up()
	car.physics_sphere.apply_central_impulse(Vector3.UP * (18.0 * car.physics_sphere.mass))

func _activate_wheelie_stomp() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_bass_impact()
	var tw = car.create_tween()
	if tw:
		tw.tween_property(car.car_pivot, "rotation:x", -0.35, 0.2)
		tw.tween_property(car.car_pivot, "rotation:x", 0.0, 0.15)
	_knockback_nearby_cops(12.0, 26.0)

func _activate_nitrous_burnout() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	car.apply_powerup(0, 3.5)
	_spawn_hazard_cloud(Color(0.9, 0.3, 0.1, 0.85), 8.0, 3.5)

func _activate_blower_surge() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_smash_hit()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (28.0 * car.physics_sphere.mass))

func _activate_smoke_veil() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_smash_hit()
	_spawn_hazard_cloud(Color(0.12, 0.12, 0.12, 0.95), 14.0, 5.0)

func _activate_coil_bounce() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_star_up()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse((Vector3.UP * 1.2 + fwd * 0.8) * (20.0 * car.physics_sphere.mass))

func _activate_floodlight() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_star_up()
	_knockback_nearby_cops(10.0, 18.0)
	
	var old_fl = car.car_pivot.get_node_or_null("RoofFloodlightRig")
	if old_fl:
		old_fl.queue_free()
	
	var rig := Node3D.new()
	rig.name = "RoofFloodlightRig"
	rig.position = Vector3(0.0, 0.65, -0.4)
	car.car_pivot.add_child(rig)
	
	var light_mat := StandardMaterial3D.new()
	light_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	light_mat.albedo_color = Color(1.0, 0.98, 0.82, 0.24)
	
	for side in [-0.42, 0.42]:
		var spot := SpotLight3D.new()
		spot.name = "Spot_%s" % ("L" if side < 0 else "R")
		spot.position = Vector3(side, 0.15, 0.0)
		spot.rotation_degrees.x = -6.0
		spot.light_color = Color("fff8db")
		spot.light_energy = 8.0
		spot.spot_range = 36.0
		spot.spot_angle = 32.0
		spot.spot_attenuation = 0.8
		rig.add_child(spot)
		
		var cone := MeshInstance3D.new()
		cone.name = "BeamCone_%s" % ("L" if side < 0 else "R")
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.10
		cyl.bottom_radius = 2.4
		cyl.height = 14.0
		cone.mesh = cyl
		cone.material_override = light_mat
		cone.position = Vector3(side, -0.2, -7.0)
		cone.rotation_degrees.x = -96.0
		rig.add_child(cone)
	
	var tw := rig.create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(light_mat, "albedo_color:a", 0.0, 0.5)
	tw.tween_callback(rig.queue_free)

func _activate_snow_plow() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_smash_hit()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var p_node := _get_world_node()
	ValorantSkillVFX.spawn_crystal_ice_field(p_node, car.car_pivot.global_position + fwd * 1.5, {
		"radius": 4.5,
		"duration": 4.0,
		"spire_count": 6
	})
	_knockback_nearby_cops(14.0, 36.0)

func _activate_slime_trail() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var p_node := _get_world_node()
	spawn_paint_splat_fx(p_node, car.car_pivot.global_position - fwd * 1.8, Color("44bd32"), 4.6, 16)
	ValorantSkillVFX.spawn_liquid_puddle(p_node, car.car_pivot.global_position - fwd * 1.8, {
		"color": Color("2ecc71"),
		"radius": 3.6,
		"duration": 5.0,
		"is_boiling": true,
		"viscosity_slow": 0.28,
		"damage_amount": 30.0
	})

func _activate_wet_cement() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_smash_hit()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var p_node := _get_world_node()
	spawn_paint_splat_fx(p_node, car.car_pivot.global_position - fwd * 1.8, Color("718093"), 4.5, 14)
	ValorantSkillVFX.spawn_liquid_puddle(p_node, car.car_pivot.global_position - fwd * 1.8, {
		"color": Color("718093"),
		"radius": 3.5,
		"duration": 5.0,
		"viscosity_slow": 0.2,
		"damage_amount": 25.0
	})

func _activate_bucket_swipe() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_bass_impact()
	_knockback_nearby_cops(14.0, 32.0)

func _activate_log_drop() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_smash_hit()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var p_node := _get_world_node()
	spawn_physical_obstacle(p_node, car.car_pivot.global_position - fwd * 2.2, "log", 1)

func _activate_crane_hook() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_bass_impact()
	_knockback_nearby_cops(12.0, 35.0)

func _activate_homing_spike() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_spike_puncture()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (22.0 * car.physics_sphere.mass))
	_knockback_nearby_cops(8.0, 22.0)

func _activate_water_cannon() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var p_node := _get_world_node()
	ValorantSkillVFX.spawn_water_torrent(p_node, car.car_pivot.global_position, fwd, {
		"length": 14.0,
		"width": 5.2,
		"impulse_power": 38.0
	})
	_knockback_nearby_cops(15.0, 28.0)

func _activate_emp_jammer() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_star_up()
	var p_node := _get_world_node()
	ValorantSkillVFX.spawn_emp_shockwave_ring(p_node, car.car_pivot.global_position, {
		"radius": 15.0,
		"color": Color("00d2d3")
	})
	_knockback_nearby_cops(14.0, 18.0)

func _activate_vault_scatter() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_coin_pickup()
	_knockback_nearby_cops(9.0, 15.0)

func _activate_upper_deck_horn() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_bass_impact()
	_knockback_nearby_cops(12.0, 22.0)

func _activate_tow_ramp() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_smash_hit()
	_knockback_nearby_cops(10.0, 30.0)

func _activate_jukebox_blast() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_star_up()
	_knockback_nearby_cops(12.0, 20.0)

func _activate_tommy_gun() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_gunshot()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	_spawn_tommy_gun_burst(car.car_pivot.global_position + Vector3.UP * 0.6, fwd)
	_knockback_nearby_cops(10.0, 24.0)

func _activate_lunar_thruster() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	car.physics_sphere.apply_central_impulse(Vector3.UP * (16.0 * car.physics_sphere.mass))

func _activate_steam_ram() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_bass_impact()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (35.0 * car.physics_sphere.mass))
	_knockback_nearby_cops(12.0, 35.0)

func _activate_torpedo_wake() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	_spawn_hazard_cloud(Color(0.0, 0.7, 0.9, 0.8), 10.0, 4.0)

func _activate_gyro_cyclone() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var tw = car.create_tween()
	if tw:
		tw.tween_property(car.car_pivot, "rotation:y", car.car_pivot.rotation.y + TAU, 0.35)
	_knockback_nearby_cops(10.0, 25.0)

func _activate_candelabra_flame() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_explosion()
	_spawn_hazard_cloud(Color(0.6, 0.15, 0.8, 0.85), 10.0, 4.0)
	_knockback_nearby_cops(11.0, 22.0)

# =============================================================================
# EPIC TIER ACTIVE ABILITY ROUTINES
# =============================================================================
func _activate_antilag_flame() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (24.0 * car.physics_sphere.mass))
	_spawn_hazard_cloud(Color(1.0, 0.25, 0.05, 0.9), 10.0, 3.5)
	_knockback_nearby_cops(9.0, 26.0)

func _activate_supercharged_drift() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (26.0 * car.physics_sphere.mass))
	_knockback_nearby_cops(8.0, 20.0)

func _activate_open_pipe_trail() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_explosion()
	_spawn_hazard_cloud(Color(0.9, 0.4, 0.1, 0.85), 11.0, 3.5)
	_knockback_nearby_cops(10.0, 28.0)

func _activate_torque_smash() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_bass_impact()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (32.0 * car.physics_sphere.mass) + Vector3.UP * (8.0 * car.physics_sphere.mass))
	_knockback_nearby_cops(11.0, 34.0)

func _activate_turbo_spool() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (28.0 * car.physics_sphere.mass))

func _activate_sonic_scream() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_bass_impact()
	_knockback_nearby_cops(14.0, 38.0)

func _activate_bull_charge() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_bass_impact()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (35.0 * car.physics_sphere.mass))
	_knockback_nearby_cops(12.0, 40.0)

func _activate_sandstorm_blind() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var p_node := _get_world_node()
	ValorantSkillVFX.spawn_gas_smoke_dome(p_node, car.car_pivot.global_position, {
		"color": Color("ffa502"),
		"radius": 10.0,
		"duration": 4.5,
		"hazard_type": "sand"
	})
	_knockback_nearby_cops(10.0, 22.0)

func _activate_mud_spray() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var p_node := _get_world_node()
	spawn_paint_splat_fx(p_node, car.car_pivot.global_position - fwd * 1.8, Color("795548"), 4.5, 14)
	ValorantSkillVFX.spawn_liquid_puddle(p_node, car.car_pivot.global_position - fwd * 1.8, {
		"color": Color("5d4037"),
		"radius": 3.6,
		"duration": 4.5,
		"viscosity_slow": 0.28,
		"damage_amount": 20.0
	})
	_knockback_nearby_cops(9.0, 24.0)

func _activate_ramming_prow() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_bass_impact()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (36.0 * car.physics_sphere.mass))
	_knockback_nearby_cops(13.0, 42.0)

func _activate_boulder_dump() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_bass_impact()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var p_node := _get_world_node()
	spawn_physical_obstacle(p_node, car.car_pivot.global_position - fwd * 2.2, "boulder", 2)
	_knockback_nearby_cops(12.0, 35.0)

func _activate_armored_slam() -> void:
	if not car or not car.physics_sphere or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_bass_impact()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (30.0 * car.physics_sphere.mass))
	var p_node := _get_world_node()
	ValorantSkillVFX.spawn_earth_spikes_rupture(p_node, car.car_pivot.global_position, fwd, {
		"count": 5,
		"spacing": 2.2,
		"max_height": 2.5,
		"damage": 50.0
	})
	_knockback_nearby_cops(12.0, 36.0)

func _activate_flashbang_blast() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_explosion()
	
	var p_node := _get_world_node()
	var origin: Vector3 = car.car_pivot.global_position
	
	var flash := OmniLight3D.new()
	flash.name = "FlashbangLight"
	flash.light_color = Color("ffffff")
	flash.light_energy = 16.0
	flash.omni_range = 24.0
	p_node.add_child(flash)
	flash.global_position = origin + Vector3.UP * 0.8
	
	var sphere_mesh := MeshInstance3D.new()
	sphere_mesh.name = "FlashbangSphere"
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	sphere_mesh.mesh = sph
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere_mesh.material_override = sm
	p_node.add_child(sphere_mesh)
	sphere_mesh.global_position = origin + Vector3.UP * 0.8
	
	var tw := p_node.create_tween().set_parallel(true)
	tw.tween_property(flash, "light_energy", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sphere_mesh, "scale", Vector3(10.0, 10.0, 10.0), 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(sm, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(func():
		if is_instance_valid(flash): flash.queue_free()
		if is_instance_valid(sphere_mesh): sphere_mesh.queue_free()
	)
	
	_spawn_hazard_cloud(Color(1.0, 1.0, 1.0, 0.95), 16.0, 3.5)
	_knockback_nearby_cops(14.0, 32.0)

func _activate_foam_cannon() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (22.0 * car.physics_sphere.mass))
	_spawn_hazard_cloud(Color(0.9, 0.95, 1.0, 0.85), 15.0, 4.0)
	_knockback_nearby_cops(11.0, 28.0)

func _activate_water_jets() -> void:
	if not car or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	var p_node := _get_world_node()
	ValorantSkillVFX.spawn_water_torrent(p_node, car.car_pivot.global_position, fwd, {
		"length": 16.0,
		"width": 6.0,
		"impulse_power": 45.0
	})
	_knockback_nearby_cops(15.0, 35.0)

func _activate_turret_fire() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_gunshot()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (18.0 * car.physics_sphere.mass))
	_knockback_nearby_cops(14.0, 30.0)

func _activate_silver_arrow_dash() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (30.0 * car.physics_sphere.mass))

func _activate_le_mans_roar() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_bass_impact()
	_knockback_nearby_cops(12.0, 32.0)

func _activate_time_fire_leap() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (28.0 * car.physics_sphere.mass) + Vector3.UP * (6.0 * car.physics_sphere.mass))
	_spawn_hazard_cloud(Color(1.0, 0.45, 0.1, 0.9), 11.0, 3.5)
	_knockback_nearby_cops(10.0, 25.0)

func _activate_vtol_thruster() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	car.physics_sphere.apply_central_impulse(Vector3.UP * (18.0 * car.physics_sphere.mass))
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (15.0 * car.physics_sphere.mass))

func _activate_quantum_phase() -> void:
	if not car: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	_spawn_hazard_cloud(Color(0.6, 0.2, 0.9, 0.8), 12.0, 3.5)
	_knockback_nearby_cops(12.0, 30.0)

func _activate_turbo_antilag_burst() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_bass_impact()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (32.0 * car.physics_sphere.mass))
	_knockback_nearby_cops(14.0, 36.0)
	_spawn_hazard_cloud(Color(0.75, 0.22, 0.17, 0.85), 8.0, 2.5)

func _activate_sidepipe_blast() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_bass_impact()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (28.0 * car.physics_sphere.mass))
	_knockback_nearby_cops(15.0, 38.0)

func _activate_parachute_airbrake() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (35.0 * car.physics_sphere.mass))
	_knockback_nearby_cops(16.0, 42.0)

func _activate_stealth_cloak() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (26.0 * car.physics_sphere.mass))
	_spawn_hazard_cloud(Color(0.0, 0.8, 0.8, 0.7), 12.0, 3.5)
	_knockback_nearby_cops(12.0, 28.0)

func _activate_mach_hyperdrive() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_bass_impact()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (38.0 * car.physics_sphere.mass))
	_knockback_nearby_cops(18.0, 45.0)

func _activate_kers_boost() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (32.0 * car.physics_sphere.mass))
	_knockback_nearby_cops(12.0, 30.0)

func _activate_graviton_repulsor() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_bass_impact()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (26.0 * car.physics_sphere.mass) + Vector3.UP * (10.0 * car.physics_sphere.mass))
	_spawn_hazard_cloud(Color(0.0, 0.9, 0.9, 0.6), 14.0, 3.0)
	_knockback_nearby_cops(18.0, 46.0)

func _activate_laser_wall_trail() -> void:
	if not car or not car.physics_sphere or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (30.0 * car.physics_sphere.mass))
	var p_node := _get_world_node()
	ValorantSkillVFX.spawn_laser_curtain_wall(p_node, car.car_pivot.global_position, fwd, {
		"length": 16.0,
		"height": 2.4,
		"width_spacing": 3.4,
		"duration": 4.5,
		"color": Color("00d2d3")
	})
	_knockback_nearby_cops(14.0, 35.0)

func _activate_stealth_afterburner() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_explosion()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (36.0 * car.physics_sphere.mass) + Vector3.UP * (8.0 * car.physics_sphere.mass))
	_knockback_nearby_cops(16.0, 48.0)

func _activate_solid_rocket_fire() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_explosion()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (42.0 * car.physics_sphere.mass))
	_spawn_hazard_cloud(Color(1.0, 0.6, 0.1, 0.8), 12.0, 3.0)
	_knockback_nearby_cops(16.0, 50.0)

func _activate_dragon_flame() -> void:
	if not car or not car.physics_sphere or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_explosion()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (30.0 * car.physics_sphere.mass))
	var p_node := _get_world_node()
	ValorantSkillVFX.spawn_dragon_flame_jet(p_node, car.car_pivot.global_position, fwd, {
		"length": 16.0,
		"duration": 4.0
	})
	_knockback_nearby_cops(15.0, 40.0)

func _activate_singularity_vortex() -> void:
	if not car or not car.physics_sphere or not car.car_pivot: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_explosion()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (34.0 * car.physics_sphere.mass))
	var p_node := _get_world_node()
	var center: Vector3 = car.car_pivot.global_position - fwd * 4.0
	ValorantSkillVFX.spawn_void_singularity_vortex(p_node, center, {
		"radius": 16.0,
		"duration": 4.5,
		"pull_force": 48.0
	})
	var cops := get_tree().get_nodes_in_group("police_units")
	for cop in cops:
		if is_instance_valid(cop) and cop is PoliceCar:
			var pc := cop as PoliceCar
			var d: float = pc.global_position.distance_to(center)
			if d <= 18.0 and d > 0.1:
				var pull_dir: Vector3 = (center - pc.global_position).normalized()
				pc.take_damage(65.0)
				if pc.has_method("apply_impact_force"):
					pc.apply_impact_force((pull_dir + Vector3.UP * 0.5) * 45.0)

func _activate_tractor_beam_lift() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_drift_boost()
	car.physics_sphere.apply_central_impulse(Vector3.UP * (14.0 * car.physics_sphere.mass))
	_spawn_hazard_cloud(Color(0.18, 0.8, 0.44, 0.85), 15.0, 3.5)
	if car.car_pivot:
		var center: Vector3 = car.car_pivot.global_position
		var cops := get_tree().get_nodes_in_group("police_units")
		for cop in cops:
			if is_instance_valid(cop) and cop is PoliceCar:
				var pc := cop as PoliceCar
				var d: float = pc.global_position.distance_to(center)
				if d <= 15.0 and d > 0.1:
					var toss_dir: Vector3 = ((pc.global_position - center).normalized() + Vector3.UP * 1.8).normalized()
					pc.take_damage(50.0)
					if pc.has_method("apply_impact_force"):
						pc.apply_impact_force(toss_dir * 55.0)

func _activate_supernova_blast() -> void:
	if not car or not car.physics_sphere: return
	if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_explosion()
	var fwd: Vector3 = -car.car_pivot.global_transform.basis.z.normalized()
	car.physics_sphere.apply_central_impulse(fwd * (38.0 * car.physics_sphere.mass))
	_spawn_hazard_cloud(Color(0.99, 0.47, 0.66, 0.95), 20.0, 4.0)
	_knockback_nearby_cops(22.0, 60.0)


