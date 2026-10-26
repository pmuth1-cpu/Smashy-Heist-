class_name GhostCar
extends Node3D

## Translucent Cyan Hologram Ghost Car for Daily Getaway replaying best local or top leaderboard runs.

@export var recorded_frames: Array[Dictionary] = []

@onready var ghost_mesh: MeshInstance3D = $GhostMesh
@onready var label_3d: Label3D = $Label3D

var _playback_time: float = 0.0
var _current_index: int = 0
var _is_active: bool = false

func _ready() -> void:
	if recorded_frames.size() > 1:
		_is_active = true
		_playback_time = 0.0
		_current_index = 0
		var f0 = recorded_frames[0]
		global_position = Vector3(float(f0["x"]), float(f0["y"]), float(f0["z"]))
		rotation.y = float(f0["ry"])
		visible = true
	else:
		_is_active = false
		visible = false

func _process(delta: float) -> void:
	if not _is_active or recorded_frames.is_empty():
		return
	
	# Only advance while run is active
	var run_active: bool = true
	if has_node("/root/WantedManager"):
		var wm = get_node("/root/WantedManager")
		run_active = wm.is_run_active
	
	if not run_active:
		return
	
	_playback_time += delta
	
	# Advance frame pointer
	while _current_index + 1 < recorded_frames.size() and float(recorded_frames[_current_index + 1]["t"]) <= _playback_time:
		_current_index += 1
	
	if _current_index + 1 < recorded_frames.size():
		var f0: Dictionary = recorded_frames[_current_index]
		var f1: Dictionary = recorded_frames[_current_index + 1]
		var t0: float = float(f0["t"])
		var t1: float = float(f1["t"])
		var span: float = maxf(0.0001, t1 - t0)
		var alpha: float = clampf((_playback_time - t0) / span, 0.0, 1.0)
		
		var p0 := Vector3(float(f0["x"]), float(f0["y"]), float(f0["z"]))
		var p1 := Vector3(float(f1["x"]), float(f1["y"]), float(f1["z"]))
		global_position = p0.lerp(p1, alpha)
		rotation.y = lerp_angle(float(f0["ry"]), float(f1["ry"]), alpha)
	elif _current_index < recorded_frames.size():
		var f: Dictionary = recorded_frames[_current_index]
		global_position = Vector3(float(f["x"]), float(f["y"]), float(f["z"]))
		rotation.y = float(f["ry"])
