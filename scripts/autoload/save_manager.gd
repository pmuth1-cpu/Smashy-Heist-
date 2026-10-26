class_name SaveManagerClass
extends Node

## Offline Save Manager & UTC Daily Streak Tracker
## Persists player progression, cash, vehicle unlocks, ghost runs, and pending score queues.

signal data_saved()
signal cash_changed(new_amount: int)
signal gems_changed(new_amount: int)
signal gacha_tokens_changed(new_amount: int)
signal car_unlocked(car_id: String)
signal car_equipped(car_id: String)
signal car_upgraded(car_id: String, new_level: int)
signal item_unlocked(item_id: String)
signal loadout_changed(slot: String, item_id: String)
signal gear_upgraded(gear_id: String, new_level: int)
signal gear_loadout_changed(slot: String, gear_id: String)
signal lucky_meter_changed(new_value: int)
signal friends_updated()
signal trophies_changed(new_amount: int)

const SAVE_PATH: String = "user://save_data.json"

var player_id: String = ""
var player_name: String = "Driver_0000"
var total_cash: int = 200
var total_trophies: int = 1250
var total_gems: int = 59752
var gacha_tokens: int = 12
var lucky_meter: int = 32
var daily_streak: int = 0
var last_daily_utc_date: String = ""
var best_daily_score: int = 0
var unlocked_cars: Array[String] = ["tuk_tuk_jet", "racer_01", "tanker", "shadow", "fire_dragon", "default_coupe"]
var equipped_car_id: String = "tuk_tuk_jet"
var car_levels: Dictionary = {
	"tuk_tuk_jet": 3,
	"racer_01": 2,
	"tanker": 2,
	"shadow": 1,
	"fire_dragon": 1,
	"default_coupe": 1
}
var car_skins: Dictionary = {
	"tuk_tuk_jet": "default",
	"racer_01": "default"
}
var car_shards: Dictionary = {}
var pending_score_queue: Array[Dictionary] = []
var saved_daily_ghost: Array[Dictionary] = []
var cached_leaderboard: Array[Dictionary] = []

# 6-Slot Sci-Fi Gear Loadout & Upgrades
var gear_loadout: Dictionary = {
	"engine": "jet_engine",
	"wheels": "cyber_wheels",
	"wings": "gt_wings",
	"armor": "titanium_bullbar",
	"gadget": "nos_booster",
	"skin": "prismatic_core"
}
var gear_levels: Dictionary = {
	"jet_engine": 3,
	"cyber_wheels": 2,
	"gt_wings": 1,
	"titanium_bullbar": 2,
	"nos_booster": 1,
	"prismatic_core": 1
}
var unlocked_gears: Array[String] = [
	"jet_engine",
	"cyber_wheels",
	"gt_wings",
	"titanium_bullbar",
	"nos_booster",
	"prismatic_core",
	"supercharger",
	"racing_slick",
	"vortex_diffuser",
	"emp_generator"
]

# Legacy Phase 12 items
var unlocked_items: Array[String] = ["bumper_standard", "underglow_cyan", "rockets_twin"]
var equipped_loadout: Dictionary = {
	"weapon_mod": "rockets_twin",
	"drift_trail": "underglow_cyan",
	"armor_mod": "bumper_standard"
}

# Phase 12: Friends & Squad
var friend_code: String = ""
var friends_list: Array[Dictionary] = []

# Phase 12: 7-Day Login & Daily Quests Persistence
var login_day_index: int = 1
var last_claimed_login_utc: String = ""
var claimed_login_days: Array[int] = []
var daily_quests: Array[Dictionary] = []
var daily_quests_date_utc: String = ""
var daily_heist_safe_claimed: bool = false

func _ready() -> void:
	load_save_data()

## Loads save data from disk or initializes defaults.
func load_save_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_init_default_profile()
		save_to_disk()
		return
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_init_default_profile()
		save_to_disk()
		return
	
	var content: String = file.get_as_text()
	file.close()
	
	var json: Variant = JSON.parse_string(content)
	if not (json is Dictionary):
		_init_default_profile()
		save_to_disk()
		return
	
	var dict := json as Dictionary
	player_id = String(dict.get("player_id", ""))
	if player_id.is_empty():
		_init_default_profile()
	else:
		player_name = String(dict.get("player_name", "Driver_" + player_id.right(4)))
	
	total_cash = int(dict.get("total_cash", 200))
	daily_streak = int(dict.get("daily_streak", 0))
	last_daily_utc_date = String(dict.get("last_daily_utc_date", ""))
	best_daily_score = int(dict.get("best_daily_score", 0))
	
	# Load unlocked cars
	unlocked_cars.clear()
	var raw_cars: Array = dict.get("unlocked_cars", ["default_coupe"])
	for c in raw_cars:
		unlocked_cars.append(String(c))
	if not ("default_coupe" in unlocked_cars):
		unlocked_cars.append("default_coupe")
	if not ("tuk_tuk_jet" in unlocked_cars):
		unlocked_cars.append("tuk_tuk_jet")
	
	equipped_car_id = String(dict.get("equipped_car_id", "default_coupe"))
	var vdb = null
	if has_node("/root/VehicleDatabase"):
		vdb = get_node("/root/VehicleDatabase")
	if not (equipped_car_id in unlocked_cars):
		if vdb and vdb.has_car(equipped_car_id):
			unlocked_cars.append(equipped_car_id)
		else:
			equipped_car_id = "default_coupe"
	
	car_shards = dict.get("car_shards", {})
	
	# Pending score queue
	pending_score_queue.clear()
	var raw_queue: Array = dict.get("pending_score_queue", [])
	for q in raw_queue:
		if q is Dictionary:
			pending_score_queue.append(q)
	
	# Saved daily ghost
	saved_daily_ghost.clear()
	var raw_ghost: Array = dict.get("saved_daily_ghost", [])
	for f in raw_ghost:
		if f is Dictionary:
			saved_daily_ghost.append(f)
	
	# Cached leaderboard
	cached_leaderboard.clear()
	var raw_lb: Array = dict.get("cached_leaderboard", [])
	for entry in raw_lb:
		if entry is Dictionary:
			cached_leaderboard.append(entry)
	
	# Load unlocked items & loadout
	unlocked_items.clear()
	var raw_items: Array = dict.get("unlocked_items", ["bumper_standard", "underglow_cyan", "rockets_twin"])
	for item in raw_items:
		unlocked_items.append(String(item))
	if not ("bumper_standard" in unlocked_items):
		unlocked_items.append("bumper_standard")
	
	var raw_loadout: Dictionary = dict.get("equipped_loadout", {})
	if raw_loadout.is_empty():
		equipped_loadout = {
			"weapon_mod": "rockets_twin",
			"drift_trail": "underglow_cyan",
			"armor_mod": "bumper_standard"
		}
	else:
		equipped_loadout["weapon_mod"] = String(raw_loadout.get("weapon_mod", "rockets_twin"))
		equipped_loadout["drift_trail"] = String(raw_loadout.get("drift_trail", "underglow_cyan"))
		equipped_loadout["armor_mod"] = String(raw_loadout.get("armor_mod", "bumper_standard"))
	
	# Friend Code & Friends List
	friend_code = String(dict.get("friend_code", ""))
	if friend_code.is_empty():
		friend_code = "#SH-" + (player_id.substr(0, 4) if player_id.length() >= 4 else "7777").to_upper()
	
	friends_list.clear()
	var raw_friends: Array = dict.get("friends_list", [])
	if raw_friends.is_empty():
		_init_default_friends()
	else:
		for f in raw_friends:
			if f is Dictionary:
				friends_list.append(f)
	
	# Login Calendar & Quests
	login_day_index = clampi(int(dict.get("login_day_index", 1)), 1, 7)
	last_claimed_login_utc = String(dict.get("last_claimed_login_utc", ""))
	claimed_login_days.clear()
	var raw_days: Array = dict.get("claimed_login_days", [])
	for d in raw_days:
		claimed_login_days.append(int(d))
	
	daily_quests.clear()
	var raw_quests: Array = dict.get("daily_quests", [])
	for q in raw_quests:
		if q is Dictionary:
			daily_quests.append(q)
	
	# Load currencies, pity and progression
	total_gems = int(dict.get("total_gems", 59752))
	gacha_tokens = int(dict.get("gacha_tokens", 12))
	lucky_meter = int(dict.get("lucky_meter", 32))
	if dict.has("car_levels"):
		var raw_cl: Dictionary = dict.get("car_levels", {})
		for k in raw_cl:
			car_levels[String(k)] = int(raw_cl[k])
	if dict.has("car_skins"):
		var raw_cs: Dictionary = dict.get("car_skins", {})
		for k in raw_cs:
			car_skins[String(k)] = String(raw_cs[k])
	if dict.has("gear_loadout"):
		var raw_gl: Dictionary = dict.get("gear_loadout", {})
		for k in raw_gl:
			gear_loadout[String(k)] = String(raw_gl[k])
	if dict.has("gear_levels"):
		var raw_lvl: Dictionary = dict.get("gear_levels", {})
		for k in raw_lvl:
			gear_levels[String(k)] = int(raw_lvl[k])
	if dict.has("unlocked_gears"):
		var raw_ug: Array = dict.get("unlocked_gears", [])
		for g in raw_ug:
			if not (String(g) in unlocked_gears):
				unlocked_gears.append(String(g))
	
	daily_quests_date_utc = String(dict.get("daily_quests_date_utc", ""))
	daily_heist_safe_claimed = bool(dict.get("daily_heist_safe_claimed", false))

func _init_default_profile() -> void:
	var unique: String = OS.get_unique_id().strip_edges()
	if unique.is_empty():
		# Fallback random hex identifier
		unique = "%08x%04x" % [randi(), randi() % 0xffff]
	player_id = unique
	player_name = "Driver_" + player_id.right(4).to_upper()
	total_cash = 200
	total_gems = 59752
	gacha_tokens = 12
	lucky_meter = 32
	daily_streak = 0
	last_daily_utc_date = ""
	best_daily_score = 0
	unlocked_cars = ["tuk_tuk_jet", "racer_01", "tanker", "shadow", "fire_dragon", "default_coupe"]
	equipped_car_id = "tuk_tuk_jet"
	car_levels = {
		"tuk_tuk_jet": 3,
		"racer_01": 2,
		"tanker": 2,
		"shadow": 1,
		"fire_dragon": 1,
		"default_coupe": 1
	}
	car_skins = {
		"tuk_tuk_jet": "default",
		"racer_01": "default"
	}
	pending_score_queue = []
	saved_daily_ghost = []
	cached_leaderboard = []
	
	gear_loadout = {
		"engine": "jet_engine",
		"wheels": "cyber_wheels",
		"wings": "gt_wings",
		"armor": "titanium_bullbar",
		"gadget": "nos_booster",
		"skin": "prismatic_core"
	}
	gear_levels = {
		"jet_engine": 3,
		"cyber_wheels": 2,
		"gt_wings": 1,
		"titanium_bullbar": 2,
		"nos_booster": 1,
		"prismatic_core": 1
	}
	unlocked_gears = [
		"jet_engine",
		"cyber_wheels",
		"gt_wings",
		"titanium_bullbar",
		"nos_booster",
		"prismatic_core",
		"supercharger",
		"racing_slick",
		"vortex_diffuser",
		"emp_generator"
	]
	
	unlocked_items = ["bumper_standard", "underglow_cyan", "rockets_twin"]
	equipped_loadout = {
		"weapon_mod": "rockets_twin",
		"drift_trail": "underglow_cyan",
		"armor_mod": "bumper_standard"
	}
	friend_code = "#SH-" + (player_id.substr(0, 4) if player_id.length() >= 4 else "7777").to_upper()
	_init_default_friends()
	login_day_index = 1
	last_claimed_login_utc = ""
	claimed_login_days = []
	daily_quests = []
	daily_quests_date_utc = ""
	daily_heist_safe_claimed = false

func _init_default_friends() -> void:
	friends_list = [
		{
			"code": "#SH-8821",
			"name": "TurboMax",
			"car_id": "cyber_interceptor",
			"trophies": 2450,
			"streak": 7,
			"status": "🟢 ONLINE",
			"loadout": {"weapon_mod": "rockets_twin", "drift_trail": "underglow_cyan", "armor_mod": "bumper_spiked"}
		},
		{
			"code": "#SH-4092",
			"name": "BrawlDrifter",
			"car_id": "ice_cream_drifter",
			"trophies": 1820,
			"streak": 3,
			"status": "🏎️ IN HEIST",
			"loadout": {"weapon_mod": "emp_dome", "drift_trail": "trail_cyber_purple", "armor_mod": "bumper_standard"}
		},
		{
			"code": "#SH-7110",
			"name": "TankBuster",
			"car_id": "armored_bulldozer",
			"trophies": 3100,
			"streak": 12,
			"status": "🟢 ONLINE",
			"loadout": {"weapon_mod": "magnet_dish", "drift_trail": "trail_gold_flame", "armor_mod": "armor_titanium"}
		}
	]

## Saves current profile state to disk in user://save_data.json.
func save_to_disk() -> void:
	var dict: Dictionary = {
		"player_id": player_id,
		"player_name": player_name,
		"total_cash": total_cash,
		"total_gems": total_gems,
		"gacha_tokens": gacha_tokens,
		"lucky_meter": lucky_meter,
		"daily_streak": daily_streak,
		"last_daily_utc_date": last_daily_utc_date,
		"best_daily_score": best_daily_score,
		"unlocked_cars": unlocked_cars,
		"equipped_car_id": equipped_car_id,
		"car_levels": car_levels,
		"car_skins": car_skins,
		"car_shards": car_shards,
		"pending_score_queue": pending_score_queue,
		"saved_daily_ghost": saved_daily_ghost,
		"cached_leaderboard": cached_leaderboard,
		"gear_loadout": gear_loadout,
		"gear_levels": gear_levels,
		"unlocked_gears": unlocked_gears,
		"unlocked_items": unlocked_items,
		"equipped_loadout": equipped_loadout,
		"friend_code": friend_code,
		"friends_list": friends_list,
		"login_day_index": login_day_index,
		"last_claimed_login_utc": last_claimed_login_utc,
		"claimed_login_days": claimed_login_days,
		"daily_quests": daily_quests,
		"daily_quests_date_utc": daily_quests_date_utc,
		"daily_heist_safe_claimed": daily_heist_safe_claimed
	}
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(dict, "\t"))
		file.close()
		data_saved.emit()

## Unlocks an inventory item
func unlock_item(item_id: String) -> bool:
	if not (item_id in unlocked_items):
		unlocked_items.append(item_id)
		save_to_disk()
		item_unlocked.emit(item_id)
		return true
	return false

## Equips a gear item into slot ("weapon_mod", "drift_trail", "armor_mod")
func equip_gear_item(slot: String, item_id: String) -> bool:
	if item_id in unlocked_items or item_id == "":
		equipped_loadout[slot] = item_id
		save_to_disk()
		loadout_changed.emit(slot, item_id)
		return true
	return false

## Adds a friend by dictionary
func add_friend(friend_dict: Dictionary) -> bool:
	var code: String = String(friend_dict.get("code", "")).strip_edges().to_upper()
	if code.is_empty():
		return false
	for f in friends_list:
		if String(f.get("code", "")).to_upper() == code:
			return false
	friends_list.append(friend_dict)
	save_to_disk()
	friends_updated.emit()
	return true

## Records a finished getaway run, awards cash, validates daily streaks, and saves ghost runs.
func record_completed_run(score: int, _survival_time: float, _cops_wrecked: int, is_daily: bool, ghost_frames: Array[Dictionary]) -> void:
	# 1. Cash award: 1 cash per 25 points
	var cash_earned: int = int(score / 25)
	if cash_earned > 0:
		total_cash += cash_earned
		cash_changed.emit(total_cash)
	
	# 2. Daily Streak Validation
	if is_daily:
		var today_utc: String = Time.get_date_string_from_system(true)
		if last_daily_utc_date != today_utc:
			var is_consecutive: bool = false
			if not last_daily_utc_date.is_empty():
				var today_unix: int = Time.get_unix_time_from_datetime_string(today_utc + "T00:00:00Z")
				var last_unix: int = Time.get_unix_time_from_datetime_string(last_daily_utc_date + "T00:00:00Z")
				var day_diff: int = int(round(float(today_unix - last_unix) / 86400.0))
				if day_diff == 1:
					is_consecutive = true
			
			if is_consecutive:
				daily_streak += 1
			else:
				daily_streak = 1
			
			last_daily_utc_date = today_utc
			best_daily_score = 0
		
		# Best score and ghost recording for today
		if score >= best_daily_score:
			best_daily_score = score
			if not ghost_frames.is_empty():
				saved_daily_ghost = ghost_frames.duplicate(true)
		
		# Queue score payload for online leaderboard synchronization
		var payload: Dictionary = {
			"player_id": player_id,
			"player_name": player_name,
			"utc_date": today_utc,
			"score": score,
			"streak": daily_streak,
			"car_id": equipped_car_id
		}
		pending_score_queue.append(payload)
	
	save_to_disk()

## Equips an unlocked vehicle or registered car from VehicleDatabase.
func equip_car(car_id: String) -> bool:
	var in_db: bool = false
	if has_node("/root/VehicleDatabase"):
		var vdb = get_node("/root/VehicleDatabase")
		if vdb and vdb.has_car(car_id):
			in_db = true
	if not in_db:
		var VDBClass = load("res://scripts/autoload/vehicle_database.gd")
		if VDBClass and "VEHICLES" in VDBClass and VDBClass.VEHICLES.has(car_id):
			in_db = true
	
	if car_id in unlocked_cars or in_db or car_id == "default_coupe":
		if not (car_id in unlocked_cars):
			unlocked_cars.append(car_id)
		equipped_car_id = car_id
		save_to_disk()
		car_equipped.emit(car_id)
		return true
	return false

## Unlocks a new car ID. Returns true if newly unlocked, false if already owned.
func unlock_car(car_id: String) -> bool:
	if not (car_id in unlocked_cars):
		unlocked_cars.append(car_id)
		save_to_disk()
		car_unlocked.emit(car_id)
		return true
	return false

## Returns current shard count for a vehicle.
func get_car_shards(car_id: String) -> int:
	return int(car_shards.get(car_id, 0))

## Adds shards for a vehicle.
func add_car_shards(car_id: String, amount: int) -> void:
	var curr: int = get_car_shards(car_id)
	car_shards[car_id] = curr + amount
	save_to_disk()

## Checks if car can be upgraded with shards.
func can_upgrade_car_with_shards(car_id: String) -> bool:
	var curr_lvl: int = car_levels.get(car_id, 1)
	if curr_lvl >= 5:
		return false
	var required_shards: int = 5 if curr_lvl == 1 else (15 if curr_lvl == 2 else (30 if curr_lvl == 3 else 50))
	return get_car_shards(car_id) >= required_shards

## Upgrades car level using collected shards.
func upgrade_car_with_shards(car_id: String) -> bool:
	var curr_lvl: int = car_levels.get(car_id, 1)
	if curr_lvl >= 5:
		return false
	var required_shards: int = 5 if curr_lvl == 1 else (15 if curr_lvl == 2 else (30 if curr_lvl == 3 else 50))
	if get_car_shards(car_id) < required_shards:
		return false
	car_shards[car_id] -= required_shards
	car_levels[car_id] = curr_lvl + 1
	save_to_disk()
	car_upgraded.emit(car_id, car_levels[car_id])
	return true

## Spend cash helper. Returns true if transaction successful.
func spend_cash(amount: int) -> bool:
	if total_cash >= amount:
		total_cash -= amount
		cash_changed.emit(total_cash)
		save_to_disk()
		return true
	return false

## Add cash bonus.
func add_cash(amount: int) -> void:
	total_cash += amount
	cash_changed.emit(total_cash)
	save_to_disk()

## Add trophy road trophies.
func add_trophies(amount: int) -> void:
	total_trophies += amount
	trophies_changed.emit(total_trophies)
	save_to_disk()

## Returns path to equipped CarStats resource.
func get_equipped_car_stats_path() -> String:
	var path: String = "res://resources/vehicles/%s.tres" % equipped_car_id
	if ResourceLoader.exists(path):
		return path
	return "res://resources/vehicles/default_coupe.tres"

## Spend gems helper.
func spend_gems(amount: int) -> bool:
	if total_gems >= amount:
		total_gems -= amount
		save_to_disk()
		gems_changed.emit(total_gems)
		return true
	return false

## Add gems bonus.
func add_gems(amount: int) -> void:
	total_gems += amount
	save_to_disk()
	gems_changed.emit(total_gems)

## Spend gacha tokens helper.
func spend_gacha_tokens(amount: int) -> bool:
	if gacha_tokens >= amount:
		gacha_tokens -= amount
		save_to_disk()
		gacha_tokens_changed.emit(gacha_tokens)
		return true
	return false

## Add gacha tokens bonus.
func add_gacha_tokens(amount: int) -> void:
	gacha_tokens += amount
	save_to_disk()
	gacha_tokens_changed.emit(gacha_tokens)

## Upgrade car level (Lv 1 to 10)
func upgrade_car(car_id: String) -> bool:
	var cur_lvl: int = car_levels.get(car_id, 1)
	if cur_lvl >= 10:
		return false
	var cost: int = cur_lvl * 1000
	if spend_gems(cost):
		car_levels[car_id] = cur_lvl + 1
		save_to_disk()
		car_upgraded.emit(car_id, cur_lvl + 1)
		return true
	return false

## Upgrade gear level (Lv 1 to 10)
func upgrade_gear(gear_id: String) -> bool:
	var cur_lvl: int = gear_levels.get(gear_id, 1)
	if cur_lvl >= 10:
		return false
	var cost: int = 2500
	if spend_gems(cost):
		gear_levels[gear_id] = cur_lvl + 1
		save_to_disk()
		gear_upgraded.emit(gear_id, cur_lvl + 1)
		return true
	return false

## Equips a gear item into a 6-slot category ("engine", "wheels", "wings", "armor", "gadget", "skin")
func equip_gear_slot(slot: String, gear_id: String) -> bool:
	gear_loadout[slot] = gear_id
	save_to_disk()
	gear_loadout_changed.emit(slot, gear_id)
	return true

## Sets the skin for a vehicle
func set_car_skin(car_id: String, skin_id: String) -> bool:
	car_skins[car_id] = skin_id
	save_to_disk()
	return true

## Increments lucky pity meter
func add_lucky_spins(spins: int) -> void:
	lucky_meter = (lucky_meter + spins) % 100
	save_to_disk()
	lucky_meter_changed.emit(lucky_meter)

