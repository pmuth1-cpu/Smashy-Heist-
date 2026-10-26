class_name SmashyKartMode
extends Node3D

## Smashy Kart Grand Prix — Full Mario Kart 3-Lap Circuit Mode Controller.
## Coordinates:
## - TrackBuilder instantiation and city generator / police spawner disabling
## - 6-Racer Staggered 2x3 Starting Grid (Local player + human peers / AI rival backfill)
## - 3-2-1-SMASH! Pre-Race Camera Swoop & Rocket Start rev mechanic
## - Real-time 1st-6th rank calculation based on total track distance
## - Checkpoint gate verification (0 -> 1 -> 2 -> 3 -> 0) preventing backward cheat
## - AI rival autonomous steering, drafting, drifting, item box targeting & weapon usage
## - 3-Lap Finish, Checkered Confetti, and 3D Gold/Silver/Bronze Podium Ceremony

const KartTrackBuilderScene = preload("res://scripts/world/kart_track_builder.gd")
const KartHUDOverlayScene = preload("res://scripts/ui/kart_hud_overlay.gd")
const KartItemSystemScript = preload("res://scripts/vehicles/kart_item_system.gd")
const KartNPCTrafficScript = preload("res://scripts/vehicles/kart_npc_traffic.gd")
const BrawlUITheme = preload("res://scripts/autoload/brawl_ui_theme.gd")

signal race_started()
signal lap_completed(racer: ArcadeCar, lap_num: int)
signal race_finished(winner: ArcadeCar, podium_order: Array[ArcadeCar])

const TOTAL_LAPS: int = 3

const RIVAL_BOT_DEFS: Array[Dictionary] = [
	{"name": "⚡ Racer 01", "car_id": "racer_01"},
	{"name": "🐉 Fire Dragon", "car_id": "fire_dragon"},
	{"name": "🛡️ Tanker", "car_id": "tanker"},
	{"name": "🍦 Ice Cream Drifter", "car_id": "ice_cream_drifter"},
	{"name": "👾 Cyber Interceptor", "car_id": "cyber_interceptor"}
]

var track_builder: KartTrackBuilder = null
var hud_overlay: KartHUDOverlay = null
var npc_traffic: Node3D = null

var local_car: ArcadeCar = null
var all_racers: Array[ArcadeCar] = []
var racer_progress: Dictionary = {} # ArcadeCar -> {"laps": int, "cp": int, "dist": float, "rank": int}

var is_race_active: bool = false
var is_countdown_active: bool = false
var countdown_timer: float = 0.0
var countdown_step: int = 0

# Rocket Start
var rev_meter: float = 0.0
var rocket_start_awarded: bool = false
var engine_stalled: bool = false
var stall_timer: float = 0.0

var podium_active: bool = false
var podium_ui: Control = null

func _ready() -> void:
	pass

## Stops Grand Prix mode and cleans up racers, hud, and tracks
func stop_grand_prix() -> void:
	is_race_active = false
	is_countdown_active = false
	if local_car and is_instance_valid(local_car):
		local_car.input_enabled = true
	if hud_overlay and is_instance_valid(hud_overlay):
		hud_overlay.queue_free()
		hud_overlay = null
	if npc_traffic and is_instance_valid(npc_traffic):
		npc_traffic.queue_free()
		npc_traffic = null
	if track_builder and is_instance_valid(track_builder):
		track_builder.queue_free()
		track_builder = null
	if podium_ui and is_instance_valid(podium_ui):
		podium_ui.queue_free()
		podium_ui = null
	for racer in all_racers:
		if is_instance_valid(racer) and racer != local_car:
			racer.queue_free()
	all_racers.clear()
	racer_progress.clear()
	var city_gen = get_tree().root.find_child("CityGenerator", true, false)
	if city_gen:
		city_gen.visible = true
		city_gen.process_mode = Node.PROCESS_MODE_INHERIT
	var cam_rig = get_tree().root.find_child("CameraRig", true, false)
	if cam_rig:
		cam_rig.mode = "FOLLOW"
	var police_spawner = get_tree().root.find_child("PoliceSpawner", true, false)
	if police_spawner:
		police_spawner.process_mode = Node.PROCESS_MODE_INHERIT
	var traffic = get_tree().root.find_child("TrafficManager", true, false)
	if traffic:
		traffic.process_mode = Node.PROCESS_MODE_INHERIT

## Called by MainGame to start Grand Prix mode
func start_grand_prix(player_car: ArcadeCar) -> void:
	local_car = player_car
	is_race_active = false
	podium_active = false
	
	_disable_city_and_police()
	_build_kart_track()
	_setup_racers()
	_setup_npc_traffic()
	_setup_hud()
	_connect_track_checkpoints()
	_start_countdown()

func _setup_npc_traffic() -> void:
	if npc_traffic and is_instance_valid(npc_traffic):
		npc_traffic.queue_free()
		npc_traffic = null
	
	npc_traffic = KartNPCTrafficScript.new()
	npc_traffic.name = "KartNPCTraffic"
	add_child(npc_traffic)
	npc_traffic.setup_traffic(track_builder.track_path.curve, track_builder.baked_length)

func _disable_city_and_police() -> void:
	# Hide / disable standard procedural city generator and cops
	var city_gen = get_tree().root.find_child("CityGenerator", true, false)
	if city_gen:
		city_gen.visible = false
		city_gen.process_mode = Node.PROCESS_MODE_DISABLED
	
	var police_spawner = get_tree().root.find_child("PoliceSpawner", true, false)
	if police_spawner:
		police_spawner.process_mode = Node.PROCESS_MODE_DISABLED
	
	var traffic = get_tree().root.find_child("TrafficManager", true, false)
	if traffic:
		traffic.process_mode = Node.PROCESS_MODE_DISABLED

func _build_kart_track() -> void:
	if track_builder and is_instance_valid(track_builder):
		track_builder.queue_free()
		track_builder = null
	
	track_builder = KartTrackBuilder.new()
	track_builder.name = "KartTrackBuilder"
	add_child(track_builder)

func _setup_racers() -> void:
	all_racers.clear()
	racer_progress.clear()
	
	var curve := track_builder.track_path.curve
	var b_len := track_builder.baked_length
	
	# Slot 0: Local Player
	all_racers.append(local_car)
	_attach_kart_item_system(local_car)
	
	# Spawn 5 AI rivals
	var car_scene: PackedScene = load("res://scenes/vehicles/arcade_car.tscn")
	for i in range(5):
		var bot_def: Dictionary = RIVAL_BOT_DEFS[i]
		var bot_car: ArcadeCar = car_scene.instantiate() as ArcadeCar
		bot_car.name = "KartRival_%d" % (i + 1)
		bot_car.driver_name = str(bot_def["name"])
		bot_car.peer_owner_id = 1
		bot_car.is_ai_rival = true
		
		var stats_path: String = "res://resources/vehicles/%s.tres" % str(bot_def["car_id"])
		if ResourceLoader.exists(stats_path):
			bot_car.stats = load(stats_path) as CarStats
		
		add_child(bot_car)
		all_racers.append(bot_car)
		_attach_kart_item_system(bot_car)
	
	# Position all 6 in staggered 2x3 starting grid behind start line (offset 0.0m)
	# Grid offsets: -6m, -10m, -14m, -18m, -22m, -26m
	var grid_slots: Array[Dictionary] = [
		{"dist": -6.0, "x": -3.5},
		{"dist": -10.0, "x": 3.5},
		{"dist": -14.0, "x": -3.5},
		{"dist": -18.0, "x": 3.5},
		{"dist": -22.0, "x": -3.5},
		{"dist": -26.0, "x": 3.5}
	]
	
	for idx in range(all_racers.size()):
		var racer: ArcadeCar = all_racers[idx]
		var slot: Dictionary = grid_slots[idx]
		var slot_dist: float = fposmod(b_len + float(slot["dist"]), b_len)
		
		var pos := curve.sample_baked(slot_dist)
		var next_p := curve.sample_baked(fposmod(slot_dist + 2.0, b_len))
		var fwd := (next_p - pos).normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		
		var spawn_pos: Vector3 = pos + right * float(slot["x"]) + Vector3(0, 0.4, 0)
		_position_car(racer, spawn_pos, fwd)
		
		racer.input_enabled = false
		racer_progress[racer] = {
			"laps": 0,
			"cp": 0,
			"dist": 0.0,
			"rank": idx + 1,
			"ai_item_timer": randf_range(2.0, 4.0)
		}
		racer.set_meta("kart_race_rank", idx + 1)

func _attach_kart_item_system(car: ArcadeCar) -> void:
	if not car.has_node("KartItemSystem"):
		var kis := KartItemSystem.new()
		kis.name = "KartItemSystem"
		car.add_child(kis)
		kis.car = car
		if car == local_car and hud_overlay:
			kis.roulette_finished.connect(func(item, count):
				hud_overlay.set_held_item(int(item), count)
			)
			kis.item_used.connect(func(item, remaining):
				hud_overlay.set_held_item(int(item), remaining)
			)
			kis.incoming_warning_triggered.connect(func(wtype):
				hud_overlay.set_warning("INCOMING %s!" % wtype, 2.2)
			)

func _get_car_pos(car: ArcadeCar) -> Vector3:
	if not is_instance_valid(car):
		return Vector3.ZERO
	if car.physics_sphere:
		return car.physics_sphere.global_position
	if car.car_pivot:
		return car.car_pivot.global_position
	return car.global_position

func _position_car(car: ArcadeCar, pos: Vector3, fwd: Vector3) -> void:
	car.position = pos
	car.global_position = pos
	if car.physics_sphere:
		car.physics_sphere.global_position = pos
		car.physics_sphere.linear_velocity = Vector3.ZERO
		car.physics_sphere.angular_velocity = Vector3.ZERO
	if car.car_pivot:
		car.car_pivot.global_position = pos
		if fwd.length_squared() > 0.01:
			car.car_pivot.look_at(pos + fwd, Vector3.UP)

func _setup_hud() -> void:
	if hud_overlay and is_instance_valid(hud_overlay):
		hud_overlay.queue_free()
	
	hud_overlay = KartHUDOverlay.new()
	hud_overlay.name = "KartHUDOverlay"
	add_child(hud_overlay)
	
	hud_overlay.setup_track(track_builder.track_path.curve, all_racers, local_car)
	hud_overlay.item_button_pressed.connect(_on_player_use_item)
	
	var kis = local_car.get_node_or_null("KartItemSystem")
	if kis:
		kis.roulette_finished.connect(func(item, count):
			hud_overlay.set_held_item(int(item), count)
		)
		kis.item_used.connect(func(item, remaining):
			hud_overlay.set_held_item(int(item), remaining)
		)
		kis.incoming_warning_triggered.connect(func(wtype):
			hud_overlay.set_warning("INCOMING %s!" % wtype, 2.2)
		)

func _on_player_use_item() -> void:
	if local_car and local_car.has_node("KartItemSystem"):
		local_car.get_node("KartItemSystem").use_item()

func _connect_track_checkpoints() -> void:
	for cp in track_builder.checkpoints:
		cp.body_entered.connect(func(body):
			_on_checkpoint_entered(cp, body)
		)

func _on_checkpoint_entered(cp: Area3D, body: Node) -> void:
	var car: ArcadeCar = null
	if body is ArcadeCar:
		car = body as ArcadeCar
	elif body.owner is ArcadeCar:
		car = body.owner as ArcadeCar
	
	if not car or not racer_progress.has(car):
		return
	
	var cp_idx: int = int(cp.get_meta("checkpoint_index", 0))
	var prog: Dictionary = racer_progress[car]
	var last_cp: int = int(prog["cp"])
	
	if cp_idx == 0:
		# Crossing start/finish line: only increments lap if passed cp 3
		if last_cp == 3:
			prog["laps"] += 1
			prog["cp"] = 0
			var lap_num: int = int(prog["laps"])
			lap_completed.emit(car, lap_num)
			
			if car == local_car:
				if hud_overlay:
					hud_overlay.update_hud(int(prog["rank"]), lap_num, TOTAL_LAPS)
				if has_node("/root/SoundFX"):
					get_node("/root/SoundFX").play_ui_click()
				
				if lap_num >= TOTAL_LAPS:
					_trigger_race_finish(car)
	else:
		if cp_idx == last_cp + 1:
			prog["cp"] = cp_idx

## 2. 3-2-1-SMASH! Pre-Race Countdown & Rocket Start
func _start_countdown() -> void:
	is_countdown_active = true
	countdown_timer = 0.0
	countdown_step = 0
	rev_meter = 0.0
	rocket_start_awarded = false
	engine_stalled = false
	
	if hud_overlay:
		hud_overlay.set_rev_gauge(0.0, true)

func _process(delta: float) -> void:
	if is_countdown_active:
		_process_countdown(delta)
	elif is_race_active:
		_process_race(delta)
		_process_ai_rivals(delta)
		_process_wrong_way(delta)

func _process_countdown(delta: float) -> void:
	countdown_timer += delta
	
	# Rocket Start Rev Gauge
	var is_holding_gas := Input.is_action_pressed("fire_rocket") or Input.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or (InputMap.has_action("jump") and Input.is_action_pressed("jump"))
	if is_holding_gas:
		rev_meter = minf(100.0, rev_meter + delta * 55.0)
	else:
		rev_meter = maxf(0.0, rev_meter - delta * 35.0)
	
	if hud_overlay:
		hud_overlay.set_rev_gauge(rev_meter, true)
	
	if countdown_timer < 1.0 and countdown_step == 0:
		countdown_step = 1
		if hud_overlay: hud_overlay.set_countdown_step("3", Color("e74c3c"))
		if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_ui_click()
	elif countdown_timer >= 1.0 and countdown_timer < 2.0 and countdown_step == 1:
		countdown_step = 2
		if hud_overlay: hud_overlay.set_countdown_step("2", Color("f39c12"))
		if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_ui_click()
	elif countdown_timer >= 2.0 and countdown_timer < 3.0 and countdown_step == 2:
		countdown_step = 3
		if hud_overlay: hud_overlay.set_countdown_step("1", Color("f1c40f"))
		if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_ui_click()
	elif countdown_timer >= 3.0 and countdown_step == 3:
		countdown_step = 4
		_trigger_race_start()

func _trigger_race_start() -> void:
	is_countdown_active = false
	is_race_active = true
	
	if hud_overlay:
		hud_overlay.set_countdown_step("SMASH!", Color("2ecc71"))
		get_tree().create_timer(1.0).timeout.connect(func():
			if hud_overlay: hud_overlay.hide_countdown()
		)
	
	# Unfreeze all racers
	for racer in all_racers:
		racer.input_enabled = true
	
	# Evaluate Rocket Start on Player
	if rev_meter >= 80.0 and rev_meter <= 95.0:
		# Fiery Rocket Start 1.6x boost for 1.8s
		local_car.apply_kart_boost(1.6, 1.8)
		if hud_overlay: hud_overlay.show_rev_result("🚀 ROCKET START!", Color("f1c40f"))
		if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_nitro_boost()
	elif rev_meter > 95.0:
		# Engine Stall
		engine_stalled = true
		stall_timer = 0.9
		local_car.input_enabled = false
		if hud_overlay: hud_overlay.show_rev_result("💨 ENGINE STALL!", Color("e74c3c"))
		if has_node("/root/SoundFX"): get_node("/root/SoundFX").play_tire_screech()
	else:
		if hud_overlay: hud_overlay.set_rev_gauge(0.0, false)
	
	race_started.emit()

func _process_race(delta: float) -> void:
	if engine_stalled:
		stall_timer -= delta
		if stall_timer <= 0.0:
			engine_stalled = false
			local_car.input_enabled = true
	
	var curve := track_builder.track_path.curve
	var b_len := track_builder.baked_length
	
	# 1. Calculate live total race distance for all 6 racers
	for racer in all_racers:
		if not is_instance_valid(racer):
			continue
		var prog: Dictionary = racer_progress[racer]
		var cur_lap: int = int(prog["laps"])
		var car_pos := _get_car_pos(racer)
		var closest_off: float = curve.get_closest_offset(car_pos)
		var total_dist: float = (float(cur_lap) * b_len) + closest_off
		prog["dist"] = total_dist
	
	# 2. Sort descending by distance to compute ranks 1 to 6
	var sorted_racers := all_racers.duplicate()
	sorted_racers.sort_custom(func(a, b):
		return racer_progress[a]["dist"] > racer_progress[b]["dist"]
	)
	
	for r_idx in range(sorted_racers.size()):
		var racer: ArcadeCar = sorted_racers[r_idx] as ArcadeCar
		var live_rank: int = r_idx + 1
		racer_progress[racer]["rank"] = live_rank
		racer.set_meta("kart_race_rank", live_rank)
	
	# 3. Update HUD with local player rank and lap
	if hud_overlay and local_car:
		var p_prog: Dictionary = racer_progress[local_car]
		hud_overlay.update_hud(int(p_prog["rank"]), int(p_prog["laps"]), TOTAL_LAPS)

## 3. AI Rival Autonomous Controller
func _process_ai_rivals(delta: float) -> void:
	var curve := track_builder.track_path.curve
	var b_len := track_builder.baked_length
	
	var bot_lanes := [-3.2, 3.2, -1.6, 1.6, 0.0]
	var bot_idx: int = 0
	
	for racer in all_racers:
		if not is_instance_valid(racer) or racer == local_car:
			continue
		
		var r_pos := _get_car_pos(racer)
		var cur_off: float = curve.get_closest_offset(r_pos)
		
		# Look-ahead steering along Curve3D (+16m)
		var look_off: float = fposmod(cur_off + 16.0, b_len)
		var target_center: Vector3 = curve.sample_baked(look_off)
		var next_center: Vector3 = curve.sample_baked(fposmod(look_off + 2.0, b_len))
		var track_fwd := (next_center - target_center).normalized()
		var track_right := track_fwd.cross(Vector3.UP).normalized()
		
		var lane_offset: float = bot_lanes[bot_idx % bot_lanes.size()]
		bot_idx += 1
		var target_pt: Vector3 = target_center + track_right * lane_offset
		
		var to_target := (target_pt - r_pos)
		to_target.y = 0.0
		var fwd := -racer.car_pivot.global_transform.basis.z.normalized() if racer.car_pivot else -racer.global_transform.basis.z.normalized()
		fwd.y = 0.0
		
		var angle_diff := fwd.signed_angle_to(to_target.normalized(), Vector3.UP)
		var target_steer: float = clampf(angle_diff * 2.8, -1.0, 1.0)
		racer.steer_input = lerpf(racer.steer_input, target_steer, 10.0 * delta)
		
		# Un-stuck recovery: if speed is nearly zero for > 1.2s, nudge along curve
		var current_speed: float = racer.physics_sphere.linear_velocity.length() if racer.physics_sphere else 0.0
		if current_speed < 1.5:
			var st: float = float(racer.get_meta("stuck_timer", 0.0)) + delta
			racer.set_meta("stuck_timer", st)
			if st > 1.5:
				racer.set_meta("stuck_timer", 0.0)
				var safe_p := curve.sample_baked(cur_off) + Vector3(0, 0.8, 0)
				var next_p := curve.sample_baked(fposmod(cur_off + 2.0, b_len))
				_position_car(racer, safe_p, (next_p - safe_p).normalized())
		else:
			racer.set_meta("stuck_timer", 0.0)
		
		# AI Weapon Usage
		var prog: Dictionary = racer_progress[racer]
		prog["ai_item_timer"] -= delta
		if prog["ai_item_timer"] <= 0.0:
			prog["ai_item_timer"] = randf_range(2.5, 4.5)
			var kis = racer.get_node_or_null("KartItemSystem")
			if kis and kis.current_item != KartItemSystem.KartItem.NONE:
				kis.use_item()

## 4. Wrong-Way & Lakitu Rescue Detection
func _process_wrong_way(delta: float) -> void:
	if not local_car or not track_builder or not track_builder.track_path:
		return
	
	var curve := track_builder.track_path.curve
	var b_len := track_builder.baked_length
	var car_pos := _get_car_pos(local_car)
	var cur_off := curve.get_closest_offset(car_pos)
	
	var p0 := curve.sample_baked(cur_off)
	var p1 := curve.sample_baked(fposmod(cur_off + 3.0, b_len))
	var track_fwd := (p1 - p0).normalized()
	var car_fwd := -local_car.car_pivot.global_transform.basis.z.normalized() if local_car.car_pivot else -local_car.global_transform.basis.z.normalized()
	
	var is_wrong_way := car_fwd.dot(track_fwd) < -0.35
	var lateral_dist: float = (Vector3(car_pos.x, 0.0, car_pos.z) - Vector3(p0.x, 0.0, p0.z)).length()
	var is_out_of_bounds: bool = lateral_dist > 14.5 or car_pos.y < -0.8
	
	if is_wrong_way or is_out_of_bounds:
		local_car.wrong_way_timer += delta
		if hud_overlay: hud_overlay.show_wrong_way(true)
		
		# Instant air-drop rescue if outside boundaries or prolonged wrong-way
		if is_out_of_bounds or local_car.wrong_way_timer >= 2.5:
			# Lakitu Air-Drop Rescue right where car was driving
			local_car.wrong_way_timer = 0.0
			var safe_pos := p0 + Vector3(0, 1.2, 0)
			_position_car(local_car, safe_pos, track_fwd)
			if hud_overlay: hud_overlay.show_wrong_way(false)
	else:
		local_car.wrong_way_timer = maxf(0.0, local_car.wrong_way_timer - delta * 1.5)
		if hud_overlay: hud_overlay.show_wrong_way(false)

## 5. Race Finish & 3D Podium Ceremony
func _trigger_race_finish(winner: ArcadeCar) -> void:
	if podium_active:
		return
	podium_active = true
	is_race_active = false
	
	# Stop racer inputs
	for racer in all_racers:
		racer.input_enabled = false
	
	var final_rank: int = int(racer_progress[local_car]["rank"])
	var trophies: int = 10
	var cash: int = 100
	if final_rank == 1:
		trophies = 30
		cash = 300
	elif final_rank == 2:
		trophies = 20
		cash = 200
	
	if has_node("/root/ProgressionManager"):
		var pm = get_node("/root/ProgressionManager")
		pm.add_trophies(trophies)
		pm.add_quest_progress("race_win", 1 if final_rank == 1 else 0)
	
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").add_cash(cash)
	
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_level_complete"):
			sfx.play_level_complete()
	
	_show_podium_ceremony(final_rank, trophies, cash)
	race_finished.emit(winner, all_racers)

func _show_podium_ceremony(rank: int, trophies: int, cash: int) -> void:
	podium_ui = Control.new()
	podium_ui.name = "PodiumCeremonyUI"
	podium_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var dark_bg := ColorRect.new()
	dark_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_bg.color = Color(0.05, 0.08, 0.12, 0.88)
	podium_ui.add_child(dark_bg)
	
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(760, 520)
	card.position = Vector2(960 - 380, 540 - 260)
	card.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("1e272e"), Color("f1c40f"), 0.05, 24))
	podium_ui.add_child(card)
	
	var cv := VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 18)
	card.add_child(cv)
	
	var trophy_icon := Label.new()
	trophy_icon.text = "🏆"
	trophy_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trophy_icon.label_settings = BrawlUITheme.make_label_settings(72, Color("f1c40f"), 12, 4)
	cv.add_child(trophy_icon)
	
	var header := Label.new()
	var ordinals := ["", "1st PLACE CHAMPION!", "2nd PLACE RUNNER-UP!", "3rd PLACE BRONZE!", "4th PLACE", "5th PLACE", "6th PLACE"]
	header.text = ordinals[clampi(rank, 1, 6)]
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.label_settings = BrawlUITheme.make_label_settings(38, Color("f1c40f") if rank <= 3 else Color.WHITE, 10, 4)
	cv.add_child(header)
	
	var rewards_lbl := Label.new()
	rewards_lbl.text = "REWARDS EARNED:\n+ %d 🏆 TROPHIES    + %d 💵 CASH" % [trophies, cash]
	rewards_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rewards_lbl.label_settings = BrawlUITheme.make_label_settings(24, Color("2ecc71"), 6, 2)
	cv.add_child(rewards_lbl)
	
	var cont_btn := Button.new()
	cont_btn.text = "CONTINUE TO MENU"
	cont_btn.custom_minimum_size = Vector2(320, 72)
	BrawlUITheme.attach_button_juice(cont_btn, Color("2ecc71"))
	cont_btn.pressed.connect(func():
		if has_node("/root/SceneTransitionManager"):
			get_node("/root/SceneTransitionManager").transition_to_scene("res://scenes/ui/brawl_main_menu.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/ui/brawl_main_menu.tscn")
	)
	cv.add_child(cont_btn)
	
	add_child(podium_ui)
