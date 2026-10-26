class_name PauseMenuModal
extends Control

## Brawl Stars Pause Menu Modal for Smashy Heist: Daily Getaway.
## Freezes gameplay, displays live run stats, audio volume controls,
## camera angle presets, and quick navigation actions (Resume, Restart, Quit to Lobby).

signal resumed()
signal restarted()
signal quit_to_lobby()

@onready var vignette_rect: ColorRect = $VignetteRect
@onready var modal_card: PanelContainer = $CenterContainer/ModalCard
@onready var header_banner: TextureRect = $CenterContainer/ModalCard/VBox/HeaderBanner
@onready var score_val_label: Label = $CenterContainer/ModalCard/VBox/StatsGrid/ScoreVal
@onready var time_val_label: Label = $CenterContainer/ModalCard/VBox/StatsGrid/TimeVal
@onready var cops_val_label: Label = $CenterContainer/ModalCard/VBox/StatsGrid/CopsVal
@onready var quest_val_label: Label = $CenterContainer/ModalCard/VBox/StatsGrid/QuestVal

@onready var sfx_slider: HSlider = $CenterContainer/ModalCard/VBox/SettingsBox/SfxHBox/SfxSlider
@onready var sfx_percent_label: Label = $CenterContainer/ModalCard/VBox/SettingsBox/SfxHBox/SfxPercent
@onready var cam_toggle_btn: Button = $CenterContainer/ModalCard/VBox/SettingsBox/CamToggleBtn

@onready var resume_btn: Button = $CenterContainer/ModalCard/VBox/ButtonsHBox/ResumeBtn
@onready var restart_btn: Button = $CenterContainer/ModalCard/VBox/ButtonsHBox/RestartBtn
@onready var quit_btn: Button = $CenterContainer/ModalCard/VBox/ButtonsHBox/QuitBtn

const BrawlUITheme = preload("res://scripts/autoload/brawl_ui_theme.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	_apply_styling()
	
	if resume_btn and not resume_btn.pressed.is_connected(resume_game):
		resume_btn.pressed.connect(resume_game)
	if restart_btn and not restart_btn.pressed.is_connected(restart_run):
		restart_btn.pressed.connect(restart_run)
	if quit_btn and not quit_btn.pressed.is_connected(quit_to_main_menu):
		quit_btn.pressed.connect(quit_to_main_menu)
	
	if sfx_slider:
		sfx_slider.value = 85.0
		if not sfx_slider.value_changed.is_connected(_on_sfx_slider_changed):
			sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	
	if cam_toggle_btn and not cam_toggle_btn.pressed.is_connected(_on_cam_toggle_pressed):
		cam_toggle_btn.pressed.connect(_on_cam_toggle_pressed)

func _apply_styling() -> void:
	# 1. Stylize Modal Card as Cute Cartoon Board
	if modal_card:
		modal_card.custom_minimum_size = Vector2(680, 580)
		modal_card.add_theme_stylebox_override("panel", BrawlUITheme.make_cartoon_board_style(Color("0e1828f4"), Color("f1c40f"), 28, 6))
	
	# 2. Load Arched 3D Cartoon Ribbon Header
	if header_banner:
		header_banner.custom_minimum_size = Vector2(460, 115)
		header_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		header_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var ribbon_path := "res://assets/ribbons/ribbon_header_paused.png"
		header_banner.texture = BrawlUITheme.load_texture_safe(ribbon_path)
	
	# 3. Stylize 3D Candy Action Buttons
	if resume_btn:
		resume_btn.text = "RESUME"
		resume_btn.custom_minimum_size = Vector2(195, 66)
		resume_btn.add_theme_font_size_override("font_size", 22)
		BrawlUITheme.attach_candy_button_juice(resume_btn, "green")
	
	if restart_btn:
		restart_btn.text = "RESTART"
		restart_btn.custom_minimum_size = Vector2(185, 66)
		restart_btn.add_theme_font_size_override("font_size", 22)
		BrawlUITheme.attach_candy_button_juice(restart_btn, "yellow")
	
	if quit_btn:
		quit_btn.text = "QUIT"
		quit_btn.custom_minimum_size = Vector2(175, 66)
		quit_btn.add_theme_font_size_override("font_size", 22)
		BrawlUITheme.attach_candy_button_juice(quit_btn, "red")
	
	if cam_toggle_btn:
		cam_toggle_btn.custom_minimum_size = Vector2(360, 52)
		BrawlUITheme.attach_candy_button_juice(cam_toggle_btn, "blue")
	
	# 4. Polish Typography & Stat Pills
	var stat_title_ls := BrawlUITheme.make_label_settings(18, Color("00d2d3"), 4)
	var stat_val_ls := BrawlUITheme.make_label_settings(24, Color.WHITE, 6)
	
	var score_title: Label = find_child("ScoreLabel", true, false)
	if score_title:
		score_title.label_settings = stat_title_ls
		score_title.text = "RUN SCORE:"
	if score_val_label:
		score_val_label.label_settings = stat_val_ls
	
	var time_title: Label = find_child("TimeLabel", true, false)
	if time_title:
		time_title.label_settings = stat_title_ls
		time_title.text = "SURVIVAL TIME:"
	if time_val_label:
		time_val_label.label_settings = stat_val_ls
	
	var cops_title: Label = find_child("CopsLabel", true, false)
	if cops_title:
		cops_title.label_settings = stat_title_ls
		cops_title.text = "COPS WRECKED:"
	if cops_val_label:
		cops_val_label.label_settings = stat_val_ls
	
	var quest_title: Label = find_child("QuestLabel", true, false)
	if quest_title:
		quest_title.label_settings = stat_title_ls
		quest_title.text = "DAILY QUESTS:"
	if quest_val_label:
		quest_val_label.label_settings = stat_val_ls

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if visible:
			resume_game()
			get_viewport().set_input_as_handled()
		else:
			var parent_hud = get_parent()
			if parent_hud and "target_car" in parent_hud and is_instance_valid(parent_hud.target_car):
				open_pause_menu()
				get_viewport().set_input_as_handled()

## Opens the pause menu and halts gameplay
func open_pause_menu() -> void:
	if visible:
		return
	
	visible = true
	get_tree().paused = true
	
	# Update live stats
	_populate_run_stats()
	
	# Update camera button label
	_update_cam_button_text()
	
	# Sound
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_ui_click()
	
	# Bounce card animation
	if modal_card:
		modal_card.scale = Vector2(0.6, 0.6)
		var tw := create_tween()
		tw.set_ignore_time_scale(true)
		tw.tween_property(modal_card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Resumes getaway run and unfreezes engine
func resume_game() -> void:
	if not visible:
		return
	
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_ui_click()
	
	get_tree().paused = false
	visible = false
	resumed.emit()

## Restarts getaway run from scratch
func restart_run() -> void:
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_ui_click()
	
	get_tree().paused = false
	visible = false
	restarted.emit()
	
	if has_node("/root/SceneTransitionManager"):
		get_node("/root/SceneTransitionManager").transition_to_scene("res://scenes/world/main_game.tscn")
	else:
		get_tree().reload_current_scene()

## Quits to 16:9 main menu lobby
func quit_to_main_menu() -> void:
	if has_node("/root/SoundFX"):
		get_node("/root/SoundFX").play_ui_click()
	
	get_tree().paused = false
	visible = false
	quit_to_lobby.emit()
	
	if has_node("/root/SceneTransitionManager"):
		get_node("/root/SceneTransitionManager").transition_to_scene("res://scenes/ui/brawl_main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/brawl_main_menu.tscn")

func _populate_run_stats() -> void:
	var score: int = 0
	var surv_time: float = 0.0
	var cops_wr: int = 0
	
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		score = wm.current_score
		surv_time = wm.survival_time
		cops_wr = wm.cops_wrecked
	
	if score_val_label:
		score_val_label.text = "%d PTS" % score
	if time_val_label:
		var mins := int(surv_time) / 60
		var secs := int(surv_time) % 60
		time_val_label.text = "%02d:%02d" % [mins, secs]
	if cops_val_label:
		cops_val_label.text = "%d WRECKED" % cops_wr
	if quest_val_label:
		if has_node("/root/ProgressionManager"):
			var pm = get_node("/root/ProgressionManager")
			var q_progress: String = str(pm.get_overall_quest_progress()) if pm.has_method("get_overall_quest_progress") else "ACTIVE"
			quest_val_label.text = q_progress
		else:
			quest_val_label.text = "IN PROGRESS"

func _on_sfx_slider_changed(value: float) -> void:
	if sfx_percent_label:
		sfx_percent_label.text = "%d%%" % int(value)
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		if value <= 0.0:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			var vol_db: float = linear_to_db(value / 100.0)
			AudioServer.set_bus_volume_db(bus_idx, vol_db)

func _on_cam_toggle_pressed() -> void:
	var cam_rig = get_tree().root.find_child("CameraRig", true, false)
	if cam_rig and cam_rig.has_method("toggle_camera_distance"):
		var new_name: String = cam_rig.toggle_camera_distance()
		if cam_toggle_btn:
			cam_toggle_btn.text = "🎥 CAMERA: %s" % new_name
	elif cam_toggle_btn:
		cam_toggle_btn.text = "🎥 CAMERA: TOGGLED"

func _update_cam_button_text() -> void:
	var cam_rig = get_tree().root.find_child("CameraRig", true, false)
	if cam_rig and cam_rig.has_method("get_camera_preset_name") and cam_toggle_btn:
		cam_toggle_btn.text = "🎥 CAMERA: %s" % cam_rig.get_camera_preset_name()
