class_name MultiplayerLobby
extends Control

## Mobile Home Menu and Lobby UI for Smashy Heist: Daily Getaway.
## Features mode selection:
## 1. Play Daily Seed Getaway (Solo challenge with ghost car)
## 2. 4P Hot Loot Tag (Online ENet Host/Join or quickplay with AI Rival backfill after 4s)
## 3. Garage & Leaderboards

signal mode_selected(mode_id: int) # 0: SOLO_DAILY, 1: HOT_LOOT
signal garage_requested()
signal leaderboard_requested()

@onready var main_menu_box: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/MainMenuBox
@onready var hot_loot_box: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/HotLootBox

# Main Menu Buttons
@onready var play_daily_btn: Button = $CenterContainer/PanelContainer/MarginContainer/MainMenuBox/PlayDailyButton
@onready var hot_loot_btn: Button = $CenterContainer/PanelContainer/MarginContainer/MainMenuBox/HotLootButton
@onready var garage_btn: Button = $CenterContainer/PanelContainer/MarginContainer/MainMenuBox/GarageButton
@onready var subtitle_label: Label = $CenterContainer/PanelContainer/MarginContainer/MainMenuBox/SubtitleLabel

# Hot Loot Room Controls
@onready var room_status_label: Label = $CenterContainer/PanelContainer/MarginContainer/HotLootBox/RoomStatusLabel
@onready var players_list_label: Label = $CenterContainer/PanelContainer/MarginContainer/HotLootBox/PlayersListLabel
@onready var auto_start_label: Label = $CenterContainer/PanelContainer/MarginContainer/HotLootBox/AutoStartLabel
@onready var ip_line_edit: LineEdit = $CenterContainer/PanelContainer/MarginContainer/HotLootBox/JoinBox/IPLineEdit
@onready var join_btn: Button = $CenterContainer/PanelContainer/MarginContainer/HotLootBox/JoinBox/JoinButton
@onready var host_btn: Button = $CenterContainer/PanelContainer/MarginContainer/HotLootBox/HostButton
@onready var start_now_btn: Button = $CenterContainer/PanelContainer/MarginContainer/HotLootBox/StartNowButton
@onready var back_btn: Button = $CenterContainer/PanelContainer/MarginContainer/HotLootBox/BackButton

var _auto_start_timer: float = 4.0
var _auto_start_active: bool = false

func _ready() -> void:
	visible = true
	main_menu_box.visible = true
	hot_loot_box.visible = false
	
	play_daily_btn.pressed.connect(_on_play_daily_pressed)
	hot_loot_btn.pressed.connect(_on_hot_loot_pressed)
	garage_btn.pressed.connect(_on_garage_pressed)
	
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	start_now_btn.pressed.connect(_on_start_now_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	
	if has_node("/root/DailySeedManager"):
		var dsm = get_node("/root/DailySeedManager")
		subtitle_label.text = "TODAY'S MODIFIER: %s" % dsm.get_modifier_name()
	
	if has_node("/root/NetworkManager"):
		var nm = get_node("/root/NetworkManager")
		nm.lobby_players_changed.connect(_on_lobby_players_changed)
		nm.connection_failed_fallback_offline.connect(_on_connection_failed)

func _process(delta: float) -> void:
	if _auto_start_active and hot_loot_box.visible:
		_auto_start_timer -= delta
		auto_start_label.text = "⏱️ Auto-filling with AI Rivals in: %.1fs" % maxf(0.0, _auto_start_timer)
		if _auto_start_timer <= 0.0:
			_auto_start_active = false
			_launch_hot_loot_match()

func _on_play_daily_pressed() -> void:
	visible = false
	_auto_start_active = false
	if has_node("/root/DailySeedManager"):
		var dsm = get_node("/root/DailySeedManager")
		dsm.init_seed(DailySeedManagerClass.SeedMode.DAILY_CHALLENGE)
	
	mode_selected.emit(0)
	
	var main = get_tree().root.find_child("MainGame", true, false)
	if main and main.has_method("start_solo_daily_mode"):
		main.start_solo_daily_mode()

func _on_hot_loot_pressed() -> void:
	main_menu_box.visible = false
	hot_loot_box.visible = true
	
	# Automatically initialize host room
	if has_node("/root/NetworkManager"):
		var nm = get_node("/root/NetworkManager")
		nm.host_room()
	
	room_status_label.text = "Lobby Ready (Host). Waiting for players or auto-starting..."
	_auto_start_timer = 4.0
	_auto_start_active = true
	_update_players_display()

func _on_host_pressed() -> void:
	if has_node("/root/NetworkManager"):
		var nm: NetworkManagerClass = get_node("/root/NetworkManager") as NetworkManagerClass
		var err: Error = nm.host_room()
		if err == OK:
			room_status_label.text = "Room hosted on port %d. Waiting for peers..." % nm.DEFAULT_PORT
			_auto_start_timer = 4.0
			_auto_start_active = true
		else:
			room_status_label.text = "Failed to host room (Error %d)." % err

func _on_join_pressed() -> void:
	_auto_start_active = false
	auto_start_label.text = "Connecting to host..."
	var ip_text := ip_line_edit.text.strip_edges()
	if ip_text.is_empty():
		ip_text = "127.0.0.1"
	
	if has_node("/root/NetworkManager"):
		var nm: NetworkManagerClass = get_node("/root/NetworkManager") as NetworkManagerClass
		var err: Error = nm.join_room(ip_text)
		if err == OK:
			room_status_label.text = "Connected to %s! Waiting for host to start..." % ip_text
		else:
			room_status_label.text = "Connection error (%d)." % err


func _on_start_now_pressed() -> void:
	_auto_start_active = false
	_launch_hot_loot_match()

func _on_back_pressed() -> void:
	_auto_start_active = false
	if has_node("/root/NetworkManager"):
		var nm = get_node("/root/NetworkManager")
		nm.disconnect_network()
	
	hot_loot_box.visible = false
	main_menu_box.visible = true

func _on_garage_pressed() -> void:
	garage_requested.emit()

func _on_lobby_players_changed(_players: Dictionary) -> void:
	_update_players_display()

func _on_connection_failed() -> void:
	room_status_label.text = "Connection failed. Falling back to offline match."
	_auto_start_timer = 2.0
	_auto_start_active = true

func _update_players_display() -> void:
	var count: int = 1
	var txt: String = ""
	if has_node("/root/NetworkManager"):
		var nm = get_node("/root/NetworkManager")
		count = nm.players.size()
		var idx: int = 1
		for pid in nm.players:
			var pinfo: Dictionary = nm.players[pid]
			var pname: String = str(pinfo.get("name", "Player %d" % pid))
			var is_h: String = " (Host)" if pid == 1 else ""
			txt += "🏎️ Slot %d: %s%s\n" % [idx, pname, is_h]
			idx += 1
		
		# Fill open slots with AI Bot indicators
		for i in range(idx, 5):
			txt += "🤖 Slot %d: [AI Rival Bot Backfill]\n" % i
	else:
		txt = "🏎️ Slot 1: Player 1 (Local)\n🤖 Slot 2: [AI Rival Bot]\n🤖 Slot 3: [AI Rival Bot]\n🤖 Slot 4: [AI Rival Bot]\n"
	
	players_list_label.text = txt
	room_status_label.text = "Players in Room: %d / 4 (Open slots filled by AI)" % count

func _launch_hot_loot_match() -> void:
	visible = false
	mode_selected.emit(1)
	
	var shared_seed: int = randi()
	if has_node("/root/NetworkManager"):
		var nm = get_node("/root/NetworkManager")
		if nm.is_online_match and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			nm.start_multiplayer_match.rpc(shared_seed)
			return

	
	var main = get_tree().root.find_child("MainGame", true, false)
	if main and main.has_method("start_hot_loot_mode"):
		main.start_hot_loot_mode(shared_seed)
