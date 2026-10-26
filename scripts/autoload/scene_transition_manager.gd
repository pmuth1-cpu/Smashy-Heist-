class_name SceneTransitionManagerClass
extends Node

## Singleton Manager for Smooth Brawl Stars-Style Scene Transitions.
## Handles asynchronous threaded loading via ResourceLoader.load_threaded_request(),
## animates the comic LoadingScreen splash art for >= 1.1 seconds,
## and changes scenes via get_tree().change_scene_to_packed() so old scenes
## (such as the 3D menu showroom) are completely unloaded before the new scene mounts.

signal transition_started(target_path: String)
signal transition_finished(target_path: String)

const MIN_TRANSITION_SECONDS: float = 1.1

const LoadingScreenScript = preload("res://scripts/ui/loading_screen.gd")
var loading_screen: CanvasLayer = null
var _loading_screen_scene: PackedScene = preload("res://scenes/ui/loading_screen.tscn")

var _is_transitioning: bool = false
var _target_scene_path: String = ""
var _elapsed_transition_time: float = 0.0
var _load_progress: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _loading_screen_scene:
		loading_screen = _loading_screen_scene.instantiate() as CanvasLayer
		add_child(loading_screen)

func _process(delta: float) -> void:
	if not _is_transitioning:
		return
	
	_elapsed_transition_time += delta
	
	# Poll ResourceLoader status
	_load_progress.clear()
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_target_scene_path, _load_progress)
	
	var engine_progress: float = 0.0
	if _load_progress.size() > 0:
		engine_progress = float(_load_progress[0])
	
	# Minimum display progress scaled to 1.1s
	var time_progress: float = clampf(_elapsed_transition_time / MIN_TRANSITION_SECONDS, 0.0, 1.0)
	var final_progress: float = minf(engine_progress, time_progress) if engine_progress < 1.0 else time_progress
	
	if loading_screen:
		loading_screen.set_loading_progress(final_progress)
	
	# Check if loaded and min display time satisfied
	if status == ResourceLoader.THREAD_LOAD_LOADED and _elapsed_transition_time >= MIN_TRANSITION_SECONDS:
		_complete_transition()
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		printerr("SceneTransitionManager: Failed to load target scene: ", _target_scene_path)
		_is_transitioning = false
		if loading_screen:
			loading_screen.hide_screen()

## Starts an asynchronous scene transition with full Brawl Stars loading splash screen
func transition_to_scene(target_path: String) -> void:
	if _is_transitioning:
		return
	
	_is_transitioning = true
	_target_scene_path = target_path
	_elapsed_transition_time = 0.0
	
	var equipped_car: String = "default_coupe"
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if sm and "equipped_car_id" in sm:
			equipped_car = sm.equipped_car_id
	
	if loading_screen:
		loading_screen.setup_equipped_car(equipped_car)
		loading_screen.show_screen()
	
	var err: Error = ResourceLoader.load_threaded_request(target_path)
	if err != OK:
		printerr("SceneTransitionManager: load_threaded_request error: ", err)
		# Fallback to direct pack load if threaded request errored
		var scene: PackedScene = load(target_path) as PackedScene
		if scene:
			get_tree().change_scene_to_packed(scene)
		_is_transitioning = false
		if loading_screen:
			loading_screen.hide_screen()
		return
	
	transition_started.emit(target_path)

func _complete_transition() -> void:
	_is_transitioning = false
	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(_target_scene_path) as PackedScene
	
	if packed_scene:
		# completely frees the old top-level scene (e.g. brawl_main_menu.tscn)
		get_tree().change_scene_to_packed(packed_scene)
	
	# Give 1 frame for new scene _ready() before hiding splash screen
	get_tree().create_timer(0.08, true, false, true).timeout.connect(func():
		if loading_screen:
			loading_screen.hide_screen()
		transition_finished.emit(_target_scene_path)
	)
