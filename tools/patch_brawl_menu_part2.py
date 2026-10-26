import os

MENU_PATH = r"D:\My project\smashy heist\scripts\ui\brawl_main_menu.gd"

with open(MENU_PATH, "r", encoding="utf-8") as f:
    text = f.read()

# ==============================================================================
# BLOCK 1: _build_layer_2_top_bar to _build_tab_drawers
# ==============================================================================
s1 = text.find("func _build_layer_2_top_bar() -> void:")
e1 = text.find("func _build_tab_drawers() -> void:")
assert s1 != -1 and e1 != -1, "Block 1 markers not found"

block1_code = '''func _build_layer_2_top_bar() -> void:
	var top_bar := Control.new()
	top_bar.name = "Layer2_TopBar"
	top_bar.set_anchors_preset(PRESET_TOP_WIDE)
	top_bar.offset_left = 24.0
	top_bar.offset_top = 16.0
	top_bar.offset_right = -24.0
	top_bar.offset_bottom = 80.0
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)
	
	var acl = get_node_or_null("/root/AssetChromaLoader")
	
	# --- LEFT: Profile & Trophy Capsule ---
	var profile_panel := PanelContainer.new()
	profile_panel.name = "ProfileCapsule"
	profile_panel.custom_minimum_size = Vector2(360, 58)
	profile_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_capsule_style(Color("06111f"), Color("0084a8"), 24))
	top_bar.add_child(profile_panel)
	
	var prof_h := HBoxContainer.new()
	prof_h.alignment = BoxContainer.ALIGNMENT_BEGIN
	prof_h.add_theme_constant_override("separation", 12)
	profile_panel.add_child(prof_h)
	
	# Avatar circle
	var av_rect := TextureRect.new()
	if acl:
		av_rect.texture = acl.load_texture("res://assets/ui/icon_avatar_pilot.png")
	elif ResourceLoader.exists("res://assets/ui/icon_avatar_pilot.png"):
		av_rect.texture = load("res://assets/ui/icon_avatar_pilot.png")
	av_rect.custom_minimum_size = Vector2(46, 46)
	av_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	av_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prof_h.add_child(av_rect)
	
	# Score & Level VBox
	var stat_v := VBoxContainer.new()
	stat_v.alignment = BoxContainer.ALIGNMENT_CENTER
	stat_v.add_theme_constant_override("separation", 2)
	prof_h.add_child(stat_v)
	
	var tr_row := HBoxContainer.new()
	tr_row.add_theme_constant_override("separation", 6)
	stat_v.add_child(tr_row)
	
	var tr_icon := TextureRect.new()
	if acl:
		tr_icon.texture = acl.load_texture("res://assets/ui/icon_trophy_cup.png")
	tr_icon.custom_minimum_size = Vector2(24, 24)
	tr_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr_row.add_child(tr_icon)
	
	_trophy_label = Label.new()
	_trophy_label.text = "210337"
	_trophy_label.label_settings = BrawlUITheme.make_label_settings(22, Color("fbc531"), 6, 2)
	tr_row.add_child(_trophy_label)
	
	var lv_row := HBoxContainer.new()
	lv_row.add_theme_constant_override("separation", 8)
	stat_v.add_child(lv_row)
	
	_level_label = Label.new()
	_level_label.text = "Lv. 12"
	_level_label.label_settings = BrawlUITheme.make_label_settings(14, Color.WHITE, 4, 1)
	lv_row.add_child(_level_label)
	
	_level_progress_bar = ProgressBar.new()
	_level_progress_bar.custom_minimum_size = Vector2(160, 8)
	_level_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_level_progress_bar.max_value = 1.0
	_level_progress_bar.value = 0.65
	_level_progress_bar.show_percentage = false
	var lv_bg := StyleBoxFlat.new()
	lv_bg.bg_color = Color("081728")
	lv_bg.set_corner_radius_all(4)
	var lv_fill := StyleBoxFlat.new()
	lv_fill.bg_color = Color("fbc531")
	lv_fill.set_corner_radius_all(4)
	_level_progress_bar.add_theme_stylebox_override("background", lv_bg)
	_level_progress_bar.add_theme_stylebox_override("fill", lv_fill)
	lv_row.add_child(_level_progress_bar)
	
	# --- CENTER: Daily Streak Banner ---
	var streak_center := CenterContainer.new()
	streak_center.set_anchors_preset(PRESET_TOP_WIDE)
	streak_center.offset_top = 0.0
	streak_center.offset_bottom = 60.0
	streak_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(streak_center)
	
	var streak_btn := Button.new()
	streak_btn.custom_minimum_size = Vector2(290, 48)
	streak_btn.focus_mode = Control.FOCUS_NONE
	var streak_sb := BrawlUITheme.make_pill_style(Color("c0392b"), Color("e84118"), 0.08, 16)
	streak_btn.add_theme_stylebox_override("normal", streak_sb)
	streak_btn.add_theme_stylebox_override("hover", streak_sb)
	streak_btn.add_theme_stylebox_override("pressed", streak_sb)
	streak_btn.pressed.connect(_open_login_calendar)
	streak_center.add_child(streak_btn)
	
	var streak_h := HBoxContainer.new()
	streak_h.set_anchors_preset(PRESET_FULL_RECT)
	streak_h.alignment = BoxContainer.ALIGNMENT_CENTER
	streak_h.add_theme_constant_override("separation", 10)
	streak_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	streak_btn.add_child(streak_h)
	
	var st_icon := TextureRect.new()
	if acl:
		st_icon.texture = acl.load_texture("res://assets/ui/icon_streak_flame.png")
	st_icon.custom_minimum_size = Vector2(28, 28)
	st_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	st_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	st_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	streak_h.add_child(st_icon)
	
	_streak_label = Label.new()
	_streak_label.text = "3 DAY STREAK"
	_streak_label.label_settings = BrawlUITheme.make_label_settings(20, Color.WHITE, 6, 2)
	_streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	streak_h.add_child(_streak_label)
	
	# --- RIGHT: Currency & Shop ---
	var right_h := HBoxContainer.new()
	right_h.anchor_left = 1.0
	right_h.anchor_right = 1.0
	right_h.offset_left = -440.0
	right_h.offset_right = 0.0
	right_h.offset_top = 0.0
	right_h.offset_bottom = 58.0
	right_h.alignment = BoxContainer.ALIGNMENT_END
	right_h.add_theme_constant_override("separation", 16)
	top_bar.add_child(right_h)
	
	# Gem Counter Capsule
	var gem_panel := PanelContainer.new()
	gem_panel.custom_minimum_size = Vector2(200, 52)
	gem_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_capsule_style(Color("06111f"), Color("0084a8"), 22))
	right_h.add_child(gem_panel)
	
	var gem_h := HBoxContainer.new()
	gem_h.alignment = BoxContainer.ALIGNMENT_CENTER
	gem_h.add_theme_constant_override("separation", 10)
	gem_panel.add_child(gem_h)
	
	var g_icon := TextureRect.new()
	if acl:
		g_icon.texture = acl.load_texture("res://assets/ui/icon_gem_green.png")
	elif ResourceLoader.exists("res://assets/ui/icon_gem_green.png"):
		g_icon.texture = load("res://assets/ui/icon_gem_green.png")
	g_icon.custom_minimum_size = Vector2(26, 26)
	g_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_h.add_child(g_icon)
	
	_cash_label = Label.new()
	_cash_label.text = "59,752"
	_cash_label.label_settings = BrawlUITheme.make_label_settings(22, Color.WHITE, 6, 2)
	gem_h.add_child(_cash_label)
	
	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(32, 32)
	BrawlUITheme.attach_button_juice(plus_btn, Color("2ecc71"))
	plus_btn.pressed.connect(_on_plus_cash_pressed)
	gem_h.add_child(plus_btn)
	
	# Golden Orange Shop Button
	_shop_btn = Button.new()
	_shop_btn.custom_minimum_size = Vector2(145, 52)
	_shop_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_button_juice(_shop_btn, Color("f39c12"))
	_shop_btn.pressed.connect(func(): switch_tab(3))
	right_h.add_child(_shop_btn)
	
	var shop_h := HBoxContainer.new()
	shop_h.set_anchors_preset(PRESET_FULL_RECT)
	shop_h.alignment = BoxContainer.ALIGNMENT_CENTER
	shop_h.add_theme_constant_override("separation", 8)
	shop_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_btn.add_child(shop_h)
	
	var shop_lbl := Label.new()
	shop_lbl.text = "🛒 SHOP"
	shop_lbl.label_settings = BrawlUITheme.make_label_settings(20, Color("1e272e"), 0, 0)
	shop_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_h.add_child(shop_lbl)
	
	# Build Side Cards
	_build_side_cards()

func _build_side_cards() -> void:
	_side_cards_container = Control.new()
	_side_cards_container.name = "SideCardsContainer"
	_side_cards_container.set_anchors_preset(PRESET_FULL_RECT)
	_side_cards_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_side_cards_container)
	
	var acl = get_node_or_null("/root/AssetChromaLoader")
	
	# =========================================================================
	# LEFT SIDE CARDS (DAILY QUESTS & EVENT)
	# =========================================================================
	var left_vbox := VBoxContainer.new()
	left_vbox.offset_left = 24.0
	left_vbox.offset_top = 92.0
	left_vbox.offset_right = 336.0
	left_vbox.offset_bottom = 260.0
	left_vbox.add_theme_constant_override("separation", 12)
	left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side_cards_container.add_child(left_vbox)
	
	# Card 1: DAILY QUESTS
	_quests_card_btn = Button.new()
	_quests_card_btn.custom_minimum_size = Vector2(312, 74)
	_quests_card_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_arcade_button_juice(_quests_card_btn, Color("00d2d3"))
	_quests_card_btn.pressed.connect(_open_daily_quests)
	left_vbox.add_child(_quests_card_btn)
	
	var q_hbox := HBoxContainer.new()
	q_hbox.set_anchors_preset(PRESET_FULL_RECT)
	q_hbox.offset_left = 12.0
	q_hbox.offset_right = -12.0
	q_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	q_hbox.add_theme_constant_override("separation", 12)
	q_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quests_card_btn.add_child(q_hbox)
	
	# Gold gift box icon badge
	var q_icon_box := PanelContainer.new()
	q_icon_box.custom_minimum_size = Vector2(44, 44)
	q_icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var q_ib_sb := StyleBoxFlat.new()
	q_ib_sb.bg_color = Color("f39c12")
	q_ib_sb.set_corner_radius_all(10)
	q_icon_box.add_theme_stylebox_override("panel", q_ib_sb)
	q_icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q_hbox.add_child(q_icon_box)
	
	var q_ico_lbl := Label.new()
	q_ico_lbl.text = "🎁"
	q_ico_lbl.set_anchors_preset(PRESET_FULL_RECT)
	q_ico_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_ico_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q_ico_lbl.label_settings = BrawlUITheme.make_label_settings(24, Color.WHITE, 0, 0)
	q_icon_box.add_child(q_ico_lbl)
	
	var q_mid_vbox := VBoxContainer.new()
	q_mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_mid_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	q_mid_vbox.add_theme_constant_override("separation", 2)
	q_mid_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q_hbox.add_child(q_mid_vbox)
	
	var q_title := Label.new()
	q_title.text = "DAILY QUESTS"
	q_title.label_settings = BrawlUITheme.make_label_settings(15, Color.WHITE, 4, 1)
	q_mid_vbox.add_child(q_title)
	
	var q_sub := Label.new()
	q_sub.text = "Complete 3 matches"
	q_sub.label_settings = BrawlUITheme.make_label_settings(13, Color("74b9ff"), 2, 1)
	q_mid_vbox.add_child(q_sub)
	
	var q_prog_h := HBoxContainer.new()
	q_prog_h.add_theme_constant_override("separation", 8)
	q_mid_vbox.add_child(q_prog_h)
	
	_quests_progress_bar = ProgressBar.new()
	_quests_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quests_progress_bar.custom_minimum_size = Vector2(0, 6)
	_quests_progress_bar.max_value = 3.0
	_quests_progress_bar.value = 1.0
	_quests_progress_bar.show_percentage = false
	var qp_fill := StyleBoxFlat.new()
	qp_fill.bg_color = Color("f39c12")
	qp_fill.set_corner_radius_all(3)
	var qp_bg := StyleBoxFlat.new()
	qp_bg.bg_color = Color("081728")
	qp_bg.set_corner_radius_all(3)
	_quests_progress_bar.add_theme_stylebox_override("fill", qp_fill)
	_quests_progress_bar.add_theme_stylebox_override("background", qp_bg)
	q_prog_h.add_child(_quests_progress_bar)
	
	_quests_progress_label = Label.new()
	_quests_progress_label.text = "1/3"
	_quests_progress_label.label_settings = BrawlUITheme.make_label_settings(12, Color("00d2d3"), 2, 1)
	q_prog_h.add_child(_quests_progress_label)
	
	var q_chev := Label.new()
	q_chev.text = ">"
	q_chev.label_settings = BrawlUITheme.make_label_settings(22, Color("00d2d3"), 4, 1)
	q_hbox.add_child(q_chev)
	
	# Card 2: EVENT
	_event_card_btn = Button.new()
	_event_card_btn.custom_minimum_size = Vector2(312, 74)
	_event_card_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_arcade_button_juice(_event_card_btn, Color("8c7ae6"))
	_event_card_btn.pressed.connect(_open_login_calendar)
	left_vbox.add_child(_event_card_btn)
	
	var ev_hbox := HBoxContainer.new()
	ev_hbox.set_anchors_preset(PRESET_FULL_RECT)
	ev_hbox.offset_left = 12.0
	ev_hbox.offset_right = -12.0
	ev_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	ev_hbox.add_theme_constant_override("separation", 12)
	ev_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_event_card_btn.add_child(ev_hbox)
	
	var ev_icon_box := PanelContainer.new()
	ev_icon_box.custom_minimum_size = Vector2(44, 44)
	ev_icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ev_ib_sb := StyleBoxFlat.new()
	ev_ib_sb.bg_color = Color("8c7ae6")
	ev_ib_sb.set_corner_radius_all(10)
	ev_icon_box.add_theme_stylebox_override("panel", ev_ib_sb)
	ev_icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ev_hbox.add_child(ev_icon_box)
	
	var ev_ico_lbl := Label.new()
	ev_ico_lbl.text = "📅"
	ev_ico_lbl.set_anchors_preset(PRESET_FULL_RECT)
	ev_ico_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev_ico_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ev_ico_lbl.label_settings = BrawlUITheme.make_label_settings(24, Color.WHITE, 0, 0)
	ev_icon_box.add_child(ev_ico_lbl)
	
	var ev_mid_vbox := VBoxContainer.new()
	ev_mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ev_mid_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ev_mid_vbox.add_theme_constant_override("separation", 2)
	ev_mid_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ev_hbox.add_child(ev_mid_vbox)
	
	var ev_title := Label.new()
	ev_title.text = "EVENT"
	ev_title.label_settings = BrawlUITheme.make_label_settings(15, Color("a29bfe"), 4, 1)
	ev_mid_vbox.add_child(ev_title)
	
	var ev_sub := Label.new()
	ev_sub.text = "Weekend Bonus"
	ev_sub.label_settings = BrawlUITheme.make_label_settings(13, Color.WHITE, 2, 1)
	ev_mid_vbox.add_child(ev_sub)
	
	_event_timer_label = Label.new()
	_event_timer_label.text = "⏱ 2d 14h"
	_event_timer_label.label_settings = BrawlUITheme.make_label_settings(12, Color("74b9ff"), 2, 1)
	ev_mid_vbox.add_child(_event_timer_label)
	
	var ev_chev := Label.new()
	ev_chev.text = ">"
	ev_chev.label_settings = BrawlUITheme.make_label_settings(22, Color("a29bfe"), 4, 1)
	ev_hbox.add_child(ev_chev)
	
	# =========================================================================
	# RIGHT SIDE CARDS (NEW MAP & FREE REWARDS)
	# =========================================================================
	var right_vbox := VBoxContainer.new()
	right_vbox.anchor_left = 1.0
	right_vbox.anchor_right = 1.0
	right_vbox.offset_left = -336.0
	right_vbox.offset_top = 92.0
	right_vbox.offset_right = -24.0
	right_vbox.offset_bottom = 260.0
	right_vbox.add_theme_constant_override("separation", 12)
	right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side_cards_container.add_child(right_vbox)
	
	# Card 1: NEW MAP (Sky City)
	_map_card_btn = Button.new()
	_map_card_btn.custom_minimum_size = Vector2(312, 74)
	_map_card_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_arcade_button_juice(_map_card_btn, Color("00d2d3"))
	_map_card_btn.pressed.connect(_toggle_mode_drawer)
	right_vbox.add_child(_map_card_btn)
	
	var m_hbox := HBoxContainer.new()
	m_hbox.set_anchors_preset(PRESET_FULL_RECT)
	m_hbox.offset_left = 10.0
	m_hbox.offset_right = -12.0
	m_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	m_hbox.add_theme_constant_override("separation", 12)
	m_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_card_btn.add_child(m_hbox)
	
	var m_thumb := TextureRect.new()
	if acl:
		m_thumb.texture = acl.load_texture("res://assets/ui/thumb_sky_city.png")
	elif ResourceLoader.exists("res://assets/ui/thumb_sky_city.png"):
		m_thumb.texture = load("res://assets/ui/thumb_sky_city.png")
	m_thumb.custom_minimum_size = Vector2(66, 48)
	m_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	m_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	m_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m_hbox.add_child(m_thumb)
	
	var m_mid_vbox := VBoxContainer.new()
	m_mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_mid_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	m_mid_vbox.add_theme_constant_override("separation", 2)
	m_mid_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m_hbox.add_child(m_mid_vbox)
	
	var m_tag := Label.new()
	m_tag.text = "NEW MAP"
	m_tag.label_settings = BrawlUITheme.make_label_settings(13, Color("00d2d3"), 3, 1)
	m_mid_vbox.add_child(m_tag)
	
	var m_title := Label.new()
	m_title.text = "Sky City"
	m_title.label_settings = BrawlUITheme.make_label_settings(17, Color.WHITE, 4, 1)
	m_mid_vbox.add_child(m_title)
	
	var m_chev := Label.new()
	m_chev.text = ">"
	m_chev.label_settings = BrawlUITheme.make_label_settings(22, Color("00d2d3"), 4, 1)
	m_hbox.add_child(m_chev)
	
	# Card 2: FREE REWARDS (Watch Ad >)
	_free_rewards_card_btn = Button.new()
	_free_rewards_card_btn.custom_minimum_size = Vector2(312, 74)
	_free_rewards_card_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_arcade_button_juice(_free_rewards_card_btn, Color("f39c12"))
	_free_rewards_card_btn.pressed.connect(_on_claim_free_rewards_pressed)
	right_vbox.add_child(_free_rewards_card_btn)
	
	var r_hbox := HBoxContainer.new()
	r_hbox.set_anchors_preset(PRESET_FULL_RECT)
	r_hbox.offset_left = 12.0
	r_hbox.offset_right = -12.0
	r_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	r_hbox.add_theme_constant_override("separation", 12)
	r_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_free_rewards_card_btn.add_child(r_hbox)
	
	var r_icons_h := HBoxContainer.new()
	r_icons_h.add_theme_constant_override("separation", 4)
	r_icons_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r_hbox.add_child(r_icons_h)
	
	var play_box := PanelContainer.new()
	play_box.custom_minimum_size = Vector2(36, 36)
	play_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pb_sb := StyleBoxFlat.new()
	pb_sb.bg_color = Color("f39c12")
	pb_sb.set_corner_radius_all(8)
	play_box.add_theme_stylebox_override("panel", pb_sb)
	play_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pb_lbl := Label.new()
	pb_lbl.text = "▶"
	pb_lbl.set_anchors_preset(PRESET_FULL_RECT)
	pb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pb_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pb_lbl.label_settings = BrawlUITheme.make_label_settings(18, Color.WHITE, 0, 0)
	play_box.add_child(pb_lbl)
	r_icons_h.add_child(play_box)
	
	var gift_box := PanelContainer.new()
	gift_box.custom_minimum_size = Vector2(36, 36)
	gift_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gb_sb := StyleBoxFlat.new()
	gb_sb.bg_color = Color("e84118")
	gb_sb.set_corner_radius_all(8)
	gift_box.add_theme_stylebox_override("panel", gb_sb)
	gift_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gb_lbl := Label.new()
	gb_lbl.text = "🎁"
	gb_lbl.set_anchors_preset(PRESET_FULL_RECT)
	gb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gb_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gb_lbl.label_settings = BrawlUITheme.make_label_settings(18, Color.WHITE, 0, 0)
	gift_box.add_child(gb_lbl)
	r_icons_h.add_child(gift_box)
	
	var r_mid_vbox := VBoxContainer.new()
	r_mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_mid_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	r_mid_vbox.add_theme_constant_override("separation", 2)
	r_mid_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r_hbox.add_child(r_mid_vbox)
	
	var r_title := Label.new()
	r_title.text = "FREE REWARDS"
	r_title.label_settings = BrawlUITheme.make_label_settings(15, Color.WHITE, 4, 1)
	r_mid_vbox.add_child(r_title)
	
	var r_sub := Label.new()
	r_sub.text = "Watch Ad >"
	r_sub.label_settings = BrawlUITheme.make_label_settings(13, Color("fbc531"), 3, 1)
	r_mid_vbox.add_child(r_sub)
	
	var r_chev := Label.new()
	r_chev.text = ">"
	r_chev.label_settings = BrawlUITheme.make_label_settings(22, Color("fbc531"), 4, 1)
	r_hbox.add_child(r_chev)

func _on_claim_free_rewards_pressed() -> void:
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.add_cash(500)
		_refresh_top_bar()
		SoundFX.play_star_up()
		
		var toast := Label.new()
		toast.text = "🎉 +💵 500 FREE AD REWARD!"
		toast.label_settings = BrawlUITheme.make_label_settings(28, Color("fbc531"), 8, 3)
		toast.set_anchors_preset(PRESET_CENTER)
		toast.position = Vector2(960 - 200, 480)
		toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(toast)
		
		var tw := create_tween()
		tw.tween_property(toast, "position:y", 420.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(toast, "modulate:a", 0.0, 1.2).set_delay(0.4)
		tw.tween_callback(toast.queue_free)

func _open_login_calendar() -> void:
	if not _login_calendar_modal:
		_login_calendar_modal = LoginCalendarModalScene.instantiate()
		_login_calendar_modal.closed.connect(func(): _refresh_notification_badges())
		_login_calendar_modal.reward_claimed.connect(func(_day, _rew):
			_refresh_top_bar()
			_refresh_notification_badges()
			_load_showroom_car(current_view_car_id)
		)
		add_child(_login_calendar_modal)
	_login_calendar_modal.open_modal()

func _open_daily_quests() -> void:
	if not _daily_quests_drawer:
		_daily_quests_drawer = DailyQuestsDrawerScene.instantiate()
		_daily_quests_drawer.closed.connect(func(): _refresh_notification_badges())
		_daily_quests_drawer.quest_claimed.connect(func(_id, _rew):
			_refresh_top_bar()
			_refresh_notification_badges()
		)
		_daily_quests_drawer.safe_claimed.connect(func(_cash, _item):
			_refresh_top_bar()
			_refresh_notification_badges()
			_load_showroom_car(current_view_car_id)
		)
		add_child(_daily_quests_drawer)
	_daily_quests_drawer.open_drawer()

func _refresh_notification_badges() -> void:
	if has_node("/root/ProgressionManager"):
		var pm = get_node("/root/ProgressionManager")
		if _quests_progress_bar:
			_quests_progress_bar.value = 1.0 if not pm.has_unclaimed_rewards() else 3.0

func _refresh_top_bar() -> void:
	if has_node("/root/SaveManager"):
		var sm: SaveManagerClass = get_node("/root/SaveManager") as SaveManagerClass
		if _cash_label:
			_cash_label.text = "%d" % sm.total_cash
		if _streak_label:
			_streak_label.text = "%d DAY STREAK" % sm.daily_streak
		if _trophy_label:
			_trophy_label.text = "%d" % sm.best_daily_score
		if _level_label:
			var lvl: int = 1 + int(sm.total_cash / 500)
			_level_label.text = "Lv. %d" % lvl
		if _level_progress_bar:
			var prog: float = float(sm.total_cash % 500) / 500.0
			_level_progress_bar.value = prog

func _on_plus_cash_pressed() -> void:
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.add_cash(100)
		_refresh_top_bar()
		SoundFX.play_star_up()

# ==============================================================================
# LAYER 3: MODE SELECTOR BAR & GIANT "SMASH!" PLAY DOCK
# ==============================================================================

func _build_layer_3_home_dock() -> void:
	_home_dock_container = Control.new()
	_home_dock_container.name = "Layer3_HomeDock"
	_home_dock_container.anchor_left = 1.0
	_home_dock_container.anchor_top = 1.0
	_home_dock_container.anchor_right = 1.0
	_home_dock_container.anchor_bottom = 1.0
	_home_dock_container.offset_left = -840.0
	_home_dock_container.offset_top = -180.0
	_home_dock_container.offset_right = -20.0
	_home_dock_container.offset_bottom = -20.0
	_home_dock_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_home_dock_container)
	
	var dock_hbox := HBoxContainer.new()
	dock_hbox.set_anchors_preset(PRESET_FULL_RECT)
	dock_hbox.alignment = BoxContainer.ALIGNMENT_END
	dock_hbox.add_theme_constant_override("separation", 18)
	dock_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_dock_container.add_child(dock_hbox)
	
	var acl = get_node_or_null("/root/AssetChromaLoader")
	
	# Left: Slanted Mode Selector Card
	_mode_card_btn = Button.new()
	_mode_card_btn.custom_minimum_size = Vector2(360, 100)
	_mode_card_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mode_card_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_arcade_button_juice(_mode_card_btn, Color("00d2d3"))
	_mode_card_btn.pressed.connect(_toggle_mode_drawer)
	dock_hbox.add_child(_mode_card_btn)
	
	var mode_h := HBoxContainer.new()
	mode_h.set_anchors_preset(PRESET_FULL_RECT)
	mode_h.offset_left = 14.0
	mode_h.offset_right = -10.0
	mode_h.alignment = BoxContainer.ALIGNMENT_BEGIN
	mode_h.add_theme_constant_override("separation", 12)
	mode_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_card_btn.add_child(mode_h)
	
	var m_gift_ico := Label.new()
	m_gift_ico.text = "🎁"
	m_gift_ico.label_settings = BrawlUITheme.make_label_settings(32, Color.WHITE, 0, 0)
	m_gift_ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_h.add_child(m_gift_ico)
	
	var mode_vbox := VBoxContainer.new()
	mode_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_vbox.add_theme_constant_override("separation", 3)
	mode_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_h.add_child(mode_vbox)
	
	_mode_title_label = Label.new()
	_mode_title_label.text = "DAILY GETAWAY"
	_mode_title_label.label_settings = BrawlUITheme.make_label_settings(20, Color("00d2d3"), 5, 2)
	mode_vbox.add_child(_mode_title_label)
	
	_mode_desc_label = Label.new()
	_mode_desc_label.text = "TAP TO CHANGE MODE"
	_mode_desc_label.label_settings = BrawlUITheme.make_label_settings(13, Color("fbc531"), 3, 1)
	mode_vbox.add_child(_mode_desc_label)
	
	_mode_thumb_rect = TextureRect.new()
	if acl:
		_mode_thumb_rect.texture = acl.load_texture("res://assets/ui/thumb_daily_getaway.png")
	elif ResourceLoader.exists("res://assets/ui/thumb_daily_getaway.png"):
		_mode_thumb_rect.texture = load("res://assets/ui/thumb_daily_getaway.png")
	_mode_thumb_rect.custom_minimum_size = Vector2(70, 54)
	_mode_thumb_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mode_thumb_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_mode_thumb_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_h.add_child(_mode_thumb_rect)
	
	# Right: Giant Primary "SMASH!" Play Button with Transparent Background
	var smash_btn := TextureButton.new()
	smash_btn.custom_minimum_size = Vector2(360, 145)
	smash_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	smash_btn.focus_mode = Control.FOCUS_NONE
	smash_btn.ignore_texture_size = true
	smash_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	
	var tex_normal: Texture2D = null
	var tex_hover: Texture2D = null
	var tex_pressed: Texture2D = null
	var tex_disabled: Texture2D = null
	
	if acl:
		tex_normal = acl.load_texture("res://assets/ui/btn_smash_normal.png")
		tex_hover = acl.load_texture("res://assets/ui/btn_smash_hover.png")
		tex_pressed = acl.load_texture("res://assets/ui/btn_smash_pressed.png")
		tex_disabled = acl.load_texture("res://assets/ui/btn_smash_disabled.png")
	
	if not tex_normal and ResourceLoader.exists("res://assets/ui/btn_smash_play.png"):
		tex_normal = load("res://assets/ui/btn_smash_play.png")
	
	smash_btn.texture_normal = tex_normal
	smash_btn.texture_hover = tex_hover if tex_hover else tex_normal
	smash_btn.texture_pressed = tex_pressed if tex_pressed else tex_normal
	smash_btn.texture_disabled = tex_disabled if tex_disabled else tex_normal
	
	smash_btn.pivot_offset = Vector2(180, 72.5)
	smash_btn.resized.connect(func():
		if is_instance_valid(smash_btn):
			smash_btn.pivot_offset = smash_btn.size * 0.5
	)
	
	# Bounce scale juice on hover and click
	smash_btn.mouse_entered.connect(func():
		var tw := smash_btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(smash_btn, "scale", Vector2(1.06, 1.06), 0.12)
	)
	smash_btn.mouse_exited.connect(func():
		var tw := smash_btn.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(smash_btn, "scale", Vector2.ONE, 0.12)
	)
	smash_btn.button_down.connect(func():
		var tw := smash_btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(smash_btn, "scale", Vector2(0.93, 0.93), 0.06)
		SoundFX.play_ui_click()
	)
	smash_btn.button_up.connect(func():
		var tw := smash_btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(smash_btn, "scale", Vector2(1.08, 1.08), 0.08)
		tw.chain().tween_property(smash_btn, "scale", Vector2.ONE, 0.08)
	)
	
	smash_btn.pressed.connect(_on_smash_play_pressed)
	dock_hbox.add_child(smash_btn)
	_smash_play_button = smash_btn
	
	_build_mode_selector_drawer()

func _start_smash_pulse() -> void:
	if not _smash_play_button:
		return
	if _smash_pulse_tween and _smash_pulse_tween.is_valid():
		_smash_pulse_tween.kill()
	
	_smash_pulse_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_smash_pulse_tween.tween_property(_smash_play_button, "scale", Vector2(1.04, 1.04), 0.7)
	_smash_pulse_tween.tween_property(_smash_play_button, "scale", Vector2.ONE, 0.7)

func _refresh_mode_display() -> void:
	if has_node("/root/GameModeManager"):
		var gmm = get_node("/root/GameModeManager")
		current_mode_index = clampi(int(gmm.current_mode), 0, MODE_DEFS.size() - 1)
	
	var mdef: Dictionary = MODE_DEFS[current_mode_index]
	if _mode_title_label:
		_mode_title_label.text = str(mdef["name"])

func _on_smash_play_pressed() -> void:
	SoundFX.play_ui_click()
	play_pressed.emit(current_mode_index)
	
	if has_node("/root/SceneTransitionManager"):
		var stm = get_node("/root/SceneTransitionManager")
		stm.transition_to_scene("res://scenes/world/main_game.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/world/main_game.tscn")

func _build_mode_selector_drawer() -> void:
	_mode_drawer_panel = PanelContainer.new()
	_mode_drawer_panel.name = "ModeDrawerPanel"
	_mode_drawer_panel.set_anchors_preset(PRESET_CENTER)
	_mode_drawer_panel.custom_minimum_size = Vector2(800, 520)
	_mode_drawer_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("1e272e"), Color("0d1117"), 0.05, 24))
	_mode_drawer_panel.visible = false
	add_child(_mode_drawer_panel)
	
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 16)
	_mode_drawer_panel.add_child(mv)
	
	var title := Label.new()
	title.text = "SELECT GAME MODE"
	title.label_settings = BrawlUITheme.make_label_settings(32, Color("fbc531"), 8, 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(title)
	
	for def in MODE_DEFS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 72)
		BrawlUITheme.attach_button_juice(btn, Color("2f3640"))
		
		var blbl := Label.new()
		blbl.text = "%s — %s" % [str(def["name"]), str(def["desc"])]
		blbl.set_anchors_preset(PRESET_FULL_RECT)
		blbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		blbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		blbl.label_settings = BrawlUITheme.make_label_settings(22, Color.WHITE, 6, 2)
		blbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(blbl)
		
		var mid: int = int(def["id"])
		btn.pressed.connect(func():
			current_mode_index = mid
			if has_node("/root/GameModeManager"):
				var gmm = get_node("/root/GameModeManager")
				gmm.set_mode(mid)
			_refresh_mode_display()
			_mode_drawer_panel.visible = false
		)
		mv.add_child(btn)
	
	var close_btn := Button.new()
	close_btn.text = "BACK"
	close_btn.custom_minimum_size = Vector2(0, 58)
	BrawlUITheme.attach_button_juice(close_btn, Color("e84118"))
	close_btn.pressed.connect(func(): _mode_drawer_panel.visible = false)
	mv.add_child(close_btn)

func _toggle_mode_drawer() -> void:
	if _mode_drawer_panel:
		_mode_drawer_panel.visible = not _mode_drawer_panel.visible

'''

text = text[:s1] + block1_code + text[e1:]
print("Block 1 replaced successfully!")

# ==============================================================================
# BLOCK 2: _build_layer_4_bottom_dock to _connect_managers
# ==============================================================================
s2 = text.find("func _build_layer_4_bottom_dock() -> void:")
e2 = text.find("func _connect_managers() -> void:")
assert s2 != -1 and e2 != -1, "Block 2 markers not found"

block2_code = '''func _build_layer_4_bottom_dock() -> void:
	_bottom_dock_container = PanelContainer.new()
	_bottom_dock_container.name = "Layer4_BottomDock"
	_bottom_dock_container.anchor_top = 1.0
	_bottom_dock_container.anchor_bottom = 1.0
	_bottom_dock_container.offset_left = 24.0
	_bottom_dock_container.offset_top = -125.0
	_bottom_dock_container.offset_right = 640.0
	_bottom_dock_container.offset_bottom = -25.0
	_bottom_dock_container.add_theme_stylebox_override("panel", BrawlUITheme.make_capsule_style(Color("081423ee"), Color("0e2744"), 22))
	add_child(_bottom_dock_container)
	
	var tab_hbox := HBoxContainer.new()
	tab_hbox.set_anchors_preset(PRESET_FULL_RECT)
	tab_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_hbox.add_theme_constant_override("separation", 6)
	_bottom_dock_container.add_child(tab_hbox)
	
	var tab_titles: Array[String] = ["HOME", "CARS", "GEAR", "GACHA", "SOCIAL"]
	var tab_icon_paths: Array[String] = [
		"res://assets/ui/icon_tab_home.png",
		"res://assets/ui/icon_tab_cars.png",
		"res://assets/ui/icon_tab_gear.png",
		"res://assets/ui/icon_tab_gacha.png",
		"res://assets/ui/icon_tab_friends.png"
	]
	var acl = get_node_or_null("/root/AssetChromaLoader")
	_tab_buttons.clear()
	_tab_labels.clear()
	_tab_icons.clear()
	
	for i in range(tab_titles.size()):
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(100, 68)
		btn.focus_mode = Control.FOCUS_NONE
		
		var bh := HBoxContainer.new()
		bh.set_anchors_preset(PRESET_FULL_RECT)
		bh.alignment = BoxContainer.ALIGNMENT_CENTER
		bh.add_theme_constant_override("separation", 8)
		bh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bh)
		
		var t_icon := TextureRect.new()
		if acl:
			t_icon.texture = acl.load_texture(tab_icon_paths[i])
		t_icon.custom_minimum_size = Vector2(24, 24)
		t_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bh.add_child(t_icon)
		_tab_icons.append(t_icon)
		
		var lbl := Label.new()
		lbl.text = tab_titles[i]
		lbl.label_settings = BrawlUITheme.make_label_settings(17, Color.WHITE, 4, 1)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bh.add_child(lbl)
		_tab_labels.append(lbl)
		
		var tab_idx := i
		btn.pressed.connect(func(): switch_tab(tab_idx))
		tab_hbox.add_child(btn)
		_tab_buttons.append(btn)

func switch_tab(tab_idx: int) -> void:
	active_tab_index = tab_idx
	
	# Update Tab Button styles
	for i in range(_tab_buttons.size()):
		var b: Button = _tab_buttons[i]
		var is_active: bool = (i == tab_idx)
		if is_active:
			b.add_theme_stylebox_override("normal", BrawlUITheme.make_active_tab_style())
			b.add_theme_stylebox_override("hover", BrawlUITheme.make_active_tab_style())
			b.add_theme_stylebox_override("pressed", BrawlUITheme.make_active_tab_style())
			if i < _tab_labels.size() and _tab_labels[i]:
				_tab_labels[i].label_settings.font_color = Color("fbc531")
		else:
			b.add_theme_stylebox_override("normal", BrawlUITheme.make_inactive_tab_style())
			b.add_theme_stylebox_override("hover", BrawlUITheme.make_inactive_tab_style())
			b.add_theme_stylebox_override("pressed", BrawlUITheme.make_inactive_tab_style())
			if i < _tab_labels.size() and _tab_labels[i]:
				_tab_labels[i].label_settings.font_color = Color("a4b0be")
	
	# Toggle views cleanly so panels NEVER overlap
	if _showroom_ui_container:
		_showroom_ui_container.visible = (tab_idx == 0)
	if _sub_viewport_container:
		_sub_viewport_container.visible = (tab_idx == 0)
	if _home_dock_container:
		_home_dock_container.visible = (tab_idx == 0)
	if _side_cards_container:
		_side_cards_container.visible = (tab_idx == 0)
	
	if _cars_drawer:
		_cars_drawer.visible = (tab_idx == 1)
		if tab_idx == 1:
			_populate_cars_grid()
	
	if _inventory_drawer:
		_inventory_drawer.visible = (tab_idx == 2)
		if tab_idx == 2 and _inventory_panel and _inventory_panel.has_method("refresh_inventory"):
			_inventory_panel.refresh_inventory()
	
	if _gacha_drawer:
		_gacha_drawer.visible = (tab_idx == 3)
		if _gacha_result_panel:
			_gacha_result_panel.visible = false
	
	if _friends_squad_drawer:
		_friends_squad_drawer.visible = (tab_idx == 4)
		if tab_idx == 4 and _friends_squad_panel and _friends_squad_panel.has_method("refresh_all"):
			_friends_squad_panel.refresh_all()
	
	if _ranks_drawer:
		_ranks_drawer.visible = false
	
	_refresh_notification_badges()

'''

text = text[:s2] + block2_code + text[e2:]
print("Block 2 replaced successfully!")

with open(MENU_PATH, "w", encoding="utf-8") as f:
    f.write(text)

print("All patches applied to brawl_main_menu.gd successfully!")
