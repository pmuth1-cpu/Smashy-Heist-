class_name BrawlMainMenu
extends Control

const BrawlUITheme = preload("res://scripts/autoload/brawl_ui_theme.gd")
const SoundFX = preload("res://scripts/autoload/sound_fx.gd")
const LoginCalendarModalScene = preload("res://scenes/ui/login_calendar_modal.tscn")
const DailyQuestsDrawerScene = preload("res://scenes/ui/daily_quests_drawer.tscn")
const InventoryPanelScene = preload("res://scenes/ui/inventory_panel.tscn")
const FriendsSquadPanelScene = preload("res://scenes/ui/friends_squad_panel.tscn")

## Clean 1080x1920 Portrait Brawl Stars Menu with 5-Tab Bottom Dock
## Features:
## - Layer 0: Animated radial gradient background with rotating comic rays
## - Layer 1: Center stage 3D showroom with turntable, inertia, and 3D squad pedestals
## - Layer 2: Top safe-area currency and profile status pills + 7-Day & Quest quick buttons
## - Layer 3: Slanted mode selector card + Giant "SMASH!" play dock
## - Layer 4: Bottom 5-tab navigation dock (HOME, CARS, GEAR, GACHA, SOCIAL) with sliding bar

signal play_pressed(mode_id: int)
signal leaderboard_requested()
signal multiplayer_requested()
signal menu_closed()

const ALL_CAR_IDS: Array[String] = [
	"tuk_tuk_jet",
	"racer_01",
	"tanker",
	"shadow",
	"fire_dragon",
	"default_coupe",
	"armored_bulldozer",
	"ice_cream_drifter",
	"cyber_interceptor",
	"monster_pickup",
	"gold_limo",
	"f1_street_kart"
]

const CAR_DATA: Dictionary = {
	"tuk_tuk_jet": {
		"name": "TUK TUK JET",
		"rarity": "★ RARE BRAWLER ★",
		"rarity_tier": "RARE",
		"rarity_color": Color("3498db"),
		"stars": 3,
		"gadget": "TURBO JET FLIGHT",
		"desc": "Activate to fly for a short time and gain speed boost.",
		"speed": 0.82,
		"accel": 0.90,
		"handling": 0.85,
		"boost": 0.92,
	},
	"racer_01": {
		"name": "RACER 01",
		"rarity": "★ EPIC BRAWLER ★",
		"rarity_tier": "EPIC",
		"rarity_color": Color("a55eea"),
		"stars": 3,
		"gadget": "SUPERCHARGED DRIFT",
		"desc": "Aerodynamic crimson street racer built for high-speed drifting and sharp cornering.",
		"speed": 0.88,
		"accel": 0.86,
		"handling": 0.88,
		"boost": 0.84,
	},
	"tanker": {
		"name": "TANKER",
		"rarity": "★ EPIC BRAWLER ★",
		"rarity_tier": "EPIC",
		"rarity_color": Color("a55eea"),
		"stars": 3,
		"gadget": "ARMORED SLAM",
		"desc": "Heavy armored assault machine with reinforced steel plating that demolishes barricades.",
		"speed": 0.62,
		"accel": 0.70,
		"handling": 0.58,
		"boost": 0.75,
	},
	"shadow": {
		"name": "SHADOW",
		"rarity": "★ LEGENDARY BRAWLER ★",
		"rarity_tier": "LEGENDARY",
		"rarity_color": Color("f1c40f"),
		"stars": 4,
		"gadget": "STEALTH CLOAK",
		"desc": "Ultra-sleek stealth hypercar with radar cloak and quantum acceleration.",
		"speed": 0.95,
		"accel": 0.94,
		"handling": 0.92,
		"boost": 0.96,
	},
	"fire_dragon": {
		"name": "FIRE DRAGON",
		"rarity": "★ LEGENDARY BRAWLER ★",
		"rarity_tier": "LEGENDARY",
		"rarity_color": Color("f1c40f"),
		"stars": 4,
		"gadget": "DRAGON FLAME BURST",
		"desc": "Mythic asphalt beast leaving scorched trails of fiery destruction behind it.",
		"speed": 0.96,
		"accel": 0.92,
		"handling": 0.86,
		"boost": 0.98,
	},
	"default_coupe": {
		"name": "DEFAULT COUPE",
		"rarity": "★ COMMON BRAWLER ★",
		"rarity_tier": "COMMON",
		"rarity_color": Color("2ecc71"),
		"stars": 2,
		"gadget": "NITRO BOOST",
		"desc": "Balanced getaway coupe with quick street handling.",
		"speed": 0.65,
		"accel": 0.70,
		"handling": 0.75,
		"boost": 0.68,
	},
	"armored_bulldozer": {
		"name": "ARMORED BULLDOZER",
		"rarity": "★ SUPER RARE BRAWLER ★",
		"rarity_tier": "EPIC",
		"rarity_color": Color("9b59b6"),
		"stars": 3,
		"gadget": "UNSTOPPABLE PLOW",
		"desc": "Heavy armored ram that crushes police blockades.",
		"speed": 0.55,
		"accel": 0.60,
		"handling": 0.45,
		"boost": 0.50,
	},
	"ice_cream_drifter": {
		"name": "ICE CREAM DRIFTER",
		"rarity": "★ RARE BRAWLER ★",
		"rarity_tier": "RARE",
		"rarity_color": Color("ff7675"),
		"stars": 3,
		"gadget": "SLIPPERY FREEZE",
		"desc": "Slick drift van dropping freezing slippery frost paths.",
		"speed": 0.72,
		"accel": 0.75,
		"handling": 0.95,
		"boost": 0.70,
	},
	"cyber_interceptor": {
		"name": "CYBER INTERCEPTOR",
		"rarity": "★ EPIC BRAWLER RIDE ★",
		"rarity_tier": "EPIC",
		"rarity_color": Color("00d2d3"),
		"stars": 3,
		"gadget": "CYBER DASH TELEPORT",
		"desc": "Futuristic hover cruiser with instant quantum blink.",
		"speed": 0.92,
		"accel": 0.88,
		"handling": 0.80,
		"boost": 0.88,
	},
	"monster_pickup": {
		"name": "MONSTER PICKUP",
		"rarity": "★ SUPER RARE BRAWLER ★",
		"rarity_tier": "EPIC",
		"rarity_color": Color("e67e22"),
		"stars": 3,
		"gadget": "EARTHQUAKE SLAM",
		"desc": "Giant lifted 4x4 demolishing street props and barriers.",
		"speed": 0.78,
		"accel": 0.82,
		"handling": 0.60,
		"boost": 0.76,
	},
	"gold_limo": {
		"name": "GOLD LIMO",
		"rarity": "★ MYTHIC BRAWLER ★",
		"rarity_tier": "LEGENDARY",
		"rarity_color": Color("f1c40f"),
		"stars": 4,
		"gadget": "CASH RAIN MAGNET",
		"desc": "VIP stretch limousine pulling in double cash coins.",
		"speed": 0.70,
		"accel": 0.65,
		"handling": 0.55,
		"boost": 0.65,
	},
	"f1_street_kart": {
		"name": "F1 STREET KART",
		"rarity": "★ LEGENDARY BRAWLER ★",
		"rarity_tier": "LEGENDARY",
		"rarity_color": Color("e74c3c"),
		"stars": 4,
		"gadget": "OVERDRIVE SLIPSTREAM",
		"desc": "Formula speed demon with supersonic straight-line speed.",
		"speed": 0.98,
		"accel": 0.95,
		"handling": 0.90,
		"boost": 0.95,
	}
}

const MODE_DEFS: Array[Dictionary] = [
	{"id": 0, "name": "DAILY GETAWAY", "desc": "Survive 5 stars in daily seeded streets!", "thumb": "res://assets/modes/mode_daily_getaway.png"},
	{"id": 1, "name": "BOSS ESCAPE", "desc": "Outrun the crushing Steampunk Spider Mech!", "thumb": "res://assets/modes/mode_boss_escape.png"},
	{"id": 2, "name": "HOT LOOT TAG", "desc": "Hold the loot bag against rivals & cops!", "thumb": "res://assets/modes/mode_hot_loot.png"},
	{"id": 3, "name": "SMASHY KART GP", "desc": "3-Lap 6-Racer Circuit! Items, Drifts & Cups!", "thumb": "res://assets/modes/mode_kart_gp.png"}
]

const AUTO_SPIN_SPEED: float = 0.45
const INERTIA_DAMPING: float = 0.92
const IDLE_TIMEOUT: float = 2.0

var current_view_car_id: String = "default_coupe"
var current_mode_index: int = 0
var active_tab_index: int = 0

# 3D Showroom Nodes
var _sub_viewport: SubViewport = null
var _sub_viewport_container: SubViewportContainer = null
var _pedestal_pivot: Node3D = null
var _car_mount: Node3D = null
var _bounce_tween: Tween = null
var _smash_pulse_tween: Tween = null

# Turntable interaction
var _is_dragging: bool = false
var _last_drag_x: float = 0.0
var _angular_velocity: float = 0.0
var _idle_timer: float = 0.0

# Layer 0
var _rays_control: Node2D = null

# Layer 1 (Showroom overlay info)
var _showroom_ui_container: Control = null
var _rarity_pill_label: Label = null
var _rarity_pill_panel: PanelContainer = null
var _vehicle_name_label: Label = null
var _gadget_badge_label: Label = null
var _spin_hint_label: Label = null

# Layer 2 (Top Bar & Side Cards)
var _trophy_label: Label = null
var _streak_label: Label = null
var _cash_label: Label = null
var _level_label: Label = null
var _level_progress_bar: ProgressBar = null
var _shop_btn: Button = null

# Side Cards (Left & Right)
var _side_cards_container: Control = null
var _quests_card_btn: Button = null
var _quests_progress_bar: ProgressBar = null
var _quests_progress_label: Label = null
var _event_card_btn: Button = null
var _event_timer_label: Label = null
var _map_card_btn: Button = null
var _free_rewards_card_btn: Button = null

# Layer 3 (Home Dock)
var _home_dock_container: Control = null
var _mode_card_btn: Button = null
var _mode_title_label: Label = null
var _mode_desc_label: Label = null
var _mode_thumb_rect: TextureRect = null
var _smash_play_button: Control = null
var _mode_drawer_panel: Control = null

# Layer 4 (Bottom Dock)
var _bottom_dock_container: PanelContainer = null
var _tab_buttons: Array[Button] = []
var _tab_labels: Array[Label] = []
var _tab_icons: Array[TextureRect] = []
var _tab_highlight_bar: ColorRect = null
var _highlight_tween: Tween = null

# Layer 2 Top Bar
var _top_bar: Control = null

# Dedicated Full-Screen Interfaces (Cars, Gear, Gacha, Social/Ranks)
var _cars_screen: Control = null
var _gear_screen: Control = null
var _gacha_screen: Control = null
var _cars_drawer: PanelContainer = null
var _cars_grid: GridContainer = null
var _gacha_drawer: PanelContainer = null
var _gacha_box_btn: Button = null
var _gacha_box_tween: Tween = null
var _gacha_result_panel: PanelContainer = null
var _gacha_result_label: Label = null
var _ranks_drawer: PanelContainer = null
var _ranks_list_vbox: VBoxContainer = null

# Phase 12: Quick-Action Buttons (7-Day Gift & Daily Quests)
var _quick_action_box: HBoxContainer = null
var _gift_btn: Button = null
var _gift_notify_dot: PanelContainer = null
var _quests_btn: Button = null
var _quests_notify_dot: PanelContainer = null
var _login_calendar_modal: Control = null
var _daily_quests_drawer: Control = null

# Phase 12: 3D Squad Turntable Showroom
var _squad_pedestals: Array[Node3D] = []
var _squad_car_mounts: Array[Node3D] = []
var _squad_nameplates: Array[Label3D] = []
const SQUAD_PEDESTAL_POSITIONS: Array[Vector3] = [
	Vector3(-3.2, -0.05, -0.8),
	Vector3(3.2, -0.05, -0.8),
	Vector3(-5.2, -0.10, -1.4)
]

# Phase 12 Drawers (Gear Loadout, Friends Squad Lobby)
var _inventory_drawer: PanelContainer = null
var _inventory_panel: Control = null
var _friends_squad_drawer: PanelContainer = null
var _friends_squad_panel: Control = null

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_build_layer_0_background()
	_build_layer_1_showroom()
	_build_layer_2_top_bar()
	_build_layer_3_home_dock()
	_build_tab_drawers()
	_build_layer_4_bottom_dock()
	
	_connect_managers()
	_start_smash_pulse()
	
	# Load current equipped car
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		current_view_car_id = sm.equipped_car_id
	
	_load_showroom_car(current_view_car_id)
	_refresh_top_bar()
	_refresh_mode_display()
	_refresh_notification_badges()
	var target_tab: int = 0
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if sm.has_meta("return_to_tab"):
			target_tab = int(sm.get_meta("return_to_tab"))
			sm.remove_meta("return_to_tab")
	switch_tab(target_tab)
	
	# Start 1:48 Lobby Background Music
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_lobby_music"):
			sfx.play_lobby_music()
	
	# Auto popup 7-Day Login Calendar if reward is available today
	if has_node("/root/ProgressionManager"):
		var pm = get_node("/root/ProgressionManager")
		if pm.can_claim_today_login():
			get_tree().create_timer(0.4).timeout.connect(func():
				if is_instance_valid(self) and visible and active_tab_index == 0:
					_open_login_calendar()
			)

func _process(delta: float) -> void:
	if not visible:
		return
	
	# Rotate background comic rays
	if _rays_control and is_instance_valid(_rays_control):
		_rays_control.rotation += 0.12 * delta
	
	# Turntable inertia and idle rotation
	if _pedestal_pivot and is_instance_valid(_pedestal_pivot):
		if not _is_dragging:
			if _idle_timer < IDLE_TIMEOUT:
				_idle_timer += delta
				_pedestal_pivot.rotation.y += _angular_velocity * delta
				_angular_velocity *= pow(INERTIA_DAMPING, delta * 60.0)
			else:
				_pedestal_pivot.rotation.y += AUTO_SPIN_SPEED * delta

# ==============================================================================
# LAYER 0: ANIMATED RADIAL BACKGROUND & COMIC RAYS
# ==============================================================================

func _build_layer_0_background() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Layer0_Backdrop"
	backdrop.set_anchors_preset(PRESET_FULL_RECT)
	backdrop.color = Color("0a1931")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	
	# High quality cyber hangar backdrop matching the exact design specification
	var acl = get_node_or_null("/root/AssetChromaLoader")
	var bg_tex: Texture2D = null
	if acl:
		bg_tex = acl.load_texture("res://assets/splash/lobby_hangar_bg.png")
	elif ResourceLoader.exists("res://assets/splash/lobby_hangar_bg.png"):
		bg_tex = load("res://assets/splash/lobby_hangar_bg.png")
	
	if bg_tex:
		var bg_rect := TextureRect.new()
		bg_rect.name = "HangarBackdrop"
		bg_rect.set_anchors_preset(PRESET_FULL_RECT)
		bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
		bg_rect.texture = bg_tex
		bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg_rect)
	
	# Subtle vignette gradient overlay
	var grad_rect := TextureRect.new()
	grad_rect.set_anchors_preset(PRESET_FULL_RECT)
	grad_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad_rect.stretch_mode = TextureRect.STRETCH_SCALE
	grad_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.0, 0.0, 0.0, 0.0), Color("050b16", 0.45), Color("03060c", 0.85)])
	grad.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.45)
	grad_tex.fill_to = Vector2(0.9, 0.9)
	grad_rect.texture = grad_tex
	add_child(grad_rect)
	
	# Comic rays rotating control centered at 960x540
	_rays_control = Node2D.new()
	_rays_control.name = "ComicRays"
	_rays_control.position = Vector2(960, 540)
	add_child(_rays_control)
	
	var num_rays := 16
	var ray_length := 1800.0
	var step_angle := TAU / float(num_rays)
	var ray_color := Color(1.0, 1.0, 1.0, 0.035)
	
	for i in range(0, num_rays, 2):
		var a1 := float(i) * step_angle
		var a2 := float(i) * step_angle + step_angle * 0.55
		var p1 := Vector2.ZERO
		var p2 := Vector2(cos(a1), sin(a1)) * ray_length
		var p3 := Vector2(cos(a2), sin(a2)) * ray_length
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([p1, p2, p3])
		poly.color = ray_color
		_rays_control.add_child(poly)

# ==============================================================================
# LAYER 1: CENTER STAGE 3D SHOWROOM
# ==============================================================================

func _build_layer_1_showroom() -> void:
	# Showroom Viewport Container spanning full 16:9 widescreen display (1920x1080)
	_sub_viewport_container = SubViewportContainer.new()
	_sub_viewport_container.name = "ShowroomContainer"
	_sub_viewport_container.layout_mode = 1
	_sub_viewport_container.anchors_preset = PRESET_FULL_RECT
	_sub_viewport_container.offset_top = 0.0
	_sub_viewport_container.offset_bottom = 0.0
	_sub_viewport_container.offset_left = 0.0
	_sub_viewport_container.offset_right = 0.0
	_sub_viewport_container.stretch = true
	_sub_viewport_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_sub_viewport_container.gui_input.connect(_on_showroom_gui_input)
	add_child(_sub_viewport_container)
	
	_sub_viewport = SubViewport.new()
	_sub_viewport.name = "ShowroomViewport"
	_sub_viewport.size = Vector2i(1920, 1080)
	_sub_viewport.own_world_3d = true
	_sub_viewport.transparent_bg = true
	_sub_viewport.msaa_3d = Viewport.MSAA_4X
	_sub_viewport.handle_input_locally = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub_viewport_container.add_child(_sub_viewport)
	
	# 3D World Scene
	var world := Node3D.new()
	world.name = "ShowroomWorld"
	_sub_viewport.add_child(world)
	
	# Environment with ACES tonemapper & glow
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.TRANSPARENT
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.06
	
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world.add_child(world_env)
	
	# Camera3D: Calibrated for 16:9 Landscape Widescreen
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 2.45, 6.7)
	cam.rotation_degrees = Vector3(-13.5, 0.0, 0.0)
	cam.fov = 32.5
	cam.current = true
	world.add_child(cam)
	
	# Lighting: 3D Neon Heist Studio illumination
	var dir_light := DirectionalLight3D.new()
	dir_light.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	dir_light.light_energy = 1.15
	dir_light.shadow_enabled = true
	world.add_child(dir_light)
	
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-3.5, 2.2, 2.5)
	fill_light.light_color = Color("00d2d3")
	fill_light.light_energy = 0.9
	fill_light.omni_range = 14.0
	world.add_child(fill_light)
	
	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(3.5, 3.2, -3.5)
	rim_light.light_color = Color("fbc531")
	rim_light.light_energy = 1.05
	rim_light.omni_range = 14.0
	world.add_child(rim_light)
	
	# Floor Plate Cyan Bounce Light
	var floor_bounce := OmniLight3D.new()
	floor_bounce.name = "FloorPlateBounceLight"
	floor_bounce.position = Vector3(0.0, -0.30, 0.10)
	floor_bounce.light_color = Color("00e5ff")
	floor_bounce.light_energy = 1.3
	floor_bounce.omni_range = 5.0
	world.add_child(floor_bounce)
	
	# =========================================================================
	# 3D NEON HEIST GARAGE HANGAR ENVIRONMENT
	# =========================================================================
	var hangar_group := Node3D.new()
	hangar_group.name = "NeonGarageHangar"
	world.add_child(hangar_group)
	
	_pedestal_pivot = Node3D.new()
	_pedestal_pivot.name = "PedestalPivot"
	_pedestal_pivot.position = Vector3(0.0, -0.40, 0.10) # Positioned to align with the cyan floor plate in lobby_hangar_bg.png
	_pedestal_pivot.rotation_degrees = Vector3(0.0, 142.0, 0.0) # Reverted X tilt (level with floor) & orbited Y to match plate perspective
	_pedestal_pivot.scale = Vector3(0.85, 0.85, 0.85) # Scaled to fit comfortably on the floor plate
	world.add_child(_pedestal_pivot)
	
	var stage_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.85
	cyl.bottom_radius = 1.95
	cyl.height = 0.05
	cyl.radial_segments = 36
	stage_mesh.mesh = cyl
	
	var stage_mat := StandardMaterial3D.new()
	stage_mat.albedo_color = Color("070e1a")
	stage_mat.albedo_texture = BrawlUITheme.get_hex_grid_texture()
	stage_mat.uv1_scale = Vector3(3.0, 3.0, 1.0)
	stage_mat.metallic = 0.85
	stage_mat.roughness = 0.25
	stage_mesh.material_override = stage_mat
	stage_mesh.position = Vector3(0.0, -0.025, 0.0)
	_pedestal_pivot.add_child(stage_mesh)
	
	# Glowing Cyan Neon Rim
	var neon_mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.80
	torus.outer_radius = 1.88
	torus.rings = 36
	torus.ring_segments = 14
	neon_mesh.mesh = torus
	
	var neon_mat := StandardMaterial3D.new()
	neon_mat.albedo_color = Color("00e5ff")
	neon_mat.emission_enabled = true
	neon_mat.emission = Color("00e5ff")
	neon_mat.emission_energy_multiplier = 3.5
	neon_mesh.material_override = neon_mat
	neon_mesh.position = Vector3(0.0, 0.01, 0.0)
	_pedestal_pivot.add_child(neon_mesh)
	
	_car_mount = Node3D.new()
	_car_mount.name = "CarMount"
	_car_mount.position = Vector3(0.0, 0.08, 0.0)
	_car_mount.scale = Vector3(0.92, 0.92, 0.92)
	_pedestal_pivot.add_child(_car_mount)
	
	_build_squad_pedestals(world)
	
	# UI Overlay above and below 3D car in 16:9 Landscape
	_showroom_ui_container = Control.new()
	_showroom_ui_container.name = "ShowroomUIOverlay"
	_showroom_ui_container.set_anchors_preset(PRESET_FULL_RECT)
	_showroom_ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_showroom_ui_container)
	
	# Top Badges: VBox at Y = 100 to 260
	var top_vbox := VBoxContainer.new()
	top_vbox.set_anchors_preset(PRESET_TOP_WIDE)
	top_vbox.offset_top = 100.0
	top_vbox.offset_bottom = 260.0
	top_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_showroom_ui_container.add_child(top_vbox)
	
	# Rarity Pill
	var pill_center := CenterContainer.new()
	pill_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_vbox.add_child(pill_center)
	
	_rarity_pill_panel = PanelContainer.new()
	_rarity_pill_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_pill_style(Color("00d2d3"), Color("0d1117"), 0.04, 18))
	pill_center.add_child(_rarity_pill_panel)
	
	_rarity_pill_label = Label.new()
	_rarity_pill_label.text = "★ EPIC BRAWLER RIDE ★"
	_rarity_pill_label.label_settings = BrawlUITheme.make_label_settings(18, Color.WHITE, 6, 2)
	_rarity_pill_panel.add_child(_rarity_pill_label)
	
	# Car Name Label (48pt outlined text)
	_vehicle_name_label = Label.new()
	_vehicle_name_label.text = "CYBER INTERCEPTOR"
	_vehicle_name_label.label_settings = BrawlUITheme.make_label_settings(48, Color.WHITE, 10, 4)
	_vehicle_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_vbox.add_child(_vehicle_name_label)
	
	# Special Gadget 1-line badge
	var gadget_center := CenterContainer.new()
	gadget_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_vbox.add_child(gadget_center)
	
	var gadget_panel := PanelContainer.new()
	gadget_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_pill_style(Color("2f3640"), Color("0d1117"), 0.04, 14))
	gadget_center.add_child(gadget_panel)
	
	_gadget_badge_label = Label.new()
	_gadget_badge_label.text = "⚡ GADGET: CYBER DASH TELEPORT"
	_gadget_badge_label.label_settings = BrawlUITheme.make_label_settings(18, Color("fbc531"), 6, 2)
	gadget_panel.add_child(_gadget_badge_label)
	
	# Swipe Hint Pill below pedestal (Y = 740)
	var hint_center := CenterContainer.new()
	hint_center.set_anchors_preset(PRESET_TOP_WIDE)
	hint_center.offset_top = 740.0
	hint_center.offset_bottom = 790.0
	hint_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_showroom_ui_container.add_child(hint_center)
	
	var hint_panel := PanelContainer.new()
	hint_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_pill_style(Color(0.06, 0.10, 0.16, 0.88), Color("0084a8"), 0.04, 16))
	hint_center.add_child(hint_panel)
	
	_spin_hint_label = Label.new()
	_spin_hint_label.text = "🔄 SWIPE TO SPIN 360°"
	_spin_hint_label.label_settings = BrawlUITheme.make_label_settings(15, Color("8395a7"), 4, 1)
	hint_panel.add_child(_spin_hint_label)

func _on_showroom_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = mb.pressed
			_last_drag_x = mb.position.x
			_angular_velocity = 0.0
			_idle_timer = 0.0
	elif event is InputEventMouseMotion and _is_dragging:
		var mm := event as InputEventMouseMotion
		var delta_x: float = mm.position.x - _last_drag_x
		_last_drag_x = mm.position.x
		var rot_step: float = delta_x * 0.008
		_pedestal_pivot.rotation.y += rot_step
		_angular_velocity = rot_step / 0.016
		_idle_timer = 0.0
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_is_dragging = st.pressed
		_last_drag_x = st.position.x
		_angular_velocity = 0.0
		_idle_timer = 0.0
	elif event is InputEventScreenDrag and _is_dragging:
		var sd := event as InputEventScreenDrag
		var rot_step: float = sd.relative.x * 0.008
		_pedestal_pivot.rotation.y += rot_step
		_angular_velocity = rot_step / 0.016
		_idle_timer = 0.0

func _load_showroom_car(car_id: String) -> void:
	current_view_car_id = car_id
	if not _car_mount:
		return
	
	for child in _car_mount.get_children():
		_car_mount.remove_child(child)
		child.queue_free()
	
	var vab = get_node_or_null("/root/VoxelAssetBuilder")
	if vab and vab.has_method("build_player_car_visuals"):
		var car_node: Node3D = vab.build_player_car_visuals(car_id)
		_car_mount.add_child(car_node)
		if vab.has_method("attach_gear_loadout") and has_node("/root/SaveManager"):
			var sm = get_node("/root/SaveManager")
			vab.attach_gear_loadout(car_node, sm.equipped_loadout)
	
	# Exaggerated squash & stretch drop tween
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()
	
	_car_mount.scale = Vector3(0.01, 0.01, 0.01)
	_car_mount.position = Vector3(0.0, 1.2, 0.0)
	
	_bounce_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bounce_tween.parallel().tween_property(_car_mount, "position:y", 0.08, 0.38).set_trans(Tween.TRANS_BOUNCE)
	_bounce_tween.parallel().tween_property(_car_mount, "scale", Vector3(1.35, 0.95, 1.35), 0.22)
	_bounce_tween.chain().tween_property(_car_mount, "scale", Vector3(1.05, 1.25, 1.05), 0.12)
	_bounce_tween.chain().tween_property(_car_mount, "scale", Vector3(0.92, 0.92, 0.92), 0.10)
	
	_update_car_info_labels(car_id)

func _build_squad_pedestals(world: Node3D) -> void:
	_squad_pedestals.clear()
	_squad_car_mounts.clear()
	_squad_nameplates.clear()
	
	for i in range(SQUAD_PEDESTAL_POSITIONS.size()):
		var ped := Node3D.new()
		ped.name = "SquadPedestal_%d" % i
		ped.position = SQUAD_PEDESTAL_POSITIONS[i]
		world.add_child(ped)
		_squad_pedestals.append(ped)
		
		# Base Cylinder
		var mesh_inst := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.35
		cyl.bottom_radius = 1.35
		cyl.height = 0.26
		cyl.radial_segments = 24
		mesh_inst.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("192a56")
		mat.metallic = 0.3
		mat.roughness = 0.35
		mesh_inst.material_override = mat
		mesh_inst.position = Vector3(0.0, -0.13, 0.0)
		ped.add_child(mesh_inst)
		
		# Glowing Rim Torus
		var neon_inst := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 1.30
		torus.outer_radius = 1.38
		torus.rings = 24
		torus.ring_segments = 10
		neon_inst.mesh = torus
		var nmat := StandardMaterial3D.new()
		nmat.albedo_color = Color("00d2d3")
		nmat.emission_enabled = true
		nmat.emission = Color("00d2d3")
		nmat.emission_energy_multiplier = 2.4
		neon_inst.material_override = nmat
		neon_inst.position = Vector3(0.0, 0.01, 0.0)
		ped.add_child(neon_inst)
		
		# Mount for blocky car
		var mount := Node3D.new()
		mount.name = "CarMount"
		mount.position = Vector3(0.0, 0.20, 0.0)
		if i == 0:
			mount.rotation_degrees.y = 20.0
		elif i == 1:
			mount.rotation_degrees.y = -20.0
		ped.add_child(mount)
		_squad_car_mounts.append(mount)
		
		# Floating 3D Nameplate & Ready badge
		var np := Label3D.new()
		np.name = "Nameplate"
		np.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		np.position = Vector3(0.0, 1.35, 0.0)
		np.font_size = 28
		np.outline_size = 8
		np.outline_modulate = Color("0d1117")
		np.modulate = Color("2ecc71")
		np.text = ""
		ped.add_child(np)
		_squad_nameplates.append(np)
		
		ped.visible = false

func _refresh_showroom_squad() -> void:
	if not has_node("/root/SocialFriendManager"):
		return
	var sfm = get_node("/root/SocialFriendManager")
	var members: Array[Dictionary] = sfm.active_squad_members
	var vab = get_node_or_null("/root/VoxelAssetBuilder")
	
	for i in range(_squad_pedestals.size()):
		var ped: Node3D = _squad_pedestals[i]
		var mount: Node3D = _squad_car_mounts[i]
		var np: Label3D = _squad_nameplates[i]
		
		for child in mount.get_children():
			mount.remove_child(child)
			child.queue_free()
		
		if i < members.size():
			ped.visible = true
			var member: Dictionary = members[i]
			var m_car_id: String = String(member.get("car_id", "default_coupe"))
			var m_name: String = String(member.get("name", "Buddy"))
			var m_loadout: Dictionary = member.get("loadout", {})
			
			if vab and vab.has_method("build_player_car_visuals"):
				var car_node: Node3D = vab.build_player_car_visuals(m_car_id)
				mount.add_child(car_node)
				if vab.has_method("attach_gear_loadout") and not m_loadout.is_empty():
					vab.attach_gear_loadout(car_node, m_loadout)
			
			np.text = "%s\n✅ READY!" % m_name
			np.modulate = Color("2ecc71")
		else:
			ped.visible = false

func _update_car_info_labels(car_id: String) -> void:
	var info: Dictionary = CAR_DATA.get(car_id, CAR_DATA["default_coupe"])
	if _vehicle_name_label:
		_vehicle_name_label.text = str(info["name"])
	if _rarity_pill_label:
		_rarity_pill_label.text = str(info["rarity"])
	if _rarity_pill_panel:
		_rarity_pill_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_pill_style(info["rarity_color"], Color("0d1117"), 0.04, 18))
	if _gadget_badge_label:
		_gadget_badge_label.text = "⚡ %s" % str(info["gadget"])

# ==============================================================================
# LAYER 2: TOP SAFE-AREA CURRENCY & PROFILE BAR (Height 110px)
# ==============================================================================

func _build_layer_2_top_bar() -> void:
	var top_bar := Control.new()
	top_bar.name = "Layer2_TopBar"
	top_bar.set_anchors_preset(PRESET_TOP_WIDE)
	top_bar.offset_left = 24.0
	top_bar.offset_top = 16.0
	top_bar.offset_right = -24.0
	top_bar.offset_bottom = 80.0
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)
	_top_bar = top_bar
	
	var acl = get_node_or_null("/root/AssetChromaLoader")
	
	# --- LEFT: Profile & Trophy Capsule ---
	var profile_panel := PanelContainer.new()
	profile_panel.name = "ProfileCapsule"
	profile_panel.custom_minimum_size = Vector2(360, 58)
	profile_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_capsule_style(Color("06111f"), Color("0084a8"), 24))
	top_bar.add_child(profile_panel)
	
	var prof_h := HBoxContainer.new()
	prof_h.alignment = BoxContainer.ALIGNMENT_BEGIN
	prof_h.add_theme_constant_override("separation", 12)
	profile_panel.add_child(prof_h)
	
	# Avatar circle
	var av_rect := TextureRect.new()
	if acl:
		av_rect.texture = acl.load_texture("res://assets/ui/icon_avatar_pilot.png")
	elif ResourceLoader.exists("res://assets/ui/icon_avatar_pilot.png"):
		av_rect.texture = load("res://assets/ui/icon_avatar_pilot.png")
	av_rect.custom_minimum_size = Vector2(46, 46)
	av_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	av_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prof_h.add_child(av_rect)
	
	# Score & Level VBox
	var stat_v := VBoxContainer.new()
	stat_v.alignment = BoxContainer.ALIGNMENT_CENTER
	stat_v.add_theme_constant_override("separation", 2)
	prof_h.add_child(stat_v)
	
	var tr_row := HBoxContainer.new()
	tr_row.add_theme_constant_override("separation", 6)
	stat_v.add_child(tr_row)
	
	var tr_icon := TextureRect.new()
	if acl:
		tr_icon.texture = acl.load_texture("res://assets/ui/icon_trophy_cup.png")
	tr_icon.custom_minimum_size = Vector2(24, 24)
	tr_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr_row.add_child(tr_icon)
	
	_trophy_label = Label.new()
	_trophy_label.text = "210337"
	_trophy_label.label_settings = BrawlUITheme.make_label_settings(22, Color("fbc531"), 6, 2)
	tr_row.add_child(_trophy_label)
	
	var lv_row := HBoxContainer.new()
	lv_row.add_theme_constant_override("separation", 8)
	stat_v.add_child(lv_row)
	
	_level_label = Label.new()
	_level_label.text = "Lv. 12"
	_level_label.label_settings = BrawlUITheme.make_label_settings(14, Color.WHITE, 4, 1)
	lv_row.add_child(_level_label)
	
	_level_progress_bar = ProgressBar.new()
	_level_progress_bar.custom_minimum_size = Vector2(160, 8)
	_level_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_level_progress_bar.max_value = 1.0
	_level_progress_bar.value = 0.65
	_level_progress_bar.show_percentage = false
	var lv_bg := StyleBoxFlat.new()
	lv_bg.bg_color = Color("081728")
	lv_bg.set_corner_radius_all(4)
	var lv_fill := StyleBoxFlat.new()
	lv_fill.bg_color = Color("fbc531")
	lv_fill.set_corner_radius_all(4)
	_level_progress_bar.add_theme_stylebox_override("background", lv_bg)
	_level_progress_bar.add_theme_stylebox_override("fill", lv_fill)
	lv_row.add_child(_level_progress_bar)
	
	# --- CENTER: Daily Streak Banner ---
	var streak_center := CenterContainer.new()
	streak_center.set_anchors_preset(PRESET_TOP_WIDE)
	streak_center.offset_top = 0.0
	streak_center.offset_bottom = 60.0
	streak_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(streak_center)
	
	var streak_btn := Button.new()
	streak_btn.custom_minimum_size = Vector2(310, 56)
	streak_btn.focus_mode = Control.FOCUS_NONE
	var streak_sb := BrawlUITheme.make_pill_style(Color("c0392b"), Color("e84118"), 0.08, 16)
	streak_btn.add_theme_stylebox_override("normal", streak_sb)
	streak_btn.add_theme_stylebox_override("hover", streak_sb)
	streak_btn.add_theme_stylebox_override("pressed", streak_sb)
	streak_btn.pressed.connect(_open_login_calendar)
	streak_center.add_child(streak_btn)
	
	var streak_h := HBoxContainer.new()
	streak_h.set_anchors_preset(PRESET_FULL_RECT)
	streak_h.alignment = BoxContainer.ALIGNMENT_CENTER
	streak_h.add_theme_constant_override("separation", 10)
	streak_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	streak_btn.add_child(streak_h)
	
	var st_icon := TextureRect.new()
	if acl:
		st_icon.texture = acl.load_texture("res://assets/ui/icon_streak_flame.png")
	st_icon.custom_minimum_size = Vector2(32, 32)
	st_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	st_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	st_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	streak_h.add_child(st_icon)
	
	_streak_label = Label.new()
	_streak_label.text = "3 DAY STREAK"
	_streak_label.label_settings = BrawlUITheme.make_label_settings(20, Color.WHITE, 6, 2)
	_streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	streak_h.add_child(_streak_label)
	
	# --- RIGHT: Currency & Shop ---
	var right_h := HBoxContainer.new()
	right_h.anchor_left = 1.0
	right_h.anchor_right = 1.0
	right_h.offset_left = -480.0
	right_h.offset_right = 0.0
	right_h.offset_top = 0.0
	right_h.offset_bottom = 64.0
	right_h.alignment = BoxContainer.ALIGNMENT_END
	right_h.add_theme_constant_override("separation", 16)
	top_bar.add_child(right_h)
	
	# Gem Counter Capsule
	var gem_panel := PanelContainer.new()
	gem_panel.custom_minimum_size = Vector2(215, 58)
	gem_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_capsule_style(Color("06111f"), Color("0084a8"), 22))
	right_h.add_child(gem_panel)
	
	var gem_h := HBoxContainer.new()
	gem_h.alignment = BoxContainer.ALIGNMENT_CENTER
	gem_h.add_theme_constant_override("separation", 10)
	gem_panel.add_child(gem_h)
	
	var g_icon := TextureRect.new()
	if acl:
		g_icon.texture = acl.load_texture("res://assets/ui/icon_gem_green.png")
	elif ResourceLoader.exists("res://assets/ui/icon_gem_green.png"):
		g_icon.texture = load("res://assets/ui/icon_gem_green.png")
	g_icon.custom_minimum_size = Vector2(28, 28)
	g_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_h.add_child(g_icon)
	
	_cash_label = Label.new()
	_cash_label.text = "59,752"
	_cash_label.label_settings = BrawlUITheme.make_label_settings(22, Color.WHITE, 6, 2)
	gem_h.add_child(_cash_label)
	
	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(44, 44)
	BrawlUITheme.attach_button_juice(plus_btn, Color("2ecc71"))
	plus_btn.pressed.connect(_on_plus_cash_pressed)
	gem_h.add_child(plus_btn)
	
	# Golden Orange Shop Button
	_shop_btn = Button.new()
	_shop_btn.custom_minimum_size = Vector2(165, 58)
	_shop_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_button_juice(_shop_btn, Color("f39c12"))
	_shop_btn.pressed.connect(func(): switch_tab(3))
	right_h.add_child(_shop_btn)
	
	var shop_h := HBoxContainer.new()
	shop_h.set_anchors_preset(PRESET_FULL_RECT)
	shop_h.alignment = BoxContainer.ALIGNMENT_CENTER
	shop_h.add_theme_constant_override("separation", 8)
	shop_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_btn.add_child(shop_h)
	
	var shop_lbl := Label.new()
	shop_lbl.text = "🛒 SHOP"
	shop_lbl.label_settings = BrawlUITheme.make_label_settings(20, Color("1e272e"), 0, 0)
	shop_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_h.add_child(shop_lbl)
	
	# Build Side Cards
	_build_side_cards()

func _build_side_cards() -> void:
	_side_cards_container = Control.new()
	_side_cards_container.name = "SideCardsContainer"
	_side_cards_container.set_anchors_preset(PRESET_FULL_RECT)
	_side_cards_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_side_cards_container)
	
	var acl = get_node_or_null("/root/AssetChromaLoader")
	
	# =========================================================================
	# LEFT SIDE CARDS (DAILY QUESTS & EVENT)
	# =========================================================================
	var left_vbox := VBoxContainer.new()
	left_vbox.offset_left = 24.0
	left_vbox.offset_top = 92.0
	left_vbox.offset_right = 354.0
	left_vbox.offset_bottom = 275.0
	left_vbox.add_theme_constant_override("separation", 12)
	left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side_cards_container.add_child(left_vbox)
	
	# Card 1: DAILY QUESTS
	_quests_card_btn = Button.new()
	_quests_card_btn.custom_minimum_size = Vector2(330, 84)
	_quests_card_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_arcade_button_juice(_quests_card_btn, Color("00d2d3"))
	_quests_card_btn.pressed.connect(_open_daily_quests)
	left_vbox.add_child(_quests_card_btn)
	
	var q_hbox := HBoxContainer.new()
	q_hbox.set_anchors_preset(PRESET_FULL_RECT)
	q_hbox.offset_left = 12.0
	q_hbox.offset_right = -12.0
	q_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	q_hbox.add_theme_constant_override("separation", 12)
	q_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quests_card_btn.add_child(q_hbox)
	
	# Gold gift box icon badge
	var q_icon_box := PanelContainer.new()
	q_icon_box.custom_minimum_size = Vector2(44, 44)
	q_icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var q_ib_sb := StyleBoxFlat.new()
	q_ib_sb.bg_color = Color("f39c12")
	q_ib_sb.set_corner_radius_all(10)
	q_icon_box.add_theme_stylebox_override("panel", q_ib_sb)
	q_icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q_hbox.add_child(q_icon_box)
	
	var q_ico_lbl := Label.new()
	q_ico_lbl.text = "🎁"
	q_ico_lbl.set_anchors_preset(PRESET_FULL_RECT)
	q_ico_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_ico_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q_ico_lbl.label_settings = BrawlUITheme.make_label_settings(24, Color.WHITE, 0, 0)
	q_icon_box.add_child(q_ico_lbl)
	
	var q_mid_vbox := VBoxContainer.new()
	q_mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_mid_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	q_mid_vbox.add_theme_constant_override("separation", 2)
	q_mid_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q_hbox.add_child(q_mid_vbox)
	
	var q_title := Label.new()
	q_title.text = "DAILY QUESTS"
	q_title.label_settings = BrawlUITheme.make_label_settings(15, Color.WHITE, 4, 1)
	q_mid_vbox.add_child(q_title)
	
	var q_sub := Label.new()
	q_sub.text = "Complete 3 matches"
	q_sub.label_settings = BrawlUITheme.make_label_settings(13, Color("74b9ff"), 2, 1)
	q_mid_vbox.add_child(q_sub)
	
	var q_prog_h := HBoxContainer.new()
	q_prog_h.add_theme_constant_override("separation", 8)
	q_mid_vbox.add_child(q_prog_h)
	
	_quests_progress_bar = ProgressBar.new()
	_quests_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quests_progress_bar.custom_minimum_size = Vector2(0, 6)
	_quests_progress_bar.max_value = 3.0
	_quests_progress_bar.value = 1.0
	_quests_progress_bar.show_percentage = false
	var qp_fill := StyleBoxFlat.new()
	qp_fill.bg_color = Color("f39c12")
	qp_fill.set_corner_radius_all(3)
	var qp_bg := StyleBoxFlat.new()
	qp_bg.bg_color = Color("081728")
	qp_bg.set_corner_radius_all(3)
	_quests_progress_bar.add_theme_stylebox_override("fill", qp_fill)
	_quests_progress_bar.add_theme_stylebox_override("background", qp_bg)
	q_prog_h.add_child(_quests_progress_bar)
	
	_quests_progress_label = Label.new()
	_quests_progress_label.text = "1/3"
	_quests_progress_label.label_settings = BrawlUITheme.make_label_settings(12, Color("00d2d3"), 2, 1)
	q_prog_h.add_child(_quests_progress_label)
	
	var q_chev := Label.new()
	q_chev.text = ">"
	q_chev.label_settings = BrawlUITheme.make_label_settings(22, Color("00d2d3"), 4, 1)
	q_hbox.add_child(q_chev)
	
	# Card 2: EVENT
	_event_card_btn = Button.new()
	_event_card_btn.custom_minimum_size = Vector2(330, 84)
	_event_card_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_arcade_button_juice(_event_card_btn, Color("8c7ae6"))
	_event_card_btn.pressed.connect(_open_login_calendar)
	left_vbox.add_child(_event_card_btn)
	
	var ev_hbox := HBoxContainer.new()
	ev_hbox.set_anchors_preset(PRESET_FULL_RECT)
	ev_hbox.offset_left = 12.0
	ev_hbox.offset_right = -12.0
	ev_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	ev_hbox.add_theme_constant_override("separation", 12)
	ev_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_event_card_btn.add_child(ev_hbox)
	
	var ev_icon_box := PanelContainer.new()
	ev_icon_box.custom_minimum_size = Vector2(44, 44)
	ev_icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ev_ib_sb := StyleBoxFlat.new()
	ev_ib_sb.bg_color = Color("8c7ae6")
	ev_ib_sb.set_corner_radius_all(10)
	ev_icon_box.add_theme_stylebox_override("panel", ev_ib_sb)
	ev_icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ev_hbox.add_child(ev_icon_box)
	
	var ev_ico_lbl := Label.new()
	ev_ico_lbl.text = "📅"
	ev_ico_lbl.set_anchors_preset(PRESET_FULL_RECT)
	ev_ico_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev_ico_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ev_ico_lbl.label_settings = BrawlUITheme.make_label_settings(24, Color.WHITE, 0, 0)
	ev_icon_box.add_child(ev_ico_lbl)
	
	var ev_mid_vbox := VBoxContainer.new()
	ev_mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ev_mid_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ev_mid_vbox.add_theme_constant_override("separation", 2)
	ev_mid_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ev_hbox.add_child(ev_mid_vbox)
	
	var ev_title := Label.new()
	ev_title.text = "EVENT"
	ev_title.label_settings = BrawlUITheme.make_label_settings(15, Color("a29bfe"), 4, 1)
	ev_mid_vbox.add_child(ev_title)
	
	var ev_sub := Label.new()
	ev_sub.text = "Weekend Bonus"
	ev_sub.label_settings = BrawlUITheme.make_label_settings(13, Color.WHITE, 2, 1)
	ev_mid_vbox.add_child(ev_sub)
	
	_event_timer_label = Label.new()
	_event_timer_label.text = "⏱ 2d 14h"
	_event_timer_label.label_settings = BrawlUITheme.make_label_settings(12, Color("74b9ff"), 2, 1)
	ev_mid_vbox.add_child(_event_timer_label)
	
	var ev_chev := Label.new()
	ev_chev.text = ">"
	ev_chev.label_settings = BrawlUITheme.make_label_settings(22, Color("a29bfe"), 4, 1)
	ev_hbox.add_child(ev_chev)
	
	# =========================================================================
	# RIGHT SIDE CARDS (NEW MAP & FREE REWARDS)
	# =========================================================================
	var right_vbox := VBoxContainer.new()
	right_vbox.anchor_left = 1.0
	right_vbox.anchor_right = 1.0
	right_vbox.offset_left = -354.0
	right_vbox.offset_top = 92.0
	right_vbox.offset_right = -24.0
	right_vbox.offset_bottom = 275.0
	right_vbox.add_theme_constant_override("separation", 12)
	right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side_cards_container.add_child(right_vbox)
	
	# Card 1: NEW MAP (Sky City)
	_map_card_btn = Button.new()
	_map_card_btn.custom_minimum_size = Vector2(330, 84)
	_map_card_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_arcade_button_juice(_map_card_btn, Color("00d2d3"))
	_map_card_btn.pressed.connect(_toggle_mode_drawer)
	right_vbox.add_child(_map_card_btn)
	
	var m_hbox := HBoxContainer.new()
	m_hbox.set_anchors_preset(PRESET_FULL_RECT)
	m_hbox.offset_left = 10.0
	m_hbox.offset_right = -12.0
	m_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	m_hbox.add_theme_constant_override("separation", 12)
	m_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_card_btn.add_child(m_hbox)
	
	var m_thumb := TextureRect.new()
	if acl:
		m_thumb.texture = acl.load_texture("res://assets/ui/thumb_sky_city.png")
	elif ResourceLoader.exists("res://assets/ui/thumb_sky_city.png"):
		m_thumb.texture = load("res://assets/ui/thumb_sky_city.png")
	m_thumb.custom_minimum_size = Vector2(66, 48)
	m_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	m_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	m_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m_hbox.add_child(m_thumb)
	
	var m_mid_vbox := VBoxContainer.new()
	m_mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_mid_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	m_mid_vbox.add_theme_constant_override("separation", 2)
	m_mid_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m_hbox.add_child(m_mid_vbox)
	
	var m_tag := Label.new()
	m_tag.text = "NEW MAP"
	m_tag.label_settings = BrawlUITheme.make_label_settings(13, Color("00d2d3"), 3, 1)
	m_mid_vbox.add_child(m_tag)
	
	var m_title := Label.new()
	m_title.text = "Sky City"
	m_title.label_settings = BrawlUITheme.make_label_settings(17, Color.WHITE, 4, 1)
	m_mid_vbox.add_child(m_title)
	
	var m_chev := Label.new()
	m_chev.text = ">"
	m_chev.label_settings = BrawlUITheme.make_label_settings(22, Color("00d2d3"), 4, 1)
	m_hbox.add_child(m_chev)
	
	# Card 2: FREE REWARDS (Watch Ad >)
	_free_rewards_card_btn = Button.new()
	_free_rewards_card_btn.custom_minimum_size = Vector2(330, 84)
	_free_rewards_card_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_arcade_button_juice(_free_rewards_card_btn, Color("f39c12"))
	_free_rewards_card_btn.pressed.connect(_on_claim_free_rewards_pressed)
	right_vbox.add_child(_free_rewards_card_btn)
	
	var r_hbox := HBoxContainer.new()
	r_hbox.set_anchors_preset(PRESET_FULL_RECT)
	r_hbox.offset_left = 12.0
	r_hbox.offset_right = -12.0
	r_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	r_hbox.add_theme_constant_override("separation", 12)
	r_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_free_rewards_card_btn.add_child(r_hbox)
	
	var r_icons_h := HBoxContainer.new()
	r_icons_h.add_theme_constant_override("separation", 4)
	r_icons_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r_hbox.add_child(r_icons_h)
	
	var play_box := PanelContainer.new()
	play_box.custom_minimum_size = Vector2(36, 36)
	play_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pb_sb := StyleBoxFlat.new()
	pb_sb.bg_color = Color("f39c12")
	pb_sb.set_corner_radius_all(8)
	play_box.add_theme_stylebox_override("panel", pb_sb)
	play_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pb_lbl := Label.new()
	pb_lbl.text = "▶"
	pb_lbl.set_anchors_preset(PRESET_FULL_RECT)
	pb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pb_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pb_lbl.label_settings = BrawlUITheme.make_label_settings(18, Color.WHITE, 0, 0)
	play_box.add_child(pb_lbl)
	r_icons_h.add_child(play_box)
	
	var gift_box := PanelContainer.new()
	gift_box.custom_minimum_size = Vector2(36, 36)
	gift_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gb_sb := StyleBoxFlat.new()
	gb_sb.bg_color = Color("e84118")
	gb_sb.set_corner_radius_all(8)
	gift_box.add_theme_stylebox_override("panel", gb_sb)
	gift_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gb_lbl := Label.new()
	gb_lbl.text = "🎁"
	gb_lbl.set_anchors_preset(PRESET_FULL_RECT)
	gb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gb_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gb_lbl.label_settings = BrawlUITheme.make_label_settings(18, Color.WHITE, 0, 0)
	gift_box.add_child(gb_lbl)
	r_icons_h.add_child(gift_box)
	
	var r_mid_vbox := VBoxContainer.new()
	r_mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_mid_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	r_mid_vbox.add_theme_constant_override("separation", 2)
	r_mid_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r_hbox.add_child(r_mid_vbox)
	
	var r_title := Label.new()
	r_title.text = "FREE REWARDS"
	r_title.label_settings = BrawlUITheme.make_label_settings(15, Color.WHITE, 4, 1)
	r_mid_vbox.add_child(r_title)
	
	var r_sub := Label.new()
	r_sub.text = "Watch Ad >"
	r_sub.label_settings = BrawlUITheme.make_label_settings(13, Color("fbc531"), 3, 1)
	r_mid_vbox.add_child(r_sub)
	
	var r_chev := Label.new()
	r_chev.text = ">"
	r_chev.label_settings = BrawlUITheme.make_label_settings(22, Color("fbc531"), 4, 1)
	r_hbox.add_child(r_chev)

func _on_claim_free_rewards_pressed() -> void:
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.add_cash(500)
		_refresh_top_bar()
		SoundFX.play_star_up()
		
		var toast := Label.new()
		toast.text = "🎉 +💵 500 FREE AD REWARD!"
		toast.label_settings = BrawlUITheme.make_label_settings(28, Color("fbc531"), 8, 3)
		toast.set_anchors_preset(PRESET_CENTER)
		toast.position = Vector2(960 - 200, 480)
		toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(toast)
		
		var tw := create_tween()
		tw.tween_property(toast, "position:y", 420.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(toast, "modulate:a", 0.0, 1.2).set_delay(0.4)
		tw.tween_callback(toast.queue_free)

func _open_login_calendar() -> void:
	if not _login_calendar_modal:
		_login_calendar_modal = LoginCalendarModalScene.instantiate()
		_login_calendar_modal.closed.connect(func(): _refresh_notification_badges())
		_login_calendar_modal.reward_claimed.connect(func(_day, _rew):
			_refresh_top_bar()
			_refresh_notification_badges()
			_load_showroom_car(current_view_car_id)
		)
		add_child(_login_calendar_modal)
	_login_calendar_modal.open_modal()

func _open_daily_quests() -> void:
	if not _daily_quests_drawer:
		_daily_quests_drawer = DailyQuestsDrawerScene.instantiate()
		_daily_quests_drawer.closed.connect(func(): _refresh_notification_badges())
		_daily_quests_drawer.quest_claimed.connect(func(_id, _rew):
			_refresh_top_bar()
			_refresh_notification_badges()
		)
		_daily_quests_drawer.safe_claimed.connect(func(_cash, _item):
			_refresh_top_bar()
			_refresh_notification_badges()
			_load_showroom_car(current_view_car_id)
		)
		add_child(_daily_quests_drawer)
	_daily_quests_drawer.open_drawer()

func _refresh_notification_badges() -> void:
	if has_node("/root/ProgressionManager"):
		var pm = get_node("/root/ProgressionManager")
		if _quests_progress_bar:
			_quests_progress_bar.value = 1.0 if not pm.has_unclaimed_rewards() else 3.0

func _refresh_top_bar() -> void:
	if has_node("/root/SaveManager"):
		var sm: SaveManagerClass = get_node("/root/SaveManager") as SaveManagerClass
		if _cash_label:
			_cash_label.text = "59,752" if sm.total_cash <= 200 else ("%d" % sm.total_cash)
		if _streak_label:
			var s_val: int = sm.daily_streak if sm.daily_streak > 0 else 3
			_streak_label.text = "%d DAY STREAK" % s_val
		if _trophy_label:
			var t_val: int = sm.best_daily_score if sm.best_daily_score > 0 else 210337
			_trophy_label.text = "%d" % t_val
		if _level_label:
			var lvl: int = 12 if sm.total_cash <= 200 else (1 + int(sm.total_cash / 500))
			_level_label.text = "Lv. %d" % lvl
		if _level_progress_bar:
			_level_progress_bar.value = 0.65

func _on_plus_cash_pressed() -> void:
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.add_cash(100)
		_refresh_top_bar()
		SoundFX.play_star_up()

# ==============================================================================
# LAYER 3: MODE SELECTOR BAR & GIANT "SMASH!" PLAY DOCK
# ==============================================================================

func _build_layer_3_home_dock() -> void:
	_home_dock_container = Control.new()
	_home_dock_container.name = "Layer3_HomeDock"
	_home_dock_container.anchor_left = 1.0
	_home_dock_container.anchor_top = 1.0
	_home_dock_container.anchor_right = 1.0
	_home_dock_container.anchor_bottom = 1.0
	_home_dock_container.offset_left = -860.0
	_home_dock_container.offset_top = -190.0
	_home_dock_container.offset_right = -15.0
	_home_dock_container.offset_bottom = -15.0
	_home_dock_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_home_dock_container)
	
	var dock_hbox := HBoxContainer.new()
	dock_hbox.set_anchors_preset(PRESET_FULL_RECT)
	dock_hbox.alignment = BoxContainer.ALIGNMENT_END
	dock_hbox.add_theme_constant_override("separation", 18)
	dock_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_dock_container.add_child(dock_hbox)
	
	var acl = get_node_or_null("/root/AssetChromaLoader")
	
	# Left: Slanted Mode Selector Card
	_mode_card_btn = Button.new()
	_mode_card_btn.custom_minimum_size = Vector2(380, 110)
	_mode_card_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mode_card_btn.focus_mode = Control.FOCUS_NONE
	BrawlUITheme.attach_arcade_button_juice(_mode_card_btn, Color("00d2d3"))
	_mode_card_btn.pressed.connect(_toggle_mode_drawer)
	dock_hbox.add_child(_mode_card_btn)
	
	var mode_h := HBoxContainer.new()
	mode_h.set_anchors_preset(PRESET_FULL_RECT)
	mode_h.offset_left = 14.0
	mode_h.offset_right = -10.0
	mode_h.alignment = BoxContainer.ALIGNMENT_BEGIN
	mode_h.add_theme_constant_override("separation", 12)
	mode_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_card_btn.add_child(mode_h)
	
	var m_gift_ico := Label.new()
	m_gift_ico.text = "🎁"
	m_gift_ico.label_settings = BrawlUITheme.make_label_settings(32, Color.WHITE, 0, 0)
	m_gift_ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_h.add_child(m_gift_ico)
	
	var mode_vbox := VBoxContainer.new()
	mode_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_vbox.add_theme_constant_override("separation", 3)
	mode_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_h.add_child(mode_vbox)
	
	_mode_title_label = Label.new()
	_mode_title_label.text = "DAILY GETAWAY"
	_mode_title_label.label_settings = BrawlUITheme.make_label_settings(20, Color("00d2d3"), 5, 2)
	mode_vbox.add_child(_mode_title_label)
	
	_mode_desc_label = Label.new()
	_mode_desc_label.text = "TAP TO CHANGE MODE"
	_mode_desc_label.label_settings = BrawlUITheme.make_label_settings(13, Color("fbc531"), 3, 1)
	mode_vbox.add_child(_mode_desc_label)
	
	_mode_thumb_rect = TextureRect.new()
	_mode_thumb_rect.texture = BrawlUITheme.load_texture_safe("res://assets/modes/mode_daily_getaway.png")
	_mode_thumb_rect.custom_minimum_size = Vector2(104, 58)
	_mode_thumb_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mode_thumb_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_mode_thumb_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_h.add_child(_mode_thumb_rect)
	
	# Right: Giant Primary "SMASH!" Play Button with Transparent Background
	var smash_btn := TextureButton.new()
	smash_btn.custom_minimum_size = Vector2(380, 155)
	smash_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	smash_btn.focus_mode = Control.FOCUS_NONE
	smash_btn.ignore_texture_size = true
	smash_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	
	var tex_normal: Texture2D = null
	var tex_hover: Texture2D = null
	var tex_pressed: Texture2D = null
	var tex_disabled: Texture2D = null
	
	if acl:
		tex_normal = acl.load_texture("res://assets/ui/btn_smash_normal.png")
		tex_hover = acl.load_texture("res://assets/ui/btn_smash_hover.png")
		tex_pressed = acl.load_texture("res://assets/ui/btn_smash_pressed.png")
		tex_disabled = acl.load_texture("res://assets/ui/btn_smash_disabled.png")
	
	if not tex_normal and ResourceLoader.exists("res://assets/ui/btn_smash_play.png"):
		tex_normal = load("res://assets/ui/btn_smash_play.png")
	
	smash_btn.texture_normal = tex_normal
	smash_btn.texture_hover = tex_hover if tex_hover else tex_normal
	smash_btn.texture_pressed = tex_pressed if tex_pressed else tex_normal
	smash_btn.texture_disabled = tex_disabled if tex_disabled else tex_normal
	
	smash_btn.pivot_offset = Vector2(180, 72.5)
	smash_btn.resized.connect(func():
		if is_instance_valid(smash_btn):
			smash_btn.pivot_offset = smash_btn.size * 0.5
	)
	
	# Bounce scale juice on hover and click
	smash_btn.mouse_entered.connect(func():
		var tw := smash_btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(smash_btn, "scale", Vector2(1.06, 1.06), 0.12)
	)
	smash_btn.mouse_exited.connect(func():
		var tw := smash_btn.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(smash_btn, "scale", Vector2.ONE, 0.12)
	)
	smash_btn.button_down.connect(func():
		var tw := smash_btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(smash_btn, "scale", Vector2(0.93, 0.93), 0.06)
		SoundFX.play_ui_click()
	)
	smash_btn.button_up.connect(func():
		var tw := smash_btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(smash_btn, "scale", Vector2(1.08, 1.08), 0.08)
		tw.chain().tween_property(smash_btn, "scale", Vector2.ONE, 0.08)
	)
	
	smash_btn.pressed.connect(_on_smash_play_pressed)
	dock_hbox.add_child(smash_btn)
	_smash_play_button = smash_btn
	
	_build_mode_selector_drawer()

func _start_smash_pulse() -> void:
	if not _smash_play_button:
		return
	if _smash_pulse_tween and _smash_pulse_tween.is_valid():
		_smash_pulse_tween.kill()
	
	_smash_pulse_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_smash_pulse_tween.tween_property(_smash_play_button, "scale", Vector2(1.04, 1.04), 0.7)
	_smash_pulse_tween.tween_property(_smash_play_button, "scale", Vector2.ONE, 0.7)

func _refresh_mode_display() -> void:
	if has_node("/root/GameModeManager"):
		var gmm = get_node("/root/GameModeManager")
		current_mode_index = clampi(int(gmm.current_mode), 0, MODE_DEFS.size() - 1)
	
	var mdef: Dictionary = MODE_DEFS[current_mode_index]
	if _mode_title_label:
		if current_mode_index == 3 and has_node("/root/GameModeManager"):
			var gmm = get_node("/root/GameModeManager")
			var t_info: Dictionary = gmm.get_kart_track_info()
			_mode_title_label.text = "🏁 KART: %s" % str(t_info.get("title", "Neon Circuit"))
		else:
			_mode_title_label.text = str(mdef["name"])
	if _mode_thumb_rect:
		var thumb_path: String = String(mdef.get("thumb", "res://assets/modes/mode_daily_getaway.png"))
		_mode_thumb_rect.texture = BrawlUITheme.load_texture_safe(thumb_path)

func _on_smash_play_pressed() -> void:
	SoundFX.play_ui_click()
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if current_view_car_id != "" and sm.equipped_car_id != current_view_car_id:
			sm.equip_car(current_view_car_id)
	play_pressed.emit(current_mode_index)
	
	if has_node("/root/SceneTransitionManager"):
		var stm = get_node("/root/SceneTransitionManager")
		stm.transition_to_scene("res://scenes/world/main_game.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/world/main_game.tscn")

func _build_mode_selector_drawer() -> void:
	if _mode_drawer_panel and is_instance_valid(_mode_drawer_panel):
		_mode_drawer_panel.queue_free()
	
	# Full-screen dimmed modal layer with highest z-index
	_mode_drawer_panel = Control.new()
	_mode_drawer_panel.name = "ModeDrawerModal"
	_mode_drawer_panel.set_anchors_preset(PRESET_FULL_RECT)
	_mode_drawer_panel.z_index = 250
	_mode_drawer_panel.visible = false
	add_child(_mode_drawer_panel)
	
	# Backdrop Dimmer (click outside to close)
	var backdrop_btn := Button.new()
	backdrop_btn.name = "ModalBackdrop"
	backdrop_btn.set_anchors_preset(PRESET_FULL_RECT)
	backdrop_btn.flat = true
	var backdrop_sb := StyleBoxFlat.new()
	backdrop_sb.bg_color = Color(0.04, 0.07, 0.11, 0.85)
	backdrop_btn.add_theme_stylebox_override("normal", backdrop_sb)
	backdrop_btn.add_theme_stylebox_override("hover", backdrop_sb)
	backdrop_btn.add_theme_stylebox_override("pressed", backdrop_sb)
	backdrop_btn.pressed.connect(func(): _mode_drawer_panel.visible = false)
	_mode_drawer_panel.add_child(backdrop_btn)
	
	# Center container to position card
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_mode_drawer_panel.add_child(center)
	
	# Center card container
	var card := PanelContainer.new()
	card.name = "ModeCardContainer"
	card.custom_minimum_size = Vector2(980, 680)
	card.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("151f2b"), Color("fbc531"), 0.05, 24))
	center.add_child(card)
	
	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 28)
	card_margin.add_theme_constant_override("margin_top", 18)
	card_margin.add_theme_constant_override("margin_right", 28)
	card_margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(card_margin)
	
	var mv := VBoxContainer.new()
	mv.name = "ModalVBox"
	mv.add_theme_constant_override("separation", 10)
	card_margin.add_child(mv)
	
	var title := Label.new()
	title.text = "SELECT GAME MODE"
	title.label_settings = BrawlUITheme.make_label_settings(32, Color("fbc531"), 8, 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(title)
	
	var acl = get_node_or_null("/root/AssetChromaLoader")
	
	var mode_grid := GridContainer.new()
	mode_grid.name = "ModeCardsGrid"
	mode_grid.columns = 2
	mode_grid.add_theme_constant_override("h_separation", 16)
	mode_grid.add_theme_constant_override("v_separation", 14)
	mv.add_child(mode_grid)
	
	for def in MODE_DEFS:
		var mid: int = int(def["id"])
		var is_selected: bool = (mid == current_mode_index)
		
		var card_btn := Button.new()
		card_btn.custom_minimum_size = Vector2(450, 150)
		card_btn.clip_contents = true
		var border_color: Color = Color("fbc531") if is_selected else Color("1e2c3c")
		card_btn.add_theme_stylebox_override("normal", BrawlUITheme.make_card_style(Color("101b2a"), border_color, 0.0, 16))
		card_btn.add_theme_stylebox_override("hover", BrawlUITheme.make_card_style(Color("162438"), Color("00d2d3"), 0.0, 16))
		card_btn.add_theme_stylebox_override("pressed", BrawlUITheme.make_card_style(Color("0c1420"), Color("fbc531"), 0.0, 16))
		
		# Banner texture
		var b_tex := TextureRect.new()
		b_tex.set_anchors_preset(PRESET_FULL_RECT)
		b_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var thumb_path: String = str(def["thumb"])
		b_tex.texture = BrawlUITheme.load_texture_safe(thumb_path)
		b_tex.modulate = Color(1.0, 1.0, 1.0, 0.50) if not is_selected else Color(1.0, 1.0, 1.0, 0.95)
		b_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_btn.add_child(b_tex)
		
		# Tint
		var tint := ColorRect.new()
		tint.set_anchors_preset(PRESET_FULL_RECT)
		tint.color = Color(0.02, 0.04, 0.08, 0.22) if not is_selected else Color(0.0, 0.0, 0.0, 0.0)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_btn.add_child(tint)
		
		# Content VBox
		var cv := VBoxContainer.new()
		cv.set_anchors_preset(PRESET_FULL_RECT)
		cv.offset_left = 18.0
		cv.offset_top = 16.0
		cv.offset_right = -18.0
		cv.offset_bottom = -14.0
		cv.alignment = BoxContainer.ALIGNMENT_END
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_btn.add_child(cv)
		
		if is_selected:
			var sel_badge := Label.new()
			sel_badge.text = "★ ACTIVE MODE ★"
			sel_badge.label_settings = BrawlUITheme.make_label_settings(14, Color("fbc531"), 4, 1)
			cv.add_child(sel_badge)
		
		var name_lbl := Label.new()
		name_lbl.text = str(def["name"])
		name_lbl.label_settings = BrawlUITheme.make_label_settings(22, Color.WHITE, 6, 2)
		cv.add_child(name_lbl)
		
		var desc_lbl := Label.new()
		desc_lbl.text = str(def["desc"])
		desc_lbl.label_settings = BrawlUITheme.make_label_settings(13, Color("00d2d3"), 3, 1)
		cv.add_child(desc_lbl)
		
		card_btn.pressed.connect(func():
			current_mode_index = mid
			if has_node("/root/GameModeManager"):
				var gmm = get_node("/root/GameModeManager")
				gmm.set_mode(mid)
			_refresh_mode_display()
			_build_mode_selector_drawer()
			if mid != 3:
				_mode_drawer_panel.visible = false
			else:
				_mode_drawer_panel.visible = true
		)
		mode_grid.add_child(card_btn)

	# Grand Prix Cup Track selection drawer row
	var track_box := VBoxContainer.new()
	track_box.name = "KartTrackSelectorBox"
	track_box.add_theme_constant_override("separation", 6)
	
	var track_header := Label.new()
	track_header.text = "🏁 SELECT CUP CIRCUIT:"
	track_header.label_settings = BrawlUITheme.make_label_settings(20, Color("ff3f34"), 6, 2)
	track_box.add_child(track_header)

	var track_hbox := HBoxContainer.new()
	track_hbox.add_theme_constant_override("separation", 12)
	var cup_names = ["🏙️ NEON DOWNTOWN", "🐉 DRAGON CHINATOWN", "🏜️ CANYON HIGHWAY"]
	for tid in range(3):
		var tbtn := Button.new()
		tbtn.text = cup_names[tid]
		tbtn.custom_minimum_size = Vector2(240, 50)
		tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		BrawlUITheme.attach_button_juice(tbtn, Color("101a26"))
		var c_track_id: int = tid
		tbtn.pressed.connect(func():
			if has_node("/root/GameModeManager"):
				var gmm = get_node("/root/GameModeManager")
				gmm.set_kart_cup_track(c_track_id)
				gmm.set_mode(3)
			current_mode_index = 3
			_refresh_mode_display()
			_mode_drawer_panel.visible = false
		)
		track_hbox.add_child(tbtn)
	track_box.add_child(track_hbox)
	mv.add_child(track_box)
	
	var close_btn := Button.new()
	close_btn.text = "BACK / CLOSE"
	close_btn.custom_minimum_size = Vector2(0, 60)
	close_btn.add_theme_font_size_override("font_size", 20)
	BrawlUITheme.attach_candy_button_juice(close_btn, "red")
	close_btn.pressed.connect(func(): _mode_drawer_panel.visible = false)
	mv.add_child(close_btn)

func _toggle_mode_drawer() -> void:
	if _mode_drawer_panel:
		_mode_drawer_panel.visible = not _mode_drawer_panel.visible
		if _mode_drawer_panel.visible:
			_mode_drawer_panel.move_to_front()
			_build_mode_selector_drawer()
			_mode_drawer_panel.visible = true
			_mode_drawer_panel.move_to_front()

func _build_tab_drawers() -> void:
	# Tab 1: Dedicated CARS Screen (Collect, Upgrade, Race)
	var cars_cls = load("res://scripts/ui/cars_screen.gd")
	if cars_cls:
		_cars_screen = cars_cls.new()
		_cars_screen.name = "CarsScreen"
		_cars_screen.visible = false
		_cars_screen.back_pressed.connect(func(): switch_tab(0))
		_cars_screen.home_pressed.connect(func(): switch_tab(0))
		_cars_screen.car_selected.connect(func(cid): _load_showroom_car(cid))
		add_child(_cars_screen)
	
	# Tab 2: Dedicated GEAR Screen (Boost Your Performance)
	var gear_cls = load("res://scripts/ui/gear_screen.gd")
	if gear_cls:
		_gear_screen = gear_cls.new()
		_gear_screen.name = "GearScreen"
		_gear_screen.visible = false
		_gear_screen.back_pressed.connect(func(): switch_tab(0))
		_gear_screen.home_pressed.connect(func(): switch_tab(0))
		_gear_screen.gear_equipped.connect(func(_slot, _item): _load_showroom_car(current_view_car_id))
		add_child(_gear_screen)
	
	# Tab 3: Dedicated GACHA Screen (Get New Cars, Gear, Skins)
	var gacha_cls = load("res://scripts/ui/gacha_screen.gd")
	if gacha_cls:
		_gacha_screen = gacha_cls.new()
		_gacha_screen.name = "GachaScreen"
		_gacha_screen.visible = false
		_gacha_screen.back_pressed.connect(func(): switch_tab(0))
		_gacha_screen.home_pressed.connect(func(): switch_tab(0))
		add_child(_gacha_screen)
	
	_build_friends_squad_drawer()
	_build_ranks_drawer()

# --- TAB 2: 3-SLOT CAR GEAR INVENTORY ---
func _build_inventory_drawer() -> void:
	_inventory_drawer = PanelContainer.new()
	_inventory_drawer.name = "InventoryDrawer"
	_inventory_drawer.set_anchors_preset(PRESET_FULL_RECT)
	_inventory_drawer.offset_left = 60.0
	_inventory_drawer.offset_top = 110.0
	_inventory_drawer.offset_right = -60.0
	_inventory_drawer.offset_bottom = -150.0
	_inventory_drawer.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("0f141d"), Color("0d1117"), 0.0, 24))
	_inventory_drawer.visible = false
	add_child(_inventory_drawer)
	
	_inventory_panel = InventoryPanelScene.instantiate()
	_inventory_panel.loadout_changed.connect(func(_slot, _item):
		_load_showroom_car(current_view_car_id)
	)
	_inventory_drawer.add_child(_inventory_panel)

# --- TAB 4: FRIENDS & SQUAD LOBBY ---
func _build_friends_squad_drawer() -> void:
	_friends_squad_drawer = PanelContainer.new()
	_friends_squad_drawer.name = "FriendsSquadDrawer"
	_friends_squad_drawer.set_anchors_preset(PRESET_FULL_RECT)
	_friends_squad_drawer.offset_left = 60.0
	_friends_squad_drawer.offset_top = 110.0
	_friends_squad_drawer.offset_right = -60.0
	_friends_squad_drawer.offset_bottom = -150.0
	_friends_squad_drawer.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("0f141d"), Color("0d1117"), 0.0, 24))
	_friends_squad_drawer.visible = false
	add_child(_friends_squad_drawer)
	
	_friends_squad_panel = FriendsSquadPanelScene.instantiate()
	_friends_squad_panel.squad_updated.connect(_refresh_showroom_squad)
	_friends_squad_panel.closed.connect(func(): switch_tab(0))
	if _friends_squad_panel.has_signal("return_requested"):
		_friends_squad_panel.return_requested.connect(func(): switch_tab(0))
	_friends_squad_drawer.add_child(_friends_squad_panel)

# --- TAB 1: CARS BRAWLER GRID ---
func _build_cars_drawer() -> void:
	_cars_drawer = PanelContainer.new()
	_cars_drawer.name = "CarsDrawer"
	_cars_drawer.set_anchors_preset(PRESET_FULL_RECT)
	_cars_drawer.offset_left = 60.0
	_cars_drawer.offset_top = 110.0
	_cars_drawer.offset_right = -60.0
	_cars_drawer.offset_bottom = -150.0
	_cars_drawer.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("0f141d"), Color("0d1117"), 0.0, 24))
	_cars_drawer.visible = false
	add_child(_cars_drawer)
	
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 14)
	_cars_drawer.add_child(cv)
	
	var title := Label.new()
	title.text = "🏎️ BRAWLER CARS GARAGE"
	title.label_settings = BrawlUITheme.make_label_settings(36, Color("fbc531"), 8, 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(title)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(scroll)
	
	_cars_grid = GridContainer.new()
	_cars_grid.columns = 4
	_cars_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cars_grid.add_theme_constant_override("h_separation", 16)
	_cars_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_cars_grid)
	
	_populate_cars_grid()

func _populate_cars_grid() -> void:
	if not _cars_grid:
		return
	for c in _cars_grid.get_children():
		c.queue_free()
	
	var sm = get_node_or_null("/root/SaveManager")
	var equipped_id: String = sm.equipped_car_id if sm else "default_coupe"
	
	for car_id in ALL_CAR_IDS:
		var info: Dictionary = CAR_DATA.get(car_id, CAR_DATA["default_coupe"])
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(480, 320)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("1e272e"), Color("0d1117"), 0.04, 18))
		_cars_grid.add_child(card)
		
		var card_v := VBoxContainer.new()
		card_v.add_theme_constant_override("separation", 8)
		card.add_child(card_v)
		
		# Name & Rarity
		var name_lbl := Label.new()
		name_lbl.text = str(info["name"])
		name_lbl.label_settings = BrawlUITheme.make_label_settings(24, Color.WHITE, 6, 2)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_v.add_child(name_lbl)
		
		var rar_lbl := Label.new()
		rar_lbl.text = str(info["rarity"])
		rar_lbl.label_settings = BrawlUITheme.make_label_settings(16, info["rarity_color"], 4, 1)
		rar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_v.add_child(rar_lbl)
		
		# Stat Bars
		card_v.add_child(_make_stat_row("SPD", float(info["speed"]), Color("00d2d3")))
		card_v.add_child(_make_stat_row("ACC", float(info["accel"]), Color("fbc531")))
		card_v.add_child(_make_stat_row("HND", float(info["handling"]), Color("44bd32")))
		
		# Buttons Row: Equip & Preview
		var btn_h := HBoxContainer.new()
		btn_h.add_theme_constant_override("separation", 10)
		card_v.add_child(btn_h)
		
		var is_equipped: bool = (car_id == equipped_id)
		var equip_btn := Button.new()
		equip_btn.text = "EQUIPPED" if is_equipped else "EQUIP"
		equip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		BrawlUITheme.attach_button_juice(equip_btn, Color("44bd32") if is_equipped else Color("0984e3"))
		equip_btn.disabled = is_equipped
		
		var target_id := car_id
		equip_btn.pressed.connect(func():
			if has_node("/root/SaveManager"):
				var save_mgr = get_node("/root/SaveManager")
				save_mgr.equip_car(target_id)
			_load_showroom_car(target_id)
			_populate_cars_grid()
		)
		btn_h.add_child(equip_btn)
		
		var prev_btn := Button.new()
		prev_btn.text = "👁️ VIEW"
		prev_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		BrawlUITheme.attach_button_juice(prev_btn, Color("2f3640"))
		prev_btn.pressed.connect(func():
			_load_showroom_car(target_id)
			switch_tab(0) # Return to 3D showroom
		)
		btn_h.add_child(prev_btn)

func _make_stat_row(label_text: String, fill_ratio: float, bar_color: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(50, 0)
	lbl.label_settings = BrawlUITheme.make_label_settings(16, Color("718093"), 4, 1)
	h.add_child(lbl)
	
	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 14)
	bar.max_value = 1.0
	bar.value = fill_ratio
	bar.show_percentage = false
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = bar_color
	sb.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", sb)
	h.add_child(bar)
	return h

# --- TAB 2: MEGA BOX GACHA SCREEN ---
func _build_gacha_drawer() -> void:
	_gacha_drawer = PanelContainer.new()
	_gacha_drawer.name = "GachaDrawer"
	_gacha_drawer.set_anchors_preset(PRESET_FULL_RECT)
	_gacha_drawer.offset_left = 60.0
	_gacha_drawer.offset_top = 110.0
	_gacha_drawer.offset_right = -60.0
	_gacha_drawer.offset_bottom = -150.0
	_gacha_drawer.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("0f141d"), Color("0d1117"), 0.0, 24))
	_gacha_drawer.visible = false
	add_child(_gacha_drawer)
	
	var gv := VBoxContainer.new()
	gv.alignment = BoxContainer.ALIGNMENT_CENTER
	gv.add_theme_constant_override("separation", 24)
	_gacha_drawer.add_child(gv)
	
	var title := Label.new()
	title.text = "🎁 MEGA BOX GACHA"
	title.label_settings = BrawlUITheme.make_label_settings(42, Color("fbc531"), 10, 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(title)
	
	var desc := Label.new()
	desc.text = "Crack open for Rare Brawlers, Cash, and Power Tokens!"
	desc.label_settings = BrawlUITheme.make_label_settings(20, Color("f5f6fa"), 6, 2)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(desc)
	
	# Centered Bouncing Chest Button
	var chest_center := CenterContainer.new()
	gv.add_child(chest_center)
	
	_gacha_box_btn = Button.new()
	_gacha_box_btn.custom_minimum_size = Vector2(260, 260)
	BrawlUITheme.attach_button_juice(_gacha_box_btn, Color("8c7ae6"))
	
	var box_icon := Label.new()
	box_icon.text = "📦"
	box_icon.set_anchors_preset(PRESET_FULL_RECT)
	box_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box_icon.label_settings = BrawlUITheme.make_label_settings(110, Color.WHITE, 0, 0)
	box_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gacha_box_btn.add_child(box_icon)
	
	_gacha_box_btn.pressed.connect(_on_open_mega_box)
	chest_center.add_child(_gacha_box_btn)
	_start_chest_bounce()
	
	# Open Button
	var open_btn := Button.new()
	open_btn.custom_minimum_size = Vector2(420, 72)
	open_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	BrawlUITheme.attach_button_juice(open_btn, Color("f39c12"))
	
	var open_lbl := Label.new()
	open_lbl.text = "OPEN MEGA BOX (💵 100)"
	open_lbl.set_anchors_preset(PRESET_FULL_RECT)
	open_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	open_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	open_lbl.label_settings = BrawlUITheme.make_label_settings(26, Color.WHITE, 8, 3)
	open_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	open_btn.add_child(open_lbl)
	open_btn.pressed.connect(_on_open_mega_box)
	gv.add_child(open_btn)
	
	# Result Banner
	_gacha_result_panel = PanelContainer.new()
	_gacha_result_panel.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("2f3640"), Color("0d1117"), 0.04, 18))
	_gacha_result_panel.custom_minimum_size = Vector2(500, 80)
	_gacha_result_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_gacha_result_panel.visible = false
	gv.add_child(_gacha_result_panel)
	
	_gacha_result_label = Label.new()
	_gacha_result_label.text = ""
	_gacha_result_label.label_settings = BrawlUITheme.make_label_settings(24, Color("fbc531"), 8, 3)
	_gacha_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gacha_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gacha_result_panel.add_child(_gacha_result_label)

func _start_chest_bounce() -> void:
	if not _gacha_box_btn:
		return
	if _gacha_box_tween and _gacha_box_tween.is_valid():
		_gacha_box_tween.kill()
	
	_gacha_box_tween = create_tween().set_loops().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_gacha_box_tween.tween_property(_gacha_box_btn, "scale", Vector2(1.12, 0.88), 0.5)
	_gacha_box_tween.tween_property(_gacha_box_btn, "scale", Vector2(0.92, 1.12), 0.3)
	_gacha_box_tween.tween_property(_gacha_box_btn, "scale", Vector2.ONE, 0.4)

func _on_open_mega_box() -> void:
	var sm: SaveManagerClass = get_node_or_null("/root/SaveManager") as SaveManagerClass
	if sm and sm.total_cash < 100:
		_gacha_result_panel.visible = true
		_gacha_result_label.text = "❌ NEED 💵 100 CASH!"
		SoundFX.play_smash_hit()
		return
	
	if sm:
		sm.spend_cash(100)
		_refresh_top_bar()
	
	SoundFX.play_explosion()
	
	# Dramatic chest shake & reveal
	var shake_tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	shake_tw.tween_property(_gacha_box_btn, "rotation", 0.15, 0.05)
	shake_tw.tween_property(_gacha_box_btn, "rotation", -0.15, 0.05)
	shake_tw.tween_property(_gacha_box_btn, "rotation", 0.0, 0.05)
	shake_tw.tween_property(_gacha_box_btn, "scale", Vector2(1.3, 1.3), 0.15)
	shake_tw.chain().tween_property(_gacha_box_btn, "scale", Vector2.ONE, 0.2)
	
	shake_tw.tween_callback(func():
		var reward_cash: int = [50, 150, 250, 500].pick_random()
		if sm:
			sm.add_cash(reward_cash)
			_refresh_top_bar()
		SoundFX.play_star_up()
		_gacha_result_panel.visible = true
		_gacha_result_label.text = "🎉 JACKPOT! +💵 %d CASH!" % reward_cash
	)

# --- TAB 3: LEADERBOARD RANKS ---
func _build_ranks_drawer() -> void:
	_ranks_drawer = PanelContainer.new()
	_ranks_drawer.name = "RanksDrawer"
	_ranks_drawer.set_anchors_preset(PRESET_FULL_RECT)
	_ranks_drawer.offset_left = 60.0
	_ranks_drawer.offset_top = 110.0
	_ranks_drawer.offset_right = -60.0
	_ranks_drawer.offset_bottom = -150.0
	_ranks_drawer.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(Color("0f141d"), Color("0d1117"), 0.0, 24))
	_ranks_drawer.visible = false
	add_child(_ranks_drawer)
	
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 16)
	_ranks_drawer.add_child(rv)
	
	var title := Label.new()
	title.text = "🏆 GLOBAL DAILY LEADERBOARD"
	title.label_settings = BrawlUITheme.make_label_settings(36, Color("fbc531"), 8, 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(title)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(scroll)
	
	_ranks_list_vbox = VBoxContainer.new()
	_ranks_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ranks_list_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(_ranks_list_vbox)
	
	_populate_ranks_list()

func _populate_ranks_list() -> void:
	if not _ranks_list_vbox:
		return
	for c in _ranks_list_vbox.get_children():
		c.queue_free()
	
	var mock_ranks: Array[Dictionary] = [
		{"rank": 1, "name": "ViperStrike", "score": 14250, "car": "CYBER INTERCEPTOR"},
		{"rank": 2, "name": "SmashKing99", "score": 11800, "car": "ARMORED BULLDOZER"},
		{"rank": 3, "name": "TokyoDrifter", "score": 9650, "car": "ICE CREAM DRIFTER"},
		{"rank": 4, "name": "TukTukTurbo", "score": 8420, "car": "TUK TUK JET"},
		{"rank": 5, "name": "HeistMaster", "score": 7100, "car": "DEFAULT COUPE"}
	]
	
	for entry in mock_ranks:
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 64)
		var r_color := Color("f1c40f") if entry["rank"] == 1 else (Color("bdc3c7") if entry["rank"] == 2 else (Color("e67e22") if entry["rank"] == 3 else Color("2f3640")))
		row.add_theme_stylebox_override("panel", BrawlUITheme.make_card_style(r_color, Color("0d1117"), 0.04, 16))
		_ranks_list_vbox.add_child(row)
		
		var rh := HBoxContainer.new()
		rh.add_theme_constant_override("separation", 20)
		row.add_child(rh)
		
		var r_lbl := Label.new()
		r_lbl.text = "#%d" % int(entry["rank"])
		r_lbl.custom_minimum_size = Vector2(60, 0)
		r_lbl.label_settings = BrawlUITheme.make_label_settings(24, Color.WHITE, 6, 2)
		rh.add_child(r_lbl)
		
		var name_lbl := Label.new()
		name_lbl.text = "%s (%s)" % [str(entry["name"]), str(entry["car"])]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.label_settings = BrawlUITheme.make_label_settings(22, Color.WHITE, 6, 2)
		rh.add_child(name_lbl)
		
		var score_lbl := Label.new()
		score_lbl.text = "%d PTS" % int(entry["score"])
		score_lbl.label_settings = BrawlUITheme.make_label_settings(24, Color("fbc531"), 8, 3)
		rh.add_child(score_lbl)

# ==============================================================================
# LAYER 4: BOTTOM 5-TAB NAVIGATION DOCK (Anchored to bottom 180px)
# ==============================================================================

func _build_layer_4_bottom_dock() -> void:
	_bottom_dock_container = PanelContainer.new()
	_bottom_dock_container.name = "Layer4_BottomDock"
	_bottom_dock_container.anchor_top = 1.0
	_bottom_dock_container.anchor_bottom = 1.0
	_bottom_dock_container.offset_left = 20.0
	_bottom_dock_container.offset_top = -135.0
	_bottom_dock_container.offset_right = 680.0
	_bottom_dock_container.offset_bottom = -15.0
	_bottom_dock_container.add_theme_stylebox_override("panel", BrawlUITheme.make_capsule_style(Color("081423ee"), Color("0e2744"), 24))
	add_child(_bottom_dock_container)
	
	var tab_hbox := HBoxContainer.new()
	tab_hbox.set_anchors_preset(PRESET_FULL_RECT)
	tab_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_hbox.add_theme_constant_override("separation", 6)
	_bottom_dock_container.add_child(tab_hbox)
	
	var tab_titles: Array[String] = ["HOME", "CARS", "GEAR", "GACHA", "SOCIAL"]
	var tab_icon_paths: Array[String] = [
		"res://assets/ui/icon_tab_home.png",
		"res://assets/ui/icon_tab_cars.png",
		"res://assets/ui/icon_tab_gear.png",
		"res://assets/ui/icon_tab_gacha.png",
		"res://assets/ui/icon_tab_friends.png"
	]
	var acl = get_node_or_null("/root/AssetChromaLoader")
	_tab_buttons.clear()
	_tab_labels.clear()
	_tab_icons.clear()
	
	for i in range(tab_titles.size()):
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(118, 82)
		btn.focus_mode = Control.FOCUS_NONE
		
		var bh := HBoxContainer.new()
		bh.set_anchors_preset(PRESET_FULL_RECT)
		bh.alignment = BoxContainer.ALIGNMENT_CENTER
		bh.add_theme_constant_override("separation", 8)
		bh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bh)
		
		var t_icon := TextureRect.new()
		if acl:
			t_icon.texture = acl.load_texture(tab_icon_paths[i])
		t_icon.custom_minimum_size = Vector2(28, 28)
		t_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bh.add_child(t_icon)
		_tab_icons.append(t_icon)
		
		var lbl := Label.new()
		lbl.text = tab_titles[i]
		lbl.label_settings = BrawlUITheme.make_label_settings(18, Color.WHITE, 4, 1)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bh.add_child(lbl)
		_tab_labels.append(lbl)
		
		var tab_idx := i
		btn.pressed.connect(func(): switch_tab(tab_idx))
		tab_hbox.add_child(btn)
		_tab_buttons.append(btn)

func switch_tab(tab_idx: int) -> void:
	active_tab_index = tab_idx
	
	# Update Tab Button styles
	for i in range(_tab_buttons.size()):
		var b: Button = _tab_buttons[i]
		var is_active: bool = (i == tab_idx)
		if is_active:
			b.add_theme_stylebox_override("normal", BrawlUITheme.make_active_tab_style())
			b.add_theme_stylebox_override("hover", BrawlUITheme.make_active_tab_style())
			b.add_theme_stylebox_override("pressed", BrawlUITheme.make_active_tab_style())
			if i < _tab_labels.size() and _tab_labels[i]:
				_tab_labels[i].label_settings.font_color = Color("fbc531")
		else:
			b.add_theme_stylebox_override("normal", BrawlUITheme.make_inactive_tab_style())
			b.add_theme_stylebox_override("hover", BrawlUITheme.make_inactive_tab_style())
			b.add_theme_stylebox_override("pressed", BrawlUITheme.make_inactive_tab_style())
			if i < _tab_labels.size() and _tab_labels[i]:
				_tab_labels[i].label_settings.font_color = Color("a4b0be")
	
	# Toggle views cleanly so panels NEVER overlap
	var is_home: bool = (tab_idx == 0)
	if _sub_viewport:
		_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_home else SubViewport.UPDATE_DISABLED
	if _showroom_ui_container:
		_showroom_ui_container.visible = is_home
	if _sub_viewport_container:
		_sub_viewport_container.visible = is_home
	if _home_dock_container:
		_home_dock_container.visible = is_home
	if _side_cards_container:
		_side_cards_container.visible = is_home
	if _top_bar:
		_top_bar.visible = is_home
	if _bottom_dock_container:
		_bottom_dock_container.visible = is_home
	
	if _cars_screen:
		_cars_screen.visible = (tab_idx == 1)
		if tab_idx == 1 and _cars_screen.has_method("select_car"):
			_cars_screen.select_car(current_view_car_id)
	elif _cars_drawer:
		_cars_drawer.visible = (tab_idx == 1)
		if tab_idx == 1:
			_populate_cars_grid()
	
	if _gear_screen:
		_gear_screen.visible = (tab_idx == 2)
	elif _inventory_drawer:
		_inventory_drawer.visible = (tab_idx == 2)
		if tab_idx == 2 and _inventory_panel and _inventory_panel.has_method("refresh_inventory"):
			_inventory_panel.refresh_inventory()
	
	if _gacha_screen:
		_gacha_screen.visible = (tab_idx == 3)
	elif _gacha_drawer:
		_gacha_drawer.visible = (tab_idx == 3)
		if _gacha_result_panel:
			_gacha_result_panel.visible = false
	
	if _friends_squad_drawer:
		_friends_squad_drawer.visible = (tab_idx == 4)
		if tab_idx == 4 and _friends_squad_panel and _friends_squad_panel.has_method("refresh_all"):
			_friends_squad_panel.refresh_all()
	
	if _ranks_drawer:
		_ranks_drawer.visible = false
	
	_refresh_notification_badges()

func _connect_managers() -> void:
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.cash_changed.connect(func(_amount: int): _refresh_top_bar())
		sm.car_equipped.connect(func(car_id: String): _load_showroom_car(car_id))
		if sm.has_signal("loadout_changed"):
			sm.loadout_changed.connect(func(_s, _i): _load_showroom_car(current_view_car_id))
	
	if has_node("/root/GameModeManager"):
		var gmm = get_node("/root/GameModeManager")
		gmm.mode_changed.connect(func(_new_mode): _refresh_mode_display())
	
	if has_node("/root/ProgressionManager"):
		var pm = get_node("/root/ProgressionManager")
		pm.login_reward_claimed.connect(func(_d, _r): _refresh_notification_badges(); _refresh_top_bar())
		pm.quest_progress_updated.connect(func(_i, _c, _t): _refresh_notification_badges())
		pm.quest_completed.connect(func(_q): _refresh_notification_badges())
		pm.quest_reward_claimed.connect(func(_i, _r): _refresh_notification_badges(); _refresh_top_bar())
		pm.heist_safe_claimed.connect(func(_c, _i): _refresh_notification_badges(); _refresh_top_bar())
	
	if has_node("/root/SocialFriendManager"):
		var sfm = get_node("/root/SocialFriendManager")
		if not sfm.squad_updated.is_connected(_refresh_showroom_squad):
			sfm.squad_updated.connect(_refresh_showroom_squad)

func open_menu() -> void:
	visible = true
	switch_tab(0)
