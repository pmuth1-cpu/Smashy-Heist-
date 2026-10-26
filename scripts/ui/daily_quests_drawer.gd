class_name DailyQuestsDrawer
extends Control

## Phase 12: 3 Rotating Daily Quests & Daily Heist Safe Drawer
## Displays active daily quests with progress bars, claim buttons, and 3/3 Heist Safe reward.

signal closed()
signal quest_claimed(quest_id: String, reward_amount: int)
signal safe_claimed(reward_cash: int, item_id: String)

const BrawlUITheme = preload("res://scripts/autoload/brawl_ui_theme.gd")
const SoundFX = preload("res://scripts/autoload/sound_fx.gd")

var _quest_cards_vbox: VBoxContainer = null
var _safe_progress_bar: ProgressBar = null
var _safe_status_label: Label = null
var _safe_claim_btn: Button = null
var _safe_reward_info_label: Label = null

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	refresh_quests()
	
	if has_node("/root/ProgressionManager"):
		var pm = get_node("/root/ProgressionManager")
		pm.quest_progress_updated.connect(func(_id, _cur, _tar): refresh_quests())
		pm.quest_reward_claimed.connect(func(_id, _rew): refresh_quests())
		pm.heist_safe_claimed.connect(func(_cash, _item): refresh_quests())

func _build_ui() -> void:
	# Dark backdrop
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.04, 0.08, 0.88)
	add_child(backdrop)
	
	# Centered Modal Window
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)
	
	var modal_box := PanelContainer.new()
	modal_box.custom_minimum_size = Vector2(860, 600)
	modal_box.add_theme_stylebox_override("panel", BrawlUITheme.make_cartoon_board_style(Color("0c1626f4"), Color("0984e3"), 28, 6))
	center.add_child(modal_box)
	
	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 12)
	modal_box.add_child(root_v)
	
	# Header Row (Title Ribbon Centered + Bubble Close Button on Right)
	var header_h := HBoxContainer.new()
	header_h.add_theme_constant_override("separation", 16)
	header_h.alignment = BoxContainer.ALIGNMENT_CENTER
	root_v.add_child(header_h)
	
	var left_spacer := Control.new()
	left_spacer.custom_minimum_size = Vector2(56, 56)
	header_h.add_child(left_spacer)
	
	var rib_rect := TextureRect.new()
	rib_rect.custom_minimum_size = Vector2(460, 95)
	rib_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rib_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rib_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var rib_path := "res://assets/ribbons/ribbon_header_quests.png"
	rib_rect.texture = BrawlUITheme.load_texture_safe(rib_path)
	header_h.add_child(rib_rect)
	
	var close_btn := Button.new()
	BrawlUITheme.attach_bubble_close_button(close_btn)
	close_btn.pressed.connect(_on_close_pressed)
	header_h.add_child(close_btn)
	
	# ==========================================================================
	# DAILY HEIST SAFE CONTAINER
	# ==========================================================================
	var safe_card := PanelContainer.new()
	safe_card.add_theme_stylebox_override("panel", BrawlUITheme.make_cartoon_board_style(Color("261a06"), Color("f39c12"), 18, 4))
	root_v.add_child(safe_card)
	
	var safe_v := VBoxContainer.new()
	safe_v.add_theme_constant_override("separation", 8)
	safe_card.add_child(safe_v)
	
	var safe_title_h := HBoxContainer.new()
	safe_title_h.add_theme_constant_override("separation", 12)
	safe_v.add_child(safe_title_h)
	
	var safe_tex_rect := TextureRect.new()
	safe_tex_rect.custom_minimum_size = Vector2(54, 54)
	safe_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	safe_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var safe_p := "res://assets/items/icon_cartoon_heist_safe.png"
	safe_tex_rect.texture = BrawlUITheme.load_texture_safe(safe_p)
	safe_title_h.add_child(safe_tex_rect)
	
	var safe_meta_v := VBoxContainer.new()
	safe_meta_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	safe_title_h.add_child(safe_meta_v)
	
	var safe_name := Label.new()
	safe_name.text = "DAILY HEIST VAULT SAFE"
	safe_name.label_settings = BrawlUITheme.make_label_settings(22, Color("fbc531"), 6, 2)
	safe_meta_v.add_child(safe_name)
	
	_safe_reward_info_label = Label.new()
	_safe_reward_info_label.text = "REWARD: +400 CASH & RANDOM 3D CAR GEAR PART"
	_safe_reward_info_label.label_settings = BrawlUITheme.make_label_settings(16, Color("2ecc71"), 6, 2)
	safe_meta_v.add_child(_safe_reward_info_label)
	
	_safe_status_label = Label.new()
	_safe_status_label.text = "0 / 3 QUESTS CLAIMED"
	_safe_status_label.label_settings = BrawlUITheme.make_label_settings(18, Color.WHITE, 6, 2)
	safe_title_h.add_child(_safe_status_label)
	
	# Progress bar for safe
	_safe_progress_bar = ProgressBar.new()
	_safe_progress_bar.custom_minimum_size = Vector2(0, 24)
	_safe_progress_bar.max_value = 3
	_safe_progress_bar.step = 1
	_safe_progress_bar.show_percentage = false
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color("f39c12")
	fill_sb.set_corner_radius_all(8)
	_safe_progress_bar.add_theme_stylebox_override("fill", fill_sb)
	safe_v.add_child(_safe_progress_bar)
	
	# Claim Safe Button
	_safe_claim_btn = Button.new()
	_safe_claim_btn.custom_minimum_size = Vector2(0, 72)
	_safe_claim_btn.text = "UNLOCK HEIST SAFE 🧰"
	BrawlUITheme.attach_button_juice(_safe_claim_btn, Color("f39c12"))
	_safe_claim_btn.pressed.connect(_on_claim_safe_pressed)
	safe_v.add_child(_safe_claim_btn)
	
	var sep2 := HSeparator.new()
	root_v.add_child(sep2)
	
	# ==========================================================================
	# 3 QUEST CARDS VBOX
	# ==========================================================================
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(scroll)
	
	_quest_cards_vbox = VBoxContainer.new()
	_quest_cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_cards_vbox.add_theme_constant_override("separation", 18)
	scroll.add_child(_quest_cards_vbox)

func refresh_quests() -> void:
	if not has_node("/root/ProgressionManager"):
		return
	
	var pm = get_node("/root/ProgressionManager")
	var quests: Array[Dictionary] = pm.daily_quests
	var claimed_count: int = pm.get_claimed_quests_count()
	
	# 1. Update Safe
	if _safe_progress_bar:
		_safe_progress_bar.value = claimed_count
	if _safe_status_label:
		_safe_status_label.text = "%d / 3 QUESTS CLAIMED" % claimed_count
	
	if _safe_claim_btn:
		if pm.daily_heist_safe_claimed:
			_safe_claim_btn.text = "✅ SAFE CRACKED FOR TODAY!"
			_safe_claim_btn.disabled = true
			BrawlUITheme.attach_button_juice(_safe_claim_btn, Color("576574"))
		elif pm.can_claim_heist_safe():
			_safe_claim_btn.text = "CRACK HEIST SAFE! (+400 💵 & GEAR) 💥"
			_safe_claim_btn.disabled = false
			BrawlUITheme.attach_candy_button_juice(_safe_claim_btn, "yellow")
		else:
			_safe_claim_btn.text = "COMPLETE ALL 3 QUESTS TO OPEN (%d/3)" % claimed_count
			_safe_claim_btn.disabled = true
			BrawlUITheme.attach_button_juice(_safe_claim_btn, Color("576574"))
	
	# 2. Update Quest Cards
	if not _quest_cards_vbox:
		return
	for c in _quest_cards_vbox.get_children():
		c.queue_free()
	
	for quest in quests:
		var card := _create_quest_card(quest)
		_quest_cards_vbox.add_child(card)

func _create_quest_card(quest: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", BrawlUITheme.make_cartoon_board_style(Color("121e2e"), Color("2980b9"), 16, 3))
	
	var cur: int = int(quest.get("current", 0))
	var tar: int = int(quest.get("target", 1))
	var claimed: bool = bool(quest.get("claimed", false))
	var q_id: String = String(quest.get("id", ""))
	var is_completed: bool = (cur >= tar)
	
	var row_h := HBoxContainer.new()
	row_h.add_theme_constant_override("separation", 20)
	card.add_child(row_h)
	
	# Left Icon Pill
	var icon_pill := PanelContainer.new()
	icon_pill.custom_minimum_size = Vector2(90, 90)
	icon_pill.add_theme_stylebox_override("panel", BrawlUITheme.make_pill_style(Color("0984e3"), Color("0d1117"), 0.04, 18))
	row_h.add_child(icon_pill)
	
	var q_icon := Label.new()
	q_icon.text = String(quest.get("icon", "🎯"))
	q_icon.label_settings = BrawlUITheme.make_label_settings(42, Color.WHITE, 4, 2)
	q_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_pill.add_child(q_icon)
	
	# Middle Quest Info & Progress
	var mid_v := VBoxContainer.new()
	mid_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_v.add_theme_constant_override("separation", 8)
	row_h.add_child(mid_v)
	
	var q_title := Label.new()
	q_title.text = String(quest.get("title", "Daily Quest"))
	q_title.label_settings = BrawlUITheme.make_label_settings(22, Color.WHITE, 6, 2)
	mid_v.add_child(q_title)
	
	var bar_h := HBoxContainer.new()
	bar_h.add_theme_constant_override("separation", 10)
	mid_v.add_child(bar_h)
	
	var pbar := ProgressBar.new()
	pbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pbar.custom_minimum_size = Vector2(0, 18)
	pbar.max_value = tar
	pbar.value = cur
	pbar.show_percentage = false
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color("2ecc71") if is_completed else Color("00d2d3")
	fill_sb.set_corner_radius_all(6)
	pbar.add_theme_stylebox_override("fill", fill_sb)
	bar_h.add_child(pbar)
	
	var frac_lbl := Label.new()
	frac_lbl.text = "%d / %d" % [cur, tar]
	frac_lbl.label_settings = BrawlUITheme.make_label_settings(18, Color("fbc531") if is_completed else Color.WHITE, 6, 2)
	bar_h.add_child(frac_lbl)
	
	# Right Action / Reward
	var right_v := VBoxContainer.new()
	right_v.alignment = BoxContainer.ALIGNMENT_CENTER
	right_v.add_theme_constant_override("separation", 6)
	row_h.add_child(right_v)
	
	var rew_lbl := Label.new()
	rew_lbl.text = "+%d 💵" % int(quest.get("reward", 150))
	rew_lbl.label_settings = BrawlUITheme.make_label_settings(22, Color("2ecc71"), 6, 2)
	rew_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_v.add_child(rew_lbl)
	
	if claimed:
		var done_lbl := Label.new()
		done_lbl.text = "✅ CLAIMED"
		done_lbl.label_settings = BrawlUITheme.make_label_settings(16, Color("718093"), 4, 1)
		right_v.add_child(done_lbl)
	elif is_completed:
		var claim_btn := Button.new()
		claim_btn.text = "CLAIM!"
		claim_btn.custom_minimum_size = Vector2(140, 52)
		BrawlUITheme.attach_candy_button_juice(claim_btn, "green")
		claim_btn.pressed.connect(func(): _on_claim_quest_pressed(q_id))
		right_v.add_child(claim_btn)
	else:
		var pending_lbl := Label.new()
		pending_lbl.text = "IN PROGRESS"
		pending_lbl.label_settings = BrawlUITheme.make_label_settings(14, Color("74b9ff"), 4, 1)
		right_v.add_child(pending_lbl)
	
	return card

func _on_claim_quest_pressed(quest_id: String) -> void:
	if not has_node("/root/ProgressionManager"):
		return
	var pm = get_node("/root/ProgressionManager")
	var success: bool = pm.claim_quest_reward(quest_id)
	if success:
		refresh_quests()
		quest_claimed.emit(quest_id, 150)

func _on_claim_safe_pressed() -> void:
	if not has_node("/root/ProgressionManager"):
		return
	var pm = get_node("/root/ProgressionManager")
	if not pm.can_claim_heist_safe():
		return
	
	var res: Dictionary = pm.claim_heist_safe()
	refresh_quests()
	safe_claimed.emit(int(res.get("cash", 400)), String(res.get("item_id", "")))

func _on_close_pressed() -> void:
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_ui_click()
	visible = false
	closed.emit()

func open_drawer() -> void:
	visible = true
	refresh_quests()
