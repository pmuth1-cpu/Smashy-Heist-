class_name NetworkManagerClass
extends Node

## Real-Time Network Manager Autoload for Smashy Heist: Daily Getaway.
## Handles ENet peer host/join, player registration, lobby synchronization,
## and deterministic seed replication across connected peers.

signal lobby_players_changed(players: Dictionary)
signal match_started(shared_seed: int, mode_id: int)
signal connection_failed_fallback_offline()

var is_online_match: bool = false
const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4
var players: Dictionary = {} # peer_id: int -> { "name": String, "car_id": String, "score": int, "is_ai": bool }

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

## Hosts a multiplayer game server on DEFAULT_PORT.
func host_room() -> Error:
	disconnect_network()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if err != OK:
		push_error("NetworkManager: Failed to create server on port %d, error: %d" % [DEFAULT_PORT, err])
		is_online_match = false
		return err
	
	multiplayer.multiplayer_peer = peer
	is_online_match = true
	
	var host_car_id: String = "default_coupe"
	if has_node("/root/SaveManager"):
		host_car_id = get_node("/root/SaveManager").equipped_car_id
	
	players.clear()
	players[1] = {
		"name": "Host (P1)",
		"car_id": host_car_id,
		"score": 0,
		"is_ai": false
	}
	lobby_players_changed.emit(players)
	print("NetworkManager: Server started on port %d, host registered." % DEFAULT_PORT)
	return OK

## Joins an existing game server using ip_address and DEFAULT_PORT.
func join_room(ip_address: String) -> Error:
	disconnect_network()
	var peer := ENetMultiplayerPeer.new()
	var target_ip := ip_address.strip_edges()
	if target_ip.is_empty():
		target_ip = "127.0.0.1"
	
	var err := peer.create_client(target_ip, DEFAULT_PORT)
	if err != OK:
		push_error("NetworkManager: Failed to connect to %s:%d, error: %d" % [target_ip, DEFAULT_PORT, err])
		is_online_match = false
		return err
	
	multiplayer.multiplayer_peer = peer
	is_online_match = true
	print("NetworkManager: Connecting to %s:%d..." % [target_ip, DEFAULT_PORT])
	return OK

## Cleanly disconnects and resets state to offline.
func disconnect_network() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_online_match = false
	players.clear()

func _on_peer_connected(id: int) -> void:
	print("NetworkManager: Peer connected with ID: %d" % id)
	if multiplayer.is_server():
		# Sync existing lobby to newly connected peer
		sync_lobby_players.rpc(players)

func _on_peer_disconnected(id: int) -> void:
	print("NetworkManager: Peer disconnected with ID: %d" % id)
	if multiplayer.is_server():
		players.erase(id)
		sync_lobby_players.rpc(players)
		lobby_players_changed.emit(players)

func _on_connected_to_server() -> void:
	var my_id := multiplayer.get_unique_id()
	print("NetworkManager: Successfully connected to server with local ID: %d" % my_id)
	
	var client_car_id: String = "default_coupe"
	if has_node("/root/SaveManager"):
		client_car_id = get_node("/root/SaveManager").equipped_car_id
	
	var my_data: Dictionary = {
		"name": "Player %d" % my_id,
		"car_id": client_car_id,
		"score": 0,
		"is_ai": false
	}
	register_player_rpc.rpc_id(1, my_data)

func _on_connection_failed() -> void:
	push_warning("NetworkManager: Connection failed, falling back to offline.")
	disconnect_network()
	connection_failed_fallback_offline.emit()

func _on_server_disconnected() -> void:
	push_warning("NetworkManager: Server disconnected, falling back to offline.")
	disconnect_network()
	connection_failed_fallback_offline.emit()

@rpc("any_peer", "call_local", "reliable")
func register_player_rpc(player_data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	players[sender_id] = player_data
	sync_lobby_players.rpc(players)
	lobby_players_changed.emit(players)

@rpc("authority", "call_local", "reliable")
func sync_lobby_players(all_players: Dictionary) -> void:
	players = all_players.duplicate(true)
	lobby_players_changed.emit(players)

@rpc("authority", "call_local", "reliable")
func start_multiplayer_match(shared_seed: int) -> void:
	print("NetworkManager: Starting multiplayer match with shared seed: %d" % shared_seed)
	if has_node("/root/DailySeedManager"):
		var dsm = get_node("/root/DailySeedManager")
		dsm.base_seed = shared_seed
		dsm.current_mode = DailySeedManagerClass.SeedMode.ENDLESS_RANDOM
		dsm.daily_modifier_index = absi(shared_seed) % 4
	
	match_started.emit(shared_seed, 1)
	
	# Transition to main_game.tscn if not already running or reloads
	var tree := get_tree()
	if tree and tree.current_scene:
		if tree.current_scene.scene_file_path == "res://scenes/world/main_game.tscn":
			var main_node = tree.current_scene
			if main_node.has_method("restart_with_seed"):
				main_node.restart_with_seed(shared_seed)
		else:
			tree.change_scene_to_file("res://scenes/world/main_game.tscn")

