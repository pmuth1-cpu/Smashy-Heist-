with open("scripts/world/main_game.gd", "r", encoding="utf-8") as f:
    text = f.read()

# Add onready var smashy_kart_mode
onready_target = "@onready var boss_escape_mode: BossEscapeMode = $BossEscapeMode"
onready_replacement = """@onready var boss_escape_mode: BossEscapeMode = $BossEscapeMode
@onready var smashy_kart_mode: SmashyKartMode = get_node_or_null("SmashyKartMode")"""

assert onready_target in text, "onready_target not found!"
text = text.replace(onready_target, onready_replacement, 1)

# Add match 4 in start_game_mode
match_target = """		3: # HOT_LOOT_4P_TAG
			var shared_seed: int = 0
			if has_node("/root/DailySeedManager"):
				var dsm = get_node("/root/DailySeedManager")
				shared_seed = dsm.base_seed
			if shared_seed == 0:
				shared_seed = randi()
			start_hot_loot_mode(shared_seed)
		_:
			start_solo_daily_mode()"""

match_replacement = """		3: # HOT_LOOT_4P_TAG
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

assert match_target in text, "match_target not found!"
text = text.replace(match_target, match_replacement, 1)

# Add start_kart_mode() function
fn_code = """
## Starts Mode 4: "Smashy Kart Grand Prix"
func start_kart_mode() -> void:
	hot_loot_mode.is_hot_loot_mode = false
	if heist_steal_mode:
		heist_steal_mode.stop_heist_mode()
	if boss_escape_mode:
		boss_escape_mode.stop_boss_mode()
	_clear_spawned_rivals()
	
	_setup_car_position(arcade_car, Vector3(0, 0.6, 0))
	_wire_local_player(arcade_car)
	
	if smashy_kart_mode:
		smashy_kart_mode.start_grand_prix(arcade_car)
"""

text += fn_code

with open("scripts/world/main_game.gd", "w", encoding="utf-8", newline="\n") as f:
    f.write(text)

print("main_game.gd updated with SmashyKartMode successfully!")
