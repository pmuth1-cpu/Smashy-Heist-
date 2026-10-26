class_name SocialFriendManagerClass
extends Node

## Phase 12: Friends Code System & 3D Squad Lobby Manager
## Registered as Autoload "SocialFriendManager" in project.godot
## Coordinates friend codes, squad invitations, 3D showroom squad pedestals, and squad match dispatch.

signal squad_updated()
signal friend_added(friend_data: Dictionary)
signal friend_code_copied()

# Active squad members invited to the lobby (excluding host, up to 3 peers -> 4-car squad)
var active_squad_members: Array[Dictionary] = []

const MAX_SQUAD_MEMBERS: int = 3 # 1 host + 3 invited friends = 4 players max

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Returns user's unique shareable 6-character Friend Code
func get_player_friend_code() -> String:
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if not sm.friend_code.is_empty():
			return sm.friend_code
	return "#SH-7777"

## Copies friend code to OS clipboard with UI feedback
func copy_friend_code_to_clipboard() -> String:
	var code := get_player_friend_code()
	DisplayServer.clipboard_set(code)
	friend_code_copied.emit()
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_ui_click()
	return code

## Returns current friends list from SaveManager
func get_friends_list() -> Array[Dictionary]:
	if has_node("/root/SaveManager"):
		return get_node("/root/SaveManager").friends_list
	return []

## Adds a friend by typing a code (e.g. "#SH-9021")
func add_friend_by_code(input_code: String) -> Dictionary:
	var clean_code: String = input_code.strip_edges().to_upper()
	if not clean_code.begins_with("#"):
		clean_code = "#" + clean_code
	if not clean_code.begins_with("#SH-") and clean_code.length() >= 5:
		clean_code = "#SH-" + clean_code.substr(1)
	
	if clean_code.length() < 7:
		return {}
	
	# Check if already added
	var friends := get_friends_list()
	for f in friends:
		if String(f.get("code", "")).to_upper() == clean_code:
			return f
	
	# Create synthetic buddy with deterministic attributes from code seed
	var hash_seed: int = absi(clean_code.hash())
	var car_keys: Array[String] = ["default_coupe", "tuk_tuk_jet", "armored_bulldozer", "ice_cream_drifter", "cyber_interceptor", "monster_pickup"]
	var chosen_car: String = car_keys[hash_seed % car_keys.size()]
	var random_names: Array[String] = ["SpeedDemon", "DriftKing", "HeistGod", "ShadowRacer", "ApexBrawler", "TurboCrash"]
	var buddy_name: String = "%s_%s" % [random_names[hash_seed % random_names.size()], clean_code.right(3)]
	
	var new_friend: Dictionary = {
		"code": clean_code,
		"name": buddy_name,
		"car_id": chosen_car,
		"trophies": 1200 + (hash_seed % 2800),
		"streak": 1 + (hash_seed % 14),
		"status": "🟢 ONLINE",
		"loadout": {
			"weapon_mod": "rockets_twin" if hash_seed % 2 == 0 else "emp_dome",
			"drift_trail": "underglow_cyan" if hash_seed % 2 == 0 else "trail_cyber_purple",
			"armor_mod": "bumper_spiked" if hash_seed % 2 == 0 else "bumper_standard"
		}
	}
	
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").add_friend(new_friend)
	
	friend_added.emit(new_friend)
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_ui_click()
	return new_friend

## Invites a friend to join the active squad lobby
func invite_friend_to_squad(friend_data: Dictionary) -> bool:
	if active_squad_members.size() >= MAX_SQUAD_MEMBERS:
		return false
	
	var code: String = String(friend_data.get("code", ""))
	for m in active_squad_members:
		if String(m.get("code", "")) == code:
			return false # Already in squad
	
	var member := friend_data.duplicate(true)
	member["ready"] = true
	member["squad_slot"] = active_squad_members.size() + 1
	active_squad_members.append(member)
	squad_updated.emit()
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_ui_click()
	return true

## Checks if a friend code is currently in squad
func is_friend_in_squad(code: String) -> bool:
	for m in active_squad_members:
		if String(m.get("code", "")).to_upper() == code.to_upper():
			return true
	return false

## Removes a friend from squad lobby
func remove_squad_member(index: int) -> void:
	if index >= 0 and index < active_squad_members.size():
		active_squad_members.remove_at(index)
		# Re-index remaining squad slots
		for i in range(active_squad_members.size()):
			active_squad_members[i]["squad_slot"] = i + 1
		squad_updated.emit()

## Clears all squad members
func clear_squad() -> void:
	active_squad_members.clear()
	squad_updated.emit()
