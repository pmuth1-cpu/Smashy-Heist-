class_name MainGame
extends Node3D

## Main Game Controller for Smashy Heist: Daily Getaway.
## Coordinates world chunks, 4-player starting grid, MultiplayerSpawner,
## Hot Loot Tag mode, camera rig, daily modifiers, and WantedManager run state.

const STARTING_GRID: Array[Vector3] = [
	Vector3(20.0, 0.6, 20.0),
	Vector3(28.0, 0.6, 20.0),
	Vector3(20.0, 0.6, 28.0),
	Vector3(28.0, 0.6, 28.0)
]

const RIVAL_CONFIGS: Array[Dictionary] = [
	{"name": "Rival Speedster", "car_id": "cyber_interceptor"},
	{"name": "Rival Bumper", "car_id": "armored_bulldozer"},
	{"name": "Rival Drifter", "car_id": "ice_cream_drifter"}
]

@onready var arcade_car: ArcadeCar = $ArcadeCar
@onready var camera_rig: CameraRig = $CameraRig
@onready var touch_hud: TouchHUD = $TouchHUD
@onready var city_generator: CityGenerator = $CityGenerator
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var hot_loot_mode: HotLootMode = $HotLootMode
@onready var boss_escape_mode: BossEscapeMode = $BossEscapeMode
@onready var smashy_kart_mode: SmashyKartMode = get_node_or_null("SmashyKartMode")
@onready var traffic_manager: Node3D = get_node_or_null("TrafficManager")
@onready var busted_cutscene_overlay: CanvasLayer = get_node_or_null("BustedCutsceneOverlay") as CanvasLayer

var spawned_rival_cars: Array[ArcadeCar] = []

func _ready() -> void:
	# Configure primary player car at starting grid slot 0
	_setup_car_position(arcade_car, STARTING_GRID[0])
	_wire_local_player(arcade_car)
	
	# Connect spawner for remote peer synchronization
	if player_spawner:
		player_spawner.spawned.connect(_on_network_player_spawned)
	
	# Connect crash and stage hazard signals
	arcade_car.crashed_into_object.connect(_on_car_crashed)
	city_generator.player_busted_in_water.connect(_on_player_busted_in_water)
	city_generator.player_hit_boost_pad.connect(_on_player_hit_boost_pad)
	if city_generator.has_signal("biome_entered"):
		city_generator.biome_entered.connect(func(_b, bname: String):
			if touch_hud and touch_hud.has_method("show_biome_banner"):
				touch_hud.show_biome_banner(bname)
		)
	
	# Apply Daily Modifier tuning
	_apply_daily_modifiers()
	
	# Start 0:51 Gameplay Background Music
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_gameplay_music"):
			sfx.play_gameplay_music()
	
	# Check if launched into online multiplayer match
	if has_node("/root/NetworkManager"):
		var nm = get_node("/root/NetworkManager")
		if nm.is_online_match:
			if touch_hud and touch_hud.multiplayer_lobby:
				touch_hud.multiplayer_lobby.visible = false
			var d_seed: int = 0
			if has_node("/root/DailySeedManager"):
				d_seed = get_node("/root/DailySeedManager").base_seed
			start_hot_loot_mode(d_seed)
			return
	
	# Connect BrawlMainMenu play button and TouchHUD mode signals
	if touch_hud and touch_hud.brawl_main_menu:
		touch_hud.brawl_main_menu.play_pressed.connect(start_game_mode)
	if touch_hud and touch_hud.has_signal("mode_play_started"):
		touch_hud.mode_play_started.connect(start_game_mode)
	
	# Connect BossEscapeMode signals to TouchHUD
	if boss_escape_mode:
		boss_escape_mode.boss_spawned.connect(func(b_name: String, max_hp: float):
			if touch_hud and touch_hud.has_method("set_boss_health"):
				touch_hud.set_boss_health(b_name, max_hp, max_hp)
		)
		boss_escape_mode.boss_damaged.connect(func(cur_hp: float, max_hp: float):
			if touch_hud and touch_hud.has_method("set_boss_health"):
				var b_name: String = boss_escape_mode.boss_name if boss_escape_mode else "BOSS"
				touch_hud.set_boss_health(b_name, cur_hp, max_hp)
		)
		boss_escape_mode.boss_defeated.connect(func(_b_name: String, _count: int):
			if touch_hud and touch_hud.has_method("hide_boss_health"):
				touch_hud.hide_boss_health()
		)
	
	# If running gameplay with GameModeManager, start current mode immediately
	if has_node("/root/GameModeManager"):
		var gmm = get_node("/root/GameModeManager")
		start_game_mode(int(gmm.current_mode))
		if touch_hud and touch_hud.multiplayer_lobby:
			touch_hud.multiplayer_lobby.visible = false
	else:
		if touch_hud and touch_hud.multiplayer_lobby:
			touch_hud.multiplayer_lobby.visible = true
			touch_hud.multiplayer_lobby.mode_selected.connect(_on_lobby_mode_selected)

func _setup_car_position(car: ArcadeCar, pos: Vector3) -> void:
	car.position = pos
	if car.physics_sphere:
		car.physics_sphere.global_position = pos
		car.physics_sphere.linear_velocity = Vector3.ZERO
		car.physics_sphere.angular_velocity = Vector3.ZERO
	if car.car_pivot:
		car.car_pivot.global_position = pos + Vector3(0.0, -0.45, 0.0)

func _wire_local_player(car: ArcadeCar) -> void:
	var car_pivot = car.get_node_or_null("CarPivot")
	if car_pivot:
		camera_rig.target = car_pivot
		camera_rig.global_position = car.position
		city_generator.target_player = car_pivot
	else:
		camera_rig.target = car
		camera_rig.global_position = car.position
		city_generator.target_player = car
	
	touch_hud.target_car = car
	if traffic_manager:
		traffic_manager.target_player = car

func _apply_daily_modifiers() -> void:
	if has_node("/root/DailySeedManager"):
		var mgr = get_node("/root/DailySeedManager")
		var mod_data: Dictionary = mgr.get_modifier_data()
		if arcade_car and arcade_car.stats:
			arcade_car.stats.max_speed *= float(mod_data["speed_multiplier"])
			arcade_car.stats.drift_grip *= float(mod_data["grip_multiplier"])
		print("Active Daily Modifier: %s" % mgr.get_modifier_name())

func _on_lobby_mode_selected(mode_id: int) -> void:
	if mode_id == 0:
		start_game_mode(0)
	else:
		start_game_mode(3)

## Central Game Mode Dispatcher for all 4 game modes
func start_game_mode(mode_id: int) -> void:
	if has_node("/root/GameModeManager"):
		var gmm: GameModeManagerClass = get_node("/root/GameModeManager") as GameModeManagerClass
		if gmm:
			gmm.set_mode(mode_id)
	
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if arcade_car and arcade_car.has_method("_on_car_equipped") and not sm.equipped_car_id.is_empty():
			arcade_car._on_car_equipped(sm.equipped_car_id)
	
	match mode_id:
		0: # DAILY_ENDLESS_GETAWAY
			start_solo_daily_mode()
		1: # ESCAPE_MEGA_BOSS
			start_boss_escape_mode()
		2: # HOT_LOOT_4P_TAG
			var shared_seed: int = 0
			if has_node("/root/DailySeedManager"):
				var dsm = get_node("/root/DailySeedManager")
				shared_seed = dsm.base_seed
			if shared_seed == 0:
				shared_seed = randi()
			start_hot_loot_mode(shared_seed)
		3: # SMASHY_KART_GP
			start_kart_mode()
		_:
			start_solo_daily_mode()

## Starts deterministic daily solo getaway run with ghost replay
func start_solo_daily_mode() -> void:
	if camera_rig:
		camera_rig.mode = "FOLLOW"
	hot_loot_mode.is_hot_loot_mode = false
	if boss_escape_mode:
		boss_escape_mode.stop_boss_mode()
	if smashy_kart_mode and smashy_kart_mode.has_method("stop_grand_prix"):
		smashy_kart_mode.stop_grand_prix()
	_clear_spawned_rivals()
	
	_setup_car_position(arcade_car, STARTING_GRID[0])
	_wire_local_player(arcade_car)
	
	# Spawn daily ghost car if previous best run exists
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if sm.saved_daily_ghost.size() > 1:
			var ghost_scene: PackedScene = load("res://scenes/vehicles/ghost_car.tscn")
			if ghost_scene:
				var ghost: GhostCar = ghost_scene.instantiate() as GhostCar
				ghost.recorded_frames = sm.saved_daily_ghost
				add_child(ghost)
	
	# Spawn squad member getaway partners if invited in lobby
	if has_node("/root/SocialFriendManager"):
		var sfm = get_node("/root/SocialFriendManager")
		var car_scene: PackedScene = load("res://scenes/vehicles/arcade_car.tscn")
		for i in range(mini(3, sfm.active_squad_members.size())):
			var smember: Dictionary = sfm.active_squad_members[i]
			var partner: ArcadeCar = car_scene.instantiate() as ArcadeCar
			partner.name = "SquadPartner_%d" % (i + 1)
			partner.peer_owner_id = 1
			partner.is_ai_rival = true
			partner.driver_name = "🤝 %s" % str(smember.get("name", "Buddy"))
			var s_car_id: String = str(smember.get("car_id", "default_coupe"))
			var stats_path: String = "res://resources/vehicles/%s.tres" % s_car_id
			if ResourceLoader.exists(stats_path):
				partner.stats = load(stats_path) as CarStats
			partner.equipped_gear_loadout = smember.get("loadout", {})
			add_child(partner, true)
			_setup_car_position(partner, STARTING_GRID[i + 1])
			partner.crashed_into_object.connect(_on_car_crashed)
			spawned_rival_cars.append(partner)
	
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		wm.start_new_run()


## Starts Mode 3: "Escape the Mega-Boss"
func start_boss_escape_mode() -> void:
	if camera_rig:
		camera_rig.mode = "FOLLOW"
	hot_loot_mode.is_hot_loot_mode = false
	if smashy_kart_mode and smashy_kart_mode.has_method("stop_grand_prix"):
		smashy_kart_mode.stop_grand_prix()
	_clear_spawned_rivals()
	
	_setup_car_position(arcade_car, STARTING_GRID[0])
	_wire_local_player(arcade_car)
	
	if boss_escape_mode:
		boss_escape_mode.start_boss_mode(arcade_car)
	
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		wm.start_new_run()

## Starts 4-player Hot Loot Tag mode with AI rival backfill
func start_hot_loot_mode(shared_seed: int = 0) -> void:
	if camera_rig:
		camera_rig.mode = "FOLLOW"
	if boss_escape_mode:
		boss_escape_mode.stop_boss_mode()
	if smashy_kart_mode and smashy_kart_mode.has_method("stop_grand_prix"):
		smashy_kart_mode.stop_grand_prix()
	_clear_spawned_rivals()
	
	if shared_seed != 0 and has_node("/root/DailySeedManager"):
		var dsm = get_node("/root/DailySeedManager")
		dsm.base_seed = shared_seed
	
	_setup_car_position(arcade_car, STARTING_GRID[0])
	arcade_car.peer_owner_id = 1
	arcade_car.is_ai_rival = false
	arcade_car.driver_name = "Player 1 (You)"
	arcade_car.update_nameplate()
	_wire_local_player(arcade_car)
	
	var all_cars: Array[ArcadeCar] = [arcade_car]
	
	var is_server_or_offline: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if is_server_or_offline:

		var car_scene: PackedScene = load("res://scenes/vehicles/arcade_car.tscn")
		var nm_players: Dictionary = {}
		if has_node("/root/NetworkManager"):
			nm_players = get_node("/root/NetworkManager").players
		
		# Identify connected human peers excluding host (id 1)
		var remote_peer_ids: Array[int] = []
		for pid in nm_players:
			if pid != 1:
				remote_peer_ids.append(pid)
		
		for i in range(1, 4):
			var rival: ArcadeCar = car_scene.instantiate() as ArcadeCar
			rival.name = "Car_%d" % (i + 1)
			
			if i - 1 < remote_peer_ids.size():
				# Assign to connected human client
				var peer_id: int = remote_peer_ids[i - 1]
				rival.peer_owner_id = peer_id
				rival.is_ai_rival = false
				var pinfo: Dictionary = nm_players[peer_id]
				rival.driver_name = str(pinfo.get("name", "Player %d" % peer_id))
			else:
				# Backfill slot with smart AI rival bot
				var cfg: Dictionary = RIVAL_CONFIGS[i - 1]
				rival.peer_owner_id = 1
				rival.is_ai_rival = true
				rival.driver_name = str(cfg["name"])
				var r_car_id: String = str(cfg["car_id"])
				var stats_path: String = "res://resources/vehicles/%s.tres" % r_car_id
				if ResourceLoader.exists(stats_path):
					rival.stats = load(stats_path) as CarStats
			
			add_child(rival, true)
			_setup_car_position(rival, STARTING_GRID[i])
			rival.crashed_into_object.connect(_on_car_crashed)
			spawned_rival_cars.append(rival)
			all_cars.append(rival)
	
	hot_loot_mode.start_hot_loot_match(all_cars)
	
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		wm.start_new_run()

func restart_with_seed(shared_seed: int) -> void:
	start_hot_loot_mode(shared_seed)

func _on_network_player_spawned(node: Node) -> void:
	if node is ArcadeCar:
		var car := node as ArcadeCar
		car.crashed_into_object.connect(_on_car_crashed)
		# If this client owns the spawned car, target it with camera and controls
		if multiplayer.has_multiplayer_peer() and car.peer_owner_id == multiplayer.get_unique_id() and not car.is_ai_rival:
			_wire_local_player(car)
			print("MainGame: Bound local camera and TouchHUD to player car: %s" % car.name)


func _clear_spawned_rivals() -> void:
	for rival in spawned_rival_cars:
		if is_instance_valid(rival):
			rival.queue_free()
	spawned_rival_cars.clear()

func _on_car_crashed(impact_force: float, collider: Object) -> void:
	var trauma_amount: float = clampf(impact_force / 16.0, 0.4, 1.0)
	camera_rig.add_trauma(trauma_amount)

func _on_player_busted_in_water(_chunk_coord: Vector2i) -> void:
	camera_rig.add_trauma(0.4)
	if arcade_car and is_instance_valid(arcade_car):
		if not arcade_car.is_abandoned and arcade_car.has_method("submerge_in_water"):
			arcade_car.submerge_in_water()

func _on_player_hit_boost_pad(_boost_pos: Vector3) -> void:
	camera_rig.add_trauma(0.35)
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		wm.add_prop_score(150)

func register_prop_smash(prop: SmashProp, _hitting_body: Node3D) -> void:
	camera_rig.add_trauma(prop.trauma_amount)
	var mult: int = 1
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		wm.add_prop_score(prop.base_points)
		mult = wm.combo_multiplier
	
	if has_node("/root/ProgressionManager"):
		get_node("/root/ProgressionManager").add_quest_progress("prop_smash", 1)
	
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if prop.prop_type == SmashProp.PropType.EXPLOSIVE_BARREL:
			sfx.play_explosion()
		else:
			sfx.play_smash_hit()
	
	if touch_hud and touch_hud.has_method("spawn_floating_text"):
		var pts: int = prop.base_points * mult
		var color: Color = Color("ff9f43") if prop.prop_type == SmashProp.PropType.EXPLOSIVE_BARREL else Color("2ecc71")
		touch_hud.spawn_floating_text(prop.global_position, "+%d!" % pts, color, 1.0)

## Starts Mode 4: "Smashy Kart Grand Prix"
func start_kart_mode() -> void:
	if camera_rig:
		camera_rig.mode = "KART_CHASE"
	hot_loot_mode.is_hot_loot_mode = false
	if boss_escape_mode:
		boss_escape_mode.stop_boss_mode()
	_clear_spawned_rivals()
	
	_setup_car_position(arcade_car, Vector3(0, 0.6, 0))
	_wire_local_player(arcade_car)
	
	if smashy_kart_mode:
		smashy_kart_mode.start_grand_prix(arcade_car)
