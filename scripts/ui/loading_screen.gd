class_name LoadingScreen
extends CanvasLayer

## High-Impact Brawl Stars-Style Loading Screen & Hero Splash Art Screen
## Features:
## - Full-screen crimson/navy diagonal comic split background with radial speed lines
## - Slanted Hero Splash Art card with 3/4 low-angle 3D action pose
## - Giant bold vehicle name, rarity badge, and comic action callouts
## - Slanted chunky ProgressBar with rotating pro tips (guaranteed >= 1.1s display time)

signal transition_display_completed()

const ROTATING_TIPS: Array[String] = [
	"TIP: Lure police into Red Fuel Tankers for a 12m chain-reaction blast!",
	"TIP: Ramming an Ambulance drops a glowing green +30 HP Medkit!",
	"TIP: Beware the Desert Railroad when the crossing lights flash red!",
	"TIP: High-speed near misses award +50 points and combo multipliers!",
	"TIP: Smash power-up crates for Nitro, EMP Shockwaves, and Titan Shields!",
	"TIP: Towing the heavy Diamond Safe in Bank Heist attracts 3-Star SWAT!",
	"TIP: The Mecha-Crusher Bulldozer takes 25% damage when rammed into buildings!"
]

const CALLOUT_MESSAGES: Array[String] = [
	"NEXT STOP: DOWNTOWN VAULT!",
	"SMASH, DRIFT & GETAWAY!",
	"MAXIMUM HEAT INCOMING!",
	"FULL THROTTLE HEIST!",
	"CRACK THE SAFE OR BUST!"
]

var _root_control: Control = null
var _bg_rect: ColorRect = null
var _hero_frame: PanelContainer = null
var _viewport_container: SubViewportContainer = null
var _sub_viewport: SubViewport = null
var _car_mount: Node3D = null
var _car_camera: Camera3D = null

var _car_name_label: Label = null
var _rarity_badge_label: Label = null
var _callout_label: Label = null
var _tip_label: Label = null
var _progress_bar: ProgressBar = null
var _progress_label: Label = null

var _tip_timer: float = 0.0
var _tip_index: int = 0
var _target_progress: float = 0.0
var _display_progress: float = 0.0
var _is_active: bool = false
var _car_model: Node3D = null

func _ready() -> void:
	layer = 100
	_build_ui()
	visible = false

func _process(delta: float) -> void:
	if not _is_active or not visible:
		return
	
	# Smoothly advance progress bar display towards target
	_display_progress = move_toward(_display_progress, _target_progress, delta * 1.5)
	if _progress_bar:
		_progress_bar.value = _display_progress * 100.0
	if _progress_label:
		_progress_label.text = "%d%%" % int(_display_progress * 100.0)
	
	# Rotate tips every 2.4 seconds
	_tip_timer += delta
	if _tip_timer >= 2.4:
		_tip_timer = 0.0
		_tip_index = (_tip_index + 1) % ROTATING_TIPS.size()
		if _tip_label:
			_tip_label.text = ROTATING_TIPS[_tip_index]
	
	# Slight heroic hover/bob for the 3D action pose
	if _car_mount:
		_car_mount.position.y = sin(Time.get_ticks_msec() * 0.003) * 0.08

func _build_ui() -> void:
	_root_control = Control.new()
	_root_control.name = "RootControl"
	_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root_control)
	
	# 1. Comic Split Diagonal Background
	_bg_rect = ColorRect.new()
	_bg_rect.name = "Background"
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = Color("1e272e")
	_root_control.add_child(_bg_rect)
	
	# Diagonal crimson slash polygon
	var slash_poly := Polygon2D.new()
	slash_poly.color = Color("b71540")
	slash_poly.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(1920 * 0.75, 0),
		Vector2(1920 * 0.35, 1080),
		Vector2(0, 1080)
	])
	_root_control.add_child(slash_poly)
	
	# Angled comic speed-line decorative stripes
	var stripe1 := Polygon2D.new()
	stripe1.color = Color(1.0, 0.9, 0.2, 0.25)
	stripe1.polygon = PackedVector2Array([
		Vector2(1920 * 0.72, 0),
		Vector2(1920 * 0.76, 0),
		Vector2(1920 * 0.36, 1080),
		Vector2(1920 * 0.32, 1080)
	])
	_root_control.add_child(stripe1)
	
	var stripe2 := Polygon2D.new()
	stripe2.color = Color(1.0, 1.0, 1.0, 0.15)
	stripe2.polygon = PackedVector2Array([
		Vector2(1920 * 0.78, 0),
		Vector2(1920 * 0.80, 0),
		Vector2(1920 * 0.40, 1080),
		Vector2(1920 * 0.38, 1080)
	])
	_root_control.add_child(stripe2)
	
	# 2. Hero Splash Art Card (Center-Left)
	_hero_frame = PanelContainer.new()
	_hero_frame.name = "HeroFrame"
	_hero_frame.custom_minimum_size = Vector2(760, 680)
	_hero_frame.position = Vector2(120, 110)
	
	var frame_sb := StyleBoxFlat.new()
	frame_sb.bg_color = Color(0.08, 0.10, 0.16, 0.96)
	frame_sb.border_color = Color("f1c40f")
	frame_sb.set_border_width_all(6)
	frame_sb.set_corner_radius_all(20)
	frame_sb.shadow_color = Color(0, 0, 0, 0.6)
	frame_sb.shadow_size = 18
	frame_sb.shadow_offset = Vector2(8, 12)
	frame_sb.skew = Vector2(0.08, 0.0)
	_hero_frame.add_theme_stylebox_override("panel", frame_sb)
	_root_control.add_child(_hero_frame)
	
	var frame_margin := MarginContainer.new()
	frame_margin.add_theme_constant_override("margin_left", 24)
	frame_margin.add_theme_constant_override("margin_top", 24)
	frame_margin.add_theme_constant_override("margin_right", 24)
	frame_margin.add_theme_constant_override("margin_bottom", 24)
	_hero_frame.add_child(frame_margin)
	
	var frame_vbox := VBoxContainer.new()
	frame_vbox.add_theme_constant_override("separation", 12)
	frame_margin.add_child(frame_vbox)
	
	# Top Rarity Badge & Callout Row
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 16)
	frame_vbox.add_child(top_h)
	
	_rarity_badge_label = Label.new()
	_rarity_badge_label.text = "[LEGENDARY]"
	_rarity_badge_label.add_theme_font_size_override("font_size", 22)
	_rarity_badge_label.add_theme_color_override("font_color", Color("f1c40f"))
	top_h.add_child(_rarity_badge_label)
	
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(sp)
	
	_callout_label = Label.new()
	_callout_label.text = "NEXT STOP: DOWNTOWN VAULT!"
	_callout_label.add_theme_font_size_override("font_size", 18)
	_callout_label.add_theme_color_override("font_color", Color("ffeaa7"))
	top_h.add_child(_callout_label)
	
	# 3D SubViewport for 3/4 low-angle Hero Render
	_viewport_container = SubViewportContainer.new()
	_viewport_container.custom_minimum_size = Vector2(700, 480)
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_container.stretch = true
	frame_vbox.add_child(_viewport_container)
	
	_sub_viewport = SubViewport.new()
	_sub_viewport.name = "LoadingSplashViewport"
	_sub_viewport.size = Vector2i(700, 480)
	_sub_viewport.own_world_3d = true
	_sub_viewport.transparent_bg = true
	_sub_viewport.handle_input_locally = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport_container.add_child(_sub_viewport)
	
	_build_3d_splash_scene()
	
	# Giant Bold Car Name
	_car_name_label = Label.new()
	_car_name_label.text = "GETAWAY COUPE"
	_car_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_car_name_label.add_theme_font_size_override("font_size", 44)
	_car_name_label.add_theme_color_override("font_color", Color("f5f6fa"))
	_car_name_label.add_theme_constant_override("outline_size", 10)
	_car_name_label.add_theme_color_override("font_outline_color", Color("1e272e"))
	frame_vbox.add_child(_car_name_label)
	
	# 3. Right-Side Lore & Mode Splash Art
	var right_box := VBoxContainer.new()
	right_box.position = Vector2(980, 220)
	right_box.custom_minimum_size = Vector2(800, 400)
	right_box.add_theme_constant_override("separation", 20)
	_root_control.add_child(right_box)
	
	var mode_title := Label.new()
	mode_title.name = "ModeTitle"
	mode_title.text = "🔥 SMASHY HEIST: DAILY GETAWAY"
	mode_title.add_theme_font_size_override("font_size", 38)
	mode_title.add_theme_color_override("font_color", Color("f39c12"))
	mode_title.add_theme_constant_override("outline_size", 8)
	mode_title.add_theme_color_override("font_outline_color", Color("1e272e"))
	right_box.add_child(mode_title)
	
	var mission_brief := Label.new()
	mission_brief.text = "OBJECTIVE: SURVIVE ESCALATING 5-STAR HEAT\nRAM POLICE CRUISERS • CRACK VAULTS • SECURE DIAMONDS"
	mission_brief.add_theme_font_size_override("font_size", 20)
	mission_brief.add_theme_color_override("font_color", Color("d2dae2"))
	right_box.add_child(mission_brief)
	
	# 4. Bottom Chunky Slanted ProgressBar & Pro Tips
	var bottom_vbox := VBoxContainer.new()
	bottom_vbox.position = Vector2(180, 890)
	bottom_vbox.custom_minimum_size = Vector2(1560, 130)
	bottom_vbox.add_theme_constant_override("separation", 12)
	_root_control.add_child(bottom_vbox)
	
	# Tip Row
	_tip_label = Label.new()
	_tip_label.text = ROTATING_TIPS[0]
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.add_theme_font_size_override("font_size", 20)
	_tip_label.add_theme_color_override("font_color", Color("f1c40f"))
	_tip_label.add_theme_constant_override("outline_size", 6)
	_tip_label.add_theme_color_override("font_outline_color", Color("1e272e"))
	bottom_vbox.add_child(_tip_label)
	
	# Progress Bar Container
	var bar_container := PanelContainer.new()
	bar_container.custom_minimum_size = Vector2(1560, 48)
	
	var bar_bg_sb := StyleBoxFlat.new()
	bar_bg_sb.bg_color = Color(0.1, 0.12, 0.16, 0.95)
	bar_bg_sb.border_color = Color("1e272e")
	bar_bg_sb.set_border_width_all(5)
	bar_bg_sb.set_corner_radius_all(14)
	bar_bg_sb.skew = Vector2(0.12, 0.0)
	bar_container.add_theme_stylebox_override("panel", bar_bg_sb)
	bottom_vbox.add_child(bar_container)
	
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(1540, 36)
	_progress_bar.show_percentage = false
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	
	var bar_fill_sb := StyleBoxFlat.new()
	bar_fill_sb.bg_color = Color("f39c12")
	bar_fill_sb.set_corner_radius_all(10)
	_progress_bar.add_theme_stylebox_override("fill", bar_fill_sb)
	
	var empty_sb := StyleBoxFlat.new()
	empty_sb.bg_color = Color.TRANSPARENT
	_progress_bar.add_theme_stylebox_override("background", empty_sb)
	bar_container.add_child(_progress_bar)
	
	_progress_label = Label.new()
	_progress_label.text = "0%"
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_size_override("font_size", 22)
	_progress_label.add_theme_color_override("font_color", Color.WHITE)
	_progress_label.add_theme_constant_override("outline_size", 6)
	_progress_label.add_theme_color_override("font_outline_color", Color("1e272e"))
	bar_container.add_child(_progress_label)

func _build_3d_splash_scene() -> void:
	var world3d := Node3D.new()
	world3d.name = "SplashWorld3D"
	_sub_viewport.add_child(world3d)
	
	# Camera: low-angle 3/4 perspective
	_car_camera = Camera3D.new()
	_car_camera.position = Vector3(0.0, 1.3, 4.4)
	_car_camera.rotation_degrees = Vector3(-10.0, 0.0, 0.0)
	_car_camera.fov = 42.0
	world3d.add_child(_car_camera)
	
	# Studio Lighting
	var key_light := DirectionalLight3D.new()
	key_light.position = Vector3(3.0, 4.5, 3.0)
	key_light.rotation_degrees = Vector3(-35.0, 40.0, 0.0)
	key_light.light_color = Color("fff5eb")
	key_light.light_energy = 1.6
	world3d.add_child(key_light)
	
	var rim_light := DirectionalLight3D.new()
	rim_light.position = Vector3(-3.0, 2.5, -3.0)
	rim_light.rotation_degrees = Vector3(20.0, -140.0, 0.0)
	rim_light.light_color = Color("00d2d3")
	rim_light.light_energy = 2.2
	world3d.add_child(rim_light)
	
	# Car Mount: Low-angle action pose (tilted 12 deg on X, 28 deg on Y)
	_car_mount = Node3D.new()
	_car_mount.name = "CarMount"
	_car_mount.position = Vector3(0.0, 0.15, 0.0)
	_car_mount.rotation_degrees = Vector3(12.0, 28.0, 0.0)
	world3d.add_child(_car_mount)

## Updates the Hero Splash Art with the equipped vehicle's stats & 3D model
func setup_equipped_car(car_id: String) -> void:
	var stats = null
	var path := "res://resources/vehicles/%s.tres" % car_id
	if ResourceLoader.exists(path):
		stats = load(path)
	
	if _car_name_label:
		_car_name_label.text = stats.car_name.to_upper() if stats else car_id.to_upper()
	if _rarity_badge_label and stats:
		_rarity_badge_label.text = "[%s]" % stats.rarity_tier
		_rarity_badge_label.add_theme_color_override("font_color", stats.rarity_color)
	if _callout_label:
		_callout_label.text = CALLOUT_MESSAGES[randi() % CALLOUT_MESSAGES.size()]
	
	# Clear old car model
	if _car_model and is_instance_valid(_car_model):
		_car_model.queue_free()
		_car_model = null
	
	# Build 3D voxel visuals
	var vab = get_node_or_null("/root/VoxelAssetBuilder")
	if vab and vab.has_method("build_player_car_visuals") and _car_mount:
		_car_model = vab.build_player_car_visuals(car_id)
		_car_mount.add_child(_car_model)

## Sets the loading percentage target (0.0 to 1.0)
func set_loading_progress(target: float) -> void:
	_target_progress = clampf(target, 0.0, 1.0)

func show_screen() -> void:
	visible = true
	_is_active = true
	if _sub_viewport:
		_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_target_progress = 0.0
	_display_progress = 0.0
	if _progress_bar:
		_progress_bar.value = 0.0
	if _progress_label:
		_progress_label.text = "0%"
	_tip_index = randi() % ROTATING_TIPS.size()
	if _tip_label:
		_tip_label.text = ROTATING_TIPS[_tip_index]

func hide_screen() -> void:
	_is_active = false
	visible = false
	if _sub_viewport:
		_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _car_model and is_instance_valid(_car_model):
		_car_model.queue_free()
		_car_model = null
