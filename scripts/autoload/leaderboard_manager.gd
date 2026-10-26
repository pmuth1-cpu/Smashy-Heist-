class_name LeaderboardManagerClass
extends Node

## Online & Offline Daily Leaderboard Manager
## Handles Nakama / REST backend synchronization, offline score queues, and simulated daily rival ladders.

signal leaderboard_updated(entries: Array[Dictionary], is_online_fresh: bool)

@export var backend_url: String = ""

var _http_request: HTTPRequest
var _is_syncing: bool = false

func _ready() -> void:
	_http_request = HTTPRequest.new()
	_http_request.timeout = 5.0
	_http_request.request_completed.connect(_on_http_request_completed)
	add_child(_http_request)

## Synchronizes pending score queue with backend if reachable, otherwise generates simulated daily ladder.
func sync_pending_scores_and_fetch() -> void:
	if not backend_url.strip_edges().is_empty() and not _is_syncing:
		_is_syncing = true
		
		# Build payload from SaveManager
		var queue: Array[Dictionary] = []
		if has_node("/root/SaveManager"):
			var sm = get_node("/root/SaveManager")
			queue = sm.pending_score_queue
		
		var body: String = JSON.stringify({
			"scores": queue,
			"seed": get_current_seed()
		})
		var headers := PackedStringArray(["Content-Type: application/json"])
		var err := _http_request.request(backend_url + "/api/v1/leaderboard", headers, HTTPClient.METHOD_POST, body)
		if err == OK:
			return
		_is_syncing = false
	
	# Fallback: Generate offline/simulated deterministic ladder
	_fallback_offline_leaderboard()

func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_syncing = false
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Array:
			var online_entries: Array[Dictionary] = []
			for item in (parsed as Array):
				if item is Dictionary:
					online_entries.append(item)
			
			if has_node("/root/SaveManager"):
				var sm = get_node("/root/SaveManager")
				sm.pending_score_queue.clear()
				sm.cached_leaderboard = online_entries
				sm.save_to_disk()
			
			leaderboard_updated.emit(online_entries, true)
			return
	
	# On request failure / timeout
	_fallback_offline_leaderboard()

func _fallback_offline_leaderboard() -> void:
	var seed_val: int = get_current_seed()
	var entries := generate_simulated_leaderboard(seed_val)
	
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.cached_leaderboard = entries
		sm.save_to_disk()
	
	leaderboard_updated.emit(entries, false)

## Deterministic daily rival ladder generated based on today's seed.
func generate_simulated_leaderboard(seed_val: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var rival_names: Array[String] = [
		"ApexDrifter", "NeonPhantom", "TurboPixel", "ViperStrike",
		"SirenChaser", "GhostRacer", "BlockSmash", "RoadRogue",
		"HeistKing", "TokyoDrift", "NitroBurn", "CyberCop",
		"ShadowDriver", "AsphaltZero", "StreetRebel", "SpeedDemon"
	]
	var car_pool: Array[String] = [
		"default_coupe", "tuk_tuk_jet", "armored_bulldozer",
		"ice_cream_drifter", "cyber_interceptor"
	]
	
	var entries: Array[Dictionary] = []
	
	# Generate 14 simulated rivals
	for i in range(14):
		var r_name: String = rival_names[i % rival_names.size()]
		var r_score: int = int(rng.randf_range(9000.0, 48000.0))
		var r_streak: int = int(rng.randi_range(1, 15))
		var r_car: String = car_pool[rng.randi() % car_pool.size()]
		entries.append({
			"player_id": "bot_%04d" % i,
			"player_name": r_name,
			"score": r_score,
			"streak": r_streak,
			"car_id": r_car,
			"is_player": false
		})
	
	# Append player's personal best
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		entries.append({
			"player_id": sm.player_id,
			"player_name": sm.player_name,
			"score": sm.best_daily_score,
			"streak": sm.daily_streak,
			"car_id": sm.equipped_car_id,
			"is_player": true
		})
	
	# Sort descending by score
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)
	
	# Assign 1-based ranks
	for idx in range(entries.size()):
		entries[idx]["rank"] = idx + 1
	
	return entries

func get_current_seed() -> int:
	if has_node("/root/DailySeedManager"):
		var dsm = get_node("/root/DailySeedManager")
		return dsm.base_seed
	return Time.get_date_string_from_system(true).hash()
