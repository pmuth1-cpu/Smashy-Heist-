class_name RunSummaryPanel
extends Control

## Daily Scorecard & Game Over Panel for Smashy Heist: Daily Getaway.
## Displays post-run stats, slow-motion camera zoom, clipboard sharing, and replay handling.

signal leaderboard_requested()
signal garage_requested()

@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var stars_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StarsLabel
@onready var score_value_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatsGrid/ScoreValue
@onready var time_value_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatsGrid/TimeValue
@onready var cops_value_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatsGrid/CopsValue
@onready var share_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonBox/ShareButton
@onready var play_again_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonBox/PlayAgainButton
@onready var leaderboard_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonBox/LeaderboardButton
@onready var garage_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonBox/GarageButton

const BrawlUITheme = preload("res://scripts/autoload/brawl_ui_theme.gd")

var _share_payload: String = ""

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Stylize panel card
	var panel_container: PanelContainer = find_child("PanelContainer", true, false)
	if panel_container:
		panel_container.custom_minimum_size = Vector2(760, 480)
		panel_container.add_theme_stylebox_override("panel", BrawlUITheme.make_cartoon_board_style(Color("0c1626f4"), Color("f1c40f"), 28, 6))
	
	# Stylize action buttons with 3D candy buttons
	if play_again_button:
		play_again_button.text = "PLAY AGAIN"
		play_again_button.custom_minimum_size = Vector2(210, 68)
		play_again_button.add_theme_font_size_override("font_size", 22)
		BrawlUITheme.attach_candy_button_juice(play_again_button, "green")
		play_again_button.pressed.connect(_on_play_again_pressed)
	
	if garage_button:
		garage_button.text = "LOBBY"
		garage_button.custom_minimum_size = Vector2(170, 68)
		garage_button.add_theme_font_size_override("font_size", 22)
		BrawlUITheme.attach_candy_button_juice(garage_button, "blue")
		garage_button.pressed.connect(_on_garage_pressed)
	
	if leaderboard_button:
		leaderboard_button.text = "RANKS"
		leaderboard_button.custom_minimum_size = Vector2(160, 68)
		leaderboard_button.add_theme_font_size_override("font_size", 22)
		BrawlUITheme.attach_candy_button_juice(leaderboard_button, "yellow")
		leaderboard_button.pressed.connect(func(): leaderboard_requested.emit())
	
	if share_button:
		share_button.text = "SHARE"
		share_button.custom_minimum_size = Vector2(160, 68)
		share_button.add_theme_font_size_override("font_size", 22)
		BrawlUITheme.attach_candy_button_juice(share_button, "purple")
		share_button.pressed.connect(_on_share_pressed)
	
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		wm.player_busted.connect(_on_player_busted)

func _on_player_busted(reason: String, final_score: int, survival_seconds: float, cops_wrecked: int) -> void:
	populate_stats(reason, final_score, survival_seconds, cops_wrecked)
	
	# If BustedCutsceneOverlay is present, it coordinates the 3D arrest cutscene and slide-up
	var cutscene = get_tree().root.find_child("BustedCutsceneOverlay", true, false)
	if cutscene:
		return
	
	# Fallback if cutscene overlay is not in the tree
	Engine.time_scale = 0.25
	_zoom_camera(16.0)
	var timer := get_tree().create_timer(1.2, true, false, true)
	timer.timeout.connect(func():
		Engine.time_scale = 1.0
		_show_panel()
	)

## Populates UI scorecard stats from run results
func populate_stats(reason: String, final_score: int, survival_seconds: float, cops_wrecked: int) -> void:
	# Compute star rating
	var star_count: int = 1
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		star_count = clampi(wm.wanted_stars, 1, 5)
	
	var star_string: String = "⭐".repeat(star_count) + "☆".repeat(5 - star_count)
	
	# Retrieve Daily ID
	var daily_id: String = "DAILY"
	if has_node("/root/DailySeedManager"):
		var mgr = get_node("/root/DailySeedManager")
		daily_id = mgr.utc_date_string if mgr.utc_date_string != "" else str(absi(mgr.base_seed) % 10000)
	
	# Prepare clipboard string
	_share_payload = "🚓 Smashy Heist Daily #%s\n⭐ Heat: %s | ⏱️ %.1fs\n💥 Cops Wrecked: %d | 🏆 Score: %d" % [
		daily_id,
		star_string,
		survival_seconds,
		cops_wrecked,
		final_score
	]
	
	# Update UI text
	title_label.text = reason.to_upper()
	if "BUSTED" in reason.to_upper():
		title_label.modulate = Color(1.0, 0.25, 0.25)
	else:
		title_label.modulate = Color(1.0, 0.55, 0.15)
	
	stars_label.text = star_string
	score_value_label.text = "%d" % final_score
	time_value_label.text = "%.1fs" % survival_seconds
	cops_value_label.text = "%d" % cops_wrecked

## Slides RunSummaryPanel up cleanly at the bottom half of the screen
## while keeping the 3D orbiting camera running in the background.
func slide_up_at_bottom(reason: String = "", final_score: int = -1, survival_seconds: float = -1.0, cops_wrecked: int = -1) -> void:
	if final_score >= 0:
		populate_stats(reason, final_score, survival_seconds, cops_wrecked)
	
	visible = true
	modulate.a = 1.0
	scale = Vector2(1.0, 1.0)
	
	var center_c = get_node_or_null("CenterContainer")
	if center_c:
		center_c.anchors_preset = Control.PRESET_BOTTOM_WIDE
		center_c.anchor_top = 0.40
		center_c.anchor_bottom = 1.0
		center_c.offset_top = 0.0
		center_c.offset_bottom = -20.0
	
	var vp_size := get_viewport_rect().size
	position.y = vp_size.y
	
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(self, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func show_podium_standings(standings: Array[Dictionary]) -> void:
	title_label.text = "🏆 HOT LOOT PODIUM 🏆"
	title_label.modulate = Color(1.0, 0.85, 0.15)
	
	var p1: String = standings[0]["name"] if standings.size() > 0 else "None"
	var s1: int = int(standings[0]["score"]) if standings.size() > 0 else 0
	var p2: String = standings[1]["name"] if standings.size() > 1 else "-"
	var s2: int = int(standings[1]["score"]) if standings.size() > 1 else 0
	var p3: String = standings[2]["name"] if standings.size() > 2 else "-"
	var s3: int = int(standings[2]["score"]) if standings.size() > 2 else 0
	var p4: String = standings[3]["name"] if standings.size() > 3 else "-"
	var s4: int = int(standings[3]["score"]) if standings.size() > 3 else 0
	
	stars_label.text = "🥇 1st: %s (%d pts)" % [p1, s1]
	
	var score_title: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatsGrid/ScoreTitle
	var time_title: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatsGrid/TimeTitle
	var cops_title: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatsGrid/CopsTitle
	
	if score_title:
		score_title.text = "🥈 2ND PLACE:"
	score_value_label.text = "%s (%d pts)" % [p2, s2]
	
	if time_title:
		time_title.text = "🥉 3RD PLACE:"
	time_value_label.text = "%s (%d pts)" % [p3, s3]
	
	if cops_title:
		cops_title.text = "🚗 4TH PLACE:"
	cops_value_label.text = "%s (%d pts)" % [p4, s4]
	
	_share_payload = "🔥 Smashy Heist Hot Loot Tag Results:\n🥇 1st: %s - %d pts\n🥈 2nd: %s - %d pts\n🥉 3rd: %s - %d pts\n4th: %s - %d pts" % [
		p1, s1, p2, s2, p3, s3, p4, s4
	]
	
	_show_panel()


func _zoom_camera(_target_dist: float) -> void:
	var cam_rig = get_tree().root.find_child("CameraRig", true, false)
	if cam_rig:
		var cam: Camera3D = cam_rig.find_child("Camera3D", true, false) as Camera3D
		if cam:
			var orig_pos: Vector3 = cam.position
			var zoomed_pos: Vector3 = orig_pos.normalized() * 16.0
			var tween := cam_rig.create_tween()
			tween.set_ignore_time_scale(true)
			tween.tween_property(cam, "position", zoomed_pos, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _show_panel() -> void:
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.9, 0.9)
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_share_pressed() -> void:
	DisplayServer.clipboard_set(_share_payload)
	share_button.text = "COPIED TO CLIPBOARD! ✓"
	var timer := get_tree().create_timer(1.8, true, false, true)
	timer.timeout.connect(func():
		if is_instance_valid(share_button):
			share_button.text = "📋 Share Daily Scorecard"
	)

func _on_play_again_pressed() -> void:
	Engine.time_scale = 1.0
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		wm.start_new_run()
	get_tree().reload_current_scene()

func _on_garage_pressed() -> void:
	Engine.time_scale = 1.0
	garage_requested.emit()
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.set_meta("return_to_tab", 1) # Direct route to CARS / Garage tab
	if has_node("/root/SceneTransitionManager"):
		get_node("/root/SceneTransitionManager").transition_to_scene("res://scenes/ui/brawl_main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/brawl_main_menu.tscn")
