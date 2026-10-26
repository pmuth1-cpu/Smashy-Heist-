# 1. Update scripts/world/main_game.gd
with open("scripts/world/main_game.gd", "r", encoding="utf-8") as f:
    text = f.read()

# Remove @onready var heist_steal_mode
text = text.replace('@onready var heist_steal_mode: HeistStealMode = $HeistStealMode\n', '')
text = text.replace('if heist_steal_mode:\n\t\theist_steal_mode.stop_heist_mode()\n', '')
text = text.replace('if heist_steal_mode:\n\theist_steal_mode.stop_heist_mode()\n', '')

# Update start_game_mode match block
old_match = """	match mode_id:
		0: # DAILY_ENDLESS_GETAWAY
			start_solo_daily_mode()
		1: # BANK_HEIST_STEAL
			start_bank_heist_mode()
		2: # ESCAPE_MEGA_BOSS
			start_boss_escape_mode()
		3: # HOT_LOOT_4P_TAG
			var shared_seed: int = 0
			if has_node("/root/DailySeedManager"):
				var dsm = get_node("/root/DailySeedManager")
				shared_seed = dsm.base_seed
			if shared_seed == 0:
				shared_seed = randi()
			start_hot_loot_mode(shared_seed)
		4: # SMASHY_KART_GP
			start_kart_mode()
		_:
			start_solo_daily_mode()"""

new_match = """	match mode_id:
		0: # DAILY_ENDLESS_GETAWAY
			start_solo_daily_mode()
		1: # ESCAPE_MEGA_BOSS
			start_boss_escape_mode()
		2: # HOT_LOOT_4P_TAG
			var shared_seed: int = 0
			if has_node("/root/DailySeedManager"):
				var dsm = get_node("/root/DailySeedManager")
				shared_seed = dsm.base_seed
			if shared_seed == 0:
				shared_seed = randi()
			start_hot_loot_mode(shared_seed)
		3: # SMASHY_KART_GP
			start_kart_mode()
		_:
			start_solo_daily_mode()"""

assert old_match in text, "old_match not found in main_game.gd"
text = text.replace(old_match, new_match, 1)

# Remove start_bank_heist_mode function
bank_fn = """## Starts Mode 2: "Bank Heist: Steal & Extract"
func start_bank_heist_mode() -> void:
	hot_loot_mode.is_hot_loot_mode = false
	if boss_escape_mode:
		boss_escape_mode.stop_boss_mode()
	_clear_spawned_rivals()
	
	_setup_car_position(arcade_car, STARTING_GRID[0])
	_wire_local_player(arcade_car)
	
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		wm.start_new_run()
"""

# Let's remove any leftover start_bank_heist_mode definition
import re
text = re.sub(r'## Starts Mode 2: "Bank Heist: Steal & Extract"[\s\S]*?wm\.start_new_run\(\)\n', '', text)

with open("scripts/world/main_game.gd", "w", encoding="utf-8", newline="\n") as f:
    f.write(text)

print("main_game.gd updated: bank heist removed, 4 clean modes configured!")

# 2. Update scripts/ui/brawl_main_menu.gd
with open("scripts/ui/brawl_main_menu.gd", "r", encoding="utf-8") as f:
    m_text = f.read()

# Update MODE_DEFS
old_defs = """const MODE_DEFS: Array[Dictionary] = [
	{"id": 0, "name": "DAILY GETAWAY", "desc": "Survive 5 stars in daily seeded streets!", "thumb": "res://assets/ui/thumb_daily_getaway.png"},
	{"id": 1, "name": "💎 BANK HEIST", "desc": "Ram the vault & tow loot to chopper!", "thumb": "res://assets/ui/thumb_sky_city.png"},
	{"id": 2, "name": "🕷️ BOSS ESCAPE", "desc": "Outrun the crushing Steampunk Spider Mech!", "thumb": "res://assets/ui/thumb_daily_getaway.png"},
	{"id": 3, "name": "🔥 HOT LOOT TAG", "desc": "Hold the loot bag against rivals & cops!", "thumb": "res://assets/ui/thumb_sky_city.png"},
	{"id": 4, "name": "🏁 SMASHY KART GP", "desc": "3-Lap 6-Racer Circuit! Items, Drifts & Cups!", "thumb": "res://assets/kart/kart_flag_checkered.png"}
]"""

new_defs = """const MODE_DEFS: Array[Dictionary] = [
	{"id": 0, "name": "DAILY GETAWAY", "desc": "Survive 5 stars in daily seeded streets!", "thumb": "res://assets/ui/thumb_daily_getaway.png"},
	{"id": 1, "name": "🕷️ BOSS ESCAPE", "desc": "Outrun the crushing Steampunk Spider Mech!", "thumb": "res://assets/ui/thumb_daily_getaway.png"},
	{"id": 2, "name": "🔥 HOT LOOT TAG", "desc": "Hold the loot bag against rivals & cops!", "thumb": "res://assets/ui/thumb_sky_city.png"},
	{"id": 3, "name": "🏁 SMASHY KART GP", "desc": "3-Lap 6-Racer Circuit! Items, Drifts & Cups!", "thumb": "res://assets/kart/kart_flag_checkered.png"}
]"""

assert old_defs in m_text, "old_defs not found in brawl_main_menu.gd"
m_text = m_text.replace(old_defs, new_defs, 1)

# Update _refresh_mode_display current_mode_index == 3 (was 4)
m_text = m_text.replace("if current_mode_index == 4 and has_node", "if current_mode_index == 3 and has_node")

# Replace _build_mode_selector_drawer and _toggle_mode_drawer with new full-screen centered modal
old_drawer_code = """func _build_mode_selector_drawer() -> void:
	_mode_drawer_panel = PanelContainer.new()
	_mode_drawer_panel.name = "ModeDrawerPanel"
	_mode_drawer_panel.set_anchors_preset(PRESET_CENTER)
	_mode_drawer_panel.custom_minimum_size = Vector2(840, 580)
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
		btn.custom_minimum_size = Vector2(0, 84)
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
			if mid != 4:
				_mode_drawer_panel.visible = false
		)
		mv.add_child(btn)

	# Grand Prix Cup Track selection drawer row
	var track_box := VBoxContainer.new()
	track_box.name = "KartTrackSelectorBox"
	var track_header := Label.new()
	track_header.text = "🏁 SELECT CUP CIRCUIT:"
	track_header.label_settings = BrawlUITheme.make_label_settings(20, Color("ff3f34"), 6, 2)
	track_box.add_child(track_header)

	var track_hbox := HBoxContainer.new()
	track_hbox.add_theme_constant_override("separation", 10)
	var cup_names = ["🏙️ NEON DOWNTOWN", "🐉 DRAGON CHINATOWN", "🏜️ CANYON HIGHWAY"]
	for tid in range(3):
		var tbtn := Button.new()
		tbtn.text = cup_names[tid]
		tbtn.custom_minimum_size = Vector2(250, 52)
		BrawlUITheme.attach_button_juice(tbtn, Color("1e272e"))
		var c_track_id: int = tid
		tbtn.pressed.connect(func():
			if has_node("/root/GameModeManager"):
				var gmm = get_node("/root/GameModeManager")
				gmm.set_kart_cup_track(c_track_id)
				gmm.set_mode(4)
			current_mode_index = 4
			_refresh_mode_display()
			_mode_drawer_panel.visible = false
		)
		track_hbox.add_child(tbtn)
	track_box.add_child(track_hbox)
	mv.add_child(track_box)
	
	var close_btn := Button.new()
	close_btn.text = "BACK"
	close_btn.custom_minimum_size = Vector2(0, 70)
	BrawlUITheme.attach_button_juice(close_btn, Color("e84118"))
	close_btn.pressed.connect(func(): _mode_drawer_panel.visible = false)
	mv.add_child(close_btn)

func _toggle_mode_drawer() -> void:
	if _mode_drawer_panel:
		_mode_drawer_panel.visible = not _mode_drawer_panel.visible"""

new_drawer_code = """func _build_mode_selector_drawer() -> void:
	if _mode_drawer_panel and is_instance_valid(_mode_drawer_panel):
		_mode_drawer_panel.queue_free()
	
	# Full-screen dimmed modal layer with highest z-index
	_mode_drawer_panel = PanelContainer.new()
	_mode_drawer_panel.name = "ModeDrawerModal"
	_mode_drawer_panel.set_anchors_preset(PRESET_FULL_RECT)
	_mode_drawer_panel.z_index = 250
	_mode_drawer_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var backdrop_sb := StyleBoxFlat.new()
	backdrop_sb.bg_color = Color(0.04, 0.07, 0.11, 0.82)
	_mode_drawer_panel.add_theme_stylebox_override("panel", backdrop_sb)
	_mode_drawer_panel.visible = false
	add_child(_mode_drawer_panel)
	
	# Center card container (920 x 640)
	var card := PanelContainer.new()
	card.name = "ModeCardContainer"
	card.custom_minimum_size = Vector2(920, 620)
	card.anchor_left = 0.5
	card.anchor_top = 0.5
	card.anchor_right = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -460.0
	card.offset_top = -310.0
	card.offset_right = 460.0
	card.offset_bottom = 310.0
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("151f2b"), Color("fbc531"), 0.05, 24))
	_mode_drawer_panel.add_child(card)
	
	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 28)
	card_margin.add_theme_constant_override("margin_top", 18)
	card_margin.add_theme_constant_override("margin_right", 28)
	card_margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(card_margin)
	
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 12)
	card_margin.add_child(mv)
	
	var title := Label.new()
	title.text = "SELECT GAME MODE"
	title.label_settings = BrawlUITheme.make_label_settings(32, Color("fbc531"), 8, 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(title)
	
	for def in MODE_DEFS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 80)
		BrawlUITheme.attach_button_juice(btn, Color("1e2c3c"))
		
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
			if mid != 3:
				_mode_drawer_panel.visible = false
		)
		mv.add_child(btn)

	# Grand Prix Cup Track selection drawer row
	var track_box := VBoxContainer.new()
	track_box.name = "KartTrackSelectorBox"
	track_box.add_theme_constant_override("separation", 6)
	
	var track_header := Label.new()
	track_header.text = "🏁 SELECT CUP CIRCUIT:"
	track_header.label_settings = BrawlUITheme.make_label_settings(20, Color("ff3f34"), 6, 2)
	track_box.add_child(track_header)

	var track_hbox := HBoxContainer.new()
	track_hbox.add_theme_constant_override("separation", 12)
	var cup_names = ["🏙️ NEON DOWNTOWN", "🐉 DRAGON CHINATOWN", "🏜️ CANYON HIGHWAY"]
	for tid in range(3):
		var tbtn := Button.new()
		tbtn.text = cup_names[tid]
		tbtn.custom_minimum_size = Vector2(240, 50)
		tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		BrawlUITheme.attach_button_juice(tbtn, Color("101a26"))
		var c_track_id: int = tid
		tbtn.pressed.connect(func():
			if has_node("/root/GameModeManager"):
				var gmm = get_node("/root/GameModeManager")
				gmm.set_kart_cup_track(c_track_id)
				gmm.set_mode(3)
			current_mode_index = 3
			_refresh_mode_display()
			_mode_drawer_panel.visible = false
		)
		track_hbox.add_child(tbtn)
	track_box.add_child(track_hbox)
	mv.add_child(track_box)
	
	var close_btn := Button.new()
	close_btn.text = "BACK / CLOSE"
	close_btn.custom_minimum_size = Vector2(0, 60)
	BrawlUITheme.attach_button_juice(close_btn, Color("e84118"))
	close_btn.pressed.connect(func(): _mode_drawer_panel.visible = false)
	mv.add_child(close_btn)

func _toggle_mode_drawer() -> void:
	if _mode_drawer_panel:
		_mode_drawer_panel.visible = not _mode_drawer_panel.visible
		if _mode_drawer_panel.visible:
			_mode_drawer_panel.move_to_front()"""

assert old_drawer_code in m_text, "old_drawer_code not found in brawl_main_menu.gd"
m_text = m_text.replace(old_drawer_code, new_drawer_code, 1)

with open("scripts/ui/brawl_main_menu.gd", "w", encoding="utf-8", newline="\n") as f:
    f.write(m_text)

print("brawl_main_menu.gd updated: bank heist deleted, full-screen modal mode selector configured!")
