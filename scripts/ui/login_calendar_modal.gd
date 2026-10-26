class_name LoginCalendarModal
extends Control

## Phase 12: 7-Day Login Calendar Modal (Brawl Stars Pop-Up Style)
## Displays 7 slanted cards, highlights today's claimable reward, and awards cash/gear/cars.

signal closed()
signal reward_claimed(day_index: int, reward: Dictionary)

const BrawlUITheme = preload("res://scripts/autoload/brawl_ui_theme.gd")
const SoundFX = preload("res://scripts/autoload/sound_fx.gd")

var _card_panels: Array[PanelContainer] = []
var _claim_button: Button = null
var _claim_tween: Tween = null
var _pulse_tween: Tween = null

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	refresh_calendar()

func _build_ui() -> void:
	# Dark backdrop
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.04, 0.08, 0.88)
	add_child(backdrop)
	
	# Centered Landscape Modal Window
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)
	
	var modal_box := PanelContainer.new()
	modal_box.custom_minimum_size = Vector2(1220, 620)
	modal_box.add_theme_stylebox_override("panel", BrawlUITheme.make_cartoon_board_style(Color("0c1626f4"), Color("f1c40f"), 28, 6))
	center.add_child(modal_box)
	
	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 10)
	modal_box.add_child(root_v)
	
	# Header Row (Title Ribbon Centered + Close Button on Right)
	var header_h := HBoxContainer.new()
	header_h.add_theme_constant_override("separation", 16)
	header_h.alignment = BoxContainer.ALIGNMENT_CENTER
	root_v.add_child(header_h)
	
	var left_spacer := Control.new()
	left_spacer.custom_minimum_size = Vector2(56, 56)
	header_h.add_child(left_spacer)
	
	var rib_rect := TextureRect.new()
	rib_rect.custom_minimum_size = Vector2(500, 105)
	rib_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rib_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rib_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var rib_path := "res://assets/ribbons/ribbon_header_rewards.png"
	rib_rect.texture = BrawlUITheme.load_texture_safe(rib_path)
	header_h.add_child(rib_rect)
	
	var close_btn := Button.new()
	BrawlUITheme.attach_bubble_close_button(close_btn)
	close_btn.pressed.connect(_on_close_pressed)
	header_h.add_child(close_btn)
	
	# Horizontal Row for all 7 Days in Landscape
	var cards_row := HBoxContainer.new()
	cards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_row.add_theme_constant_override("separation", 10)
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root_v.add_child(cards_row)
	
	_card_panels.clear()
	
	# Build 7 Day Cards
	for day_num in range(1, 8):
		var is_grand := (day_num == 7)
		var card := _create_day_card(day_num, is_grand)
		cards_row.add_child(card)
		_card_panels.append(card)
	
	# Bottom Claim Action Button Center Container
	var btn_center := CenterContainer.new()
	btn_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_v.add_child(btn_center)
	
	_claim_button = Button.new()
	_claim_button.custom_minimum_size = Vector2(460, 68)
	_claim_button.text = "CLAIM TODAY'S REWARD!"
	_claim_button.add_theme_font_size_override("font_size", 22)
	BrawlUITheme.attach_candy_button_juice(_claim_button, "green")
	_claim_button.pressed.connect(_on_claim_pressed)
	btn_center.add_child(_claim_button)

func _create_day_card(day_num: int, is_grand_prize: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "DayCard_%d" % day_num
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	if is_grand_prize:
		card.custom_minimum_size = Vector2(230, 360)
		card.add_theme_stylebox_override("panel", BrawlUITheme.make_cartoon_board_style(Color("261a06"), Color("f1c40f"), 18, 4))
	else:
		card.custom_minimum_size = Vector2(130, 360)
		card.add_theme_stylebox_override("panel", BrawlUITheme.make_cartoon_board_style(Color("121e2e"), Color("2980b9"), 14, 3))
	
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	cv.alignment = BoxContainer.ALIGNMENT_BEGIN
	card.add_child(cv)
	
	# Day Pill at Top
	var day_pill := PanelContainer.new()
	day_pill.name = "DayPill"
	var pill_color: Color = Color("f1c40f") if is_grand_prize else Color("0984e3")
	day_pill.add_theme_stylebox_override("panel", BrawlUITheme.make_pill_style(pill_color, Color("0d1117"), 0.02, 12))
	cv.add_child(day_pill)
	
	var day_lbl := Label.new()
	day_lbl.name = "DayLabel"
	day_lbl.text = "DAY %d" % day_num if not is_grand_prize else "DAY 7 ★ GRAND PRIZE"
	day_lbl.label_settings = BrawlUITheme.make_label_settings(14 if not is_grand_prize else 15, Color.WHITE, 4, 1)
	day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_pill.add_child(day_lbl)
	
	# Category Pill (CURRENCY, GEAR, CAR, etc.)
	var cat_lbl := Label.new()
	cat_lbl.name = "CategoryLabel"
	cat_lbl.text = "REWARD"
	cat_lbl.label_settings = BrawlUITheme.make_label_settings(11, Color("74b9ff"), 3, 1)
	cat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(cat_lbl)
	
	# Reward Artwork Showcase Container with Radial Glow & Tech Hex Pattern Backdrop
	var art_stage := Control.new()
	art_stage.name = "ArtStage"
	art_stage.custom_minimum_size = Vector2(180, 180) if not is_grand_prize else Vector2(270, 180)
	art_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.add_child(art_stage)
	
	# Glow Backdrop Texture
	var glow_rect := TextureRect.new()
	glow_rect.name = "GlowBackdrop"
	glow_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow_rect.stretch_mode = TextureRect.STRETCH_SCALE
	glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var glow_grad := Gradient.new()
	glow_grad.set_color(0, Color(0.0, 0.8, 1.0, 0.40))
	glow_grad.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	var glow_tex := GradientTexture2D.new()
	glow_tex.gradient = glow_grad
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(0.5, 0.0)
	glow_rect.texture = glow_tex
	art_stage.add_child(glow_rect)
	
	# Subtle Tech Hex Grid Detail Overlay
	var tech_rect := TextureRect.new()
	tech_rect.name = "TechGrid"
	tech_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tech_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tech_rect.stretch_mode = TextureRect.STRETCH_TILE
	tech_rect.texture = BrawlUITheme.get_hex_grid_texture()
	tech_rect.modulate = Color(1.0, 1.0, 1.0, 0.16)
	tech_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_stage.add_child(tech_rect)
	
	# Pedestal Grounding Disc
	var disc := PanelContainer.new()
	disc.name = "PedestalDisc"
	disc.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	disc.offset_top = -24.0
	disc.offset_left = 16.0
	disc.offset_right = -16.0
	disc.add_theme_stylebox_override("panel", BrawlUITheme.make_pill_style(Color("08111d"), Color("008da8"), 0.0, 10))
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_stage.add_child(disc)
	
	# Exact Reward Image TextureRect (No emojis!)
	var art_rect := TextureRect.new()
	art_rect.name = "RewardArt"
	art_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	art_rect.offset_left = 8.0
	art_rect.offset_right = -8.0
	art_rect.offset_top = 8.0
	art_rect.offset_bottom = -12.0
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_stage.add_child(art_rect)
	
	# Fallback IconLabel kept invisible for compatibility
	var icon_lbl := Label.new()
	icon_lbl.name = "IconLabel"
	icon_lbl.visible = false
	cv.add_child(icon_lbl)
	
	# Exact Reward Title (Bold 15pt / 18pt)
	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = "REWARD"
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.label_settings = BrawlUITheme.make_label_settings(15 if not is_grand_prize else 18, Color("fbc531") if is_grand_prize else Color.WHITE, 6, 2)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(title_lbl)
	
	# Subtitle / Benefit (12pt)
	var sub_lbl := Label.new()
	sub_lbl.name = "SubtitleLabel"
	sub_lbl.text = "BONUS"
	sub_lbl.label_settings = BrawlUITheme.make_label_settings(12, Color("74b9ff") if not is_grand_prize else Color("ffeaa7"), 3, 1)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(sub_lbl)
	
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(spacer)
	
	# Status Badge (CLAIMED / READY / LOCKED)
	var status_panel := PanelContainer.new()
	status_panel.name = "StatusPanel"
	status_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_pill_style(Color("1e272e"), Color("0d1117"), 0.02, 10))
	cv.add_child(status_panel)
	
	var status_lbl := Label.new()
	status_lbl.name = "StatusLabel"
	status_lbl.text = "LOCKED"
	status_lbl.label_settings = BrawlUITheme.make_label_settings(13, Color("718093"), 4, 1)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_panel.add_child(status_lbl)
	
	return card

func refresh_calendar() -> void:
	if not has_node("/root/ProgressionManager"):
		return
	
	var pm = get_node("/root/ProgressionManager")
	var current_day: int = pm.login_day_index
	var can_claim: bool = pm.can_claim_today_login()
	var claimed_days: Array[int] = pm.claimed_login_days
	
	for i in range(_card_panels.size()):
		var day_num: int = i + 1
		var card: PanelContainer = _card_panels[i]
		var reward_def: Dictionary = pm.get_reward_for_day(day_num)
		var is_grand: bool = (day_num == 7)
		var accent_col: Color = reward_def.get("accent_color", Color("00d2d3") if not is_grand else Color("f1c40f"))
		
		var art_rect: TextureRect = card.find_child("RewardArt", true, false) as TextureRect
		var glow_rect: TextureRect = card.find_child("GlowBackdrop", true, false) as TextureRect
		var icon_lbl: Label = card.find_child("IconLabel", true, false) as Label
		var title_lbl: Label = card.find_child("TitleLabel", true, false) as Label
		var sub_lbl: Label = card.find_child("SubtitleLabel", true, false) as Label
		var cat_lbl: Label = card.find_child("CategoryLabel", true, false) as Label
		var status_lbl: Label = card.find_child("StatusLabel", true, false) as Label
		var status_panel: PanelContainer = card.find_child("StatusPanel", true, false) as PanelContainer
		
		# Set Exact Reward Graphic (No emojis!)
		var tex_path: String = String(reward_def.get("texture_path", ""))
		if art_rect and not tex_path.is_empty():
			var tex: Texture2D = BrawlUITheme.load_texture_safe(tex_path)
			if not tex and ResourceLoader.exists(tex_path):
				tex = load(tex_path) as Texture2D
			art_rect.texture = tex
		
		# Radial glow tinted to reward accent
		if glow_rect and glow_rect.texture is GradientTexture2D:
			var gt: GradientTexture2D = glow_rect.texture as GradientTexture2D
			if gt.gradient:
				gt.gradient.set_color(0, accent_col * Color(1.0, 1.0, 1.0, 0.45))
		
		if icon_lbl:
			icon_lbl.text = String(reward_def.get("icon", "🎁"))
		if title_lbl:
			title_lbl.text = String(reward_def.get("title", ""))
		if sub_lbl:
			sub_lbl.text = String(reward_def.get("subtitle", reward_def.get("desc", "")))
		if cat_lbl:
			cat_lbl.text = String(reward_def.get("category", "REWARD"))
			cat_lbl.label_settings.font_color = accent_col
		
		# Check state
		if day_num in claimed_days:
			# Claimed state
			card.modulate = Color(0.65, 0.65, 0.65, 0.85)
			if status_lbl:
				status_lbl.text = "✅ CLAIMED"
				status_lbl.label_settings.font_color = Color("2ecc71")
			if status_panel:
				status_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_pill_style(Color("102618"), Color("2ecc71"), 0.02, 10))
			card.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("0a121a"), Color("162432"), 0.03, 16))
		elif day_num == current_day and can_claim:
			# Available today!
			card.modulate = Color.WHITE
			if status_lbl:
				status_lbl.text = "⚡ READY TO CLAIM!"
				status_lbl.label_settings.font_color = Color("fbc531")
			if status_panel:
				status_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_pill_style(Color("3d2a04"), Color("f1c40f"), 0.02, 10))
			card.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("1a2b3c") if not is_grand else Color("382506"), accent_col, 0.04, 18))
			_pulse_card(card)
		else:
			# Future or pending day
			card.modulate = Color(0.82, 0.82, 0.82, 0.7)
			if status_lbl:
				status_lbl.text = "🔒 DAY %d" % day_num
				status_lbl.label_settings.font_color = Color("718093")
			if status_panel:
				status_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_pill_style(Color("161f28"), Color("0d1117"), 0.02, 10))
			card.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("0f1826"), Color("1f2d3d"), 0.03, 16))
	
	# Update Action Button
	if _claim_button:
		var btn_lbl: Label = _claim_button.find_child("ButtonLabel", true, false) as Label
		if can_claim:
			_claim_button.disabled = false
			BrawlUITheme.attach_button_juice(_claim_button, Color("44bd32"))
			if btn_lbl:
				btn_lbl.text = "CLAIM DAY %d REWARD! 🎁" % current_day
			_start_button_pulse()
		else:
			_claim_button.disabled = true
			BrawlUITheme.attach_button_juice(_claim_button, Color("576574"))
			if btn_lbl:
				btn_lbl.text = "COME BACK TOMORROW! (DAY %d NEXT)" % current_day
			if _pulse_tween and _pulse_tween.is_valid():
				_pulse_tween.kill()

func _pulse_card(card: PanelContainer) -> void:
	var tw := card.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(card, "scale", Vector2(1.03, 1.03), 0.6)
	tw.tween_property(card, "scale", Vector2.ONE, 0.6)

func _start_button_pulse() -> void:
	if not _claim_button:
		return
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(_claim_button, "scale", Vector2(1.04, 1.04), 0.5)
	_pulse_tween.tween_property(_claim_button, "scale", Vector2.ONE, 0.5)

func _on_claim_pressed() -> void:
	if not has_node("/root/ProgressionManager"):
		return
	var pm = get_node("/root/ProgressionManager")
	if not pm.can_claim_today_login():
		return
	
	var day_claimed: int = pm.login_day_index
	var reward: Dictionary = pm.claim_today_login()
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_star_up()
	
	refresh_calendar()
	reward_claimed.emit(day_claimed, reward)
	
	# Quick close after 1.2s delay or let player admire
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(func():
		if is_instance_valid(self):
			refresh_calendar()
	)

func _on_close_pressed() -> void:
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_ui_click()
	visible = false
	closed.emit()

func open_modal() -> void:
	visible = true
	refresh_calendar()
