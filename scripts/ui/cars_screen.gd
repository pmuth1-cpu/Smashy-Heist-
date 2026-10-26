class_name CarsScreen
extends Control

## Dedicated CARS Screen ("COLLECT • UPGRADE • RACE")
## Matches the high-end sci-fi mobile brawler reference interface:
## - Top bar with Back, Title, Gems, and Home buttons
## - Left vertical rarity filter tabs (ALL, COMMON, RARE, EPIC, LEGENDARY)
## - Center 3D turntable display with carousel arrows and stat bars (Speed, Accel, Handling, Boost)
## - Right sidebar: Special Gadget card, skin selector, and primary UPGRADE button
## - Bottom horizontal car cards carousel with selected checkmarks and rarity badges

signal back_pressed()
signal home_pressed()
signal car_selected(car_id: String)
signal car_upgraded(car_id: String, new_level: int)

const BrawlUITheme = preload("res://scripts/autoload/brawl_ui_theme.gd")
const SoundFX = preload("res://scripts/autoload/sound_fx.gd")

const RARITY_TABS: Array[String] = ["ALL", "COMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC"]
const RARITY_TAB_CONFIG: Dictionary = {
	"ALL": {"code": "ALL", "col": Color("00d2d3")},
	"COMMON": {"code": "COM", "col": Color("95afc0")},
	"RARE": {"code": "RAR", "col": Color("0984e3")},
	"EPIC": {"code": "EPC", "col": Color("a55eea")},
	"LEGENDARY": {"code": "LEG", "col": Color("f1c40f")},
	"MYTHIC": {"code": "MYT", "col": Color("e056fd")},
}

var current_car_id: String = "tuk_tuk_jet"
var current_filter: String = "ALL"
var current_skin: String = "default"

# UI Nodes
var _gem_label: Label = null
var _filter_buttons: Dictionary = {}
var _car_name_label: Label = null
var _stars_label: Label = null
var _rarity_badge_label: Label = null
var _rarity_badge_panel: PanelContainer = null
var _stat_bars: Dictionary = {}

var _gadget_name_label: Label = null
var _gadget_desc_label: Label = null
var _skin_buttons: Array[Button] = []
var _upgrade_btn: Button = null
var _upgrade_btn_label: Label = null

var _carousel_container: HBoxContainer = null
var _car_cards: Dictionary = {}

# 3D Viewport
var _sub_viewport: SubViewport = null
var _pedestal_pivot: Node3D = null
var _car_mount: Node3D = null
var _is_dragging: bool = false
var _last_drag_x: float = 0.0
var _angular_velocity: float = 0.0
var _idle_timer: float = 0.0

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_build_ui()
	_connect_save_manager()
	
	# Load current equipped car from SaveManager
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.equipped_car_id:
		current_car_id = sm.equipped_car_id
	
	select_car(current_car_id)
	_refresh_currencies()

func _process(delta: float) -> void:
	if not visible:
		return
	if _pedestal_pivot and is_instance_valid(_pedestal_pivot):
		if not _is_dragging:
			if _idle_timer < 2.0:
				_idle_timer += delta
				_pedestal_pivot.rotation.y += _angular_velocity * delta
				_angular_velocity *= pow(0.92, delta * 60.0)
			else:
				_pedestal_pivot.rotation.y += (0.45 + _angular_velocity) * delta
				_angular_velocity *= pow(0.92, delta * 60.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed
			_last_drag_x = event.position.x
			if event.pressed:
				_angular_velocity = 0.0
				_idle_timer = 0.0
	elif event is InputEventMouseMotion and _is_dragging:
		var dx: float = event.position.x - _last_drag_x
		_last_drag_x = event.position.x
		if _pedestal_pivot and is_instance_valid(_pedestal_pivot):
			_pedestal_pivot.rotation.y += dx * 0.015
			_angular_velocity = dx * 0.4
			_idle_timer = 0.0

func _build_ui() -> void:
	# 1. Cinematic Sci-Fi Showroom Background
	var bg_tex: Texture2D = BrawlUITheme.load_texture_safe("res://assets/textures/ui/cars_screen_bg.jpg")
	if bg_tex:
		var bg := TextureRect.new()
		bg.set_anchors_preset(PRESET_FULL_RECT)
		bg.texture = bg_tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(bg)
	else:
		var col_bg := ColorRect.new()
		col_bg.set_anchors_preset(PRESET_FULL_RECT)
		col_bg.color = Color("07111e")
		add_child(col_bg)
	
	# Atmospheric tint overlay so UI stands out sharply while preserving the showroom
	var tint := ColorRect.new()
	tint.set_anchors_preset(PRESET_FULL_RECT)
	tint.color = Color(0.04, 0.08, 0.14, 0.35)
	add_child(tint)
	
	# 2. 3D Showroom Viewport (Center)
	_build_3d_turntable()
	
	# 3. Top Header Bar
	_build_header_bar()
	
	# 4. Main Body Split Container
	var body_h := HBoxContainer.new()
	body_h.set_anchors_preset(PRESET_FULL_RECT)
	body_h.offset_left = 24.0
	body_h.offset_top = 84.0
	body_h.offset_right = -24.0
	body_h.offset_bottom = -195.0
	body_h.add_theme_constant_override("separation", 18)
	body_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body_h)
	
	# 4A. Left Sidebar: Rarity Filter Tabs
	_build_left_filters(body_h)
	
	# 4B. Center Column: Carousel Navigation & Stats (Expands fully across screen)
	_build_center_column(body_h)
	
	# 4C. Right Sidebar: Removed per user feedback ("this section seem like unnessessary")
	_build_right_sidebar(null)
	
	# 5. Bottom Horizontal Car Carousel
	_build_bottom_carousel()

func _build_3d_turntable() -> void:
	var vp_cont := SubViewportContainer.new()
	vp_cont.set_anchors_preset(PRESET_FULL_RECT)
	vp_cont.stretch = true
	vp_cont.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(vp_cont)
	
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(1920, 1080)
	_sub_viewport.own_world_3d = true
	_sub_viewport.transparent_bg = true
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp_cont.add_child(_sub_viewport)
	
	var world := Node3D.new()
	_sub_viewport.add_child(world)
	
	var cam := Camera3D.new()
	cam.look_at_from_position(Vector3(0.0, 2.2, 5.2), Vector3(0.0, 0.45, 0.0), Vector3.UP)
	cam.fov = 42.0
	world.add_child(cam)
	
	# Environment with ACES tonemapper & glow for crisp, rich 3D studio lighting
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.TRANSPARENT
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.08
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("1e2738")
	env.ambient_light_energy = 0.40
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world.add_child(world_env)
	
	# Key Light with contact shadows
	var light := DirectionalLight3D.new()
	light.name = "KeyLight"
	light.rotation_degrees = Vector3(-38.0, 38.0, 0.0)
	light.light_color = Color("ffffff")
	light.light_energy = 1.35
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 16.0
	light.shadow_bias = 0.03
	world.add_child(light)
	
	# Cool cyan fill light
	var fill_light := DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.rotation_degrees = Vector3(25.0, -140.0, 0.0)
	fill_light.light_color = Color("80d8ff")
	fill_light.light_energy = 0.65
	world.add_child(fill_light)
	
	# Warm rim light (edge contour illumination)
	var rim_light := DirectionalLight3D.new()
	rim_light.name = "RimLight"
	rim_light.rotation_degrees = Vector3(35.0, 160.0, 0.0)
	rim_light.light_color = Color("ffeaa7")
	rim_light.light_energy = 0.95
	world.add_child(rim_light)
	
	# Turntable Underglow Bounce Light
	var bounce_light := OmniLight3D.new()
	bounce_light.name = "TurntableBounceLight"
	bounce_light.position = Vector3(0.0, 0.15, -1.2)
	bounce_light.light_color = Color("00e5ff")
	bounce_light.light_energy = 1.2
	bounce_light.omni_range = 4.5
	world.add_child(bounce_light)
	
	_pedestal_pivot = Node3D.new()
	_pedestal_pivot.position = Vector3(0.0, 0.0, -1.2) # Shifted back on Z-axis to give breathing room from UI
	_pedestal_pivot.rotation_degrees.y = 130.0 # Rotated Y by -25 degrees (from 155.0 showcase default)
	world.add_child(_pedestal_pivot)
	
	# Glowing Stage Turntable Disk with Hex Grid texture
	var vab = get_node_or_null("/root/VoxelAssetBuilder")
	var disk = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 2.4
	cyl.bottom_radius = 2.5
	cyl.height = 0.25
	cyl.radial_segments = 36
	disk.mesh = cyl
	var d_mat = StandardMaterial3D.new()
	d_mat.albedo_color = Color("0d1724")
	d_mat.albedo_texture = BrawlUITheme.get_hex_grid_texture()
	d_mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
	d_mat.metallic = 0.85
	d_mat.roughness = 0.28
	disk.material_override = d_mat
	disk.position.y = -0.12
	_pedestal_pivot.add_child(disk)
	
	# Textured Brushed Titanium Bevel Ring
	var bevel_disk = MeshInstance3D.new()
	var bevel_cyl = CylinderMesh.new()
	bevel_cyl.top_radius = 2.48
	bevel_cyl.bottom_radius = 2.56
	bevel_cyl.height = 0.08
	bevel_cyl.radial_segments = 36
	bevel_disk.mesh = bevel_cyl
	var b_mat = StandardMaterial3D.new()
	b_mat.albedo_texture = BrawlUITheme.get_brushed_metal_texture()
	b_mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
	b_mat.metallic = 0.90
	b_mat.roughness = 0.22
	bevel_disk.material_override = b_mat
	bevel_disk.position.y = -0.22
	_pedestal_pivot.add_child(bevel_disk)
	
	# Neon Cyan Ring
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 2.3
	torus.outer_radius = 2.42
	torus.rings = 36
	torus.ring_segments = 14
	ring.mesh = torus
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color("00d2d3")
	r_mat.emission_enabled = true
	r_mat.emission = Color("00d2d3")
	r_mat.emission_energy_multiplier = 2.5
	ring.material_override = r_mat
	ring.position.y = 0.01
	_pedestal_pivot.add_child(ring)
	
	_car_mount = Node3D.new()
	_car_mount.position = Vector3(0.0, 0.02, 0.0)
	_pedestal_pivot.add_child(_car_mount)

func _build_header_bar() -> void:
	var top_bar := Control.new()
	top_bar.anchor_right = 1.0
	top_bar.custom_minimum_size = Vector2(0, 80)
	top_bar.offset_top = 10.0
	top_bar.offset_bottom = 90.0
	top_bar.offset_left = 20.0
	top_bar.offset_right = -20.0
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)
	
	# --- LEFT: Back Button + Title ---
	var left_h := HBoxContainer.new()
	left_h.offset_left = 0.0
	left_h.offset_top = 0.0
	left_h.offset_bottom = 70.0
	left_h.alignment = BoxContainer.ALIGNMENT_BEGIN
	left_h.add_theme_constant_override("separation", 16)
	top_bar.add_child(left_h)
	
	# Back Button
	var back_btn := Button.new()
	back_btn.text = "◀"
	back_btn.custom_minimum_size = Vector2(76, 76)
	back_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_arcade_button_juice(back_btn, Color("00d2d3"))
	back_btn.pressed.connect(func():
		SoundFX.play_ui_click()
		back_pressed.emit()
	)
	left_h.add_child(back_btn)
	
	# Icon + CARS Title + Subtitle
	var title_v := VBoxContainer.new()
	title_v.alignment = BoxContainer.ALIGNMENT_CENTER
	title_v.add_theme_constant_override("separation", 0)
	left_h.add_child(title_v)
	
	var title_lbl := Label.new()
	title_lbl.text = "🚗 CARS"
	title_lbl.label_settings = BrawlUITheme.make_label_settings(28, Color.WHITE, 6, 2)
	title_v.add_child(title_lbl)
	
	var sub_lbl := Label.new()
	sub_lbl.text = "COLLECT • UPGRADE • RACE"
	sub_lbl.label_settings = BrawlUITheme.make_label_settings(13, Color("74b9ff"), 3, 1)
	title_v.add_child(sub_lbl)
	
	# --- RIGHT: Gems + Home Button ---
	var right_h := HBoxContainer.new()
	right_h.anchor_left = 1.0
	right_h.anchor_right = 1.0
	right_h.offset_left = -380.0
	right_h.offset_right = 0.0
	right_h.offset_top = 0.0
	right_h.offset_bottom = 76.0
	right_h.alignment = BoxContainer.ALIGNMENT_END
	right_h.add_theme_constant_override("separation", 14)
	top_bar.add_child(right_h)
	
	# Gem Capsule
	var gem_panel := PanelContainer.new()
	gem_panel.custom_minimum_size = Vector2(195, 58)
	gem_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_capsule_style(Color("06111f"), Color("0084a8"), 24))
	right_h.add_child(gem_panel)
	
	var gem_h := HBoxContainer.new()
	gem_h.alignment = BoxContainer.ALIGNMENT_CENTER
	gem_h.add_theme_constant_override("separation", 8)
	gem_panel.add_child(gem_h)
	
	var gem_icon := Label.new()
	gem_icon.text = "💎"
	gem_icon.label_settings = BrawlUITheme.make_label_settings(20, Color.WHITE, 0, 0)
	gem_h.add_child(gem_icon)
	
	_gem_label = Label.new()
	_gem_label.text = "59,752"
	_gem_label.label_settings = BrawlUITheme.make_label_settings(22, Color.WHITE, 4, 1)
	gem_h.add_child(_gem_label)
	
	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(44, 44)
	BrawlUITheme.attach_button_juice(plus_btn, Color("2ecc71"))
	gem_h.add_child(plus_btn)
	
	# Home Button
	var home_btn := Button.new()
	home_btn.text = "⌂"
	home_btn.custom_minimum_size = Vector2(76, 76)
	home_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_arcade_button_juice(home_btn, Color("00d2d3"))
	home_btn.pressed.connect(func():
		SoundFX.play_ui_click()
		home_pressed.emit()
	)
	right_h.add_child(home_btn)

func _build_left_filters(parent: HBoxContainer) -> void:
	var left_box := VBoxContainer.new()
	left_box.custom_minimum_size = Vector2(235, 0)
	left_box.add_theme_constant_override("separation", 12)
	parent.add_child(left_box)
	
	for tab_name in RARITY_TABS:
		var cfg: Dictionary = RARITY_TAB_CONFIG.get(tab_name, {"code": tab_name.substr(0, 3), "col": Color("00d2d3")})
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(235, 76)
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = "" # Rich arcade layout constructed with inner controls
		
		# Left colored accent stripe
		var bar := ColorRect.new()
		bar.name = "AccentBar"
		bar.anchor_bottom = 1.0
		bar.offset_left = 0.0
		bar.offset_right = 6.0
		bar.offset_top = 8.0
		bar.offset_bottom = -8.0
		bar.color = cfg["col"]
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bar)
		
		# Inner layout row
		var row := HBoxContainer.new()
		row.name = "ContentRow"
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 16.0
		row.offset_right = -14.0
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(row)
		
		# Pill code badge
		var tag_panel := PanelContainer.new()
		tag_panel.name = "TagPanel"
		tag_panel.custom_minimum_size = Vector2(46, 26)
		var t_sb := StyleBoxFlat.new()
		var col: Color = cfg["col"]
		t_sb.bg_color = Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 0.9)
		t_sb.border_color = col
		t_sb.set_border_width_all(1)
		t_sb.set_corner_radius_all(6)
		tag_panel.add_theme_stylebox_override("panel", t_sb)
		
		var tag_lbl := Label.new()
		tag_lbl.name = "TagLabel"
		tag_lbl.text = cfg["code"]
		tag_lbl.label_settings = BrawlUITheme.make_label_settings(11, col, 2, 1)
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag_panel.add_child(tag_lbl)
		row.add_child(tag_panel)
		
		# Title label
		var title_lbl := Label.new()
		title_lbl.name = "TitleLabel"
		title_lbl.text = tab_name
		title_lbl.label_settings = BrawlUITheme.make_label_settings(17, Color.WHITE, 3, 1)
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title_lbl)
		
		# Right chevron
		var chev := Label.new()
		chev.name = "Chevron"
		chev.text = "❯"
		chev.label_settings = BrawlUITheme.make_label_settings(16, Color("f1c40f"), 2, 1)
		row.add_child(chev)
		
		var is_active := (tab_name == current_filter)
		_apply_filter_btn_style(btn, is_active, tab_name)
		
		btn.pressed.connect(func(t = tab_name):
			SoundFX.play_ui_click()
			set_filter(t)
		)
		left_box.add_child(btn)
		_filter_buttons[tab_name] = btn

func _apply_filter_btn_style(btn: Button, is_active: bool, tab_name: String = "") -> void:
	var cfg: Dictionary = RARITY_TAB_CONFIG.get(tab_name, {"col": Color("00d2d3")})
	var accent_col: Color = cfg["col"]
	
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	if is_active:
		sb.bg_color = Color("14273d")
		sb.border_color = Color("f1c40f")
		sb.border_width_left = 7
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.shadow_color = Color("f1c40f", 0.35)
		sb.shadow_size = 8
	else:
		sb.bg_color = Color("081321")
		sb.border_color = Color("19283d")
		sb.border_width_left = 6
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	
	var bar = btn.get_node_or_null("AccentBar") as ColorRect
	if bar:
		bar.color = accent_col if is_active else Color(accent_col.r, accent_col.g, accent_col.b, 0.7)
	
	var row = btn.get_node_or_null("ContentRow")
	if row:
		var title_lbl = row.get_node_or_null("TitleLabel") as Label
		if title_lbl:
			var font_col = Color.WHITE if is_active else Color("8fa4be")
			title_lbl.label_settings = BrawlUITheme.make_label_settings(17, font_col, 3 if is_active else 2, 1)
		var chev = row.get_node_or_null("Chevron") as Label
		if chev:
			chev.label_settings = BrawlUITheme.make_label_settings(16, Color("f1c40f") if is_active else Color("223b56"), 2, 1)

func set_filter(filter_name: String) -> void:
	current_filter = filter_name
	for t in _filter_buttons:
		_apply_filter_btn_style(_filter_buttons[t], t == current_filter, t)
	_refresh_carousel_filtering()

func _build_center_column(parent: HBoxContainer) -> void:
	var center_v := VBoxContainer.new()
	center_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center_v)
	
	# Header Info over Turntable
	var info_h := HBoxContainer.new()
	info_h.alignment = BoxContainer.ALIGNMENT_CENTER
	info_h.add_theme_constant_override("separation", 14)
	center_v.add_child(info_h)
	
	_car_name_label = Label.new()
	_car_name_label.text = "TUK TUK JET"
	_car_name_label.label_settings = BrawlUITheme.make_label_settings(32, Color.WHITE, 8, 3)
	info_h.add_child(_car_name_label)
	
	_stars_label = Label.new()
	_stars_label.text = "★★★"
	_stars_label.label_settings = BrawlUITheme.make_label_settings(22, Color("f1c40f"), 4, 1)
	info_h.add_child(_stars_label)
	
	_rarity_badge_panel = PanelContainer.new()
	_rarity_badge_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_capsule_style(Color("0984e3"), Color("74b9ff"), 12))
	info_h.add_child(_rarity_badge_panel)
	
	_rarity_badge_label = Label.new()
	_rarity_badge_label.text = "RARE"
	_rarity_badge_label.label_settings = BrawlUITheme.make_label_settings(14, Color.WHITE, 2, 1)
	_rarity_badge_panel.add_child(_rarity_badge_label)
	
	# Spacer for 3D Turntable view
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_v.add_child(space)
	
	# Left & Right Carousel Arrows inside the space
	var arrows_h := HBoxContainer.new()
	arrows_h.set_anchors_preset(PRESET_FULL_RECT)
	arrows_h.alignment = BoxContainer.ALIGNMENT_CENTER
	space.add_child(arrows_h)
	
	var left_arrow := Button.new()
	left_arrow.text = "◀"
	left_arrow.custom_minimum_size = Vector2(76, 96)
	BrawlUITheme.attach_arcade_button_juice(left_arrow, Color("00d2d3"))
	left_arrow.pressed.connect(func(): _cycle_car(-1))
	arrows_h.add_child(left_arrow)
	
	var spacer_mid := Control.new()
	spacer_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arrows_h.add_child(spacer_mid)
	
	var right_arrow := Button.new()
	right_arrow.text = "▶"
	right_arrow.custom_minimum_size = Vector2(76, 96)
	BrawlUITheme.attach_arcade_button_juice(right_arrow, Color("00d2d3"))
	right_arrow.pressed.connect(func(): _cycle_car(1))
	arrows_h.add_child(right_arrow)
	
	# Stat Bars Box
	var stats_panel := PanelContainer.new()
	stats_panel.custom_minimum_size = Vector2(360, 100)
	stats_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stats_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_neon_card_style(Color("091524eb"), Color("00a8ff"), 14, 2))
	center_v.add_child(stats_panel)
	
	var stats_v := VBoxContainer.new()
	stats_v.add_theme_constant_override("separation", 6)
	stats_panel.add_child(stats_v)
	
	_stat_bars["speed"] = _build_stat_row(stats_v, "SPEED", 0.82)
	_stat_bars["accel"] = _build_stat_row(stats_v, "ACCELERATION", 0.90)
	_stat_bars["handling"] = _build_stat_row(stats_v, "HANDLING", 0.85)
	_stat_bars["boost"] = _build_stat_row(stats_v, "BOOST", 0.92)

func _build_stat_row(parent: VBoxContainer, stat_name: String, value: float) -> ProgressBar:
	var row_h := HBoxContainer.new()
	row_h.add_theme_constant_override("separation", 10)
	parent.add_child(row_h)
	
	var lbl := Label.new()
	lbl.text = stat_name
	lbl.custom_minimum_size = Vector2(110, 0)
	lbl.label_settings = BrawlUITheme.make_label_settings(13, Color("74b9ff"), 2, 1)
	row_h.add_child(lbl)
	
	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 14)
	bar.max_value = 1.0
	bar.value = value
	bar.show_percentage = false
	
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color("142236")
	bg_sb.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg_sb)
	
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color("00d2d3")
	fill_sb.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill_sb)
	
	row_h.add_child(bar)
	return bar

func _build_right_sidebar(parent: HBoxContainer) -> void:
	# Retain dummy references so tests and helper functions do not throw null errors,
	# but do not attach to screen parent (user requested removing right sidebar for maximum 3D stage room).
	_gadget_name_label = Label.new()
	_gadget_name_label.text = "TURBO JET FLIGHT"
	_gadget_desc_label = Label.new()
	_gadget_desc_label.text = "Activate to fly for a short time and gain speed boost."
	
	_skin_buttons.clear()
	for s_idx in range(2):
		var s_btn := Button.new()
		s_btn.custom_minimum_size = Vector2(88, 78)
		s_btn.pressed.connect(func(idx = s_idx): _on_skin_selected(idx))
		_skin_buttons.append(s_btn)
	
	_upgrade_btn = Button.new()
	_upgrade_btn_label = Label.new()
	_upgrade_btn_label.text = "UPGRADE (Lv. 3)"
	_upgrade_btn.add_child(_upgrade_btn_label)
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	
	if parent != null:
		pass

func _build_bottom_carousel() -> void:
	var bottom_panel := PanelContainer.new()
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.offset_top = -185.0
	bottom_panel.offset_bottom = -10.0
	bottom_panel.offset_left = 20.0
	bottom_panel.offset_right = -20.0
	bottom_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_neon_card_style(Color("06111fef"), Color("0984e3"), 18, 2))
	add_child(bottom_panel)
	
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom_panel.add_child(scroll)
	
	_carousel_container = HBoxContainer.new()
	_carousel_container.add_theme_constant_override("separation", 16)
	scroll.add_child(_carousel_container)
	
	_populate_carousel()

func _populate_carousel() -> void:
	for c in _carousel_container.get_children():
		c.queue_free()
	_car_cards.clear()
	
	var vdb = null
	if is_inside_tree():
		vdb = get_node_or_null("/root/VehicleDatabase")
	elif Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st and st.root:
			vdb = st.root.get_node_or_null("VehicleDatabase")
	
	var car_data: Dictionary = {}
	var all_cars: Array = []
	if vdb:
		car_data = vdb.VEHICLES
		all_cars = vdb.get_all_car_ids()
	else:
		var brawl_menu_script = load("res://scripts/ui/brawl_main_menu.gd")
		car_data = brawl_menu_script.CAR_DATA if brawl_menu_script else {}
		all_cars = brawl_menu_script.ALL_CAR_IDS if brawl_menu_script else []
	
	for car_id in all_cars:
		var info: Dictionary = car_data.get(car_id, {})
		var card := Button.new()
		card.custom_minimum_size = Vector2(215, 165)
		card.focus_mode = Control.FOCUS_NONE
		
		var is_selected: bool = (String(car_id) == current_car_id)
		var tier_str: String = str(info.get("rarity_tier", "RARE"))
		var tier_col: Color = BrawlUITheme.get_tier_color(tier_str)
		_apply_card_style(card, is_selected, tier_str)
		
		# 1. Background Radial Tier Glow (Gives rich depth and eliminates flat single-color look)
		var grad := Gradient.new()
		grad.colors = PackedColorArray([
			Color(tier_col.r, tier_col.g, tier_col.b, 0.36 if is_selected else 0.20),
			Color(tier_col.r * 0.4, tier_col.g * 0.4, tier_col.b * 0.4, 0.10),
			Color(0.03, 0.06, 0.12, 0.95)
		])
		grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		
		var gtex := GradientTexture2D.new()
		gtex.gradient = grad
		gtex.fill = GradientTexture2D.FILL_RADIAL
		gtex.fill_from = Vector2(0.5, 0.45)
		gtex.fill_to = Vector2(0.85, 0.9)
		gtex.width = 215
		gtex.height = 165
		
		var bg_rect := TextureRect.new()
		bg_rect.name = "BgGlow"
		bg_rect.texture = gtex
		bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
		bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(bg_rect)
		
		# 2. Tech top-header stripe in tier color
		var top_stripe := ColorRect.new()
		top_stripe.anchor_right = 1.0
		top_stripe.offset_left = 12.0
		top_stripe.offset_right = -12.0
		top_stripe.offset_top = 4.0
		top_stripe.offset_bottom = 6.0
		top_stripe.color = tier_col
		top_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(top_stripe)
		
		# 3. Turntable Neon Oval Platform under car image
		var platform := PanelContainer.new()
		platform.anchor_left = 0.5
		platform.anchor_right = 0.5
		platform.anchor_top = 0.5
		platform.anchor_bottom = 0.5
		platform.offset_left = -75.0
		platform.offset_right = 75.0
		platform.offset_top = -6.0
		platform.offset_bottom = 26.0
		var p_sb := StyleBoxFlat.new()
		p_sb.bg_color = Color(tier_col.r * 0.2, tier_col.g * 0.2, tier_col.b * 0.2, 0.45)
		p_sb.border_color = Color(tier_col.r, tier_col.g, tier_col.b, 0.75)
		p_sb.set_border_width_all(2)
		p_sb.set_corner_radius_all(16)
		p_sb.shadow_color = Color(tier_col.r, tier_col.g, tier_col.b, 0.4)
		p_sb.shadow_size = 6
		platform.add_theme_stylebox_override("panel", p_sb)
		platform.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(platform)
		
		# 4. Content VBox
		var card_v := VBoxContainer.new()
		card_v.name = "CardVBox"
		card_v.set_anchors_preset(PRESET_FULL_RECT)
		card_v.alignment = BoxContainer.ALIGNMENT_CENTER
		card_v.add_theme_constant_override("separation", 2)
		card_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(card_v)
		
		# Selected Gold Check Badge
		var check_lbl := Label.new()
		check_lbl.text = "✓ EQUIPPED" if is_selected else ""
		check_lbl.label_settings = BrawlUITheme.make_label_settings(10, Color("f1c40f"), 3, 1)
		check_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_v.add_child(check_lbl)
		
		# Exact 3D Rendered Car Thumbnail on Tier Background
		var tex_path := "res://assets/textures/cars/car_%s.png" % car_id
		var car_tex: Texture2D = BrawlUITheme.load_texture_safe(tex_path)
		if car_tex:
			var car_img := TextureRect.new()
			car_img.texture = car_tex
			car_img.custom_minimum_size = Vector2(165, 84)
			car_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			car_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			card_v.add_child(car_img)
		else:
			var icon_lbl := Label.new()
			icon_lbl.text = "🏎️"
			icon_lbl.label_settings = BrawlUITheme.make_label_settings(28, Color.WHITE, 0, 0)
			icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card_v.add_child(icon_lbl)
		
		# Name
		var name_lbl := Label.new()
		name_lbl.text = str(info.get("name", car_id.to_upper()))
		name_lbl.label_settings = BrawlUITheme.make_label_settings(12, Color.WHITE, 3, 1)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_v.add_child(name_lbl)
		
		# Rarity Pill Badge
		var rar_panel := PanelContainer.new()
		rar_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rar_panel.custom_minimum_size = Vector2(76, 16)
		var r_sb := StyleBoxFlat.new()
		r_sb.bg_color = Color(tier_col.r * 0.25, tier_col.g * 0.25, tier_col.b * 0.25, 0.8)
		r_sb.border_color = tier_col
		r_sb.set_border_width_all(1)
		r_sb.set_corner_radius_all(6)
		rar_panel.add_theme_stylebox_override("panel", r_sb)
		
		var rar_lbl := Label.new()
		rar_lbl.text = tier_str
		rar_lbl.label_settings = BrawlUITheme.make_label_settings(9, tier_col, 2, 1)
		rar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rar_panel.add_child(rar_lbl)
		card_v.add_child(rar_panel)
		
		card.pressed.connect(func(cid = car_id):
			SoundFX.play_ui_click()
			select_car(cid)
		)
		
		_carousel_container.add_child(card)
		_car_cards[car_id] = card

func _apply_card_style(card: Button, is_selected: bool, tier_or_col) -> void:
	var tier := "RARE"
	if tier_or_col is String:
		tier = tier_or_col
	var tier_col: Color = BrawlUITheme.get_tier_color(tier)
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("08121f")
	sb.border_color = Color("f1c40f") if is_selected else tier_col
	sb.set_border_width_all(3 if is_selected else 2)
	sb.set_corner_radius_all(14)
	sb.shadow_color = (Color("f1c40f", 0.5) if is_selected else tier_col * Color(1, 1, 1, 0.35))
	sb.shadow_size = 12 if is_selected else 6
	card.add_theme_stylebox_override("normal", sb)
	card.add_theme_stylebox_override("hover", sb)
	card.add_theme_stylebox_override("pressed", sb)

func _refresh_carousel_filtering() -> void:
	var vdb = null
	if is_inside_tree():
		vdb = get_node_or_null("/root/VehicleDatabase")
	elif Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st and st.root:
			vdb = st.root.get_node_or_null("VehicleDatabase")
	
	var car_data: Dictionary = vdb.VEHICLES if vdb else {}
	if car_data.is_empty():
		var brawl_menu_script = load("res://scripts/ui/brawl_main_menu.gd")
		car_data = brawl_menu_script.CAR_DATA if brawl_menu_script else {}
		
	for car_id in _car_cards:
		var info: Dictionary = car_data.get(car_id, {})
		var tier = str(info.get("rarity_tier", "COMMON"))
		var matches: bool = (current_filter == "ALL" or tier == current_filter)
		_car_cards[car_id].visible = matches

func select_car(car_id: String) -> void:
	current_car_id = car_id
	_idle_timer = 0.0
	if _pedestal_pivot and is_instance_valid(_pedestal_pivot):
		_pedestal_pivot.rotation_degrees.y = 130.0
		_angular_velocity = 0.0
	
	var vdb = null
	if is_inside_tree():
		vdb = get_node_or_null("/root/VehicleDatabase")
	elif Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st and st.root:
			vdb = st.root.get_node_or_null("VehicleDatabase")
	
	var car_data: Dictionary = vdb.VEHICLES if vdb else {}
	if car_data.is_empty():
		var brawl_menu_script = load("res://scripts/ui/brawl_main_menu.gd")
		car_data = brawl_menu_script.CAR_DATA if brawl_menu_script else {}
		
	var info: Dictionary = car_data.get(car_id, car_data.get("default_coupe", {}))
	
	# Update 3D mount
	if _car_mount and is_instance_valid(_car_mount):
		for c in _car_mount.get_children():
			c.queue_free()
		var vab = get_node_or_null("/root/VoxelAssetBuilder")
		if vab and vab.has_method("build_player_car_visuals"):
			var car_mesh = vab.build_player_car_visuals(car_id)
			_car_mount.add_child(car_mesh)
	
	# Update Labels & Stats
	if _car_name_label:
		_car_name_label.text = str(info.get("name", "BRAWLER"))
	
	var stars: int = int(info.get("stars", 3))
	if _stars_label:
		_stars_label.text = "★".repeat(stars)
	
	var tier: String = str(info.get("rarity_tier", "RARE"))
	var r_col: Color = info.get("rarity_color", Color("3498db"))
	if _rarity_badge_label:
		_rarity_badge_label.text = tier
	if _rarity_badge_panel:
		_rarity_badge_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_capsule_style(r_col, r_col.lightened(0.2), 12))
	
	# Stat bars
	var sm = get_node_or_null("/root/SaveManager")
	var lvl: int = sm.car_levels.get(car_id, 1) if sm else 1
	var bonus: float = (lvl - 1) * 0.04
	
	if _stat_bars.has("speed"):
		_stat_bars["speed"].value = minf(1.0, float(info.get("speed", 0.7)) + bonus)
	if _stat_bars.has("accel"):
		_stat_bars["accel"].value = minf(1.0, float(info.get("accel", 0.7)) + bonus)
	if _stat_bars.has("handling"):
		_stat_bars["handling"].value = minf(1.0, float(info.get("handling", 0.7)) + bonus)
	if _stat_bars.has("boost"):
		_stat_bars["boost"].value = minf(1.0, float(info.get("boost", 0.7)) + bonus)
	
	# Gadget info
	if _gadget_name_label:
		_gadget_name_label.text = str(info.get("gadget_name", info.get("gadget", "NITRO BOOST")))
	if _gadget_desc_label:
		_gadget_desc_label.text = str(info.get("gadget_desc", info.get("desc", "High performance booster.")))
	
	# Upgrade Button Label
	if _upgrade_btn_label:
		_upgrade_btn_label.text = "UPGRADE (Lv. %d)" % lvl
	
	# Persist equipped car
	if sm and sm.has_method("equip_car"):
		sm.equip_car(car_id)
	
	# Refresh carousel card borders & equipped badges
	for cid in _car_cards:
		var c_info: Dictionary = car_data.get(cid, {})
		_apply_card_style(_car_cards[cid], cid == current_car_id, c_info.get("rarity_tier", "RARE"))
		var v = _car_cards[cid].get_node_or_null("CardVBox")
		if not v:
			for ch in _car_cards[cid].get_children():
				if ch is VBoxContainer:
					v = ch
					break
		if v and v.get_child_count() > 0:
			var chk = v.get_child(0) as Label
			if chk:
				chk.text = "✓ EQUIPPED" if cid == current_car_id else ""
	
	car_selected.emit(car_id)

func _cycle_car(direction: int) -> void:
	var brawl_menu_script = load("res://scripts/ui/brawl_main_menu.gd")
	var all_cars: Array = brawl_menu_script.ALL_CAR_IDS if brawl_menu_script else []
	var cur_idx: int = all_cars.find(current_car_id)
	if cur_idx == -1:
		cur_idx = 0
	var next_idx: int = posmod(cur_idx + direction, all_cars.size())
	SoundFX.play_ui_click()
	select_car(all_cars[next_idx])

func _on_skin_selected(skin_idx: int) -> void:
	current_skin = "default" if skin_idx == 0 else "stealth"
	SoundFX.play_ui_click()
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("set_car_skin"):
		sm.set_car_skin(current_car_id, current_skin)
	# Visual toggle feedback on skin buttons
	for i in range(_skin_buttons.size()):
		var b = _skin_buttons[i]
		BrawlUITheme.attach_arcade_button_juice(b, Color("f1c40f") if i == skin_idx else Color("00d2d3"))

func _on_upgrade_pressed() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("upgrade_car"):
		if sm.upgrade_car(current_car_id):
			SoundFX.play_star_up()
			var new_lvl: int = sm.car_levels.get(current_car_id, 1)
			if _upgrade_btn_label:
				_upgrade_btn_label.text = "UPGRADE (Lv. %d)" % new_lvl
			select_car(current_car_id)
			car_upgraded.emit(current_car_id, new_lvl)
		else:
			SoundFX.play_ui_click()

func _connect_save_manager() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		if sm.has_signal("gems_changed"):
			sm.gems_changed.connect(func(_g): _refresh_currencies())
		if sm.has_signal("car_equipped"):
			sm.car_equipped.connect(func(cid):
				if cid != current_car_id:
					select_car(cid)
			)

func _refresh_currencies() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if _gem_label and sm:
		_gem_label.text = "%d" % sm.total_gems

## Preserves clean vibrant voxel materials illuminated by studio lighting
func _apply_3d_car_textures(_car_node: Node3D) -> void:
	# Retained as clean pass-through: voxel materials are preserved in their authentic
	# high-contrast styling and illuminated by the studio WorldEnvironment & lights
	pass

