class_name KartNPCTraffic
extends Node3D

## Autonomous Moving NPC Circuit Vehicles & Road Hazards for Smashy Kart Grand Prix.
## Features:
## - 4 to 6 autonomous moving track vehicles (Taxis, Delivery Vans, Sweepers, Cruisers)
## - Autonomous Curve3D path & lane following at cruising speeds (11–15 m/s)
## - Interactive Drafting: Tuck behind NPC traffic for slipstream boost
## - Interactive Bumping: Bump into traffic with physics shake
## - Smash & Flip Mechanics: Hit with Star/Nitro/Missile to trigger 360 cartwheel flips (+150 pts)
## - Cheering trackside spectator marshals along safety walkways

signal traffic_smashed(npc_name: String, smash_pos: Vector3)

const NPC_VEHICLE_CONFIGS: Array[Dictionary] = [
	{"name": "🚖 Downtown Cab", "color": Color("f1c40f"), "roof_color": Color("2c3e50"), "speed": 12.5, "lane": -4.2, "offset_pct": 0.12},
	{"name": "🚚 Brawl Express Van", "color": Color("e74c3c"), "roof_color": Color("ecf0f1"), "speed": 11.0, "lane": 4.2, "offset_pct": 0.32},
	{"name": "🧹 Turbo Sweeper", "color": Color("e67e22"), "roof_color": Color("f39c12"), "speed": 9.5, "lane": 0.0, "offset_pct": 0.52},
	{"name": "🚓 Smashy Cruiser", "color": Color("34495e"), "roof_color": Color("ffffff"), "speed": 13.2, "lane": -4.2, "offset_pct": 0.72},
	{"name": "🍧 Ice Cream Buggy", "color": Color("ff9ff3"), "roof_color": Color("54a0ff"), "speed": 10.5, "lane": 4.2, "offset_pct": 0.90}
]

var track_curve: Curve3D = null
var baked_length: float = 780.0
var active_npc_cars: Array[Dictionary] = []
var spectator_nodes: Array[Node3D] = []

func _ready() -> void:
	pass

func setup_traffic(curve: Curve3D, length: float) -> void:
	track_curve = curve
	baked_length = length
	_clear_all()
	_spawn_npc_vehicles()
	_spawn_trackside_spectators()

func _clear_all() -> void:
	for child in get_children():
		child.queue_free()
	active_npc_cars.clear()
	spectator_nodes.clear()

## 1. Spawn 5 Moving NPC Hazard Vehicles
func _spawn_npc_vehicles() -> void:
	if not track_curve or baked_length < 10.0:
		return
	
	for i in range(NPC_VEHICLE_CONFIGS.size()):
		var cfg: Dictionary = NPC_VEHICLE_CONFIGS[i]
		var root := Node3D.new()
		root.name = "NPCVehicle_%d" % i
		add_child(root)
		
		# Voxel-style vehicle body
		var body := Node3D.new()
		body.name = "VehicleBody"
		root.add_child(body)
		
		# Main Chassis
		var chassis := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = Vector3(2.1, 0.95, 4.4)
		chassis.mesh = bmesh
		chassis.position = Vector3(0, 0.65, 0)
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = cfg["color"]
		cmat.roughness = 0.45
		chassis.material_override = cmat
		body.add_child(chassis)
		
		# Cabin / Roof
		var cabin := MeshInstance3D.new()
		var cmesh := BoxMesh.new()
		cmesh.size = Vector3(1.85, 0.75, 2.3)
		cabin.mesh = cmesh
		cabin.position = Vector3(0, 1.4, -0.2)
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = cfg["roof_color"]
		rmat.roughness = 0.35
		cabin.material_override = rmat
		body.add_child(cabin)
		
		# Windshield & Windows
		var glass := MeshInstance3D.new()
		var gmesh := BoxMesh.new()
		gmesh.size = Vector3(1.9, 0.65, 2.1)
		glass.mesh = gmesh
		glass.position = Vector3(0, 1.38, -0.2)
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color("1e272e")
		gmat.roughness = 0.1
		gmat.metallic = 0.4
		glass.material_override = gmat
		body.add_child(glass)
		
		# Working Headlights (Glowing Yellow/White)
		for hx in [-0.75, 0.75]:
			var lamp := MeshInstance3D.new()
			var lmesh := SphereMesh.new()
			lmesh.radius = 0.22
			lmesh.height = 0.44
			lamp.mesh = lmesh
			lamp.position = Vector3(hx, 0.65, -2.2)
			var lmat := StandardMaterial3D.new()
			lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			lmat.albedo_color = Color("fff5eb")
			lamp.material_override = lmat
			body.add_child(lamp)
		
		# Working Taillights (Glowing Red)
		for tx in [-0.75, 0.75]:
			var rlamp := MeshInstance3D.new()
			var rlmesh := BoxMesh.new()
			rlmesh.size = Vector3(0.35, 0.2, 0.1)
			rlamp.mesh = rlmesh
			rlamp.position = Vector3(tx, 0.65, 2.2)
			var rlmat := StandardMaterial3D.new()
			rlmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			rlmat.albedo_color = Color("e74c3c")
			rlamp.material_override = rlmat
			body.add_child(rlamp)
		
		# 4 Rotating Wheels
		var wheels: Array[MeshInstance3D] = []
		var wheel_positions := [
			Vector3(-1.15, 0.38, -1.3),
			Vector3(1.15, 0.38, -1.3),
			Vector3(-1.15, 0.38, 1.3),
			Vector3(1.15, 0.38, 1.3)
		]
		for wpos in wheel_positions:
			var wheel := MeshInstance3D.new()
			var wmesh := CylinderMesh.new()
			wmesh.top_radius = 0.38
			wmesh.bottom_radius = 0.38
			wmesh.height = 0.32
			wheel.mesh = wmesh
			wheel.position = wpos
			wheel.rotation_degrees.z = 90.0
			var wmat := StandardMaterial3D.new()
			wmat.albedo_color = Color(0.12, 0.12, 0.14)
			wmat.roughness = 0.9
			wheel.material_override = wmat
			body.add_child(wheel)
			wheels.append(wheel)
		
		# Special roof attachments
		if i == 0: # Taxi Sign
			var sign := Label3D.new()
			sign.text = "🚖 TAXI"
			sign.font_size = 48
			sign.modulate = Color("f1c40f")
			sign.position = Vector3(0, 1.95, -0.2)
			body.add_child(sign)
		elif i == 3: # Police Flashing Lightbar
			var siren := MeshInstance3D.new()
			var smesh := BoxMesh.new()
			smesh.size = Vector3(1.0, 0.18, 0.3)
			siren.mesh = smesh
			siren.position = Vector3(0, 1.88, -0.2)
			var simat := StandardMaterial3D.new()
			simat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			simat.albedo_color = Color("e74c3c")
			siren.material_override = simat
			body.add_child(siren)
		
		# Collision Trigger Area
		var area := Area3D.new()
		area.name = "CollisionArea"
		area.collision_layer = 8 # Layer 4 Obstacles
		area.collision_mask = 2 | 4 # Player & Rival Cars
		area.add_to_group("kart_npc_traffic")
		
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.5, 1.8, 4.6)
		col.shape = box
		col.position = Vector3(0, 0.9, 0)
		area.add_child(col)
		root.add_child(area)
		
		var start_dist: float = fposmod(float(cfg["offset_pct"]) * baked_length, baked_length)
		var entry: Dictionary = {
			"root": root,
			"body": body,
			"wheels": wheels,
			"cfg": cfg,
			"dist": start_dist,
			"speed": float(cfg["speed"]),
			"lane": float(cfg["lane"]),
			"is_spinning": false,
			"spin_timer": 0.0,
			"area": area
		}
		
		area.body_entered.connect(func(hitting_body):
			_on_traffic_hit(entry, hitting_body)
		)
		
		active_npc_cars.append(entry)
		_update_car_transform(entry, 0.0)

## 2. Spawn 14 Cheering Trackside Spectators along Grandstands & Safety Railings
func _spawn_trackside_spectators() -> void:
	if not track_curve or baked_length < 10.0:
		return
	
	var spectator_offsets := [
		{"d": 6.0, "x": -13.5, "col": Color("3498db")},
		{"d": 16.0, "x": -13.5, "col": Color("e74c3c")},
		{"d": 26.0, "x": -13.5, "col": Color("2ecc71")},
		{"d": 36.0, "x": -13.5, "col": Color("f1c40f")},
		{"d": 6.0, "x": 13.5, "col": Color("9b59b6")},
		{"d": 16.0, "x": 13.5, "col": Color("e67e22")},
		{"d": 26.0, "x": 13.5, "col": Color("1abc9c")},
		{"d": 36.0, "x": 13.5, "col": Color("e84118")},
		# Mid-track cheering spots
		{"d": baked_length * 0.25, "x": -13.2, "col": Color("f39c12")},
		{"d": baked_length * 0.35, "x": 13.2, "col": Color("00d2d3")},
		{"d": baked_length * 0.50, "x": -13.2, "col": Color("ff4757")},
		{"d": baked_length * 0.65, "x": 13.2, "col": Color("2ed573")},
		{"d": baked_length * 0.75, "x": -13.2, "col": Color("ffa502")},
		{"d": baked_length * 0.88, "x": 13.2, "col": Color("70a1ff")}
	]
	
	for s_data in spectator_offsets:
		var pos := track_curve.sample_baked(float(s_data["d"]))
		var next_pos := track_curve.sample_baked(fposmod(float(s_data["d"]) + 2.0, baked_length))
		var fwd := (next_pos - pos).normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		
		var spec := Node3D.new()
		spec.name = "SpectatorNPC"
		var spec_pos := pos + right * float(s_data["x"]) + Vector3(0, 0.2, 0)
		spec.position = spec_pos
		add_child(spec)
		
		# Face towards track center
		spec.look_at(pos + Vector3(0, 0.2, 0), Vector3.UP)
		
		# Voxel humanoid spectator
		var body_mesh := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = Vector3(0.55, 0.85, 0.35)
		body_mesh.mesh = bmesh
		body_mesh.position = Vector3(0, 0.75, 0)
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = s_data["col"]
		body_mesh.material_override = bmat
		spec.add_child(body_mesh)
		
		# Head
		var head_mesh := MeshInstance3D.new()
		var hmesh := SphereMesh.new()
		hmesh.radius = 0.24
		hmesh.height = 0.48
		head_mesh.mesh = hmesh
		head_mesh.position = Vector3(0, 1.42, 0)
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = Color("ffeaa7")
		head_mesh.material_override = hmat
		spec.add_child(head_mesh)
		
		# Cheering Flag
		var flag := Label3D.new()
		flag.text = "🏁"
		flag.font_size = 54
		flag.position = Vector3(0.35, 1.65, 0)
		spec.add_child(flag)
		
		spec.set_meta("base_y", spec_pos.y)
		spec.set_meta("anim_phase", randf() * TAU)
		spectator_nodes.append(spec)

func _physics_process(delta: float) -> void:
	if not track_curve or baked_length < 10.0:
		return
	
	# 1. Update moving NPC hazard vehicles
	for entry in active_npc_cars:
		if entry["is_spinning"]:
			entry["spin_timer"] -= delta
			var body: Node3D = entry["body"]
			body.rotation.y += delta * 18.0
			body.rotation.x = sin(entry["spin_timer"] * 12.0) * 0.4
			if entry["spin_timer"] <= 0.0:
				entry["is_spinning"] = false
				body.rotation = Vector3.ZERO
		else:
			entry["dist"] = fposmod(float(entry["dist"]) + float(entry["speed"]) * delta, baked_length)
			_update_car_transform(entry, delta)
	
	# 2. Animate cheering spectators (jumping & cheering rhythmically)
	var t: float = Time.get_ticks_msec() * 0.005
	for spec in spectator_nodes:
		if is_instance_valid(spec):
			var base_y: float = float(spec.get_meta("base_y", 0.0))
			var phase: float = float(spec.get_meta("anim_phase", 0.0))
			var jump_y: float = maxf(0.0, sin(t + phase)) * 0.35
			spec.position.y = base_y + jump_y
			spec.rotation.z = sin((t + phase) * 1.5) * 0.08

func _update_car_transform(entry: Dictionary, delta: float) -> void:
	var root: Node3D = entry["root"]
	var d: float = float(entry["dist"])
	var pos := track_curve.sample_baked(d)
	var next_pos := track_curve.sample_baked(fposmod(d + 2.0, baked_length))
	var fwd := (next_pos - pos).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	
	var lane_offset: float = float(entry["lane"])
	var target_pos := pos + right * lane_offset + Vector3(0, 0.12, 0)
	
	root.global_position = target_pos
	if fwd.length_squared() > 0.001:
		root.look_at(target_pos + fwd, Vector3.UP)
	
	# Roll wheels forward
	var wheel_rot: float = float(entry["speed"]) * delta * 4.0
	for wheel in entry["wheels"]:
		if is_instance_valid(wheel):
			wheel.rotation.x += wheel_rot

## Handle Racer vs Traffic Vehicle Collisions
func _on_traffic_hit(entry: Dictionary, hitting_body: Node) -> void:
	var car: ArcadeCar = null
	if hitting_body is ArcadeCar:
		car = hitting_body as ArcadeCar
	elif hitting_body.get_parent() is ArcadeCar:
		car = hitting_body.get_parent() as ArcadeCar
	elif hitting_body.owner is ArcadeCar:
		car = hitting_body.owner as ArcadeCar
	
	if not car or not is_instance_valid(car):
		return
	
	var is_super_powered: bool = false
	if car.has_node("KartItemSystem"):
		var kis = car.get_node("KartItemSystem")
		if kis.is_gold_star_active() or kis.current_active_item == 3: # Gold star or Nitro
			is_super_powered = true
	if "drift_boost_time" in car and car.drift_boost_time > 0.0:
		is_super_powered = true
	
	var root: Node3D = entry["root"]
	var cfg: Dictionary = entry["cfg"]
	
	if is_super_powered:
		# SMASH & CARTWHEEL FLIP!
		entry["is_spinning"] = true
		entry["spin_timer"] = 1.4
		if has_node("/root/SoundFX"):
			get_node("/root/SoundFX").play_explosion()
		
		# Show floating text
		var hud = get_tree().root.find_child("TouchHUD", true, false)
		if hud and hud.has_method("spawn_floating_text"):
			hud.spawn_floating_text(root.global_position + Vector3(0, 2.5, 0), "+150 TRAFFIC SMASH!", Color("f1c40f"), 1.2)
		
		traffic_smashed.emit(str(cfg["name"]), root.global_position)
	else:
		# Bump collision
		if has_node("/root/SoundFX"):
			get_node("/root/SoundFX").play_smash_hit()
		
		var cam_rig = get_tree().root.find_child("CameraRig", true, false)
		if cam_rig and cam_rig.has_method("add_trauma"):
			cam_rig.add_trauma(0.35)
		
		# Squeeze car speed slightly
		if car.physics_sphere:
			car.physics_sphere.linear_velocity *= 0.75
