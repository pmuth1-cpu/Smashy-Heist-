class_name PowerupCrate
extends Node3D

## Street Power-Up Crate for Smashy Heist: Daily Getaway.
## Floating, rotating 3D blocky gold crate granting 1 of 4 arcade power-ups:
## 0: NITRO_OVERDRIVE (+40% speed, blue flames, arrest immunity)
## 1: EMP_SHOCKWAVE (18m sphere ring launching & disabling all nearby cops)
## 2: OIL_SLICK_DROPPER (Drops 5 oil patches making cops spin out wildly)
## 3: TITAN_REPAIR_SHIELD (+60 HP & golden forcefield deflecting cops on impact)

enum PowerupType {
	NITRO_OVERDRIVE = 0,
	EMP_SHOCKWAVE = 1,
	OIL_SLICK_DROPPER = 2,
	TITAN_REPAIR_SHIELD = 3
}

signal powerup_collected(powerup_type: int)

@export var forced_powerup: int = -1 # -1 for random

@onready var area: Area3D = $Area3D
@onready var crate_mesh: MeshInstance3D = $CrateMesh

var _bob_timer: float = 0.0
var _base_y: float = 0.8
var _is_collected: bool = false

func _ready() -> void:
	_bob_timer = randf() * TAU
	_base_y = position.y if position.y > 0.1 else 0.8
	
	if area and not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)
	
	var actual_type: int = forced_powerup if forced_powerup >= 0 else randi() % 4
	forced_powerup = actual_type
	
	var vab = get_node_or_null("/root/VoxelAssetBuilder")
	if vab and vab.has_method("build_powerup_3d_model"):
		if crate_mesh:
			crate_mesh.visible = false
		var trim = get_node_or_null("TrimMesh")
		if trim:
			trim.visible = false
		var model: Node3D = vab.build_powerup_3d_model(actual_type)
		model.name = "VoxelModel"
		add_child(model)

func _process(delta: float) -> void:
	if _is_collected:
		return
	_bob_timer += delta * 3.5
	position.y = _base_y + sin(_bob_timer) * 0.15
	rotation.y += delta * 2.2

func _on_body_entered(body: Node3D) -> void:
	if _is_collected:
		return
	
	var car: Node3D = null
	if body is RigidBody3D and body.get_parent() and body.get_parent().has_method("apply_powerup"):
		car = body.get_parent()
	elif body.has_method("apply_powerup"):
		car = body
	elif body.is_in_group("player"):
		car = body
	
	if car != null:
		_is_collected = true
		var p_type: int = forced_powerup if forced_powerup >= 0 else randi() % 4
		powerup_collected.emit(p_type)
		
		# Apply powerup to car
		if car.has_method("apply_powerup"):
			car.apply_powerup(p_type, 6.0)
		
		# Notify TouchHUD
		var hud = get_tree().root.find_child("TouchHUD", true, false)
		if hud and hud.has_method("show_powerup_banner"):
			var p_names: Array[String] = ["⚡ NITRO OVERDRIVE!", "💥 EMP SHOCKWAVE!", "🛢️ OIL SLICK DROPPER!", "🛡️ TITAN SHIELD!"]
			var p_colors: Array[Color] = [Color("00d2d3"), Color("3498db"), Color("e67e22"), Color("f1c40f")]
			hud.show_powerup_banner(p_names[p_type], p_colors[p_type], 6.0)
		
		# Disappear with brief scale-down tween
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(queue_free)
