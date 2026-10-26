import re

with open("scripts/ui/brawl_main_menu.gd", "r", encoding="utf-8") as f:
    text = f.read()

# Update MODE_DEFS
old_defs = """const MODE_DEFS: Array[Dictionary] = [
	{"id": 0, "name": "DAILY GETAWAY", "desc": "Survive 5 stars in daily seeded streets!", "thumb": "res://assets/ui/thumb_daily_getaway.png"},
	{"id": 1, "name": "💎 BANK HEIST", "desc": "Ram the vault & tow loot to chopper!", "thumb": "res://assets/ui/thumb_sky_city.png"},
	{"id": 2, "name": "🕷️ BOSS ESCAPE", "desc": "Outrun the crushing Steampunk Spider Mech!", "thumb": "res://assets/ui/thumb_daily_getaway.png"},
	{"id": 3, "name": "🔥 HOT LOOT TAG", "desc": "Hold the loot bag against rivals & cops!", "thumb": "res://assets/ui/thumb_sky_city.png"}
]"""

new_defs = """const MODE_DEFS: Array[Dictionary] = [
	{"id": 0, "name": "DAILY GETAWAY", "desc": "Survive 5 stars in daily seeded streets!", "thumb": "res://assets/ui/thumb_daily_getaway.png"},
	{"id": 1, "name": "💎 BANK HEIST", "desc": "Ram the vault & tow loot to chopper!", "thumb": "res://assets/ui/thumb_sky_city.png"},
	{"id": 2, "name": "🕷️ BOSS ESCAPE", "desc": "Outrun the crushing Steampunk Spider Mech!", "thumb": "res://assets/ui/thumb_daily_getaway.png"},
	{"id": 3, "name": "🔥 HOT LOOT TAG", "desc": "Hold the loot bag against rivals & cops!", "thumb": "res://assets/ui/thumb_sky_city.png"},
	{"id": 4, "name": "🏁 SMASHY KART GP", "desc": "3-Lap 6-Racer Circuit! Items, Drifts & Cups!", "thumb": "res://assets/kart/kart_flag_checkered.png"}
]"""

assert old_defs in text, "old_defs not found!"
text = text.replace(old_defs, new_defs, 1)

# Update _refresh_mode_display()
old_refresh = """	var mdef: Dictionary = MODE_DEFS[current_mode_index]
	if _mode_title_label:
		_mode_title_label.text = str(mdef["name"])"""

new_refresh = """	var mdef: Dictionary = MODE_DEFS[current_mode_index]
	if _mode_title_label:
		if current_mode_index == 4 and has_node("/root/GameModeManager"):
			var gmm = get_node("/root/GameModeManager")
			var t_info: Dictionary = gmm.get_kart_track_info()
			_mode_title_label.text = "🏁 KART: %s" % str(t_info.get("title", "Neon Circuit"))
		else:
			_mode_title_label.text = str(mdef["name"])"""

assert old_refresh in text, "old_refresh not found!"
text = text.replace(old_refresh, new_refresh, 1)

# Update _build_mode_selector_drawer to add track selector
old_drawer = """		var mid: int = int(def["id"])
		btn.pressed.connect(func():
			current_mode_index = mid
			if has_node("/root/GameModeManager"):
				var gmm = get_node("/root/GameModeManager")
				gmm.set_mode(mid)
			_refresh_mode_display()
			_mode_drawer_panel.visible = false
		)
		mv.add_child(btn)
	
	var close_btn := Button.new()"""

new_drawer = """		var mid: int = int(def["id"])
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
	
	var close_btn := Button.new()"""

assert old_drawer in text, "old_drawer not found!"
text = text.replace(old_drawer, new_drawer, 1)

with open("scripts/ui/brawl_main_menu.gd", "w", encoding="utf-8", newline="\n") as f:
    f.write(text)

print("brawl_main_menu.gd updated successfully!")
