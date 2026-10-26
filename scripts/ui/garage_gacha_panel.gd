class_name GarageGachaPanel
extends Control

## Garage & Gacha Panel for Smashy Heist: Daily Getaway.
## Handles vehicle viewing, stats preview, equipping, and gacha lottery rolls.

signal panel_closed()

const CAR_DEFINITIONS: Array[Dictionary] = [
	{
		"id": "default_coupe",
		"name": "Classic Coupe",
		"rarity": "COMMON",
		"rarity_color": Color(0.75, 0.75, 0.75, 1.0),
		"weight": 40,
		"resource_path": "res://resources/vehicles/default_coupe.tres"
	},
	{
		"id": "tuk_tuk_jet",
		"name": "Tuk-Tuk Rocket",
		"rarity": "RARE",
		"rarity_color": Color(0.2, 0.7, 1.0, 1.0),
		"weight": 25,
		"resource_path": "res://resources/vehicles/tuk_tuk_jet.tres"
	},
	{
		"id": "ice_cream_drifter",
		"name": "Ice Cream Drifter",
		"rarity": "RARE",
		"rarity_color": Color(0.25, 0.9, 0.7, 1.0),
		"weight": 20,
		"resource_path": "res://resources/vehicles/ice_cream_drifter.tres"
	},
	{
		"id": "armored_bulldozer",
		"name": "Armored Bulldozer",
		"rarity": "EPIC",
		"rarity_color": Color(0.85, 0.45, 1.0, 1.0),
		"weight": 10,
		"resource_path": "res://resources/vehicles/armored_bulldozer.tres"
	},
	{
		"id": "cyber_interceptor",
		"name": "Cyber Interceptor",
		"rarity": "LEGENDARY",
		"rarity_color": Color(1.0, 0.8, 0.1, 1.0),
		"weight": 5,
		"resource_path": "res://resources/vehicles/cyber_interceptor.tres"
	}
]

@onready var cash_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HeaderBox/CashLabel
@onready var streak_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HeaderBox/StreakLabel
@onready var close_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HeaderBox/CloseButton
@onready var cards_container: HBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/CardsContainer
@onready var spin_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/GachaSection/SpinButton
@onready var result_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/GachaSection/ResultLabel

var _is_spinning: bool = false
var _card_nodes: Dictionary = {}

func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if spin_button:
		spin_button.pressed.connect(_on_spin_pressed)
	
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.cash_changed.connect(_on_cash_changed)
		sm.car_unlocked.connect(_on_car_unlocked)
		sm.car_equipped.connect(_on_car_equipped)
	
	_build_car_cards()
	refresh_ui()

func refresh_ui() -> void:
	if not has_node("/root/SaveManager"):
		return
	var sm = get_node("/root/SaveManager")
	
	if cash_label:
		cash_label.text = "💵 %d CASH" % sm.total_cash
	if streak_label:
		streak_label.text = "🔥 %d DAY STREAK" % sm.daily_streak
	
	if spin_button and not _is_spinning:
		spin_button.disabled = (sm.total_cash < 100)
		spin_button.text = "🎰 SPIN GACHA (100 CASH)" if sm.total_cash >= 100 else "🎰 NEED 100 CASH TO SPIN"
	
	_update_card_buttons()

func _build_car_cards() -> void:
	if not cards_container:
		return
	
	for child in cards_container.get_children():
		child.queue_free()
	_card_nodes.clear()
	
	for car_def in CAR_DEFINITIONS:
		var card := _create_car_card(car_def)
		cards_container.add_child(card)
		_card_nodes[car_def["id"]] = card

func _create_car_card(car_def: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(175, 290)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.2, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = car_def["rarity_color"]
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	panel.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	# Rarity badge
	var rarity_lbl := Label.new()
	rarity_lbl.text = car_def["rarity"]
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_color_override("font_color", car_def["rarity_color"])
	rarity_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(rarity_lbl)
	
	# Name
	var name_lbl := Label.new()
	name_lbl.text = car_def["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_lbl)
	
	# Separator
	var hsep := HSeparator.new()
	vbox.add_child(hsep)
	
	# Stats
	var stats: CarStats = null
	if ResourceLoader.exists(car_def["resource_path"]):
		stats = load(car_def["resource_path"]) as CarStats
	
	if stats:
		vbox.add_child(_create_stat_row("Speed", stats.max_speed, 40.0, Color(0.2, 0.8, 1.0)))
		vbox.add_child(_create_stat_row("Accel", stats.acceleration, 60.0, Color(1.0, 0.7, 0.2)))
		vbox.add_child(_create_stat_row("Turn", stats.turn_speed, 6.0, Color(0.4, 1.0, 0.4)))
		vbox.add_child(_create_stat_row("Mass", stats.mass_weight, 6.0, Color(1.0, 0.4, 0.4)))
	
	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Equip Button
	var btn := Button.new()
	btn.name = "ActionBtn"
	btn.custom_minimum_size = Vector2(0, 36)
	btn.text = "EQUIP"
	btn.pressed.connect(_on_card_action_pressed.bind(car_def["id"]))
	vbox.add_child(btn)
	
	return panel

func _create_stat_row(stat_name: String, value: float, max_val: float, bar_color: Color) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	
	var label_box := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = stat_name
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_box.add_child(name_lbl)
	
	var val_lbl := Label.new()
	val_lbl.text = "%.1f" % value
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label_box.add_child(val_lbl)
	row.add_child(label_box)
	
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(0, 6)
	pb.max_value = max_val
	pb.value = value
	pb.show_percentage = false
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = bar_color
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_right = 3
	sb.corner_radius_bottom_left = 3
	pb.add_theme_stylebox_override("fill", sb)
	row.add_child(pb)
	
	return row

func _update_card_buttons() -> void:
	if not has_node("/root/SaveManager"):
		return
	var sm = get_node("/root/SaveManager")
	
	for car_id in _card_nodes:
		var panel: PanelContainer = _card_nodes[car_id]
		var btn: Button = panel.find_child("ActionBtn", true, false) as Button
		if not btn:
			continue
		
		var is_unlocked: bool = car_id in sm.unlocked_cars
		var is_equipped: bool = (sm.equipped_car_id == car_id)
		
		if is_equipped:
			btn.text = "EQUIPPED"
			btn.disabled = true
		elif is_unlocked:
			btn.text = "EQUIP"
			btn.disabled = _is_spinning
		else:
			btn.text = "LOCKED"
			btn.disabled = true

func _on_card_action_pressed(car_id: String) -> void:
	if _is_spinning:
		return
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.equip_car(car_id)
		if result_label:
			result_label.text = "Equipped %s!" % _get_car_name(car_id)
			result_label.modulate = Color(0.2, 1.0, 0.4)

func _on_spin_pressed() -> void:
	if _is_spinning or not has_node("/root/SaveManager"):
		return
	var sm = get_node("/root/SaveManager")
	if not sm.spend_cash(100):
		if result_label:
			result_label.text = "Not enough cash! Need 100 Cash."
			result_label.modulate = Color(1.0, 0.3, 0.3)
		return
	
	_is_spinning = true
	spin_button.disabled = true
	_update_card_buttons()
	
	# Weighted random roll
	var roll_car_id: String = _pick_weighted_car()
	
	# Spin animation over cards
	_animate_spin(roll_car_id)

func _pick_weighted_car() -> String:
	var total_weight: int = 0
	for c in CAR_DEFINITIONS:
		total_weight += int(c["weight"])
	
	var roll: int = randi() % total_weight
	var accum: int = 0
	for c in CAR_DEFINITIONS:
		accum += int(c["weight"])
		if roll < accum:
			return String(c["id"])
	return "default_coupe"

func _animate_spin(target_car_id: String) -> void:
	var cycle_count: int = 14
	var delay: float = 0.08
	
	for i in range(cycle_count):
		var highlight_id: String = CAR_DEFINITIONS[i % CAR_DEFINITIONS.size()]["id"]
		_highlight_card(highlight_id)
		if result_label:
			result_label.text = "🎰 Rolling... [%s]" % _get_car_name(highlight_id)
			result_label.modulate = Color(1.0, 0.9, 0.3)
		await get_tree().create_timer(delay).timeout
		delay += 0.008
	
	# Final landing on target_car_id
	_highlight_card(target_car_id)
	_is_spinning = false
	
	# Check unlock status
	var sm = get_node("/root/SaveManager")
	var car_name: String = _get_car_name(target_car_id)
	
	if target_car_id in sm.unlocked_cars:
		# Duplicate consolation
		sm.add_cash(50)
		if result_label:
			result_label.text = "Duplicate %s! +50 Cash consolation bonus!" % car_name
			result_label.modulate = Color(1.0, 0.8, 0.2)
	else:
		sm.unlock_car(target_car_id)
		if result_label:
			result_label.text = "🎉 UNLOCKED NEW CAR: %s!" % car_name
			result_label.modulate = Color(0.2, 1.0, 0.5)
	
	refresh_ui()

func _highlight_card(car_id: String) -> void:
	for id in _card_nodes:
		var panel: PanelContainer = _card_nodes[id]
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			if id == car_id:
				style.bg_color = Color(0.28, 0.35, 0.48, 1.0)
			else:
				style.bg_color = Color(0.12, 0.15, 0.2, 0.95)

func _get_car_name(car_id: String) -> String:
	for c in CAR_DEFINITIONS:
		if c["id"] == car_id:
			return String(c["name"])
	return car_id

func open_panel() -> void:
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.95, 0.95)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	refresh_ui()

func close_panel() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		visible = false
		panel_closed.emit()
	)

func _on_close_pressed() -> void:
	close_panel()

func _on_cash_changed(_new_amount: int) -> void:
	refresh_ui()

func _on_car_unlocked(_car_id: String) -> void:
	refresh_ui()

func _on_car_equipped(_car_id: String) -> void:
	refresh_ui()
