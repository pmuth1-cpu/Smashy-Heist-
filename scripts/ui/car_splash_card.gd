class_name CarSplashCard
extends PanelContainer

## Stylized 2D/3D Comic Splash Art Card for the BrawlMainMenu Garage Picker Drawer
## Features:
## - Comic starburst / speed-stripe background colored by rarity_color
## - 3D SubViewport rendering vehicle in a heroic mid-jump drift angle
## - Shiny rarity badge, vehicle name, and equipped/locked status indicators

signal card_clicked(car_id: String)

var car_id: String = "default_coupe"
var is_unlocked: bool = true
var is_equipped: bool = false
var is_selected: bool = false

var _viewport_container: SubViewportContainer = null
var _sub_viewport: SubViewport = null
var _car_mount: Node3D = null
var _car_mesh: Node3D = null

var _name_label: Label = null
var _rarity_label: Label = null
var _status_badge: Label = null
var _lock_overlay: ColorRect = null
var _bg_starburst: Control = null

static func make_card_stylebox(bg_color: Color, border_color: Color, border_width: int = 4, corner_radius: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(corner_radius)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	return sb

func _ready() -> void:
	custom_minimum_size = Vector2(340, 220)
	mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_gui_input)
	_build_ui()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		card_clicked.emit(car_id)

func _build_ui() -> void:
	# Clip children to panel bounds
	clip_contents = true
	
	# Background comic starburst container
	_bg_starburst = Control.new()
	_bg_starburst.name = "StarburstBG"
	_bg_starburst.set_anchors_preset(PRESET_FULL_RECT)
	_bg_starburst.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_bg_starburst)
	
	# Add comic speed stripe polygons
	for i in range(4):
		var stripe := Polygon2D.new()
		stripe.color = Color(1, 1, 1, 0.08)
		var x_start := i * 90.0 - 20.0
		stripe.polygon = PackedVector2Array([
			Vector2(x_start, 0),
			Vector2(x_start + 45.0, 0),
			Vector2(x_start - 25.0, 220),
			Vector2(x_start - 70.0, 220)
		])
		_bg_starburst.add_child(stripe)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = MOUSE_FILTER_PASS
	add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = MOUSE_FILTER_PASS
	margin.add_child(vbox)
	
	# Top Row: Rarity Badge and Status Pill
	var top_h := HBoxContainer.new()
	top_h.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(top_h)
	
	_rarity_label = Label.new()
	_rarity_label.text = "[RARE]"
	_rarity_label.add_theme_font_size_override("font_size", 13)
	_rarity_label.add_theme_color_override("font_color", Color("f1c40f"))
	top_h.add_child(_rarity_label)
	
	var sp := Control.new()
	sp.size_flags_horizontal = SIZE_EXPAND_FILL
	top_h.add_child(sp)
	
	_status_badge = Label.new()
	_status_badge.text = "EQUIPPED"
	_status_badge.add_theme_font_size_override("font_size", 12)
	_status_badge.add_theme_color_override("font_color", Color("2ecc71"))
	top_h.add_child(_status_badge)
	
	# Middle: 3D SubViewport
	_viewport_container = SubViewportContainer.new()
	_viewport_container.custom_minimum_size = Vector2(316, 130)
	_viewport_container.size_flags_vertical = SIZE_EXPAND_FILL
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = MOUSE_FILTER_PASS
	vbox.add_child(_viewport_container)
	
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(316, 130)
	_sub_viewport.transparent_bg = true
	_sub_viewport.handle_input_locally = false
	_viewport_container.add_child(_sub_viewport)
	
	_build_3d_viewport_scene()
	
	# Bottom: Car Name Label
	_name_label = Label.new()
	_name_label.text = "GETAWAY COUPE"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", Color("f5f6fa"))
	_name_label.add_theme_constant_override("outline_size", 4)
	_name_label.add_theme_color_override("font_outline_color", Color("1e272e"))
	vbox.add_child(_name_label)
	
	# Lock overlay (shown if car is not unlocked)
	_lock_overlay = ColorRect.new()
	_lock_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_lock_overlay.color = Color(0.04, 0.05, 0.08, 0.72)
	_lock_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	_lock_overlay.visible = false
	add_child(_lock_overlay)
	
	var lock_lbl := Label.new()
	lock_lbl.text = "🔒 LOCKED\n(MEGA BOX)"
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_lbl.set_anchors_preset(PRESET_FULL_RECT)
	lock_lbl.add_theme_font_size_override("font_size", 18)
	lock_lbl.add_theme_color_override("font_color", Color("e74c3c"))
	_lock_overlay.add_child(lock_lbl)

func _build_3d_viewport_scene() -> void:
	var world := Node3D.new()
	world.name = "CardWorld"
	_sub_viewport.add_child(world)
	
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.4, 3.8)
	cam.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	cam.fov = 38.0
	world.add_child(cam)
	
	var light := DirectionalLight3D.new()
	light.position = Vector3(2.0, 4.0, 3.0)
	light.rotation_degrees = Vector3(-35.0, 35.0, 0.0)
	light.light_energy = 1.6
	world.add_child(light)
	
	var rim := DirectionalLight3D.new()
	rim.position = Vector3(-2.0, 2.0, -2.0)
	rim.rotation_degrees = Vector3(15.0, -145.0, 0.0)
	rim.light_energy = 1.8
	world.add_child(rim)
	
	# Posed in heroic mid-jump drift angle
	_car_mount = Node3D.new()
	_car_mount.name = "CarMount"
	_car_mount.position = Vector3(0.0, 0.1, 0.0)
	_car_mount.rotation_degrees = Vector3(-8.0, 32.0, 6.0)
	world.add_child(_car_mount)

## Reconfigures card data, 3D mesh, and styling
func setup_card(p_car_id: String, p_unlocked: bool, p_equipped: bool, p_selected: bool) -> void:
	car_id = p_car_id
	is_unlocked = p_unlocked
	is_equipped = p_equipped
	is_selected = p_selected
	
	var stats = null
	var path := "res://resources/vehicles/%s.tres" % car_id
	if ResourceLoader.exists(path):
		stats = load(path)
	
	var r_color: Color = stats.rarity_color if stats else Color("f1c40f")
	var bg_color := Color(0.12, 0.15, 0.22) if is_selected else Color(0.08, 0.10, 0.14)
	var border_color := Color("f5f6fa") if is_selected else r_color
	var border_w: int = 5 if is_selected else 3
	
	add_theme_stylebox_override("panel", make_card_stylebox(bg_color, border_color, border_w, 14))
	
	if _name_label:
		_name_label.text = stats.car_name.to_upper() if stats else car_id.to_upper()
	if _rarity_label and stats:
		_rarity_label.text = "[%s]" % stats.rarity_tier
		_rarity_label.add_theme_color_override("font_color", r_color)
	
	if _status_badge:
		if is_equipped:
			_status_badge.text = "✓ EQUIPPED"
			_status_badge.add_theme_color_override("font_color", Color("2ecc71"))
			_status_badge.visible = true
		elif is_selected:
			_status_badge.text = "VIEWING"
			_status_badge.add_theme_color_override("font_color", Color("f1c40f"))
			_status_badge.visible = true
		else:
			_status_badge.visible = false
	
	if _lock_overlay:
		_lock_overlay.visible = not is_unlocked
	
	# Load 3D model
	if _car_mesh and is_instance_valid(_car_mesh):
		_car_mesh.queue_free()
		_car_mesh = null
	
	var vab = null
	if is_inside_tree():
		vab = get_node_or_null("/root/VoxelAssetBuilder")
	elif Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st and st.root:
			vab = st.root.get_node_or_null("VoxelAssetBuilder")
	
	if vab and vab.has_method("build_player_car_visuals") and _car_mount:
		_car_mesh = vab.build_player_car_visuals(car_id)
		_car_mount.add_child(_car_mesh)
