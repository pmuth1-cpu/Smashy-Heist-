class_name WantedManagerClass
extends Node

## Phase 3: Wanted Escalation & Run Scoring Singleton
## Manages heat level escalation, score accumulation, combo timers, and run lifecycle.

signal wanted_star_changed(new_stars: int, star_title: String)
signal score_updated(current_score: int, combo_multiplier: int)
signal run_started(seed_value: int, modifier_name: String)
signal player_busted(reason: String, final_score: int, survival_seconds: float, cops_wrecked: int)
signal perk_applied(perk_id: String)
signal player_surrounded(cops_count: int)
signal player_escaped_surround()

var is_run_active: bool = false
var survival_time: float = 0.0
var current_score: int = 0
var combo_multiplier: int = 1
var combo_timer: float = 0.0
var cops_wrecked: int = 0
var wanted_stars: int = 1
var max_active_units: int = 3
var active_perks: Array[String] = []

# Surrounded mechanic tracking
var is_surrounded: bool = false
var surrounded_duration: float = 0.0
var surrounded_heat_timer: float = 0.0

# Persistent on-foot player health (prevents health restoration exploit across vehicles)
var player_persistent_hp: float = 100.0

# Tracks the exact character or vehicle the player was lastly using for death/wasted cutscenes
var last_wasted_target: Node3D = null
var last_active_car: Node3D = null

var _survival_score_accumulator: float = 0.0

const STAR_DEFINITIONS: Array[Dictionary] = [
	{ "stars": 1, "threshold": 0.0, "title": "Patrol Alert", "units": 3 },
	{ "stars": 2, "threshold": 20.0, "title": "Interceptor Pursuit", "units": 5 },
	{ "stars": 3, "threshold": 45.0, "title": "SWAT Response", "units": 7 },
	{ "stars": 4, "threshold": 75.0, "title": "Air Support", "units": 9 },
	{ "stars": 5, "threshold": 110.0, "title": "Military Lockdown", "units": 12 },
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not is_run_active:
		return
	
	# 1. Survival time & score (paced score accumulation)
	survival_time += delta
	_survival_score_accumulator += 5.0 * float(wanted_stars) * delta
	if _survival_score_accumulator >= 1.0:
		var pts: int = int(_survival_score_accumulator)
		_survival_score_accumulator -= float(pts)
		current_score += pts
		score_updated.emit(current_score, combo_multiplier)
	
	# 2. Combo timer decay
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_multiplier = 1
			score_updated.emit(current_score, combo_multiplier)
	
	# 3. Escalation check
	var target_stars: int = 1
	var target_title: String = "Patrol Alert"
	var target_units: int = 3
	
	for def in STAR_DEFINITIONS:
		if survival_time >= float(def["threshold"]):
			target_stars = int(def["stars"])
			target_title = String(def["title"])
			target_units = int(def["units"])
	
	if target_stars > wanted_stars:
		wanted_stars = target_stars
		max_active_units = target_units
		wanted_star_changed.emit(wanted_stars, target_title)
		if has_node("/root/SoundFX"):
			var sfx = get_node("/root/SoundFX")
			sfx.play_star_up()
	else:
		max_active_units = target_units

## Called by ArcadeCar when multiple police cruisers surround the player
func register_surrounded_pressure(delta: float, surrounding_cops: int) -> void:
	if not is_run_active:
		return
	
	if surrounding_cops >= 2:
		if not is_surrounded:
			is_surrounded = true
			player_surrounded.emit(surrounding_cops)
			if has_node("/root/SoundFX"):
				var sfx = get_node("/root/SoundFX")
				if sfx.has_method("play_police_siren"):
					sfx.play_police_siren()
		
		surrounded_duration += delta
		surrounded_heat_timer += delta
		
		# Surrounding slightly accelerates survival heat by +0.35s per real second
		survival_time += delta * 0.35
		
		# Being surrounded continuously by 3+ cops for 15.0s triggers +1 Wanted Star escalation
		if surrounding_cops >= 3 and surrounded_heat_timer >= 15.0 and wanted_stars < 5:
			surrounded_heat_timer = 0.0
			escalate_wanted_level("POLICE SURROUNDED!")
	else:
		if is_surrounded:
			is_surrounded = false
			surrounded_duration = 0.0
			surrounded_heat_timer = 0.0
			player_escaped_surround.emit()

## Manually escalates wanted stars (used by surrounded mechanic, bank heist, etc.)
func escalate_wanted_level(reason: String = "") -> void:
	if not is_run_active or wanted_stars >= 5:
		return
	wanted_stars += 1
	var def_index: int = mini(wanted_stars - 1, STAR_DEFINITIONS.size() - 1)
	var title: String = String(STAR_DEFINITIONS[def_index]["title"])
	max_active_units = int(STAR_DEFINITIONS[def_index]["units"])
	wanted_star_changed.emit(wanted_stars, title)
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		sfx.play_star_up()
	var hud = get_tree().root.find_child("TouchHUD", true, false)
	if hud and hud.has_method("spawn_floating_text"):
		var banner: String = "⭐ %d STARS: %s!" % [wanted_stars, title]
		if not reason.is_empty():
			banner = "⚠️ %s (⭐ %d STARS)" % [reason, wanted_stars]
		hud.spawn_floating_text(Vector3.ZERO, banner, Color("ff4757"), 1.8)

## Starts a fresh getaway run and resets all counters.
func start_new_run() -> void:
	is_run_active = true
	survival_time = 0.0
	current_score = 0
	combo_multiplier = 1
	combo_timer = 0.0
	cops_wrecked = 0
	wanted_stars = 1
	max_active_units = 3
	_survival_score_accumulator = 0.0
	active_perks.clear()
	is_surrounded = false
	surrounded_duration = 0.0
	surrounded_heat_timer = 0.0
	player_persistent_hp = 100.0
	
	var seed_val: int = 0
	var mod_name: String = "Standard Getaway"
	if has_node("/root/DailySeedManager"):
		var mgr = get_node("/root/DailySeedManager")
		seed_val = mgr.base_seed
		mod_name = mgr.get_modifier_name()
	
	run_started.emit(seed_val, mod_name)
	score_updated.emit(current_score, combo_multiplier)
	wanted_star_changed.emit(wanted_stars, "Patrol Alert")

## Adds score with combo multiplier from smashed props.
func add_prop_score(base_points: int) -> void:
	if not is_run_active:
		return
	
	combo_multiplier = mini(5, combo_multiplier + 1)
	combo_timer = 3.0
	current_score += base_points * combo_multiplier
	score_updated.emit(current_score, combo_multiplier)

## Adds raw score points (used by near-miss bonuses and mode events)
func add_score(pts: int) -> void:
	current_score += pts
	score_updated.emit(current_score, combo_multiplier)

## Registers a destroyed police unit for score & stats.
func register_cop_wrecked() -> void:
	if not is_run_active:
		return
	
	cops_wrecked += 1
	current_score += 250 * combo_multiplier
	survival_time += 3.5 # Wrecking police accelerates wanted star progression!
	score_updated.emit(current_score, combo_multiplier)
	hit_stop()
	
	if has_node("/root/ProgressionManager"):
		get_node("/root/ProgressionManager").add_quest_progress("cop_wreck", 1)

## Checks if a roguelike star-up perk is active in the current run
func has_perk(perk_id: String) -> bool:
	return active_perks.has(perk_id)

## Applies a roguelike perk for the duration of the current run
func apply_perk(perk_id: String) -> void:
	if not active_perks.has(perk_id):
		active_perks.append(perk_id)
		perk_applied.emit(perk_id)

## Brief micro-freeze hit-stop on high-impact events (e.g. cop wreck or fuel tanker explosion)
func hit_stop(duration_sec: float = 0.055) -> void:
	Engine.time_scale = 0.08
	var timer := get_tree().create_timer(duration_sec, true, false, true)
	timer.timeout.connect(func():
		if is_run_active and Engine.time_scale < 0.2:
			Engine.time_scale = 1.0
	)

## Triggers game over (arrested or vehicle destroyed).
func trigger_busted(reason: String) -> void:
	if not is_run_active:
		return
	
	is_run_active = false
	player_busted.emit(reason, current_score, survival_time, cops_wrecked)
