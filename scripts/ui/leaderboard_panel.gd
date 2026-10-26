class_name LeaderboardPanel
extends Control

## Daily Seed Leaderboard UI Panel
## Displays online / offline rival rankings, player rank highlight, and streak indicators.

@onready var status_pill: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HeaderBox/StatusPill
@onready var streak_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HeaderBox/StreakLabel
@onready var close_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HeaderBox/CloseButton
@onready var refresh_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BottomBox/RefreshButton
@onready var rows_container: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/RowsContainer

func _ready() -> void:
	visible = false
	close_button.pressed.connect(close_panel)
	refresh_button.pressed.connect(_on_refresh_pressed)
	
	if has_node("/root/LeaderboardManager"):
		var lm = get_node("/root/LeaderboardManager")
		lm.leaderboard_updated.connect(_on_leaderboard_updated)

## Opens the leaderboard modal and fetches latest entries.
func open_panel() -> void:
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.95, 0.95)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	_update_streak_display()
	
	# Initial render from cache if available
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if not sm.cached_leaderboard.is_empty():
			_render_rows(sm.cached_leaderboard, false)
	
	if has_node("/root/LeaderboardManager"):
		var lm = get_node("/root/LeaderboardManager")
		lm.sync_pending_scores_and_fetch()

func close_panel() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): visible = false)

func _on_refresh_pressed() -> void:
	if has_node("/root/LeaderboardManager"):
		var lm = get_node("/root/LeaderboardManager")
		lm.sync_pending_scores_and_fetch()

func _update_streak_display() -> void:
	var streak: int = 0
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		streak = sm.daily_streak
	if streak_label:
		streak_label.text = "🔥 %d DAY STREAK" % streak

func _on_leaderboard_updated(entries: Array[Dictionary], is_online_fresh: bool) -> void:
	_update_streak_display()
	_render_rows(entries, is_online_fresh)

func _render_rows(entries: Array[Dictionary], is_online_fresh: bool) -> void:
	if status_pill:
		if is_online_fresh:
			status_pill.text = "● ONLINE LIVE"
			status_pill.modulate = Color(0.2, 0.95, 0.4)
		else:
			status_pill.text = "● OFFLINE CACHED — WILL SYNC"
			status_pill.modulate = Color(1.0, 0.78, 0.15)
	
	# Clear previous rows
	for child in rows_container.get_children():
		child.queue_free()
	
	# Render header row
	var header := _create_row_panel("#", "DRIVER", "CAR", "STREAK", "SCORE", Color(0.5, 0.55, 0.65), false)
	rows_container.add_child(header)
	
	for entry in entries:
		var rank_str: String = "#%d" % int(entry.get("rank", 0))
		var name_str: String = String(entry.get("player_name", "Unknown"))
		var car_id: String = String(entry.get("car_id", "default_coupe"))
		var car_str: String = _format_car_name(car_id)
		var streak_str: String = "🔥 %d" % int(entry.get("streak", 0))
		var score_str: String = "%d" % int(entry.get("score", 0))
		var is_player: bool = bool(entry.get("is_player", false))
		
		var text_color: Color = Color(1.0, 0.85, 0.2) if is_player else Color(0.9, 0.92, 0.95)
		var row := _create_row_panel(rank_str, name_str, car_str, streak_str, score_str, text_color, is_player)
		rows_container.add_child(row)

func _create_row_panel(rank: String, driver: String, car: String, streak: String, score: String, text_col: Color, is_player: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	if is_player:
		style.bg_color = Color(0.22, 0.18, 0.08, 0.9)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.95, 0.78, 0.15, 0.9)
	else:
		style.bg_color = Color(0.12, 0.14, 0.18, 0.65)
	
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	panel.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)
	
	# Rank
	var lbl_rank := Label.new()
	lbl_rank.custom_minimum_size = Vector2(48, 0)
	lbl_rank.text = rank
	lbl_rank.modulate = text_col
	hbox.add_child(lbl_rank)
	
	# Driver Name
	var lbl_name := Label.new()
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.text = driver
	lbl_name.modulate = text_col
	hbox.add_child(lbl_name)
	
	# Car
	var lbl_car := Label.new()
	lbl_car.custom_minimum_size = Vector2(130, 0)
	lbl_car.text = car
	lbl_car.modulate = text_col
	hbox.add_child(lbl_car)
	
	# Streak
	var lbl_streak := Label.new()
	lbl_streak.custom_minimum_size = Vector2(70, 0)
	lbl_streak.text = streak
	lbl_streak.modulate = text_col
	hbox.add_child(lbl_streak)
	
	# Score
	var lbl_score := Label.new()
	lbl_score.custom_minimum_size = Vector2(90, 0)
	lbl_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_score.text = score
	lbl_score.modulate = text_col
	hbox.add_child(lbl_score)
	
	return panel

func _format_car_name(car_id: String) -> String:
	match car_id:
		"tuk_tuk_jet": return "Jet Tuk-Tuk"
		"armored_bulldozer": return "Dozer Tank"
		"ice_cream_drifter": return "Frosty Van"
		"cyber_interceptor": return "Neon Blade"
		_: return "Getaway Coupe"
