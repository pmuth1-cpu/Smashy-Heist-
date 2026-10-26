class_name GearScreen
extends Control

## Dedicated GEAR Screen ("BOOST YOUR PERFORMANCE")
## Matches the high-end sci-fi mobile brawler reference interface:
## - Top bar with Back, Title, Gems, and Home buttons
## - Left vertical slot category tabs (ENGINE, WHEELS, WINGS, ARMOR, GADGET, SKIN)
## - Center 3D turntable displaying the active 3D gear voxel model
## - Gear stats breakdown (+18% Speed, +12% Boost, Lv. 3/10) with UPGRADE (💎 2,500) and AUTO UPGRADE buttons
## - Bottom row of 6 equipped gear slots with active selection highlight
## - Right sidebar: GEAR SET BONUS card (Turbo Set, (2) +10% Speed, (4) +20% Boost) and 3x3 ALL GEAR inventory grid

signal back_pressed()
signal home_pressed()
signal gear_equipped(slot: String, gear_id: String)
signal gear_upgraded(gear_id: String, new_level: int)

const BrawlUITheme = preload("res://scripts/autoload/brawl_ui_theme.gd")
const SoundFX = preload("res://scripts/autoload/sound_fx.gd")

const CATEGORIES: Array[Dictionary] = [
	{"id": "engine", "name": "ENGINE", "code": "ENG", "color": Color("e67e22"), "icon": "⚡"},
	{"id": "wheels", "name": "WHEELS", "code": "WHL", "color": Color("f39c12"), "icon": "⚙️"},
	{"id": "wings", "name": "WINGS", "code": "WNG", "color": Color("0984e3"), "icon": "🕊️"},
	{"id": "armor", "name": "ARMOR", "code": "ARM", "color": Color("00cec9"), "icon": "🛡️"},
	{"id": "gadget", "name": "GADGET", "code": "GDT", "color": Color("a55eea"), "icon": "🚀"},
	{"id": "skin", "name": "SKIN", "code": "SKN", "color": Color("fd79a8"), "icon": "👕"}
]

const GEAR_CATALOG: Dictionary = {
	"engine": [
		{"id": "jet_engine", "name": "JET ENGINE", "tier": "EPIC", "color": Color("a55eea"), "stars": 3, "speed": 18, "boost": 12, "desc": "A high-performance jet engine that increases your top speed and boost duration."},
		{"id": "supercharger", "name": "SUPERCHARGER", "tier": "RARE", "color": Color("3498db"), "stars": 2, "speed": 12, "boost": 8, "desc": "Twin-screw blower providing immediate low-end torque."},
		{"id": "plasma_core", "name": "PLASMA TURBINE", "tier": "LEGENDARY", "color": Color("f1c40f"), "stars": 4, "speed": 25, "boost": 20, "desc": "Experimental fusion thruster with near-limitless thrust output."}
	],
	"wheels": [
		{"id": "cyber_wheels", "name": "CYBER ALLOY", "tier": "RARE", "color": Color("3498db"), "stars": 2, "speed": 8, "boost": 10, "desc": "Low-profile beadlock rims with magnetic grip compound."},
		{"id": "racing_slick", "name": "RACING SLICKS", "tier": "EPIC", "color": Color("a55eea"), "stars": 3, "speed": 14, "boost": 6, "desc": "Ultra-soft racing rubber engineered for flawless asphalt traction."}
	],
	"wings": [
		{"id": "gt_wings", "name": "GT CARBON WING", "tier": "EPIC", "color": Color("a55eea"), "stars": 3, "speed": 10, "boost": 14, "desc": "Downforce dual-plane spoiler stabilizing high-speed maneuvers."},
		{"id": "vortex_diffuser", "name": "VORTEX DIFFUSER", "tier": "RARE", "color": Color("3498db"), "stars": 2, "speed": 6, "boost": 12, "desc": "Underbody ground-effect tunnels sucking the chassis to the road."}
	],
	"armor": [
		{"id": "titanium_bullbar", "name": "TITANIUM BUMPER", "tier": "EPIC", "color": Color("a55eea"), "stars": 3, "speed": 5, "boost": 15, "desc": "Heavy-duty brush guard that shrugs off police barricades and spikes."},
		{"id": "spiked_plow", "name": "SPIKED RAM PROW", "tier": "LEGENDARY", "color": Color("f1c40f"), "stars": 4, "speed": 8, "boost": 20, "desc": "Serrated wedge plow sending rival vehicles flying into orbit."}
	],
	"gadget": [
		{"id": "nos_booster", "name": "DUAL NOS TANK", "tier": "RARE", "color": Color("3498db"), "stars": 2, "speed": 12, "boost": 16, "desc": "Pressurized nitrous oxide injection for supersonic bursts."},
		{"id": "emp_generator", "name": "EMP PULSE EMITTER", "tier": "LEGENDARY", "color": Color("f1c40f"), "stars": 4, "speed": 10, "boost": 25, "desc": "Radial electromagnetic pulse disabling nearby squad cars."}
	],
	"skin": [
		{"id": "prismatic_core", "name": "PRISMATIC CORE", "tier": "LEGENDARY", "color": Color("f1c40f"), "stars": 4, "speed": 15, "boost": 15, "desc": "Holographic polychromatic coating shifting colors with momentum."},
		{"id": "stealth_matte", "name": "STEALTH MATTE", "tier": "EPIC", "color": Color("a55eea"), "stars": 3, "speed": 8, "boost": 10, "desc": "Radar-absorbent carbon finish keeping unwanted eyes away."}
	]
}

var current_category: String = "engine"
var current_gear_id: String = "jet_engine"

# UI Nodes
var _gem_label: Label = null
var _category_buttons: Dictionary = {}
var _gear_name_label: Label = null
var _tier_badge_label: Label = null
var _stars_label: Label = null
var _level_label: Label = null
var _stat1_label: Label = null
var _stat2_label: Label = null
var _desc_label: Label = null
var _upgrade_btn: Button = null

var _equipped_slot_cards: Dictionary = {}
var _all_gear_container: GridContainer = null

# 3D Viewport
var _sub_viewport: SubViewport = null
var _pedestal_pivot: Node3D = null
var _gear_mount: Node3D = null
var _is_dragging: bool = false
var _last_drag_x: float = 0.0
var _angular_velocity: float = 0.0

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_build_ui()
	_connect_save_manager()
	
	select_category("engine")
	_refresh_currencies()

func _process(delta: float) -> void:
	if not visible:
		return
	if _pedestal_pivot and is_instance_valid(_pedestal_pivot):
		if not _is_dragging:
			_pedestal_pivot.rotation.y += (0.40 + _angular_velocity) * delta
			_angular_velocity *= pow(0.92, delta * 60.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed
			_last_drag_x = event.position.x
			if event.pressed:
				_angular_velocity = 0.0
	elif event is InputEventMouseMotion and _is_dragging:
		var dx: float = event.position.x - _last_drag_x
		_last_drag_x = event.position.x
		if _pedestal_pivot and is_instance_valid(_pedestal_pivot):
			_pedestal_pivot.rotation.y += dx * 0.015
			_angular_velocity = dx * 0.4

func _build_ui() -> void:
	# 1. Cinematic Sci-Fi Tuning Garage Background
	var bg_tex: Texture2D = BrawlUITheme.load_texture_safe("res://assets/textures/ui/gear_screen_bg.jpg")
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
	
	var tint := ColorRect.new()
	tint.set_anchors_preset(PRESET_FULL_RECT)
	tint.color = Color(0.04, 0.08, 0.14, 0.30)
	add_child(tint)
	
	# 2. 3D Gear Showcase Viewport
	_build_3d_stage()
	
	# 3. Header Bar
	_build_header_bar()
	
	# 4. Main Body Split Container
	var body_h := HBoxContainer.new()
	body_h.set_anchors_preset(PRESET_FULL_RECT)
	body_h.offset_left = 24.0
	body_h.offset_top = 84.0
	body_h.offset_right = -24.0
	body_h.offset_bottom = -16.0
	body_h.add_theme_constant_override("separation", 18)
	body_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body_h)
	
	# 4A. Left: Category Tabs
	_build_left_tabs(body_h)
	
	# 4B. Center: Details, Stats, Upgrade & Equipped Bar
	_build_center_column(body_h)
	
	# 4C. Right: Set Bonus & All Gear Grid
	_build_right_column(body_h)

func _build_3d_stage() -> void:
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
	cam.look_at_from_position(Vector3(-0.6, 2.0, 4.4), Vector3(-0.6, 0.95, 0.0), Vector3.UP)
	cam.fov = 38.0
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
	light.rotation_degrees = Vector3(-40.0, 45.0, 0.0)
	light.light_color = Color("ffffff")
	light.light_energy = 1.4
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 16.0
	light.shadow_bias = 0.03
	world.add_child(light)
	
	# Cool cyan fill light
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(20.0, -135.0, 0.0)
	fill.light_color = Color("80d8ff")
	fill.light_energy = 0.65
	world.add_child(fill)
	
	# Warm rim light (edge contour illumination)
	var rim := DirectionalLight3D.new()
	rim.name = "RimLight"
	rim.rotation_degrees = Vector3(35.0, 160.0, 0.0)
	rim.light_color = Color("ffeaa7")
	rim.light_energy = 0.95
	world.add_child(rim)
	
	# Pedestal Underglow Bounce Light
	var bounce := OmniLight3D.new()
	bounce.name = "PedestalBounceLight"
	bounce.position = Vector3(-0.6, 0.25, -1.2)
	bounce.light_color = Color("00e5ff")
	bounce.light_energy = 1.2
	bounce.omni_range = 4.5
	world.add_child(bounce)
	
	_pedestal_pivot = Node3D.new()
	_pedestal_pivot.position = Vector3(-0.6, 0.15, -1.2) # Shifted back on Z-axis and up on Y in 3D
	_pedestal_pivot.scale = Vector3(0.78, 0.78, 0.78) # Scaled so it fits with breathing room
	world.add_child(_pedestal_pivot)
	
	# High-Tech 3D Tuning Pedestal Disk
	var stage_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.95
	cyl.bottom_radius = 2.05
	cyl.height = 0.20
	cyl.radial_segments = 36
	stage_mesh.mesh = cyl
	var s_mat := StandardMaterial3D.new()
	s_mat.albedo_color = Color("141c28")
	s_mat.albedo_texture = BrawlUITheme.get_tech_panel_texture()
	s_mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
	s_mat.metallic = 0.88
	s_mat.roughness = 0.25
	stage_mesh.material_override = s_mat
	stage_mesh.position.y = -0.10
	_pedestal_pivot.add_child(stage_mesh)
	
	# Glowing Cyan/Amber Perimeter Ring
	var neon_mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.88
	torus.outer_radius = 1.98
	torus.rings = 36
	torus.ring_segments = 14
	neon_mesh.mesh = torus
	var n_mat := StandardMaterial3D.new()
	n_mat.albedo_color = Color("00d2d3")
	n_mat.emission_enabled = true
	n_mat.emission = Color("00d2d3")
	n_mat.emission_energy_multiplier = 2.5
	neon_mesh.material_override = n_mat
	neon_mesh.position.y = 0.01
	_pedestal_pivot.add_child(neon_mesh)
	
	_gear_mount = Node3D.new()
	_pedestal_pivot.add_child(_gear_mount)

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
	
	# LEFT: Back + Title
	var left_h := HBoxContainer.new()
	left_h.offset_left = 0.0
	left_h.offset_top = 0.0
	left_h.offset_bottom = 70.0
	left_h.alignment = BoxContainer.ALIGNMENT_BEGIN
	left_h.add_theme_constant_override("separation", 16)
	top_bar.add_child(left_h)
	
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
	
	var title_v := VBoxContainer.new()
	title_v.alignment = BoxContainer.ALIGNMENT_CENTER
	title_v.add_theme_constant_override("separation", 0)
	left_h.add_child(title_v)
	
	var title_lbl := Label.new()
	title_lbl.text = "⚙️ GEAR"
	title_lbl.label_settings = BrawlUITheme.make_label_settings(28, Color.WHITE, 6, 2)
	title_v.add_child(title_lbl)
	
	var sub_lbl := Label.new()
	sub_lbl.text = "BOOST YOUR PERFORMANCE"
	sub_lbl.label_settings = BrawlUITheme.make_label_settings(13, Color("74b9ff"), 3, 1)
	title_v.add_child(sub_lbl)
	
	# RIGHT: Gems + Home
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

func _build_left_tabs(parent: HBoxContainer) -> void:
	var left_box := VBoxContainer.new()
	left_box.custom_minimum_size = Vector2(235, 0)
	left_box.add_theme_constant_override("separation", 10)
	parent.add_child(left_box)
	
	for cat in CATEGORIES:
		var cat_id: String = cat["id"]
		var cat_name: String = cat["name"]
		var cat_code: String = cat.get("code", cat_name.substr(0, 3))
		var cat_col: Color = cat.get("color", Color("00d2d3"))
		
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
		bar.color = cat_col
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
		
		# Mini pill code tag
		var tag_panel := PanelContainer.new()
		tag_panel.name = "TagPanel"
		tag_panel.custom_minimum_size = Vector2(46, 26)
		var t_sb := StyleBoxFlat.new()
		t_sb.bg_color = Color(cat_col.r * 0.25, cat_col.g * 0.25, cat_col.b * 0.25, 0.9)
		t_sb.border_color = cat_col
		t_sb.set_border_width_all(1)
		t_sb.set_corner_radius_all(6)
		tag_panel.add_theme_stylebox_override("panel", t_sb)
		
		var tag_lbl := Label.new()
		tag_lbl.name = "TagLabel"
		tag_lbl.text = cat_code
		tag_lbl.label_settings = BrawlUITheme.make_label_settings(11, cat_col, 2, 1)
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag_panel.add_child(tag_lbl)
		row.add_child(tag_panel)
		
		# Title label
		var title_lbl := Label.new()
		title_lbl.name = "TitleLabel"
		title_lbl.text = cat_name
		title_lbl.label_settings = BrawlUITheme.make_label_settings(17, Color.WHITE, 3, 1)
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title_lbl)
		
		# Right chevron
		var chev := Label.new()
		chev.name = "Chevron"
		chev.text = "❯"
		chev.label_settings = BrawlUITheme.make_label_settings(16, Color("f1c40f"), 2, 1)
		row.add_child(chev)
		
		var is_active = (cat_id == current_category)
		_apply_cat_btn_style(btn, is_active, cat_id)
		
		btn.pressed.connect(func(cid = cat_id):
			SoundFX.play_ui_click()
			select_category(cid)
		)
		left_box.add_child(btn)
		_category_buttons[cat_id] = btn

func _apply_cat_btn_style(btn: Button, is_active: bool, cat_id: String = "") -> void:
	var cat_col: Color = Color("00d2d3")
	for c in CATEGORIES:
		if c["id"] == cat_id:
			cat_col = c.get("color", Color("00d2d3"))
			break
	
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
		bar.color = cat_col if is_active else Color(cat_col.r, cat_col.g, cat_col.b, 0.7)
	
	var row = btn.get_node_or_null("ContentRow")
	if row:
		var title_lbl = row.get_node_or_null("TitleLabel") as Label
		if title_lbl:
			var font_col = Color.WHITE if is_active else Color("8fa4be")
			title_lbl.label_settings = BrawlUITheme.make_label_settings(17, font_col, 3 if is_active else 2, 1)
		var chev = row.get_node_or_null("Chevron") as Label
		if chev:
			chev.label_settings = BrawlUITheme.make_label_settings(16, Color("f1c40f") if is_active else Color("223b56"), 2, 1)

func _build_center_column(parent: HBoxContainer) -> void:
	var center_v := VBoxContainer.new()
	center_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_v.add_theme_constant_override("separation", 12)
	parent.add_child(center_v)
	
	# Top Details Card (Over 3D Gear)
	var details_card := PanelContainer.new()
	details_card.add_theme_stylebox_override("panel", BrawlUITheme.make_neon_card_style(Color("081426ef"), Color("0984e3"), 16, 2))
	center_v.add_child(details_card)
	
	var d_vbox := VBoxContainer.new()
	d_vbox.add_theme_constant_override("separation", 8)
	details_card.add_child(d_vbox)
	
	# Name & Badges Row
	var name_h := HBoxContainer.new()
	name_h.add_theme_constant_override("separation", 12)
	d_vbox.add_child(name_h)
	
	_gear_name_label = Label.new()
	_gear_name_label.text = "JET ENGINE"
	_gear_name_label.label_settings = BrawlUITheme.make_label_settings(24, Color.WHITE, 6, 2)
	name_h.add_child(_gear_name_label)
	
	_tier_badge_label = Label.new()
	_tier_badge_label.text = "EPIC"
	_tier_badge_label.label_settings = BrawlUITheme.make_label_settings(14, Color("a55eea"), 3, 1)
	name_h.add_child(_tier_badge_label)
	
	_stars_label = Label.new()
	_stars_label.text = "★★★☆☆"
	_stars_label.label_settings = BrawlUITheme.make_label_settings(16, Color("f1c40f"), 3, 1)
	name_h.add_child(_stars_label)
	
	_level_label = Label.new()
	_level_label.text = "Lv. 3 / 10"
	_level_label.label_settings = BrawlUITheme.make_label_settings(18, Color.WHITE, 4, 1)
	name_h.add_child(_level_label)
	
	# Stats Row (Speed & Boost)
	var stats_h := HBoxContainer.new()
	stats_h.add_theme_constant_override("separation", 24)
	d_vbox.add_child(stats_h)
	
	_stat1_label = Label.new()
	_stat1_label.text = "⚡ SPEED  +18%"
	_stat1_label.label_settings = BrawlUITheme.make_label_settings(15, Color("2ecc71"), 3, 1)
	stats_h.add_child(_stat1_label)
	
	_stat2_label = Label.new()
	_stat2_label.text = "🚀 BOOST  +12%"
	_stat2_label.label_settings = BrawlUITheme.make_label_settings(15, Color("2ecc71"), 3, 1)
	stats_h.add_child(_stat2_label)
	
	_desc_label = Label.new()
	_desc_label.text = "A high-performance jet engine that increases your top speed and boost duration."
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.label_settings = BrawlUITheme.make_label_settings(13, Color("dfe6e9"), 2, 1)
	d_vbox.add_child(_desc_label)
	
	# Action Buttons (UPGRADE 💎 2,500 & AUTO UPGRADE)
	var action_h := HBoxContainer.new()
	action_h.add_theme_constant_override("separation", 16)
	d_vbox.add_child(action_h)
	
	_upgrade_btn = Button.new()
	_upgrade_btn.custom_minimum_size = Vector2(230, 74)
	_upgrade_btn.focus_mode = Control.FOCUS_NONE
	_upgrade_btn.text = "UPGRADE 💎 2,500"
	BrawlUITheme.attach_arcade_button_juice(_upgrade_btn, Color("f39c12"))
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	action_h.add_child(_upgrade_btn)
	
	var auto_btn := Button.new()
	auto_btn.custom_minimum_size = Vector2(230, 74)
	auto_btn.focus_mode = Control.FOCUS_NONE
	auto_btn.text = "AUTO UPGRADE ❯"
	BrawlUITheme.attach_arcade_button_juice(auto_btn, Color("0984e3"))
	auto_btn.pressed.connect(_on_upgrade_pressed)
	action_h.add_child(auto_btn)
	
	# Spacer for 3D Viewport
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_v.add_child(space)
	
	# Bottom: Equipped Gear Bar (6 Slots)
	var equipped_box := VBoxContainer.new()
	equipped_box.add_theme_constant_override("separation", 8)
	center_v.add_child(equipped_box)
	
	var eq_title := Label.new()
	eq_title.text = "EQUIPPED GEAR"
	eq_title.label_settings = BrawlUITheme.make_label_settings(14, Color("74b9ff"), 2, 1)
	equipped_box.add_child(eq_title)
	
	var eq_slots_h := HBoxContainer.new()
	eq_slots_h.add_theme_constant_override("separation", 12)
	equipped_box.add_child(eq_slots_h)
	
	for cat in CATEGORIES:
		var slot_card := Button.new()
		slot_card.custom_minimum_size = Vector2(100, 100)
		slot_card.focus_mode = Control.FOCUS_NONE
		
		var is_selected = (cat["id"] == current_category)
		_apply_slot_style(slot_card, is_selected)
		
		var gear_file_id: String = "jet_engine" if cat["id"] == "engine" else str(cat["id"])
		var g_tex_path := "res://assets/textures/gear/gear_%s.png" % gear_file_id
		var g_tex: Texture2D = BrawlUITheme.load_texture_safe(g_tex_path)
		if g_tex:
			var g_img := TextureRect.new()
			g_img.texture = g_tex
			g_img.set_anchors_preset(PRESET_FULL_RECT)
			g_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			g_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			g_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_card.add_child(g_img)
		else:
			slot_card.text = cat["icon"]
		
		slot_card.pressed.connect(func(cid = cat["id"]):
			SoundFX.play_ui_click()
			select_category(cid)
		)
		eq_slots_h.add_child(slot_card)
		_equipped_slot_cards[cat["id"]] = slot_card

func _apply_slot_style(card: Button, is_selected: bool) -> void:
	card.add_theme_stylebox_override("normal", BrawlUITheme.make_tier_card_style("EPIC", is_selected, 14))
	card.add_theme_stylebox_override("hover", BrawlUITheme.make_tier_card_style("EPIC", true, 14))
	card.add_theme_stylebox_override("pressed", BrawlUITheme.make_tier_card_style("EPIC", true, 14))

func _build_right_column(parent: HBoxContainer) -> void:
	var right_v := VBoxContainer.new()
	right_v.custom_minimum_size = Vector2(310, 0)
	right_v.add_theme_constant_override("separation", 14)
	parent.add_child(right_v)
	
	# ALL GEAR Inventory Grid (Set Bonus removed per user feedback: "don't need this")
	var inv_title := Label.new()
	inv_title.text = "ALL GEAR"
	inv_title.label_settings = BrawlUITheme.make_label_settings(16, Color("74b9ff"), 2, 1)
	right_v.add_child(inv_title)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_v.add_child(scroll)
	
	_all_gear_container = GridContainer.new()
	_all_gear_container.columns = 3
	_all_gear_container.add_theme_constant_override("h_separation", 10)
	_all_gear_container.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_all_gear_container)

func select_category(cat_id: String) -> void:
	current_category = cat_id
	for cid in _category_buttons:
		_apply_cat_btn_style(_category_buttons[cid], cid == current_category, cid)
	for sid in _equipped_slot_cards:
		_apply_slot_style(_equipped_slot_cards[sid], sid == current_category)
	
	var items: Array = GEAR_CATALOG.get(cat_id, [])
	if not items.is_empty():
		inspect_gear(items[0]["id"])
	_populate_all_gear_grid()

func inspect_gear(gear_id: String) -> void:
	current_gear_id = gear_id
	var item: Dictionary = _find_gear_def(gear_id)
	
	# Update 3D mount
	if _gear_mount and is_instance_valid(_gear_mount):
		for c in _gear_mount.get_children():
			c.queue_free()
		var vab = get_node_or_null("/root/VoxelAssetBuilder")
		if vab and vab.has_method("build_gear_visuals"):
			var mesh = vab.build_gear_visuals(current_category)
			_gear_mount.add_child(mesh)
	
	# Update labels
	if _gear_name_label:
		_gear_name_label.text = str(item.get("name", "GEAR"))
	if _tier_badge_label:
		_tier_badge_label.text = str(item.get("tier", "EPIC"))
		_tier_badge_label.label_settings.font_color = item.get("color", Color("a55eea"))
	
	var stars: int = int(item.get("stars", 3))
	if _stars_label:
		_stars_label.text = "★".repeat(stars) + "☆".repeat(5 - stars)
	
	var sm = get_node_or_null("/root/SaveManager")
	var lvl: int = sm.gear_levels.get(gear_id, 3) if sm else 3
	if _level_label:
		_level_label.text = "Lv. %d / 10" % lvl
	
	var sp: int = int(item.get("speed", 15)) + (lvl - 1) * 2
	var bt: int = int(item.get("boost", 10)) + (lvl - 1) * 2
	if _stat1_label:
		_stat1_label.text = "⚡ SPEED  +%d%%" % sp
	if _stat2_label:
		_stat2_label.text = "🚀 BOOST  +%d%%" % bt
	if _desc_label:
		_desc_label.text = str(item.get("desc", ""))
	
	# Equip gear into slot
	if sm and sm.has_method("equip_gear_slot"):
		sm.equip_gear_slot(current_category, gear_id)
	
	gear_equipped.emit(current_category, gear_id)
	_populate_all_gear_grid()

func _find_gear_def(gear_id: String) -> Dictionary:
	for cat in GEAR_CATALOG:
		for item in GEAR_CATALOG[cat]:
			if item["id"] == gear_id:
				return item
	return GEAR_CATALOG["engine"][0]

func _populate_all_gear_grid() -> void:
	if not _all_gear_container:
		return
	for c in _all_gear_container.get_children():
		c.queue_free()
	
	var items: Array = GEAR_CATALOG.get(current_category, [])
	var sm = get_node_or_null("/root/SaveManager")
	var equipped_in_slot: String = sm.gear_loadout.get(current_category, "") if sm else ""
	
	for item in items:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(102, 102)
		btn.focus_mode = Control.FOCUS_NONE
		
		var is_equipped: bool = (item["id"] == equipped_in_slot)
		var is_inspected: bool = (item["id"] == current_gear_id)
		var item_tier: String = str(item.get("tier", "EPIC"))
		
		btn.add_theme_stylebox_override("normal", BrawlUITheme.make_tier_card_style(item_tier, is_equipped or is_inspected, 14))
		btn.add_theme_stylebox_override("hover", BrawlUITheme.make_tier_card_style(item_tier, true, 14))
		btn.add_theme_stylebox_override("pressed", BrawlUITheme.make_tier_card_style(item_tier, true, 14))
		
		var gear_file_id: String = "jet_engine" if current_category == "engine" else current_category
		var g_tex_path := "res://assets/textures/gear/gear_%s.png" % gear_file_id
		var g_tex: Texture2D = BrawlUITheme.load_texture_safe(g_tex_path)
		if g_tex:
			var g_img := TextureRect.new()
			g_img.texture = g_tex
			g_img.set_anchors_preset(PRESET_FULL_RECT)
			g_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			g_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			g_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(g_img)
		
		if is_equipped:
			var chk := Label.new()
			chk.text = "✓"
			chk.label_settings = BrawlUITheme.make_label_settings(14, Color("f1c40f"), 2, 1)
			chk.position = Vector2(8, 6)
			btn.add_child(chk)
		
		btn.pressed.connect(func(gid = item["id"]):
			SoundFX.play_ui_click()
			inspect_gear(gid)
		)
		_all_gear_container.add_child(btn)

func _on_upgrade_pressed() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("upgrade_gear"):
		if sm.upgrade_gear(current_gear_id):
			SoundFX.play_star_up()
			var new_lvl: int = sm.gear_levels.get(current_gear_id, 1)
			inspect_gear(current_gear_id)
			gear_upgraded.emit(current_gear_id, new_lvl)
		else:
			SoundFX.play_ui_click()

func _connect_save_manager() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_signal("gems_changed"):
		sm.gems_changed.connect(func(_g): _refresh_currencies())

func _refresh_currencies() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if _gem_label and sm:
		_gem_label.text = "%d" % sm.total_gems

## Preserves clean vibrant voxel materials illuminated by studio lighting
func _apply_3d_gear_textures(_gear_node: Node3D, _category: String) -> void:
	# Retained as clean pass-through: voxel gear materials are preserved in their authentic
	# styling and illuminated by the studio WorldEnvironment & lights
	pass

