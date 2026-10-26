class_name VoxelAssetBuilderClass
extends Node

## Procedural 3D Blocky Asset Builder for Smashy Heist: Daily Getaway.
## Constructs handcrafted Smashy Road / Crossy Road style 30-45 part voxel models in code:
## - 8 Player Brawler Cars (Getaway Coupe, Jet Tuk-Tuk, Dozer Tank, Frosty Van, Neon Blade, Bigfoot 4x4, VIP Limo, Apex F1)
## - 4 Police Units (Patrol Cruiser, Interceptor Muscle, SWAT Van, Rhino Tank)
## - 6 Civilian NPC Traffic Vehicles (Yellow Taxi, City Bus, Pizza Van, Dump Truck, Ambulance, Fuel Tanker)
## - Detailed Architectural City Buildings & Biome Landmarks (Donut Shop, Bank, Pagoda, Arcade, Gas Station, Docks Crane)

const VoxelCarBuilderScript = preload("res://scripts/vehicles/voxel_car_builder.gd")

var _mat_cache: Dictionary = {}

func _ready() -> void:
	pass

## Shared StandardMaterial3D instance factory with caching
func _make_mat(color: Color, emissive: bool = false, metallic: float = 0.1, roughness: float = 0.45) -> StandardMaterial3D:
	var key: String = "%s_%s_%.2f_%.2f" % [color.to_html(true), emissive, metallic, roughness]
	if _mat_cache.has(key):
		return _mat_cache[key]
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.6
	
	_mat_cache[key] = mat
	return mat

## Adds a BoxMesh instance to parent
func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, emissive: bool = false, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _make_mat(color, emissive)
	mi.position = pos
	if not rot_deg.is_zero_approx():
		mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

## Adds a CylinderMesh instance to parent
func _add_cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO, emissive: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = _make_mat(color, emissive)
	mi.position = pos
	if not rot_deg.is_zero_approx():
		mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

## Adds a TorusMesh instance to parent
func _add_torus(parent: Node3D, inner_rad: float, outer_rad: float, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO, emissive: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner_rad
	tm.outer_radius = outer_rad
	tm.rings = 16
	tm.ring_segments = 10
	mi.mesh = tm
	mi.material_override = _make_mat(color, emissive)
	mi.position = pos
	if not rot_deg.is_zero_approx():
		mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

## Adds a SphereMesh instance to parent
func _add_sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, emissive: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = _make_mat(color, emissive)
	mi.position = pos
	parent.add_child(mi)
	return mi

## Adds a solid StaticBody3D box collider on Layer 4 (Buildings: 8)
func _add_building_collider(parent: Node3D, size: Vector3, pos: Vector3, collision_layer: int = 8) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = "BuildingCollider"
	sb.position = pos
	sb.collision_layer = collision_layer # Layer 4: Buildings (8)
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	sb.add_child(cs)
	parent.add_child(sb)
	return sb

## Adds an AnimatableBody3D solid collider for moving vehicles/trains on Layer 4 (Buildings: 8)
func _add_train_collider(parent: Node3D, size: Vector3, pos: Vector3, collision_layer: int = 8) -> AnimatableBody3D:
	var ab := AnimatableBody3D.new()
	ab.name = "TrainCarSolidCollider"
	ab.position = pos
	ab.collision_layer = collision_layer # Layer 4: Buildings / Obstacles (8)
	ab.collision_mask = 0
	ab.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	ab.add_child(cs)
	parent.add_child(ab)
	return ab

## Multi-part wheels with tire tread, metallic rim, 5-spoke crossed bars, and red brake calipers
func _add_wheels(parent: Node3D, wheel_radius: float, wheel_width: float, track_x: float, wheelbase_z: float) -> Array[Node3D]:
	var wheels: Array[Node3D] = []
	var offsets: Array[Vector3] = [
		Vector3(-track_x, wheel_radius - 0.3, -wheelbase_z), # Front Left
		Vector3(track_x, wheel_radius - 0.3, -wheelbase_z),  # Front Right
		Vector3(-track_x, wheel_radius - 0.3, wheelbase_z),  # Rear Left
		Vector3(track_x, wheel_radius - 0.3, wheelbase_z)    # Rear Right
	]
	var tire_col := Color("1e272e")
	var rim_col := Color("d2dae2")
	var caliper_col := Color("e84118") # Bright red brake caliper
	
	for i in range(offsets.size()):
		var w_node := Node3D.new()
		w_node.name = "Wheel_%d" % i
		w_node.position = offsets[i]
		
		# 1. Outer tire tread CylinderMesh
		_add_cylinder(w_node, wheel_radius, wheel_width, Vector3.ZERO, tire_col, Vector3(0, 0, 90))
		# 2. Recessed metallic rim CylinderMesh
		_add_cylinder(w_node, wheel_radius * 0.72, wheel_width * 1.02, Vector3.ZERO, rim_col, Vector3(0, 0, 90))
		# 3. Two crossed BoxMesh 5-spoke bars for spin visibility
		_add_box(w_node, Vector3(wheel_width + 0.03, wheel_radius * 0.88, wheel_radius * 0.22), Vector3.ZERO, rim_col)
		_add_box(w_node, Vector3(wheel_width + 0.03, wheel_radius * 0.22, wheel_radius * 0.88), Vector3.ZERO, rim_col)
		# 4. Bright red brake caliper BoxMesh visible inside the rim
		var caliper_x_offset: float = -0.02 if offsets[i].x < 0 else 0.02
		_add_box(w_node, Vector3(wheel_width * 0.6, wheel_radius * 0.36, wheel_radius * 0.36), Vector3(caliper_x_offset, wheel_radius * 0.35, 0.0), caliper_col)
		
		parent.add_child(w_node)
		wheels.append(w_node)
	return wheels

## Flared 3-block arched wheel wells surrounding recessed cavities
func _add_flared_wheel_wells(root: Node3D, track_x: float, wheelbase_z: float, flare_color: Color) -> void:
	for side_x in [-track_x, track_x]:
		for axle_z in [-wheelbase_z, wheelbase_z]:
			# Top arch box over wheel
			_add_box(root, Vector3(0.14, 0.10, 0.62), Vector3(side_x * 0.98, 0.34, axle_z), flare_color)
			# Front mudflap arch box
			_add_box(root, Vector3(0.12, 0.24, 0.12), Vector3(side_x * 0.98, 0.20, axle_z - 0.26), flare_color)
			# Rear mudflap arch box
			_add_box(root, Vector3(0.12, 0.24, 0.12), Vector3(side_x * 0.98, 0.20, axle_z + 0.26), flare_color)

## Ultra-detailed common chassis: sills, bumpers, grille, headlights, taillights, wipers, interior, plates, mirrors
func _add_common_chassis(root: Node3D) -> void:
	# Lower Underbody Frame in dark charcoal
	_add_box(root, Vector3(1.16, 0.22, 2.30), Vector3(0.0, 0.05, 0.0), Color("1e272e"))
	# Left/Right Side-Skirt Rocker Panels
	_add_box(root, Vector3(0.10, 0.12, 1.48), Vector3(-0.58, 0.08, 0.0), Color("2f3640"))
	_add_box(root, Vector3(0.10, 0.12, 1.48), Vector3(0.58, 0.08, 0.0), Color("2f3640"))
	# Front & Rear Stepped Valence Aprons
	_add_box(root, Vector3(1.08, 0.10, 0.12), Vector3(0.0, 0.02, -1.14), Color("1e272e"))
	_add_box(root, Vector3(1.08, 0.10, 0.12), Vector3(0.0, 0.02, 1.14), Color("1e272e"))
	# Front & Rear Chrome Bumpers
	_add_box(root, Vector3(1.22, 0.16, 0.14), Vector3(0.0, 0.08, -1.16), Color("d2dae2"))
	_add_box(root, Vector3(1.22, 0.16, 0.14), Vector3(0.0, 0.08, 1.16), Color("d2dae2"))
	# Front Radiator Grille in dark iron
	_add_box(root, Vector3(0.64, 0.20, 0.06), Vector3(0.0, 0.24, -1.14), Color("2f3640"))
	# Front & Rear White License Plates
	_add_box(root, Vector3(0.36, 0.12, 0.04), Vector3(0.0, 0.08, -1.24), Color("f5f6fa"))
	_add_box(root, Vector3(0.36, 0.12, 0.04), Vector3(0.0, 0.08, 1.24), Color("f5f6fa"))
	# 4-Block Headlights: Main beam warm-yellow + Amber corner blinkers
	_add_box(root, Vector3(0.20, 0.14, 0.06), Vector3(-0.38, 0.26, -1.14), Color("fff200"), true)
	_add_box(root, Vector3(0.10, 0.14, 0.06), Vector3(-0.52, 0.26, -1.14), Color("e67e22"), true)
	_add_box(root, Vector3(0.20, 0.14, 0.06), Vector3(0.38, 0.26, -1.14), Color("fff200"), true)
	_add_box(root, Vector3(0.10, 0.14, 0.06), Vector3(0.52, 0.26, -1.14), Color("e67e22"), true)
	# 4-Block Taillights: Red brake + White reverse lights
	_add_box(root, Vector3(0.22, 0.14, 0.06), Vector3(-0.42, 0.26, 1.14), Color("ff3f34"), true)
	_add_box(root, Vector3(0.08, 0.14, 0.06), Vector3(-0.28, 0.26, 1.14), Color("f5f6fa"), true)
	_add_box(root, Vector3(0.22, 0.14, 0.06), Vector3(0.42, 0.26, 1.14), Color("ff3f34"), true)
	_add_box(root, Vector3(0.08, 0.14, 0.06), Vector3(0.28, 0.26, 1.14), Color("f5f6fa"), true)
	# Side Wing Mirrors with reflective silver glass faces
	_add_box(root, Vector3(0.14, 0.10, 0.10), Vector3(-0.64, 0.48, -0.25), Color("1e272e"))
	_add_box(root, Vector3(0.02, 0.08, 0.08), Vector3(-0.70, 0.48, -0.25), Color("d2dae2"))
	_add_box(root, Vector3(0.14, 0.10, 0.10), Vector3(0.64, 0.48, -0.25), Color("1e272e"))
	_add_box(root, Vector3(0.02, 0.08, 0.08), Vector3(0.70, 0.48, -0.25), Color("d2dae2"))
	# Chrome Door Handles (left & right)
	_add_box(root, Vector3(0.04, 0.05, 0.12), Vector3(-0.61, 0.32, 0.08), Color("d2dae2"))
	_add_box(root, Vector3(0.04, 0.05, 0.12), Vector3(0.61, 0.32, 0.08), Color("d2dae2"))
	# Windshield Cowl & 2 Voxel Windshield Wiper Blades
	_add_box(root, Vector3(0.26, 0.03, 0.04), Vector3(-0.22, 0.42, -0.54), Color("1e272e"), false, Vector3(0, 15, 0))
	_add_box(root, Vector3(0.26, 0.03, 0.04), Vector3(0.22, 0.42, -0.54), Color("1e272e"), false, Vector3(0, 15, 0))
	# Visible Interior Steering Wheel & Driver Headrest Block
	_add_box(root, Vector3(0.16, 0.16, 0.05), Vector3(-0.26, 0.48, -0.28), Color("2f3640"), false, Vector3(25, 0, 0))
	_add_box(root, Vector3(0.18, 0.22, 0.14), Vector3(-0.26, 0.50, 0.05), Color("2f3640"))
	# Twin Exhaust Pipes in dark silver
	_add_box(root, Vector3(0.10, 0.10, 0.18), Vector3(-0.32, 0.04, 1.20), Color("718093"))
	_add_box(root, Vector3(0.10, 0.10, 0.18), Vector3(0.32, 0.04, 1.20), Color("718093"))

## Builds ultra-detailed 30-45 part 3D blocky visuals for all 8 brawler cars
func build_player_car_visuals(car_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelCarModel_%s" % car_id
	
	match car_id:
		"tuk_tuk_jet":
			# 3-Wheel layout
			var w_front := Node3D.new()
			w_front.position = Vector3(0.0, 0.02, -0.92)
			_add_cylinder(w_front, 0.26, 0.16, Vector3.ZERO, Color("1e272e"), Vector3(0, 0, 90))
			_add_box(w_front, Vector3(0.18, 0.22, 0.22), Vector3.ZERO, Color("d2dae2"))
			root.add_child(w_front)
			
			for rx in [-0.56, 0.56]:
				var w_rear := Node3D.new()
				w_rear.position = Vector3(rx, 0.02, 0.72)
				_add_cylinder(w_rear, 0.28, 0.18, Vector3.ZERO, Color("1e272e"), Vector3(0, 0, 90))
				_add_box(w_rear, Vector3(0.20, 0.24, 0.24), Vector3.ZERO, Color("d2dae2"))
				root.add_child(w_rear)
			
			# Tubular front fork over single front wheel
			_add_cylinder(root, 0.04, 0.45, Vector3(-0.10, 0.22, -0.92), Color("d2dae2"))
			_add_cylinder(root, 0.04, 0.45, Vector3(0.10, 0.22, -0.92), Color("d2dae2"))
			# Brass handlebars + round retro headlamp
			_add_box(root, Vector3(0.44, 0.06, 0.06), Vector3(0.0, 0.44, -0.84), Color("f9ca24"))
			_add_cylinder(root, 0.10, 0.08, Vector3(0.0, 0.38, -1.06), Color("fff200"), Vector3(90, 0, 0), true)
			
			# Chassis floor & teal front cowl
			_add_box(root, Vector3(1.02, 0.18, 2.00), Vector3(0.0, 0.06, 0.0), Color("1e272e"))
			_add_box(root, Vector3(0.94, 0.44, 0.88), Vector3(0.0, 0.34, -0.62), Color("00d2d3"))
			
			# Gold-fringed fabric canopy roof with hanging tassels
			_add_box(root, Vector3(1.06, 0.08, 1.45), Vector3(0.0, 0.86, 0.12), Color("f9ca24"))
			_add_box(root, Vector3(1.08, 0.04, 0.04), Vector3(0.0, 0.82, -0.60), Color("fbc531"))
			_add_box(root, Vector3(1.08, 0.04, 0.04), Vector3(0.0, 0.82, 0.84), Color("fbc531"))
			for px in [-0.46, 0.46]:
				for pz in [-0.52, 0.76]:
					_add_box(root, Vector3(0.06, 0.52, 0.06), Vector3(px, 0.58, pz), Color("d2dae2"))
			
			# Passenger bench seat inside
			_add_box(root, Vector3(0.86, 0.22, 0.42), Vector3(0.0, 0.24, 0.28), Color("2f3640"))
			
			# 7-Part Turbofan Jet Engine
			_add_cylinder(root, 0.34, 0.75, Vector3(0.0, 0.42, 0.95), Color("718093"), Vector3(90, 0, 0)) # Cowling
			_add_cylinder(root, 0.24, 0.22, Vector3(0.0, 0.42, 1.36), Color("00ffff"), Vector3(90, 0, 0), true) # Afterburner ring
			_add_cylinder(root, 0.16, 0.14, Vector3(0.0, 0.42, 1.44), Color("e67e22"), Vector3(90, 0, 0), true) # Flame core
			_add_cylinder(root, 0.04, 0.65, Vector3(-0.36, 0.42, 0.95), Color("e17055")) # Copper pipe L
			_add_cylinder(root, 0.04, 0.65, Vector3(0.36, 0.42, 0.95), Color("e17055"))  # Copper pipe R
			_add_box(root, Vector3(0.36, 0.04, 0.04), Vector3(0.0, 0.42, 0.58), Color("2f3640")) # Intake fan cross 1
			_add_box(root, Vector3(0.04, 0.36, 0.04), Vector3(0.0, 0.42, 0.58), Color("2f3640")) # Intake fan cross 2
			
		"armored_bulldozer":
			_add_wheels(root, 0.36, 0.26, 0.72, 0.78)
			_add_flared_wheel_wells(root, 0.72, 0.78, Color("fbc531"))
			# Heavy industrial yellow body with steel armor plates
			_add_box(root, Vector3(1.34, 0.46, 2.20), Vector3(0.0, 0.30, 0.0), Color("fbc531"))
			_add_box(root, Vector3(1.38, 0.32, 1.60), Vector3(0.0, 0.32, 0.0), Color("353b48")) # Side armor plates
			# Cabin with roll cage
			_add_box(root, Vector3(1.05, 0.55, 1.05), Vector3(0.0, 0.72, 0.05), Color("2f3640"))
			_add_box(root, Vector3(0.96, 0.38, 0.90), Vector3(0.0, 0.72, 0.05), Color("00d2d3"))
			for cx in [-0.54, 0.54]:
				for cz in [-0.48, 0.58]:
					_add_box(root, Vector3(0.08, 0.58, 0.08), Vector3(cx, 0.72, cz), Color("1e272e"))
			
			# Spinning amber dual roof beacons
			_add_cylinder(root, 0.12, 0.18, Vector3(-0.35, 1.02, 0.15), Color("ffa801"), Vector3.ZERO, true)
			_add_cylinder(root, 0.12, 0.18, Vector3(0.35, 1.02, 0.15), Color("ffa801"), Vector3.ZERO, true)
			
			# Twin vertical smokestack exhausts with flapper caps
			_add_cylinder(root, 0.06, 0.65, Vector3(-0.48, 0.85, 0.65), Color("2f3640"))
			_add_box(root, Vector3(0.12, 0.03, 0.12), Vector3(-0.48, 1.18, 0.65), Color("718093"))
			_add_cylinder(root, 0.06, 0.65, Vector3(0.48, 0.85, 0.65), Color("2f3640"))
			_add_box(root, Vector3(0.12, 0.03, 0.12), Vector3(0.48, 1.18, 0.65), Color("718093"))
			
			# Curved 5-Part Snowplow/Dozer Blade with yellow hazard stripes
			_add_box(root, Vector3(1.56, 0.55, 0.18), Vector3(0.0, 0.22, -1.38), Color("d2dae2"), false, Vector3(-12, 0, 0))
			_add_box(root, Vector3(1.64, 0.12, 0.06), Vector3(0.0, 0.40, -1.48), Color("f1c40f"), true) # Hazard stripe top
			_add_box(root, Vector3(1.64, 0.12, 0.06), Vector3(0.0, 0.12, -1.36), Color("f1c40f"), true) # Hazard stripe bot
			_add_box(root, Vector3(0.16, 0.16, 0.75), Vector3(-0.70, 0.26, -1.02), Color("718093")) # Piston L
			_add_box(root, Vector3(0.16, 0.16, 0.75), Vector3(0.70, 0.26, -1.02), Color("718093"))  # Piston R
			
		"ice_cream_drifter":
			_add_common_chassis(root)
			_add_flared_wheel_wells(root, 0.62, 0.82, Color("ff9ff3"))
			_add_wheels(root, 0.30, 0.20, 0.62, 0.82)
			# Two-tone scalloped pink & mint body
			_add_box(root, Vector3(1.22, 0.42, 2.34), Vector3(0.0, 0.26, 0.0), Color("ff9ff3"))
			_add_box(root, Vector3(1.20, 0.42, 2.30), Vector3(0.0, 0.62, 0.0), Color("ffffff"))
			_add_box(root, Vector3(1.24, 0.08, 2.32), Vector3(0.0, 0.44, 0.0), Color("55efc4")) # Mint scalloped trim
			# Side serving window with mini menu board and popsicles
			_add_box(root, Vector3(0.06, 0.30, 0.75), Vector3(0.61, 0.65, 0.20), Color("1e272e")) # Window cutout
			_add_box(root, Vector3(0.04, 0.18, 0.25), Vector3(0.61, 0.65, -0.32), Color("ffeaa7")) # Menu board
			_add_box(root, Vector3(0.03, 0.08, 0.04), Vector3(0.62, 0.60, 0.10), Color("e84118")) # Popsicle 1
			_add_box(root, Vector3(0.03, 0.08, 0.04), Vector3(0.62, 0.60, 0.20), Color("00cec9")) # Popsicle 2
			_add_box(root, Vector3(0.03, 0.08, 0.04), Vector3(0.62, 0.60, 0.30), Color("fdcb6e")) # Popsicle 3
			_add_box(root, Vector3(0.16, 0.26, 1.05), Vector3(0.64, 0.82, 0.20), Color("ff3f34"), false, Vector3(15, 0, 0)) # Striped awning
			# Vintage brass bell on roof
			_add_cylinder(root, 0.08, 0.12, Vector3(0.0, 0.88, -0.65), Color("f1c40f"))
			# 9-Part Tilted Waffle Cone + Swirling Soft-Serve & Cherry
			_add_cylinder(root, 0.28, 0.65, Vector3(0.0, 1.05, -0.1), Color("f3a683"), Vector3(70, 0, 0))
			_add_box(root, Vector3(0.42, 0.16, 0.42), Vector3(0.0, 1.20, 0.12), Color("ff9ff3"))
			_add_box(root, Vector3(0.34, 0.14, 0.34), Vector3(0.0, 1.32, 0.12), Color("ffffff"))
			_add_box(root, Vector3(0.24, 0.12, 0.24), Vector3(0.0, 1.42, 0.12), Color("ff9ff3"))
			_add_cylinder(root, 0.09, 0.10, Vector3(0.0, 1.50, 0.12), Color("e84118"), Vector3.ZERO, true) # Red cherry
			_add_box(root, Vector3(0.04, 0.28, 0.04), Vector3(0.12, 1.40, 0.12), Color("6c5ce7"), false, Vector3(20, 10, 0)) # Wafer stick
			
		"cyber_interceptor":
			_add_common_chassis(root)
			_add_flared_wheel_wells(root, 0.66, 0.84, Color("1e272e"))
			_add_wheels(root, 0.32, 0.22, 0.66, 0.84)
			# Origami wedge supercar body
			_add_box(root, Vector3(1.26, 0.28, 2.36), Vector3(0.0, 0.20, 0.0), Color("1e272e"))
			_add_box(root, Vector3(0.92, 0.24, 1.10), Vector3(0.0, 0.44, 0.0), Color("0a0a0a"))
			# Glowing cyan neon edge channels (6 channels)
			_add_box(root, Vector3(0.06, 0.06, 2.32), Vector3(-0.63, 0.24, 0.0), Color("00ffff"), true)
			_add_box(root, Vector3(0.06, 0.06, 2.32), Vector3(0.63, 0.24, 0.0), Color("00ffff"), true)
			_add_box(root, Vector3(0.06, 0.06, 1.10), Vector3(-0.46, 0.54, 0.0), Color("00ffff"), true)
			_add_box(root, Vector3(0.06, 0.06, 1.10), Vector3(0.46, 0.54, 0.0), Color("00ffff"), true)
			_add_box(root, Vector3(1.02, 0.04, 0.04), Vector3(0.0, 0.32, -1.18), Color("00ffff"), true)
			_add_box(root, Vector3(1.10, 0.08, 0.06), Vector3(0.0, 0.26, 1.18), Color("ff0055"), true) # Full-width cyberpunk LED lightbar
			# Scissor-door seam lines
			_add_box(root, Vector3(0.02, 0.22, 0.65), Vector3(-0.64, 0.26, 0.0), Color("00ffff"), true)
			_add_box(root, Vector3(0.02, 0.22, 0.65), Vector3(0.64, 0.26, 0.0), Color("00ffff"), true)
			# Glowing purple reactor core under rear glass
			_add_box(root, Vector3(0.42, 0.14, 0.42), Vector3(0.0, 0.36, 0.65), Color("9b59b6"), true)
			_add_box(root, Vector3(0.65, 0.04, 0.55), Vector3(0.0, 0.44, 0.65), Color("00ffff"), true) # Glass cover
			
		"monster_pickup":
			_add_wheels(root, 0.46, 0.34, 0.78, 0.88)
			# Raised chassis & red coil-over suspension springs
			_add_box(root, Vector3(1.18, 0.20, 2.30), Vector3(0.0, 0.28, 0.0), Color("1e272e"))
			for sx in [-0.60, 0.60]:
				for sz in [-0.88, 0.88]:
					_add_cylinder(root, 0.09, 0.38, Vector3(sx, 0.18, sz), Color("e84118")) # Red springs
			# Electric-blue cab & open bed
			_add_box(root, Vector3(1.24, 0.32, 0.90), Vector3(0.0, 0.52, -0.65), Color("0abde3"))
			_add_box(root, Vector3(1.16, 0.42, 0.85), Vector3(0.0, 0.85, -0.15), Color("0abde3"))
			_add_box(root, Vector3(1.18, 0.34, 0.75), Vector3(0.0, 0.85, -0.15), Color("1b9cfc"))
			_add_box(root, Vector3(1.24, 0.34, 1.05), Vector3(0.0, 0.52, 0.65), Color("0abde3"))
			_add_box(root, Vector3(0.96, 0.30, 0.88), Vector3(0.0, 0.54, 0.65), Color("1e272e"))
			# Chrome double-tube bullbar with winch
			_add_box(root, Vector3(1.30, 0.36, 0.16), Vector3(0.0, 0.42, -1.25), Color("d2dae2"))
			_add_box(root, Vector3(0.24, 0.16, 0.12), Vector3(0.0, 0.32, -1.32), Color("2f3640")) # Winch
			# Tubular bed roll-bar topped with 4 round chrome KC floodlights
			_add_box(root, Vector3(1.12, 0.06, 0.18), Vector3(0.0, 1.10, -0.15), Color("d2dae2"))
			for fx in [-0.42, -0.14, 0.14, 0.42]:
				_add_cylinder(root, 0.09, 0.10, Vector3(fx, 1.16, -0.15), Color("f9ca24"), Vector3(90, 0, 0), true)
			# 2 Strapped red jerrycans + angled spare tire in bed
			_add_box(root, Vector3(0.18, 0.26, 0.14), Vector3(-0.35, 0.65, 0.35), Color("e84118"))
			_add_box(root, Vector3(0.18, 0.26, 0.14), Vector3(-0.15, 0.65, 0.35), Color("e84118"))
			var spare := Node3D.new()
			spare.position = Vector3(0.15, 0.65, 0.62)
			spare.rotation_degrees = Vector3(25, 0, 0)
			_add_cylinder(spare, 0.42, 0.28, Vector3.ZERO, Color("1e272e"), Vector3(0, 0, 90))
			_add_box(spare, Vector3(0.30, 0.36, 0.36), Vector3.ZERO, Color("d2dae2"))
			root.add_child(spare)
			
		"gold_limo":
			# Stretched 3.2m golden body with 3 side window bays separated by chrome B-pillars
			_add_wheels(root, 0.28, 0.18, 0.60, 1.25)
			# Center auxiliary wheels
			for mx in [-0.60, 0.60]:
				var w_m := Node3D.new()
				w_m.position = Vector3(mx, -0.02, 0.0)
				_add_cylinder(w_m, 0.28, 0.18, Vector3.ZERO, Color("1e272e"), Vector3(0, 0, 90))
				_add_box(w_m, Vector3(0.20, 0.24, 0.24), Vector3.ZERO, Color("d2dae2"))
				root.add_child(w_m)
			
			_add_box(root, Vector3(1.18, 0.24, 3.20), Vector3(0.0, 0.08, 0.0), Color("1e272e"))
			_add_box(root, Vector3(1.20, 0.34, 3.16), Vector3(0.0, 0.28, 0.0), Color("f9ca24"))
			_add_box(root, Vector3(0.96, 0.32, 2.20), Vector3(0.0, 0.56, 0.10), Color("0a0a0a"))
			# Chrome B-Pillars dividing 3 window bays
			_add_box(root, Vector3(0.98, 0.32, 0.06), Vector3(0.0, 0.56, -0.40), Color("d2dae2"))
			_add_box(root, Vector3(0.98, 0.32, 0.06), Vector3(0.0, 0.56, 0.40), Color("d2dae2"))
			# White vinyl landau roof rear section
			_add_box(root, Vector3(1.02, 0.34, 0.70), Vector3(0.0, 0.57, 0.95), Color("f5f6fa"))
			# Boomerang TV antenna on trunk
			_add_box(root, Vector3(0.36, 0.04, 0.20), Vector3(0.0, 0.48, 1.45), Color("d2dae2"))
			# Golden hood ornament statue
			_add_cylinder(root, 0.06, 0.16, Vector3(0.0, 0.48, -1.50), Color("fbc531"), Vector3.ZERO, true)
			# Central party sunroof with mini disco ball sphere & neon magenta glow
			_add_box(root, Vector3(0.68, 0.04, 0.90), Vector3(0.0, 0.72, 0.10), Color("a55eea"), true)
			_add_cylinder(root, 0.10, 0.10, Vector3(0.0, 0.80, 0.10), Color("ffffff"), Vector3.ZERO, true)
			
		"f1_street_kart":
			_add_wheels(root, 0.26, 0.24, 0.66, 0.85)
			# Narrow aerodynamic fuselage
			_add_box(root, Vector3(0.62, 0.26, 2.40), Vector3(0.0, 0.16, 0.0), Color("eb4d4b"))
			# Multi-element front carbon wing with endplates
			_add_box(root, Vector3(1.30, 0.06, 0.32), Vector3(0.0, 0.08, -1.24), Color("130f40"))
			_add_box(root, Vector3(0.06, 0.16, 0.36), Vector3(-0.68, 0.12, -1.24), Color("eb4d4b"))
			_add_box(root, Vector3(0.06, 0.16, 0.36), Vector3(0.68, 0.12, -1.24), Color("eb4d4b"))
			# Front pushrod suspension arms
			_add_cylinder(root, 0.02, 0.48, Vector3(-0.35, 0.18, -0.85), Color("718093"), Vector3(0, 0, 45))
			_add_cylinder(root, 0.02, 0.48, Vector3(0.35, 0.18, -0.85), Color("718093"), Vector3(0, 0, -45))
			# Sculpted sidepods with radiator intakes
			_add_box(root, Vector3(0.34, 0.22, 1.05), Vector3(-0.48, 0.14, 0.15), Color("ffffff"))
			_add_box(root, Vector3(0.34, 0.22, 1.05), Vector3(0.48, 0.14, 0.15), Color("ffffff"))
			# Halo safety bar + driver helmet with gold visor
			_add_cylinder(root, 0.18, 0.24, Vector3(0.0, 0.38, 0.0), Color("f1c40f")) # Helmet
			_add_box(root, Vector3(0.14, 0.06, 0.10), Vector3(0.0, 0.40, -0.08), Color("f39c12"), true) # Gold visor
			_add_box(root, Vector3(0.38, 0.06, 0.38), Vector3(0.0, 0.48, 0.0), Color("130f40")) # Halo safety loop
			# Overhead airbox intake & DRS dual-plane rear wing
			_add_box(root, Vector3(0.24, 0.22, 0.32), Vector3(0.0, 0.52, 0.36), Color("eb4d4b"))
			_add_box(root, Vector3(0.06, 0.36, 0.30), Vector3(-0.58, 0.44, 1.15), Color("130f40"))
			_add_box(root, Vector3(0.06, 0.36, 0.30), Vector3(0.58, 0.44, 1.15), Color("130f40"))
			_add_box(root, Vector3(1.22, 0.05, 0.28), Vector3(0.0, 0.58, 1.15), Color("eb4d4b"))
			_add_box(root, Vector3(1.22, 0.05, 0.20), Vector3(0.0, 0.68, 1.15), Color("eb4d4b"))
			
		"racer_01":
			# Aerodynamic crimson GT street racer with low front splitter & dual-plane rear wing
			_add_wheels(root, 0.28, 0.22, 0.64, 0.78)
			_add_flared_wheel_wells(root, 0.64, 0.78, Color("c0392b"))
			# Low-slung chassis & front carbon splitter
			_add_box(root, Vector3(1.22, 0.30, 2.30), Vector3(0.0, 0.20, 0.0), Color("e74c3c"))
			_add_box(root, Vector3(1.28, 0.04, 0.36), Vector3(0.0, 0.06, -1.22), Color("1e272e"))
			# Aerodynamic curved cockpit with dark tinted canopy
			_add_box(root, Vector3(0.96, 0.32, 1.10), Vector3(0.0, 0.48, 0.04), Color("1e272e"))
			_add_box(root, Vector3(0.98, 0.24, 0.90), Vector3(0.0, 0.48, 0.04), Color("0984e3"))
			# Hood vents & twin gold racing stripes
			_add_box(root, Vector3(0.14, 0.32, 2.32), Vector3(-0.16, 0.20, 0.0), Color("f1c40f"))
			_add_box(root, Vector3(0.14, 0.32, 2.32), Vector3(0.16, 0.20, 0.0), Color("f1c40f"))
			# GT Racing Wing on twin carbon uprights
			_add_box(root, Vector3(0.06, 0.24, 0.08), Vector3(-0.46, 0.46, 1.05), Color("1e272e"))
			_add_box(root, Vector3(0.06, 0.24, 0.08), Vector3(0.46, 0.46, 1.05), Color("1e272e"))
			_add_box(root, Vector3(1.28, 0.06, 0.28), Vector3(0.0, 0.58, 1.05), Color("e74c3c"))
			_add_box(root, Vector3(0.06, 0.16, 0.30), Vector3(-0.66, 0.58, 1.05), Color("1e272e"))
			_add_box(root, Vector3(0.06, 0.16, 0.30), Vector3(0.66, 0.58, 1.05), Color("1e272e"))
			# Twin chrome exhausts
			_add_cylinder(root, 0.06, 0.14, Vector3(-0.30, 0.14, 1.18), Color("dfe6e9"), Vector3(90, 0, 0))
			_add_cylinder(root, 0.06, 0.14, Vector3(0.30, 0.14, 1.18), Color("dfe6e9"), Vector3(90, 0, 0))
			
		"tanker":
			# Heavy armored combat assault vehicle with olive green armor plating and turret cupola
			# 6-wheel heavy armored suspension
			for wx in [-0.72, 0.72]:
				for wz in [-0.85, 0.0, 0.85]:
					var w := Node3D.new()
					w.position = Vector3(wx, 0.02, wz)
					_add_cylinder(w, 0.32, 0.22, Vector3.ZERO, Color("1e272e"), Vector3(0, 0, 90))
					_add_cylinder(w, 0.18, 0.24, Vector3.ZERO, Color("27ae60"), Vector3(0, 0, 90))
					root.add_child(w)
			# Angular armored hull in military green
			_add_box(root, Vector3(1.42, 0.45, 2.50), Vector3(0.0, 0.32, 0.0), Color("27ae60"))
			# Side armored skirts shielding wheels
			_add_box(root, Vector3(0.12, 0.28, 2.40), Vector3(-0.76, 0.22, 0.0), Color("2c3e50"))
			_add_box(root, Vector3(0.12, 0.28, 2.40), Vector3(0.76, 0.22, 0.0), Color("2c3e50"))
			# Angled steel ramming prow on front
			_add_box(root, Vector3(1.46, 0.48, 0.25), Vector3(0.0, 0.26, -1.32), Color("34495e"), false, Vector3(-18, 0, 0))
			# Low-profile armored command cupola with hatch & periscopes
			_add_box(root, Vector3(0.92, 0.35, 1.10), Vector3(0.0, 0.70, -0.10), Color("218c74"))
			_add_cylinder(root, 0.30, 0.12, Vector3(0.0, 0.92, -0.05), Color("2c3e50"))
			_add_box(root, Vector3(0.16, 0.12, 0.16), Vector3(-0.24, 0.94, -0.22), Color("f1c40f"), true)
			_add_box(root, Vector3(0.16, 0.12, 0.16), Vector3(0.24, 0.94, -0.22), Color("f1c40f"), true)
			
		"shadow":
			# Ultra-sleek stealth hypercar with matte carbon black body and violet neon energy veins
			_add_wheels(root, 0.27, 0.20, 0.64, 0.80)
			# Aggressive wedge body with sharp geometric facets
			_add_box(root, Vector3(1.24, 0.28, 2.35), Vector3(0.0, 0.20, 0.0), Color("1e272e"))
			_add_box(root, Vector3(1.10, 0.20, 1.20), Vector3(0.0, 0.42, 0.08), Color("0a0a0a"))
			# Glowing neon violet underglow and intake edges
			_add_box(root, Vector3(1.28, 0.04, 2.30), Vector3(0.0, 0.08, 0.0), Color("9b59b6"), true)
			_add_box(root, Vector3(0.35, 0.04, 0.04), Vector3(-0.42, 0.26, -1.18), Color("9b59b6"), true)
			_add_box(root, Vector3(0.35, 0.04, 0.04), Vector3(0.42, 0.26, -1.18), Color("9b59b6"), true)
			# Dark purple tinted cockpit
			_add_box(root, Vector3(0.92, 0.22, 0.85), Vector3(0.0, 0.44, 0.04), Color("8e44ad"))
			# Stealth shark fin dorsal spine & split rear diffuser
			_add_box(root, Vector3(0.04, 0.26, 0.85), Vector3(0.0, 0.52, 0.48), Color("9b59b6"), true)
			_add_box(root, Vector3(1.20, 0.06, 0.22), Vector3(0.0, 0.48, 1.15), Color("1e272e"))
			
		"fire_dragon":
			# Mythic blazing fire dragon hypercar with dorsal horns, flame orange body and exhaust vents
			_add_wheels(root, 0.29, 0.22, 0.65, 0.80)
			_add_flared_wheel_wells(root, 0.65, 0.80, Color("c0392b"))
			# Fiery crimson body with gold horn accents
			_add_box(root, Vector3(1.26, 0.32, 2.36), Vector3(0.0, 0.22, 0.0), Color("d63031"))
			# Dragon head sculpted front hood with glowing orange intake nostrils
			_add_box(root, Vector3(0.85, 0.22, 0.90), Vector3(0.0, 0.32, -0.75), Color("e17055"))
			_add_box(root, Vector3(0.18, 0.08, 0.15), Vector3(-0.22, 0.42, -1.05), Color("f1c40f"), true)
			_add_box(root, Vector3(0.18, 0.08, 0.15), Vector3(0.22, 0.42, -1.05), Color("f1c40f"), true)
			# Dragon dorsal spine ridges along roof
			for fz in range(3):
				_add_box(root, Vector3(0.08, 0.18, 0.22), Vector3(0.0, 0.66 + fz * 0.02, -0.20 + fz * 0.35), Color("f1c40f"))
			# Cockpit with golden tinted glass
			_add_box(root, Vector3(0.94, 0.26, 0.95), Vector3(0.0, 0.48, 0.06), Color("f39c12"))
			# Dragon tail swept rear wing with upward flame tips
			_add_box(root, Vector3(0.08, 0.28, 0.12), Vector3(-0.52, 0.48, 1.10), Color("d63031"))
			_add_box(root, Vector3(0.08, 0.28, 0.12), Vector3(0.52, 0.48, 1.10), Color("d63031"))
			_add_box(root, Vector3(1.30, 0.08, 0.32), Vector3(0.0, 0.62, 1.10), Color("e17055"))
			_add_box(root, Vector3(0.12, 0.22, 0.12), Vector3(-0.66, 0.70, 1.10), Color("f1c40f"), true)
			_add_box(root, Vector3(0.12, 0.22, 0.12), Vector3(0.66, 0.70, 1.10), Color("f1c40f"), true)
			# Quad side exhaust flame ports
			for sx in [-0.66, 0.66]:
				_add_box(root, Vector3(0.08, 0.10, 0.32), Vector3(sx, 0.15, 0.25), Color("f1c40f"), true)
			
		_: # Check if in VehicleDatabase, otherwise default to Getaway Coupe
			var vdb = null
			if is_inside_tree():
				vdb = get_node_or_null("/root/VehicleDatabase")
			elif Engine.get_main_loop() is SceneTree:
				var st := Engine.get_main_loop() as SceneTree
				if st and st.root:
					vdb = st.root.get_node_or_null("VehicleDatabase")
			
			if vdb and vdb.has_car(car_id) and car_id != "default_coupe":
				return VoxelCarBuilderScript.build_car(car_id, vdb.get_car(car_id), self)
			
			_add_common_chassis(root)
			_add_flared_wheel_wells(root, 0.60, 0.75, Color("e84118"))
			_add_wheels(root, 0.28, 0.18, 0.60, 0.75)
			# Main Body in Crimson
			_add_box(root, Vector3(1.18, 0.36, 2.24), Vector3(0.0, 0.24, 0.0), Color("e84118"))
			# Twin White Racing Stripes
			_add_box(root, Vector3(0.16, 0.38, 2.25), Vector3(-0.14, 0.24, 0.0), Color("f5f6fa"))
			_add_box(root, Vector3(0.16, 0.38, 2.25), Vector3(0.14, 0.24, 0.0), Color("f5f6fa"))
			# Supercharger Blower Intake with 3 Chrome Butterfly Valves
			_add_box(root, Vector3(0.32, 0.18, 0.42), Vector3(0.0, 0.46, -0.62), Color("d2dae2"))
			_add_cylinder(root, 0.05, 0.12, Vector3(-0.08, 0.54, -0.62), Color("ff3f34"), Vector3(90, 0, 0), true)
			_add_cylinder(root, 0.05, 0.12, Vector3(0.0, 0.54, -0.62), Color("ff3f34"), Vector3(90, 0, 0), true)
			_add_cylinder(root, 0.05, 0.12, Vector3(0.08, 0.54, -0.62), Color("ff3f34"), Vector3(90, 0, 0), true)
			# Cabin Greenhouse with dark cyan windshield
			_add_box(root, Vector3(0.98, 0.34, 1.05), Vector3(0.0, 0.56, 0.08), Color("1e272e"))
			_add_box(root, Vector3(1.00, 0.26, 0.88), Vector3(0.0, 0.56, 0.08), Color("1b9cfc"))
			# Rear Window Louvers (4 horizontal black slats)
			for lz in range(4):
				_add_box(root, Vector3(0.86, 0.03, 0.06), Vector3(0.0, 0.58 - lz * 0.06, 0.42 + lz * 0.09), Color("0a0a0a"))
			# Dual-Pedestal GT Wing
			_add_box(root, Vector3(0.08, 0.20, 0.08), Vector3(-0.42, 0.44, 1.00), Color("1e272e"))
			_add_box(root, Vector3(0.08, 0.20, 0.08), Vector3(0.42, 0.44, 1.00), Color("1e272e"))
			_add_box(root, Vector3(1.16, 0.06, 0.24), Vector3(0.0, 0.54, 1.02), Color("e84118"))
	
	return root

## =============================================================================
## 3D GEAR ITEM BUILDERS (ENGINE, WHEELS, WINGS, ARMOR, GADGET, SKIN)
## =============================================================================

## Builds a 3D preview model for any gear item category
func build_gear_visuals(gear_type: String) -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelGearModel_%s" % gear_type
	
	match gear_type.to_lower():
		"engine":
			return build_gear_jet_engine()
		"wheels":
			return build_gear_wheels()
		"wings":
			return build_gear_wings()
		"armor":
			return build_gear_armor()
		"gadget":
			return build_gear_gadget()
		"skin":
			return build_gear_skin()
		_:
			return build_gear_jet_engine()

## 3D High-Performance Jet Engine with intake fan, bronze combustor and glowing afterburner
func build_gear_jet_engine() -> Node3D:
	var root := Node3D.new()
	root.name = "GearJetEngine"
	
	# Pedestal Base Stand
	_add_cylinder(root, 1.10, 0.25, Vector3(0.0, 0.12, 0.0), Color("1e272e"))
	_add_cylinder(root, 0.95, 0.15, Vector3(0.0, 0.28, 0.0), Color("00d2d3"), Vector3.ZERO, true) # Glowing cyan ring
	# Support Pylons
	_add_box(root, Vector3(0.20, 0.85, 0.60), Vector3(-0.45, 0.70, 0.0), Color("2f3542"))
	_add_box(root, Vector3(0.20, 0.85, 0.60), Vector3(0.45, 0.70, 0.0), Color("2f3542"))
	
	# Main Turbofan Nacelle (Horizontal along Z)
	var engine_y := 1.25
	_add_cylinder(root, 0.65, 1.30, Vector3(0.0, engine_y, 0.0), Color("2f3640"), Vector3(90, 0, 0))
	_add_cylinder(root, 0.68, 0.20, Vector3(0.0, engine_y, -0.60), Color("f1c40f"), Vector3(90, 0, 0)) # Gold intake lip
	_add_cylinder(root, 0.58, 0.18, Vector3(0.0, engine_y, -0.65), Color("74b9ff"), Vector3(90, 0, 0), true) # Intake fan
	# Combustor section in bronze
	_add_cylinder(root, 0.62, 0.45, Vector3(0.0, engine_y, 0.15), Color("e67e22"), Vector3(90, 0, 0))
	# Copper fuel injection conduits
	_add_cylinder(root, 0.06, 1.10, Vector3(-0.68, engine_y, 0.0), Color("d35400"), Vector3(90, 0, 0))
	_add_cylinder(root, 0.06, 1.10, Vector3(0.68, engine_y, 0.0), Color("d35400"), Vector3(90, 0, 0))
	# Conical Afterburner Nozzle
	_add_cylinder(root, 0.55, 0.35, Vector3(0.0, engine_y, 0.75), Color("1e272e"), Vector3(90, 0, 0))
	# Glowing exhaust flame core
	_add_cylinder(root, 0.42, 0.25, Vector3(0.0, engine_y, 0.85), Color("00d2d3"), Vector3(90, 0, 0), true) # Cyan plasma
	_add_sphere(root, 0.32, Vector3(0.0, engine_y, 0.98), Color("ff7675"), true) # Fiery orange center
	
	return root

## 3D Performance Alloy Wheel with low-profile tire and glowing cyan brake caliper
func build_gear_wheels() -> Node3D:
	var root := Node3D.new()
	root.name = "GearWheels"
	
	# Pedestal Base
	_add_cylinder(root, 1.0, 0.20, Vector3(0.0, 0.10, 0.0), Color("1e272e"))
	_add_cylinder(root, 0.85, 0.10, Vector3(0.0, 0.20, 0.0), Color("f1c40f"), Vector3.ZERO, true)
	
	var wheel_y := 1.15
	# Outer Rubber Tire (Upright, facing along X)
	_add_cylinder(root, 0.75, 0.40, Vector3(0.0, wheel_y, 0.0), Color("1e272e"), Vector3(0, 0, 90))
	# Tread Blocks
	for deg in range(0, 360, 30):
		var rad := deg_to_rad(float(deg))
		var px := 0.0
		var py := wheel_y + sin(rad) * 0.77
		var pz := cos(rad) * 0.77
		_add_box(root, Vector3(0.38, 0.06, 0.12), Vector3(px, py, pz), Color("2f3640"), false, Vector3(float(deg), 0, 0))
	# Bronze / Gold Alloy Rim
	_add_cylinder(root, 0.52, 0.42, Vector3(0.0, wheel_y, 0.0), Color("f39c12"), Vector3(0, 0, 90))
	# 5-Spoke Pattern
	for deg in range(0, 360, 72):
		_add_box(root, Vector3(0.44, 0.12, 0.45), Vector3(0.0, wheel_y, 0.0), Color("f5f6fa"), false, Vector3(0, 0, float(deg)))
	# Glowing Cyan 6-Piston Caliper
	_add_box(root, Vector3(0.44, 0.30, 0.22), Vector3(0.0, wheel_y + 0.35, -0.28), Color("00d2d3"), true)
	# Center Lug Nuts Hub
	_add_cylinder(root, 0.15, 0.46, Vector3(0.0, wheel_y, 0.0), Color("d2dae2"), Vector3(0, 0, 90))
	
	return root

## 3D Carbon Fiber Racing GT Wing with cyan LED wingtips
func build_gear_wings() -> Node3D:
	var root := Node3D.new()
	root.name = "GearWings"
	
	_add_cylinder(root, 1.0, 0.20, Vector3(0.0, 0.10, 0.0), Color("1e272e"))
	_add_cylinder(root, 0.85, 0.10, Vector3(0.0, 0.20, 0.0), Color("00d2d3"), Vector3.ZERO, true)
	
	# Twin swan-neck vertical mounting uprights
	_add_box(root, Vector3(0.10, 1.10, 0.20), Vector3(-0.65, 0.70, 0.0), Color("2f3542"), false, Vector3(-12, 0, 0))
	_add_box(root, Vector3(0.10, 1.10, 0.20), Vector3(0.65, 0.70, 0.0), Color("2f3542"), false, Vector3(-12, 0, 0))
	# Main Carbon Wing Airfoil
	_add_box(root, Vector3(1.95, 0.10, 0.55), Vector3(0.0, 1.25, -0.10), Color("1e272e"), false, Vector3(8, 0, 0))
	# Upper Gurney Flap
	_add_box(root, Vector3(1.95, 0.06, 0.05), Vector3(0.0, 1.32, 0.16), Color("f1c40f"))
	# Vertical Endplates with glowing cyan LED edge
	_add_box(root, Vector3(0.08, 0.42, 0.65), Vector3(-1.02, 1.25, -0.10), Color("2f3640"))
	_add_box(root, Vector3(0.08, 0.42, 0.65), Vector3(1.02, 1.25, -0.10), Color("2f3640"))
	_add_box(root, Vector3(0.10, 0.44, 0.06), Vector3(-1.02, 1.25, 0.22), Color("00d2d3"), true)
	_add_box(root, Vector3(0.10, 0.44, 0.06), Vector3(1.02, 1.25, 0.22), Color("00d2d3"), true)
	
	return root

## 3D Heavy Reinforced Steel Push-Bar Armor with tow shackles
func build_gear_armor() -> Node3D:
	var root := Node3D.new()
	root.name = "GearArmor"
	
	_add_cylinder(root, 1.0, 0.20, Vector3(0.0, 0.10, 0.0), Color("1e272e"))
	_add_cylinder(root, 0.85, 0.10, Vector3(0.0, 0.20, 0.0), Color("e74c3c"), Vector3.ZERO, true)
	
	# Heavy tubular steel push bar bumper
	var b_y := 1.10
	_add_box(root, Vector3(1.80, 0.22, 0.26), Vector3(0.0, b_y, 0.0), Color("34495e"))
	_add_box(root, Vector3(1.40, 0.18, 0.18), Vector3(0.0, b_y + 0.42, 0.0), Color("34495e"))
	# Tubular side risers
	_add_cylinder(root, 0.08, 0.48, Vector3(-0.65, b_y + 0.20, 0.0), Color("718093"))
	_add_cylinder(root, 0.08, 0.48, Vector3(0.65, b_y + 0.20, 0.0), Color("718093"))
	# Skid Plate with diamond cutouts
	_add_box(root, Vector3(1.10, 0.55, 0.08), Vector3(0.0, b_y - 0.28, -0.08), Color("95a5a6"), false, Vector3(25, 0, 0))
	# Dual Red Forged Recovery D-Rings
	_add_torus(root, 0.05, 0.14, Vector3(-0.50, b_y - 0.05, 0.16), Color("e74c3c"), Vector3(90, 0, 0))
	_add_torus(root, 0.05, 0.14, Vector3(0.50, b_y - 0.05, 0.16), Color("e74c3c"), Vector3(90, 0, 0))
	
	return root

## 3D High-Tech Dual NOS Rocket Booster Gadget
func build_gear_gadget() -> Node3D:
	var root := Node3D.new()
	root.name = "GearGadget"
	
	_add_cylinder(root, 1.0, 0.20, Vector3(0.0, 0.10, 0.0), Color("1e272e"))
	_add_cylinder(root, 0.85, 0.10, Vector3(0.0, 0.20, 0.0), Color("00d2d3"), Vector3.ZERO, true)
	
	# Twin Blue NOS Bottles
	var nos_y := 1.10
	for nx in [-0.35, 0.35]:
		_add_cylinder(root, 0.26, 1.05, Vector3(nx, nos_y, 0.0), Color("0984e3"))
		_add_sphere(root, 0.26, Vector3(nx, nos_y + 0.52, 0.0), Color("0984e3"))
		_add_cylinder(root, 0.08, 0.22, Vector3(nx, nos_y + 0.72, 0.0), Color("dfe6e9"))
		_add_cylinder(root, 0.12, 0.08, Vector3(nx, nos_y + 0.82, 0.0), Color("f1c40f")) # Brass valve
		# Carbon mounting strap
		_add_box(root, Vector3(0.60, 0.08, 0.60), Vector3(nx, nos_y, 0.0), Color("2d3436"))
	
	# Pressure Gauge with glowing cyan needle
	_add_cylinder(root, 0.16, 0.08, Vector3(0.0, nos_y + 0.40, 0.28), Color("f5f6fa"), Vector3(90, 0, 0))
	_add_box(root, Vector3(0.03, 0.12, 0.04), Vector3(0.0, nos_y + 0.42, 0.33), Color("e74c3c"), true)
	
	return root

## 3D Holographic Prismatic Skin Core
func build_gear_skin() -> Node3D:
	var root := Node3D.new()
	root.name = "GearSkin"
	
	_add_cylinder(root, 1.0, 0.20, Vector3(0.0, 0.10, 0.0), Color("1e272e"))
	_add_cylinder(root, 0.85, 0.10, Vector3(0.0, 0.20, 0.0), Color("9b59b6"), Vector3.ZERO, true)
	
	var core_y := 1.20
	# Floating Holographic Tesseract Cube with neon glow
	_add_box(root, Vector3(0.70, 0.70, 0.70), Vector3(0.0, core_y, 0.0), Color("a55eea"), true, Vector3(25, 45, 15))
	_add_sphere(root, 0.32, Vector3(0.0, core_y, 0.0), Color("00d2d3"), true)
	# Floating Orbital Cyber Rings
	_add_torus(root, 0.04, 0.62, Vector3(0.0, core_y, 0.0), Color("f1c40f"), Vector3(45, 0, 0))
	_add_torus(root, 0.04, 0.72, Vector3(0.0, core_y, 0.0), Color("00d2d3"), Vector3(0, 45, 45))
	
	return root

## Builds detailed multi-part 3D blocky visuals for any of the 4 Police Units
func build_police_car_visuals(police_type: int) -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelPoliceModel_%d" % police_type
	
	match police_type:
		1: # INTERCEPTOR_MUSCLE
			_add_common_chassis(root)
			_add_flared_wheel_wells(root, 0.66, 0.82, Color("192a56"))
			_add_wheels(root, 0.30, 0.22, 0.66, 0.82)
			_add_box(root, Vector3(1.26, 0.34, 2.30), Vector3(0.0, 0.24, 0.0), Color("192a56"))
			_add_box(root, Vector3(0.98, 0.32, 1.08), Vector3(0.0, 0.54, 0.06), Color("0a0a0a"))
			_add_box(root, Vector3(1.30, 0.08, 0.24), Vector3(0.0, 0.06, -1.22), Color("ffffff"))
			_add_box(root, Vector3(0.34, 0.10, 0.42), Vector3(0.0, 0.44, -0.65), Color("ffffff"))
			_add_box(root, Vector3(0.42, 0.08, 0.08), Vector3(-0.24, 0.66, -0.38), Color("ff0000"), true)
			_add_box(root, Vector3(0.42, 0.08, 0.08), Vector3(0.24, 0.66, -0.38), Color("00a8ff"), true)
			_add_box(root, Vector3(1.24, 0.06, 0.24), Vector3(0.0, 0.58, 1.05), Color("192a56"))
			
		2: # SWAT_VAN
			_add_wheels(root, 0.34, 0.24, 0.70, 0.85)
			_add_box(root, Vector3(1.36, 0.86, 2.48), Vector3(0.0, 0.52, 0.0), Color("273c75"))
			_add_box(root, Vector3(1.10, 0.22, 0.08), Vector3(0.0, 0.68, -1.26), Color("0a0a0a"))
			_add_box(root, Vector3(0.12, 0.08, 1.80), Vector3(-0.74, 0.12, 0.0), Color("1e272e"))
			_add_box(root, Vector3(0.12, 0.08, 1.80), Vector3(0.74, 0.12, 0.0), Color("1e272e"))
			_add_box(root, Vector3(1.44, 0.48, 0.24), Vector3(0.0, 0.24, -1.34), Color("718093"), false, Vector3(-14, 0, 0))
			_add_cylinder(root, 0.26, 0.08, Vector3(0.0, 0.98, 0.20), Color("1e272e"))
			_add_box(root, Vector3(0.24, 0.14, 0.14), Vector3(-0.35, 1.02, -0.80), Color("ff0000"), true)
			_add_box(root, Vector3(0.24, 0.14, 0.14), Vector3(0.35, 1.02, -0.80), Color("00a8ff"), true)
			
		3: # RHINO_TANK
			_add_box(root, Vector3(1.65, 0.52, 2.60), Vector3(0.0, 0.32, 0.0), Color("4b6584"))
			_add_box(root, Vector3(0.30, 0.42, 2.70), Vector3(-0.80, 0.21, 0.0), Color("2f3640"))
			_add_box(root, Vector3(0.30, 0.42, 2.70), Vector3(0.80, 0.21, 0.0), Color("2f3640"))
			for side in [-0.96, 0.96]:
				for wz in [-1.0, -0.6, -0.2, 0.2, 0.6, 1.0]:
					_add_cylinder(root, 0.16, 0.06, Vector3(side, 0.18, wz), Color("718093"), Vector3(0, 0, 90))
			
			var turret_pivot := Node3D.new()
			turret_pivot.name = "TurretPivot"
			turret_pivot.position = Vector3(0.0, 0.60, 0.0)
			_add_box(turret_pivot, Vector3(1.05, 0.42, 1.15), Vector3(0.0, 0.21, 0.0), Color("353b48"))
			_add_box(turret_pivot, Vector3(0.18, 0.18, 2.10), Vector3(0.0, 0.21, -1.25), Color("718093"))
			_add_cylinder(turret_pivot, 0.14, 0.22, Vector3(0.0, 0.21, -2.32), Color("2f3640"), Vector3(90, 0, 0))
			_add_box(turret_pivot, Vector3(0.12, 0.10, 0.10), Vector3(-0.35, 0.46, 0.0), Color("ff0000"), true)
			_add_box(turret_pivot, Vector3(0.12, 0.10, 0.10), Vector3(0.35, 0.46, 0.0), Color("00a8ff"), true)
			root.add_child(turret_pivot)
			
		_: # 0: PATROL_CRUISER
			_add_common_chassis(root)
			_add_flared_wheel_wells(root, 0.60, 0.75, Color("1e272e"))
			_add_wheels(root, 0.28, 0.18, 0.60, 0.75)
			_add_box(root, Vector3(1.18, 0.36, 0.75), Vector3(0.0, 0.24, -0.74), Color("1e272e"))
			_add_box(root, Vector3(1.18, 0.36, 0.85), Vector3(0.0, 0.24, 0.05), Color("f5f6fa"))
			_add_box(root, Vector3(1.18, 0.36, 0.64), Vector3(0.0, 0.24, 0.80), Color("1e272e"))
			_add_box(root, Vector3(0.98, 0.34, 1.05), Vector3(0.0, 0.56, 0.08), Color("f5f6fa"))
			_add_box(root, Vector3(1.00, 0.26, 0.88), Vector3(0.0, 0.56, 0.08), Color("1b9cfc"))
			_add_box(root, Vector3(0.10, 0.42, 0.10), Vector3(-0.34, 0.24, -1.24), Color("2f3640"))
			_add_box(root, Vector3(0.10, 0.42, 0.10), Vector3(0.34, 0.24, -1.24), Color("2f3640"))
			_add_box(root, Vector3(0.96, 0.12, 0.10), Vector3(0.0, 0.32, -1.24), Color("2f3640"))
			_add_box(root, Vector3(0.24, 0.12, 0.16), Vector3(0.0, 0.78, 0.08), Color("f5f6fa"))
			_add_box(root, Vector3(0.30, 0.12, 0.16), Vector3(-0.28, 0.78, 0.08), Color("ff0000"), true)
			_add_box(root, Vector3(0.30, 0.12, 0.16), Vector3(0.28, 0.78, 0.08), Color("00a8ff"), true)
			_add_cylinder(root, 0.015, 0.65, Vector3(-0.42, 0.65, 1.0), Color("1e272e"))
	
	return root

## Builds detailed 3D models for 6 Civilian NPC Road Traffic Vehicles:
## 0: YELLOW_TAXI, 1: CITY_BUS, 2: PIZZA_DELIVERY_VAN, 3: DUMP_TRUCK, 4: AMBULANCE_VAN, 5: FUEL_TANKER_SEMI
func build_npc_traffic_visuals(npc_type: int) -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelNPCTraffic_%d" % npc_type
	
	match npc_type:
		1: # CITY_BUS (long 3.8m blue-and-white transit bus, 6 wheels, 5 window bays)
			_add_wheels(root, 0.32, 0.20, 0.66, 1.20)
			# Mid axle wheels
			for mx in [-0.66, 0.66]:
				var w_mid := Node3D.new()
				w_mid.position = Vector3(mx, 0.02, 0.50)
				_add_cylinder(w_mid, 0.32, 0.20, Vector3.ZERO, Color("1e272e"), Vector3(0, 0, 90))
				_add_box(w_mid, Vector3(0.22, 0.24, 0.24), Vector3.ZERO, Color("d2dae2"))
				root.add_child(w_mid)
			
			# Lower blue body + upper white body
			_add_box(root, Vector3(1.30, 0.44, 3.80), Vector3(0.0, 0.28, 0.0), Color("0984e3"))
			_add_box(root, Vector3(1.28, 0.52, 3.76), Vector3(0.0, 0.76, 0.0), Color("f5f6fa"))
			# 5 Passenger window bays on each side (dark tinted glass)
			for wz in range(-4, 5, 2):
				var z_pos: float = wz * 0.38
				_add_box(root, Vector3(0.04, 0.34, 0.32), Vector3(-0.65, 0.76, z_pos), Color("0a0a0a"))
				_add_box(root, Vector3(0.04, 0.34, 0.32), Vector3(0.65, 0.76, z_pos), Color("0a0a0a"))
			# Front windshield & orange LED destination board
			_add_box(root, Vector3(1.16, 0.38, 0.06), Vector3(0.0, 0.76, -1.89), Color("1b9cfc"))
			_add_box(root, Vector3(0.85, 0.12, 0.04), Vector3(0.0, 0.98, -1.90), Color("f39c12"), true)
			# Roof AC pods
			_add_box(root, Vector3(0.70, 0.14, 0.95), Vector3(0.0, 1.08, -0.40), Color("d2dae2"))
			_add_box(root, Vector3(0.70, 0.14, 0.95), Vector3(0.0, 1.08, 0.80), Color("d2dae2"))
			# Headlights & Taillights
			_add_box(root, Vector3(0.20, 0.14, 0.06), Vector3(-0.45, 0.24, -1.91), Color("fff200"), true)
			_add_box(root, Vector3(0.20, 0.14, 0.06), Vector3(0.45, 0.24, -1.91), Color("fff200"), true)
			_add_box(root, Vector3(0.20, 0.14, 0.06), Vector3(-0.45, 0.24, 1.91), Color("ff3f34"), true)
			_add_box(root, Vector3(0.20, 0.14, 0.06), Vector3(0.45, 0.24, 1.91), Color("ff3f34"), true)
			
		2: # PIZZA_DELIVERY_VAN (compact white kei-van with red/green Italian stripe + 3D roof pizza slice)
			_add_common_chassis(root)
			_add_wheels(root, 0.26, 0.16, 0.58, 0.70)
			# White van body
			_add_box(root, Vector3(1.14, 0.54, 2.05), Vector3(0.0, 0.34, 0.0), Color("f5f6fa"))
			# Red & green Italian center stripe
			_add_box(root, Vector3(0.12, 0.55, 2.06), Vector3(-0.08, 0.34, 0.0), Color("e84118"))
			_add_box(root, Vector3(0.12, 0.55, 2.06), Vector3(0.08, 0.34, 0.0), Color("44bd32"))
			# Cabin windshield
			_add_box(root, Vector3(0.96, 0.32, 0.65), Vector3(0.0, 0.58, -0.65), Color("1b9cfc"))
			# Giant 3D Pepperoni Pizza Slice on roof rack
			_add_box(root, Vector3(0.85, 0.06, 0.85), Vector3(0.0, 0.65, 0.15), Color("2f3640")) # Rack
			# Crust base (tapered wedge)
			_add_box(root, Vector3(0.72, 0.12, 0.90), Vector3(0.0, 0.74, 0.15), Color("f39c12"))
			_add_box(root, Vector3(0.64, 0.08, 0.82), Vector3(0.0, 0.82, 0.15), Color("f5cd79")) # Melted cheese
			_add_cylinder(root, 0.09, 0.04, Vector3(-0.16, 0.88, 0.0), Color("c0392b")) # Pepperoni 1
			_add_cylinder(root, 0.09, 0.04, Vector3(0.16, 0.88, 0.10), Color("c0392b"))  # Pepperoni 2
			_add_cylinder(root, 0.09, 0.04, Vector3(0.0, 0.88, 0.35), Color("c0392b"))   # Pepperoni 3
			
		3: # DUMP_TRUCK (orange heavy cab with chrome vertical exhausts and gravel bed)
			_add_wheels(root, 0.36, 0.24, 0.72, 0.90)
			# Heavy cab in safety orange
			_add_box(root, Vector3(1.30, 0.72, 1.10), Vector3(0.0, 0.50, -0.65), Color("e67e22"))
			_add_box(root, Vector3(1.10, 0.34, 0.10), Vector3(0.0, 0.64, -1.21), Color("1b9cfc"))
			# Heavy chrome bumper & front grille
			_add_box(root, Vector3(1.36, 0.24, 0.16), Vector3(0.0, 0.14, -1.24), Color("d2dae2"))
			# Vertical chrome stacks
			_add_cylinder(root, 0.06, 0.85, Vector3(-0.62, 0.75, -0.05), Color("d2dae2"))
			_add_cylinder(root, 0.06, 0.85, Vector3(0.62, 0.75, -0.05), Color("d2dae2"))
			# Ribbed steel dump bed in dark slate
			_add_box(root, Vector3(1.34, 0.62, 1.65), Vector3(0.0, 0.45, 0.72), Color("353b48"))
			# Bed filled with gray gravel blocks
			_add_box(root, Vector3(1.18, 0.22, 1.45), Vector3(0.0, 0.68, 0.72), Color("7f8c8d"))
			_add_box(root, Vector3(0.42, 0.14, 0.42), Vector3(0.15, 0.82, 0.65), Color("95a5a6"))
			_add_box(root, Vector3(0.38, 0.12, 0.38), Vector3(-0.20, 0.80, 0.85), Color("bdc3c7"))
			
		4: # AMBULANCE_VAN (white emergency van with red cross emblem blocks & flashing lightbar)
			_add_common_chassis(root)
			_add_wheels(root, 0.30, 0.20, 0.64, 0.82)
			# White van body
			_add_box(root, Vector3(1.28, 0.72, 2.45), Vector3(0.0, 0.46, 0.0), Color("ffffff"))
			_add_box(root, Vector3(1.08, 0.32, 0.10), Vector3(0.0, 0.62, -1.24), Color("1b9cfc"))
			# Red Cross Emblems on left and right side walls
			for sx in [-0.65, 0.65]:
				_add_box(root, Vector3(0.02, 0.36, 0.12), Vector3(sx, 0.54, 0.35), Color("ff3f34"))
				_add_box(root, Vector3(0.02, 0.12, 0.36), Vector3(sx, 0.54, 0.35), Color("ff3f34"))
			# Red cross on roof
			_add_box(root, Vector3(0.42, 0.02, 0.14), Vector3(0.0, 0.83, 0.30), Color("ff3f34"))
			_add_box(root, Vector3(0.14, 0.02, 0.42), Vector3(0.0, 0.83, 0.30), Color("ff3f34"))
			# Roof lightbar (flashing red and white)
			_add_box(root, Vector3(0.32, 0.12, 0.16), Vector3(-0.25, 0.88, -0.65), Color("ff0000"), true)
			_add_box(root, Vector3(0.32, 0.12, 0.16), Vector3(0.25, 0.88, -0.65), Color("ffffff"), true)
			
		5: # FUEL_TANKER_SEMI (4.2m heavy truck with long cylindrical fuel tank trailer)
			_add_wheels(root, 0.34, 0.22, 0.70, 1.45)
			# Mid axle duals
			for mx in [-0.70, 0.70]:
				var w_tm := Node3D.new()
				w_tm.position = Vector3(mx, 0.04, 0.85)
				_add_cylinder(w_tm, 0.34, 0.22, Vector3.ZERO, Color("1e272e"), Vector3(0, 0, 90))
				root.add_child(w_tm)
			# Heavy cab in dark red
			_add_box(root, Vector3(1.30, 0.74, 1.05), Vector3(0.0, 0.50, -1.25), Color("c0392b"))
			_add_box(root, Vector3(1.08, 0.34, 0.10), Vector3(0.0, 0.65, -1.78), Color("1b9cfc"))
			# Long silver cylindrical fuel tank trailer
			_add_cylinder(root, 0.60, 2.55, Vector3(0.0, 0.65, 0.45), Color("d2dae2"), Vector3(90, 0, 0))
			# Red hazard stripe bands around cylinder
			_add_cylinder(root, 0.62, 0.16, Vector3(0.0, 0.65, -0.45), Color("ff3f34"), Vector3(90, 0, 0))
			_add_cylinder(root, 0.62, 0.16, Vector3(0.0, 0.65, 1.35), Color("ff3f34"), Vector3(90, 0, 0))
			# Top pipe valves & catwalk
			_add_box(root, Vector3(0.34, 0.06, 2.20), Vector3(0.0, 1.28, 0.45), Color("718093"))
			_add_cylinder(root, 0.12, 0.14, Vector3(0.0, 1.38, 0.15), Color("f1c40f"))
			_add_cylinder(root, 0.12, 0.14, Vector3(0.0, 1.38, 0.85), Color("f1c40f"))
			
		_: # 0: YELLOW_TAXI (bright yellow sedan with checkered side strip & TAXI roof sign)
			_add_common_chassis(root)
			_add_flared_wheel_wells(root, 0.60, 0.75, Color("f1c40f"))
			_add_wheels(root, 0.28, 0.18, 0.60, 0.75)
			# Bright yellow body
			_add_box(root, Vector3(1.18, 0.36, 2.24), Vector3(0.0, 0.24, 0.0), Color("f1c40f"))
			# Checkered black-and-white side stripe
			for cz in range(-4, 5):
				var z_sq: float = cz * 0.22
				var col: Color = Color("1e272e") if (cz % 2 == 0) else Color("ffffff")
				_add_box(root, Vector3(0.04, 0.08, 0.18), Vector3(-0.60, 0.26, z_sq), col)
				_add_box(root, Vector3(0.04, 0.08, 0.18), Vector3(0.60, 0.26, z_sq), col)
			# Cabin with dark glass
			_add_box(root, Vector3(0.98, 0.34, 1.05), Vector3(0.0, 0.56, 0.08), Color("1e272e"))
			_add_box(root, Vector3(1.00, 0.26, 0.88), Vector3(0.0, 0.56, 0.08), Color("1b9cfc"))
			# Glowing white/amber "TAXI" roof sign box
			_add_box(root, Vector3(0.38, 0.14, 0.22), Vector3(0.0, 0.80, 0.08), Color("fff200"), true)
	
	return root

## Builds detailed architectural city building with stepped foundation, awnings, window columns, fire escapes, and roof props
func build_detailed_building(width: float, depth: float, height: float, primary_color: Color, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelBuilding"
	
	var lobby_height: float = 3.2
	var tower_height: float = maxf(1.0, height - lobby_height)
	
	# 1. Stepped Stone Foundation Plinth & Ground-Floor Lobby Base
	var lobby_color := Color("2f3640")
	_add_box(root, Vector3(width + 0.30, 0.40, depth + 0.30), Vector3(0.0, 0.20, 0.0), Color("1e272e")) # Plinth
	_add_box(root, Vector3(width, lobby_height, depth), Vector3(0.0, lobby_height * 0.5, 0.0), lobby_color)
	
	# Street-facing shop awning (front Z = -depth * 0.5)
	var awning_color: Color = Color("e84118") if rng.randf() > 0.5 else Color("0097e6")
	_add_box(root, Vector3(width * 0.75, 0.18, 1.25), Vector3(0.0, 2.7, -depth * 0.5 - 0.5), awning_color, false, Vector3(10, 0, 0))
	
	# Glowing glass double-doors
	_add_box(root, Vector3(1.6, 2.1, 0.12), Vector3(0.0, 1.1, -depth * 0.5 - 0.04), Color("ffeaa7"), true)
	
	# 2. Main Facade Tower
	var tower_y: float = lobby_height + tower_height * 0.5
	_add_box(root, Vector3(width * 0.96, tower_height, depth * 0.96), Vector3(0.0, tower_y, 0.0), primary_color)
	
	# Vertical Brick Pilasters on Facade
	var pilaster_col := Color("1e272e")
	for px in [-width * 0.46, -width * 0.15, width * 0.15, width * 0.46]:
		_add_box(root, Vector3(0.35, tower_height, 0.14), Vector3(px, tower_y, -depth * 0.48 - 0.05), pilaster_col)
	
	# Recessed window rows spaced every 3.2m vertically
	var win_color_warm := Color("fed330")
	var win_color_dark := Color("192a56")
	var cur_y: float = lobby_height + 1.8
	var window_spacing: float = 3.2
	
	while cur_y < height - 1.2:
		var is_lit: bool = (rng.randf() > 0.35)
		var w_col: Color = win_color_warm if is_lit else win_color_dark
		
		# Front & Rear wall window bands
		_add_box(root, Vector3(width * 0.72, 1.15, 0.08), Vector3(0.0, cur_y, -depth * 0.48 - 0.02), w_col, is_lit)
		_add_box(root, Vector3(width * 0.72, 1.15, 0.08), Vector3(0.0, cur_y, depth * 0.48 + 0.02), w_col, is_lit)
		
		# Side wall window bands
		if width > 6.0:
			_add_box(root, Vector3(0.08, 1.15, depth * 0.65), Vector3(-width * 0.48 - 0.02, cur_y, 0.0), w_col, is_lit)
			_add_box(root, Vector3(0.08, 1.15, depth * 0.65), Vector3(width * 0.48 + 0.02, cur_y, 0.0), w_col, is_lit)
		
		# Window AC Units on select windows
		if rng.randf() > 0.65:
			_add_box(root, Vector3(0.65, 0.45, 0.45), Vector3(width * 0.22, cur_y - 0.30, -depth * 0.48 - 0.22), Color("718093"))
		
		cur_y += window_spacing
	
	# External Black Metal Fire Escape on Side Wall (zig-zag stairs)
	if height >= 14.0:
		var fe_x: float = width * 0.48 + 0.25
		var fe_y: float = lobby_height + 2.0
		while fe_y < height - 2.5:
			_add_box(root, Vector3(0.50, 0.08, 1.60), Vector3(fe_x, fe_y, 0.0), Color("1e272e")) # Platform
			_add_box(root, Vector3(0.08, 0.65, 1.60), Vector3(fe_x + 0.22, fe_y + 0.32, 0.0), Color("1e272e")) # Railing
			fe_y += 3.2
	
	# 3. Roof Cornice Trim Ledge & Parapet Wall
	_add_box(root, Vector3(width + 0.40, 0.45, depth + 0.40), Vector3(0.0, height + 0.22, 0.0), Color("d2dae2"))
	_add_box(root, Vector3(width + 0.20, 0.60, 0.15), Vector3(0.0, height + 0.50, -depth * 0.5), Color("2f3640")) # Parapet
	_add_box(root, Vector3(width + 0.20, 0.60, 0.15), Vector3(0.0, height + 0.50, depth * 0.5), Color("2f3640"))
	
	# 4. Procedural Rooftop Details (Helipad, Water Tower, or HVAC with Blinking Radio Antenna)
	var roll: float = rng.randf()
	if height >= 18.0 and roll > 0.4:
		# Helipad on tall towers
		_add_box(root, Vector3(6.2, 0.12, 6.2), Vector3(0.0, height + 0.48, 0.0), Color("353b48"))
		_add_box(root, Vector3(0.6, 0.14, 3.6), Vector3(-1.2, height + 0.50, 0.0), Color("f1c40f"), true)
		_add_box(root, Vector3(0.6, 0.14, 3.6), Vector3(1.2, height + 0.50, 0.0), Color("f1c40f"), true)
		_add_box(root, Vector3(2.4, 0.14, 0.6), Vector3(0.0, height + 0.50, 0.0), Color("f1c40f"), true)
	elif roll > 0.6 and height < 26.0:
		# Cylindrical wooden water tower on 4 stilts
		_add_cylinder(root, 1.15, 1.95, Vector3(0.0, height + 1.85, 0.0), Color("b33939"))
		_add_cylinder(root, 1.25, 0.14, Vector3(0.0, height + 2.85, 0.0), Color("474787"))
		for sx in [-0.65, 0.65]:
			for sz in [-0.65, 0.65]:
				_add_box(root, Vector3(0.12, 1.2, 0.12), Vector3(sx, height + 0.8, sz), Color("2c2c54"))
	else:
		# Gray HVAC units
		_add_box(root, Vector3(1.8, 1.1, 1.3), Vector3(-width * 0.2, height + 0.8, 0.0), Color("718093"))
		_add_cylinder(root, 0.42, 0.14, Vector3(-width * 0.2, height + 1.38, 0.0), Color("1e272e"))
	
	# Blinking Red Rooftop Radio Antenna
	_add_cylinder(root, 0.04, 3.2, Vector3(width * 0.35, height + 1.6, depth * 0.35), Color("718093"))
	_add_cylinder(root, 0.12, 0.18, Vector3(width * 0.35, height + 3.2, depth * 0.35), Color("ff0000"), Vector3.ZERO, true)
	
	return root

## Builds Biome-Specific Landmark Buildings:
## DOWNTOWN_METRO (0: Grand Bank, 1: Donut Shop)
## NEON_CHINATOWN (0: Pagoda Temple, 1: Cyber Arcade/Ramen)
## DESERT_CANYON_ROUTE66 (0: Retro Gas Station, 1: Railroad Crossing)
## CARGO_HARBOR_DOCKS (0: Shipping Containers & Gantry Crane)
func build_biome_landmark(biome: int, landmark_type: int, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "BiomeLandmark_B%d_T%d" % [biome, landmark_type]
	
	match biome:
		1: # NEON_CHINATOWN
			if landmark_type == 0:
				# "PAGODA TEMPLE TOWER" (3-tiered crimson-and-gold curved eaves roof)
				_add_box(root, Vector3(14.0, 0.8, 14.0), Vector3(0.0, 0.4, 0.0), Color("2f3640")) # Stone base
				# 4 Red entrance pillars
				for px in [-4.5, 4.5]:
					for pz in [-4.5, 4.5]:
						_add_cylinder(root, 0.35, 4.2, Vector3(px, 2.5, pz), Color("c0392b"))
				_add_box(root, Vector3(9.5, 3.8, 9.5), Vector3(0.0, 2.3, 0.0), Color("c0392b")) # Core 1
				_add_box(root, Vector3(14.5, 0.4, 14.5), Vector3(0.0, 4.4, 0.0), Color("f1c40f")) # Eaves Tier 1
				_add_box(root, Vector3(7.5, 3.2, 7.5), Vector3(0.0, 6.2, 0.0), Color("c0392b")) # Core 2
				_add_box(root, Vector3(11.5, 0.4, 11.5), Vector3(0.0, 8.0, 0.0), Color("f1c40f")) # Eaves Tier 2
				_add_box(root, Vector3(5.5, 2.8, 5.5), Vector3(0.0, 9.6, 0.0), Color("c0392b")) # Core 3
				_add_box(root, Vector3(8.5, 0.4, 8.5), Vector3(0.0, 11.2, 0.0), Color("f1c40f")) # Eaves Tier 3
				# Gold finial spire on top
				_add_cylinder(root, 0.18, 2.8, Vector3(0.0, 12.8, 0.0), Color("f1c40f"), Vector3.ZERO, true)
				# Glowing red lanterns
				for lx in [-5.5, 5.5]:
					_add_cylinder(root, 0.28, 0.42, Vector3(lx, 3.8, -5.5), Color("ff0000"), Vector3.ZERO, true)
				# Solid pagoda colliders (Layer 4: 8)
				_add_building_collider(root, Vector3(14.0, 0.8, 14.0), Vector3(0.0, 0.4, 0.0))
				_add_building_collider(root, Vector3(9.5, 9.6, 9.5), Vector3(0.0, 5.2, 0.0))
			else:
				# "CYBER ARCADE & RAMEN HOUSE"
				_add_box(root, Vector3(12.0, 6.5, 12.0), Vector3(0.0, 3.25, 0.0), Color("130f40"))
				# Protruding vertical neon signs
				_add_box(root, Vector3(0.12, 3.8, 0.9), Vector3(-6.08, 4.2, -2.5), Color("00ffff"), true)
				_add_box(root, Vector3(0.12, 3.8, 0.9), Vector3(6.08, 4.2, 2.5), Color("ff007f"), true)
				_add_box(root, Vector3(0.9, 3.8, 0.12), Vector3(0.0, 4.2, -6.08), Color("f1c40f"), true)
				# Giant 3D Voxel Ramen Bowl on Roof
				_add_cylinder(root, 2.2, 1.2, Vector3(0.0, 7.2, 0.0), Color("e74c3c"))
				_add_cylinder(root, 2.0, 0.1, Vector3(0.0, 7.7, 0.0), Color("f5cd79")) # Broth
				_add_cylinder(root, 0.08, 2.8, Vector3(0.4, 8.4, 0.0), Color("e17055"), Vector3(0, 0, 35)) # Chopsticks
				# Solid arcade building collider (Layer 4: 8)
				_add_building_collider(root, Vector3(12.0, 6.5, 12.0), Vector3(0.0, 3.25, 0.0))
				
		2: # DESERT_CANYON_ROUTE66
			if landmark_type == 0:
				# "RETRO GAS STATION" (Canopy + 4 explosive fuel pumps)
				# Main station store
				_add_box(root, Vector3(10.0, 4.0, 8.0), Vector3(0.0, 2.0, 4.0), Color("d2dae2"))
				_add_box(root, Vector3(9.6, 0.4, 0.12), Vector3(0.0, 3.6, -0.06), Color("c0392b"))
				# Large fuel canopy
				_add_box(root, Vector3(12.0, 0.5, 7.0), Vector3(0.0, 4.2, -4.5), Color("c0392b"))
				_add_box(root, Vector3(11.6, 0.1, 6.6), Vector3(0.0, 3.9, -4.5), Color("f5f6fa"))
				for px in [-4.8, 4.8]:
					_add_cylinder(root, 0.22, 4.0, Vector3(px, 2.0, -4.5), Color("d2dae2"))
				# Solid station store & canopy colliders (Layer 4: 8)
				_add_building_collider(root, Vector3(10.0, 4.0, 8.0), Vector3(0.0, 2.0, 4.0))
				_add_building_collider(root, Vector3(0.5, 4.0, 0.5), Vector3(-4.8, 2.0, -4.5))
				_add_building_collider(root, Vector3(0.5, 4.0, 0.5), Vector3(4.8, 2.0, -4.5))
				# 4 Red Explosive Fuel Pumps
				for px in [-3.2, -1.1, 1.1, 3.2]:
					var pump := Node3D.new()
					pump.name = "FuelPump"
					pump.position = Vector3(px, 0.75, -4.5)
					_add_box(pump, Vector3(0.65, 1.5, 0.65), Vector3.ZERO, Color("e84118"))
					_add_box(pump, Vector3(0.55, 0.35, 0.67), Vector3(0.0, 0.35, 0.0), Color("f5f6fa")) # Meter
					root.add_child(pump)
			else:
				# "RAILROAD CROSSING & FREIGHT TRAIN"
				# Wooden ties & rails
				for rz in range(-18, 19, 3):
					_add_box(root, Vector3(5.5, 0.14, 0.65), Vector3(0.0, 0.07, float(rz)), Color("4b4b4b"))
				_add_box(root, Vector3(0.12, 0.22, 38.0), Vector3(-1.8, 0.18, 0.0), Color("718093"))
				_add_box(root, Vector3(0.12, 0.22, 38.0), Vector3(1.8, 0.18, 0.0), Color("718093"))
				# Flashing crossing gates
				for cx in [-3.0, 3.0]:
					_add_cylinder(root, 0.12, 3.2, Vector3(cx, 1.6, 0.0), Color("2f3640"))
					_add_box(root, Vector3(0.35, 0.25, 0.25), Vector3(cx, 2.9, 0.0), Color("1e272e"))
					_add_cylinder(root, 0.12, 0.10, Vector3(cx, 2.9, -0.16), Color("ff0000"), Vector3(90, 0, 0), true)
					_add_cylinder(root, 0.12, 0.10, Vector3(cx, 2.9, 0.16), Color("ff0000"), Vector3(90, 0, 0), true)
					_add_building_collider(root, Vector3(0.4, 3.2, 0.4), Vector3(cx, 1.6, 0.0))
				# 3D Blocky Locomotive
				var train := Node3D.new()
				train.name = "FreightTrain"
				train.position = Vector3(0.0, 0.9, -6.0)
				_add_box(train, Vector3(2.6, 1.8, 6.2), Vector3.ZERO, Color("2c3e50")) # Engine body
				_add_box(train, Vector3(2.4, 2.2, 2.4), Vector3(0.0, 0.2, 1.6), Color("e74c3c")) # Cab
				_add_cylinder(train, 0.32, 0.85, Vector3(0.0, 1.2, -1.8), Color("1e272e")) # Smokestack
				_add_cylinder(train, 0.24, 0.18, Vector3(0.0, 0.4, -3.12), Color("fff200"), Vector3(90, 0, 0), true) # Headlight
				# Solid stationary train collider
				_add_building_collider(train, Vector3(2.6, 2.2, 6.2), Vector3.ZERO)
				root.add_child(train)
				
		3: # CARGO_HARBOR_DOCKS
			# "SHIPPING CONTAINER STACKS & GANTRY CRANE"
			var colors := [Color("e74c3c"), Color("2980b9"), Color("e67e22"), Color("27ae60")]
			# Stacked containers (3 levels high forming warehouse container stacks)
			var c_idx := 0
			for sy in [0.75, 2.25, 3.75]:
				for sx in [-4.0, 4.0]:
					var col: Color = colors[c_idx % colors.size()]
					c_idx += 1
					_add_box(root, Vector3(2.4, 1.45, 6.2), Vector3(sx, sy, 0.0), col)
					# Corrugated rib ridges
					for rz in range(-2, 3):
						_add_box(root, Vector3(2.44, 1.45, 0.12), Vector3(sx, sy, float(rz) * 1.1), Color("1e272e"))
			# Solid container warehouse stacks
			_add_building_collider(root, Vector3(2.6, 4.5, 6.4), Vector3(-4.0, 2.25, 0.0))
			_add_building_collider(root, Vector3(2.6, 4.5, 6.4), Vector3(4.0, 2.25, 0.0))
			# Towering Yellow 3D Steel Harbor Gantry Crane
			_add_box(root, Vector3(0.45, 8.5, 0.45), Vector3(-6.2, 4.25, -2.5), Color("f1c40f"))
			_add_box(root, Vector3(0.45, 8.5, 0.45), Vector3(-6.2, 4.25, 2.5), Color("f1c40f"))
			_add_box(root, Vector3(0.45, 8.5, 0.45), Vector3(6.2, 4.25, -2.5), Color("f1c40f"))
			_add_box(root, Vector3(0.45, 8.5, 0.45), Vector3(6.2, 4.25, 2.5), Color("f1c40f"))
			# Solid gantry crane 4 support legs
			_add_building_collider(root, Vector3(0.5, 8.5, 0.5), Vector3(-6.2, 4.25, -2.5))
			_add_building_collider(root, Vector3(0.5, 8.5, 0.5), Vector3(-6.2, 4.25, 2.5))
			_add_building_collider(root, Vector3(0.5, 8.5, 0.5), Vector3(6.2, 4.25, -2.5))
			_add_building_collider(root, Vector3(0.5, 8.5, 0.5), Vector3(6.2, 4.25, 2.5))
			# Top horizontal gantry boom
			_add_box(root, Vector3(14.2, 0.75, 1.2), Vector3(0.0, 8.8, 0.0), Color("f1c40f"))
			# Operator cabin & hoist winch
			_add_box(root, Vector3(1.6, 1.2, 1.4), Vector3(0.0, 7.8, 0.0), Color("e67e22"))
			
		4: # FARMLAND_COUNTRYSIDE
			if landmark_type == 0:
				return build_red_barn_and_silo(rng)
			else:
				return build_country_windmill(rng)
			
		0, _: # DOWNTOWN_METRO
			if landmark_type == 0:
				# "GRAND PILLARED BANK"
				_add_box(root, Vector3(16.0, 0.6, 16.0), Vector3(0.0, 0.3, 0.0), Color("d2dae2")) # Steps
				_add_box(root, Vector3(14.0, 5.5, 14.0), Vector3(0.0, 3.2, 0.0), Color("f5f6fa")) # Main Hall
				# 4 White Cylindrical Neo-Classical Columns
				for px in [-4.5, -1.5, 1.5, 4.5]:
					_add_cylinder(root, 0.42, 5.4, Vector3(px, 3.2, -7.2), Color("ffffff"))
				# Triangular pediment roof
				_add_box(root, Vector3(14.5, 0.6, 15.0), Vector3(0.0, 6.2, -0.2), Color("d2dae2"))
				_add_box(root, Vector3(11.0, 1.4, 0.4), Vector3(0.0, 7.0, -7.4), Color("f1c40f"), true) # Gold frieze
				# Heavy Gold Vault Doors
				_add_box(root, Vector3(2.4, 3.2, 0.22), Vector3(0.0, 2.2, -7.05), Color("f1c40f"), true)
				# Solid Bank Hall & Columns Collider (Layer 4: 8)
				_add_building_collider(root, Vector3(14.0, 5.5, 14.0), Vector3(0.0, 3.2, 0.0))
				_add_building_collider(root, Vector3(12.0, 5.4, 1.2), Vector3(0.0, 3.2, -7.2))
			else:
				# "GIANT DONUT SHOP" (Drive-thru retro diner with 3.5m spinning pink TorusMesh Donut)
				_add_box(root, Vector3(12.0, 3.8, 10.0), Vector3(0.0, 1.9, 0.0), Color("dfe6e9"))
				_add_box(root, Vector3(12.4, 0.35, 10.4), Vector3(0.0, 3.9, 0.0), Color("e84118")) # Roof rim
				_add_box(root, Vector3(9.5, 1.6, 0.12), Vector3(0.0, 2.2, -5.04), Color("00d2d3"), true) # Glass
				# Center roof pole
				_add_cylinder(root, 0.16, 2.2, Vector3(0.0, 5.0, 0.0), Color("718093"))
				# Solid Donut Shop diner building collider (Layer 4: 8)
				_add_building_collider(root, Vector3(12.0, 3.8, 10.0), Vector3(0.0, 1.9, 0.0))
				# Giant 3.5m Pink-Frosted 3D TorusMesh Donut
				var donut_pivot := Node3D.new()
				donut_pivot.name = "DonutPivot"
				donut_pivot.position = Vector3(0.0, 6.8, 0.0)
				_add_torus(donut_pivot, 0.85, 1.75, Vector3.ZERO, Color("ff9ff3"), Vector3(75, 0, 0)) # Dough / frosting
				# Colorful sprinkle blocks
				var sprinkle_colors := [Color("e84118"), Color("0984e3"), Color("f1c40f"), Color("2ecc71")]
				for sp_i in range(8):
					var angle: float = sp_i * (PI / 4.0)
					var sp_pos := Vector3(cos(angle) * 1.3, sin(angle) * 0.3, sin(angle) * 1.3)
					_add_box(donut_pivot, Vector3(0.12, 0.08, 0.25), sp_pos, sprinkle_colors[sp_i % sprinkle_colors.size()], true, Vector3(0, sp_i * 30, 0))
				root.add_child(donut_pivot)
	
	return root

## Builds a cute blocky 3D voxel police officer (0.9m tall)
## Features: dark-blue uniform torso, blocky head, peaked police cap with gold badge,
## and raised hands holding a baton and handcuffs.
func build_police_officer() -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelPoliceOfficer"
	
	# Color palette
	var uniform_col := Color("192a56")  # Dark-blue police uniform
	var belt_col := Color("1e272e")     # Black leather utility belt
	var shoe_col := Color("111111")     # Polished black shoes
	var skin_col := Color("f8c291")     # Warm skin tone
	var gold_col := Color("f1c40f")     # Gold badges / buckle
	var shirt_col := Color("f5f6fa")    # White collar/tie
	var baton_col := Color("1e272e")    # Black police nightstick
	var silver_col := Color("d2dae2")   # Metallic silver handcuffs
	var eye_col := Color("111111")      # Black cute eye pixels
	
	# 1. LEGS & SHOES (Height: 0.0m to 0.30m)
	# Left Leg
	var leg_l := Node3D.new()
	leg_l.name = "Leg_L"
	leg_l.position = Vector3(-0.09, 0.30, 0.0)
	_add_box(leg_l, Vector3(0.12, 0.26, 0.14), Vector3(0.0, -0.13, 0.0), uniform_col)
	_add_box(leg_l, Vector3(0.13, 0.07, 0.18), Vector3(0.0, -0.265, -0.02), shoe_col)
	root.add_child(leg_l)
	
	# Right Leg
	var leg_r := Node3D.new()
	leg_r.name = "Leg_R"
	leg_r.position = Vector3(0.09, 0.30, 0.0)
	_add_box(leg_r, Vector3(0.12, 0.26, 0.14), Vector3(0.0, -0.13, 0.0), uniform_col)
	_add_box(leg_r, Vector3(0.13, 0.07, 0.18), Vector3(0.0, -0.265, -0.02), shoe_col)
	root.add_child(leg_r)
	
	# 2. TORSO & BELT (Height: 0.30m to 0.58m)
	var torso := Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0.0, 0.44, 0.0)
	# Dark-blue uniform torso
	_add_box(torso, Vector3(0.32, 0.28, 0.20), Vector3(0.0, 0.0, 0.0), uniform_col)
	# Black duty belt
	_add_box(torso, Vector3(0.33, 0.06, 0.21), Vector3(0.0, -0.11, 0.0), belt_col)
	# Gold belt buckle
	_add_box(torso, Vector3(0.08, 0.06, 0.22), Vector3(0.0, -0.11, 0.0), gold_col, true)
	# White police collar / tie
	_add_box(torso, Vector3(0.07, 0.16, 0.02), Vector3(0.0, 0.06, -0.105), shirt_col)
	# Gold police star badge on left chest
	_add_box(torso, Vector3(0.06, 0.06, 0.02), Vector3(-0.09, 0.06, -0.105), gold_col, true)
	# Radio pouch on right hip
	_add_box(torso, Vector3(0.06, 0.08, 0.08), Vector3(0.18, -0.10, 0.0), belt_col)
	root.add_child(torso)
	
	# 3. BLOCKY HEAD (Height: 0.58m to 0.78m)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.68, 0.0)
	# Head cube
	_add_box(head, Vector3(0.24, 0.20, 0.22), Vector3(0.0, 0.0, 0.0), skin_col)
	# Cute eyes
	_add_box(head, Vector3(0.04, 0.04, 0.02), Vector3(-0.06, 0.01, -0.115), eye_col)
	_add_box(head, Vector3(0.04, 0.04, 0.02), Vector3(0.06, 0.01, -0.115), eye_col)
	# Cute rosy cheeks
	_add_box(head, Vector3(0.04, 0.02, 0.01), Vector3(-0.08, -0.04, -0.115), Color("ff7675"))
	_add_box(head, Vector3(0.04, 0.02, 0.01), Vector3(0.08, -0.04, -0.115), Color("ff7675"))
	root.add_child(head)
	
	# 4. PEAKED POLICE CAP WITH GOLD BADGE (Height: 0.78m to 0.90m)
	var cap := Node3D.new()
	cap.name = "Cap"
	cap.position = Vector3(0.0, 0.78, 0.0)
	# Cap base
	_add_box(cap, Vector3(0.26, 0.05, 0.26), Vector3(0.0, 0.025, 0.0), uniform_col)
	# Flared peaked crown
	_add_box(cap, Vector3(0.28, 0.06, 0.28), Vector3(0.0, 0.07, 0.01), uniform_col)
	# Black cap band
	_add_box(cap, Vector3(0.265, 0.03, 0.265), Vector3(0.0, 0.015, 0.0), belt_col)
	# Black visor / brim angled slightly down
	_add_box(cap, Vector3(0.26, 0.025, 0.10), Vector3(0.0, 0.01, -0.14), belt_col, false, Vector3(-12, 0, 0))
	# Gold police shield badge on front
	_add_box(cap, Vector3(0.06, 0.06, 0.02), Vector3(0.0, 0.06, -0.145), gold_col, true)
	root.add_child(cap)
	
	# 5. RAISED HANDS HOLDING BATON / HANDCUFFS (Height: ~0.50m to 0.75m)
	# Left Arm & Hand (Holding Baton)
	var arm_l := Node3D.new()
	arm_l.name = "Arm_L"
	arm_l.position = Vector3(-0.20, 0.52, 0.0)
	# Raised sleeve angled forward/upward
	_add_box(arm_l, Vector3(0.09, 0.18, 0.09), Vector3(-0.04, 0.06, -0.06), uniform_col, false, Vector3(-35, 10, -15))
	# Skin tone hand
	_add_box(arm_l, Vector3(0.08, 0.08, 0.08), Vector3(-0.07, 0.14, -0.12), skin_col)
	# Police nightstick / baton held upright in hand
	var baton := Node3D.new()
	baton.name = "Baton"
	baton.position = Vector3(-0.07, 0.20, -0.12)
	_add_cylinder(baton, 0.025, 0.32, Vector3.ZERO, baton_col, Vector3(25, 0, 15))
	_add_box(baton, Vector3(0.04, 0.07, 0.04), Vector3(0.0, -0.10, 0.0), belt_col) # Handle grip
	arm_l.add_child(baton)
	root.add_child(arm_l)
	
	# Right Arm & Hand (Holding Handcuffs)
	var arm_r := Node3D.new()
	arm_r.name = "Arm_R"
	arm_r.position = Vector3(0.20, 0.52, 0.0)
	# Raised sleeve angled forward/upward
	_add_box(arm_r, Vector3(0.09, 0.18, 0.09), Vector3(0.04, 0.06, -0.06), uniform_col, false, Vector3(-35, -10, 15))
	# Skin tone hand
	_add_box(arm_r, Vector3(0.08, 0.08, 0.08), Vector3(0.07, 0.14, -0.12), skin_col)
	# Metallic handcuffs hanging from hand
	var cuffs := Node3D.new()
	cuffs.name = "Handcuffs"
	cuffs.position = Vector3(0.07, 0.10, -0.14)
	# Loop 1
	_add_torus(cuffs, 0.02, 0.045, Vector3(0.0, 0.0, 0.0), silver_col, Vector3(90, 0, 0))
	# Chain link
	_add_box(cuffs, Vector3(0.04, 0.015, 0.015), Vector3(0.035, 0.0, 0.0), silver_col)
	# Loop 2
	_add_torus(cuffs, 0.02, 0.045, Vector3(0.07, -0.02, 0.0), silver_col, Vector3(70, 20, 0))
	arm_r.add_child(cuffs)
	root.add_child(arm_r)
	
	return root

## Phase 12: 3-Slot Visual Gear Loadout Attacher
## Attaches 3D block meshes, glowing lights, and particles for equipped gear items
## across 3 slots: "weapon_mod", "drift_trail", "armor_mod".
func attach_gear_loadout(car_root: Node3D, loadout: Dictionary) -> Node3D:
	if not car_root or not is_instance_valid(car_root):
		return null
	
	# Clean up any existing gear node
	var old_gear := car_root.get_node_or_null("GearLoadoutNode")
	if old_gear and is_instance_valid(old_gear):
		old_gear.name = "OldGear"
		old_gear.queue_free()
	
	var gear_root := Node3D.new()
	gear_root.name = "GearLoadoutNode"
	car_root.add_child(gear_root)
	
	var roof_y: float = 0.88
	
	# --------------------------------------------------------------------------
	# SLOT 1: ROOF WEAPON MOD
	# --------------------------------------------------------------------------
	var weapon_mod: String = String(loadout.get("weapon_mod", ""))
	match weapon_mod:
		"rockets_twin":
			# Twin rear rocket pods on roof
			_add_box(gear_root, Vector3(0.85, 0.05, 0.12), Vector3(0.0, roof_y - 0.04, 0.45), Color("2f3640"))
			for rx in [-0.34, 0.34]:
				# Dark tube pod
				_add_box(gear_root, Vector3(0.16, 0.16, 0.62), Vector3(rx, roof_y + 0.08, 0.42), Color("1e272e"))
				# Red warhead cone
				_add_box(gear_root, Vector3(0.14, 0.14, 0.14), Vector3(rx, roof_y + 0.08, 0.06), Color("e84118"))
				# Orange afterburner nozzle
				_add_box(gear_root, Vector3(0.12, 0.12, 0.06), Vector3(rx, roof_y + 0.08, 0.76), Color("ffa801"), true)
		"emp_dome":
			# Pulse EMP Dome
			_add_cylinder(gear_root, 0.32, 0.08, Vector3(0.0, roof_y - 0.02, 0.0), Color("2f3640"))
			_add_cylinder(gear_root, 0.28, 0.20, Vector3(0.0, roof_y + 0.10, 0.0), Color("00d2d3"), Vector3.ZERO, true)
			_add_box(gear_root, Vector3(0.48, 0.05, 0.08), Vector3(0.0, roof_y + 0.22, 0.0), Color("f5f6fa"))
			var emp_light := OmniLight3D.new()
			emp_light.name = "EmpDomeLight"
			emp_light.light_color = Color("00d2d3")
			emp_light.light_energy = 1.8
			emp_light.omni_range = 3.5
			emp_light.position = Vector3(0.0, roof_y + 0.15, 0.0)
			gear_root.add_child(emp_light)
		"magnet_dish":
			# Golden Cash Dish (spinning satellite dish)
			_add_cylinder(gear_root, 0.05, 0.22, Vector3(0.0, roof_y + 0.06, 0.1), Color("718093"))
			var dish := _add_cylinder(gear_root, 0.30, 0.06, Vector3(0.0, roof_y + 0.22, 0.1), Color("f1c40f"), Vector3(32, 0, 0), true)
			dish.name = "DishMesh"
			_add_cylinder(gear_root, 0.03, 0.14, Vector3(0.0, roof_y + 0.28, -0.04), Color("e67e22"), Vector3(-58, 0, 0))
	
	# --------------------------------------------------------------------------
	# SLOT 2: NEON UNDERGLOW & DRIFT TRAIL
	# --------------------------------------------------------------------------
	var drift_trail: String = String(loadout.get("drift_trail", ""))
	var underglow_color: Color = Color.TRANSPARENT
	match drift_trail:
		"underglow_cyan":
			underglow_color = Color("00d2d3")
		"trail_gold_flame":
			underglow_color = Color("ff9f43")
		"trail_cyber_purple":
			underglow_color = Color("9b59b6")
	
	if underglow_color != Color.TRANSPARENT:
		var underglow := OmniLight3D.new()
		underglow.name = "NeonUnderglowLight"
		underglow.light_color = underglow_color
		underglow.light_energy = 2.4
		underglow.omni_range = 4.2
		underglow.position = Vector3(0.0, 0.08, 0.0)
		gear_root.add_child(underglow)
		
		# Visible neon tubes under side skirts
		_add_box(gear_root, Vector3(0.06, 0.04, 1.4), Vector3(-0.62, 0.06, 0.0), underglow_color, true)
		_add_box(gear_root, Vector3(0.06, 0.04, 1.4), Vector3(0.62, 0.06, 0.0), underglow_color, true)
		
		# If attached to an ArcadeCar, also tint drift particles
		if "drift_smoke_left" in car_root and car_root.drift_smoke_left:
			var gp_left: CPUParticles3D = car_root.drift_smoke_left as CPUParticles3D
			if gp_left:
				gp_left.color = underglow_color
		if "drift_smoke_right" in car_root and car_root.drift_smoke_right:
			var gp_right: CPUParticles3D = car_root.drift_smoke_right as CPUParticles3D
			if gp_right:
				gp_right.color = underglow_color
	
	# --------------------------------------------------------------------------
	# SLOT 3: BUMPER & CHASSIS ARMOR
	# --------------------------------------------------------------------------
	var armor_mod: String = String(loadout.get("armor_mod", ""))
	match armor_mod:
		"bumper_standard":
			# Stock Chrome Bumper
			_add_box(gear_root, Vector3(1.36, 0.12, 0.12), Vector3(0.0, 0.22, -1.24), Color("d2dae2"))
			_add_box(gear_root, Vector3(0.10, 0.24, 0.14), Vector3(-0.45, 0.26, -1.25), Color("718093"))
			_add_box(gear_root, Vector3(0.10, 0.24, 0.14), Vector3(0.45, 0.26, -1.25), Color("718093"))
		"bumper_spiked":
			# Spiked Ramming Bullbar (+35% knockback)
			_add_box(gear_root, Vector3(1.44, 0.26, 0.16), Vector3(0.0, 0.24, -1.28), Color("1e272e"))
			_add_box(gear_root, Vector3(0.95, 0.08, 0.08), Vector3(0.0, 0.44, -1.28), Color("2f3640"))
			for sx in [-0.55, -0.18, 0.18, 0.55]:
				_add_box(gear_root, Vector3(0.08, 0.08, 0.28), Vector3(sx, 0.24, -1.45), Color("d2dae2"))
		"armor_titanium":
			# Titanium Roll-Cage Plates (+65 Max HP, -25% collision damage)
			_add_box(gear_root, Vector3(0.08, 0.32, 1.8), Vector3(-0.68, 0.32, 0.0), Color("718093"))
			_add_box(gear_root, Vector3(0.08, 0.32, 1.8), Vector3(0.68, 0.32, 0.0), Color("718093"))
			_add_box(gear_root, Vector3(1.15, 0.08, 0.08), Vector3(0.0, 0.88, -0.4), Color("bdc3c7"))
			_add_box(gear_root, Vector3(1.15, 0.08, 0.08), Vector3(0.0, 0.88, 0.5), Color("bdc3c7"))
			_add_box(gear_root, Vector3(0.08, 0.08, 0.98), Vector3(-0.54, 0.88, 0.05), Color("bdc3c7"))
			_add_box(gear_root, Vector3(0.08, 0.08, 0.98), Vector3(0.54, 0.88, 0.05), Color("bdc3c7"))
	
	return gear_root

## Builds a cute blocky 3D voxel Getaway Robber player character (0.88m tall)
## Features: striped black/white heist shirt, burglar eye-mask, knit beanie,
## running legs, swinging arms, and a cash sack on the back.
func build_player_character_visuals() -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelPlayerCharacter"
	
	var stripe_black := Color("1e272e")
	var stripe_white := Color("f5f6fa")
	var skin_col := Color("f8c291")
	var pants_col := Color("2f3542")
	var shoe_col := Color("111111")
	var beanie_col := Color("1e272e")
	var bag_col := Color("c7ecee")
	var strap_col := Color("833471")
	var eye_col := Color("f5f6fa")
	
	# 1. LEGS (Pivots at hip for running animation)
	var leg_l := Node3D.new()
	leg_l.name = "Leg_L"
	leg_l.position = Vector3(-0.09, 0.30, 0.0)
	_add_box(leg_l, Vector3(0.12, 0.26, 0.14), Vector3(0.0, -0.13, 0.0), pants_col)
	_add_box(leg_l, Vector3(0.13, 0.07, 0.18), Vector3(0.0, -0.265, -0.02), shoe_col)
	root.add_child(leg_l)
	
	var leg_r := Node3D.new()
	leg_r.name = "Leg_R"
	leg_r.position = Vector3(0.09, 0.30, 0.0)
	_add_box(leg_r, Vector3(0.12, 0.26, 0.14), Vector3(0.0, -0.13, 0.0), pants_col)
	_add_box(leg_r, Vector3(0.13, 0.07, 0.18), Vector3(0.0, -0.265, -0.02), shoe_col)
	root.add_child(leg_r)
	
	# 2. TORSO (Horizontal prison/heist stripes)
	var torso := Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0.0, 0.44, 0.0)
	# 4 alternating stripes
	_add_box(torso, Vector3(0.32, 0.07, 0.20), Vector3(0.0, -0.105, 0.0), stripe_black)
	_add_box(torso, Vector3(0.32, 0.07, 0.20), Vector3(0.0, -0.035, 0.0), stripe_white)
	_add_box(torso, Vector3(0.32, 0.07, 0.20), Vector3(0.0, 0.035, 0.0), stripe_black)
	_add_box(torso, Vector3(0.32, 0.07, 0.20), Vector3(0.0, 0.105, 0.0), stripe_white)
	# Duffel strap across chest
	_add_box(torso, Vector3(0.06, 0.30, 0.03), Vector3(0.0, 0.0, -0.105), strap_col, false, Vector3(0, 0, 32))
	# Green loot cash sack slung on back
	_add_box(torso, Vector3(0.24, 0.26, 0.16), Vector3(0.0, 0.02, 0.15), Color("2ed573"))
	_add_box(torso, Vector3(0.12, 0.12, 0.02), Vector3(0.0, 0.02, 0.235), Color("f1c40f"), true) # Dollar sign emblem
	root.add_child(torso)
	
	# 3. ARMS (Pivots at shoulder for running swing)
	var arm_l := Node3D.new()
	arm_l.name = "Arm_L"
	arm_l.position = Vector3(-0.20, 0.52, 0.0)
	_add_box(arm_l, Vector3(0.09, 0.18, 0.09), Vector3(-0.02, -0.09, 0.0), stripe_black)
	_add_box(arm_l, Vector3(0.08, 0.08, 0.08), Vector3(-0.02, -0.22, 0.0), skin_col)
	root.add_child(arm_l)
	
	var arm_r := Node3D.new()
	arm_r.name = "Arm_R"
	arm_r.position = Vector3(0.20, 0.52, 0.0)
	_add_box(arm_r, Vector3(0.09, 0.18, 0.09), Vector3(0.02, -0.09, 0.0), stripe_black)
	_add_box(arm_r, Vector3(0.08, 0.08, 0.08), Vector3(0.02, -0.22, 0.0), skin_col)
	root.add_child(arm_r)
	
	# 4. HEAD WITH BURGLAR MASK & BEANIE
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.68, 0.0)
	# Skin base
	_add_box(head, Vector3(0.24, 0.20, 0.22), Vector3(0.0, 0.0, 0.0), skin_col)
	# Black domino burglar eye mask
	_add_box(head, Vector3(0.25, 0.08, 0.04), Vector3(0.0, 0.02, -0.105), stripe_black)
	# White glowing eye slits inside mask
	_add_box(head, Vector3(0.04, 0.03, 0.02), Vector3(-0.06, 0.02, -0.12), eye_col, true)
	_add_box(head, Vector3(0.04, 0.03, 0.02), Vector3(0.06, 0.02, -0.12), eye_col, true)
	# Knit beanie cap
	_add_box(head, Vector3(0.26, 0.10, 0.24), Vector3(0.0, 0.10, 0.0), beanie_col)
	_add_box(head, Vector3(0.27, 0.04, 0.25), Vector3(0.0, 0.06, 0.0), Color("2f3542")) # Beanie brim fold
	_add_box(head, Vector3(0.06, 0.06, 0.06), Vector3(0.0, 0.16, 0.0), beanie_col) # Pom-pom
	root.add_child(head)
	
	return root

## Builds a 3D tactical spike strip prop (3.6m width across road lane)
func build_spike_strip_visual() -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelSpikeStrip"
	var base_col := Color("1e272e")
	var spike_col := Color("dfe4ea")
	
	# Central frame
	_add_box(root, Vector3(3.6, 0.06, 0.35), Vector3(0.0, 0.03, 0.0), base_col)
	# Yellow warning stripes on ends
	_add_box(root, Vector3(0.2, 0.065, 0.36), Vector3(-1.7, 0.03, 0.0), Color("f1c40f"))
	_add_box(root, Vector3(0.2, 0.065, 0.36), Vector3(1.7, 0.03, 0.0), Color("f1c40f"))
	
	# 10 silver puncture spikes
	for i in range(10):
		var x_pos := -1.5 + float(i) * 0.33
		_add_box(root, Vector3(0.06, 0.16, 0.06), Vector3(x_pos, 0.11, 0.0), spike_col, true)
	
	return root

## Builds a 3D tactical landmine prop with flashing red warning light
func build_trap_mine_visual() -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelTrapMine"
	var dark_steel := Color("2f3640")
	var yellow_band := Color("e1b12c")
	var red_core := Color("e84118")
	
	# Octagonal base
	_add_cylinder(root, 0.38, 0.09, Vector3(0.0, 0.045, 0.0), dark_steel)
	# Yellow outer hazard ring
	_add_torus(root, 0.025, 0.35, Vector3(0.0, 0.07, 0.0), yellow_band, Vector3(90, 0, 0))
	# Center red glowing detonator button
	_add_cylinder(root, 0.14, 0.05, Vector3(0.0, 0.10, 0.0), red_core)
	
	var light := OmniLight3D.new()
	light.name = "MineBeacon"
	light.light_color = red_core
	light.light_energy = 2.5
	light.omni_range = 3.5
	light.position = Vector3(0.0, 0.20, 0.0)
	root.add_child(light)
	
	return root

## Builds a 3D blocky powerup sculpture with ground aura ring and omni light
func build_powerup_3d_model(powerup_type: int) -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelPowerup_%d" % powerup_type
	
	var pivot := Node3D.new()
	pivot.name = "SculpturePivot"
	root.add_child(pivot)
	
	var aura_col := Color("00d2d3")
	
	match powerup_type:
		0: # NITRO_OVERDRIVE: Twin angled blue NOS bottles with chrome valves & blue flame
			aura_col = Color("00d2d3")
			var nos_blue := Color("0984e3")
			var chrome := Color("dfe4ea")
			var gold_strap := Color("fbc531")
			var flame_blue := Color("00cec9")
			
			# Left bottle
			var b_l := Node3D.new()
			b_l.position = Vector3(-0.16, 0.0, 0.0)
			b_l.rotation_degrees = Vector3(0, 0, -12)
			_add_cylinder(b_l, 0.14, 0.54, Vector3.ZERO, nos_blue)
			_add_cylinder(b_l, 0.06, 0.12, Vector3(0.0, 0.30, 0.0), chrome) # Valve neck
			_add_box(b_l, Vector3(0.12, 0.05, 0.08), Vector3(0.0, 0.36, 0.0), chrome) # Valve tap
			_add_sphere(b_l, 0.07, Vector3(0.0, 0.44, 0.0), flame_blue, true) # Flame tip
			pivot.add_child(b_l)
			
			# Right bottle
			var b_r := Node3D.new()
			b_r.position = Vector3(0.16, 0.0, 0.0)
			b_r.rotation_degrees = Vector3(0, 0, 12)
			_add_cylinder(b_r, 0.14, 0.54, Vector3.ZERO, nos_blue)
			_add_cylinder(b_r, 0.06, 0.12, Vector3(0.0, 0.30, 0.0), chrome)
			_add_box(b_r, Vector3(0.12, 0.05, 0.08), Vector3(0.0, 0.36, 0.0), chrome)
			_add_sphere(b_r, 0.07, Vector3(0.0, 0.44, 0.0), flame_blue, true)
			pivot.add_child(b_r)
			
			# Mounting cross-brace bracket
			_add_box(pivot, Vector3(0.44, 0.08, 0.12), Vector3(0.0, 0.0, 0.0), gold_strap)
			_add_box(pivot, Vector3(0.40, 0.06, 0.10), Vector3(0.0, -0.16, 0.0), gold_strap)

		1: # EMP_SHOCKWAVE: Pulsating plasma core + dual perpendicular gyro rings
			aura_col = Color("3498db")
			var plasma_core := Color("00d2d3")
			var ring_outer := Color("8c7ae6")
			var ring_inner := Color("4834d4")
			var gold_node := Color("fbc531")
			
			# Plasma sphere core
			_add_sphere(pivot, 0.22, Vector3.ZERO, plasma_core, true)
			
			# Horizontal gyro ring
			_add_torus(pivot, 0.34, 0.40, Vector3.ZERO, ring_outer, Vector3(0, 0, 0), true)
			# Vertical gyro ring
			_add_torus(pivot, 0.32, 0.38, Vector3.ZERO, ring_inner, Vector3(90, 0, 0), true)
			
			# 4 Node capacitors on outer ring
			_add_box(pivot, Vector3(0.08, 0.08, 0.08), Vector3(0.38, 0.0, 0.0), gold_node)
			_add_box(pivot, Vector3(0.08, 0.08, 0.08), Vector3(-0.38, 0.0, 0.0), gold_node)
			_add_box(pivot, Vector3(0.08, 0.08, 0.08), Vector3(0.0, 0.0, 0.38), gold_node)
			_add_box(pivot, Vector3(0.08, 0.08, 0.08), Vector3(0.0, 0.0, -0.38), gold_node)

		2: # OIL_SLICK_DROPPER: Tilted industrial yellow hazard drum dripping oil
			aura_col = Color("e67e22")
			var drum_yellow := Color("f1c40f")
			var hazard_black := Color("2f3542")
			var oil_dark := Color("1e272e")
			
			var drum := Node3D.new()
			drum.rotation_degrees = Vector3(15, 0, -18)
			
			# Drum body
			_add_cylinder(drum, 0.22, 0.56, Vector3.ZERO, drum_yellow)
			# Black hazard band
			_add_cylinder(drum, 0.225, 0.18, Vector3.ZERO, hazard_black)
			# Rims
			_add_torus(drum, 0.21, 0.23, Vector3(0.0, 0.28, 0.0), drum_yellow)
			_add_torus(drum, 0.21, 0.23, Vector3(0.0, -0.28, 0.0), drum_yellow)
			# Dripping oil spout
			_add_cylinder(drum, 0.05, 0.10, Vector3(0.12, 0.30, 0.0), hazard_black)
			_add_sphere(drum, 0.06, Vector3(0.16, 0.38, 0.0), oil_dark, true)
			_add_sphere(drum, 0.05, Vector3(0.20, 0.22, 0.0), oil_dark, true)
			pivot.add_child(drum)

		3: # TITAN_REPAIR_SHIELD: Golden wrench surrounded by protective hexagonal aura
			aura_col = Color("f1c40f")
			var gold_mat := Color("f1c40f")
			var chrome_accent := Color("dfe4ea")
			var green_shield := Color("2ecc71")
			
			# Golden Wrench
			var wrench := Node3D.new()
			wrench.rotation_degrees = Vector3(0, 0, 45)
			# Handle
			_add_box(wrench, Vector3(0.09, 0.48, 0.06), Vector3.ZERO, gold_mat)
			# Top Jaw head
			_add_box(wrench, Vector3(0.20, 0.14, 0.07), Vector3(0.0, 0.26, 0.0), gold_mat)
			_add_box(wrench, Vector3(0.08, 0.10, 0.08), Vector3(0.0, 0.29, 0.0), Color("0d1117")) # Cutout opening
			# Bottom ring head
			_add_cylinder(wrench, 0.09, 0.07, Vector3(0.0, -0.26, 0.0), gold_mat)
			_add_cylinder(wrench, 0.05, 0.08, Vector3(0.0, -0.26, 0.0), Color("0d1117")) # Ring cutout
			pivot.add_child(wrench)
			
			# Protective shield ring
			_add_torus(pivot, 0.36, 0.42, Vector3.ZERO, green_shield, Vector3(90, 0, 0), true)
			_add_box(pivot, Vector3(0.12, 0.04, 0.04), Vector3(0.0, 0.0, 0.08), chrome_accent)
			_add_box(pivot, Vector3(0.04, 0.12, 0.04), Vector3(0.0, 0.0, 0.08), chrome_accent)

	# Ground glowing aura ring
	var aura := _add_torus(root, 0.65, 0.78, Vector3(0.0, -0.50, 0.0), aura_col, Vector3.ZERO, true)
	aura.name = "GroundAuraRing"
	
	# Light
	var light := OmniLight3D.new()
	light.name = "PowerupLight"
	light.light_color = aura_col
	light.light_energy = 1.8
	light.omni_range = 3.6
	light.position = Vector3(0.0, 0.1, 0.0)
	root.add_child(light)
	
	return root

# ==============================================================================
# REALISTIC CITY ARCHITECTURE & LANDMARKS
# ==============================================================================

## Multi-tier corporate skyscraper with setbacks, rooftop helipad, and antennas
func build_skyscraper_tiered(width: float, depth: float, height: float, primary_color: Color, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelSkyscraperTiered"
	
	# Tier 1: Street Lobby Base (4.5m high)
	var t1_h: float = 4.5
	var base_col := Color("1e272e")
	_add_box(root, Vector3(width + 0.4, 0.4, depth + 0.4), Vector3(0.0, 0.2, 0.0), base_col)
	_add_box(root, Vector3(width, t1_h, depth), Vector3(0.0, t1_h * 0.5, 0.0), Color("2f3640"))
	
	# Glass revolving door & illuminated corporate sign
	_add_box(root, Vector3(2.4, 2.6, 0.15), Vector3(0.0, 1.3, -depth * 0.5 - 0.05), Color("00d2d3"), true)
	_add_box(root, Vector3(width * 0.6, 0.6, 0.25), Vector3(0.0, 3.8, -depth * 0.5 - 0.1), Color("fbc531"), true)
	
	# Tier 2: Mid-Rise Tower with Setback
	var t2_w: float = width * 0.88
	var t2_d: float = depth * 0.88
	var t2_h: float = maxf(6.0, height * 0.55)
	var t2_y: float = t1_h + t2_h * 0.5
	_add_box(root, Vector3(t2_w, t2_h, t2_d), Vector3(0.0, t2_y, 0.0), primary_color)
	
	# Window rows along Tier 2
	var wy: float = t1_h + 1.8
	while wy < t1_h + t2_h - 1.2:
		var is_lit: bool = (rng.randf() > 0.35)
		var win_col: Color = Color("ffeaa7") if is_lit else Color("192a56")
		_add_box(root, Vector3(t2_w * 0.82, 0.9, 0.1), Vector3(0.0, wy, -t2_d * 0.5 - 0.04), win_col, is_lit)
		_add_box(root, Vector3(t2_w * 0.82, 0.9, 0.1), Vector3(0.0, wy, t2_d * 0.5 + 0.04), win_col, is_lit)
		wy += 2.4
	
	# Tier 3: High-Rise Crown with Setback & Helipad
	var t3_w: float = t2_w * 0.82
	var t3_d: float = t2_d * 0.82
	var t3_h: float = maxf(4.0, height - (t1_h + t2_h))
	var t3_y: float = t1_h + t2_h + t3_h * 0.5
	_add_box(root, Vector3(t3_w, t3_h, t3_d), Vector3(0.0, t3_y, 0.0), primary_color.darkened(0.15))
	
	# Rooftop Helipad
	var roof_y: float = t1_h + t2_h + t3_h
	var pad_size: float = minf(t3_w, t3_d) * 0.85
	_add_box(root, Vector3(pad_size, 0.2, pad_size), Vector3(0.0, roof_y + 0.1, 0.0), Color("2d3436"))
	# Yellow Helipad Circle Rim & 'H' Mark
	_add_torus(root, pad_size * 0.38, pad_size * 0.44, Vector3(0.0, roof_y + 0.22, 0.0), Color("f1c40f"))
	_add_box(root, Vector3(pad_size * 0.45, 0.04, 0.35), Vector3(0.0, roof_y + 0.22, 0.0), Color("f1c40f")) # H crossbar
	_add_box(root, Vector3(0.35, 0.04, pad_size * 0.55), Vector3(-pad_size * 0.22, roof_y + 0.22, 0.0), Color("f1c40f")) # H left
	_add_box(root, Vector3(0.35, 0.04, pad_size * 0.55), Vector3(pad_size * 0.22, roof_y + 0.22, 0.0), Color("f1c40f")) # H right
	
	# Communications Antenna Spire with flashing red aviation beacon
	var spire_x: float = pad_size * 0.42
	_add_cylinder(root, 0.15, 6.5, Vector3(spire_x, roof_y + 3.25, spire_x), Color("dfe6e9"))
	_add_sphere(root, 0.32, Vector3(spire_x, roof_y + 6.6, spire_x), Color("e74c3c"), true)
	
	return root

## 2-story open-deck parking garage with drivable approach ramp and rooftop stunt jump
func build_parking_garage_with_ramp(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelParkingGarage"
	
	var conc_col := Color("636e72")
	var pillar_col := Color("2d3436")
	
	# Deck 1: Elevated Concrete Slab at Y = 3.8m
	_add_box(root, Vector3(16.0, 0.4, 16.0), Vector3(0.0, 3.8, 0.0), conc_col)
	# Support Pillars under Deck 1
	for px in [-7.0, 7.0]:
		for pz in [-7.0, 7.0]:
			_add_box(root, Vector3(0.8, 3.8, 0.8), Vector3(px, 1.9, pz), pillar_col)
	
	# Deck 2: Rooftop Slab at Y = 7.6m
	_add_box(root, Vector3(16.0, 0.4, 16.0), Vector3(0.0, 7.6, 0.0), conc_col)
	for px in [-7.0, 7.0]:
		for pz in [-7.0, 7.0]:
			_add_box(root, Vector3(0.8, 3.4, 0.8), Vector3(px, 5.7, pz), pillar_col)
	
	# Perimeter Crash Barriers on Rooftop
	_add_box(root, Vector3(16.2, 0.8, 0.3), Vector3(0.0, 8.2, -7.9), Color("f1c40f"))
	_add_box(root, Vector3(16.2, 0.8, 0.3), Vector3(0.0, 8.2, 7.9), Color("f1c40f"))
	_add_box(root, Vector3(0.3, 0.8, 16.2), Vector3(-7.9, 8.2, 0.0), Color("f1c40f"))
	
	# Yellow Painted Parking Stalls on Roof
	for sx in range(-5, 6, 3):
		_add_box(root, Vector3(0.15, 0.02, 3.8), Vector3(float(sx), 7.82, 4.0), Color("f5f6fa"))
	
	# Straight Drivable Approach Ramp along the side (from Y=0 to Y=7.6m)
	var ramp1 := _add_box(root, Vector3(4.2, 0.3, 10.5), Vector3(10.2, 1.9, 0.0), Color("2d3436"), false, Vector3(-20, 0, 0))
	ramp1.name = "GarageRamp1"
	
	# Rooftop Stunt Jump Ramp (facing off edge)
	var jump_lip := _add_box(root, Vector3(4.5, 0.6, 3.2), Vector3(0.0, 8.1, -6.5), Color("e84118"), false, Vector3(-24, 0, 0))
	jump_lip.name = "RooftopJumpLip"
	
	# Speed Boost Chevron Pad on Rooftop Ramp
	_add_box(root, Vector3(2.4, 0.04, 1.8), Vector3(0.0, 8.35, -5.8), Color("00d2d3"), true)
	
	return root

## Classic red gambrel barn and cylindrical metal grain silo
func build_red_barn_and_silo(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelFarmlandBarn"
	
	var barn_red := Color("c0392b")
	var barn_white := Color("f5f6fa")
	var roof_gray := Color("34495e")
	
	# Barn Main Structure (14m x 10m x 7m)
	_add_box(root, Vector3(14.0, 7.0, 10.0), Vector3(0.0, 3.5, 0.0), barn_red)
	
	# White Corner Trim Posts
	for px in [-6.9, 6.9]:
		for pz in [-4.9, 4.9]:
			_add_box(root, Vector3(0.35, 7.2, 0.35), Vector3(px, 3.6, pz), barn_white)
	
	# Gambrel Curved/Slanted Roof (Multi-tier pitched boxes)
	_add_box(root, Vector3(14.6, 2.2, 10.6), Vector3(0.0, 8.1, 0.0), roof_gray)
	_add_box(root, Vector3(14.4, 1.8, 7.6), Vector3(0.0, 9.8, 0.0), roof_gray)
	_add_box(root, Vector3(14.2, 1.2, 4.2), Vector3(0.0, 11.0, 0.0), roof_gray)
	
	# Giant Double Sliding Barn Doors with White 'X' Bracing (Front facing -Z)
	_add_box(root, Vector3(4.8, 4.2, 0.2), Vector3(0.0, 2.1, -5.05), barn_white)
	_add_box(root, Vector3(4.4, 3.8, 0.22), Vector3(0.0, 2.1, -5.05), barn_red)
	# White X diagonal crossbars
	_add_box(root, Vector3(0.3, 4.4, 0.26), Vector3(-1.2, 2.1, -5.06), barn_white, false, Vector3(0, 0, 42))
	_add_box(root, Vector3(0.3, 4.4, 0.26), Vector3(-1.2, 2.1, -5.06), barn_white, false, Vector3(0, 0, -42))
	_add_box(root, Vector3(0.3, 4.4, 0.26), Vector3(1.2, 2.1, -5.06), barn_white, false, Vector3(0, 0, 42))
	_add_box(root, Vector3(0.3, 4.4, 0.26), Vector3(1.2, 2.1, -5.06), barn_white, false, Vector3(0, 0, -42))
	
	# High Loft Window with Hay Hoist Beam
	_add_box(root, Vector3(1.8, 1.8, 0.15), Vector3(0.0, 6.2, -5.05), barn_white)
	_add_box(root, Vector3(0.24, 0.24, 2.4), Vector3(0.0, 7.5, -5.2), Color("795548"))
	
	# Cylindrical Grain Silo (Offset to side X = 9.5m)
	var silo_col := Color("bdc3c7")
	var silo_cap := Color("7f8c8d")
	_add_cylinder(root, 2.2, 11.0, Vector3(9.5, 5.5, -0.5), silo_col)
	_add_cylinder(root, 2.3, 1.6, Vector3(9.5, 11.5, -0.5), silo_cap)
	_add_cylinder(root, 1.2, 1.0, Vector3(9.5, 12.6, -0.5), silo_cap)
	for ly in range(2, 11, 2):
		_add_box(root, Vector3(0.6, 0.08, 0.12), Vector3(9.5, float(ly), -2.75), Color("2c3e50"))
	
	# Weather Vane on Barn Roof Peak
	_add_cylinder(root, 0.05, 1.2, Vector3(0.0, 12.0, 0.0), Color("f1c40f"))
	_add_box(root, Vector3(0.65, 0.35, 0.05), Vector3(0.0, 12.5, 0.0), Color("e67e22"))
	
	# Solid Barn & Silo Colliders (Layer 4: 8)
	_add_building_collider(root, Vector3(14.0, 7.0, 10.0), Vector3(0.0, 3.5, 0.0))
	_add_building_collider(root, Vector3(4.4, 11.0, 4.4), Vector3(9.5, 5.5, -0.5))
	
	return root

## Country wooden windmill with continuously spinning 4-blade rotor
func build_country_windmill(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelCountryWindmill"
	
	var stone_col := Color("d7ccc8")
	var timber_col := Color("5d4037")
	var blade_col := Color("f5f6fa")
	
	# Tapered octagonal wooden tower body
	_add_cylinder(root, 2.8, 3.5, Vector3(0.0, 1.75, 0.0), stone_col)
	_add_cylinder(root, 2.3, 4.0, Vector3(0.0, 5.5, 0.0), timber_col)
	_add_cylinder(root, 1.8, 3.0, Vector3(0.0, 9.0, 0.0), timber_col)
	_add_cylinder(root, 1.9, 1.2, Vector3(0.0, 11.0, 0.0), Color("3e2723"))
	
	# Solid Windmill Tower Collider (Layer 4: 8)
	_add_building_collider(root, Vector3(5.6, 9.0, 5.6), Vector3(0.0, 4.5, 0.0))
	
	# Rotating Blades Pivot Assembly (facing -Z)
	var rotor_pivot := Node3D.new()
	rotor_pivot.name = "WindmillRotor"
	rotor_pivot.position = Vector3(0.0, 10.8, -1.8)
	
	_add_cylinder(rotor_pivot, 0.45, 0.4, Vector3.ZERO, Color("d35400"), Vector3(90, 0, 0))
	
	for b_angle in [0.0, 90.0, 180.0, 270.0]:
		var blade := Node3D.new()
		blade.rotation_degrees = Vector3(0, 0, b_angle)
		_add_box(blade, Vector3(0.18, 4.2, 0.12), Vector3(0.0, 2.1, 0.0), Color("795548"))
		for sy in range(1, 4):
			_add_box(blade, Vector3(0.85, 0.65, 0.04), Vector3(0.42, float(sy) + 0.5, 0.0), blade_col)
		rotor_pivot.add_child(blade)
	
	root.add_child(rotor_pivot)
	
	var tw := root.create_tween().set_loops()
	tw.tween_property(rotor_pivot, "rotation:z", TAU, 5.0).as_relative()
	
	return root

## Green farm tractor with large rear tread wheels
func build_farm_tractor() -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelFarmTractor"
	
	var jd_green := Color("27ae60")
	var jd_yellow := Color("f1c40f")
	var tire_black := Color("1e272e")
	
	# Large Rear Wheels (Radius 0.68m, Width 0.36m)
	for rx in [-0.75, 0.75]:
		_add_cylinder(root, 0.68, 0.36, Vector3(rx, 0.68, 0.65), tire_black, Vector3(0, 0, 90))
		_add_cylinder(root, 0.35, 0.38, Vector3(rx, 0.68, 0.65), jd_yellow, Vector3(0, 0, 90))
	
	# Small Front Wheels (Radius 0.38m, Width 0.22m)
	for fx in [-0.58, 0.58]:
		_add_cylinder(root, 0.38, 0.22, Vector3(fx, 0.38, -0.85), tire_black, Vector3(0, 0, 90))
		_add_cylinder(root, 0.20, 0.24, Vector3(fx, 0.38, -0.85), jd_yellow, Vector3(0, 0, 90))
	
	# Chassis & Green Engine Hood
	_add_box(root, Vector3(0.95, 0.65, 1.6), Vector3(0.0, 0.65, -0.45), jd_green)
	_add_box(root, Vector3(0.97, 0.12, 1.5), Vector3(0.0, 0.75, -0.45), jd_yellow)
	_add_box(root, Vector3(0.85, 0.45, 0.1), Vector3(0.0, 0.60, -1.26), Color("2d3436"))
	
	# Vertical Exhaust Smokestack
	_add_cylinder(root, 0.06, 0.95, Vector3(0.35, 1.35, -0.75), Color("2f3542"))
	
	# Driver Operator Station & Roll-over Bar (ROPS)
	_add_box(root, Vector3(0.88, 0.18, 0.65), Vector3(0.0, 0.85, 0.45), Color("2f3542"))
	_add_box(root, Vector3(0.48, 0.35, 0.42), Vector3(0.0, 1.10, 0.55), Color("f1c40f"))
	_add_cylinder(root, 0.04, 0.45, Vector3(0.0, 1.15, 0.15), Color("1e272e"), Vector3(-25, 0, 0))
	_add_torus(root, 0.16, 0.20, Vector3(0.0, 1.35, 0.08), Color("1e272e"), Vector3(-25, 0, 0))
	
	_add_box(root, Vector3(0.92, 0.08, 0.08), Vector3(0.0, 2.05, 0.65), Color("2f3542"))
	_add_cylinder(root, 0.04, 1.15, Vector3(-0.42, 1.45, 0.65), Color("2f3542"))
	_add_cylinder(root, 0.04, 1.15, Vector3(0.42, 1.45, 0.65), Color("2f3542"))
	
	return root

## Furrowed crop field rows with stalks or pumpkins
func build_crop_field(width: float, depth: float, crop_type: int, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelCropField"
	
	var soil_col := Color("4e342e")
	var wheat_col := Color("f1c40f")
	var corn_col := Color("2ecc71")
	var pumpkin_col := Color("e67e22")
	
	_add_box(root, Vector3(width, 0.12, depth), Vector3.ZERO, soil_col)
	
	var start_x: float = -width * 0.5 + 1.2
	var end_x: float = width * 0.5 - 1.2
	var cur_x: float = start_x
	
	while cur_x <= end_x:
		_add_box(root, Vector3(0.85, 0.18, depth * 0.95), Vector3(cur_x, 0.09, 0.0), soil_col.darkened(0.12))
		
		var start_z: float = -depth * 0.5 + 1.2
		var end_z: float = depth * 0.5 - 1.2
		var cur_z: float = start_z
		
		while cur_z <= end_z:
			match crop_type:
				0:
					_add_box(root, Vector3(0.65, 0.85, 0.65), Vector3(cur_x, 0.50, cur_z), wheat_col)
					_add_box(root, Vector3(0.45, 0.35, 0.45), Vector3(cur_x, 0.95, cur_z), Color("fed330"))
				1:
					_add_cylinder(root, 0.08, 1.45, Vector3(cur_x, 0.80, cur_z), corn_col)
					_add_box(root, Vector3(0.45, 0.35, 0.45), Vector3(cur_x, 1.35, cur_z), corn_col)
					_add_box(root, Vector3(0.15, 0.25, 0.15), Vector3(cur_x + 0.1, 0.90, cur_z), wheat_col)
				_:
					_add_sphere(root, 0.38, Vector3(cur_x, 0.38, cur_z), pumpkin_col)
					_add_cylinder(root, 0.04, 0.18, Vector3(cur_x, 0.78, cur_z), Color("27ae60"))
			cur_z += 2.2
		cur_x += 2.6
	
	return root

## Continuous ballasted dual-track railway bed with overhead electrification posts
func build_rail_tracks(length: float = 48.0) -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelRailTracks"
	
	var ballast_col := Color("576574")
	var tie_col := Color("4b382a")
	var rail_col := Color("b2bec3")
	var pole_col := Color("2c3e50")
	
	_add_box(root, Vector3(7.4, 0.18, length), Vector3(0.0, 0.09, 0.0), ballast_col)
	
	for track_x in [-1.8, 1.8]:
		var half_len: float = length * 0.5
		var cur_z: float = -half_len + 0.75
		while cur_z <= half_len:
			_add_box(root, Vector3(2.6, 0.12, 0.36), Vector3(track_x, 0.20, cur_z), tie_col)
			cur_z += 1.5
		
		for rx in [-0.72, 0.72]:
			_add_box(root, Vector3(0.09, 0.18, length), Vector3(track_x + rx, 0.32, 0.0), rail_col, false)
			_add_box(root, Vector3(0.12, 0.04, length), Vector3(track_x + rx, 0.40, 0.0), Color("dfe6e9"))
	
	for pz in [-length * 0.35, length * 0.35]:
		_add_box(root, Vector3(0.35, 6.5, 0.35), Vector3(-4.4, 3.25, pz), pole_col)
		_add_box(root, Vector3(0.35, 6.5, 0.35), Vector3(4.4, 3.25, pz), pole_col)
		_add_box(root, Vector3(9.2, 0.4, 0.35), Vector3(0.0, 6.3, pz), pole_col)
		for tx in [-1.8, 1.8]:
			_add_cylinder(root, 0.06, 0.8, Vector3(tx, 5.7, pz), Color("bdc3c7"))
	
	return root

## Functional railroad level crossing barrier with crossbuck and warning lights
func build_level_crossing_barrier() -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelLevelCrossingBarrier"
	
	_add_box(root, Vector3(0.65, 0.85, 0.65), Vector3(0.0, 0.425, 0.0), Color("2f3542"))
	_add_cylinder(root, 0.14, 4.2, Vector3(0.0, 2.1, 0.0), Color("718093"))
	
	var x_pos := Vector3(0.0, 3.4, 0.0)
	_add_box(root, Vector3(1.6, 0.28, 0.06), x_pos, Color("f5f6fa"), false, Vector3(0, 0, 45))
	_add_box(root, Vector3(1.6, 0.28, 0.06), x_pos, Color("f5f6fa"), false, Vector3(0, 0, -45))
	
	var lamp_left := _add_cylinder(root, 0.20, 0.12, Vector3(-0.65, 3.0, 0.15), Color("e74c3c"), Vector3(90, 0, 0), true)
	lamp_left.name = "FlasherLeft"
	var lamp_right := _add_cylinder(root, 0.20, 0.12, Vector3(0.65, 3.0, 0.15), Color("2f3542"), Vector3(90, 0, 0))
	lamp_right.name = "FlasherRight"
	
	var gate_pivot := Node3D.new()
	gate_pivot.name = "GatePivot"
	gate_pivot.position = Vector3(0.0, 1.15, 0.0)
	
	var arm_mesh := _add_box(gate_pivot, Vector3(7.2, 0.26, 0.10), Vector3(-3.6, 0.0, 0.0), Color("f5f6fa"))
	arm_mesh.name = "GateArm"
	for rx in range(1, 7):
		_add_box(gate_pivot, Vector3(0.45, 0.28, 0.12), Vector3(-float(rx), 0.0, 0.0), Color("e74c3c"))
	
	root.add_child(gate_pivot)
	return root

## Multi-car freight train with locomotive, boxcar, tanker, container flatbed, and caboose
func build_freight_train_multi_car() -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelMultiCarTrain"
	
	var dark_navy := Color("192a56")
	var bright_yellow := Color("f1c40f")
	var boxcar_red := Color("c0392b")
	var tanker_blue := Color("2980b9")
	var flatbed_orange := Color("e67e22")
	var steel_gray := Color("2c3e50")
	var wheel_black := Color("1e272e")
	
	var cur_z: float = 0.0
	
	# 1. DIESEL LOCOMOTIVE
	var loco := Node3D.new()
	loco.name = "Locomotive"
	loco.position = Vector3(0.0, 0.0, cur_z)
	root.add_child(loco)
	
	for bz in [-3.2, 3.2]:
		for bx in [-1.15, 1.15]:
			for wx in [-0.75, 0.75]:
				_add_cylinder(loco, 0.42, 0.22, Vector3(bx, 0.42, bz + wx), wheel_black, Vector3(0, 0, 90))
	
	_add_box(loco, Vector3(2.6, 0.45, 9.4), Vector3(0.0, 0.85, 0.0), steel_gray)
	_add_box(loco, Vector3(2.7, 0.55, 0.5), Vector3(0.0, 0.55, -4.7), bright_yellow)
	_add_box(loco, Vector3(2.4, 2.1, 6.4), Vector3(0.0, 2.05, 0.9), dark_navy)
	_add_box(loco, Vector3(2.5, 2.4, 2.6), Vector3(0.0, 2.2, -3.2), dark_navy)
	_add_box(loco, Vector3(2.55, 0.25, 2.8), Vector3(0.0, 3.45, -3.2), bright_yellow)
	_add_box(loco, Vector3(2.1, 0.85, 0.1), Vector3(0.0, 2.65, -4.52), Color("ffeaa7"), true)
	_add_cylinder(loco, 0.25, 0.15, Vector3(-0.45, 1.85, -4.72), Color("fff200"), Vector3(90, 0, 0), true)
	_add_cylinder(loco, 0.25, 0.15, Vector3(0.45, 1.85, -4.72), Color("fff200"), Vector3(90, 0, 0), true)
	
	var t_light := OmniLight3D.new()
	t_light.name = "TrainHeadlight"
	t_light.light_color = Color("fff200")
	t_light.light_energy = 3.5
	t_light.omni_range = 18.0
	t_light.position = Vector3(0.0, 1.85, -5.5)
	loco.add_child(t_light)
	
	_add_cylinder(loco, 0.30, 0.75, Vector3(0.0, 3.3, 0.5), steel_gray)
	_add_cylinder(loco, 0.30, 0.75, Vector3(0.0, 3.3, 2.2), steel_gray)
	_add_train_collider(loco, Vector3(2.6, 2.8, 9.4), Vector3(0.0, 1.4, 0.0))
	
	cur_z += 10.8
	
	# 2. CARGO BOXCAR
	var boxcar := Node3D.new()
	boxcar.name = "Boxcar"
	boxcar.position = Vector3(0.0, 0.0, cur_z)
	root.add_child(boxcar)
	for bz in [-2.8, 2.8]:
		for bx in [-1.15, 1.15]:
			for wx in [-0.75, 0.75]:
				_add_cylinder(boxcar, 0.40, 0.20, Vector3(bx, 0.40, bz + wx), wheel_black, Vector3(0, 0, 90))
	_add_box(boxcar, Vector3(2.5, 0.35, 8.4), Vector3(0.0, 0.80, 0.0), steel_gray)
	_add_box(boxcar, Vector3(2.4, 2.4, 8.2), Vector3(0.0, 2.15, 0.0), boxcar_red)
	for rz in range(-3, 4):
		_add_box(boxcar, Vector3(2.44, 2.4, 0.14), Vector3(0.0, 2.15, float(rz) * 1.15), Color("e74c3c"))
	_add_box(boxcar, Vector3(2.46, 1.1, 2.4), Vector3(0.0, 2.2, 0.0), Color("f5f6fa"))
	_add_train_collider(boxcar, Vector3(2.5, 2.6, 8.4), Vector3(0.0, 1.35, 0.0))
	
	cur_z += 9.6
	
	# 3. TANKER
	var tanker := Node3D.new()
	tanker.name = "Tanker"
	tanker.position = Vector3(0.0, 0.0, cur_z)
	root.add_child(tanker)
	for bz in [-2.8, 2.8]:
		for bx in [-1.15, 1.15]:
			for wx in [-0.75, 0.75]:
				_add_cylinder(tanker, 0.40, 0.20, Vector3(bx, 0.40, bz + wx), wheel_black, Vector3(0, 0, 90))
	_add_box(tanker, Vector3(2.5, 0.35, 8.4), Vector3(0.0, 0.80, 0.0), steel_gray)
	_add_cylinder(tanker, 1.25, 7.8, Vector3(0.0, 2.15, 0.0), tanker_blue, Vector3(90, 0, 0))
	_add_sphere(tanker, 1.25, Vector3(0.0, 2.15, -3.9), tanker_blue)
	_add_sphere(tanker, 1.25, Vector3(0.0, 2.15, 3.9), tanker_blue)
	_add_box(tanker, Vector3(1.1, 0.08, 6.8), Vector3(0.0, 3.45, 0.0), steel_gray)
	_add_cylinder(tanker, 0.45, 0.4, Vector3(0.0, 3.6, 0.0), Color("f1c40f"))
	_add_train_collider(tanker, Vector3(2.5, 2.6, 8.4), Vector3(0.0, 1.35, 0.0))
	
	cur_z += 9.6
	
	# 4. FLATBED
	var flatbed := Node3D.new()
	flatbed.name = "Flatbed"
	flatbed.position = Vector3(0.0, 0.0, cur_z)
	root.add_child(flatbed)
	for bz in [-2.8, 2.8]:
		for bx in [-1.15, 1.15]:
			for wx in [-0.75, 0.75]:
				_add_cylinder(flatbed, 0.40, 0.20, Vector3(bx, 0.40, bz + wx), wheel_black, Vector3(0, 0, 90))
	_add_box(flatbed, Vector3(2.6, 0.4, 8.4), Vector3(0.0, 0.80, 0.0), flatbed_orange)
	_add_box(flatbed, Vector3(2.35, 1.6, 3.8), Vector3(0.0, 1.80, -1.95), Color("27ae60"))
	_add_box(flatbed, Vector3(2.35, 1.6, 3.8), Vector3(0.0, 1.80, 1.95), Color("f1c40f"))
	_add_train_collider(flatbed, Vector3(2.6, 2.2, 8.4), Vector3(0.0, 1.1, 0.0))
	
	cur_z += 9.6
	
	# 5. CABOOSE
	var caboose := Node3D.new()
	caboose.name = "Caboose"
	caboose.position = Vector3(0.0, 0.0, cur_z)
	root.add_child(caboose)
	for bz in [-2.2, 2.2]:
		for bx in [-1.15, 1.15]:
			for wx in [-0.65, 0.65]:
				_add_cylinder(caboose, 0.38, 0.20, Vector3(bx, 0.38, bz + wx), wheel_black, Vector3(0, 0, 90))
	_add_box(caboose, Vector3(2.5, 0.35, 7.2), Vector3(0.0, 0.75, 0.0), steel_gray)
	_add_box(caboose, Vector3(2.3, 2.0, 5.6), Vector3(0.0, 1.95, 0.0), boxcar_red)
	_add_box(caboose, Vector3(1.8, 0.9, 2.2), Vector3(0.0, 3.35, 0.0), boxcar_red)
	_add_box(caboose, Vector3(1.85, 0.35, 2.0), Vector3(0.0, 3.35, 0.0), Color("ffeaa7"), true)
	_add_cylinder(caboose, 0.16, 0.12, Vector3(0.0, 1.85, 3.65), Color("ff0000"), Vector3(90, 0, 0), true)
	_add_train_collider(caboose, Vector3(2.5, 2.6, 7.2), Vector3(0.0, 1.35, 0.0))
	
	return root

## Multi-arch stone roadway bridge with decorative balustrades and streetlamps
func build_arched_stone_bridge(width: float = 12.0, span: float = 14.0) -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelArchedStoneBridge"
	
	var stone_col := Color("95a5a6")
	var deck_col := Color("1e272e")
	
	_add_box(root, Vector3(width, 0.45, span), Vector3(0.0, -0.22, 0.0), deck_col)
	_add_box(root, Vector3(0.25, 0.04, span), Vector3(0.0, 0.02, 0.0), Color("f1c40f"))
	
	for sx in [-width * 0.5 + 0.25, width * 0.5 - 0.25]:
		_add_box(root, Vector3(0.5, 0.85, span), Vector3(sx, 0.425, 0.0), stone_col)
		var cz: float = -span * 0.5 + 1.2
		while cz <= span * 0.5:
			_add_box(root, Vector3(0.65, 0.95, 0.45), Vector3(sx, 0.475, cz), stone_col.darkened(0.12))
			cz += 2.4
	
	for px in [-width * 0.35, width * 0.35]:
		_add_box(root, Vector3(1.8, 2.4, span * 0.75), Vector3(px, -1.6, 0.0), stone_col)
	
	_add_cylinder(root, 2.8, width * 0.9, Vector3(0.0, -1.8, 0.0), Color("0d1117"), Vector3(0, 0, 90))
	
	return root

## Heavy industrial Warren through-truss steel railway bridge
func build_railway_girder_bridge(span: float = 14.0) -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelRailwayGirderBridge"
	
	var truss_red := Color("c0392b")
	var steel_gray := Color("2c3e50")
	var rail_silver := Color("dfe6e9")
	
	_add_box(root, Vector3(7.4, 0.4, span), Vector3(0.0, -0.2, 0.0), steel_gray)
	for rx in [-2.5, -1.1, 1.1, 2.5]:
		_add_box(root, Vector3(0.12, 0.18, span), Vector3(rx, 0.1, 0.0), rail_silver)
	
	for gx in [-3.8, 3.8]:
		_add_box(root, Vector3(0.4, 0.4, span), Vector3(gx, 0.2, 0.0), truss_red)
		_add_box(root, Vector3(0.4, 0.4, span), Vector3(gx, 4.4, 0.0), truss_red)
		var vz: float = -span * 0.5 + 1.4
		while vz <= span * 0.5:
			_add_box(root, Vector3(0.35, 4.0, 0.35), Vector3(gx, 2.3, vz), truss_red)
			_add_box(root, Vector3(0.25, 4.4, 0.25), Vector3(gx, 2.3, vz + 1.4), truss_red, false, Vector3(32, 0, 0))
			vz += 2.8
	
	var oz: float = -span * 0.5 + 1.4
	while oz <= span * 0.5:
		_add_box(root, Vector3(8.0, 0.35, 0.35), Vector3(0.0, 4.4, oz), truss_red)
		oz += 2.8
	
	for px in [-3.5, 3.5]:
		_add_box(root, Vector3(1.2, 2.6, 2.2), Vector3(px, -1.5, -span * 0.4), steel_gray)
		_add_box(root, Vector3(1.2, 2.6, 2.2), Vector3(px, -1.5, span * 0.4), steel_gray)
	
	return root

## Stone canal quay retaining wall with safety bollards, lifebuoy, and drain pipe
func build_canal_quay_wall(length: float = 48.0) -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelCanalQuayWall"
	
	var stone_col := Color("636e72")
	var bollard_col := Color("2d3436")
	
	# Retaining wall running along X (East-West river bank)
	_add_box(root, Vector3(length, 2.4, 1.2), Vector3(0.0, -1.2, 0.0), stone_col)
	_add_box(root, Vector3(length, 0.25, 1.4), Vector3(0.0, 0.05, 0.0), stone_col.lightened(0.15))
	
	# Cast iron mooring bollards spaced every 8m along the quay
	var bx: float = -length * 0.5 + 4.0
	while bx <= length * 0.5:
		_add_cylinder(root, 0.16, 0.45, Vector3(bx, 0.38, -0.35), bollard_col)
		_add_sphere(root, 0.20, Vector3(bx, 0.62, -0.35), bollard_col)
		bx += 8.0
	
	# Emergency rescue lifebuoy hanging on canal water-facing side (+Z)
	_add_torus(root, 0.28, 0.38, Vector3(0.0, -0.65, 0.62), Color("e74c3c"), Vector3(0, 0, 0))
	_add_box(root, Vector3(0.8, 0.12, 0.04), Vector3(0.0, -0.65, 0.62), Color("f5f6fa"))
	
	# Stormwater drainage outfall culvert pipe recessed into stone quay
	_add_cylinder(root, 0.45, 0.8, Vector3(-6.0, -1.4, 0.55), Color("2f3542"), Vector3(90, 0, 0))
	_add_cylinder(root, 0.35, 0.82, Vector3(-6.0, -1.4, 0.55), Color("0d1117"), Vector3(90, 0, 0))
	
	return root

