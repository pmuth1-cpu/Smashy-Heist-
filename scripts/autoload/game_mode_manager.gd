class_name GameModeManagerClass
extends Node

## Central Game Mode Manager for Smashy Heist: Daily Getaway.
## Controls game modes, mode metadata, mode objectives, and mode-specific transitions:
## 1. DAILY_ENDLESS_GETAWAY: Classic escalating 5-star police getaway & daily leaderboard
## 2. ESCAPE_MEGA_BOSS: Epic battle against Mecha-Crusher Dozer & Goliath Chopper
## 3. HOT_LOOT_4P_TAG: 4-player tag mode with golden Crown Bag and AI bot backfill
## 4. SMASHY_KART_GP: 3-Lap 6-Racer Circuit Mode with Mario Kart items, drift turbos & rocket start

enum GameMode {
	DAILY_ENDLESS_GETAWAY = 0,
	ESCAPE_MEGA_BOSS = 1,
	HOT_LOOT_4P_TAG = 2,
	SMASHY_KART_GP = 3
}

enum KartCupTrack {
	DOWNTOWN_NEON_CIRCUIT = 0,
	CHINATOWN_DRAGON_LOOP = 1,
	CANYON_HIGHWAY_SPEEDWAY = 2
}

const KART_TRACK_METADATA: Dictionary = {
	0: {
		"title": "Downtown Neon Circuit",
		"desc": "Nighttime asphalt with glowing cyan/magenta barriers, skyscraper grandstands, and fountain shortcut.",
		"color": Color("00d2d3")
	},
	1: {
		"title": "Chinatown Dragon Loop",
		"desc": "Crimson pagoda arches, red lantern canopies, and a tight 270-degree spiral drift corner.",
		"color": Color("ff3f34")
	},
	2: {
		"title": "Canyon Highway Speedway",
		"desc": "Terracotta desert canyon walls, high-banked sweeping curves, and a giant broken-bridge jump!",
		"color": Color("f39c12")
	}
}

signal mode_changed(new_mode: GameMode)
signal mode_objective_updated(text: String, progress: float)
signal kart_track_changed(new_track: KartCupTrack)

var current_mode: GameMode = GameMode.DAILY_ENDLESS_GETAWAY
var selected_cup_track: KartCupTrack = KartCupTrack.DOWNTOWN_NEON_CIRCUIT

const MODE_METADATA: Dictionary = {
	0: {
		"title": "DAILY & ENDLESS GETAWAY",
		"icon": "🔥",
		"subtitle": "Survive escalating 5-Star heat & climb the global seed leaderboard!",
		"theme_color": Color("f39c12")
	},
	1: {
		"title": "ESCAPE THE MEGA-BOSS",
		"icon": "🕷️",
		"subtitle": "Survive the Steampunk Spider Mech & Goliath Laser Chopper!",
		"theme_color": Color("9b59b6")
	},
	2: {
		"title": "4P HOT LOOT TAG (ONLINE/BOTS)",
		"icon": "👑",
		"subtitle": "Ram rivals to steal the Crown Bag while all cops chase the leader!",
		"theme_color": Color("00d2d3")
	},
	3: {
		"title": "🏁 SMASHY KART GRAND PRIX",
		"icon": "🏎️",
		"subtitle": "3-Lap 6-Racer Circuit! Grab Rainbow Item Boxes, chain 3-Stage Drift Turbos & blast 1st Place!",
		"theme_color": Color("ff3f34")
	}
}

func _ready() -> void:
	pass

func set_mode(mode: int) -> void:
	current_mode = clampi(mode, 0, get_mode_count() - 1) as GameMode
	mode_changed.emit(current_mode)

func set_kart_cup_track(track: int) -> void:
	selected_cup_track = clampi(track, 0, 2) as KartCupTrack
	kart_track_changed.emit(selected_cup_track)

func get_kart_track_info(track: int = -1) -> Dictionary:
	var t_idx: int = int(selected_cup_track) if track < 0 else track
	return KART_TRACK_METADATA.get(t_idx, KART_TRACK_METADATA[0])

func get_mode_info(mode: int) -> Dictionary:
	return MODE_METADATA.get(int(mode), MODE_METADATA[0])

func get_current_mode_info() -> Dictionary:
	return get_mode_info(current_mode)

func get_mode_count() -> int:
	return MODE_METADATA.size()

func update_objective(text: String, progress: float = -1.0) -> void:
	mode_objective_updated.emit(text, progress)
