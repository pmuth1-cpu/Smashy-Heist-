class_name InventoryPanel
extends Control

## Phase 12: 3-Slot Visual Car Inventory & Gear Loadout
## Lets players inspect and equip 9 collectible gear items across 3 slots:
## - Slot 1: Weapon Mod (Rockets, EMP Dome, Magnet Dish)
## - Slot 2: Drift Trail & Underglow (Cyan, Gold Flame, Cyber Purple)
## - Slot 3: Chassis & Bumper Armor (Chrome, Spiked Ram, Titanium)

signal loadout_changed(slot_name: String, item_id: String)
signal closed()

const BrawlUITheme = preload("res://scripts/autoload/brawl_ui_theme.gd")
const SoundFX = preload("res://scripts/autoload/sound_fx.gd")

const SLOT_KEYS: Array[String] = ["weapon_mod", "drift_trail", "armor_mod"]
const SLOT_TITLES: Array[String] = ["🚀 ROOF WEAPONS", "✨ NEON & TRAILS", "🛡️ ARMOR & BUMPERS"]

const GEAR_DATA: Dictionary = {
	"weapon_mod": [
		{
			"id": "rockets_twin",
			"name": "TWIN REAR ROCKETS",
			"slot": "weapon_mod",
			"icon": "🚀",
			"stat": "Twin rocket pods mounted on roof.",
			"color": Color("e84118")
		},
		{
			"id": "emp_dome",
			"name": "PULSE EMP DOME",
			"slot": "weapon_mod",
			"icon": "⚡",
			"stat": "+20% EMP radius & glowing cyan dome.",
			"color": Color("00d2d3")
		},
		{
			"id": "magnet_dish",
			"name": "GOLDEN CASH DISH",
			"slot": "weapon_mod",
			"icon": "📡",
			"stat": "Spinning dish pulls cash from 14m.",
			"color": Color("f1c40f")
		}
	],
	"drift_trail": [
		{
			"id": "underglow_cyan",
			"name": "NEON CYAN UNDERGLOW",
			"slot": "drift_trail",
			"icon": "💡",
			"stat": "Vibrant cyan downward ground aura.",
			"color": Color("00d2d3")
		},
		{
			"id": "trail_gold_flame",
			"name": "GOLDEN FLAME TRAIL",
			"slot": "drift_trail",
			"icon": "🔥",
			"stat": "Turns tire drift particles bright gold.",
			"color": Color("ff9f43")
		},
		{
			"id": "trail_cyber_purple",
			"name": "CYBER VIOLET TRAIL",
			"slot": "drift_trail",
			"icon": "🔮",
			"stat": "Purple electric sparks & underglow.",
			"color": Color("9b59b6")
		}
	],
	"armor_mod": [
		{
			"id": "bumper_standard",
			"name": "STOCK CHROME BUMPER",
			"slot": "armor_mod",
			"icon": "🛡️",
			"stat": "Polished chrome bumper (+10 Max HP).",
			"color": Color("d2dae2")
		},
		{
			"id": "bumper_spiked",
			"name": "SPIKED RAM BULLBAR",
			"slot": "armor_mod",
			"icon": "⚔️",
			"stat": "Heavy steel bullbar (+35% knockback).",
			"color": Color("e84118")
		},
		{
			"id": "armor_titanium",
			"name": "TITANIUM ROLL-CAGE",
			"slot": "armor_mod",
			"icon": "🦺",
			"stat": "+65 Max HP & -25% collision damage.",
			"color": Color("718093")
		}
	]
}

var current_slot_index: int = 0
var _slot_buttons: Array[Button] = []
var _items_grid: GridContainer = null
var _equipped_summary_labels: Dictionary = {}

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	refresh_inventory()

func _build_ui() -> void:
	# Main Drawer Panel styled with Brawl Stars card style
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("161f2e"), Color("0d1117"), 0.0, 24))
	add_child(panel)
	
	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 18)
	panel.add_child(root_v)
	
	# Header
	var title_lbl := Label.new()
	title_lbl.text = "🎒 3-SLOT CAR LOADOUT & GEAR"
	title_lbl.label_settings = BrawlUITheme.make_label_settings(38, Color("fbc531"), 10, 4)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_v.add_child(title_lbl)
	
	var sub_lbl := Label.new()
	sub_lbl.text = "EQUIP WEAPONS, NEON TRAILS & ARMOR THAT ATTACH TO YOUR 3D CAR!"
	sub_lbl.label_settings = BrawlUITheme.make_label_settings(18, Color("74b9ff"), 6, 2)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_v.add_child(sub_lbl)
	
	# Equipped Summary Row (3 mini pills)
	var summary_h := HBoxContainer.new()
	summary_h.add_theme_constant_override("separation", 14)
	root_v.add_child(summary_h)
	
	for slot_key in SLOT_KEYS:
		var pill := PanelContainer.new()
		pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pill.add_theme_stylebox_override("panel", BrawlUITheme.make_pill_style(Color("1e272e"), Color("0d1117"), 0.04, 16))
		summary_h.add_child(pill)
		
		var pv := VBoxContainer.new()
		pv.add_theme_constant_override("separation", 4)
		pill.add_child(pv)
		
		var slot_lbl := Label.new()
		slot_lbl.text = slot_key.to_upper().replace("_", " ")
		slot_lbl.label_settings = BrawlUITheme.make_label_settings(14, Color("fbc531"), 4, 1)
		slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pv.add_child(slot_lbl)
		
		var val_lbl := Label.new()
		val_lbl.text = "EQUIPPED"
		val_lbl.label_settings = BrawlUITheme.make_label_settings(16, Color.WHITE, 6, 2)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pv.add_child(val_lbl)
		_equipped_summary_labels[slot_key] = val_lbl
	
	# Slot Filter Tabs (ROOF, DRIFT, ARMOR)
	var tabs_h := HBoxContainer.new()
	tabs_h.add_theme_constant_override("separation", 12)
	root_v.add_child(tabs_h)
	
	_slot_buttons.clear()
	for i in range(SLOT_TITLES.size()):
		var s_btn := Button.new()
		s_btn.text = SLOT_TITLES[i]
		s_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_btn.custom_minimum_size = Vector2(0, 64)
		BrawlUITheme.attach_button_juice(s_btn, Color("2f3640"))
		
		var s_idx := i
		s_btn.pressed.connect(func(): _select_slot(s_idx))
		tabs_h.add_child(s_btn)
		_slot_buttons.append(s_btn)
	
	var sep := HSeparator.new()
	root_v.add_child(sep)
	
	# Items Grid (3 Cards for the selected slot)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(scroll)
	
	_items_grid = GridContainer.new()
	_items_grid.columns = 1
	_items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_items_grid)

func _select_slot(idx: int) -> void:
	current_slot_index = idx
	for i in range(_slot_buttons.size()):
		var b: Button = _slot_buttons[i]
		var is_active: bool = (i == idx)
		BrawlUITheme.attach_button_juice(b, Color("f39c12") if is_active else Color("2f3640"))
	refresh_inventory()

func refresh_inventory() -> void:
	if not has_node("/root/SaveManager"):
		return
	
	var sm = get_node("/root/SaveManager")
	var unlocked_items: Array[String] = []
	for itm in sm.unlocked_items:
		unlocked_items.append(String(itm))
	var loadout: Dictionary = sm.equipped_loadout
	
	# Update top summary labels
	for slot_key in SLOT_KEYS:
		var cur_id: String = String(loadout.get(slot_key, "none"))
		if _equipped_summary_labels.has(slot_key):
			var lbl: Label = _equipped_summary_labels[slot_key]
			lbl.text = cur_id.to_upper().replace("_", " ")
	
	# Populate current slot items
	if not _items_grid:
		return
	for c in _items_grid.get_children():
		c.queue_free()
	
	var current_slot_key: String = SLOT_KEYS[current_slot_index]
	var items: Array = GEAR_DATA.get(current_slot_key, [])
	var equipped_in_slot: String = String(loadout.get(current_slot_key, ""))
	
	for item_data in items:
		var item: Dictionary = item_data as Dictionary
		var i_id: String = String(item.get("id", ""))
		var i_name: String = String(item.get("name", ""))
		var i_icon: String = String(item.get("icon", "📦"))
		var i_stat: String = String(item.get("stat", ""))
		var i_col: Color = item.get("color", Color.WHITE)
		var is_unlocked: bool = (i_id in unlocked_items)
		var is_equipped: bool = (i_id == equipped_in_slot)
		
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 130)
		var border_col: Color = Color("f39c12") if is_equipped else (i_col if is_unlocked else Color("0d1117"))
		card.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("1e272e"), border_col, 0.04, 20))
		_items_grid.add_child(card)
		
		var row_h := HBoxContainer.new()
		row_h.add_theme_constant_override("separation", 20)
		card.add_child(row_h)
		
		# Icon Pill
		var icon_pill := PanelContainer.new()
		icon_pill.custom_minimum_size = Vector2(100, 100)
		icon_pill.add_theme_stylebox_override("panel", BrawlUITheme.make_pill_style(i_col.darkened(0.3), Color("0d1117"), 0.04, 18))
		row_h.add_child(icon_pill)
		
		var icon_lbl := Label.new()
		icon_lbl.text = i_icon
		icon_lbl.label_settings = BrawlUITheme.make_label_settings(48, Color.WHITE, 4, 2)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_pill.add_child(icon_lbl)
		
		# Info VBox
		var info_v := VBoxContainer.new()
		info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_v.alignment = BoxContainer.ALIGNMENT_CENTER
		info_v.add_theme_constant_override("separation", 6)
		row_h.add_child(info_v)
		
		var name_lbl := Label.new()
		name_lbl.text = i_name
		name_lbl.label_settings = BrawlUITheme.make_label_settings(24, Color.WHITE, 6, 2)
		info_v.add_child(name_lbl)
		
		var stat_lbl := Label.new()
		stat_lbl.text = i_stat
		stat_lbl.label_settings = BrawlUITheme.make_label_settings(17, Color("2ecc71") if is_unlocked else Color("718093"), 4, 1)
		info_v.add_child(stat_lbl)
		
		# Action Button
		var action_v := VBoxContainer.new()
		action_v.alignment = BoxContainer.ALIGNMENT_CENTER
		row_h.add_child(action_v)
		
		if is_equipped:
			var eq_pill := PanelContainer.new()
			eq_pill.add_theme_stylebox_override("panel", BrawlUITheme.make_pill_style(Color("f39c12"), Color("0d1117"), 0.04, 14))
			action_v.add_child(eq_pill)
			
			var eq_lbl := Label.new()
			eq_lbl.text = "★ EQUIPPED ★"
			eq_lbl.label_settings = BrawlUITheme.make_label_settings(18, Color.WHITE, 6, 2)
			eq_pill.add_child(eq_lbl)
		elif is_unlocked:
			var eq_btn := Button.new()
			eq_btn.text = "EQUIP"
			eq_btn.custom_minimum_size = Vector2(160, 56)
			BrawlUITheme.attach_button_juice(eq_btn, Color("44bd32"))
			eq_btn.pressed.connect(func(): _on_equip_pressed(current_slot_key, i_id))
			action_v.add_child(eq_btn)
		else:
			var lock_pill := PanelContainer.new()
			lock_pill.add_theme_stylebox_override("panel", BrawlUITheme.make_pill_style(Color("2f3640"), Color("0d1117"), 0.04, 14))
			action_v.add_child(lock_pill)
			
			var lock_lbl := Label.new()
			lock_lbl.text = "🔒 LOCKED"
			lock_lbl.label_settings = BrawlUITheme.make_label_settings(16, Color("718093"), 4, 1)
			lock_pill.add_child(lock_lbl)

func _on_equip_pressed(slot: String, item_id: String) -> void:
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.equip_gear_item(slot, item_id)
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_ui_click()
	
	refresh_inventory()
	loadout_changed.emit(slot, item_id)
