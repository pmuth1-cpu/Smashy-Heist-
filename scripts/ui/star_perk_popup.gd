class_name StarPerkPopup
extends Control

## Mid-Run Roguelike Star-Up Perk Cards Modal.
## Displays 2 large tactile Brawl Stars Perk Cards when Wanted Stars level up (2★..5★).
## Pauses the game and requires the player to choose an upgrade for the rest of the run.

signal perk_selected(perk_id: String)

const ALL_PERKS: Array[Dictionary] = [
	{
		"id": "NITRO_DRIFT",
		"title": "🔥 NITRO DRIFT",
		"desc": "Drift Boost +40% charge & +1.0s duration",
		"color": Color("e67e22"),
		"texture_path": "res://assets/textures/perks/perk_nitro_drift.jpg"
	},
	{
		"id": "EXPLOSIVE_BUMPER",
		"title": "💥 EXPLOSIVE BUMPER",
		"desc": "Ram explosions & -50% collision damage",
		"color": Color("e74c3c"),
		"texture_path": "res://assets/textures/perks/perk_explosive_bumper.jpg"
	},
	{
		"id": "MEGA_MAGNET",
		"title": "🧲 MEGA MAGNET",
		"desc": "16m item pull radius + 50 HP repair",
		"color": Color("9b59b6"),
		"texture_path": "res://assets/textures/perks/perk_mega_magnet.jpg"
	},
	{
		"id": "OVERCLOCKED_GADGET",
		"title": "⚡ OVERCLOCKED GADGET",
		"desc": "-35% roof weapon cooldown",
		"color": Color("00d2d3"),
		"texture_path": "res://assets/textures/perks/perk_overclocked_gadget.jpg"
	},
	{
		"id": "SPIKED_FENDERS",
		"title": "🛡️ SPIKED FENDERS",
		"desc": "+3.6s busted timer & spike ram damage",
		"color": Color("2ecc71"),
		"texture_path": "res://assets/textures/perks/perk_spiked_fenders.jpg"
	}
]

var is_showing: bool = false
var _current_options: Array[Dictionary] = []

# Roguelike Star-Up Smooth Slow-Motion System
var _is_transitioning_time: bool = false
var _time_start: float = 1.0
var _time_target: float = 1.0
var _time_duration: float = 0.25
var _time_elapsed: float = 0.0

@onready var header_label: Label = $HeaderBox/HeaderLabel
@onready var subheader_label: Label = $HeaderBox/SubheaderLabel
@onready var card_container: HBoxContainer = $CardContainer

@onready var card_left: Button = $CardContainer/CardLeft
@onready var art_left: TextureRect = $CardContainer/CardLeft/VBox/ArtContainer/PerkArt
@onready var title_left: Label = $CardContainer/CardLeft/VBox/TitleLabel
@onready var desc_left: Label = $CardContainer/CardLeft/VBox/DescLabel

@onready var card_right: Button = $CardContainer/CardRight
@onready var art_right: TextureRect = $CardContainer/CardRight/VBox/ArtContainer/PerkArt
@onready var title_right: Label = $CardContainer/CardRight/VBox/TitleLabel
@onready var desc_right: Label = $CardContainer/CardRight/VBox/DescLabel

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if card_left:
		card_left.pressed.connect(func(): _select_perk(0))
	if card_right:
		card_right.pressed.connect(func(): _select_perk(1))
	
	_style_components()

func _exit_tree() -> void:
	# Ensure game speed is completely restored if node leaves tree
	Engine.time_scale = 1.0

func _process(delta: float) -> void:
	if _is_transitioning_time:
		var cur_ts: float = maxf(0.001, Engine.time_scale)
		var real_dt: float = delta / cur_ts
		_time_elapsed += real_dt
		var progress: float = clampf(_time_elapsed / _time_duration, 0.0, 1.0)
		var t_eased: float = sin(progress * PI * 0.5) if _time_target < _time_start else (1.0 - cos(progress * PI * 0.5))
		Engine.time_scale = lerpf(_time_start, _time_target, t_eased)
		if progress >= 1.0:
			Engine.time_scale = _time_target
			_is_transitioning_time = false

func transition_time_scale(target_scale: float, real_duration: float = 0.25) -> void:
	_time_start = Engine.time_scale
	_time_target = target_scale
	_time_duration = maxf(0.01, real_duration)
	_time_elapsed = 0.0
	_is_transitioning_time = true

func _style_components() -> void:
	if not has_node("/root/BrawlUITheme"):
		return
	var theme = get_node("/root/BrawlUITheme")
	
	if header_label and theme.has_method("make_label_settings"):
		header_label.label_settings = theme.make_label_settings(34, Color("f1c40f"), 10, 4)
	if subheader_label and theme.has_method("make_label_settings"):
		subheader_label.label_settings = theme.make_label_settings(18, Color("00d2d3"), 6, 2)
	
	if title_left and theme.has_method("make_label_settings"):
		title_left.label_settings = theme.make_label_settings(24, Color.WHITE, 8, 3)
	if title_right and theme.has_method("make_label_settings"):
		title_right.label_settings = theme.make_label_settings(24, Color.WHITE, 8, 3)
	
	if desc_left and theme.has_method("make_label_settings"):
		desc_left.label_settings = theme.make_label_settings(16, Color("dfe6e9"), 4, 1)
	if desc_right and theme.has_method("make_label_settings"):
		desc_right.label_settings = theme.make_label_settings(16, Color("dfe6e9"), 4, 1)

## Displays 2 random distinct large perk cards and pauses gameplay until player chooses
func show_star_perks(star_level: int) -> void:
	if is_showing:
		return
	is_showing = true
	visible = true
	
	# Smoothly decelerate into cinematic Roguelike slow-motion (0.12x speed)
	transition_time_scale(0.12, 0.25)
	
	# Camera punch on star-up
	var cam_rig = get_tree().root.find_child("CameraRig", true, false)
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.35)
	
	if header_label:
		header_label.text = "⭐ %d-STAR ROGUELIKE UPGRADE! ⭐" % star_level
	if subheader_label:
		subheader_label.text = "CHOOSE 1 PERK TO UPGRADE YOUR GETAWAY RUN"
	
	# Reset card transforms
	if card_left:
		card_left.scale = Vector2.ONE
		card_left.modulate.a = 1.0
	if card_right:
		card_right.scale = Vector2.ONE
		card_right.modulate.a = 1.0
	
	# Pick 2 distinct perks
	var shuffled := ALL_PERKS.duplicate()
	shuffled.shuffle()
	_current_options = [shuffled[0], shuffled[1]]
	
	_populate_card(card_left, art_left, title_left, desc_left, _current_options[0])
	_populate_card(card_right, art_right, title_right, desc_right, _current_options[1])
	
	# Slide-in animation from bottom
	modulate = Color(1, 1, 1, 0)
	position.y = 80.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.25)
	tw.tween_property(self, "position:y", 0.0, 0.25)
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_star_up()

func _make_rectangular_card_style(accent_color: Color, is_hover: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	# 100% solid opacity (no transparency)
	sb.bg_color = Color("0a121e") if not is_hover else Color("142236")
	sb.border_color = accent_color
	sb.border_width_left = 4
	sb.border_width_top = 4
	sb.border_width_right = 4
	sb.border_width_bottom = 8 # Arcade solid bottom edge
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0.0, 6.0)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 16.0
	return sb

func _populate_card(card_btn: Button, art_rect: TextureRect, title_lbl: Label, desc_lbl: Label, perk_data: Dictionary) -> void:
	if not card_btn:
		return
	
	if title_lbl:
		title_lbl.text = String(perk_data["title"])
	if desc_lbl:
		desc_lbl.text = String(perk_data["desc"])
	
	# Load Generated Perk Art
	var tex_path: String = String(perk_data.get("texture_path", ""))
	if art_rect and not tex_path.is_empty():
		var tex: Texture2D = null
		if has_node("/root/BrawlUITheme"):
			var theme = get_node("/root/BrawlUITheme")
			if theme.has_method("load_texture_safe"):
				tex = theme.load_texture_safe(tex_path)
		if not tex and ResourceLoader.exists(tex_path):
			tex = load(tex_path) as Texture2D
		
		if tex:
			art_rect.texture = tex
			art_rect.visible = true
		else:
			art_rect.visible = false
	
	var col: Color = perk_data["color"] as Color
	var normal_sb := _make_rectangular_card_style(col, false)
	var hover_sb := _make_rectangular_card_style(col, true)
	if has_node("/root/BrawlUITheme"):
		var theme = get_node("/root/BrawlUITheme")
		if theme.has_method("attach_button_juice"):
			theme.attach_button_juice(card_btn, col)
	
	card_btn.add_theme_stylebox_override("normal", normal_sb)
	card_btn.add_theme_stylebox_override("hover", hover_sb)
	card_btn.add_theme_stylebox_override("pressed", hover_sb)
	card_btn.add_theme_stylebox_override("focus", normal_sb)

func _select_perk(index: int) -> void:
	if not is_showing:
		return
	is_showing = false
	
	var perk_data: Dictionary = _current_options[clampi(index, 0, _current_options.size() - 1)]
	var perk_id: String = String(perk_data["id"])
	
	# Apply perk to WantedManager
	var wm: Node = get_node_or_null("/root/WantedManager")
	if not wm and get_tree() and get_tree().root:
		wm = get_tree().root.get_node_or_null("WantedManager")
	if wm and wm.has_method("apply_perk"):
		wm.apply_perk(perk_id)
	
	# Tactile feedback: animate the chosen card with a juicy scale pop and fade out the other
	var selected_card: Button = card_left if index == 0 else card_right
	var other_card: Button = card_right if index == 0 else card_left
	if selected_card:
		selected_card.pivot_offset = selected_card.size * 0.5
		var c_tw := selected_card.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		c_tw.tween_property(selected_card, "scale", Vector2(1.08, 1.08), 0.15)
	if other_card:
		var o_tw := other_card.create_tween()
		o_tw.tween_property(other_card, "modulate:a", 0.25, 0.15)
	
	# Smoothly accelerate game speed back to normal (1.0x) over 0.35s
	transition_time_scale(1.0, 0.35)
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_drift_boost()
	
	# Spawn Floating Notification
	var hud := get_tree().root.find_child("TouchHUD", true, false)
	if hud and hud.has_method("spawn_floating_text"):
		var cam = get_viewport().get_camera_3d()
		var spawn_pos: Vector3 = (cam.global_position - cam.global_transform.basis.z * 5.0) if cam else Vector3.ZERO
		hud.spawn_floating_text(spawn_pos, "UPGRADE: " + String(perk_data["title"]) + "!", Color("f1c40f"), 1.4)
	
	perk_selected.emit(perk_id)
	
	# Slide out and hide
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_property(self, "position:y", 120.0, 0.2)
	tw.chain().tween_callback(func():
		visible = false
	)
