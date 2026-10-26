class_name TouchHUD
extends CanvasLayer

const BrawlUITheme = preload("res://scripts/autoload/brawl_ui_theme.gd")
const SoundFX = preload("res://scripts/autoload/sound_fx.gd")

## In-Game Brawl Stars HUD Overhaul & 3D Floating Popup Text
## Features:
## - Slanted dynamic health bar (green->yellow->red) + HP readout
## - 5 Animated Wanted Stars with pop & gold flash animation
## - Giant 42pt outlined score counter + shaking combo badge with timer drain bar
## - Bottom-center circular/slanted Active Gadget button with cooldown sweep
## - 3D Floating billboard combat text popups for smash props, wrecked cops, and near-misses

signal steer_changed(steer: float)
signal reverse_changed(is_reversing: bool)
signal mode_play_started(mode_id: int)

@export var target_car: ArcadeCar:
	set(val):
		target_car = val
		_refresh_gadget_info()
		if target_car and target_car.has_signal("powerup_applied") and not target_car.powerup_applied.is_connected(_on_car_powerup_applied):
			target_car.powerup_applied.connect(_on_car_powerup_applied)

# Top Bar Nodes
@onready var safe_margin_container: MarginContainer = $SafeMarginContainer
@onready var left_touch_zone: Control = $SafeMarginContainer/TouchZones/LeftTouchZone
@onready var right_touch_zone: Control = $SafeMarginContainer/TouchZones/RightTouchZone
@onready var left_indicator: ColorRect = $SafeMarginContainer/TouchZones/LeftTouchZone/LeftIndicator
@onready var right_indicator: ColorRect = $SafeMarginContainer/TouchZones/RightTouchZone/RightIndicator

@onready var health_panel: PanelContainer = $SafeMarginContainer/VBoxContainer/TopBar/TopLeftBox/HealthPanel
@onready var health_icon: Label = find_child("HealthIcon", true, false)
@onready var health_bar: ProgressBar = $SafeMarginContainer/VBoxContainer/TopBar/TopLeftBox/HealthPanel/HealthHBox/HealthBar
@onready var health_number: Label = $SafeMarginContainer/VBoxContainer/TopBar/TopLeftBox/HealthPanel/HealthHBox/HealthNumber
@onready var stars_container: HBoxContainer = $SafeMarginContainer/VBoxContainer/TopBar/TopLeftBox/StarsContainer

@onready var score_label: Label = find_child("ScoreLabel", true, false)
@onready var combo_badge: PanelContainer = find_child("ComboBadge", true, false)
@onready var combo_label: Label = find_child("ComboLabel", true, false)
@onready var combo_drain_bar: ProgressBar = find_child("ComboDrainBar", true, false)
@onready var loot_banner: Label = find_child("LootBanner", true, false)
@onready var pause_button: Button = find_child("PauseButton", true, false)

# Gadget Button Nodes
@onready var gadget_container: Control = $GadgetContainer
@onready var gadget_button: Button = $GadgetContainer/GadgetButton
@onready var gadget_icon: Label = $GadgetContainer/GadgetButton/GadgetVBox/GadgetIcon
@onready var gadget_name: Label = $GadgetContainer/GadgetButton/GadgetVBox/GadgetName
@onready var cooldown_overlay: ColorRect = $GadgetContainer/GadgetButton/CooldownOverlay
@onready var cooldown_label: Label = $GadgetContainer/GadgetButton/CooldownOverlay/CooldownLabel

# Modals & Overlays
@onready var pause_menu_modal: Control = get_node_or_null("PauseMenuModal")
@onready var loot_pointer: Control = get_node_or_null("LootPointer")
@onready var run_summary_panel: RunSummaryPanel = get_node_or_null("RunSummaryPanel")
@onready var leaderboard_panel: LeaderboardPanel = get_node_or_null("LeaderboardPanel")
@onready var garage_panel: GarageGachaPanel = get_node_or_null("GarageGachaPanel")
@onready var multiplayer_lobby: MultiplayerLobby = get_node_or_null("MultiplayerLobby")
@onready var brawl_main_menu: Control = get_node_or_null("BrawlMainMenu")
@onready var star_perk_popup: Control = get_node_or_null("StarPerkPopup")

var steer_input: float = 0.0
var is_reversing: bool = false

var _touches: Dictionary = {}
var _zone_left_held: bool = false
var _zone_right_held: bool = false
var _zone_reverse_held: bool = false
var _score: int = 0
var _current_stars: int = 1
var _display_hp: float = 150.0

# Gadget State
var gadget_cooldown: float = 0.0
const GADGET_MAX_COOLDOWN: float = 8.0

# Powerup & Boss HUD
var _powerup_panel: PanelContainer = null
var _powerup_label: Label = null
var _powerup_timer: float = 0.0
var _boss_panel: PanelContainer = null
var _boss_name_label: Label = null
var _boss_hp_bar: ProgressBar = null
var _mode_objective_active: bool = false
var action_vehicle_button: Button = null
var tank_rocket_button: Button = null

# Low HP Alert System
var _low_hp_vignette: Panel = null
var _low_hp_alert_badge: PanelContainer = null
var _low_hp_alert_label: Label = null
var _low_hp_pulse_timer: float = 0.0
var _low_hp_sound_timer: float = 0.0

func _ready() -> void:
	_apply_safe_area()
	_init_hud_styles()
	_setup_mobile_vehicle_button()
	_setup_tank_rocket_button()
	_setup_low_hp_alert()
	set_score(0)
	set_wanted_stars(1)
	
	if combo_badge:
		combo_badge.visible = false
	if combo_drain_bar:
		combo_drain_bar.visible = false
	
	# Connect to WantedManager
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		wm.score_updated.connect(func(score: int, combo: int):
			set_score(score)
			if combo > 1:
				show_combo(combo, 0)
			else:
				hide_combo()
		)
		wm.wanted_star_changed.connect(func(stars: int, _title: String):
			set_wanted_stars(stars)
			if stars >= 2 and star_perk_popup:
				star_perk_popup.show_star_perks(stars)
		)
		wm.run_started.connect(func(_seed: int, _mod: String):
			set_score(0)
			set_wanted_stars(1)
		)
	
	if has_node("/root/ProgressionManager"):
		var pm = get_node("/root/ProgressionManager")
		if pm.has_signal("quest_toast_requested") and not pm.quest_toast_requested.is_connected(show_quest_toast):
			pm.quest_toast_requested.connect(show_quest_toast)
	
	# Touch Zone Inputs
	if left_touch_zone and not left_touch_zone.gui_input.is_connected(_on_left_touch_gui_input):
		left_touch_zone.gui_input.connect(_on_left_touch_gui_input)
	if right_touch_zone and not right_touch_zone.gui_input.is_connected(_on_right_touch_gui_input):
		right_touch_zone.gui_input.connect(_on_right_touch_gui_input)
	
	# Gadget Button
	if gadget_button:
		gadget_button.custom_minimum_size = Vector2(96, 96)
		BrawlUITheme.attach_candy_button_juice(gadget_button, "green")
		if not gadget_button.pressed.is_connected(_on_gadget_button_pressed):
			gadget_button.pressed.connect(_on_gadget_button_pressed)
	
	# Pause Button
	if pause_button:
		BrawlUITheme.attach_bubble_pause_button(pause_button)
		if not pause_button.pressed.is_connected(_on_pause_button_pressed):
			pause_button.pressed.connect(_on_pause_button_pressed)
	
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if not sm.car_equipped.is_connected(_on_car_equipped):
			sm.car_equipped.connect(_on_car_equipped)
	
	_refresh_gadget_info()

func _init_hud_styles() -> void:
	if score_label:
		score_label.label_settings = BrawlUITheme.make_label_settings(42, Color.WHITE, 10, 4)
	if combo_label:
		combo_label.label_settings = BrawlUITheme.make_label_settings(26, Color.WHITE, 8, 3)
	if pause_button:
		pause_button.icon = null
	_setup_wanted_stars()

func _setup_wanted_stars() -> void:
	if not stars_container:
		return
	
	var gold_tex: Texture2D = BrawlUITheme.load_texture_safe("res://assets/hud/hud_cartoon_star_gold.png")
	if not gold_tex:
		gold_tex = BrawlUITheme.load_texture_safe("res://assets/hud/hud_wanted_star_gold.png")
	var empty_tex: Texture2D = BrawlUITheme.load_texture_safe("res://assets/hud/hud_cartoon_star_empty.png")
	if not empty_tex:
		empty_tex = BrawlUITheme.load_texture_safe("res://assets/hud/hud_wanted_star_empty.png")
	
	if not gold_tex:
		return
	
	for c in stars_container.get_children():
		c.queue_free()
	
	for i in range(5):
		var tr := TextureRect.new()
		tr.name = "Star_%d" % i
		tr.custom_minimum_size = Vector2(34, 34)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = empty_tex
		tr.set_meta("gold_tex", gold_tex)
		tr.set_meta("empty_tex", empty_tex)
		stars_container.add_child(tr)

func _process(delta: float) -> void:
	_update_health_display(delta)
	_update_combo_drain()
	_update_gadget_cooldown(delta)
	_update_loot_pointer()
	_update_mobile_vehicle_button()
	
	if _powerup_timer > 0.0:
		_powerup_timer -= delta
		if _powerup_timer <= 0.0 and _powerup_panel:
			_powerup_panel.visible = false
	
	_process_steering_input()

# ==============================================================================
# 1. SLANTED HEALTH BAR & WANTED STARS
# ==============================================================================

func _update_health_display(delta: float) -> void:
	# Check if player is on foot as PlayerCharacter
	var active_runner: PlayerCharacter = null
	if is_inside_tree():
		var runners := get_tree().get_nodes_in_group("player_character")
		for r in runners:
			if is_instance_valid(r) and not r.is_queued_for_deletion():
				active_runner = r as PlayerCharacter
				break
	
	var current_target_hp: float = 0.0
	var max_val: float = 100.0
	var is_on_foot: bool = false
	
	if active_runner:
		is_on_foot = true
		current_target_hp = active_runner.current_hp
		max_val = maxf(1.0, active_runner.max_hp)
	elif target_car and is_instance_valid(target_car):
		current_target_hp = target_car.current_hp
		max_val = maxf(1.0, target_car.max_hp)
	else:
		return
	
	_display_hp = lerpf(_display_hp, current_target_hp, 10.0 * delta)
	
	if health_icon:
		if is_on_foot:
			health_icon.text = "🏃"
		else:
			health_icon.text = "🚗"
	
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = _display_hp
		
		var ratio: float = clampf(_display_hp / max_val, 0.0, 1.0)
		var fill_color: Color = Color("2ecc71") # Green
		if ratio < 0.30:
			fill_color = Color("e74c3c") # Red
		elif ratio < 0.60:
			fill_color = Color("f1c40f") # Yellow
		
		var sb: StyleBoxFlat = health_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if sb:
			sb.bg_color = fill_color
	
	if health_number:
		if is_on_foot:
			var hearts: int = clampi(int(ceil(_display_hp / 33.34)), 0, 3)
			var heart_str: String = "❤️".repeat(hearts) + "🖤".repeat(3 - hearts)
			health_number.text = "%s %d" % [heart_str, int(ceil(_display_hp))]
		else:
			health_number.text = "%d/%d" % [int(ceil(_display_hp)), int(max_val)]
	
	# Process Low HP Alert (vignette, warning badge, urgent audio chime)
	var hp_ratio: float = current_target_hp / max_val
	_process_low_hp_alert(delta, hp_ratio, current_target_hp > 0.0)

func _setup_low_hp_alert() -> void:
	if _low_hp_vignette:
		return
	
	# Red Pulsing Perimeter Border Vignette
	_low_hp_vignette = Panel.new()
	_low_hp_vignette.name = "LowHPVignette"
	_low_hp_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_low_hp_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var v_style := StyleBoxFlat.new()
	v_style.draw_center = false
	v_style.border_width_left = 32
	v_style.border_width_right = 32
	v_style.border_width_top = 32
	v_style.border_width_bottom = 32
	v_style.border_color = Color(0.95, 0.15, 0.15, 0.85)
	_low_hp_vignette.add_theme_stylebox_override("panel", v_style)
	_low_hp_vignette.visible = false
	add_child(_low_hp_vignette)
	
	# Floating Warning Alert Banner
	_low_hp_alert_badge = PanelContainer.new()
	_low_hp_alert_badge.name = "LowHPAlertBadge"
	_low_hp_alert_badge.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_low_hp_alert_badge.custom_minimum_size = Vector2(400, 48)
	_low_hp_alert_badge.position = Vector2(440, 105)
	_low_hp_alert_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_low_hp_alert_badge.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("c0392b"), Color("e74c3c"), 0.06, 12))
	
	_low_hp_alert_label = Label.new()
	_low_hp_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_low_hp_alert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_low_hp_alert_label.label_settings = BrawlUITheme.make_label_settings(18, Color.WHITE, 6, 2)
	_low_hp_alert_label.text = "⚠️ CRITICAL HP! FIND A GETAWAY CAR!"
	_low_hp_alert_badge.add_child(_low_hp_alert_label)
	_low_hp_alert_badge.visible = false
	add_child(_low_hp_alert_badge)

func _process_low_hp_alert(delta: float, ratio: float, is_alive: bool) -> void:
	if not _low_hp_vignette:
		_setup_low_hp_alert()
	
	var is_critical: bool = is_alive and ratio <= 0.28
	if is_critical:
		_low_hp_pulse_timer += delta * 6.5
		var pulse: float = (sin(_low_hp_pulse_timer) + 1.0) * 0.5 # 0.0 to 1.0
		
		# Pulse vignette border alpha between 0.35 and 0.95
		_low_hp_vignette.visible = true
		_low_hp_vignette.modulate.a = lerpf(0.35, 0.95, pulse)
		
		# Pulse warning banner
		_low_hp_alert_badge.visible = true
		var s: float = lerpf(0.96, 1.05, pulse)
		_low_hp_alert_badge.scale = Vector2(s, s)
		
		# Periodic audio alert beep every 0.85s
		_low_hp_sound_timer -= delta
		if _low_hp_sound_timer <= 0.0:
			_low_hp_sound_timer = 0.85
			if has_node("/root/SoundFX"):
				var sfx = get_node("/root/SoundFX")
				if sfx.has_method("play_low_hp_alert"):
					sfx.play_low_hp_alert()
	else:
		if _low_hp_vignette and _low_hp_vignette.visible:
			_low_hp_vignette.visible = false
		if _low_hp_alert_badge and _low_hp_alert_badge.visible:
			_low_hp_alert_badge.visible = false
		_low_hp_sound_timer = 0.0

func set_wanted_stars(level: int) -> void:
	var new_level: int = clampi(level, 0, 5)
	if not stars_container:
		_current_stars = new_level
		return
	
	for i in range(stars_container.get_child_count()):
		var star_node := stars_container.get_child(i)
		if not star_node:
			continue
		
		var gold_tex: Texture2D = star_node.get_meta("gold_tex") as Texture2D if star_node.has_meta("gold_tex") else null
		var empty_tex: Texture2D = star_node.get_meta("empty_tex") as Texture2D if star_node.has_meta("empty_tex") else null
		
		if i < new_level:
			if star_node is TextureRect and gold_tex:
				star_node.texture = gold_tex
			
			if i >= _current_stars:
				# Star pop to 1.45x scale and flash bright gold
				star_node.pivot_offset = star_node.size * 0.5
				star_node.modulate = Color(1.0, 1.0, 0.4, 1.0)
				var tw := star_node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.parallel().tween_property(star_node, "scale", Vector2(1.45, 1.45), 0.16)
				tw.parallel().tween_property(star_node, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
				tw.chain().tween_property(star_node, "scale", Vector2.ONE, 0.14)
				
				if has_node("/root/SoundFX"):
					var sfx = get_node("/root/SoundFX")
					sfx.play_star_up()
			else:
				star_node.modulate = Color.WHITE
		else:
			if star_node is TextureRect and empty_tex:
				star_node.texture = empty_tex
			star_node.modulate = Color(0.7, 0.7, 0.7, 0.6)
			star_node.scale = Vector2.ONE
	
	_current_stars = new_level

# ==============================================================================
# SCORE & COMBO BADGE WITH TIMER DRAIN BAR
# ==============================================================================

func set_score(val: int) -> void:
	_score = val
	if score_label:
		score_label.text = "%06d" % _score

func add_score(amount: int) -> void:
	set_score(_score + amount)

func show_combo(multiplier: int, _bonus_points: int = 0) -> void:
	if not combo_badge or not combo_label:
		return
	
	combo_badge.visible = true
	combo_label.text = "🔥 x%d COMBO!" % multiplier
	
	# Shake and scale punch
	combo_badge.pivot_offset = combo_badge.size * 0.5
	var tw := combo_badge.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(combo_badge, "scale", Vector2(1.35, 1.35), 0.10)
	tw.chain().tween_property(combo_badge, "scale", Vector2.ONE, 0.12)
	
	if combo_drain_bar:
		combo_drain_bar.visible = true
		combo_drain_bar.value = 1.0

func hide_combo() -> void:
	if combo_badge:
		combo_badge.visible = false
	if combo_drain_bar:
		combo_drain_bar.visible = false

func _update_combo_drain() -> void:
	if not has_node("/root/WantedManager"):
		return
	var wm = get_node("/root/WantedManager")
	if wm.combo_timer > 0.0 and wm.combo_multiplier > 1:
		if combo_drain_bar:
			combo_drain_bar.visible = true
			combo_drain_bar.value = clampf(wm.combo_timer / 3.0, 0.0, 1.0)
	else:
		hide_combo()

# ==============================================================================
# 2. BOTTOM-CENTER ACTIVE GADGET HUD
# ==============================================================================

func _on_car_equipped(_car_id: String) -> void:
	_refresh_gadget_info()

func _refresh_gadget_info() -> void:
	if not gadget_icon or not gadget_name:
		return
	
	var car_id: String = "default_coupe"
	if target_car:
		if target_car.stats and not target_car.stats.car_id.is_empty():
			car_id = target_car.stats.car_id
		elif not target_car.car_id.is_empty():
			car_id = target_car.car_id
	elif is_inside_tree() and has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		car_id = sm.equipped_car_id
	
	var vdb = null
	if is_inside_tree():
		vdb = get_node_or_null("/root/VehicleDatabase")
	elif Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st and st.root:
			vdb = st.root.get_node_or_null("VehicleDatabase")
	if vdb and vdb.has_car(car_id):
		var info: Dictionary = vdb.get_car(car_id)
		var g_name: String = String(info.get("gadget_name", "NITRO BOOST"))
		gadget_name.text = g_name.to_upper()
		gadget_icon.text = _get_gadget_icon_for_id(String(info.get("gadget_id", "")))
		return
	
	match car_id:
		"cyber_interceptor":
			gadget_icon.text = "🌐"
			gadget_name.text = "CYBER DASH"
		"armored_bulldozer":
			gadget_icon.text = "🛡️"
			gadget_name.text = "TITAN PLOW"
		"ice_cream_drifter":
			gadget_icon.text = "❄️"
			gadget_name.text = "FREEZE TRAIL"
		"tuk_tuk_jet":
			gadget_icon.text = "🚀"
			gadget_name.text = "TURBO JET"
		"monster_pickup":
			gadget_icon.text = "💥"
			gadget_name.text = "EARTHQUAKE"
		"gold_limo":
			gadget_icon.text = "💰"
			gadget_name.text = "CASH MAGNET"
		"f1_street_kart":
			gadget_icon.text = "🏎️"
			gadget_name.text = "OVERDRIVE"
		_:
			gadget_icon.text = "⚡"
			gadget_name.text = "NITRO BOOST"

func _get_gadget_icon_for_id(gid: String) -> String:
	var g := gid.to_upper()
	if "DEFIB" in g or "HEAL" in g or "REPAIR" in g or "MEDKIT" in g:
		return "🩹"
	if "SIREN" in g or "POLICE" in g:
		return "🚨"
	if "LIGHT" in g or "FLASH" in g:
		return "💡"
	if "ROCKET" in g or "MISSILE" in g:
		return "🚀"
	if "LEAP" in g or "JUMP" in g or "HOP" in g or "BOUNCE" in g or "THRUSTER" in g:
		return "🦘"
	if "SLAM" in g or "RAM" in g or "STOMP" in g or "CRUSHER" in g or "BULL" in g:
		return "💥"
	if "BLIZZARD" in g or "ICE" in g or "FROST" in g:
		return "❄️"
	if "WARP" in g or "QUANTUM" in g or "PHASE" in g or "SINGULARITY" in g or "GRAVITON" in g:
		return "🌐"
	if "FLAME" in g or "FIRE" in g or "MOLTEN" in g or "DRAGON" in g or "ANTILAG" in g:
		return "🔥"
	if "CASH" in g or "COIN" in g or "VAULT" in g:
		return "💰"
	if "SAUCE" in g or "MUSTARD" in g or "SLIME" in g or "CHEESE" in g or "CEMENT" in g or "PAINT" in g:
		return "🎨"
	if "TRASH" in g or "CARDBOARD" in g or "BOULDER" in g or "LOG" in g or "ROADBLOCK" in g:
		return "📦"
	if "WATER" in g or "HOSE" in g or "TORPEDO" in g:
		return "🌊"
	if "GUN" in g or "TURRET" in g or "CANNON" in g or "SPIKE" in g:
		return "🎯"
	if "SMOKE" in g or "VEIL" in g or "DUST" in g or "SANDSTORM" in g:
		return "🌫️"
	if "CLOAK" in g or "STEALTH" in g:
		return "👻"
	if "ELECTRO" in g or "ZAP" in g or "EMP" in g:
		return "⚡"
	if "TURBO" in g or "V8" in g or "VTEC" in g or "BLOWER" in g or "KERS" in g or "MACH" in g or "SPEED" in g or "DRS" in g:
		return "🏎️"
	return "⚡"

func _update_gadget_cooldown(delta: float) -> void:
	var in_kart_mode: bool = has_node("/root/GameModeManager") and int(get_node("/root/GameModeManager").current_mode) == 3
	if gadget_container:
		gadget_container.visible = not in_kart_mode
	if in_kart_mode:
		return
	
	if target_car and is_instance_valid(target_car) and "gadget_system" in target_car and target_car.gadget_system:
		gadget_cooldown = target_car.gadget_system.cooldown
	elif gadget_cooldown > 0.0:
		gadget_cooldown = maxf(0.0, gadget_cooldown - delta)
	
	if gadget_cooldown > 0.0:
		if cooldown_overlay:
			cooldown_overlay.visible = true
		if cooldown_label:
			cooldown_label.text = "%.1fs" % gadget_cooldown
		if gadget_button:
			gadget_button.disabled = true
	else:
		if cooldown_overlay and cooldown_overlay.visible:
			cooldown_overlay.visible = false
			if gadget_button:
				gadget_button.disabled = false
				# Ready flash
				var tw := gadget_button.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(gadget_button, "scale", Vector2(1.15, 1.15), 0.12)
				tw.chain().tween_property(gadget_button, "scale", Vector2.ONE, 0.12)

func _on_gadget_button_pressed() -> void:
	if has_node("/root/GameModeManager") and int(get_node("/root/GameModeManager").current_mode) == 3:
		return
	if gadget_cooldown > 0.0:
		return
	
	if target_car and is_instance_valid(target_car) and "gadget_system" in target_car and target_car.gadget_system:
		target_car.gadget_system.activate_gadget()
		gadget_cooldown = target_car.gadget_system.cooldown
	else:
		gadget_cooldown = GADGET_MAX_COOLDOWN
		if target_car and is_instance_valid(target_car):
			target_car.activate_gadget()
	
	if cooldown_overlay:
		cooldown_overlay.visible = true
	if cooldown_label:
		cooldown_label.text = "%.1fs" % gadget_cooldown
	if gadget_button:
		gadget_button.disabled = true
	
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		sfx.play_drift_boost()

# ==============================================================================
# 3. 3D FLOATING COMBAT & SCORE POPUPS
# ==============================================================================

## Spawns a billboarded Label3D that pops upward and fades out over 0.75 seconds
func spawn_floating_text(world_pos: Vector3, text: String, color: Color, scale_mult: float = 1.0) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 48
	lbl.outline_size = 12
	lbl.outline_modulate = Color("0d1117")
	lbl.modulate = color
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.scale = Vector3.ONE * scale_mult
	lbl.position = world_pos + Vector3(0.0, 1.8, 0.0)
	
	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.add_child(lbl)
	elif get_tree() and get_tree().root:
		get_tree().root.add_child(lbl)
	else:
		add_child(lbl)
	
	var tw := lbl.create_tween()
	tw.parallel().tween_property(lbl, "position:y", lbl.position.y + 2.4, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "scale", Vector3.ONE * (scale_mult * 1.35), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.75).set_ease(Tween.EASE_IN)
	tw.tween_callback(lbl.queue_free)

# ==============================================================================
# TOUCH & STEERING PROCESSOR
# ==============================================================================

func _process_steering_input() -> void:
	if _is_modal_open():
		steer_input = 0.0
		is_reversing = false
		_zone_left_held = false
		_zone_right_held = false
		_zone_reverse_held = false
		_touches.clear()
		if target_car and is_instance_valid(target_car):
			target_car.steer_input = 0.0
			target_car.is_reversing = false
		if left_indicator: left_indicator.visible = false
		if right_indicator: right_indicator.visible = false
		return
	
	var left_held: bool = _zone_left_held or ("left" in _touches.values())
	var right_held: bool = _zone_right_held or ("right" in _touches.values())
	var reverse_held: bool = _zone_reverse_held
	
	# Desktop mouse fallback (clicks below top bar Y > 150)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mpos: Vector2 = get_viewport().get_mouse_position()
		var v_size: Vector2 = get_viewport().get_visible_rect().size
		if mpos.y > 150.0 and mpos.x >= 0.0 and mpos.x <= v_size.x and mpos.y <= v_size.y:
			# If not hovering gadget button
			if mpos.y < (v_size.y - 220.0) or absf(mpos.x - v_size.x * 0.5) > 90.0:
				if mpos.x < v_size.x * 0.5:
					left_held = true
				else:
					right_held = true
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		reverse_held = true
	
	# Desktop keyboard fallback
	var kb_steer: float = Input.get_axis("steer_left", "steer_right")
	var kb_reverse: bool = Input.is_action_pressed("reverse_brake")
	if kb_steer < -0.1:
		left_held = true
	elif kb_steer > 0.1:
		right_held = true
	if kb_reverse:
		reverse_held = true
	
	# Steering & Reversing Resolution
	if (left_held and right_held) or reverse_held:
		steer_input = 0.0
		is_reversing = true
	elif left_held:
		steer_input = -1.0
		is_reversing = false
	elif right_held:
		steer_input = 1.0
		is_reversing = false
	else:
		steer_input = 0.0
		is_reversing = false
	
	if left_indicator:
		left_indicator.visible = (left_held or is_reversing)
	if right_indicator:
		right_indicator.visible = (right_held or is_reversing)
	
	if target_car and is_instance_valid(target_car):
		var has_auth: bool = target_car.has_local_authority() if target_car.has_method("has_local_authority") else true
		if has_auth and not target_car.is_ai_rival and not target_car.is_abandoned and target_car.input_enabled:
			target_car.steer_input = steer_input
			target_car.is_reversing = is_reversing
	
	# Route car-like A/D steering & reversing to runner when on foot
	var runners := get_tree().get_nodes_in_group("player_character")
	for r in runners:
		if is_instance_valid(r) and not r.is_queued_for_deletion() and "steer_input" in r:
			r.steer_input = steer_input
			r.is_reversing = is_reversing
	
	steer_changed.emit(steer_input)
	reverse_changed.emit(is_reversing)

func _on_left_touch_gui_input(event: InputEvent) -> void:
	if _is_modal_open():
		_zone_left_held = false
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_zone_left_held = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_zone_reverse_held = event.pressed
	elif event is InputEventScreenTouch:
		_zone_left_held = event.pressed

func _on_right_touch_gui_input(event: InputEvent) -> void:
	if _is_modal_open():
		_zone_right_held = false
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_zone_right_held = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_zone_reverse_held = event.pressed
	elif event is InputEventScreenTouch:
		_zone_right_held = event.pressed

func _input(event: InputEvent) -> void:
	if _is_modal_open():
		_touches.clear()
		_zone_left_held = false
		_zone_right_held = false
		_zone_reverse_held = false
		return
	
	var v_width: float = get_viewport().get_visible_rect().size.x
	if event is InputEventScreenTouch:
		if event.pressed:
			var zone: String = "left" if event.position.x < v_width * 0.5 else "right"
			_touches[event.index] = zone
		else:
			_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		var zone: String = "left" if event.position.x < v_width * 0.5 else "right"
		_touches[event.index] = zone

func _is_modal_open() -> bool:
	if multiplayer_lobby and multiplayer_lobby.visible:
		return true
	if run_summary_panel and run_summary_panel.visible:
		return true
	if leaderboard_panel and leaderboard_panel.visible:
		return true
	if garage_panel and garage_panel.visible:
		return true
	return false

func _apply_safe_area() -> void:
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()
	
	var margin_left: int = 28
	var margin_top: int = 28
	var margin_right: int = 28
	var margin_bottom: int = 28
	
	if window_size.x > 0 and window_size.y > 0 and safe_area.size.x > 0:
		margin_left = maxi(safe_area.position.x, 28)
		margin_top = maxi(safe_area.position.y, 28)
		margin_right = maxi(window_size.x - safe_area.end.x, 28)
		margin_bottom = maxi(window_size.y - safe_area.end.y, 28)
	
	if safe_margin_container:
		safe_margin_container.add_theme_constant_override("margin_left", margin_left)
		safe_margin_container.add_theme_constant_override("margin_top", margin_top)
		safe_margin_container.add_theme_constant_override("margin_right", margin_right)
		safe_margin_container.add_theme_constant_override("margin_bottom", margin_bottom)

# ==============================================================================
# MODE OBJECTIVE & LOOT POINTER
# ==============================================================================

func _update_loot_pointer() -> void:
	var target_world_pos: Vector3 = Vector3.ZERO
	var has_target: bool = false
	var banner_override: String = ""
	
	# Hot Loot Mode
	var hot_loot := get_tree().root.find_child("HotLootMode", true, false)
	if hot_loot and hot_loot.is_hot_loot_mode and hot_loot.loot_holder_car and is_instance_valid(hot_loot.loot_holder_car):
		var holder: Node3D = hot_loot.loot_holder_car
		var is_me: bool = (target_car != null and target_car == holder)
		if is_me:
			if loot_pointer: loot_pointer.visible = false
			if loot_banner:
				loot_banner.visible = true
				loot_banner.text = "👑 YOU HOLD THE HOT LOOT! (+100 PTS/SEC)"
			return
		else:
			var hname: String = holder.driver_name if "driver_name" in holder else holder.name
			banner_override = "🔥 DRIFT & RAM %s TO STEAL LOOT!" % hname
			target_world_pos = holder.car_pivot.global_position if ("car_pivot" in holder and holder.car_pivot) else holder.global_position
			has_target = true
	
	# On-Foot Getaway: Point towards closest drivable car (NPC, Police, or Abandoned)
	if not has_target:
		var runners := get_tree().get_nodes_in_group("player_character")
		for r in runners:
			if is_instance_valid(r) and not r.is_queued_for_deletion():
				var runner := r as PlayerCharacter
				var nearest_veh = runner.get_nearest_vehicle() if runner.has_method("get_nearest_vehicle") else null
				if nearest_veh and is_instance_valid(nearest_veh):
					var vpos: Vector3 = nearest_veh.global_position
					if nearest_veh is PoliceCar and (nearest_veh as PoliceCar).physics_sphere:
						vpos = (nearest_veh as PoliceCar).physics_sphere.global_position
					elif nearest_veh is ArcadeCar and (nearest_veh as ArcadeCar).car_pivot:
						vpos = (nearest_veh as ArcadeCar).car_pivot.global_position
					target_world_pos = vpos
					has_target = true
					var vname := "VEHICLE"
					if nearest_veh is PoliceCar:
						vname = "POLICE CRUISER"
					elif nearest_veh is NPCTrafficCar:
						var npc := nearest_veh as NPCTrafficCar
						if not npc.car_id.is_empty():
							var vdb = get_node_or_null("/root/VehicleDatabase")
							if vdb and vdb.has_car(npc.car_id):
								vname = String(vdb.get_car(npc.car_id).get("name", "CIVILIAN CAR"))
							else:
								vname = npc.car_id.replace("_", " ").to_upper()
						else:
							vname = "CIVILIAN CAR"
					elif nearest_veh is ArcadeCar:
						var ac := nearest_veh as ArcadeCar
						if not ac.car_id.is_empty():
							var vdb = get_node_or_null("/root/VehicleDatabase")
							if vdb and vdb.has_car(ac.car_id):
								vname = String(vdb.get_car(ac.car_id).get("name", "GETAWAY CAR"))
							else:
								vname = ac.car_id.replace("_", " ").to_upper()
						else:
							vname = "GETAWAY CAR"
					var dist: int = int(runner.global_position.distance_to(vpos))
					banner_override = "🚗 NEAREST %s [%dm] ➔ HIJACK RIDE!" % [vname, dist]
				break
	
	if not has_target:
		if loot_pointer: loot_pointer.visible = false
		if loot_banner and not _mode_objective_active: loot_banner.visible = false
		return
	
	if loot_banner and not banner_override.is_empty():
		loot_banner.visible = true
		loot_banner.text = banner_override
	
	var cam := get_viewport().get_camera_3d()
	if not cam or not loot_pointer:
		return
	
	var is_behind: bool = cam.is_position_behind(target_world_pos)
	var screen_pos: Vector2 = cam.unproject_position(target_world_pos)
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var edge_pad: float = 60.0
	var is_offscreen: bool = is_behind or screen_pos.x < edge_pad or screen_pos.x > (vp_size.x - edge_pad) or screen_pos.y < edge_pad or screen_pos.y > (vp_size.y - edge_pad)
	
	if is_offscreen:
		loot_pointer.visible = true
		var center := vp_size * 0.5
		var dir := -(screen_pos - center) if is_behind else (screen_pos - center)
		if dir.is_zero_approx():
			dir = Vector2.UP
		dir = dir.normalized()
		
		var bounds_min := Vector2(edge_pad, edge_pad)
		var bounds_max := vp_size - Vector2(edge_pad, edge_pad)
		var t_x: float = (bounds_max.x - center.x) / dir.x if dir.x > 0.0 else ((bounds_min.x - center.x) / dir.x if dir.x < 0.0 else 999999.0)
		var t_y: float = (bounds_max.y - center.y) / dir.y if dir.y > 0.0 else ((bounds_min.y - center.y) / dir.y if dir.y < 0.0 else 999999.0)
		var t: float = minf(t_x, t_y)
		loot_pointer.position = center + dir * t
		loot_pointer.rotation = dir.angle() + PI * 0.5
	else:
		loot_pointer.visible = false

# ==============================================================================
# POWERUPS, BOSS HUD & BIOME BANNERS
# ==============================================================================

func _on_car_powerup_applied(type: int, duration: float) -> void:
	var p_names: Array[String] = ["⚡ NITRO OVERDRIVE!", "💥 EMP SHOCKWAVE!", "🛢️ OIL SLICK DROPPER!", "🛡️ TITAN SHIELD!"]
	var p_colors: Array[Color] = [Color("00d2d3"), Color("3498db"), Color("e67e22"), Color("f1c40f")]
	if type >= 0 and type < p_names.size():
		show_powerup_banner(p_names[type], p_colors[type], duration)

func show_powerup_banner(p_name: String, p_color: Color, duration: float = 6.0) -> void:
	if not _powerup_panel:
		var vbox: VBoxContainer = $SafeMarginContainer/VBoxContainer as VBoxContainer
		_powerup_panel = PanelContainer.new()
		_powerup_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("1e272e"), p_color, 0.04, 16))
		_powerup_label = Label.new()
		_powerup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_powerup_label.label_settings = BrawlUITheme.make_label_settings(24, p_color, 8, 3)
		_powerup_panel.add_child(_powerup_label)
		vbox.add_child(_powerup_panel)
	
	_powerup_panel.visible = true
	_powerup_label.text = p_name
	_powerup_timer = duration

func set_boss_health(b_name: String, current_hp: float, max_hp: float) -> void:
	if not _boss_panel:
		var vbox: VBoxContainer = $SafeMarginContainer/VBoxContainer as VBoxContainer
		_boss_panel = PanelContainer.new()
		_boss_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("120508"), Color("e74c3c"), 0.04, 14))
		
		var bv := VBoxContainer.new()
		bv.add_theme_constant_override("separation", 6)
		_boss_panel.add_child(bv)
		
		_boss_name_label = Label.new()
		_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_boss_name_label.label_settings = BrawlUITheme.make_label_settings(20, Color("ff7675"), 6, 2)
		bv.add_child(_boss_name_label)
		
		_boss_hp_bar = ProgressBar.new()
		_boss_hp_bar.custom_minimum_size = Vector2(280, 18)
		var fill_sb := StyleBoxFlat.new()
		fill_sb.bg_color = Color("e74c3c")
		fill_sb.set_corner_radius_all(6)
		_boss_hp_bar.add_theme_stylebox_override("fill", fill_sb)
		bv.add_child(_boss_hp_bar)
		vbox.add_child(_boss_panel)
	
	_boss_panel.visible = true
	_boss_name_label.text = "⚠️ %s" % b_name.to_upper()
	_boss_hp_bar.max_value = max_hp
	_boss_hp_bar.value = current_hp

func hide_boss_health() -> void:
	if _boss_panel:
		_boss_panel.visible = false

func show_biome_banner(biome_title: String) -> void:
	if loot_banner:
		loot_banner.text = "🌆 ENTERING: %s" % biome_title.to_upper()
		loot_banner.visible = true
		get_tree().create_timer(3.0, true, false, true).timeout.connect(func():
			if is_instance_valid(loot_banner) and loot_banner.text.begins_with("🌆 ENTERING:"):
				loot_banner.visible = false
		)

# ==============================================================================
# PHASE 12: SLIDE-DOWN DAILY QUEST TOAST BANNER
# ==============================================================================

var _quest_toast_panel: PanelContainer = null
var _quest_toast_label: Label = null
var _quest_toast_tween: Tween = null

func show_quest_toast(msg: String) -> void:
	if not _quest_toast_panel:
		_quest_toast_panel = PanelContainer.new()
		_quest_toast_panel.name = "QuestToastPanel"
		_quest_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_quest_toast_panel.custom_minimum_size = Vector2(720, 80)
		_quest_toast_panel.position = Vector2(180, -120)
		_quest_toast_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("16a085"), Color("0d1117"), 0.05, 18))
		
		_quest_toast_label = Label.new()
		_quest_toast_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_quest_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_quest_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_quest_toast_label.label_settings = BrawlUITheme.make_label_settings(24, Color.WHITE, 8, 3)
		_quest_toast_panel.add_child(_quest_toast_label)
		add_child(_quest_toast_panel)
	
	_quest_toast_label.text = msg
	_quest_toast_panel.visible = true
	
	if _quest_toast_tween and _quest_toast_tween.is_valid():
		_quest_toast_tween.kill()
	
	_quest_toast_panel.position.y = -120.0
	_quest_toast_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_quest_toast_tween.tween_property(_quest_toast_panel, "position:y", 60.0, 0.35)
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_star_up()
	
	_quest_toast_tween.tween_interval(2.4)
	_quest_toast_tween.chain().tween_property(_quest_toast_panel, "position:y", -120.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_quest_toast_tween.tween_callback(func():
		if is_instance_valid(_quest_toast_panel):
			_quest_toast_panel.visible = false
	)

func _on_pause_button_pressed() -> void:
	if pause_menu_modal:
		pause_menu_modal.open_pause_menu()

# ==============================================================================
# MOBILE VEHICLE ACTION BUTTON (ENTER CAR / JUMP OUT)
# ==============================================================================

func _setup_mobile_vehicle_button() -> void:
	if action_vehicle_button:
		return
	action_vehicle_button = Button.new()
	action_vehicle_button.name = "ActionVehicleButton"
	action_vehicle_button.custom_minimum_size = Vector2(240, 80)
	action_vehicle_button.text = "🚗 ENTER CAR"
	action_vehicle_button.focus_mode = Control.FOCUS_NONE
	
	action_vehicle_button.anchor_left = 0.5
	action_vehicle_button.anchor_top = 1.0
	action_vehicle_button.anchor_right = 0.5
	action_vehicle_button.anchor_bottom = 1.0
	action_vehicle_button.offset_left = -120.0
	action_vehicle_button.offset_top = -150.0
	action_vehicle_button.offset_right = 120.0
	action_vehicle_button.offset_bottom = -70.0
	action_vehicle_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	action_vehicle_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	BrawlUITheme.attach_button_juice(action_vehicle_button, Color("f1c40f"))
	action_vehicle_button.pressed.connect(_on_action_vehicle_button_pressed)
	add_child(action_vehicle_button)

func _update_mobile_vehicle_button() -> void:
	if not action_vehicle_button:
		return
	
	var runners := get_tree().get_nodes_in_group("player_character")
	var on_foot_runner: PlayerCharacter = null
	for r in runners:
		if is_instance_valid(r) and not r.is_queued_for_deletion():
			on_foot_runner = r as PlayerCharacter
			break
	
	if on_foot_runner:
		action_vehicle_button.visible = true
		var nearby = on_foot_runner.get_nearby_vehicle() if on_foot_runner.has_method("get_nearby_vehicle") else null
		if nearby and is_instance_valid(nearby):
			if nearby is PoliceCar:
				var pc := nearby as PoliceCar
				if pc.officers_inside > 0:
					action_vehicle_button.text = "⛔ %d POLICE INSIDE" % pc.officers_inside
					action_vehicle_button.modulate = Color("ff4757")
					action_vehicle_button.disabled = true
				else:
					action_vehicle_button.text = "⚡ DRIVE EMPTY POLICE"
					action_vehicle_button.modulate = Color("2ecc71")
					action_vehicle_button.disabled = false
			elif nearby is NPCTrafficCar:
				action_vehicle_button.disabled = false
				var npc := nearby as NPCTrafficCar
				var vname := "CIVILIAN CAR"
				if not npc.car_id.is_empty():
					var vdb = get_node_or_null("/root/VehicleDatabase")
					if vdb and vdb.has_car(npc.car_id):
						vname = String(vdb.get_car(npc.car_id).get("name", "VEHICLE"))
					else:
						vname = npc.car_id.replace("_", " ").to_upper()
				action_vehicle_button.text = "⚡ HIJACK %s" % vname
				action_vehicle_button.modulate = Color(1.2, 1.2, 1.0)
			else:
				action_vehicle_button.disabled = false
				action_vehicle_button.text = "🚗 ENTER CAR"
				action_vehicle_button.modulate = Color(1.2, 1.2, 1.0)
		else:
			action_vehicle_button.disabled = false
			action_vehicle_button.text = "🚗 ENTER CAR"
			action_vehicle_button.modulate = Color(1.0, 1.0, 1.0, 0.85)
	else:
		var active_car: ArcadeCar = target_car if (target_car and is_instance_valid(target_car) and not target_car.is_abandoned) else null
		if not active_car:
			var cars := get_tree().get_nodes_in_group("player_vehicles")
			for c in cars:
				if is_instance_valid(c) and c is ArcadeCar and not (c as ArcadeCar).is_abandoned:
					active_car = c as ArcadeCar
					target_car = active_car
					break
		if active_car and active_car.input_enabled:
			action_vehicle_button.visible = true
			action_vehicle_button.text = "🏃 JUMP OUT [SPACE/F]"
			action_vehicle_button.modulate = Color(1.0, 0.5, 0.5, 0.95)
		else:
			action_vehicle_button.visible = false
	
	# Update Tank Rocket button
	if tank_rocket_button:
		var show_rocket: bool = target_car and is_instance_valid(target_car) and not target_car.is_abandoned and target_car.has_method("is_tank") and target_car.is_tank()
		tank_rocket_button.visible = show_rocket
		if show_rocket:
			var cooldown: float = target_car.tank_rocket_cooldown if "tank_rocket_cooldown" in target_car else 0.0
			if cooldown > 0.0:
				tank_rocket_button.text = "🚀 RELOAD (%.1fs)" % cooldown
				tank_rocket_button.disabled = true
			else:
				tank_rocket_button.text = "🚀 FIRE ROCKET"
				tank_rocket_button.disabled = false

func _setup_tank_rocket_button() -> void:
	if tank_rocket_button:
		return
	tank_rocket_button = Button.new()
	tank_rocket_button.name = "TankRocketButton"
	tank_rocket_button.custom_minimum_size = Vector2(200, 80)
	tank_rocket_button.text = "🚀 FIRE ROCKET"
	tank_rocket_button.focus_mode = Control.FOCUS_NONE
	
	tank_rocket_button.anchor_left = 1.0
	tank_rocket_button.anchor_top = 1.0
	tank_rocket_button.anchor_right = 1.0
	tank_rocket_button.anchor_bottom = 1.0
	tank_rocket_button.offset_left = -230.0
	tank_rocket_button.offset_top = -260.0
	tank_rocket_button.offset_right = -30.0
	tank_rocket_button.offset_bottom = -180.0
	tank_rocket_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tank_rocket_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tank_rocket_button.visible = false
	
	BrawlUITheme.attach_button_juice(tank_rocket_button, Color("ff4757"))
	tank_rocket_button.pressed.connect(_on_tank_rocket_button_pressed)
	add_child(tank_rocket_button)

func _on_tank_rocket_button_pressed() -> void:
	if target_car and is_instance_valid(target_car) and target_car.has_method("fire_tank_rocket"):
		target_car.fire_tank_rocket()

func _on_action_vehicle_button_pressed() -> void:
	var runners := get_tree().get_nodes_in_group("player_character")
	for r in runners:
		if is_instance_valid(r) and not r.is_queued_for_deletion() and r is PlayerCharacter:
			(r as PlayerCharacter).hijack_nearby()
			return
	
	var active_car: ArcadeCar = target_car if (target_car and is_instance_valid(target_car) and not target_car.is_abandoned) else null
	if not active_car:
		var cars := get_tree().get_nodes_in_group("player_vehicles")
		for c in cars:
			if is_instance_valid(c) and c is ArcadeCar and not (c as ArcadeCar).is_abandoned:
				active_car = c as ArcadeCar
				target_car = active_car
				break
	if active_car and active_car.input_enabled:
		active_car.eject_player_character()

