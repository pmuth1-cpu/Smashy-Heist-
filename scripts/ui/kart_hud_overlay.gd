class_name KartHUDOverlay
extends CanvasLayer

## Dedicated 16:9 Landscape HUD for Smashy Kart Grand Prix.
## Displays:
## - Bottom-Left: Giant Metallic Position Badge ("1st" to "6th") & Lap Counter ("LAP 1/3" / "FINAL LAP!")
## - Top-Left: 2D Minimap polyline with 6 live colored racer blips
## - Top-Center: Rainbow Item Roulette Box + Rear-View Incoming Missile/Drone Warning
## - Bottom-Right: "⚡ USE ITEM" Touch Button (also Space / E) with "x3" charges badge
## - Center: 3-2-1-SMASH! Giant Countdown & Rocket Start Rev Gauge
## - Wrong-Way Alert Banner ("⚠️ WRONG WAY!")

const BrawlUITheme = preload("res://scripts/autoload/brawl_ui_theme.gd")
const AssetChromaLoader = preload("res://scripts/autoload/asset_chroma_loader.gd")

signal item_button_pressed()

var track_curve: Curve3D = null
var racers: Array[ArcadeCar] = []
var local_player_car: ArcadeCar = null

# Position & Lap Nodes
var position_panel: PanelContainer = null
var position_label: Label = null
var lap_label: Label = null
var _last_rank: int = -1

# Minimap
var minimap_control: Control = null
var _track_points_2d: PackedVector2Array = PackedVector2Array()
var _track_bounds_min: Vector2 = Vector2.ZERO
var _track_bounds_max: Vector2 = Vector2.ONE

# Top-Center Item Roulette & Warning
var roulette_container: Control = null
var roulette_frame_rect: TextureRect = null
var item_icon_rect: TextureRect = null
var item_count_badge: Label = null
var incoming_warning_label: Label = null
var _warning_timer: float = 0.0

# Skill Detail Panel
var skill_detail_panel: PanelContainer = null
var skill_title_label: Label = null
var skill_desc_label: Label = null
var skill_action_label: Label = null

# Bottom-Right Use Item Button
var use_item_button: Button = null
var use_item_button_label: Label = null

const ITEM_DETAILS: Dictionary = {
	1: {
		"name": "GREEN TIRE",
		"icon": "🐢",
		"action": "FIRE BOUNCING TIRE",
		"desc": "Ricochets off track walls & flips rival racers on hit!",
		"color": Color("2ecc71")
	},
	2: {
		"name": "HOMING RED MISSILE",
		"icon": "🚀",
		"action": "LAUNCH HOMING MISSILE",
		"desc": "Locks onto the racer ahead & triggers a flip blast!",
		"color": Color("ff4757")
	},
	3: {
		"name": "TRIPLE NITRO BOOST",
		"icon": "🔥",
		"action": "TRIGGER NITRO BOOST",
		"desc": "3x Supercharged Turbo Rocket Blasts (1.45x speed)!",
		"color": Color("ff9f43")
	},
	4: {
		"name": "SLICK MOTOR OIL",
		"icon": "🍌",
		"action": "DROP OIL HAZARD",
		"desc": "Drops slippery puddle behind causing 360° spin-outs!",
		"color": Color("f1c40f")
	},
	5: {
		"name": "SUPERCHARGED EMP",
		"icon": "⚡",
		"action": "DISCHARGE EMP ZAP",
		"desc": "Supercharged crackle shrinks & slows all opponents!",
		"color": Color("00d2d3")
	},
	6: {
		"name": "INVINCIBLE GOLD STAR",
		"icon": "⭐",
		"action": "ACTIVATE INVINCIBILITY",
		"desc": "Invincible aura, +40% top speed & smashes all cars!",
		"color": Color("f1c40f")
	},
	7: {
		"name": "FAKE ITEM BOX",
		"icon": "💣",
		"action": "DROP TNT DECOY",
		"desc": "Deceptive explosive box that detonates when touched!",
		"color": Color("e74c3c")
	},
	8: {
		"name": "BLUE SPIKE DRONE",
		"icon": "👑",
		"action": "LAUNCH 1st-PLACE STRIKE",
		"desc": "Flies to 1st place leader with a massive blast radius!",
		"color": Color("54a0ff")
	}
}

# Center Countdown & Rocket Start Rev
var countdown_label: Label = null
var rev_meter_container: VBoxContainer = null
var rev_meter_bar: ProgressBar = null
var rev_feedback_label: Label = null
var wrong_way_banner: Label = null

# Cyan Flash
var emp_flash_rect: ColorRect = null

var racer_colors: Array[Color] = [
	Color("f1c40f"), # Player 1 (Gold)
	Color("3498db"), # Rival 1 (Blue)
	Color("e74c3c"), # Rival 2 (Red)
	Color("9b59b6"), # Rival 3 (Purple)
	Color("2ecc71"), # Rival 4 (Green)
	Color("e67e22")  # Rival 5 (Orange)
]

func _ready() -> void:
	layer = 15
	_build_hud_elements()

func _build_hud_elements() -> void:
	# 1. Minimap (Top-Left, 240x180)
	var map_container := PanelContainer.new()
	map_container.name = "MinimapContainer"
	map_container.position = Vector2(35, 30)
	map_container.custom_minimum_size = Vector2(250, 190)
	map_container.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color(0.08, 0.1, 0.14, 0.85), Color("00d2d3"), 0.04, 16))
	add_child(map_container)
	
	minimap_control = Control.new()
	minimap_control.custom_minimum_size = Vector2(230, 170)
	minimap_control.draw.connect(_on_minimap_draw)
	map_container.add_child(minimap_control)
	
	# 2. Position & Lap Counter (Bottom-Left)
	position_panel = PanelContainer.new()
	position_panel.name = "PositionPanel"
	position_panel.position = Vector2(35, 870)
	position_panel.custom_minimum_size = Vector2(280, 150)
	position_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("1e272e"), Color("f1c40f"), 0.04, 20))
	add_child(position_panel)
	
	var pos_vbox := VBoxContainer.new()
	pos_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	position_panel.add_child(pos_vbox)
	
	position_label = Label.new()
	position_label.text = "1st"
	position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	position_label.label_settings = BrawlUITheme.make_label_settings(64, Color("f1c40f"), 10, 4)
	pos_vbox.add_child(position_label)
	
	lap_label = Label.new()
	lap_label.text = "LAP 1/3"
	lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lap_label.label_settings = BrawlUITheme.make_label_settings(24, Color.WHITE, 6, 2)
	pos_vbox.add_child(lap_label)
	
	# 3. Top-Center Item Roulette Box & Incoming Warning
	roulette_container = Control.new()
	roulette_container.name = "RouletteContainer"
	roulette_container.position = Vector2(960 - 70, 30)
	roulette_container.custom_minimum_size = Vector2(140, 140)
	add_child(roulette_container)
	
	roulette_frame_rect = TextureRect.new()
	roulette_frame_rect.custom_minimum_size = Vector2(140, 140)
	roulette_frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	roulette_frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var acl = get_node_or_null("/root/AssetChromaLoader")
	if acl:
		roulette_frame_rect.texture = acl.load_texture("res://assets/kart/kart_hud_roulette_frame.png")
	roulette_container.add_child(roulette_frame_rect)
	
	item_icon_rect = TextureRect.new()
	item_icon_rect.position = Vector2(25, 25)
	item_icon_rect.custom_minimum_size = Vector2(90, 90)
	item_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	roulette_container.add_child(item_icon_rect)
	
	item_count_badge = Label.new()
	item_count_badge.position = Vector2(85, 85)
	item_count_badge.text = ""
	item_count_badge.label_settings = BrawlUITheme.make_label_settings(24, Color("f1c40f"), 6, 2)
	roulette_container.add_child(item_count_badge)
	
	incoming_warning_label = Label.new()
	incoming_warning_label.name = "IncomingWarningLabel"
	incoming_warning_label.position = Vector2(960 - 250, 160)
	incoming_warning_label.custom_minimum_size = Vector2(500, 36)
	incoming_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	incoming_warning_label.label_settings = BrawlUITheme.make_label_settings(24, Color("ff4757"), 8, 3)
	incoming_warning_label.visible = false
	add_child(incoming_warning_label)
	
	# Top-Center Skill Detail Panel (Brawl Stars Style)
	skill_detail_panel = PanelContainer.new()
	skill_detail_panel.name = "SkillDetailPanel"
	skill_detail_panel.position = Vector2(960 - 240, 185)
	skill_detail_panel.custom_minimum_size = Vector2(480, 85)
	skill_detail_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color(0.08, 0.12, 0.18, 0.90), Color("00d2d3"), 0.04, 16))
	add_child(skill_detail_panel)
	
	var skill_vbox := VBoxContainer.new()
	skill_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_vbox.add_theme_constant_override("separation", 2)
	skill_detail_panel.add_child(skill_vbox)
	
	skill_title_label = Label.new()
	skill_title_label.text = "📦 KART GAMEMODE SKILL"
	skill_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_title_label.label_settings = BrawlUITheme.make_label_settings(20, Color("f1c40f"), 6, 2)
	skill_vbox.add_child(skill_title_label)
	
	skill_desc_label = Label.new()
	skill_desc_label.text = "Hit Rainbow Item Boxes to roll battle powers!"
	skill_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_desc_label.label_settings = BrawlUITheme.make_label_settings(15, Color("dcdde1"), 4, 1)
	skill_vbox.add_child(skill_desc_label)
	
	skill_action_label = Label.new()
	skill_action_label.text = "PRESS [SPACE / E] OR TAP BUTTON TO USE"
	skill_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_action_label.label_settings = BrawlUITheme.make_label_settings(13, Color("00d2d3"), 4, 1)
	skill_vbox.add_child(skill_action_label)
	
	# 4. Bottom-Right "⚡ USE ITEM" Button
	use_item_button = Button.new()
	use_item_button.name = "UseItemButton"
	use_item_button.position = Vector2(1620, 850)
	use_item_button.custom_minimum_size = Vector2(260, 140)
	BrawlUITheme.attach_button_juice(use_item_button, Color("ff3f34"))
	
	use_item_button_label = Label.new()
	use_item_button_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	use_item_button_label.text = "⚡ GAMEMODE SKILL\n[ROLL FROM BOX]"
	use_item_button_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	use_item_button_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	use_item_button_label.label_settings = BrawlUITheme.make_label_settings(20, Color.WHITE, 6, 2)
	use_item_button_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	use_item_button.add_child(use_item_button_label)
	
	use_item_button.pressed.connect(func():
		item_button_pressed.emit()
	)
	add_child(use_item_button)
	
	# 5. Center Countdown & Rev Meter
	countdown_label = Label.new()
	countdown_label.name = "CountdownLabel"
	countdown_label.position = Vector2(960 - 300, 360)
	countdown_label.custom_minimum_size = Vector2(600, 160)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.label_settings = BrawlUITheme.make_label_settings(96, Color("f1c40f"), 14, 6)
	countdown_label.visible = false
	add_child(countdown_label)
	
	rev_meter_container = VBoxContainer.new()
	rev_meter_container.position = Vector2(960 - 180, 540)
	rev_meter_container.custom_minimum_size = Vector2(360, 90)
	rev_meter_container.visible = false
	add_child(rev_meter_container)
	
	var rev_title := Label.new()
	rev_title.text = "HOLD GAS TO REV ENGINE!"
	rev_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rev_title.label_settings = BrawlUITheme.make_label_settings(20, Color.WHITE, 6, 2)
	rev_meter_container.add_child(rev_title)
	
	rev_meter_bar = ProgressBar.new()
	rev_meter_bar.custom_minimum_size = Vector2(360, 24)
	rev_meter_bar.max_value = 100.0
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("2ecc71")
	bar_fill.set_corner_radius_all(8)
	rev_meter_bar.add_theme_stylebox_override("fill", bar_fill)
	rev_meter_container.add_child(rev_meter_bar)
	
	rev_feedback_label = Label.new()
	rev_feedback_label.position = Vector2(960 - 250, 480)
	rev_feedback_label.custom_minimum_size = Vector2(500, 60)
	rev_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rev_feedback_label.label_settings = BrawlUITheme.make_label_settings(36, Color("f1c40f"), 10, 4)
	rev_feedback_label.visible = false
	add_child(rev_feedback_label)
	
	wrong_way_banner = Label.new()
	wrong_way_banner.name = "WrongWayBanner"
	wrong_way_banner.position = Vector2(960 - 250, 240)
	wrong_way_banner.custom_minimum_size = Vector2(500, 60)
	wrong_way_banner.text = "⚠️ WRONG WAY!"
	wrong_way_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrong_way_banner.label_settings = BrawlUITheme.make_label_settings(36, Color("ff3f34"), 10, 4)
	wrong_way_banner.visible = false
	add_child(wrong_way_banner)
	
	# EMP Screen Flash Overlay
	emp_flash_rect = ColorRect.new()
	emp_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	emp_flash_rect.color = Color(0, 0.82, 0.83, 0.0)
	emp_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(emp_flash_rect)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_SPACE or event.keycode == KEY_E:
			item_button_pressed.emit()

func setup_track(curve: Curve3D, all_racers: Array[ArcadeCar], local_car: ArcadeCar) -> void:
	track_curve = curve
	racers = all_racers
	local_player_car = local_car
	
	_compute_minimap_polyline()

func _compute_minimap_polyline() -> void:
	if not track_curve:
		return
	
	_track_points_2d.clear()
	var b_len := track_curve.get_baked_length()
	var step := 8.0
	var steps := int(ceil(b_len / step))
	
	var min_x := 99999.0
	var max_x := -99999.0
	var min_z := 99999.0
	var max_z := -99999.0
	
	for i in range(steps + 1):
		var d := fposmod(float(i) * step, b_len)
		var p3 := track_curve.sample_baked(d)
		var p2 := Vector2(p3.x, p3.z)
		_track_points_2d.append(p2)
		min_x = minf(min_x, p2.x)
		max_x = maxf(max_x, p2.x)
		min_z = minf(min_z, p2.y)
		max_z = maxf(max_z, p2.y)
	
	_track_bounds_min = Vector2(min_x - 15.0, min_z - 15.0)
	_track_bounds_max = Vector2(max_x + 15.0, max_z + 15.0)

func _process(delta: float) -> void:
	if minimap_control:
		minimap_control.queue_redraw()
	
	if _warning_timer > 0.0:
		_warning_timer -= delta
		if _warning_timer <= 0.0 and incoming_warning_label:
			incoming_warning_label.visible = false

func update_hud(current_rank: int, completed_lap: int, total_laps: int = 3) -> void:
	# Update Position Badge
	if current_rank != _last_rank:
		_last_rank = current_rank
		var ordinals := ["", "1st", "2nd", "3rd", "4th", "5th", "6th"]
		var r_str: String = ordinals[clampi(current_rank, 1, 6)]
		position_label.text = r_str
		
		# Rank Colors: 1st Gold, 2nd Silver, 3rd Bronze
		var col := Color("f1c40f")
		if current_rank == 2:
			col = Color("dfe4ea")
		elif current_rank == 3:
			col = Color("cd7f32")
		elif current_rank >= 4:
			col = Color("74b9ff")
		position_label.label_settings.font_color = col
		
		# Pop animation
		var tw := position_panel.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(position_panel, "scale", Vector2(1.2, 1.2), 0.1)
		tw.chain().tween_property(position_panel, "scale", Vector2.ONE, 0.15)
	
	# Update Lap Counter
	var cur_lap: int = mini(completed_lap + 1, total_laps)
	if cur_lap >= total_laps:
		lap_label.text = "LAP %d/%d — FINAL LAP!" % [cur_lap, total_laps]
		lap_label.label_settings.font_color = Color("f1c40f")
	else:
		lap_label.text = "LAP %d/%d" % [cur_lap, total_laps]
		lap_label.label_settings.font_color = Color.WHITE

func set_held_item(item_id: int, charges: int = 1) -> void:
	if item_id == 0:
		item_icon_rect.texture = null
		item_count_badge.text = ""
		if skill_title_label:
			skill_title_label.text = "📦 KART GAMEMODE SKILL"
			skill_title_label.label_settings.font_color = Color("f1c40f")
		if skill_desc_label:
			skill_desc_label.text = "Hit Rainbow Item Boxes to roll battle powers!"
		if skill_action_label:
			skill_action_label.text = "PRESS [SPACE / E] OR TAP BUTTON TO USE"
		if use_item_button_label:
			use_item_button_label.text = "⚡ GAMEMODE SKILL\n[ROLL FROM BOX]"
		return
	
	var path: String = KartItemSystem.ITEM_ICONS.get(item_id, "")
	var acl = get_node_or_null("/root/AssetChromaLoader")
	if acl and not path.is_empty():
		item_icon_rect.texture = acl.load_texture(path)
	elif ResourceLoader.exists(path):
		item_icon_rect.texture = load(path)
	
	item_count_badge.text = "x%d" % charges if charges > 1 else ""
	
	# Update Skill Details
	var info: Dictionary = ITEM_DETAILS.get(item_id, {})
	if not info.is_empty():
		var skill_name: String = str(info.get("name", "ITEM"))
		var skill_icon: String = str(info.get("icon", "⚡"))
		var skill_action: String = str(info.get("action", "USE ITEM"))
		var skill_desc: String = str(info.get("desc", ""))
		var skill_col: Color = info.get("color", Color("f1c40f"))
		
		if skill_title_label:
			var charge_str := (" (x%d)" % charges) if charges > 1 else ""
			skill_title_label.text = "%s %s%s" % [skill_icon, skill_name, charge_str]
			skill_title_label.label_settings.font_color = skill_col
		if skill_desc_label:
			skill_desc_label.text = skill_desc
		if skill_action_label:
			skill_action_label.text = "⚡ [SPACE / E] TO %s" % skill_action
		
		if use_item_button_label:
			var charge_suffix := (" (x%d)" % charges) if charges > 1 else ""
			use_item_button_label.text = "%s %s%s\n[SPACE / E]" % [skill_icon, skill_action, charge_suffix]
		
		# Pop animation on detail panel
		if skill_detail_panel:
			var tw := skill_detail_panel.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(skill_detail_panel, "scale", Vector2(1.08, 1.08), 0.1)
			tw.chain().tween_property(skill_detail_panel, "scale", Vector2.ONE, 0.15)

func set_warning(warning_text: String, duration: float = 2.0) -> void:
	if incoming_warning_label:
		incoming_warning_label.text = "⚠️ %s" % warning_text
		incoming_warning_label.visible = true
		_warning_timer = duration

func show_wrong_way(active: bool) -> void:
	if wrong_way_banner:
		wrong_way_banner.visible = active

func flash_emp_screen() -> void:
	if emp_flash_rect:
		var tw := emp_flash_rect.create_tween()
		emp_flash_rect.color = Color(0, 0.82, 0.83, 0.55)
		tw.tween_property(emp_flash_rect, "color:a", 0.0, 0.6)

func set_countdown_step(text: String, col: Color) -> void:
	countdown_label.text = text
	countdown_label.label_settings.font_color = col
	countdown_label.visible = true
	
	var tw := countdown_label.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	countdown_label.scale = Vector2(1.4, 1.4)
	tw.tween_property(countdown_label, "scale", Vector2.ONE, 0.25)

func hide_countdown() -> void:
	countdown_label.visible = false

func set_rev_gauge(val: float, is_visible: bool = true) -> void:
	rev_meter_container.visible = is_visible
	rev_meter_bar.value = val

func show_rev_result(text: String, col: Color) -> void:
	rev_meter_container.visible = false
	rev_feedback_label.text = text
	rev_feedback_label.label_settings.font_color = col
	rev_feedback_label.visible = true
	var tw := rev_feedback_label.create_tween()
	tw.tween_property(rev_feedback_label, "modulate:a", 0.0, 1.4)
	tw.tween_callback(func(): rev_feedback_label.visible = false; rev_feedback_label.modulate.a = 1.0)

func _on_minimap_draw() -> void:
	if _track_points_2d.size() < 2 or not minimap_control:
		return
	
	var map_size := minimap_control.size
	var range_x := _track_bounds_max.x - _track_bounds_min.x
	var range_y := _track_bounds_max.y - _track_bounds_min.y
	if range_x <= 0.0 or range_y <= 0.0:
		return
	
	# Draw Track Neon Polyline
	var mapped_pts: PackedVector2Array = PackedVector2Array()
	for pt in _track_points_2d:
		var nx := (pt.x - _track_bounds_min.x) / range_x
		var ny := (pt.y - _track_bounds_min.y) / range_y
		mapped_pts.append(Vector2(nx * map_size.x, ny * map_size.y))
	
	if mapped_pts.size() > 1:
		minimap_control.draw_polyline(mapped_pts, Color("00d2d3"), 3.5, true)
	
	# Draw Racer Dots
	for i in range(racers.size()):
		var r := racers[i]
		if not is_instance_valid(r):
			continue
		var r_pos: Vector3 = r.car_pivot.global_position if r.car_pivot else (r.physics_sphere.global_position if r.physics_sphere else r.global_position)
		var nx := (r_pos.x - _track_bounds_min.x) / range_x
		var ny := (r_pos.z - _track_bounds_min.y) / range_y
		var dot_pos := Vector2(nx * map_size.x, ny * map_size.y)
		
		var col: Color = racer_colors[i % racer_colors.size()]
		var radius: float = 5.5 if r == local_player_car else 4.0
		if r == local_player_car:
			# Outer highlight ring for player
			minimap_control.draw_circle(dot_pos, radius + 2.5, Color.WHITE)
		minimap_control.draw_circle(dot_pos, radius, col)
