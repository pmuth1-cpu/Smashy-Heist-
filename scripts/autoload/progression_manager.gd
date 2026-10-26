class_name ProgressionManagerClass
extends Node

## Phase 12: 7-Day Login Calendar & 3 Rotating Daily Quests + Heist Safe
## Registered as Autoload "ProgressionManager" in project.godot
## Manages deterministic daily reward progression, mid-run quest milestones, and heist safe unlocks.

signal login_reward_claimed(day_index: int, reward: Dictionary)
signal quest_progress_updated(quest_id: String, current: int, target: int)
signal quest_completed(quest: Dictionary)
signal quest_reward_claimed(quest_id: String, reward_amount: int)
signal heist_safe_claimed(reward_cash: int, item_id: String)
signal quest_toast_requested(message: String)

const LOGIN_REWARDS: Array[Dictionary] = [
	{
		"day": 1,
		"title": "+250 CASH",
		"subtitle": "GETAWAY FUNDS",
		"category": "CURRENCY",
		"type": "cash",
		"amount": 250,
		"icon": "💵",
		"texture_path": "res://assets/ui/icon_cash_stack.png",
		"accent_color": Color("2ecc71"),
		"desc": "Fresh start bonus for today's getaway run!"
	},
	{
		"day": 2,
		"title": "CYAN UNDERGLOW",
		"subtitle": "NEON CHASSIS AURA",
		"category": "TUNING GEAR",
		"type": "item",
		"item_id": "underglow_cyan",
		"slot": "drift_trail",
		"icon": "💡",
		"texture_path": "res://assets/textures/gear/gear_gadget.png",
		"accent_color": Color("00d2d3"),
		"desc": "Downward-facing vibrant cyan neon ground aura."
	},
	{
		"day": 3,
		"title": "+500 CASH",
		"subtitle": "WALLET BOOST",
		"category": "CURRENCY",
		"type": "cash",
		"amount": 500,
		"icon": "💵",
		"texture_path": "res://assets/ui/icon_cash_stack.png",
		"accent_color": Color("2ecc71"),
		"desc": "Heavy wallet boost for car tuning & gacha!"
	},
	{
		"day": 4,
		"title": "SPIKED RAM BULLBAR",
		"subtitle": "+35% RAM KNOCKBACK",
		"category": "BULLBAR ARMOR",
		"type": "item",
		"item_id": "bumper_spiked",
		"slot": "armor_mod",
		"icon": "🛡️",
		"texture_path": "res://assets/textures/gear/gear_armor.png",
		"accent_color": Color("e67e22"),
		"desc": "Heavy steel bullbar with +35% ram knockback on cops."
	},
	{
		"day": 5,
		"title": "MEGA BRAWL BOX",
		"subtitle": "+600 CASH VALUE",
		"category": "EPIC REWARD",
		"type": "cash",
		"amount": 600,
		"icon": "🎁",
		"texture_path": "res://assets/textures/ui/gacha_chest_closed.jpg",
		"accent_color": Color("9b59b6"),
		"desc": "+600 Cash value for unlocking rare brawlers."
	},
	{
		"day": 6,
		"title": "GOLD FLAME TRAIL",
		"subtitle": "FIRE DRIFT SMOKE",
		"category": "DRIFT TRAIL",
		"type": "item",
		"item_id": "trail_gold_flame",
		"slot": "drift_trail",
		"icon": "🔥",
		"texture_path": "res://assets/textures/gear/gear_wings.png",
		"accent_color": Color("f39c12"),
		"desc": "Turns tire drift smoke into blazing gold & fire sparks."
	},
	{
		"day": 7,
		"title": "APEX F1 + $1,000",
		"subtitle": "SUPERSONIC BRAWLER",
		"category": "GRAND PRIZE",
		"type": "grand_prize",
		"car_id": "f1_street_kart",
		"amount": 1000,
		"icon": "🏎️",
		"texture_path": "res://assets/items/icon_cartoon_chest_day7.png",
		"accent_color": Color("f1c40f"),
		"desc": "GRAND PRIZE! Legendary supersonic Formula brawler."
	}
]

const ALL_GEAR_POOL: Array[String] = [
	"rockets_twin", "emp_dome", "magnet_dish",
	"underglow_cyan", "trail_gold_flame", "trail_cyber_purple",
	"bumper_standard", "bumper_spiked", "armor_titanium"
]

var login_day_index: int = 1
var last_claimed_login_utc: String = ""
var claimed_login_days: Array[int] = []

var daily_quests: Array[Dictionary] = []
var daily_quests_date_utc: String = ""
var daily_heist_safe_claimed: bool = false

# In-run drift accumulator to prevent excessive calls
var _drift_accumulator: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_state_from_save()
	check_daily_reset()

## Synchronizes local state with SaveManager
func _load_state_from_save() -> void:
	if not has_node("/root/SaveManager"):
		return
	var sm = get_node("/root/SaveManager")
	login_day_index = clampi(sm.login_day_index, 1, 7)
	last_claimed_login_utc = sm.last_claimed_login_utc
	claimed_login_days = sm.claimed_login_days.duplicate()
	daily_quests = sm.daily_quests.duplicate(true)
	daily_quests_date_utc = sm.daily_quests_date_utc
	daily_heist_safe_claimed = sm.daily_heist_safe_claimed

## Pushes state back to SaveManager
func _persist_state() -> void:
	if not has_node("/root/SaveManager"):
		return
	var sm = get_node("/root/SaveManager")
	sm.login_day_index = login_day_index
	sm.last_claimed_login_utc = last_claimed_login_utc
	sm.claimed_login_days = claimed_login_days.duplicate()
	sm.daily_quests = daily_quests.duplicate(true)
	sm.daily_quests_date_utc = daily_quests_date_utc
	sm.daily_heist_safe_claimed = daily_heist_safe_claimed
	sm.save_to_disk()

## Checks UTC date rollover for quests and calendar claims
func check_daily_reset() -> void:
	var today_utc: String = Time.get_date_string_from_system(true)
	
	# Generate 3 Daily Quests if not yet created for today
	if daily_quests_date_utc != today_utc or daily_quests.is_empty():
		daily_quests_date_utc = today_utc
		daily_heist_safe_claimed = false
		daily_quests = [
			{
				"id": "quest_cops",
				"title": "Juke or Wreck 6 Police Cars",
				"type": "cop_wreck",
				"current": 0,
				"target": 6,
				"reward": 150,
				"claimed": false,
				"icon": "🚓"
			},
			{
				"id": "quest_drift",
				"title": "Drift for 20 Seconds Total",
				"type": "drift_time",
				"current": 0,
				"target": 20,
				"reward": 150,
				"claimed": false,
				"icon": "💨"
			},
			{
				"id": "quest_props",
				"title": "Smash 25 Street Props or Cars",
				"type": "prop_smash",
				"current": 0,
				"target": 25,
				"reward": 150,
				"claimed": false,
				"icon": "💥"
			}
		]
		_persist_state()

# ==============================================================================
# 7-DAY LOGIN CALENDAR API
# ==============================================================================

## Returns true if today's reward has not yet been claimed
func can_claim_today_login() -> bool:
	var today_utc: String = Time.get_date_string_from_system(true)
	return last_claimed_login_utc != today_utc

## Returns reward metadata for day (1 to 7)
func get_reward_for_day(day: int) -> Dictionary:
	var idx: int = clampi(day - 1, 0, LOGIN_REWARDS.size() - 1)
	return LOGIN_REWARDS[idx]

## Claims today's login reward, grants payload, and advances day index
func claim_today_login() -> Dictionary:
	if not can_claim_today_login():
		return {}
	
	var day_to_claim: int = login_day_index
	var reward: Dictionary = get_reward_for_day(day_to_claim)
	var today_utc: String = Time.get_date_string_from_system(true)
	
	last_claimed_login_utc = today_utc
	if not (day_to_claim in claimed_login_days):
		claimed_login_days.append(day_to_claim)
	
	# Grant rewards via SaveManager
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		var r_type: String = String(reward.get("type", "cash"))
		
		match r_type:
			"cash":
				sm.add_cash(int(reward.get("amount", 250)))
			"item":
				var i_id: String = String(reward.get("item_id", ""))
				sm.unlock_item(i_id)
			"grand_prize":
				var c_id: String = String(reward.get("car_id", "f1_street_kart"))
				sm.unlock_car(c_id)
				sm.add_cash(int(reward.get("amount", 1000)))
	
	# Advance day index (loops 1..7)
	if day_to_claim >= 7:
		login_day_index = 1
		claimed_login_days.clear()
	else:
		login_day_index += 1
	
	_persist_state()
	login_reward_claimed.emit(day_to_claim, reward)
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_star_up()
	
	return reward

# ==============================================================================
# 3 ROTATING DAILY QUESTS API
# ==============================================================================

## Adds progress towards active daily quests (called by gameplay hooks)
func add_quest_progress(quest_type: String, amount: int) -> void:
	if amount <= 0:
		return
	
	for quest in daily_quests:
		if quest.get("type", "") == quest_type and not quest.get("claimed", false):
			var cur: int = int(quest.get("current", 0))
			var tar: int = int(quest.get("target", 1))
			var was_done: bool = (cur >= tar)
			
			cur = mini(tar, cur + amount)
			quest["current"] = cur
			quest_progress_updated.emit(String(quest.get("id", "")), cur, tar)
			
			if not was_done and cur >= tar:
				quest_completed.emit(quest)
				var toast_msg := "✅ DAILY QUEST COMPLETE! +%d 💵\n%s" % [
					int(quest.get("reward", 150)),
					String(quest.get("title", ""))
				]
				quest_toast_requested.emit(toast_msg)
				_show_hud_toast(toast_msg)
	
	_persist_state()

## Accumulates floating drift seconds before committing integer quest progress
func add_drift_seconds(delta_sec: float) -> void:
	_drift_accumulator += delta_sec
	if _drift_accumulator >= 1.0:
		var whole_secs: int = int(_drift_accumulator)
		_drift_accumulator -= float(whole_secs)
		add_quest_progress("drift_time", whole_secs)

## Claims reward for completed quest
func claim_quest_reward(quest_id: String) -> bool:
	for quest in daily_quests:
		if quest.get("id", "") == quest_id:
			var cur: int = int(quest.get("current", 0))
			var tar: int = int(quest.get("target", 1))
			var claimed: bool = bool(quest.get("claimed", false))
			
			if cur >= tar and not claimed:
				quest["claimed"] = true
				var rew: int = int(quest.get("reward", 150))
				if has_node("/root/SaveManager"):
					get_node("/root/SaveManager").add_cash(rew)
				
				_persist_state()
				quest_reward_claimed.emit(quest_id, rew)
				if has_node("/root/SoundFX"):
					get_node("/root/SoundFX").play_star_up()
				return true
	return false

# ==============================================================================
# DAILY HEIST SAFE API (0/3 Quests Claimed -> +400 Cash & Gear)
# ==============================================================================

## Returns number of claimed daily quests (0 to 3)
func get_claimed_quests_count() -> int:
	var count: int = 0
	for q in daily_quests:
		if q.get("claimed", false):
			count += 1
	return count

## Returns true if all 3 quests have been claimed and safe not yet opened today
func can_claim_heist_safe() -> bool:
	return get_claimed_quests_count() >= 3 and not daily_heist_safe_claimed

## Unlocks Daily Heist Safe, awards +400 Cash and a random locked gear item
func claim_heist_safe() -> Dictionary:
	if not can_claim_heist_safe():
		return {}
	
	daily_heist_safe_claimed = true
	var cash_bonus: int = 400
	var awarded_item_id: String = ""
	
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.add_cash(cash_bonus)
		
		# Find unowned items from ALL_GEAR_POOL
		var locked_items: Array[String] = []
		for item in ALL_GEAR_POOL:
			if not (item in sm.unlocked_items):
				locked_items.append(item)
		
		if not locked_items.is_empty():
			awarded_item_id = locked_items[randi() % locked_items.size()]
			sm.unlock_item(awarded_item_id)
		else:
			# Fallback if player owns all items: extra cash
			sm.add_cash(300)
			cash_bonus += 300
	
	_persist_state()
	heist_safe_claimed.emit(cash_bonus, awarded_item_id)
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_explosion()
	
	return { "cash": cash_bonus, "item_id": awarded_item_id }

## Returns true if any reward notification dot should be active
func has_unclaimed_rewards() -> bool:
	if can_claim_today_login():
		return true
	if can_claim_heist_safe():
		return true
	for q in daily_quests:
		if int(q.get("current", 0)) >= int(q.get("target", 1)) and not bool(q.get("claimed", false)):
			return true
	return false

## Non-intrusive green toast banner on TouchHUD
func _show_hud_toast(msg: String) -> void:
	var hud := get_tree().root.find_child("TouchHUD", true, false)
	if hud and hud.has_method("show_quest_toast"):
		hud.show_quest_toast(msg)

## Trophy Road progression
func add_trophies(amount: int) -> void:
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if sm.has_method("add_trophies"):
			sm.add_trophies(amount)

func get_trophies() -> int:
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if "total_trophies" in sm:
			return int(sm.total_trophies)
	return 1250
