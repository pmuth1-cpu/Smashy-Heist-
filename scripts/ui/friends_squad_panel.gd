class_name FriendsSquadPanel
extends Control

## Phase 12: Friends Code & 3D Squad Lobby Management Panel
## Coordinates player friend code copy, friend search/add, friend cards,
## and 1-tap squad lobby invitations (up to 4 players).

signal closed()
signal return_requested()
signal friend_invited(friend_data: Dictionary)
signal squad_updated()

const BrawlUITheme = preload("res://scripts/autoload/brawl_ui_theme.gd")
const SoundFX = preload("res://scripts/autoload/sound_fx.gd")

var _my_code_label: Label = null
var _copy_feedback_label: Label = null
var _add_friend_input: LineEdit = null
var _squad_chips_hbox: HBoxContainer = null
var _friends_list_vbox: VBoxContainer = null

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	refresh_all()
	
	if has_node("/root/SocialFriendManager"):
		var sfm = get_node("/root/SocialFriendManager")
		sfm.squad_updated.connect(refresh_squad_lobby)
		sfm.friend_added.connect(func(_f): refresh_friends_list())

func _on_return_pressed() -> void:
	closed.emit()
	return_requested.emit()

func _build_ui() -> void:
	# Main Drawer Panel styled with Brawl Stars card style
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("161f2e"), Color("0d1117"), 0.0, 24))
	add_child(panel)
	
	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 16)
	panel.add_child(root_v)
	
	# Top Navigation Bar with Return & Home buttons
	var top_nav_h := HBoxContainer.new()
	top_nav_h.add_theme_constant_override("separation", 12)
	top_nav_h.alignment = BoxContainer.ALIGNMENT_BEGIN
	root_v.add_child(top_nav_h)
	
	var back_btn := Button.new()
	back_btn.name = "ReturnButton"
	back_btn.text = "◀ RETURN"
	back_btn.custom_minimum_size = Vector2(140, 56)
	BrawlUITheme.attach_arcade_button_juice(back_btn, Color("00d2d3"))
	back_btn.pressed.connect(_on_return_pressed)
	top_nav_h.add_child(back_btn)
	
	var home_btn := Button.new()
	home_btn.name = "HomeButton"
	home_btn.text = "⌂ HOME"
	home_btn.custom_minimum_size = Vector2(120, 56)
	BrawlUITheme.attach_arcade_button_juice(home_btn, Color("00d2d3"))
	home_btn.pressed.connect(_on_return_pressed)
	top_nav_h.add_child(home_btn)
	
	# Centered Title & Subtitle
	var title_v := VBoxContainer.new()
	title_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_v.alignment = BoxContainer.ALIGNMENT_CENTER
	top_nav_h.add_child(title_v)
	
	var title_lbl := Label.new()
	title_lbl.text = "👥 SQUAD LOBBY & FRIENDS"
	title_lbl.label_settings = BrawlUITheme.make_label_settings(36, Color("fbc531"), 10, 4)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_v.add_child(title_lbl)
	
	var sub_lbl := Label.new()
	sub_lbl.text = "INVITE FRIENDS TO FORM A 4-CAR GETAWAY SQUAD ON YOUR TURNTABLE!"
	sub_lbl.label_settings = BrawlUITheme.make_label_settings(16, Color("74b9ff"), 6, 2)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_v.add_child(sub_lbl)
	
	# Right spacer for balance
	var right_spacer := Control.new()
	right_spacer.custom_minimum_size = Vector2(272, 56)
	top_nav_h.add_child(right_spacer)
	
	# ==========================================================================
	# SECTION 1: MY FRIEND CODE & ADD FRIEND BAR
	# ==========================================================================
	var code_card := PanelContainer.new()
	code_card.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("1e272e"), Color("0984e3"), 0.04, 18))
	root_v.add_child(code_card)
	
	var code_h := HBoxContainer.new()
	code_h.add_theme_constant_override("separation", 16)
	code_card.add_child(code_h)
	
	# My Code Left
	var my_code_v := VBoxContainer.new()
	my_code_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	my_code_v.add_theme_constant_override("separation", 4)
	code_h.add_child(my_code_v)
	
	var code_title := Label.new()
	code_title.text = "YOUR SHAREABLE FRIEND CODE:"
	code_title.label_settings = BrawlUITheme.make_label_settings(14, Color("fbc531"), 4, 1)
	my_code_v.add_child(code_title)
	
	var copy_row := HBoxContainer.new()
	copy_row.add_theme_constant_override("separation", 10)
	my_code_v.add_child(copy_row)
	
	_my_code_label = Label.new()
	_my_code_label.text = "#SH-XXXX"
	_my_code_label.label_settings = BrawlUITheme.make_label_settings(28, Color.WHITE, 8, 3)
	copy_row.add_child(_my_code_label)
	
	var copy_btn := Button.new()
	copy_btn.text = "📋 COPY"
	copy_btn.custom_minimum_size = Vector2(110, 44)
	BrawlUITheme.attach_button_juice(copy_btn, Color("0984e3"))
	copy_btn.pressed.connect(_on_copy_code_pressed)
	copy_row.add_child(copy_btn)
	
	_copy_feedback_label = Label.new()
	_copy_feedback_label.text = ""
	_copy_feedback_label.label_settings = BrawlUITheme.make_label_settings(14, Color("2ecc71"), 4, 1)
	my_code_v.add_child(_copy_feedback_label)
	
	# Add Friend Right
	var add_v := VBoxContainer.new()
	add_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_v.add_theme_constant_override("separation", 4)
	code_h.add_child(add_v)
	
	var add_title := Label.new()
	add_title.text = "ENTER FRIEND CODE:"
	add_title.label_settings = BrawlUITheme.make_label_settings(14, Color("74b9ff"), 4, 1)
	add_v.add_child(add_title)
	
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 10)
	add_v.add_child(add_row)
	
	_add_friend_input = LineEdit.new()
	_add_friend_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_friend_input.custom_minimum_size = Vector2(0, 48)
	_add_friend_input.placeholder_text = "#SH-9021"
	_add_friend_input.max_length = 10
	add_row.add_child(_add_friend_input)
	
	var add_btn := Button.new()
	add_btn.text = "➕ ADD"
	add_btn.custom_minimum_size = Vector2(100, 48)
	BrawlUITheme.attach_button_juice(add_btn, Color("44bd32"))
	add_btn.pressed.connect(_on_add_friend_pressed)
	add_row.add_child(add_btn)
	
	# ==========================================================================
	# SECTION 2: ACTIVE SQUAD LOBBY BAR (1 HOST + 3 PEERS)
	# ==========================================================================
	var squad_box := PanelContainer.new()
	squad_box.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("1a2536"), Color("f39c12"), 0.04, 18))
	root_v.add_child(squad_box)
	
	var squad_v := VBoxContainer.new()
	squad_v.add_theme_constant_override("separation", 10)
	squad_box.add_child(squad_v)
	
	var squad_header_h := HBoxContainer.new()
	squad_header_h.add_theme_constant_override("separation", 12)
	squad_v.add_child(squad_header_h)
	
	var s_title := Label.new()
	s_title.text = "🏎️ ACTIVE GETAWAY SQUAD (SHOWROOM STAGE)"
	s_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s_title.label_settings = BrawlUITheme.make_label_settings(20, Color("fbc531"), 6, 2)
	squad_header_h.add_child(s_title)
	
	var clear_btn := Button.new()
	clear_btn.text = "CLEAR SQUAD"
	clear_btn.custom_minimum_size = Vector2(120, 36)
	BrawlUITheme.attach_button_juice(clear_btn, Color("e84118"))
	clear_btn.pressed.connect(_on_clear_squad_pressed)
	squad_header_h.add_child(clear_btn)
	
	_squad_chips_hbox = HBoxContainer.new()
	_squad_chips_hbox.add_theme_constant_override("separation", 12)
	squad_v.add_child(_squad_chips_hbox)
	
	var sep2 := HSeparator.new()
	root_v.add_child(sep2)
	
	# ==========================================================================
	# SECTION 3: FRIENDS LIST SCROLL CONTAINER
	# ==========================================================================
	var list_title := Label.new()
	list_title.text = "ONLINE FRIENDS & BENCHMARK BUDDIES"
	list_title.label_settings = BrawlUITheme.make_label_settings(22, Color.WHITE, 6, 2)
	root_v.add_child(list_title)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(scroll)
	
	_friends_list_vbox = VBoxContainer.new()
	_friends_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_friends_list_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(_friends_list_vbox)

func refresh_all() -> void:
	if has_node("/root/SocialFriendManager"):
		var sfm = get_node("/root/SocialFriendManager")
		if _my_code_label:
			_my_code_label.text = sfm.get_player_friend_code()
	
	refresh_squad_lobby()
	refresh_friends_list()

func refresh_squad_lobby() -> void:
	if not _squad_chips_hbox:
		return
	for c in _squad_chips_hbox.get_children():
		c.queue_free()
	
	# Slot 0: Local Player (Host)
	var host_chip := _create_squad_chip("👑 YOU (HOST)", "default_coupe", true, -1)
	_squad_chips_hbox.add_child(host_chip)
	
	# Slots 1 to 3: Active Squad Members or Empty Slots
	var active_members: Array[Dictionary] = []
	if has_node("/root/SocialFriendManager"):
		var sfm = get_node("/root/SocialFriendManager")
		active_members = sfm.active_squad_members
	
	for slot_idx in range(3):
		if slot_idx < active_members.size():
			var member: Dictionary = active_members[slot_idx]
			var m_name: String = String(member.get("name", "Buddy"))
			var m_car: String = String(member.get("car_id", "default_coupe"))
			var chip := _create_squad_chip(m_name, m_car, false, slot_idx)
			_squad_chips_hbox.add_child(chip)
		else:
			# Empty Slot
			var empty_chip := _create_empty_squad_chip(slot_idx + 1)
			_squad_chips_hbox.add_child(empty_chip)

func _create_squad_chip(member_name: String, car_id: String, is_host: bool, member_idx: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border_col: Color = Color("f39c12") if is_host else Color("00d2d3")
	chip.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("101622"), border_col, 0.04, 16))
	
	var cv := VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 4)
	chip.add_child(cv)
	
	var n_lbl := Label.new()
	n_lbl.text = member_name
	n_lbl.label_settings = BrawlUITheme.make_label_settings(16, Color.WHITE, 6, 2)
	n_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(n_lbl)
	
	var c_lbl := Label.new()
	c_lbl.text = car_id.to_upper().replace("_", " ")
	c_lbl.label_settings = BrawlUITheme.make_label_settings(12, Color("74b9ff"), 4, 1)
	c_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(c_lbl)
	
	var status_lbl := Label.new()
	status_lbl.text = "✅ READY!"
	status_lbl.label_settings = BrawlUITheme.make_label_settings(14, Color("2ecc71"), 4, 1)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(status_lbl)
	
	if not is_host:
		var kick_btn := Button.new()
		kick_btn.text = "✕ REMOVE"
		kick_btn.custom_minimum_size = Vector2(0, 30)
		BrawlUITheme.attach_button_juice(kick_btn, Color("e84118"))
		kick_btn.pressed.connect(func(): _on_kick_squad_member(member_idx))
		cv.add_child(kick_btn)
	
	return chip

func _create_empty_squad_chip(slot_num: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("0f141e"), Color("2f3640"), 0.04, 16))
	
	var cv := VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 6)
	chip.add_child(cv)
	
	var plus_lbl := Label.new()
	plus_lbl.text = "➕"
	plus_lbl.label_settings = BrawlUITheme.make_label_settings(24, Color("718093"), 4, 1)
	plus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(plus_lbl)
	
	var slot_lbl := Label.new()
	slot_lbl.text = "SLOT %d EMPTY" % slot_num
	slot_lbl.label_settings = BrawlUITheme.make_label_settings(14, Color("718093"), 4, 1)
	slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(slot_lbl)
	
	return chip

func refresh_friends_list() -> void:
	if not _friends_list_vbox or not has_node("/root/SocialFriendManager"):
		return
	for c in _friends_list_vbox.get_children():
		c.queue_free()
	
	var sfm = get_node("/root/SocialFriendManager")
	var friends: Array[Dictionary] = sfm.get_friends_list()
	
	for friend in friends:
		var card := _create_friend_card(friend)
		_friends_list_vbox.add_child(card)

func _create_friend_card(friend: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 96)
	card.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("1e272e"), Color("0d1117"), 0.04, 18))
	
	var f_code: String = String(friend.get("code", "#SH-0000"))
	var f_name: String = String(friend.get("name", "Buddy"))
	var f_car: String = String(friend.get("car_id", "default_coupe"))
	var f_trophies: int = int(friend.get("trophies", 1200))
	var f_streak: int = int(friend.get("streak", 1))
	var f_status: String = String(friend.get("status", "🟢 ONLINE"))
	
	var row_h := HBoxContainer.new()
	row_h.add_theme_constant_override("separation", 18)
	card.add_child(row_h)
	
	# Avatar Badge
	var av_pill := PanelContainer.new()
	av_pill.custom_minimum_size = Vector2(76, 76)
	av_pill.add_theme_stylebox_override("panel", BrawlUITheme.make_pill_style(Color("0984e3"), Color("0d1117"), 0.04, 16))
	row_h.add_child(av_pill)
	
	var av_lbl := Label.new()
	av_lbl.text = "🏎️"
	av_lbl.label_settings = BrawlUITheme.make_label_settings(36, Color.WHITE, 4, 2)
	av_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av_pill.add_child(av_lbl)
	
	# Friend Info VBox
	var info_v := VBoxContainer.new()
	info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_v.alignment = BoxContainer.ALIGNMENT_CENTER
	info_v.add_theme_constant_override("separation", 4)
	row_h.add_child(info_v)
	
	var name_h := HBoxContainer.new()
	name_h.add_theme_constant_override("separation", 10)
	info_v.add_child(name_h)
	
	var name_lbl := Label.new()
	name_lbl.text = f_name
	name_lbl.label_settings = BrawlUITheme.make_label_settings(22, Color.WHITE, 6, 2)
	name_h.add_child(name_lbl)
	
	var code_lbl := Label.new()
	code_lbl.text = "(%s)" % f_code
	code_lbl.label_settings = BrawlUITheme.make_label_settings(16, Color("74b9ff"), 4, 1)
	name_h.add_child(code_lbl)
	
	var meta_h := HBoxContainer.new()
	meta_h.add_theme_constant_override("separation", 14)
	info_v.add_child(meta_h)
	
	var car_lbl := Label.new()
	car_lbl.text = "RIDE: %s" % f_car.to_upper().replace("_", " ")
	car_lbl.label_settings = BrawlUITheme.make_label_settings(15, Color("fbc531"), 4, 1)
	meta_h.add_child(car_lbl)
	
	var trophy_lbl := Label.new()
	trophy_lbl.text = "🏆 %d" % f_trophies
	trophy_lbl.label_settings = BrawlUITheme.make_label_settings(15, Color("f1c40f"), 4, 1)
	meta_h.add_child(trophy_lbl)
	
	var streak_lbl := Label.new()
	streak_lbl.text = "🔥 %d" % f_streak
	streak_lbl.label_settings = BrawlUITheme.make_label_settings(15, Color("e74c3c"), 4, 1)
	meta_h.add_child(streak_lbl)
	
	var status_lbl := Label.new()
	status_lbl.text = f_status
	status_lbl.label_settings = BrawlUITheme.make_label_settings(14, Color("2ecc71"), 4, 1)
	meta_h.add_child(status_lbl)
	
	# Action Button: Invite to Squad
	var action_v := VBoxContainer.new()
	action_v.alignment = BoxContainer.ALIGNMENT_CENTER
	row_h.add_child(action_v)
	
	var sfm = get_node("/root/SocialFriendManager")
	var is_in_squad: bool = sfm.is_friend_in_squad(f_code)
	
	if is_in_squad:
		var in_pill := PanelContainer.new()
		in_pill.add_theme_stylebox_override("panel", BrawlUITheme.make_pill_style(Color("2ecc71"), Color("0d1117"), 0.04, 14))
		action_v.add_child(in_pill)
		
		var in_lbl := Label.new()
		in_lbl.text = "IN SQUAD"
		in_lbl.label_settings = BrawlUITheme.make_label_settings(16, Color.WHITE, 6, 2)
		in_pill.add_child(in_lbl)
	else:
		var inv_btn := Button.new()
		inv_btn.text = "➕ INVITE"
		inv_btn.custom_minimum_size = Vector2(140, 50)
		BrawlUITheme.attach_button_juice(inv_btn, Color("44bd32"))
		inv_btn.pressed.connect(func(): _on_invite_pressed(friend))
		action_v.add_child(inv_btn)
	
	return card

func _on_copy_code_pressed() -> void:
	if has_node("/root/SocialFriendManager"):
		var sfm = get_node("/root/SocialFriendManager")
		var code: String = sfm.copy_friend_code_to_clipboard()
		if _copy_feedback_label:
			_copy_feedback_label.text = "✅ COPIED %s TO CLIPBOARD!" % code
			var tw := create_tween()
			tw.tween_interval(2.5)
			tw.tween_callback(func():
				if is_instance_valid(_copy_feedback_label):
					_copy_feedback_label.text = ""
			)

func _on_add_friend_pressed() -> void:
	if not _add_friend_input:
		return
	var text: String = _add_friend_input.text.strip_edges()
	if text.is_empty():
		return
	
	if has_node("/root/SocialFriendManager"):
		var sfm = get_node("/root/SocialFriendManager")
		var friend_added: Dictionary = sfm.add_friend_by_code(text)
		if not friend_added.is_empty():
			_add_friend_input.text = ""
			refresh_friends_list()

func _on_invite_pressed(friend: Dictionary) -> void:
	if has_node("/root/SocialFriendManager"):
		var sfm = get_node("/root/SocialFriendManager")
		var success: bool = sfm.invite_friend_to_squad(friend)
		if success:
			refresh_squad_lobby()
			refresh_friends_list()
			friend_invited.emit(friend)
			squad_updated.emit()

func _on_kick_squad_member(member_idx: int) -> void:
	if has_node("/root/SocialFriendManager"):
		var sfm = get_node("/root/SocialFriendManager")
		sfm.remove_squad_member(member_idx)
		refresh_squad_lobby()
		refresh_friends_list()
		squad_updated.emit()

func _on_clear_squad_pressed() -> void:
	if has_node("/root/SocialFriendManager"):
		var sfm = get_node("/root/SocialFriendManager")
		sfm.clear_squad()
		refresh_squad_lobby()
		refresh_friends_list()
		squad_updated.emit()
