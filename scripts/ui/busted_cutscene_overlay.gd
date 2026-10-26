class_name BustedCutsceneOverlay
extends CanvasLayer

## Classic GTA Desaturated Screen Shader & Giant Stamp Slam Overlay
## Orchestrates 3D arrest cutscene: slow-mo, camera orbit, officer hop & run,
## sweeping siren spotlights, screen desaturation shader, and animated stamp slam.

const SoundFXClass = preload("res://scripts/autoload/sound_fx.gd")

@onready var shader_rect: ColorRect = $ShaderRect
@onready var center_container: CenterContainer = $CenterContainer
@onready var stamp_holder: Control = $CenterContainer/StampHolder
@onready var banner_frame: PanelContainer = $CenterContainer/StampHolder/BannerFrame
@onready var stamp_label: Label = $CenterContainer/StampHolder/BannerFrame/MarginContainer/StampLabel

var _shader_mat: ShaderMaterial = null
var _time_elapsed: float = 0.0
var _is_cutscene_active: bool = false
var _police_pulse_active: bool = false

# 3D Cutscene references
var _spawned_officers: Array[Node3D] = []
var _spawned_lights: Array[SpotLight3D] = []
var _officer_start_positions: Array[Vector3] = []
var _officer_target_positions: Array[Vector3] = []
var _officer_anim_time: float = 0.0
var _officer_anim_active: bool = false
var _target_car_pivot: Node3D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	
	if shader_rect and shader_rect.material is ShaderMaterial:
		_shader_mat = shader_rect.material as ShaderMaterial
	elif shader_rect:
		var s = load("res://shaders/busted_desaturate.gdshader")
		if s:
			_shader_mat = ShaderMaterial.new()
			_shader_mat.shader = s
			shader_rect.material = _shader_mat
	
	# Initial shader state (invisible/normal saturation)
	if _shader_mat:
		_shader_mat.set_shader_parameter("saturation", 1.0)
		_shader_mat.set_shader_parameter("vignette_intensity", 0.0)
		_shader_mat.set_shader_parameter("police_pulse", 0.0)
		_shader_mat.set_shader_parameter("time_val", 0.0)
	
	if stamp_holder:
		stamp_holder.visible = false
		stamp_holder.pivot_offset = stamp_holder.size / 2.0
	
	# Connect to WantedManager
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		if not wm.player_busted.is_connected(_on_player_busted):
			wm.player_busted.connect(_on_player_busted)

func _process(delta: float) -> void:
	if not _is_cutscene_active:
		return
	
	_time_elapsed += delta
	if _shader_mat and _police_pulse_active:
		_shader_mat.set_shader_parameter("time_val", _time_elapsed)
	
	# Animate hopping/running officers & sweeping siren spotlights
	if _officer_anim_active:
		_update_officers_and_lights(delta)

## Central handler when player is busted or wrecked
func _on_player_busted(reason: String, final_score: int, survival_seconds: float, cops_wrecked: int) -> void:
	if _is_cutscene_active:
		return
	_is_cutscene_active = true
	_time_elapsed = 0.0
	
	var is_arrest: bool = reason.to_upper().contains("BUSTED")
	_police_pulse_active = is_arrest
	
	# Locate last used character or vehicle
	var wasted_entity: Node3D = null
	var wm = get_node_or_null("/root/WantedManager")
	if wm and "last_wasted_target" in wm and is_instance_valid(wm.last_wasted_target):
		wasted_entity = wm.last_wasted_target
	
	if not wasted_entity:
		var runners := get_tree().get_nodes_in_group("player_character")
		for r in runners:
			if is_instance_valid(r):
				wasted_entity = r as Node3D
				break
	
	var cam_rig := get_tree().root.find_child("CameraRig", true, false) as CameraRig
	if not wasted_entity and cam_rig and is_instance_valid(cam_rig.target):
		wasted_entity = cam_rig.target
	
	if not wasted_entity and wm and "last_active_car" in wm and is_instance_valid(wm.last_active_car):
		wasted_entity = wm.last_active_car
	
	if not wasted_entity:
		var p_vehicles := get_tree().get_nodes_in_group("player_vehicles")
		for v in p_vehicles:
			if is_instance_valid(v) and v is ArcadeCar and not (v as ArcadeCar).is_abandoned:
				wasted_entity = v as Node3D
				break
	
	if not wasted_entity:
		var cars := get_tree().get_nodes_in_group("player_vehicles")
		if not cars.is_empty() and is_instance_valid(cars[0]):
			wasted_entity = cars[0] as Node3D
		else:
			wasted_entity = get_tree().root.find_child("ArcadeCar", true, false)
	
	var player_car: ArcadeCar = wasted_entity as ArcadeCar if wasted_entity is ArcadeCar else null
	
	# 1. Physics Slowdown: time_scale = 0.18 for 0.8s, then freeze vehicle driving forces
	Engine.time_scale = 0.18
	var freeze_timer := get_tree().create_timer(0.8, true, false, true)
	freeze_timer.timeout.connect(func():
		Engine.time_scale = 1.0
		if player_car and is_instance_valid(player_car):
			if player_car.has_method("freeze_driving_forces"):
				player_car.freeze_driving_forces()
			elif "physics_sphere" in player_car and player_car.physics_sphere:
				player_car.physics_sphere.linear_velocity = Vector3.ZERO
				player_car.physics_sphere.angular_velocity = Vector3.ZERO
	)
	
	# 2. CameraRig into "CUTSCENE_ORBIT" mode centered on the lastly used character or car
	var pivot: Node3D = null
	if wasted_entity and is_instance_valid(wasted_entity):
		pivot = wasted_entity.car_pivot if ("car_pivot" in wasted_entity and wasted_entity.car_pivot) else wasted_entity
	
	_target_car_pivot = pivot
	
	if cam_rig:
		if cam_rig.has_method("switch_to_cutscene_orbit"):
			cam_rig.switch_to_cutscene_orbit(pivot)
		else:
			cam_rig.mode = "CUTSCENE_ORBIT"
			if pivot:
				cam_rig.target = pivot
	
	# 3. 3D Police Officers & Siren Beams if reason contains "BUSTED"
	if is_arrest and wasted_entity and is_instance_valid(wasted_entity):
		_spawn_cutscene_police(wasted_entity)
	
	# 4. Desaturated Screen Shader lerp
	_animate_screen_shader(is_arrest)
	
	# 5. Giant Stamp Slam Animation
	_trigger_stamp_slam(is_arrest)
	
	# 6. Slide RunSummaryPanel up cleanly after 1.6 seconds of admiring the 3D arrest cutscene
	var summary_timer := get_tree().create_timer(1.6, true, false, true)
	summary_timer.timeout.connect(func():
		_slide_run_summary_panel(reason, final_score, survival_seconds, cops_wrecked)
	)

## Smoothly lerps screen saturation down to 0.15 (gritty black-and-white contrast) with dark vignette & edge pulse
func _animate_screen_shader(is_arrest: bool) -> void:
	if not _shader_mat:
		return
	
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.set_parallel(true)
	
	# Lerp saturation down to 0.15
	tween.tween_method(func(val: float):
		if _shader_mat:
			_shader_mat.set_shader_parameter("saturation", val)
	, 1.0, 0.15, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Dark vignette
	tween.tween_method(func(val: float):
		if _shader_mat:
			_shader_mat.set_shader_parameter("vignette_intensity", val)
	, 0.0, 0.70, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Red/blue police light edge pulse if arrested
	if is_arrest:
		tween.tween_method(func(val: float):
			if _shader_mat:
				_shader_mat.set_shader_parameter("police_pulse", val)
		, 0.0, 0.85, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Center Pivot Control ("StampHolder") giant 86pt outlined Label slam
func _trigger_stamp_slam(is_arrest: bool) -> void:
	if not stamp_holder or not stamp_label:
		return
	
	# Style stamp label & banner
	_style_stamp(is_arrest)
	
	# Center pivot offset
	stamp_holder.pivot_offset = stamp_holder.size / 2.0
	stamp_holder.scale = Vector2(3.2, 3.2)
	stamp_holder.modulate.a = 0.0
	stamp_holder.visible = true
	
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(stamp_holder, "modulate:a", 1.0, 0.06)
	tween.parallel().tween_property(stamp_holder, "scale", Vector2(1.0, 1.0), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		# Trigger CameraRig trauma 0.55 & SoundFX deep bass impact sound
		var cam_rig := get_tree().root.find_child("CameraRig", true, false) as CameraRig
		if cam_rig:
			cam_rig.add_trauma(0.55)
		
		if has_node("/root/SoundFX"):
			var sfx = get_node("/root/SoundFX")
			if sfx.has_method("play_bass_impact"):
				sfx.play_bass_impact()
			elif sfx.has_method("play_busted_slam"):
				sfx.play_busted_slam()
	)

func _style_stamp(is_arrest: bool) -> void:
	if not stamp_label or not banner_frame:
		return
	
	var settings := LabelSettings.new()
	settings.font_size = 86
	settings.outline_size = 18
	
	var sb := StyleBoxFlat.new()
	sb.border_width_left = 6
	sb.border_width_top = 6
	sb.border_width_right = 6
	sb.border_width_bottom = 6
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_right = 16
	sb.corner_radius_bottom_left = 16
	sb.shadow_size = 18
	sb.shadow_color = Color(0, 0, 0, 0.85)
	sb.skew = Vector2(-0.08, 0)
	
	if is_arrest:
		# Check for high-impact Nanobanana comic stamp asset
		var stamp_tex: Texture2D = null
		if has_node("/root/AssetChromaLoader"):
			var acl = get_node("/root/AssetChromaLoader")
			stamp_tex = acl.load_transparent_texture("res://assets/hud/stamp_busted.png")
		elif ResourceLoader.exists("res://assets/hud/stamp_busted.png"):
			stamp_tex = load("res://assets/hud/stamp_busted.png")
		
		if stamp_tex:
			var stamp_img: TextureRect = stamp_holder.get_node_or_null("StampTexture")
			if not stamp_img:
				stamp_img = TextureRect.new()
				stamp_img.name = "StampTexture"
				stamp_img.custom_minimum_size = Vector2(512, 256)
				stamp_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				stamp_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				stamp_holder.add_child(stamp_img)
			stamp_img.texture = stamp_tex
			stamp_img.visible = true
			banner_frame.visible = false
			return
		
		# "BUSTED" in electric police blue/white
		banner_frame.visible = true
		stamp_label.text = "BUSTED"
		settings.font_color = Color(0.95, 0.98, 1.0) # Electric white
		settings.outline_color = Color(0.02, 0.12, 0.35) # Deep navy outline
		settings.shadow_size = 12
		settings.shadow_color = Color(0.0, 0.65, 1.0, 0.75) # Electric blue glow
		
		sb.bg_color = Color(0.04, 0.08, 0.16, 0.96)
		sb.border_color = Color(0.0, 0.85, 1.0, 1.0) # Electric police blue
	else:
		# "WASTED" in crimson red
		stamp_label.text = "WASTED"
		settings.font_color = Color(1.0, 0.18, 0.18) # Crimson red
		settings.outline_color = Color(0.18, 0.02, 0.02) # Dark crimson outline
		settings.shadow_size = 12
		settings.shadow_color = Color(0.0, 0.0, 0.0, 0.9)
		
		sb.bg_color = Color(0.12, 0.02, 0.02, 0.96)
		sb.border_color = Color(0.95, 0.15, 0.15, 1.0)
	
	stamp_label.label_settings = settings
	banner_frame.add_theme_stylebox_override("panel", sb)

## Spawns 2 blocky 3D Police Officers hopping out of nearest PoliceCar and running to driver door or fallen runner
func _spawn_cutscene_police(target_entity: Node3D) -> void:
	var builder: VoxelAssetBuilderClass = null
	if has_node("/root/VoxelAssetBuilder"):
		builder = get_node("/root/VoxelAssetBuilder") as VoxelAssetBuilderClass
	
	if not builder or not builder.has_method("build_police_officer") or not target_entity or not is_instance_valid(target_entity):
		return
	
	# Find nearest police car
	var cops := get_tree().get_nodes_in_group("police_units")
	var nearest_cop: Node3D = null
	var min_dist: float = 9999.0
	for cop in cops:
		if is_instance_valid(cop) and cop is PoliceCar and not cop.is_wrecked:
			var d: float = target_entity.global_position.distance_to(cop.global_position)
			if d < min_dist:
				min_dist = d
				nearest_cop = cop
	
	var cop_pos: Vector3
	var cop_basis: Basis
	if nearest_cop and is_instance_valid(nearest_cop) and min_dist < 40.0:
		cop_pos = nearest_cop.global_position
		cop_basis = nearest_cop.global_transform.basis
		# Park the cop car cleanly during cutscene
		if nearest_cop is PoliceCar:
			nearest_cop.is_wrecked = false
			if nearest_cop.physics_sphere:
				nearest_cop.physics_sphere.linear_velocity = Vector3.ZERO
				nearest_cop.physics_sphere.angular_velocity = Vector3.ZERO
	else:
		# Place near rear-left of player entity
		var entity_basis: Basis = target_entity.global_transform.basis
		if "car_pivot" in target_entity and target_entity.car_pivot:
			entity_basis = target_entity.car_pivot.global_transform.basis
		var p_right: Vector3 = entity_basis.x.normalized()
		var p_fwd: Vector3 = -entity_basis.z.normalized()
		cop_pos = target_entity.global_position - p_right * 5.2 - p_fwd * 2.5
		cop_basis = entity_basis
	
	var world: Node = target_entity.get_parent()
	if not world:
		world = get_tree().current_scene
	
	# Instantiate 2 officers
	var officer1 := builder.build_police_officer()
	var officer2 := builder.build_police_officer()
	officer1.name = "VoxelPoliceOfficer_1"
	officer2.name = "VoxelPoliceOfficer_2"
	officer1.add_to_group("cutscene_police_officers")
	officer2.add_to_group("cutscene_police_officers")
	world.add_child(officer1)
	world.add_child(officer2)
	_spawned_officers = [officer1, officer2]
	
	var ground_y: float = target_entity.global_position.y - 0.45
	
	# Start positions (hopping out of cop car doors)
	var cop_left: Vector3 = -cop_basis.x.normalized() * 1.3
	var cop_right: Vector3 = cop_basis.x.normalized() * 1.3
	var start1: Vector3 = cop_pos + cop_left
	start1.y = ground_y
	var start2: Vector3 = cop_pos + cop_right
	start2.y = ground_y
	
	officer1.global_position = start1
	officer2.global_position = start2
	
	_officer_start_positions = [start1, start2]
	
	# Target positions
	var target1: Vector3
	var target2: Vector3
	if target_entity is ArcadeCar:
		var car_pivot_node: Node3D = target_entity.car_pivot if target_entity.car_pivot else target_entity
		var car_pos: Vector3 = car_pivot_node.global_position
		var car_fwd: Vector3 = -car_pivot_node.global_transform.basis.z.normalized()
		var car_left: Vector3 = -car_pivot_node.global_transform.basis.x.normalized()
		var driver_door_base: Vector3 = car_pos + car_left * 1.45
		driver_door_base.y = ground_y
		target1 = driver_door_base + car_fwd * 0.42
		target2 = driver_door_base - car_fwd * 0.42
	else:
		# Runner on foot: flank the fallen character
		var t_pos: Vector3 = target_entity.global_position
		t_pos.y = ground_y
		target1 = t_pos + Vector3(-1.1, 0.0, 0.6)
		target2 = t_pos + Vector3(1.1, 0.0, -0.6)
	_officer_target_positions = [target1, target2]
	
	# Spawn alternating red and blue SpotLight3D siren beams sweeping across car
	var red_spot := SpotLight3D.new()
	red_spot.name = "CutsceneRedSirenBeam"
	red_spot.light_color = Color(1.0, 0.15, 0.15)
	red_spot.light_energy = 8.5
	red_spot.spot_range = 24.0
	red_spot.spot_angle = 32.0
	world.add_child(red_spot)
	red_spot.global_position = cop_pos + Vector3(0.0, 2.6, 0.0)
	
	var blue_spot := SpotLight3D.new()
	blue_spot.name = "CutsceneBlueSirenBeam"
	blue_spot.light_color = Color(0.15, 0.45, 1.0)
	blue_spot.light_energy = 8.5
	blue_spot.spot_range = 24.0
	blue_spot.spot_angle = 32.0
	world.add_child(blue_spot)
	blue_spot.global_position = cop_pos + Vector3(0.0, 2.6, 0.0)
	
	_spawned_lights = [red_spot, blue_spot]
	
	_officer_anim_time = 0.0
	_officer_anim_active = true

## Updates hopping/running animation of officers and sweeping siren spotlights
func _update_officers_and_lights(delta: float) -> void:
	_officer_anim_time += delta
	
	# 1. Update Officers hopping out and running to door over 1.25s
	var run_duration: float = 1.25
	var progress: float = clampf(_officer_anim_time / run_duration, 0.0, 1.0)
	
	for i in range(_spawned_officers.size()):
		var officer := _spawned_officers[i]
		if not is_instance_valid(officer):
			continue
		
		var start_p: Vector3 = _officer_start_positions[i]
		var target_p: Vector3 = _officer_target_positions[i]
		
		# Hop arc in first 0.3s
		var hop_y: float = 0.0
		if progress < 0.25:
			var hop_prog: float = progress / 0.25
			hop_y = sin(hop_prog * PI) * 0.45
		
		var cur_pos: Vector3 = start_p.lerp(target_p, progress)
		cur_pos.y += hop_y
		
		# Running bob & leg animation
		if progress < 1.0:
			var bob: float = absf(sin(_officer_anim_time * 16.0)) * 0.07
			cur_pos.y += bob
			officer.global_position = cur_pos
			
			# Face movement direction
			var dir := (target_p - start_p).normalized()
			if dir.length_squared() > 0.01:
				officer.look_at(officer.global_position + Vector3(dir.x, 0.0, dir.z), Vector3.UP)
			
			# Animate legs swinging
			var leg_l = officer.find_child("Leg_L", true, false)
			var leg_r = officer.find_child("Leg_R", true, false)
			if leg_l and leg_r:
				leg_l.rotation.x = sin(_officer_anim_time * 16.0) * 0.6
				leg_r.rotation.x = -sin(_officer_anim_time * 16.0) * 0.6
		else:
			# Arrived at door: stand firmly surrounding the driver door, facing the car
			officer.global_position = target_p
			if _target_car_pivot and is_instance_valid(_target_car_pivot):
				officer.look_at(_target_car_pivot.global_position, Vector3.UP)
			var leg_l = officer.find_child("Leg_L", true, false)
			var leg_r = officer.find_child("Leg_R", true, false)
			if leg_l and leg_r:
				leg_l.rotation.x = 0.0
				leg_r.rotation.x = 0.0
	
	# 2. Sweeping alternating siren spotlight beams
	if _spawned_lights.size() >= 2 and _target_car_pivot and is_instance_valid(_target_car_pivot):
		var red_light := _spawned_lights[0]
		var blue_light := _spawned_lights[1]
		var car_pos := _target_car_pivot.global_position
		
		# Sweeping aim across the car
		var sweep_x: float = sin(_officer_anim_time * 5.5) * 2.4
		var sweep_z: float = cos(_officer_anim_time * 5.5) * 1.6
		var aim_target_red := car_pos + Vector3(sweep_x, 0.3, sweep_z)
		var aim_target_blue := car_pos - Vector3(sweep_x, -0.3, sweep_z)
		
		if is_instance_valid(red_light):
			red_light.look_at(aim_target_red, Vector3.UP)
			red_light.light_energy = 8.5 * maxf(0.2, sin(_officer_anim_time * 9.0))
		
		if is_instance_valid(blue_light):
			blue_light.look_at(aim_target_blue, Vector3.UP)
			blue_light.light_energy = 8.5 * maxf(0.2, -sin(_officer_anim_time * 9.0))

## Slides RunSummaryPanel up cleanly at bottom half of screen while 3D orbiting camera continues
func _slide_run_summary_panel(reason: String, final_score: int, survival_seconds: float, cops_wrecked: int) -> void:
	var summary_panel: RunSummaryPanel = null
	var found = get_tree().root.find_child("RunSummaryPanel", true, false)
	if found is RunSummaryPanel:
		summary_panel = found
	
	if not summary_panel:
		return
	
	# Float StampHolder slightly up into upper half so bottom half is free for RunSummaryPanel
	if stamp_holder:
		var float_tween := create_tween()
		float_tween.set_ignore_time_scale(true)
		float_tween.tween_property(stamp_holder, "position:y", stamp_holder.position.y - 120.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Trigger slide up on RunSummaryPanel
	if summary_panel.has_method("slide_up_at_bottom"):
		summary_panel.slide_up_at_bottom(reason, final_score, survival_seconds, cops_wrecked)
	else:
		summary_panel.visible = true
