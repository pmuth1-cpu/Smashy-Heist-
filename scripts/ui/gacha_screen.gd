class_name GachaScreen
extends Control

## Dedicated GACHA Screen ("GET NEW CARS • GEAR • SKINS")
## Matches the high-end sci-fi mobile brawler reference interface:
## - Top bar with Back, Title, Gacha Cubes (12), Gems (59,752), Info (?), and Home buttons
## - Left vertical banner tabs (FEATURED, CAR GACHA, GEAR GACHA, SKIN GACHA)
## - Grand Featured Banner with cosmic nebula backdrop, "LIMITED TIME", "LEGENDARY TUK TUK JET",
##   countdown "Ends in 2d 14h", 3D rotating showcase, drop preview strip, and DETAILS button
## - Bottom action bar: LUCKY METER (32/100 pity), 1 SPIN (120 🎲), and 10 SPINS (1,080 🎲, -10% OFF)
## - Right sidebar: MORE REWARDS milestone ladder, and Mascot Bot ("NEXT REWARD in 8 spins")
## - Interactive spin opening animation and award result modal

signal back_pressed()
signal home_pressed()
signal spin_completed(rewards: Array[Dictionary])

const BrawlUITheme = preload("res://scripts/autoload/brawl_ui_theme.gd")
const SoundFX = preload("res://scripts/autoload/sound_fx.gd")

const BANNERS: Array[Dictionary] = [
	{"id": "featured", "name": "FEATURED", "icon": "👑"},
	{"id": "car", "name": "CAR GACHA", "icon": "🚗"},
	{"id": "gear", "name": "GEAR GACHA", "icon": "⚙️"},
	{"id": "skin", "name": "SKIN GACHA", "icon": "🎨"}
]

const DROP_POOL: Array[Dictionary] = [
	{"name": "LEGENDARY TUK TUK JET", "tier": "LEGENDARY", "color": Color("f1c40f"), "icon": "🏎️", "weight": 5, "id": "tuk_tuk_jet", "type": "car"},
	{"name": "FIRE DRAGON", "tier": "LEGENDARY", "color": Color("f1c40f"), "icon": "🐉", "weight": 5, "id": "fire_dragon", "type": "car"},
	{"name": "SHADOW HYPERCAR", "tier": "LEGENDARY", "color": Color("f1c40f"), "icon": "🛸", "weight": 8, "id": "shadow", "type": "car"},
	{"name": "RACER 01", "tier": "EPIC", "color": Color("a55eea"), "icon": "🏎️", "weight": 18, "id": "racer_01", "type": "car"},
	{"name": "TANKER ASSAULT", "tier": "EPIC", "color": Color("a55eea"), "icon": "🚜", "weight": 18, "id": "tanker", "type": "car"},
	{"name": "JET ENGINE (Lv. 3)", "tier": "EPIC", "color": Color("a55eea"), "icon": "⚡", "weight": 22, "id": "jet_engine", "type": "gear"},
	{"name": "CYBER ALLOY WHEELS", "tier": "RARE", "color": Color("3498db"), "icon": "⚙️", "weight": 35, "id": "wheels", "type": "gear"},
	{"name": "GT CARBON WING", "tier": "RARE", "color": Color("3498db"), "icon": "🕊️", "weight": 35, "id": "wings", "type": "gear"},
	{"name": "500 BONUS GEMS", "tier": "RARE", "color": Color("2ecc71"), "icon": "💎", "weight": 40, "id": "gems", "type": "currency"},
	{"name": "1,000 CASH COINS", "tier": "COMMON", "color": Color("dfe6e9"), "icon": "💰", "weight": 60, "id": "coins", "type": "currency"}
]

var current_banner: String = "featured"

# UI Nodes
var _token_label: Label = null
var _gem_label: Label = null
var _banner_buttons: Dictionary = {}
var _lucky_bar: ProgressBar = null
var _lucky_label: Label = null
var _result_modal: Control = null
var _result_cards_h: HBoxContainer = null
var _chest_container: CenterContainer = null
var _chest_rect: TextureRect = null
var _flash_rect: ColorRect = null
var _reveal_content: Control = null
var _info_modal: Control = null
var _active_anim_tweens: Array[Tween] = []

# 3D Showcase
var _sub_viewport: SubViewport = null
var _pedestal_pivot: Node3D = null
var _model_mount: Node3D = null
var _is_dragging: bool = false
var _last_drag_x: float = 0.0
var _angular_velocity: float = 0.0

static func _get_drop_texture(drop: Dictionary) -> Texture2D:
	var item_type: String = str(drop.get("type", ""))
	var item_id: String = str(drop.get("id", ""))
	var name_str: String = str(drop.get("name", ""))
	
	if item_type == "car" or "TUK TUK" in name_str or "DRAGON" in name_str or "SHADOW" in name_str or "RACER" in name_str or "TANKER" in name_str:
		var car_id: String = item_id if item_id != "" else (
			"tuk_tuk_jet" if "TUK TUK" in name_str else (
				"fire_dragon" if "DRAGON" in name_str else (
					"shadow" if "SHADOW" in name_str else (
						"racer_01" if "RACER" in name_str else "tanker"
					)
				)
			)
		)
		var p := "res://assets/textures/cars/car_%s.png" % car_id
		return BrawlUITheme.load_texture_safe(p)
	elif item_type == "gear" or "ENGINE" in name_str or "WHEEL" in name_str or "WING" in name_str or "ARMOR" in name_str or "GADGET" in name_str or "SKIN" in name_str:
		var gear_id: String = item_id if item_id != "" else (
			"jet_engine" if "ENGINE" in name_str else (
				"wheels" if "WHEEL" in name_str else (
					"wings" if "WING" in name_str else (
						"armor" if "ARMOR" in name_str else (
							"gadget" if "GADGET" in name_str else "skin"
						)
					)
				)
			)
		)
		var p := "res://assets/textures/gear/gear_%s.png" % gear_id
		return BrawlUITheme.load_texture_safe(p)
	return null

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_build_ui()
	_connect_save_manager()
	select_banner("featured")
	_refresh_currencies()

func _process(delta: float) -> void:
	if not visible:
		return
	if _pedestal_pivot and is_instance_valid(_pedestal_pivot):
		if not _is_dragging:
			_pedestal_pivot.rotation.y += (0.50 + _angular_velocity) * delta
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
	# 1. Cinematic Cosmic Gacha Portal Background
	var bg_tex: Texture2D = BrawlUITheme.load_texture_safe("res://assets/textures/ui/gacha_screen_bg.jpg")
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
	tint.color = Color(0.04, 0.06, 0.12, 0.28)
	add_child(tint)
	
	# 2. 3D Featured Showcase Viewport
	_build_3d_stage()
	
	# 3. Top Header Bar
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
	
	# 4A. Left: Banner Categories
	_build_left_banners(body_h)
	
	# 4B. Center: Grand Banner & Spin Buttons
	_build_center_banner_area(body_h)
	
	# 4C. Right: Milestone Ladder & Mascot Bot
	_build_right_milestones(body_h)
	
	# 5. Spin Result Modal Overlay
	_build_result_modal()

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
	cam.look_at_from_position(Vector3(0.0, 1.9, 5.0), Vector3(0.0, 0.45, 0.0), Vector3.UP)
	cam.fov = 42.0
	world.add_child(cam)
	
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, 45.0, 0.0)
	light.light_color = Color("ffffff")
	light.light_energy = 1.5
	world.add_child(light)
	
	var neon_purple := DirectionalLight3D.new()
	neon_purple.rotation_degrees = Vector3(25.0, -135.0, 0.0)
	neon_purple.light_color = Color("a55eea")
	neon_purple.light_energy = 1.0
	world.add_child(neon_purple)
	
	_pedestal_pivot = Node3D.new()
	_pedestal_pivot.position = Vector3(0.0, 0.0, 0.0)
	world.add_child(_pedestal_pivot)
	
	# Neon Hexagonal Gacha Turntable
	var vab = get_node_or_null("/root/VoxelAssetBuilder")
	var disk = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 2.4
	cyl.bottom_radius = 2.5
	cyl.height = 0.25
	disk.mesh = cyl
	var d_mat = StandardMaterial3D.new()
	d_mat.albedo_color = Color("130f40")
	disk.material_override = d_mat
	disk.position.y = -0.12
	_pedestal_pivot.add_child(disk)
	
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 2.3
	torus.outer_radius = 2.42
	ring.mesh = torus
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color("f1c40f")
	r_mat.emission_enabled = true
	r_mat.emission = Color("f1c40f")
	r_mat.emission_energy_multiplier = 2.0
	ring.material_override = r_mat
	ring.position.y = 0.01
	_pedestal_pivot.add_child(ring)
	
	_model_mount = Node3D.new()
	_model_mount.position = Vector3(0.0, 0.02, 0.0)
	_pedestal_pivot.add_child(_model_mount)

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
	title_lbl.text = "🎁 GACHA"
	title_lbl.label_settings = BrawlUITheme.make_label_settings(28, Color.WHITE, 6, 2)
	title_v.add_child(title_lbl)
	
	var sub_lbl := Label.new()
	sub_lbl.text = "GET NEW CARS • GEAR • SKINS"
	sub_lbl.label_settings = BrawlUITheme.make_label_settings(13, Color("74b9ff"), 3, 1)
	title_v.add_child(sub_lbl)
	
	# RIGHT: Gacha Cubes + Gems + Info + Home
	var right_h := HBoxContainer.new()
	right_h.anchor_left = 1.0
	right_h.anchor_right = 1.0
	right_h.offset_left = -540.0
	right_h.offset_right = 0.0
	right_h.offset_top = 0.0
	right_h.offset_bottom = 76.0
	right_h.alignment = BoxContainer.ALIGNMENT_END
	right_h.add_theme_constant_override("separation", 12)
	top_bar.add_child(right_h)
	
	# Gacha Cubes Capsule
	var cube_panel := PanelContainer.new()
	cube_panel.custom_minimum_size = Vector2(155, 58)
	cube_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_capsule_style(Color("06111f"), Color("8e44ad"), 24))
	right_h.add_child(cube_panel)
	
	var cube_h := HBoxContainer.new()
	cube_h.alignment = BoxContainer.ALIGNMENT_CENTER
	cube_h.add_theme_constant_override("separation", 8)
	cube_panel.add_child(cube_h)
	
	var c_icon := Label.new()
	c_icon.text = "🎲"
	c_icon.label_settings = BrawlUITheme.make_label_settings(20, Color.WHITE, 0, 0)
	cube_h.add_child(c_icon)
	
	_token_label = Label.new()
	_token_label.text = "12"
	_token_label.label_settings = BrawlUITheme.make_label_settings(22, Color.WHITE, 4, 1)
	cube_h.add_child(_token_label)
	
	var c_plus := Button.new()
	c_plus.text = "+"
	c_plus.custom_minimum_size = Vector2(44, 44)
	BrawlUITheme.attach_button_juice(c_plus, Color("a55eea"))
	cube_h.add_child(c_plus)
	
	# Gem Capsule
	var gem_panel := PanelContainer.new()
	gem_panel.custom_minimum_size = Vector2(195, 58)
	gem_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_capsule_style(Color("06111f"), Color("0084a8"), 24))
	right_h.add_child(gem_panel)
	
	var gem_h := HBoxContainer.new()
	gem_h.alignment = BoxContainer.ALIGNMENT_CENTER
	gem_h.add_theme_constant_override("separation", 8)
	gem_panel.add_child(gem_h)
	
	var g_icon := Label.new()
	g_icon.text = "💎"
	g_icon.label_settings = BrawlUITheme.make_label_settings(20, Color.WHITE, 0, 0)
	gem_h.add_child(g_icon)
	
	_gem_label = Label.new()
	_gem_label.text = "59,752"
	_gem_label.label_settings = BrawlUITheme.make_label_settings(22, Color.WHITE, 4, 1)
	gem_h.add_child(_gem_label)
	
	var g_plus := Button.new()
	g_plus.text = "+"
	g_plus.custom_minimum_size = Vector2(44, 44)
	BrawlUITheme.attach_button_juice(g_plus, Color("2ecc71"))
	gem_h.add_child(g_plus)
	
	# Info Button
	var info_btn := Button.new()
	info_btn.text = "?"
	info_btn.custom_minimum_size = Vector2(76, 76)
	info_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_arcade_button_juice(info_btn, Color("00d2d3"))
	info_btn.pressed.connect(_show_rates_info)
	right_h.add_child(info_btn)
	
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

func _build_left_banners(parent: HBoxContainer) -> void:
	var left_box := VBoxContainer.new()
	left_box.custom_minimum_size = Vector2(205, 0)
	left_box.add_theme_constant_override("separation", 12)
	parent.add_child(left_box)
	
	for b in BANNERS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(205, 72)
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = "  " + b["icon"] + " " + b["name"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var is_active = (b["id"] == current_banner)
		_apply_banner_btn_style(btn, is_active)
		
		btn.pressed.connect(func(bid = b["id"]):
			SoundFX.play_ui_click()
			select_banner(bid)
		)
		left_box.add_child(btn)
		_banner_buttons[b["id"]] = btn

func _apply_banner_btn_style(btn: Button, is_active: bool) -> void:
	if is_active:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("142236")
		sb.border_color = Color("f39c12")
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(14)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_color_override("font_color", Color("f1c40f"))
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("0a1524")
		sb.border_color = Color("1e3048")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_color_override("font_color", Color("74b9ff"))

func _build_center_banner_area(parent: HBoxContainer) -> void:
	var center_v := VBoxContainer.new()
	center_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_v.add_theme_constant_override("separation", 10)
	parent.add_child(center_v)
	
	# Grand Banner Container with Glowing Cosmic Border
	var banner_card := PanelContainer.new()
	banner_card.custom_minimum_size = Vector2(0, 160)
	banner_card.add_theme_stylebox_override("panel", BrawlUITheme.make_neon_card_style(Color("100826cc"), Color("f39c12"), 20, 3))
	center_v.add_child(banner_card)
	
	var b_vbox := VBoxContainer.new()
	b_vbox.add_theme_constant_override("separation", 6)
	banner_card.add_child(b_vbox)
	
	# Top Badges Row (LIMITED TIME, Rating & Countdown)
	var badges_h := HBoxContainer.new()
	badges_h.add_theme_constant_override("separation", 12)
	b_vbox.add_child(badges_h)
	
	var ribbon := PanelContainer.new()
	ribbon.add_theme_stylebox_override("panel", BrawlUITheme.make_capsule_style(Color("e84118"), Color("ff7675"), 10))
	var r_lbl := Label.new()
	r_lbl.text = "LIMITED TIME"
	r_lbl.label_settings = BrawlUITheme.make_label_settings(12, Color.WHITE, 2, 1)
	ribbon.add_child(r_lbl)
	badges_h.add_child(ribbon)
	
	var timer_lbl := Label.new()
	timer_lbl.text = "⏱ Ends in 2d 14h"
	timer_lbl.label_settings = BrawlUITheme.make_label_settings(13, Color("f1c40f"), 2, 1)
	badges_h.add_child(timer_lbl)
	
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badges_h.add_child(spacer)
	
	var stars_lbl := Label.new()
	stars_lbl.text = "★★★★ LEGENDARY"
	stars_lbl.label_settings = BrawlUITheme.make_label_settings(14, Color("f1c40f"), 3, 1)
	badges_h.add_child(stars_lbl)
	
	# Banner Title & Subtitle
	var title_lbl := Label.new()
	title_lbl.text = "LEGENDARY TUK TUK JET"
	title_lbl.label_settings = BrawlUITheme.make_label_settings(32, Color.WHITE, 8, 3)
	b_vbox.add_child(title_lbl)
	
	var sub_lbl := Label.new()
	sub_lbl.text = "SPIN NOW FOR A CHANCE TO GET!"
	sub_lbl.label_settings = BrawlUITheme.make_label_settings(14, Color("74b9ff"), 3, 1)
	b_vbox.add_child(sub_lbl)
	
	# Drop Preview Strip
	var reel_h := HBoxContainer.new()
	reel_h.add_theme_constant_override("separation", 10)
	b_vbox.add_child(reel_h)
	
	for drop in DROP_POOL.slice(0, 6):
		var pill := PanelContainer.new()
		pill.custom_minimum_size = Vector2(58, 58)
		var tier_str: String = str(drop.get("tier", "RARE"))
		pill.add_theme_stylebox_override("panel", BrawlUITheme.make_tier_card_style(tier_str, false, 12))
		
		var tex: Texture2D = _get_drop_texture(drop)
		if tex:
			var img := TextureRect.new()
			img.texture = tex
			img.custom_minimum_size = Vector2(48, 48)
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pill.add_child(img)
		else:
			var l := Label.new()
			l.text = drop["icon"]
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			pill.add_child(l)
		reel_h.add_child(pill)
	
	var details_btn := Button.new()
	details_btn.text = "DETAILS ❯"
	details_btn.custom_minimum_size = Vector2(130, 58)
	details_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_arcade_button_juice(details_btn, Color("00d2d3"))
	details_btn.pressed.connect(_show_rates_info)
	reel_h.add_child(details_btn)
	
	# Spacer for 3D Viewport
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_v.add_child(space)
	
	# Bottom Action Bar (Lucky Meter + 1 Spin + 10 Spins) - Scaled for Mobile Touch
	var bottom_h := HBoxContainer.new()
	bottom_h.add_theme_constant_override("separation", 16)
	center_v.add_child(bottom_h)
	
	# Lucky Meter Box (Scaled to 96px height)
	var lucky_panel := PanelContainer.new()
	lucky_panel.custom_minimum_size = Vector2(240, 96)
	lucky_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_neon_card_style(Color("081426eb"), Color("00d2d3"), 16, 2))
	bottom_h.add_child(lucky_panel)
	
	var lucky_v := VBoxContainer.new()
	lucky_v.alignment = BoxContainer.ALIGNMENT_CENTER
	lucky_v.add_theme_constant_override("separation", 6)
	lucky_panel.add_child(lucky_v)
	
	var l_top_h := HBoxContainer.new()
	lucky_v.add_child(l_top_h)
	
	var l_title := Label.new()
	l_title.text = "🎯 LUCKY METER"
	l_title.label_settings = BrawlUITheme.make_label_settings(14, Color("74b9ff"), 2, 1)
	l_top_h.add_child(l_title)
	
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_top_h.add_child(sp2)
	
	_lucky_label = Label.new()
	_lucky_label.text = "32 / 100"
	_lucky_label.label_settings = BrawlUITheme.make_label_settings(14, Color("f1c40f"), 2, 1)
	l_top_h.add_child(_lucky_label)
	
	_lucky_bar = ProgressBar.new()
	_lucky_bar.custom_minimum_size = Vector2(0, 16)
	_lucky_bar.max_value = 100
	_lucky_bar.value = 32
	_lucky_bar.show_percentage = false
	
	var l_bg := StyleBoxFlat.new()
	l_bg.bg_color = Color("142236")
	l_bg.set_corner_radius_all(6)
	_lucky_bar.add_theme_stylebox_override("background", l_bg)
	
	var l_fill := StyleBoxFlat.new()
	l_fill.bg_color = Color("f1c40f")
	l_fill.set_corner_radius_all(6)
	_lucky_bar.add_theme_stylebox_override("fill", l_fill)
	lucky_v.add_child(_lucky_bar)
	
	# 1 Spin Button (Scaled to 250x96 for mobile touch)
	var spin1_btn := Button.new()
	spin1_btn.custom_minimum_size = Vector2(250, 96)
	spin1_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_textured_button_juice(spin1_btn, "res://assets/ui/btn_gold_cta.png", Color("f39c12"), 24.0)
	spin1_btn.pressed.connect(func(): _perform_spins(1))
	bottom_h.add_child(spin1_btn)
	
	var s1_v := VBoxContainer.new()
	s1_v.set_anchors_preset(PRESET_FULL_RECT)
	s1_v.alignment = BoxContainer.ALIGNMENT_CENTER
	s1_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spin1_btn.add_child(s1_v)
	
	var s1_lbl := Label.new()
	s1_lbl.text = "1 SPIN"
	s1_lbl.label_settings = BrawlUITheme.make_label_settings(20, Color.WHITE, 4, 1)
	s1_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s1_v.add_child(s1_lbl)
	
	var s1_cost := Label.new()
	s1_cost.text = "🎲 120"
	s1_cost.label_settings = BrawlUITheme.make_label_settings(15, Color("00d2d3"), 2, 1)
	s1_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s1_v.add_child(s1_cost)
	
	# 10 Spins Button with -10% OFF Tag (Scaled to 290x96 for mobile touch)
	var spin10_btn := Button.new()
	spin10_btn.custom_minimum_size = Vector2(290, 96)
	spin10_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_textured_button_juice(spin10_btn, "res://assets/ui/btn_gold_cta.png", Color("f39c12"), 24.0)
	spin10_btn.pressed.connect(func(): _perform_spins(10))
	bottom_h.add_child(spin10_btn)
	
	var s10_v := VBoxContainer.new()
	s10_v.set_anchors_preset(PRESET_FULL_RECT)
	s10_v.alignment = BoxContainer.ALIGNMENT_CENTER
	s10_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spin10_btn.add_child(s10_v)
	
	var s10_lbl := Label.new()
	s10_lbl.text = "10 SPINS"
	s10_lbl.label_settings = BrawlUITheme.make_label_settings(20, Color.WHITE, 4, 1)
	s10_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s10_v.add_child(s10_lbl)
	
	var s10_cost := Label.new()
	s10_cost.text = "🎲 1,080"
	s10_cost.label_settings = BrawlUITheme.make_label_settings(15, Color("f1c40f"), 2, 1)
	s10_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s10_v.add_child(s10_cost)
	
	# Red Discount Pill
	var disc := PanelContainer.new()
	disc.position = Vector2(170, -10)
	disc.add_theme_stylebox_override("panel", BrawlUITheme.make_capsule_style(Color("e84118"), Color("ff7675"), 10))
	var d_lbl := Label.new()
	d_lbl.text = "-10% OFF"
	d_lbl.label_settings = BrawlUITheme.make_label_settings(11, Color.WHITE, 2, 1)
	disc.add_child(d_lbl)
	spin10_btn.add_child(disc)

func _build_right_milestones(parent: HBoxContainer) -> void:
	var right_v := VBoxContainer.new()
	right_v.custom_minimum_size = Vector2(240, 0)
	right_v.add_theme_constant_override("separation", 12)
	parent.add_child(right_v)
	
	# MORE REWARDS Card
	var more_card := PanelContainer.new()
	more_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	more_card.add_theme_stylebox_override("panel", BrawlUITheme.make_neon_card_style(Color("081426eb"), Color("0984e3"), 16, 2))
	right_v.add_child(more_card)
	
	var m_vbox := VBoxContainer.new()
	m_vbox.add_theme_constant_override("separation", 10)
	more_card.add_child(m_vbox)
	
	var m_head := HBoxContainer.new()
	m_vbox.add_child(m_head)
	
	var m_lbl := Label.new()
	m_lbl.text = "MORE REWARDS"
	m_lbl.label_settings = BrawlUITheme.make_label_settings(13, Color("74b9ff"), 2, 1)
	m_head.add_child(m_lbl)
	
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_head.add_child(sp)
	
	var view_all := Label.new()
	view_all.text = "VIEW ALL"
	view_all.label_settings = BrawlUITheme.make_label_settings(12, Color("f1c40f"), 2, 1)
	m_head.add_child(view_all)
	
	# Milestone Ladder Preview Items
	for item in [
		{"icon": "🏎️", "name": "Tuk Tuk Jet", "tier": "LEGENDARY", "id": "tuk_tuk_jet", "type": "car"},
		{"icon": "⚡", "name": "Jet Engine Lv.3", "tier": "EPIC", "id": "jet_engine", "type": "gear"},
		{"icon": "🛡️", "name": "Plated Armor", "tier": "RARE", "id": "armor", "type": "gear"},
		{"icon": "👑", "name": "Master Crown", "tier": "MYTHIC", "id": "skin", "type": "gear"}
	]:
		var r_item := PanelContainer.new()
		r_item.custom_minimum_size = Vector2(0, 56)
		var item_tier: String = str(item.get("tier", "RARE"))
		r_item.add_theme_stylebox_override("panel", BrawlUITheme.make_tier_card_style(item_tier, false, 12))
		m_vbox.add_child(r_item)
		
		var ri_h := HBoxContainer.new()
		ri_h.add_theme_constant_override("separation", 10)
		r_item.add_child(ri_h)
		
		var tex: Texture2D = _get_drop_texture(item)
		if tex:
			var img := TextureRect.new()
			img.texture = tex
			img.custom_minimum_size = Vector2(44, 44)
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ri_h.add_child(img)
		else:
			var icon := Label.new()
			icon.text = item["icon"]
			icon.custom_minimum_size = Vector2(36, 36)
			icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ri_h.add_child(icon)
		
		var name_lbl := Label.new()
		name_lbl.text = item["name"]
		name_lbl.label_settings = BrawlUITheme.make_label_settings(13, Color.WHITE, 2, 1)
		ri_h.add_child(name_lbl)
	
	# Mascot Bot Card
	var bot_card := PanelContainer.new()
	bot_card.custom_minimum_size = Vector2(0, 84)
	bot_card.add_theme_stylebox_override("panel", BrawlUITheme.make_neon_card_style(Color("100826eb"), Color("f1c40f"), 16, 2))
	right_v.add_child(bot_card)
	
	var bot_h := HBoxContainer.new()
	bot_h.add_theme_constant_override("separation", 12)
	bot_card.add_child(bot_h)
	
	var bot_icon := Label.new()
	bot_icon.text = "🤖"
	bot_icon.label_settings = BrawlUITheme.make_label_settings(36, Color.WHITE, 0, 0)
	bot_h.add_child(bot_icon)
	
	var bot_v := VBoxContainer.new()
	bot_v.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_h.add_child(bot_v)
	
	var b_lbl1 := Label.new()
	b_lbl1.text = "NEXT REWARD"
	b_lbl1.label_settings = BrawlUITheme.make_label_settings(12, Color("74b9ff"), 2, 1)
	bot_v.add_child(b_lbl1)
	
	var b_lbl2 := Label.new()
	b_lbl2.text = "in 8 spins"
	b_lbl2.label_settings = BrawlUITheme.make_label_settings(18, Color("f1c40f"), 3, 1)
	bot_v.add_child(b_lbl2)

func _build_result_modal() -> void:
	_result_modal = Control.new()
	_result_modal.set_anchors_preset(PRESET_FULL_RECT)
	_result_modal.visible = false
	add_child(_result_modal)
	
	# Dim backdrop
	var dim := ColorRect.new()
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.05, 0.98)
	_result_modal.add_child(dim)
	
	# Chest Container (Centered)
	_chest_container = CenterContainer.new()
	_chest_container.set_anchors_preset(PRESET_FULL_RECT)
	_chest_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_modal.add_child(_chest_container)
	
	_chest_rect = TextureRect.new()
	_chest_rect.custom_minimum_size = Vector2(380, 380)
	_chest_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_chest_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var c_tex: Texture2D = BrawlUITheme.load_texture_safe("res://assets/textures/ui/gacha_chest_closed.jpg")
	if c_tex:
		_chest_rect.texture = c_tex
	_chest_container.add_child(_chest_rect)
	
	# Flash explosion overlay
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(PRESET_FULL_RECT)
	_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_modal.add_child(_flash_rect)
	
	# Reveal Content Container (Overlaid)
	_reveal_content = Control.new()
	_reveal_content.set_anchors_preset(PRESET_FULL_RECT)
	_reveal_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_modal.add_child(_reveal_content)
	
	var r_center := CenterContainer.new()
	r_center.set_anchors_preset(PRESET_FULL_RECT)
	r_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_content.add_child(r_center)
	
	var main_v := VBoxContainer.new()
	main_v.alignment = BoxContainer.ALIGNMENT_CENTER
	main_v.add_theme_constant_override("separation", 16)
	r_center.add_child(main_v)
	
	# Header
	var title_lbl := Label.new()
	title_lbl.text = "🎉 GACHA REWARDS UNLOCKED! 🎉"
	title_lbl.label_settings = BrawlUITheme.make_label_settings(32, Color("f1c40f"), 8, 3)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_v.add_child(title_lbl)
	
	var sub_lbl := Label.new()
	sub_lbl.text = "CHECK YOUR GARAGE AND WORKSHOP TO EQUIP YOUR NEW LOOT"
	sub_lbl.label_settings = BrawlUITheme.make_label_settings(14, Color("74b9ff"), 3, 1)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_v.add_child(sub_lbl)
	
	# Scroll area for reward cards
	var scroll_panel := PanelContainer.new()
	scroll_panel.custom_minimum_size = Vector2(1250, 340)
	scroll_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_neon_card_style(Color("081426ea"), Color("0984e3"), 20, 2))
	main_v.add_child(scroll_panel)
	
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_panel.add_child(scroll)
	
	_result_cards_h = HBoxContainer.new()
	_result_cards_h.add_theme_constant_override("separation", 16)
	_result_cards_h.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_cards_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_cards_h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_result_cards_h)
	
	# Bottom CLAIM REWARDS Button (scaled large for mobile touch: 360x84)
	var claim_btn := Button.new()
	claim_btn.text = "AWESOME! CLAIM REWARDS"
	claim_btn.custom_minimum_size = Vector2(360, 84)
	claim_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	claim_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_textured_button_juice(claim_btn, "res://assets/ui/btn_primary_green.png", Color("2ecc71"), 24.0)
	claim_btn.pressed.connect(func():
		SoundFX.play_ui_click()
		_finish_gacha_animation()
		_result_modal.visible = false
	)
	main_v.add_child(claim_btn)
	
	# Skip button (top-right, scaled for mobile touch: 150x58)
	var skip_btn := Button.new()
	skip_btn.text = "SKIP ❯❯"
	skip_btn.custom_minimum_size = Vector2(150, 58)
	skip_btn.anchor_left = 1.0
	skip_btn.anchor_right = 1.0
	skip_btn.offset_left = -180.0
	skip_btn.offset_right = -30.0
	skip_btn.offset_top = 20.0
	skip_btn.offset_bottom = 78.0
	skip_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_arcade_button_juice(skip_btn, Color("00d2d3"))
	skip_btn.pressed.connect(func():
		SoundFX.play_ui_click()
		_finish_gacha_animation()
	)
	_result_modal.add_child(skip_btn)

func _finish_gacha_animation() -> void:
	for tw in _active_anim_tweens:
		if tw and is_instance_valid(tw) and tw.is_valid():
			tw.kill()
	_active_anim_tweens.clear()
	
	if _chest_rect and is_instance_valid(_chest_rect):
		var o_tex: Texture2D = BrawlUITheme.load_texture_safe("res://assets/textures/ui/gacha_chest_opened_flash.jpg")
		if o_tex:
			_chest_rect.texture = o_tex
		_chest_rect.scale = Vector2.ONE * 0.8
		_chest_rect.rotation = 0.0
		_chest_rect.modulate.a = 0.35
	if _flash_rect and is_instance_valid(_flash_rect):
		_flash_rect.color.a = 0.0
	if _reveal_content and is_instance_valid(_reveal_content):
		_reveal_content.visible = true
		_reveal_content.modulate.a = 1.0
	if _result_cards_h and is_instance_valid(_result_cards_h):
		for card in _result_cards_h.get_children():
			card.scale = Vector2.ONE
			card.modulate.a = 1.0

func select_banner(banner_id: String) -> void:
	current_banner = banner_id
	for bid in _banner_buttons:
		_apply_banner_btn_style(_banner_buttons[bid], bid == current_banner)
	
	# Update 3D model
	if _model_mount and is_instance_valid(_model_mount):
		for c in _model_mount.get_children():
			c.queue_free()
		var vab = get_node_or_null("/root/VoxelAssetBuilder")
		if vab:
			if banner_id == "gear":
				_model_mount.add_child(vab.build_gear_jet_engine())
			elif banner_id == "skin":
				_model_mount.add_child(vab.build_gear_skin())
			elif banner_id == "car":
				_model_mount.add_child(vab.build_player_car_visuals("fire_dragon"))
			else:
				_model_mount.add_child(vab.build_player_car_visuals("tuk_tuk_jet"))

func _perform_spins(count: int) -> void:
	var sm = get_node_or_null("/root/SaveManager")
	var cost := 120 if count == 1 else 1080
	
	# Spend tokens or gems
	var success := false
	if sm:
		if sm.gacha_tokens >= (1 if count == 1 else 10):
			sm.spend_gacha_tokens(1 if count == 1 else 10)
			success = true
		elif sm.total_gems >= cost:
			sm.spend_gems(cost)
			success = true
	else:
		success = true
	
	if not success:
		SoundFX.play_ui_click()
		return
	
	SoundFX.play_star_up()
	
	# Update Lucky Meter
	if sm and sm.has_method("add_lucky_spins"):
		sm.add_lucky_spins(count)
		if _lucky_bar:
			_lucky_bar.value = sm.lucky_meter
		if _lucky_label:
			_lucky_label.text = "%d / 100" % sm.lucky_meter
	
	# Roll rewards
	var rewards: Array[Dictionary] = []
	for i in range(count):
		var pick: Dictionary = DROP_POOL[randi() % DROP_POOL.size()]
		rewards.append(pick)
		if sm:
			if "TUK TUK" in pick["name"]:
				sm.unlock_car("tuk_tuk_jet")
			elif "DRAGON" in pick["name"]:
				sm.unlock_car("fire_dragon")
			elif "SHADOW" in pick["name"]:
				sm.unlock_car("shadow")
			elif "RACER" in pick["name"]:
				sm.unlock_car("racer_01")
			elif "TANKER" in pick["name"]:
				sm.unlock_car("tanker")
	
	# Show result cards in modal
	for c in _result_cards_h.get_children():
		_result_cards_h.remove_child(c)
		c.queue_free()
	
	for r in rewards:
		var tier_str: String = str(r.get("tier", "COMMON"))
		var tier_col: Color = BrawlUITheme.get_tier_color(tier_str)
		
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(210, 270)
		card.add_theme_stylebox_override("panel", BrawlUITheme.make_tier_card_style(tier_str, false, 18))
		
		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 6)
		card.add_child(cv)
		
		var stars_count: int = 5 if tier_str == "MYTHIC" else (4 if tier_str == "LEGENDARY" else (3 if tier_str == "EPIC" else (2 if tier_str == "RARE" else 1)))
		var star_lbl := Label.new()
		star_lbl.text = "★".repeat(stars_count)
		star_lbl.label_settings = BrawlUITheme.make_label_settings(16, Color("f1c40f"), 3, 1)
		star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(star_lbl)
		
		var tex: Texture2D = _get_drop_texture(r)
		if tex:
			var img := TextureRect.new()
			img.texture = tex
			img.custom_minimum_size = Vector2(160, 105)
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			cv.add_child(img)
		else:
			var icon := Label.new()
			icon.text = r.get("icon", "🎁")
			icon.label_settings = BrawlUITheme.make_label_settings(42, Color.WHITE, 0, 0)
			icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(icon)
		
		var name_lbl := Label.new()
		name_lbl.text = str(r.get("name", "REWARD"))
		name_lbl.label_settings = BrawlUITheme.make_label_settings(14, Color.WHITE, 4, 1)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(name_lbl)
		
		var tier_lbl := Label.new()
		tier_lbl.text = tier_str
		tier_lbl.label_settings = BrawlUITheme.make_label_settings(12, tier_col, 2, 1)
		tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(tier_lbl)
		
		_result_cards_h.add_child(card)
	
	_result_modal.visible = true
	
	# Reset visual elements for animated opening
	var c_closed: Texture2D = BrawlUITheme.load_texture_safe("res://assets/textures/ui/gacha_chest_closed.jpg")
	if c_closed:
		_chest_rect.texture = c_closed
	_chest_rect.pivot_offset = _chest_rect.custom_minimum_size * 0.5
	_chest_rect.scale = Vector2(0.2, 0.2)
	_chest_rect.rotation = 0.0
	_chest_rect.modulate.a = 1.0
	_chest_container.visible = true
	_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_reveal_content.visible = false
	_reveal_content.modulate.a = 0.0
	
	for tw in _active_anim_tweens:
		if tw and is_instance_valid(tw) and tw.is_valid():
			tw.kill()
	_active_anim_tweens.clear()
	
	var tw := create_tween()
	_active_anim_tweens.append(tw)
	
	# Phase 1: Chest Drop & Bouncy Impact (0.30s)
	tw.tween_property(_chest_rect, "scale", Vector2(1.15, 1.15), 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_chest_rect, "scale", Vector2(1.0, 1.0), 0.10)
	
	# Phase 2: Anticipation Rattle (0.24s)
	tw.tween_property(_chest_rect, "rotation", deg_to_rad(-5.0), 0.06)
	tw.tween_property(_chest_rect, "rotation", deg_to_rad(5.0), 0.06)
	tw.tween_property(_chest_rect, "rotation", deg_to_rad(-3.0), 0.06)
	tw.tween_property(_chest_rect, "rotation", 0.0, 0.06)
	
	# Phase 3: Flash Explosion Burst & Open Chest!
	tw.tween_callback(func():
		var c_open: Texture2D = BrawlUITheme.load_texture_safe("res://assets/textures/ui/gacha_chest_opened_flash.jpg")
		if c_open:
			_chest_rect.texture = c_open
		_flash_rect.color = Color(1.0, 0.96, 0.82, 0.95)
		SoundFX.play_star_up()
	)
	tw.parallel().tween_property(_chest_rect, "scale", Vector2(1.25, 1.25), 0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_flash_rect, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Phase 4: Fade chest to background and reveal reward cards
	tw.tween_property(_chest_rect, "modulate:a", 0.30, 0.25)
	tw.parallel().tween_property(_chest_rect, "scale", Vector2(0.8, 0.8), 0.25)
	tw.tween_callback(func():
		_reveal_content.visible = true
	)
	tw.tween_property(_reveal_content, "modulate:a", 1.0, 0.30)
	
	spin_completed.emit(rewards)

func _show_rates_info() -> void:
	SoundFX.play_ui_click()
	if _info_modal and is_instance_valid(_info_modal):
		_info_modal.visible = true
		return
	
	_info_modal = Control.new()
	_info_modal.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_info_modal)
	
	var dim := ColorRect.new()
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.80)
	_info_modal.add_child(dim)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	_info_modal.add_child(center)
	
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 420)
	card.add_theme_stylebox_override("panel", BrawlUITheme.make_neon_card_style(Color("081426"), Color("00d2d3"), 20, 3))
	center.add_child(card)
	
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	
	var t := Label.new()
	t.text = "📊 GACHA PROBABILITIES & RULES"
	t.label_settings = BrawlUITheme.make_label_settings(22, Color("00d2d3"), 6, 2)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	
	var desc := Label.new()
	desc.text = "• MYTHIC Tier: 1.0%\n• LEGENDARY Tier: 5.0%\n• EPIC Tier: 18.0%\n• RARE Tier: 35.0%\n• COMMON Tier: 41.0%\n\n🎯 LUCKY METER GUARANTEE:\nEvery spin adds +1 to your Lucky Meter. Upon reaching 100/100, your next spin is GUARANTEED to award a Featured LEGENDARY Vehicle!"
	desc.label_settings = BrawlUITheme.make_label_settings(14, Color.WHITE, 2, 1)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	
	var close_btn := Button.new()
	close_btn.text = "GOT IT"
	close_btn.custom_minimum_size = Vector2(220, 68)
	close_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_arcade_button_juice(close_btn, Color("00d2d3"))
	close_btn.pressed.connect(func():
		SoundFX.play_ui_click()
		_info_modal.visible = false
	)
	v.add_child(close_btn)

func _connect_save_manager() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		if sm.has_signal("gems_changed"):
			sm.gems_changed.connect(func(_g): _refresh_currencies())
		if sm.has_signal("gacha_tokens_changed"):
			sm.gacha_tokens_changed.connect(func(_t): _refresh_currencies())
		if sm.has_signal("lucky_meter_changed"):
			sm.lucky_meter_changed.connect(func(v):
				if _lucky_bar: _lucky_bar.value = v
				if _lucky_label: _lucky_label.text = "%d / 100" % v
			)

func _refresh_currencies() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		if _gem_label:
			_gem_label.text = "%d" % sm.total_gems
		if _token_label:
			_token_label.text = "%d" % sm.gacha_tokens
		if _lucky_bar:
			_lucky_bar.value = sm.lucky_meter
		if _lucky_label:
			_lucky_label.text = "%d / 100" % sm.lucky_meter
