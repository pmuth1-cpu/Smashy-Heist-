class_name VoxelCarBuilder
extends RefCounted

## Procedural Voxel Vehicle Assembler for Smashy Heist
## Builds high-detail 3D blocky models for the 30 COMMON-Tier vehicles and future expansions.
## Features multi-element lighting, mirrors, door handles, license plates, visible interior,
## wipers, exhaust systems, structural pillars, and bespoke vehicle embellishments.

static func build_car(car_id: String, info: Dictionary, vab: Node) -> Node3D:
	var root := Node3D.new()
	root.name = "VoxelCarModel_%s" % car_id
	
	var recipe: Dictionary = info.get("recipe", {})
	var archetype: String = String(recipe.get("archetype", "ARCHETYPE_COUPE"))
	
	match archetype:
		"ARCHETYPE_COUPE":
			_build_coupe(root, car_id, recipe, vab)
		"ARCHETYPE_MUSCLE":
			_build_muscle(root, car_id, recipe, vab)
		"ARCHETYPE_OFFROAD":
			_build_offroad(root, car_id, recipe, vab)
		"ARCHETYPE_HEAVY":
			_build_heavy(root, car_id, recipe, vab)
		"ARCHETYPE_VAN":
			_build_van(root, car_id, recipe, vab)
		"ARCHETYPE_BUS":
			_build_bus(root, car_id, recipe, vab)
		"ARCHETYPE_NOVELTY":
			_build_novelty(root, car_id, recipe, vab)
		_:
			_build_coupe(root, car_id, recipe, vab)
			
	return root

# =============================================================================
# REUSABLE ULTRA-DETAIL SUBROUTINES
# =============================================================================

## Side wing mirrors with body-colored housing and silver reflective faces
static func _add_side_mirrors(root: Node3D, b_wid: float, mirror_y: float, mirror_z: float, body_col: Color, vab: Node) -> void:
	for side_x in [-1.0, 1.0]:
		var mx: float = (b_wid * 0.5 + 0.05) * side_x
		# Mirror stalk / housing
		vab._add_box(root, Vector3(0.12, 0.08, 0.10), Vector3(mx, mirror_y, mirror_z), body_col)
		# Reflective mirror glass face
		vab._add_box(root, Vector3(0.02, 0.06, 0.08), Vector3(mx + 0.055 * side_x, mirror_y, mirror_z), Color("d2dae2"))

## Chrome / black flush door handles on left & right flanks
static func _add_door_handles(root: Node3D, b_wid: float, handle_y: float, z_positions: Array, vab: Node, is_chrome: bool = true) -> void:
	var h_col: Color = Color("d2dae2") if is_chrome else Color("1e272e")
	for side_x in [-1.0, 1.0]:
		var hx: float = (b_wid * 0.5 + 0.015) * side_x
		for hz in z_positions:
			vab._add_box(root, Vector3(0.03, 0.04, 0.12), Vector3(hx, handle_y, float(hz)), h_col)

## Front & rear embossed license plates with contrast border
static func _add_license_plates(root: Node3D, b_len: float, front_y: float, rear_y: float, vab: Node) -> void:
	# Front Plate (White with dark border)
	vab._add_box(root, Vector3(0.38, 0.12, 0.02), Vector3(0.0, front_y, -b_len * 0.5 - 0.065), Color("1e272e"))
	vab._add_box(root, Vector3(0.34, 0.09, 0.02), Vector3(0.0, front_y, -b_len * 0.5 - 0.075), Color("f5f6fa"))
	# Rear Plate (Yellow/White with dark border)
	vab._add_box(root, Vector3(0.38, 0.12, 0.02), Vector3(0.0, rear_y, b_len * 0.5 + 0.065), Color("1e272e"))
	vab._add_box(root, Vector3(0.34, 0.09, 0.02), Vector3(0.0, rear_y, b_len * 0.5 + 0.075), Color("f1c40f"))

## Multi-element cluster headlights (projector high-beam + amber corner blinker)
static func _add_headlights(root: Node3D, b_wid: float, b_len: float, light_y: float, vab: Node) -> void:
	var lx: float = b_wid * 0.36
	var lz: float = -b_len * 0.5 - 0.02
	# Left cluster: Warm yellow high beam + Amber corner turn signal
	vab._add_box(root, Vector3(0.18, 0.11, 0.04), Vector3(-lx, light_y, lz), Color("fff200"), true)
	vab._add_box(root, Vector3(0.08, 0.11, 0.04), Vector3(-lx - 0.12, light_y, lz), Color("e67e22"), true)
	# Right cluster: Warm yellow high beam + Amber corner turn signal
	vab._add_box(root, Vector3(0.18, 0.11, 0.04), Vector3(lx, light_y, lz), Color("fff200"), true)
	vab._add_box(root, Vector3(0.08, 0.11, 0.04), Vector3(lx + 0.12, light_y, lz), Color("e67e22"), true)

## Multi-element cluster taillights (crimson brake light + amber signal + white reverse lamp)
static func _add_taillights(root: Node3D, b_wid: float, b_len: float, light_y: float, vab: Node) -> void:
	var rx: float = b_wid * 0.36
	var rz: float = b_len * 0.5 + 0.02
	# Left cluster
	vab._add_box(root, Vector3(0.18, 0.10, 0.04), Vector3(-rx, light_y, rz), Color("ff3838"), true)
	vab._add_box(root, Vector3(0.07, 0.10, 0.04), Vector3(-rx - 0.11, light_y, rz), Color("e67e22"), true)
	vab._add_box(root, Vector3(0.07, 0.10, 0.04), Vector3(-rx + 0.11, light_y, rz), Color("f5f6fa"), true)
	# Right cluster
	vab._add_box(root, Vector3(0.18, 0.10, 0.04), Vector3(rx, light_y, rz), Color("ff3838"), true)
	vab._add_box(root, Vector3(0.07, 0.10, 0.04), Vector3(rx + 0.11, light_y, rz), Color("e67e22"), true)
	vab._add_box(root, Vector3(0.07, 0.10, 0.04), Vector3(rx - 0.11, light_y, rz), Color("f5f6fa"), true)

## Polished chrome exhaust tips with dark inner hollow
static func _add_exhaust_pipes(root: Node3D, b_len: float, exh_y: float, positions_x: Array, vab: Node, is_large_tuner: bool = false) -> void:
	var rad: float = 0.075 if is_large_tuner else 0.048
	var hgt: float = 0.22 if is_large_tuner else 0.16
	for ex in positions_x:
		# Chrome outer shroud
		vab._add_cylinder(root, rad, hgt, Vector3(float(ex), exh_y, b_len * 0.5 + hgt * 0.45), Color("d2dae2"), Vector3(90, 0, 0))
		# Dark hollow interior opening
		vab._add_cylinder(root, rad * 0.72, 0.04, Vector3(float(ex), exh_y, b_len * 0.5 + hgt * 0.95), Color("1e272e"), Vector3(90, 0, 0))

## Windshield wiper blades lying flat on the cowl
static func _add_windshield_wipers(root: Node3D, cowl_y: float, cowl_z: float, vab: Node) -> void:
	vab._add_box(root, Vector3(0.24, 0.02, 0.03), Vector3(-0.20, cowl_y, cowl_z), Color("1e272e"), false, Vector3(0, 14, 0))
	vab._add_box(root, Vector3(0.24, 0.02, 0.03), Vector3(0.20, cowl_y, cowl_z), Color("1e272e"), false, Vector3(0, 14, 0))

## Visible interior cockpit (dashboard, angled steering wheel column, driver/passenger headrests)
static func _add_interior_cockpit(root: Node3D, cab_wid: float, cab_y: float, cab_z: float, vab: Node) -> void:
	var dark_interior := Color("2f3640")
	# Dark dashboard
	vab._add_box(root, Vector3(cab_wid * 0.88, 0.14, 0.26), Vector3(0.0, cab_y - 0.08, cab_z - 0.30), dark_interior)
	# Angled steering wheel on left side
	vab._add_cylinder(root, 0.09, 0.03, Vector3(-cab_wid * 0.28, cab_y + 0.04, cab_z - 0.22), Color("1e272e"), Vector3(25, 0, 0))
	# Driver & Passenger headrests
	vab._add_box(root, Vector3(0.18, 0.18, 0.14), Vector3(-cab_wid * 0.26, cab_y + 0.10, cab_z + 0.12), dark_interior)
	vab._add_box(root, Vector3(0.18, 0.18, 0.14), Vector3(cab_wid * 0.26, cab_y + 0.10, cab_z + 0.12), dark_interior)

## Structural window pillars (A-pillar, B-pillar, C-pillar)
static func _add_window_pillars(root: Node3D, cab_wid: float, cab_hgt: float, cab_len: float, cab_y: float, cab_z: float, pillar_col: Color, vab: Node) -> void:
	var pw: float = 0.05
	# A-Pillars (Front left/right corners)
	vab._add_box(root, Vector3(pw, cab_hgt * 0.85, pw), Vector3(-cab_wid * 0.5 + pw * 0.5, cab_y, cab_z - cab_len * 0.46), pillar_col)
	vab._add_box(root, Vector3(pw, cab_hgt * 0.85, pw), Vector3(cab_wid * 0.5 - pw * 0.5, cab_y, cab_z - cab_len * 0.46), pillar_col)
	# B-Pillars (Center door pillars)
	vab._add_box(root, Vector3(pw, cab_hgt * 0.85, pw * 1.5), Vector3(-cab_wid * 0.5 + pw * 0.5, cab_y, cab_z), Color("1e272e"))
	vab._add_box(root, Vector3(pw, cab_hgt * 0.85, pw * 1.5), Vector3(cab_wid * 0.5 - pw * 0.5, cab_y, cab_z), Color("1e272e"))
	# C-Pillars (Rear quarters)
	vab._add_box(root, Vector3(pw * 1.6, cab_hgt * 0.85, pw * 2.0), Vector3(-cab_wid * 0.5 + pw * 0.8, cab_y, cab_z + cab_len * 0.44), pillar_col)
	vab._add_box(root, Vector3(pw * 1.6, cab_hgt * 0.85, pw * 2.0), Vector3(cab_wid * 0.5 - pw * 0.8, cab_y, cab_z + cab_len * 0.44), pillar_col)


# =============================================================================
# 1. ARCHETYPE: COUPE / HATCHBACK / RUNABOUT
# =============================================================================
static func _build_coupe(root: Node3D, car_id: String, recipe: Dictionary, vab: Node) -> void:
	var prim: Color = recipe.get("primary_color", Color("e84118"))
	var sec: Color = recipe.get("secondary_color", Color("f5f6fa"))
	var win: Color = recipe.get("window_color", Color("1b9cfc"))
	var wr: float = float(recipe.get("wheel_radius", 0.28))
	var ww: float = float(recipe.get("wheel_width", 0.18))
	var tx: float = float(recipe.get("track_x", 0.60))
	var wz: float = float(recipe.get("wheelbase_z", 0.75))
	var b_len: float = float(recipe.get("body_length", 2.24))
	var b_wid: float = float(recipe.get("body_width", 1.18))
	var b_hgt: float = float(recipe.get("body_height", 0.36))
	
	# Underbody frame & rocker panels
	vab._add_box(root, Vector3(b_wid - 0.06, 0.18, b_len), Vector3(0.0, 0.06, 0.0), Color("1e272e"))
	vab._add_box(root, Vector3(0.08, 0.10, wz * 1.6), Vector3(-b_wid * 0.5 - 0.02, 0.12, 0.0), Color("2f3640"))
	vab._add_box(root, Vector3(0.08, 0.10, wz * 1.6), Vector3(b_wid * 0.5 + 0.02, 0.12, 0.0), Color("2f3640"))
	
	vab._add_flared_wheel_wells(root, tx, wz, prim)
	vab._add_wheels(root, wr, ww, tx, wz)
	
	# Main lower body & hood
	vab._add_box(root, Vector3(b_wid, b_hgt, b_len), Vector3(0.0, 0.24, 0.0), prim)
	
	# Aerodynamic front chin lip splitter
	vab._add_box(root, Vector3(b_wid + 0.04, 0.06, 0.16), Vector3(0.0, 0.08, -b_len * 0.5 - 0.07), Color("1e272e"))
	
	# Front Radiator Grille
	vab._add_box(root, Vector3(b_wid * 0.55, 0.16, 0.04), Vector3(0.0, 0.23, -b_len * 0.5 - 0.01), Color("2f3640"))
	
	# Cabin Greenhouse & Tinted Glass
	var cab_len: float = b_len * 0.48
	var cab_wid: float = b_wid * 0.84
	var cab_hgt: float = b_hgt * 0.95
	var cab_z: float = wz * 0.10
	var cab_y: float = 0.24 + b_hgt * 0.85
	
	vab._add_box(root, Vector3(cab_wid, cab_hgt, cab_len), Vector3(0.0, cab_y, cab_z), Color("1e272e"))
	vab._add_box(root, Vector3(cab_wid + 0.02, cab_hgt * 0.78, cab_len * 0.88), Vector3(0.0, cab_y, cab_z), win)
	
	# Roof panel cap
	vab._add_box(root, Vector3(cab_wid - 0.02, 0.06, cab_len - 0.04), Vector3(0.0, cab_y + cab_hgt * 0.5 + 0.02, cab_z), prim)
	
	# Micro Details: Pillars, Interior, Mirrors, Handles, Lights, Exhaust, Wipers, Plates
	_add_window_pillars(root, cab_wid, cab_hgt, cab_len, cab_y, cab_z, prim, vab)
	_add_interior_cockpit(root, cab_wid, cab_y, cab_z, vab)
	_add_side_mirrors(root, b_wid, cab_y - 0.02, cab_z - cab_len * 0.38, prim, vab)
	_add_door_handles(root, b_wid, 0.30, [cab_z - 0.08, cab_z + 0.22], vab, true)
	_add_headlights(root, b_wid, b_len, 0.26, vab)
	_add_taillights(root, b_wid, b_len, 0.26, vab)
	_add_windshield_wipers(root, 0.42, cab_z - cab_len * 0.5 - 0.08, vab)
	_add_license_plates(root, b_len, 0.14, 0.14, vab)
	
	# Dual chrome exhaust tips
	_add_exhaust_pipes(root, b_len, 0.12, [-0.28, 0.28], vab, false)
	
	# Car-specific bespoke touches
	match car_id:
		"drift_panda":
			# Iconic two-tone black rocker panels & black rear ducktail
			vab._add_box(root, Vector3(b_wid + 0.03, 0.12, b_len * 0.98), Vector3(0.0, 0.14, 0.0), Color("1e272e"))
			vab._add_box(root, Vector3(b_wid * 0.88, 0.08, 0.12), Vector3(0.0, 0.44, b_len * 0.48), Color("1e272e"), false, Vector3(-18, 0, 0))
		"turbo_civic":
			# Red Type-R badge + Carbon hood vent scoop
			vab._add_box(root, Vector3(0.10, 0.08, 0.02), Vector3(0.0, 0.24, -b_len * 0.5 - 0.02), Color("e74c3c"), true)
			vab._add_box(root, Vector3(0.32, 0.04, 0.28), Vector3(0.0, 0.44, -b_len * 0.25), Color("2f3640"))
		"euro_gti":
			# Iconic red grille trim line
			vab._add_box(root, Vector3(b_wid * 0.55, 0.03, 0.05), Vector3(0.0, 0.28, -b_len * 0.5 - 0.01), Color("e84118"), true)
		"rotary_bullet":
			# Carbon hood scoop, widebody side aero skirts, and titanium burnt exhaust tip
			vab._add_box(root, Vector3(0.36, 0.05, 0.32), Vector3(0.0, 0.44, -b_len * 0.22), Color("2f3640"))
			vab._add_box(root, Vector3(b_wid + 0.06, 0.08, wz * 1.5), Vector3(0.0, 0.12, 0.0), Color("2f3640"))
			vab._add_cylinder(root, 0.08, 0.24, Vector3(-0.35, 0.12, b_len * 0.5 + 0.12), Color("3498db"), Vector3(90, 0, 0))
		"skyline_phantom":
			# Front intercooler mesh box & NISMO style side skirts & quad round taillights
			vab._add_box(root, Vector3(0.65, 0.18, 0.06), Vector3(0.0, 0.18, -b_len * 0.5 - 0.02), Color("dfe6e9"))
			vab._add_box(root, Vector3(b_wid + 0.05, 0.06, wz * 1.6), Vector3(0.0, 0.11, 0.0), Color("2d3436"))
		"stance_boxer":
			# Aggressive hood scoop & underbody diffuser fins & WRC wing stabilizing fins
			vab._add_box(root, Vector3(0.42, 0.08, 0.35), Vector3(0.0, 0.46, -b_len * 0.24), prim)
			vab._add_box(root, Vector3(0.40, 0.04, 0.08), Vector3(0.0, 0.46, -b_len * 0.24 - 0.16), Color("1e272e"))
			for dx in [-0.35, 0.0, 0.35]:
				vab._add_box(root, Vector3(0.04, 0.08, 0.24), Vector3(dx, 0.08, b_len * 0.5), Color("1e272e"))
		"interceptor_pursuit":
			# A-pillar dual spotlights & rear deck warning flashers
			vab._add_cylinder(root, 0.05, 0.08, Vector3(-b_wid * 0.46, 0.56, cab_z - cab_len * 0.35), Color("1e272e"), Vector3(0, 0, 90))
			vab._add_cylinder(root, 0.05, 0.08, Vector3(b_wid * 0.46, 0.56, cab_z - cab_len * 0.35), Color("1e272e"), Vector3(0, 0, 90))
		"classic_57_tailfin":
			# Sweeping rear chrome tailfins with silver ribbed anodized inserts & whitewall rims
			for side_x in [-1.0, 1.0]:
				var fx: float = (b_wid * 0.5 - 0.02) * side_x
				vab._add_box(root, Vector3(0.04, 0.22, 0.75), Vector3(fx, 0.46, b_len * 0.5 - 0.30), sec)
				vab._add_box(root, Vector3(0.05, 0.04, 0.72), Vector3(fx, 0.56, b_len * 0.5 - 0.30), Color("d2dae2"))
			vab._add_cylinder(root, 0.08, 0.14, Vector3(-0.35, 0.16, -b_len * 0.5 - 0.12), Color("d2dae2"), Vector3(90, 0, 0))
			vab._add_cylinder(root, 0.08, 0.14, Vector3(0.35, 0.16, -b_len * 0.5 - 0.12), Color("d2dae2"), Vector3(90, 0, 0))
		"gangster_v8_32":
			# Tall upright chrome radiator shell with winged goddess cap & wooden running boards
			vab._add_box(root, Vector3(0.55, 0.45, 0.12), Vector3(0.0, 0.38, -b_len * 0.5 - 0.02), Color("d2dae2"))
			vab._add_cylinder(root, 0.03, 0.08, Vector3(0.0, 0.64, -b_len * 0.5 - 0.02), Color("d2dae2"))
			vab._add_box(root, Vector3(0.14, 0.04, wz * 1.5), Vector3(-b_wid * 0.5 - 0.06, 0.14, 0.0), Color("8b5a2b"))
			vab._add_box(root, Vector3(0.14, 0.04, wz * 1.5), Vector3(b_wid * 0.5 + 0.06, 0.14, 0.0), Color("8b5a2b"))
			vab._add_cylinder(root, wr * 0.95, ww * 0.9, Vector3(0.0, 0.36, b_len * 0.5 + 0.14), Color("1e272e"), Vector3(90, 0, 0))
		"amphicar_aquasport":
			# Upward-swept boat hull prow & twin rear brass propellers
			vab._add_box(root, Vector3(b_wid * 0.85, 0.12, 0.35), Vector3(0.0, 0.14, -b_len * 0.5 - 0.12), sec, false, Vector3(-15, 0, 0))
			vab._add_cylinder(root, 0.09, 0.04, Vector3(-0.25, 0.08, b_len * 0.5 + 0.08), Color("f1c40f"), Vector3(90, 0, 0))
			vab._add_cylinder(root, 0.09, 0.04, Vector3(0.25, 0.08, b_len * 0.5 + 0.08), Color("f1c40f"), Vector3(90, 0, 0))
			vab._add_cylinder(root, 0.015, 0.35, Vector3(b_wid * 0.38, 0.55, b_len * 0.45), Color("d2dae2"))
			vab._add_box(root, Vector3(0.04, 0.04, 0.04), Vector3(b_wid * 0.38, 0.72, b_len * 0.45), Color("ffffff"), true)
		"midnight_supra":
			# Iconic high curved hoop wing, front intercooler mesh cutout, dual hood vents & cannon exhaust
			vab._add_box(root, Vector3(0.72, 0.20, 0.08), Vector3(0.0, 0.18, -b_len * 0.5 - 0.02), Color("dfe6e9")) # Front FMIC
			vab._add_box(root, Vector3(0.20, 0.05, 0.35), Vector3(-0.25, 0.44, -b_len * 0.24), Color("1e272e")) # Hood vent L
			vab._add_box(root, Vector3(0.20, 0.05, 0.35), Vector3(0.25, 0.44, -b_len * 0.24), Color("1e272e")) # Hood vent R
			for sx in [-0.48, 0.48]:
				vab._add_box(root, Vector3(0.05, 0.32, 0.14), Vector3(sx, 0.52, b_len * 0.46), prim)
			vab._add_box(root, Vector3(1.05, 0.06, 0.28), Vector3(0.0, 0.68, b_len * 0.46), prim)
			vab._add_cylinder(root, 0.09, 0.28, Vector3(0.38, 0.12, b_len * 0.5 + 0.14), Color("00d2d3"), Vector3(85, 10, 0))
		"racer_01":
			# Carbon GT3 swan-neck wing, front bumper canards, wide aero skirts & 4-fin diffuser
			vab._add_box(root, Vector3(b_wid + 0.08, 0.05, wz * 1.55), Vector3(0.0, 0.10, 0.0), Color("1e272e"))
			for side_x in [-1.0, 1.0]:
				vab._add_box(root, Vector3(0.18, 0.03, 0.12), Vector3((b_wid * 0.5 + 0.04) * side_x, 0.22, -b_len * 0.48), Color("1e272e"), false, Vector3(0, 0, -15 * side_x))
				vab._add_box(root, Vector3(0.15, 0.03, 0.10), Vector3((b_wid * 0.5 + 0.03) * side_x, 0.28, -b_len * 0.46), Color("1e272e"), false, Vector3(0, 0, -15 * side_x))
			vab._add_box(root, Vector3(1.18, 0.05, 0.30), Vector3(0.0, 0.72, b_len * 0.46), Color("1e272e"))
			vab._add_box(root, Vector3(0.05, 0.32, 0.15), Vector3(-0.35, 0.56, b_len * 0.44), Color("1e272e"))
			vab._add_box(root, Vector3(0.05, 0.32, 0.15), Vector3(0.35, 0.56, b_len * 0.44), Color("1e272e"))
			for df in [-0.36, -0.12, 0.12, 0.36]:
				vab._add_box(root, Vector3(0.03, 0.10, 0.22), Vector3(df, 0.08, b_len * 0.5), Color("1e272e"))
		"veloce_v12":
			# Extreme 90s wedge nose, roof snorkel air duct, scissor door lines & quad high central exhaust
			vab._add_box(root, Vector3(b_wid * 0.92, 0.14, 0.45), Vector3(0.0, 0.22, -b_len * 0.5 - 0.12), prim, false, Vector3(-12, 0, 0))
			vab._add_box(root, Vector3(0.24, 0.12, cab_len * 0.8), Vector3(0.0, cab_y + cab_hgt * 0.5 + 0.06, cab_z - 0.10), prim)
			vab._add_cylinder(root, 0.07, 0.12, Vector3(0.0, cab_y + cab_hgt * 0.5 + 0.10, cab_z - cab_len * 0.4), Color("1e272e"), Vector3(90, 0, 0))
			for ex in [-0.15, -0.05, 0.05, 0.15]:
				vab._add_cylinder(root, 0.04, 0.16, Vector3(ex, 0.28, b_len * 0.5 + 0.08), Color("d2dae2"), Vector3(90, 0, 0))
		"bull_centenario":
			# Carbon aero fangs, yellow pinstriped 6-fin rear diffuser & triple hex central exhaust
			vab._add_box(root, Vector3(b_wid + 0.08, 0.04, 0.35), Vector3(0.0, 0.10, -b_len * 0.5 - 0.10), Color("1e272e"))
			vab._add_box(root, Vector3(b_wid + 0.09, 0.02, 0.04), Vector3(0.0, 0.11, -b_len * 0.5 - 0.27), Color("f1c40f"), true)
			for d in range(6):
				var dx: float = -0.45 + d * 0.18
				vab._add_box(root, Vector3(0.03, 0.14, 0.28), Vector3(dx, 0.09, b_len * 0.5), Color("1e272e"))
				vab._add_box(root, Vector3(0.03, 0.02, 0.28), Vector3(dx, 0.02, b_len * 0.5), Color("f1c40f"), true)
			vab._add_cylinder(root, 0.05, 0.18, Vector3(-0.09, 0.24, b_len * 0.5 + 0.08), Color("d2dae2"), Vector3(90, 0, 0))
			vab._add_cylinder(root, 0.05, 0.18, Vector3(0.0, 0.27, b_len * 0.5 + 0.08), Color("d2dae2"), Vector3(90, 0, 0))
			vab._add_cylinder(root, 0.05, 0.18, Vector3(0.09, 0.24, b_len * 0.5 + 0.08), Color("d2dae2"), Vector3(90, 0, 0))
		"gullwing_300sl":
			# Chrome star grille, twin hood power bulges, side fender gill air vents
			vab._add_box(root, Vector3(0.48, 0.20, 0.08), Vector3(0.0, 0.25, -b_len * 0.5 - 0.04), Color("d2dae2"))
			vab._add_box(root, Vector3(0.12, 0.04, 0.65), Vector3(-0.20, 0.44, -b_len * 0.22), prim)
			vab._add_box(root, Vector3(0.12, 0.04, 0.65), Vector3(0.20, 0.44, -b_len * 0.22), prim)
			for side_x in [-1.0, 1.0]:
				for g in range(3):
					vab._add_box(root, Vector3(0.03, 0.03, 0.12), Vector3((b_wid * 0.5 + 0.01) * side_x, 0.28 + g * 0.06, -wz * 0.25), Color("d2dae2"))
		"daytona_coupe_65":
			# Kamm tail chopped rear duckbill, white Le Mans stripes & side-exit lake pipes
			vab._add_box(root, Vector3(b_wid * 0.88, 0.16, 0.12), Vector3(0.0, 0.44, b_len * 0.48), prim, false, Vector3(-25, 0, 0))
			vab._add_box(root, Vector3(0.28, 0.02, b_len * 0.98), Vector3(-0.16, 0.43, 0.0), sec)
			vab._add_box(root, Vector3(0.28, 0.02, b_len * 0.98), Vector3(0.16, 0.43, 0.0), sec)
			vab._add_cylinder(root, 0.06, 1.35, Vector3(-b_wid * 0.52, 0.10, 0.0), Color("ffffff"), Vector3(90, 0, 0))
			vab._add_cylinder(root, 0.06, 1.35, Vector3(b_wid * 0.52, 0.10, 0.0), Color("ffffff"), Vector3(90, 0, 0))
		"delorean_time_dmc":
			# Brushed stainless steel, glowing blue flux capacitor unit & twin rear nuclear thruster cooling vents
			vab._add_box(root, Vector3(0.22, 0.18, 0.12), Vector3(0.0, cab_y - 0.02, cab_z + 0.18), Color("00d2d3"), true)
			vab._add_box(root, Vector3(0.38, 0.28, 0.35), Vector3(-0.35, 0.42, b_len * 0.45), Color("2f3640"))
			vab._add_box(root, Vector3(0.38, 0.28, 0.35), Vector3(0.35, 0.42, b_len * 0.45), Color("2f3640"))
			vab._add_cylinder(root, 0.025, b_len * 0.85, Vector3(-b_wid * 0.51, 0.32, 0.0), Color("e67e22"), Vector3(90, 0, 0))
			vab._add_cylinder(root, 0.025, b_len * 0.85, Vector3(b_wid * 0.51, 0.32, 0.0), Color("3498db"), Vector3(90, 0, 0))
		"cyber_interceptor":
			# Faceted cyberpunk angular body panels, cyan/magenta neon edge strips & twin vector thrusters
			vab._add_box(root, Vector3(b_wid + 0.04, 0.03, b_len * 0.95), Vector3(0.0, 0.12, 0.0), Color("00d2d3"), true)
			vab._add_box(root, Vector3(b_wid * 0.90, 0.02, 0.03), Vector3(0.0, 0.38, -b_len * 0.5), Color("e056fd"), true)
			vab._add_box(root, Vector3(0.26, 0.16, 0.22), Vector3(-0.32, 0.22, b_len * 0.5 + 0.08), Color("1e272e"))
			vab._add_box(root, Vector3(0.26, 0.16, 0.22), Vector3(0.32, 0.22, b_len * 0.5 + 0.08), Color("1e272e"))
			vab._add_box(root, Vector3(0.20, 0.10, 0.04), Vector3(-0.32, 0.22, b_len * 0.5 + 0.18), Color("00d2d3"), true)
			vab._add_box(root, Vector3(0.20, 0.10, 0.04), Vector3(0.32, 0.22, b_len * 0.5 + 0.18), Color("00d2d3"), true)
		"blade_runner_spinner":
			# Aerodynamic front enclosed wheel fairings with blue LEDs & underbody VTOL thrusters
			for side_x in [-1.0, 1.0]:
				vab._add_box(root, Vector3(0.12, 0.32, 0.65), Vector3((tx + 0.08) * side_x, 0.22, -wz), Color("2f3640"))
				vab._add_box(root, Vector3(0.13, 0.04, 0.60), Vector3((tx + 0.08) * side_x, 0.22, -wz), Color("00d2d3"), true)
			for vx in [-0.35, 0.35]:
				for vz in [-wz * 0.6, wz * 0.6]:
					vab._add_cylinder(root, 0.14, 0.05, Vector3(vx, 0.04, vz), Color("00d2d3"), Vector3.ZERO, true)
		"silhouette_wide":
			# Group 5 Super Silhouette: Boxed widebody, chin air dam with exposed oil cooler & braided lines, dual-deck wing
			vab._add_box(root, Vector3(b_wid + 0.16, 0.24, b_len * 0.45), Vector3(0.0, 0.22, wz * 0.5), Color("111111")) # Rear box fenders
			vab._add_box(root, Vector3(b_wid + 0.12, 0.22, b_len * 0.35), Vector3(0.0, 0.22, -wz * 0.5), Color("111111")) # Front box fenders
			vab._add_box(root, Vector3(b_wid + 0.14, 0.06, 0.35), Vector3(0.0, 0.08, -b_len * 0.5 - 0.15), Color("111111")) # Deep chin spoiler
			vab._add_box(root, Vector3(0.52, 0.18, 0.08), Vector3(0.0, 0.15, -b_len * 0.5 - 0.18), Color("dfe6e9")) # Front oil cooler core
			vab._add_cylinder(root, 0.02, 0.25, Vector3(-0.16, 0.24, -b_len * 0.5 - 0.08), Color("3498db"), Vector3(0, 0, 45)) # Blue braided line
			vab._add_cylinder(root, 0.02, 0.25, Vector3(0.16, 0.24, -b_len * 0.5 - 0.08), Color("e74c3c"), Vector3(0, 0, -45)) # Red braided line
			# Giant dual-deck box wing on extended endplates
			for sx in [-b_wid * 0.48, b_wid * 0.48]:
				vab._add_box(root, Vector3(0.04, 0.45, 0.38), Vector3(sx, 0.58, b_len * 0.46), prim)
			vab._add_box(root, Vector3(b_wid * 0.95, 0.04, 0.30), Vector3(0.0, 0.58, b_len * 0.46), Color("111111")) # Lower wing deck
			vab._add_box(root, Vector3(b_wid * 0.95, 0.04, 0.24), Vector3(0.0, 0.74, b_len * 0.46), prim) # Upper wing deck
			# Side-exit flame pipe
			vab._add_cylinder(root, 0.075, 0.16, Vector3(b_wid * 0.56, 0.10, 0.22), Color("3498db"), Vector3(0, 0, 90))
		"f1_street_kart":
			# Apex F1: Needle nose, 1.30m multi-element front wing with endplates, halo cockpit, DRS wing, rain light
			vab._add_box(root, Vector3(0.52, 0.22, 1.30), Vector3(0.0, 0.16, -b_len * 0.5 + 0.35), prim)
			vab._add_box(root, Vector3(1.30, 0.06, 0.32), Vector3(0.0, 0.08, -b_len * 0.5 - 0.08), sec) # Front wing main plane
			vab._add_box(root, Vector3(0.05, 0.18, 0.36), Vector3(-0.65, 0.14, -b_len * 0.5 - 0.08), prim) # Endplate L
			vab._add_box(root, Vector3(0.05, 0.18, 0.36), Vector3(0.65, 0.14, -b_len * 0.5 - 0.08), prim) # Endplate R
			# Sculpted sidepods with radiator inlets
			vab._add_box(root, Vector3(0.32, 0.20, 0.95), Vector3(-0.46, 0.14, 0.10), sec)
			vab._add_box(root, Vector3(0.32, 0.20, 0.95), Vector3(0.46, 0.14, 0.10), sec)
			# Halo safety arch + gold-visor driver helmet
			vab._add_cylinder(root, 0.16, 0.22, Vector3(0.0, 0.36, -0.06), Color("f1c40f")) # Helmet
			vab._add_box(root, Vector3(0.12, 0.06, 0.08), Vector3(0.0, 0.38, -0.14), Color("e67e22"), true) # Gold visor
			vab._add_box(root, Vector3(0.36, 0.05, 0.36), Vector3(0.0, 0.46, -0.06), sec) # Halo safety ring
			# DRS rear wing + red rain flasher
			vab._add_box(root, Vector3(0.05, 0.38, 0.28), Vector3(-0.55, 0.48, b_len * 0.46), sec)
			vab._add_box(root, Vector3(0.05, 0.38, 0.28), Vector3(0.55, 0.48, b_len * 0.46), sec)
			vab._add_box(root, Vector3(1.20, 0.05, 0.28), Vector3(0.0, 0.60, b_len * 0.46), prim) # Main wing
			vab._add_box(root, Vector3(1.20, 0.04, 0.18), Vector3(0.0, 0.68, b_len * 0.46), prim) # DRS flap
			vab._add_box(root, Vector3(0.08, 0.08, 0.04), Vector3(0.0, 0.16, b_len * 0.5 + 0.02), Color("ff4757"), true) # Rain light
		"shadow":
			# Stealth hypercar: Faceted radar-absorbent body, cyan lightbar slit, glowing skirts, quad exhaust
			vab._add_box(root, Vector3(b_wid * 0.88, 0.03, 0.04), Vector3(0.0, 0.24, -b_len * 0.5 - 0.02), Color("00d2d3"), true)
			vab._add_box(root, Vector3(b_wid + 0.06, 0.03, wz * 1.5), Vector3(0.0, 0.10, 0.0), Color("00d2d3"), true)
			# Dorsal shark fin spine along roof and engine cover
			vab._add_box(root, Vector3(0.04, 0.28, 0.90), Vector3(0.0, 0.54, 0.35), Color("00d2d3"), true)
			# Angular active rear carbon spoiler
			vab._add_box(root, Vector3(b_wid * 0.96, 0.05, 0.26), Vector3(0.0, 0.48, b_len * 0.48), Color("1e272e"))
			# Quad titanium afterburner exhaust cluster with cyan emissive glow
			for ex in [-0.18, -0.06, 0.06, 0.18]:
				vab._add_cylinder(root, 0.045, 0.18, Vector3(ex, 0.20, b_len * 0.5 + 0.06), Color("2f3640"), Vector3(90, 0, 0))
				vab._add_cylinder(root, 0.035, 0.04, Vector3(ex, 0.20, b_len * 0.5 + 0.15), Color("00d2d3"), Vector3(90, 0, 0), true)
		"hyper_chiron":
			# W16 Chiron: Chrome horseshoe grille with black mesh, sweeping side C-line aero bar, quad turbo engine deck
			vab._add_box(root, Vector3(0.44, 0.24, 0.06), Vector3(0.0, 0.22, -b_len * 0.5 - 0.03), Color("f5f6fa")) # Silver horseshoe
			vab._add_box(root, Vector3(0.36, 0.18, 0.04), Vector3(0.0, 0.22, -b_len * 0.5 - 0.04), Color("111111")) # Inner mesh
			# Sweeping side C-curves framing doors and side air ducts
			for side_x in [-1.0, 1.0]:
				var cx: float = (b_wid * 0.5 + 0.02) * side_x
				vab._add_box(root, Vector3(0.03, 0.35, 0.06), Vector3(cx, 0.40, -wz * 0.2), Color("f5f6fa"))
				vab._add_box(root, Vector3(0.03, 0.05, wz * 1.2), Vector3(cx, 0.58, wz * 0.25), Color("f5f6fa"))
				vab._add_box(root, Vector3(0.03, 0.35, 0.06), Vector3(cx, 0.40, wz * 0.7), Color("f5f6fa"))
			# Exposed mid-engine deck with 4 aluminum turbo intakes
			for tx_i in [-0.18, 0.18]:
				for tz_i in [0.15, 0.35]:
					vab._add_cylinder(root, 0.06, 0.08, Vector3(tx_i, 0.42, tz_i), Color("dfe6e9"), Vector3(90, 0, 0))
			# Hydraulic active rear wing
			vab._add_box(root, Vector3(0.04, 0.22, 0.06), Vector3(-0.35, 0.46, b_len * 0.44), Color("d2dae2"))
			vab._add_box(root, Vector3(0.04, 0.22, 0.06), Vector3(0.35, 0.46, b_len * 0.44), Color("d2dae2"))
			vab._add_box(root, Vector3(b_wid * 0.94, 0.05, 0.30), Vector3(0.0, 0.58, b_len * 0.46), Color("1e272e"))
			# Full-width continuous red LED lightbar
			vab._add_box(root, Vector3(b_wid * 0.90, 0.03, 0.03), Vector3(0.0, 0.30, b_len * 0.5 + 0.02), Color("ff3838"), true)
		"hybrid_p1":
			# P1 Track: Teardrop bubble canopy, roof snorkel, hood heat ducts, towering wing, center high-exit exhaust
			vab._add_box(root, Vector3(0.24, 0.12, 0.48), Vector3(0.0, cab_y + cab_hgt * 0.5 + 0.07, -0.08), Color("2c3e50")) # Snorkel
			vab._add_cylinder(root, 0.07, 0.08, Vector3(0.0, cab_y + cab_hgt * 0.5 + 0.09, -0.28), Color("111111"), Vector3(90, 0, 0)) # Snorkel mouth
			# Deep twin hood heat extractors
			vab._add_box(root, Vector3(0.26, 0.04, 0.40), Vector3(-0.25, 0.43, -b_len * 0.22), Color("111111"))
			vab._add_box(root, Vector3(0.26, 0.04, 0.40), Vector3(0.25, 0.43, -b_len * 0.22), Color("111111"))
			# Towering rear curved wing on swan-neck pylons
			vab._add_box(root, Vector3(0.05, 0.36, 0.14), Vector3(-0.40, 0.55, b_len * 0.45), Color("2c3e50"))
			vab._add_box(root, Vector3(0.05, 0.36, 0.14), Vector3(0.40, 0.55, b_len * 0.45), Color("2c3e50"))
			vab._add_box(root, Vector3(b_wid * 1.02, 0.05, 0.32), Vector3(0.0, 0.72, b_len * 0.46), prim)
			# Center high-exit flamethrower exhaust pipe
			vab._add_cylinder(root, 0.085, 0.22, Vector3(0.0, 0.42, b_len * 0.5 + 0.06), Color("dfe6e9"), Vector3(90, 0, 0))
	
	_apply_features(root, recipe, b_len, b_wid, b_hgt, cab_len, cab_hgt, cab_z, prim, sec, vab)

# =============================================================================
# 2. ARCHETYPE: MUSCLE CAR / FASTBACK
# =============================================================================
static func _build_muscle(root: Node3D, car_id: String, recipe: Dictionary, vab: Node) -> void:
	var prim: Color = recipe.get("primary_color", Color("e67e22"))
	var sec: Color = recipe.get("secondary_color", Color("1e272e"))
	var win: Color = recipe.get("window_color", Color("2f3640"))
	var wr: float = float(recipe.get("wheel_radius", 0.30))
	var ww: float = float(recipe.get("wheel_width", 0.22))
	var tx: float = float(recipe.get("track_x", 0.64))
	var wz: float = float(recipe.get("wheelbase_z", 0.82))
	var b_len: float = float(recipe.get("body_length", 2.36))
	var b_wid: float = float(recipe.get("body_width", 1.22))
	var b_hgt: float = float(recipe.get("body_height", 0.36))
	
	# Heavy steel perimeter chassis
	vab._add_box(root, Vector3(b_wid - 0.04, 0.20, b_len), Vector3(0.0, 0.06, 0.0), Color("1e272e"))
	vab._add_flared_wheel_wells(root, tx, wz, prim)
	vab._add_wheels(root, wr, ww, tx, wz)
	
	# Long muscle hood, wide coke-bottle stance
	vab._add_box(root, Vector3(b_wid, b_hgt, b_len), Vector3(0.0, 0.24, 0.0), prim)
	# Dual racing stripes running full length of body
	vab._add_box(root, Vector3(0.20, 0.02, b_len * 0.98), Vector3(-0.16, 0.43, 0.0), sec)
	vab._add_box(root, Vector3(0.20, 0.02, b_len * 0.98), Vector3(0.16, 0.43, 0.0), sec)
	
	# Sloped Fastback Greenhouse
	var cab_len: float = b_len * 0.44
	var cab_wid: float = b_wid * 0.82
	var cab_hgt: float = b_hgt * 0.90
	var cab_z: float = wz * 0.16
	var cab_y: float = 0.24 + b_hgt * 0.85
	
	vab._add_box(root, Vector3(cab_wid, cab_hgt, cab_len), Vector3(0.0, cab_y, cab_z), Color("1e272e"))
	vab._add_box(root, Vector3(cab_wid + 0.02, cab_hgt * 0.75, cab_len * 0.85), Vector3(0.0, cab_y, cab_z), win)
	vab._add_box(root, Vector3(cab_wid - 0.02, 0.06, cab_len - 0.04), Vector3(0.0, cab_y + cab_hgt * 0.5 + 0.02, cab_z), prim)
	
	# Chrome heavy bumpers
	vab._add_box(root, Vector3(b_wid + 0.06, 0.16, 0.14), Vector3(0.0, 0.16, -b_len * 0.5 - 0.06), Color("d2dae2"))
	vab._add_box(root, Vector3(b_wid + 0.06, 0.16, 0.14), Vector3(0.0, 0.16, b_len * 0.5 + 0.06), Color("d2dae2"))
	
	# Wide Quad Round Headlights in Chrome Bezel
	for hx in [-0.46, -0.28, 0.28, 0.46]:
		vab._add_cylinder(root, 0.07, 0.06, Vector3(hx, 0.25, -b_len * 0.5 - 0.08), Color("fff200"), Vector3(90, 0, 0), true)
	
	# Micro Details: Pillars, Cockpit, Mirrors, Handles, Taillights, Plates, Wipers
	_add_window_pillars(root, cab_wid, cab_hgt, cab_len, cab_y, cab_z, prim, vab)
	_add_interior_cockpit(root, cab_wid, cab_y, cab_z, vab)
	_add_side_mirrors(root, b_wid, cab_y - 0.02, cab_z - cab_len * 0.35, Color("d2dae2"), vab) # Chrome mirrors
	_add_door_handles(root, b_wid, 0.32, [cab_z - 0.05], vab, true)
	_add_taillights(root, b_wid, b_len, 0.26, vab)
	_add_windshield_wipers(root, 0.44, cab_z - cab_len * 0.5 - 0.08, vab)
	_add_license_plates(root, b_len, 0.16, 0.16, vab)
	
	# Quad muscle exhaust pipes
	_add_exhaust_pipes(root, b_len, 0.12, [-0.42, -0.28, 0.28, 0.42], vab, false)
	
	# Car-specific muscle features
	match car_id:
		"boss_mustang_302":
			# Black functional shaker hood scoop & rear window louvers
			vab._add_box(root, Vector3(0.36, 0.12, 0.38), Vector3(0.0, 0.48, -b_len * 0.20), Color("1e272e"))
			# Fastback window louvers
			for lz in range(4):
				vab._add_box(root, Vector3(cab_wid * 0.75, 0.02, 0.08), Vector3(0.0, cab_y + 0.14 - lz * 0.06, cab_z + 0.12 + lz * 0.12), Color("1e272e"))
		"blown_nova_sport":
			# Chrome wheelie bars & rear drag parachute pack
			vab._add_box(root, Vector3(0.24, 0.18, 0.16), Vector3(0.0, 0.22, b_len * 0.5 + 0.18), Color("e74c3c")) # Parachute pack
			vab._add_cylinder(root, 0.03, 0.40, Vector3(-0.25, 0.06, b_len * 0.5 + 0.25), Color("d2dae2"), Vector3(20, 0, 0))
			vab._add_cylinder(root, 0.03, 0.40, Vector3(0.25, 0.06, b_len * 0.5 + 0.25), Color("d2dae2"), Vector3(20, 0, 0))
		"charger_doom_69":
			# Matte-black welded steel pushbar & side lake pipes
			vab._add_box(root, Vector3(0.75, 0.35, 0.12), Vector3(0.0, 0.22, -b_len * 0.5 - 0.12), Color("1e272e"))
			vab._add_cylinder(root, 0.05, 1.45, Vector3(-b_wid * 0.52, 0.10, 0.0), Color("d2dae2"), Vector3(90, 0, 0))
			vab._add_cylinder(root, 0.05, 1.45, Vector3(b_wid * 0.52, 0.10, 0.0), Color("d2dae2"), Vector3(90, 0, 0))
		"gto_judge":
			# Twin Ram Air IV hood scoops & hood tachometer & rear pedestal wing
			vab._add_box(root, Vector3(0.18, 0.08, 0.32), Vector3(-0.22, 0.46, -b_len * 0.22), prim)
			vab._add_box(root, Vector3(0.18, 0.08, 0.32), Vector3(0.22, 0.46, -b_len * 0.22), prim)
			vab._add_cylinder(root, 0.04, 0.08, Vector3(-0.35, 0.46, -b_len * 0.15), Color("1e272e"), Vector3(25, 0, 0))
		"camaro_ss_69":
			# Cowl induction hood bulge & RS hideaway headlights
			vab._add_box(root, Vector3(0.38, 0.06, 0.65), Vector3(0.0, 0.45, -b_len * 0.20), prim)
			vab._add_box(root, Vector3(b_wid * 0.88, 0.14, 0.04), Vector3(0.0, 0.25, -b_len * 0.5 - 0.03), Color("1e272e"))
		"firebird_transam":
			# Gold Screaming Chicken hood bird & gold snowflake rims & shaker scoop
			vab._add_box(root, Vector3(0.48, 0.02, 0.48), Vector3(0.0, 0.43, -b_len * 0.22), Color("f1c40f"))
			vab._add_box(root, Vector3(0.28, 0.10, 0.32), Vector3(0.0, 0.48, -b_len * 0.18), Color("1e272e"))
		"rat_rod_flame":
			# Chopped sun visor, exposed massive V8 with 8 velocity stacks & side zoomie headers
			vab._add_box(root, Vector3(cab_wid + 0.08, 0.04, 0.22), Vector3(0.0, cab_y + cab_hgt * 0.45, cab_z - cab_len * 0.5 - 0.10), Color("d35400"), false, Vector3(-20, 0, 0))
			vab._add_box(root, Vector3(0.65, 0.35, 0.65), Vector3(0.0, 0.35, -b_len * 0.25), Color("718093"))
			for stack in range(4):
				var sz: float = -b_len * 0.25 - 0.20 + stack * 0.13
				vab._add_cylinder(root, 0.04, 0.18, Vector3(-0.16, 0.60, sz), Color("d2dae2"))
				vab._add_cylinder(root, 0.04, 0.18, Vector3(0.16, 0.60, sz), Color("d2dae2"))
			for side_x in [-1.0, 1.0]:
				for z_i in range(4):
					var zz: float = -b_len * 0.25 - 0.18 + z_i * 0.12
					vab._add_cylinder(root, 0.035, 0.28, Vector3((b_wid * 0.5 + 0.08) * side_x, 0.30, zz), Color("e74c3c"), Vector3(0, 0, -35 * side_x))
		"hemi_cuda":
			# Shaker hood scoop through cutout, black vinyl roof & rear billboard graphics
			vab._add_box(root, Vector3(0.32, 0.14, 0.38), Vector3(0.0, 0.48, -b_len * 0.22), Color("1e272e"))
			vab._add_box(root, Vector3(cab_wid - 0.01, 0.08, cab_len - 0.02), Vector3(0.0, cab_y + cab_hgt * 0.5 + 0.02, cab_z), Color("1e272e"))
			for ex in [-0.40, -0.25, 0.25, 0.40]:
				vab._add_box(root, Vector3(0.08, 0.05, 0.18), Vector3(ex, 0.12, b_len * 0.5 + 0.08), Color("d2dae2"))
		"buick_gnx_stealth":
			# Total blacked-out murdered treatment, offset turbo hood bulge, fender louvers & ducktail spoiler
			vab._add_box(root, Vector3(0.35, 0.06, 0.55), Vector3(0.12, 0.45, -b_len * 0.22), Color("050505"))
			for side_x in [-1.0, 1.0]:
				for l_i in range(3):
					vab._add_box(root, Vector3(0.02, 0.02, 0.08), Vector3((b_wid * 0.5 + 0.01) * side_x, 0.30 + l_i * 0.05, -wz * 0.3), Color("1a1a1a"))
			vab._add_box(root, Vector3(b_wid * 0.90, 0.08, 0.14), Vector3(0.0, 0.44, b_len * 0.48), Color("050505"), false, Vector3(-20, 0, 0))
		"cobra_427":
			# 427 S/C Roadster: Open cockpit, chrome roll hoop, big-block scoop, sidepipes with heat guards, quick jacks
			vab._add_box(root, Vector3(0.85, 0.24, 0.70), Vector3(0.0, cab_y - 0.05, 0.0), Color("111111")) # Open cockpit cutout
			vab._add_cylinder(root, 0.08, 0.02, Vector3(-0.25, 0.44, -0.15), Color("8b5a2b"), Vector3(25, 0, 0)) # Wood-rim wheel
			vab._add_torus(root, 0.03, 0.14, Vector3(-0.26, 0.58, 0.18), Color("d2dae2")) # Chrome driver roll hoop
			vab._add_box(root, Vector3(0.32, 0.08, 0.42), Vector3(0.0, 0.46, -b_len * 0.22), prim) # Big-block scoop
			vab._add_box(root, Vector3(0.26, 0.04, 0.06), Vector3(0.0, 0.46, -b_len * 0.22 - 0.21), Color("111111")) # Scoop intake mouth
			# Long chrome sidepipes with slotted heat shields
			for side_x in [-1.0, 1.0]:
				var sx: float = (b_wid * 0.5 + 0.04) * side_x
				vab._add_cylinder(root, 0.06, 1.40, Vector3(sx, 0.10, 0.0), Color("d2dae2"), Vector3(90, 0, 0))
				vab._add_box(root, Vector3(0.02, 0.08, 0.90), Vector3(sx + 0.04 * side_x, 0.10, 0.0), Color("718093"))
			# Chrome quick-jack lift brackets front and rear
			for qx in [-0.35, 0.35]:
				vab._add_box(root, Vector3(0.06, 0.12, 0.06), Vector3(qx, 0.16, -b_len * 0.5 - 0.04), Color("d2dae2"))
				vab._add_box(root, Vector3(0.06, 0.12, 0.06), Vector3(qx, 0.16, b_len * 0.5 + 0.04), Color("d2dae2"))
			vab._add_cylinder(root, 0.05, 0.04, Vector3(0.36, 0.45, 0.32), Color("d2dae2")) # Le Mans fuel flip-cap
		"top_fuel_dragster":
			# Nitro Rail Dragster: Ultra-long chassis, blown hemi with tall scoop, rear drag wing, parachutes, wheelie bar
			vab._add_box(root, Vector3(0.60, 0.35, 0.55), Vector3(0.0, 0.34, 0.30), Color("718093")) # Hemi engine block
			vab._add_box(root, Vector3(0.40, 0.22, 0.38), Vector3(0.0, 0.58, 0.30), Color("dfe6e9")) # Chrome 14-71 supercharger
			for val in [-0.08, 0.0, 0.08]:
				vab._add_cylinder(root, 0.04, 0.10, Vector3(val, 0.68, 0.14), Color("e74c3c"), Vector3(90, 0, 0), true) # 3 red butterfly valves
			# Upward-angled zoomie exhaust headers (4 per side)
			for side_x in [-1.0, 1.0]:
				for z_i in range(4):
					var zz: float = 0.12 + z_i * 0.12
					vab._add_cylinder(root, 0.035, 0.32, Vector3((0.36 + z_i * 0.02) * side_x, 0.46, zz), Color("e17055"), Vector3(-25, 0, -40 * side_x))
			# Towering high-mount rear drag wing
			vab._add_cylinder(root, 0.025, 0.65, Vector3(-0.35, 0.68, b_len * 0.45), Color("718093"), Vector3(10, 0, 0))
			vab._add_cylinder(root, 0.025, 0.65, Vector3(0.35, 0.68, b_len * 0.45), Color("718093"), Vector3(10, 0, 0))
			vab._add_box(root, Vector3(1.15, 0.06, 0.42), Vector3(0.0, 0.98, b_len * 0.46), Color("111111"))
			vab._add_box(root, Vector3(0.04, 0.20, 0.45), Vector3(-0.58, 0.98, b_len * 0.46), prim)
			vab._add_box(root, Vector3(0.04, 0.20, 0.45), Vector3(0.58, 0.98, b_len * 0.46), prim)
			# Dual red parachute packs
			vab._add_box(root, Vector3(0.18, 0.18, 0.14), Vector3(-0.14, 0.26, b_len * 0.5 + 0.12), Color("e74c3c"))
			vab._add_box(root, Vector3(0.18, 0.18, 0.14), Vector3(0.14, 0.26, b_len * 0.5 + 0.12), Color("e74c3c"))
			# Wheelie bar with dual roller wheels
			vab._add_cylinder(root, 0.02, 0.70, Vector3(-0.20, 0.08, b_len * 0.5 + 0.35), Color("d2dae2"), Vector3(15, 0, 0))
			vab._add_cylinder(root, 0.02, 0.70, Vector3(0.20, 0.08, b_len * 0.5 + 0.35), Color("d2dae2"), Vector3(15, 0, 0))
			vab._add_cylinder(root, 0.06, 0.04, Vector3(-0.20, 0.05, b_len * 0.5 + 0.68), Color("111111"), Vector3(0, 0, 90))
			vab._add_cylinder(root, 0.06, 0.04, Vector3(0.20, 0.05, b_len * 0.5 + 0.68), Color("111111"), Vector3(0, 0, 90))
	
	_apply_features(root, recipe, b_len, b_wid, b_hgt, cab_len, cab_hgt, cab_z, prim, sec, vab)

# =============================================================================
# 3. ARCHETYPE: OFF-ROAD / 4x4 / BUGGY
# =============================================================================
static func _build_offroad(root: Node3D, car_id: String, recipe: Dictionary, vab: Node) -> void:
	var prim: Color = recipe.get("primary_color", Color("27ae60"))
	var sec: Color = recipe.get("secondary_color", Color("2c3e50"))
	var wr: float = float(recipe.get("wheel_radius", 0.35))
	var ww: float = float(recipe.get("wheel_width", 0.26))
	var tx: float = float(recipe.get("track_x", 0.68))
	var wz: float = float(recipe.get("wheelbase_z", 0.78))
	var b_len: float = float(recipe.get("body_length", 2.25))
	var b_wid: float = float(recipe.get("body_width", 1.20))
	var b_hgt: float = float(recipe.get("body_height", 0.50))
	
	# Lifted heavy frame & exposed red coil springs
	vab._add_box(root, Vector3(b_wid - 0.10, 0.24, b_len), Vector3(0.0, 0.18, 0.0), Color("1e272e"))
	for sx in [-tx * 0.75, tx * 0.75]:
		for sz in [-wz, wz]:
			vab._add_cylinder(root, 0.08, 0.35, Vector3(sx, 0.18, sz), Color("e74c3c"))
	vab._add_wheels(root, wr, ww, tx, wz)
	
	# Open body / tub
	vab._add_box(root, Vector3(b_wid, b_hgt * 0.65, b_len), Vector3(0.0, 0.35, 0.0), prim)
	
	# Tubular Roll Cage
	var cage_hgt: float = 0.55
	var cage_y: float = 0.35 + b_hgt * 0.65 + cage_hgt * 0.5
	for cx in [-b_wid * 0.42, b_wid * 0.42]:
		for cz in [-wz * 0.7, wz * 0.7]:
			vab._add_cylinder(root, 0.045, cage_hgt, Vector3(cx, cage_y, cz), sec)
	vab._add_box(root, Vector3(b_wid * 0.88, 0.06, wz * 1.45), Vector3(0.0, cage_y + cage_hgt * 0.5, 0.0), sec)
	
	# Front Heavy Winch Bumper & Steel Tow Hook
	vab._add_box(root, Vector3(b_wid + 0.12, 0.22, 0.18), Vector3(0.0, 0.25, -b_len * 0.5 - 0.08), Color("2c3e50"))
	vab._add_cylinder(root, 0.10, 0.25, Vector3(0.0, 0.25, -b_len * 0.5 - 0.18), Color("7f8c8d"), Vector3(0, 0, 90))
	
	# Micro Details: Headlights, Taillights, Plates, Mirrors
	_add_headlights(root, b_wid, b_len, 0.38, vab)
	_add_taillights(root, b_wid, b_len, 0.38, vab)
	_add_license_plates(root, b_len, 0.25, 0.25, vab)
	_add_side_mirrors(root, b_wid, 0.60, -wz * 0.45, sec, vab)
	
	match car_id:
		"dune_sand_rail":
			# Rear exposed air-cooled engine with twin chrome stinger exhaust stacks
			vab._add_box(root, Vector3(0.60, 0.30, 0.45), Vector3(0.0, 0.32, b_len * 0.42), Color("718093"))
			vab._add_cylinder(root, 0.05, 0.55, Vector3(-0.16, 0.65, b_len * 0.48), Color("d2dae2"), Vector3(-35, 0, 0))
			vab._add_cylinder(root, 0.05, 0.55, Vector3(0.16, 0.65, b_len * 0.48), Color("d2dae2"), Vector3(-35, 0, 0))
			# Safety whip antenna with bright orange pennant
			vab._add_cylinder(root, 0.015, 0.90, Vector3(-b_wid * 0.40, cage_y + 0.75, wz * 0.7), Color("d2dae2"))
			vab._add_box(root, Vector3(0.02, 0.12, 0.22), Vector3(-b_wid * 0.40, cage_y + 1.15, wz * 0.7 - 0.11), Color("e67e22"), true)
		"trail_wrangler":
			# Iconic 7-slot vertical grille
			for g in range(-3, 4):
				vab._add_box(root, Vector3(0.04, 0.22, 0.02), Vector3(g * 0.08, 0.38, -b_len * 0.5 - 0.02), Color("1e272e"))
			# Full-size rear tailgate spare tire with wheel cover
			vab._add_cylinder(root, wr * 0.95, ww * 0.9, Vector3(0.0, 0.48, b_len * 0.5 + 0.18), Color("1e272e"), Vector3(90, 0, 0))
			vab._add_box(root, Vector3(0.35, 0.35, 0.04), Vector3(0.0, 0.48, b_len * 0.5 + 0.28), Color("f1c40f")) # Yellow smiley face / logo
		"desert_crawler":
			# Rear dual radiator fans & long-travel bypass shocks
			vab._add_box(root, Vector3(0.65, 0.35, 0.25), Vector3(0.0, 0.45, b_len * 0.45), Color("718093"))
			vab._add_cylinder(root, 0.12, 0.05, Vector3(-0.18, 0.48, b_len * 0.45 + 0.14), Color("2f3542"), Vector3(90, 0, 0))
			vab._add_cylinder(root, 0.12, 0.05, Vector3(0.18, 0.48, b_len * 0.45 + 0.14), Color("2f3542"), Vector3(90, 0, 0))
		"overland_cruiser":
			# Snorkel air intake tube & twin rear red jerrycans & roof safari tent
			vab._add_cylinder(root, 0.04, 0.70, Vector3(-b_wid * 0.48, 0.55, -wz * 0.4), Color("1e272e"))
			vab._add_box(root, Vector3(0.10, 0.08, 0.10), Vector3(-b_wid * 0.48, 0.92, -wz * 0.4 + 0.05), Color("1e272e"))
			vab._add_box(root, Vector3(0.18, 0.24, 0.12), Vector3(-0.35, 0.45, b_len * 0.5 + 0.08), Color("c0392b"))
			vab._add_box(root, Vector3(0.18, 0.24, 0.12), Vector3(-0.15, 0.45, b_len * 0.5 + 0.08), Color("c0392b"))
		"arctic_snow_cat":
			# Front V-Plow wedge blade & dual continuous rubber tracks
			vab._add_box(root, Vector3(b_wid * 0.65, 0.35, 0.25), Vector3(-b_wid * 0.30, 0.22, -b_len * 0.5 - 0.15), Color("e74c3c"), false, Vector3(0, 30, 0))
			vab._add_box(root, Vector3(b_wid * 0.65, 0.35, 0.25), Vector3(b_wid * 0.30, 0.22, -b_len * 0.5 - 0.15), Color("e74c3c"), false, Vector3(0, -30, 0))
			for sx in [-tx * 1.05, tx * 1.05]:
				vab._add_box(root, Vector3(0.08, 0.32, wz * 2.2), Vector3(sx, 0.16, 0.0), Color("2f3542"))
		"mud_bogger_jeep":
			# High-clearance stinger front bar & twin vertical smokestacks
			vab._add_cylinder(root, 0.04, 0.65, Vector3(0.0, 0.48, -b_len * 0.5 - 0.25), Color("1e272e"), Vector3(-40, 0, 0))
			vab._add_cylinder(root, 0.05, 0.75, Vector3(-b_wid * 0.45, 0.75, wz * 0.3), Color("d2dae2"))
			vab._add_cylinder(root, 0.05, 0.75, Vector3(b_wid * 0.45, 0.75, wz * 0.3), Color("d2dae2"))
		"secret_black_suv":
			# Dark presidential SUV with roof satellite dome & concealed grille strobes
			vab._add_cylinder(root, 0.18, 0.08, Vector3(0.0, cage_y + cage_hgt * 0.5 + 0.08, wz * 0.2), Color("1e272e"))
			vab._add_cylinder(root, 0.015, 0.35, Vector3(-b_wid * 0.46, 0.52, -b_len * 0.45), Color("d2dae2"))
			vab._add_cylinder(root, 0.015, 0.35, Vector3(b_wid * 0.46, 0.52, -b_len * 0.45), Color("d2dae2"))
		"orbital_rover_6x6":
			# NASA lunar exploration rover with gold bubble cockpit & parabolic dish
			vab._add_cylinder(root, 0.25, 0.04, Vector3(0.0, cage_y + 0.60, wz * 0.4), Color("d2dae2"), Vector3(45, 0, 0))
			vab._add_cylinder(root, 0.02, 0.30, Vector3(0.0, cage_y + 0.45, wz * 0.4), Color("718093"))
			for side_x in [-tx, tx]:
				vab._add_cylinder(root, wr * 0.95, ww, Vector3(side_x, 0.18, 0.0), Color("f1c40f"), Vector3(0, 0, 90))
		"monster_pickup":
			# Lifted monster 4x4 chassis, tubular bed rollcage with 4 yellow KC lights & chrome supercharger
			vab._add_box(root, Vector3(0.42, 0.25, 0.50), Vector3(0.0, 0.52, -b_len * 0.25), Color("d2dae2"))
			vab._add_cylinder(root, 0.06, 0.14, Vector3(-0.11, 0.62, -b_len * 0.25), Color("ff3f34"), Vector3(90, 0, 0), true)
			vab._add_cylinder(root, 0.06, 0.14, Vector3(0.11, 0.62, -b_len * 0.25), Color("ff3f34"), Vector3(90, 0, 0), true)
			vab._add_box(root, Vector3(b_wid * 0.85, 0.65, 0.10), Vector3(0.0, cage_y + 0.30, wz * 0.2), Color("f1c40f"))
			for k in range(4):
				var kx: float = -0.42 + k * 0.28
				vab._add_cylinder(root, 0.08, 0.06, Vector3(kx, cage_y + 0.68, wz * 0.2), Color("f1c40f"), Vector3(90, 0, 0), true)
		"baja_trophy_truck":
			# Tubular prerunner front bumper, angled dual rear spare tires & 6-pod curved LED roof lightbar
			vab._add_box(root, Vector3(b_wid * 0.88, 0.24, 0.18), Vector3(0.0, 0.22, -b_len * 0.5 - 0.16), Color("2f3640"))
			vab._add_box(root, Vector3(0.65, 0.05, 0.45), Vector3(0.0, 0.12, -b_len * 0.5 - 0.10), Color("d2dae2"), false, Vector3(-30, 0, 0))
			vab._add_cylinder(root, wr * 0.95, ww * 0.9, Vector3(-0.30, 0.45, wz * 0.65), Color("1e272e"), Vector3(55, 0, 0))
			vab._add_cylinder(root, wr * 0.95, ww * 0.9, Vector3(0.30, 0.45, wz * 0.65), Color("1e272e"), Vector3(55, 0, 0))
		"dakar_rally_raid":
			# Carbon rally raid shell, roof air intake scoop, twin rear radiator fans & mudflaps
			vab._add_box(root, Vector3(0.38, 0.12, 0.45), Vector3(0.0, cage_y + cage_hgt * 0.5 + 0.08, -0.15), prim)
			vab._add_cylinder(root, 0.12, 0.06, Vector3(-0.25, 0.52, b_len * 0.42), Color("1e272e"), Vector3(90, 0, 0))
			vab._add_cylinder(root, 0.12, 0.06, Vector3(0.25, 0.52, b_len * 0.42), Color("1e272e"), Vector3(90, 0, 0))
			vab._add_box(root, Vector3(0.26, 0.25, 0.03), Vector3(-tx, 0.15, wz + 0.35), Color("c0392b"))
			vab._add_box(root, Vector3(0.26, 0.25, 0.03), Vector3(tx, 0.15, wz + 0.35), Color("c0392b"))
		"six_by_six_truck":
			# Triple-axle 6x6 chassis, front diamond-plate brushguard & vertical intake snorkel
			for side_x in [-tx, tx]:
				vab._add_cylinder(root, wr, ww, Vector3(side_x, 0.18, 0.0), Color("1e272e"), Vector3(0, 0, 90))
			vab._add_box(root, Vector3(b_wid + 0.06, 0.35, 0.16), Vector3(0.0, 0.25, -b_len * 0.5 - 0.12), Color("2c3e50"))
			vab._add_cylinder(root, 0.05, 0.90, Vector3(-b_wid * 0.48, 0.70, -wz * 0.35), Color("1e272e"))
		"military_humvee":
			# Desert military slantback, 360 roof gun ring with .50 cal machine gun & heavy brushguard
			vab._add_box(root, Vector3(b_wid * 0.90, 0.30, b_len * 0.42), Vector3(0.0, 0.45, b_len * 0.26), prim, false, Vector3(-25, 0, 0))
			vab._add_cylinder(root, 0.30, 0.10, Vector3(0.0, cage_y + cage_hgt * 0.5 + 0.05, 0.0), Color("2f3542"))
			vab._add_box(root, Vector3(0.35, 0.24, 0.04), Vector3(0.0, cage_y + cage_hgt * 0.5 + 0.22, -0.22), Color("2f3542"))
			vab._add_cylinder(root, 0.04, 0.65, Vector3(0.0, cage_y + cage_hgt * 0.5 + 0.18, -0.45), Color("1e272e"), Vector3(90, 0, 0))
	
	_apply_features(root, recipe, b_len, b_wid, b_hgt, wz * 1.45, cage_hgt, 0.0, prim, sec, vab)

# =============================================================================
# 4. ARCHETYPE: HEAVY DUTY / ROLLER / PAVER / INDUSTRIAL
# =============================================================================
static func _build_heavy(root: Node3D, car_id: String, recipe: Dictionary, vab: Node) -> void:
	var prim: Color = recipe.get("primary_color", Color("f39c12"))
	var sec: Color = recipe.get("secondary_color", Color("7f8c8d"))
	var wr: float = float(recipe.get("wheel_radius", 0.40))
	var ww: float = float(recipe.get("wheel_width", 0.30))
	var tx: float = float(recipe.get("track_x", 0.70))
	var wz: float = float(recipe.get("wheelbase_z", 0.90))
	var b_len: float = float(recipe.get("body_length", 2.60))
	var b_wid: float = float(recipe.get("body_width", 1.35))
	var b_hgt: float = float(recipe.get("body_height", 0.70))
	var wtype: String = String(recipe.get("wheel_type", "HEAVY_TRUCK"))
	
	# Massive steel ladder frame
	vab._add_box(root, Vector3(b_wid, 0.28, b_len), Vector3(0.0, 0.20, 0.0), Color("2c3e50"))
	
	if wtype == "HEAVY_ROLLER":
		# Front massive cylinder compaction roller
		vab._add_cylinder(root, 0.45, 1.42, Vector3(0.0, 0.18, -wz * 1.1), sec, Vector3(0, 0, 90))
		# Heavy scraper bar
		vab._add_box(root, Vector3(1.44, 0.14, 0.08), Vector3(0.0, 0.24, -wz * 1.1 + 0.48), Color("2f3640"))
		# Rear dual pneumatic compactor wheels
		for rx in [-tx, tx]:
			vab._add_cylinder(root, 0.42, 0.32, Vector3(rx, 0.16, wz * 0.85), Color("1e272e"), Vector3(0, 0, 90))
	else:
		# Standard 6-wheel heavy dual axles with chrome rim hubs
		for side_x in [-tx, tx]:
			vab._add_cylinder(root, wr, ww, Vector3(side_x, 0.16, -wz), Color("1e272e"), Vector3(0, 0, 90))
			vab._add_cylinder(root, wr, ww, Vector3(side_x, 0.16, wz * 0.5), Color("1e272e"), Vector3(0, 0, 90))
			vab._add_cylinder(root, wr, ww, Vector3(side_x, 0.16, wz * 1.1), Color("1e272e"), Vector3(0, 0, 90))
	
	# Heavy cab or driver platform
	vab._add_box(root, Vector3(b_wid * 0.92, b_hgt, b_len * 0.60), Vector3(0.0, 0.20 + b_hgt * 0.5, wz * 0.15), prim)
	
	# Yellow Hazard Chevron Plates
	vab._add_box(root, Vector3(b_wid + 0.08, 0.18, 0.06), Vector3(0.0, 0.20, -b_len * 0.5 - 0.04), Color("f1c40f"), true)
	vab._add_box(root, Vector3(b_wid + 0.08, 0.18, 0.06), Vector3(0.0, 0.20, b_len * 0.5 + 0.04), Color("f1c40f"), true)
	
	# Heavy mirrors, work lamps, license plates
	_add_side_mirrors(root, b_wid + 0.1, 0.65, -0.10, Color("1e272e"), vab)
	_add_license_plates(root, b_len, 0.20, 0.20, vab)
	
	# Tall chrome vertical smokestack exhaust with rain flapper cap
	vab._add_cylinder(root, 0.07, 0.95, Vector3(-b_wid * 0.46, 0.95, -0.15), Color("d2dae2"))
	vab._add_box(root, Vector3(0.12, 0.02, 0.12), Vector3(-b_wid * 0.46, 1.44, -0.15), Color("d2dae2"), false, Vector3(15, 0, 0))
	
	match car_id:
		"garbage_compactor":
			# Rear hydraulic hopper with lift arms & grab rails
			vab._add_box(root, Vector3(b_wid * 0.88, 0.75, 0.65), Vector3(0.0, 0.58, b_len * 0.42), Color("27ae60"))
			vab._add_cylinder(root, 0.04, 0.80, Vector3(-b_wid * 0.46, 0.60, b_len * 0.45), Color("f1c40f")) # Grab rail
			vab._add_cylinder(root, 0.04, 0.80, Vector3(b_wid * 0.46, 0.60, b_len * 0.45), Color("f1c40f"))
		"street_asphalt_paver":
			# Heated rear screed plate assembly with thickness adjustment handwheels
			vab._add_box(root, Vector3(b_wid + 0.20, 0.18, 0.35), Vector3(0.0, 0.16, b_len * 0.5 + 0.15), Color("2f3640"))
			vab._add_cylinder(root, 0.12, 0.04, Vector3(-0.45, 0.32, b_len * 0.5 + 0.15), Color("f1c40f"), Vector3(90, 0, 0))
			vab._add_cylinder(root, 0.12, 0.04, Vector3(0.45, 0.32, b_len * 0.5 + 0.15), Color("f1c40f"), Vector3(90, 0, 0))
		"concrete_mixer":
			# Large angled rotating cylindrical cement mixing drum & rear discharge chute
			vab._add_cylinder(root, 0.52, 1.35, Vector3(0.0, 0.65, 0.35), Color("f8c291"), Vector3(25, 0, 0))
			vab._add_box(root, Vector3(0.24, 0.35, 0.40), Vector3(0.0, 0.38, b_len * 0.5 + 0.12), Color("718093"))
			vab._add_cylinder(root, 0.18, 0.55, Vector3(0.0, 0.85, -0.30), Color("d2dae2"), Vector3(0, 0, 90))
		"mega_excavator":
			# Turret cab, boom arm, hydraulic ram, and digging bucket
			vab._add_box(root, Vector3(0.85, 0.65, 0.95), Vector3(-0.15, 0.55, 0.0), prim)
			vab._add_box(root, Vector3(0.14, 0.22, 1.45), Vector3(0.35, 0.85, -0.65), Color("2c3e50"), false, Vector3(-35, 0, 0))
			vab._add_box(root, Vector3(0.35, 0.35, 0.35), Vector3(0.35, 0.25, -1.55), Color("718093"))
		"timber_log_hauler":
			# Steel log bunks with chained redwood timber trunks
			vab._add_cylinder(root, 0.26, 1.85, Vector3(-0.25, 0.55, 0.45), Color("784212"), Vector3(90, 0, 0))
			vab._add_cylinder(root, 0.26, 1.85, Vector3(0.25, 0.55, 0.45), Color("784212"), Vector3(90, 0, 0))
			vab._add_cylinder(root, 0.26, 1.85, Vector3(0.0, 0.90, 0.45), Color("6e2c00"), Vector3(90, 0, 0))
			vab._add_torus(root, 0.55, 0.58, Vector3(0.0, 0.68, 0.10), Color("d2dae2"), Vector3(90, 0, 0))
			vab._add_torus(root, 0.55, 0.58, Vector3(0.0, 0.68, 0.80), Color("d2dae2"), Vector3(90, 0, 0))
		"mobile_crane_rig":
			# Deployable outrigger pads & telescopic lattice crane boom
			for ox in [-b_wid * 0.55, b_wid * 0.55]:
				for oz in [-wz * 0.5, wz * 0.8]:
					vab._add_box(root, Vector3(0.18, 0.06, 0.18), Vector3(ox, 0.08, oz), Color("f1c40f"))
			vab._add_box(root, Vector3(0.32, 0.28, 2.60), Vector3(0.0, 0.95, -0.20), Color("f1c40f"), false, Vector3(-8, 0, 0))
			vab._add_cylinder(root, 0.08, 0.22, Vector3(0.0, 0.75, -b_len * 0.5 - 0.45), Color("2f3640"))
		"big_ladder_fire":
			# Extendable aerial rescue turntable ladder & side hose reels
			vab._add_cylinder(root, 0.35, 0.12, Vector3(0.0, 0.72, 0.40), Color("d2dae2"))
			vab._add_box(root, Vector3(0.42, 0.16, 2.20), Vector3(0.0, 0.92, -0.20), Color("f5f6fa"), false, Vector3(-10, 0, 0))
			vab._add_cylinder(root, 0.18, 0.12, Vector3(-b_wid * 0.48, 0.45, 0.25), Color("e74c3c"), Vector3(0, 0, 90))
			vab._add_cylinder(root, 0.18, 0.12, Vector3(b_wid * 0.48, 0.45, 0.25), Color("e74c3c"), Vector3(0, 0, 90))
		"flatbed_tow_truck":
			# Slanted diamond-plate slideback bed & overhead lightbar pylon
			vab._add_box(root, Vector3(b_wid * 0.95, 0.08, 1.85), Vector3(0.0, 0.45, 0.45), Color("7f8c8d"), false, Vector3(-8, 0, 0))
			vab._add_box(root, Vector3(b_wid * 0.85, 0.55, 0.08), Vector3(0.0, 0.65, -0.35), Color("2c3e50"))
		"steam_train_car":
			# Authentic steam boiler chassis, cowcatcher wedge, and brass bell
			vab._add_cylinder(root, 0.42, 2.10, Vector3(0.0, 0.48, -0.15), Color("2c3e50"), Vector3(90, 0, 0))
			vab._add_box(root, Vector3(1.20, 0.30, 0.35), Vector3(0.0, 0.18, -b_len * 0.5 - 0.12), Color("c0392b"), false, Vector3(-25, 0, 0))
			vab._add_cylinder(root, 0.06, 0.12, Vector3(0.0, 0.95, -0.55), Color("f1c40f"))
			vab._add_cylinder(root, 0.09, 0.35, Vector3(0.0, 1.05, -b_len * 0.5 + 0.35), Color("1e272e"))
			vab._add_sphere(root, 0.14, Vector3(0.0, 1.28, -b_len * 0.5 + 0.35), Color("f5f6fa"))
		"armored_bulldozer":
			# Massive curved steel dozer blade with hydraulic rams, hazard chevrons & rear ripper shank
			vab._add_box(root, Vector3(b_wid * 1.15, 0.55, 0.20), Vector3(0.0, 0.25, -b_len * 0.5 - 0.25), Color("f39c12"), false, Vector3(-12, 0, 0))
			for h in range(-3, 4):
				vab._add_box(root, Vector3(0.12, 0.06, 0.04), Vector3(h * 0.22, 0.50, -b_len * 0.5 - 0.22), Color("1e272e"))
			vab._add_cylinder(root, 0.06, 0.55, Vector3(-b_wid * 0.45, 0.35, -b_len * 0.45), Color("d2dae2"), Vector3(-25, 0, 0))
			vab._add_cylinder(root, 0.06, 0.55, Vector3(b_wid * 0.45, 0.35, -b_len * 0.45), Color("d2dae2"), Vector3(-25, 0, 0))
			for r in [-0.35, 0.0, 0.35]:
				vab._add_box(root, Vector3(0.08, 0.45, 0.15), Vector3(r, 0.18, b_len * 0.5 + 0.18), Color("1e272e"), false, Vector3(25, 0, 0))
		"dump_titan":
			# Massive quarry dump bed tilted slightly, left operator cab, walkway & giant fuel tank
			vab._add_box(root, Vector3(b_wid * 1.08, 0.70, b_len * 0.65), Vector3(0.0, 0.75, 0.35), prim, false, Vector3(-6, 0, 0))
			vab._add_box(root, Vector3(b_wid * 1.08, 0.12, 0.85), Vector3(0.0, 1.25, -b_len * 0.25), prim)
			vab._add_box(root, Vector3(0.45, 0.50, 0.55), Vector3(-b_wid * 0.28, 0.65, -b_len * 0.35), Color("ffffff"))
			vab._add_box(root, Vector3(b_wid * 0.85, 0.05, 0.35), Vector3(0.0, 0.45, -b_len * 0.35), Color("7f8c8d"))
		"tanker":
			# Cylindrical chrome fuel vessel with safety placards, top catwalk & dual vertical exhaust stacks
			vab._add_cylinder(root, 0.52, b_len * 0.65, Vector3(0.0, 0.60, 0.30), Color("d2dae2"), Vector3(90, 0, 0))
			vab._add_box(root, Vector3(0.35, 0.04, b_len * 0.60), Vector3(0.0, 1.15, 0.30), Color("7f8c8d"))
			vab._add_box(root, Vector3(0.18, 0.18, 0.04), Vector3(0.0, 0.60, b_len * 0.5 + 0.05), Color("e74c3c"))
			vab._add_cylinder(root, 0.05, 0.95, Vector3(-b_wid * 0.42, 0.85, -b_len * 0.15), Color("d2dae2"))
			vab._add_cylinder(root, 0.05, 0.95, Vector3(b_wid * 0.42, 0.85, -b_len * 0.15), Color("d2dae2"))
		"swat_enforcer_van":
			# Matte black armored personnel carrier, window bars, heavy pushbar & roof sniper hatch
			for side_x in [-1.0, 1.0]:
				for b in range(3):
					vab._add_box(root, Vector3(0.02, 0.03, 0.55), Vector3((b_wid * 0.5 + 0.01) * side_x, 0.45 + b * 0.08, 0.15), Color("1e272e"))
			vab._add_box(root, Vector3(b_wid * 0.88, 0.35, 0.18), Vector3(0.0, 0.25, -b_len * 0.5 - 0.12), Color("1e272e"))
			vab._add_cylinder(root, 0.24, 0.08, Vector3(0.0, b_hgt + 0.35, -0.10), Color("2f3640"))
			vab._add_box(root, Vector3(0.32, 0.20, 0.04), Vector3(0.0, b_hgt + 0.48, -0.28), Color("1e272e"))
		"airport_crash_tender":
			# High-speed airport rescue tender, roof water/foam monitor turret & bumper foam nozzle
			vab._add_box(root, Vector3(0.35, 0.25, 0.35), Vector3(0.0, b_hgt + 0.35, -b_len * 0.20), Color("d2dae2"))
			vab._add_cylinder(root, 0.06, 0.55, Vector3(0.0, b_hgt + 0.50, -b_len * 0.20 - 0.28), Color("e74c3c"), Vector3(80, 0, 0))
			vab._add_cylinder(root, 0.05, 0.20, Vector3(0.0, 0.22, -b_len * 0.5 - 0.12), Color("d2dae2"), Vector3(90, 0, 0))
		"riot_water_cannon":
			# Front hydraulic riot V-plow, twin roof high-pressure water turrets & window wire mesh
			vab._add_box(root, Vector3(b_wid * 0.65, 0.45, 0.25), Vector3(-b_wid * 0.30, 0.25, -b_len * 0.5 - 0.18), Color("1e272e"), false, Vector3(0, 25, 0))
			vab._add_box(root, Vector3(b_wid * 0.65, 0.45, 0.25), Vector3(b_wid * 0.30, 0.25, -b_len * 0.5 - 0.18), Color("1e272e"), false, Vector3(0, -25, 0))
			for sx in [-0.32, 0.32]:
				vab._add_cylinder(root, 0.12, 0.15, Vector3(sx, b_hgt + 0.35, -b_len * 0.25), Color("d2dae2"))
				vab._add_cylinder(root, 0.045, 0.45, Vector3(sx, b_hgt + 0.45, -b_len * 0.25 - 0.25), Color("3498db"), Vector3(80, 0, 0))
		"gold_limo":
			# VIP Golden Limo: 6-wheel presidential stretch, 24k gold body, waterfall grille, flying goddess, rooftop jacuzzi
			for wx in [-tx, tx]:
				var w_mid := Node3D.new()
				w_mid.position = Vector3(wx, 0.02, 0.0)
				vab._add_cylinder(w_mid, wr * 0.95, ww * 0.9, Vector3.ZERO, Color("1e272e"), Vector3(0, 0, 90))
				vab._add_box(w_mid, Vector3(0.20, 0.24, 0.24), Vector3.ZERO, Color("f1c40f")) # Gold wire hub
				root.add_child(w_mid)
			# Chrome waterfall grille & flying goddess mascot
			vab._add_box(root, Vector3(0.68, 0.38, 0.06), Vector3(0.0, 0.28, -b_len * 0.5 - 0.03), Color("f5f6fa"))
			vab._add_cylinder(root, 0.04, 0.16, Vector3(0.0, 0.52, -b_len * 0.5 - 0.02), Color("f5f6fa"))
			# Triple window privacy bays with gold B & C pillars
			vab._add_box(root, Vector3(b_wid - 0.04, 0.32, 2.20), Vector3(0.0, 0.54, 0.10), Color("0a0a0a"))
			vab._add_box(root, Vector3(b_wid, 0.32, 0.08), Vector3(0.0, 0.54, -0.40), Color("f1c40f"))
			vab._add_box(root, Vector3(b_wid, 0.32, 0.08), Vector3(0.0, 0.54, 0.40), Color("f1c40f"))
			# Rooftop sunken jacuzzi with illuminated water & gold perimeter railing
			vab._add_box(root, Vector3(0.72, 0.06, 0.90), Vector3(0.0, 0.72, 0.15), Color("00d2d3"), true)
			for rx in [-0.38, 0.38]:
				vab._add_cylinder(root, 0.015, 0.90, Vector3(rx, 0.76, 0.15), Color("f1c40f"), Vector3(90, 0, 0))
			# Rear continental kit spare tire shroud & dual chrome bumperettes
			vab._add_cylinder(root, wr * 0.95, 0.18, Vector3(0.0, 0.32, b_len * 0.5 + 0.12), Color("f1c40f"), Vector3(90, 0, 0))
	
	_apply_features(root, recipe, b_len, b_wid, b_hgt, b_len * 0.6, b_hgt, wz * 0.15, prim, sec, vab)

# =============================================================================
# 5. ARCHETYPE: COMMERCIAL VAN / CARGO / EMERGENCY
# =============================================================================
static func _build_van(root: Node3D, car_id: String, recipe: Dictionary, vab: Node) -> void:
	var prim: Color = recipe.get("primary_color", Color("ffffff"))
	var sec: Color = recipe.get("secondary_color", Color("e74c3c"))
	var win: Color = recipe.get("window_color", Color("1e272e"))
	var wr: float = float(recipe.get("wheel_radius", 0.29))
	var ww: float = float(recipe.get("wheel_width", 0.20))
	var tx: float = float(recipe.get("track_x", 0.60))
	var wz: float = float(recipe.get("wheelbase_z", 0.78))
	var b_len: float = float(recipe.get("body_length", 2.30))
	var b_wid: float = float(recipe.get("body_width", 1.18))
	var b_hgt: float = float(recipe.get("body_height", 0.65))
	
	vab._add_box(root, Vector3(b_wid - 0.04, 0.20, b_len), Vector3(0.0, 0.06, 0.0), Color("1e272e"))
	vab._add_flared_wheel_wells(root, tx, wz, prim)
	vab._add_wheels(root, wr, ww, tx, wz)
	
	# Stepped Cab + Cargo Box
	# Cab nose
	vab._add_box(root, Vector3(b_wid, 0.40, 0.65), Vector3(0.0, 0.26, -b_len * 0.5 + 0.32), prim)
	# Tall Box Body
	vab._add_box(root, Vector3(b_wid, b_hgt, b_len - 0.50), Vector3(0.0, 0.16 + b_hgt * 0.5, 0.25), prim)
	# Side accent stripe
	vab._add_box(root, Vector3(b_wid + 0.02, 0.12, b_len - 0.48), Vector3(0.0, 0.35, 0.25), sec)
	
	# Windshield & side cab windows
	vab._add_box(root, Vector3(b_wid * 0.92, 0.30, 0.08), Vector3(0.0, 0.55, -b_len * 0.5 + 0.62), win)
	vab._add_box(root, Vector3(b_wid + 0.02, 0.26, 0.42), Vector3(0.0, 0.55, -b_len * 0.5 + 0.85), win)
	
	# Bumpers
	vab._add_box(root, Vector3(b_wid + 0.04, 0.16, 0.14), Vector3(0.0, 0.15, -b_len * 0.5 - 0.05), Color("2f3640"))
	vab._add_box(root, Vector3(b_wid + 0.04, 0.16, 0.14), Vector3(0.0, 0.15, b_len * 0.5 + 0.05), Color("2f3640"))
	
	# Micro Details: Side mirrors, Door handles, Lights, Plates, Wipers, Exhaust
	_add_side_mirrors(root, b_wid, 0.52, -b_len * 0.5 + 0.60, Color("2f3640"), vab)
	_add_door_handles(root, b_wid, 0.38, [-b_len * 0.5 + 0.95, 0.35], vab, true)
	_add_headlights(root, b_wid, b_len, 0.28, vab)
	_add_taillights(root, b_wid, b_len, 0.28, vab)
	_add_license_plates(root, b_len, 0.16, 0.16, vab)
	_add_windshield_wipers(root, 0.48, -b_len * 0.5 + 0.60, vab)
	_add_exhaust_pipes(root, b_len, 0.12, [-0.35], vab, false)
	
	# Rear cargo barn doors with center split and lock latch
	vab._add_box(root, Vector3(0.02, b_hgt * 0.85, 0.02), Vector3(0.0, 0.16 + b_hgt * 0.5, b_len * 0.5 + 0.01), Color("1e272e"))
	vab._add_box(root, Vector3(0.08, 0.06, 0.04), Vector3(0.06, 0.45, b_len * 0.5 + 0.02), Color("d2dae2")) # Chrome handle
	
	match car_id:
		"paramedic_rapid":
			# Red cross emblems on sides
			for sx in [-b_wid * 0.5 - 0.02, b_wid * 0.5 + 0.02]:
				vab._add_box(root, Vector3(0.02, 0.22, 0.08), Vector3(sx, 0.55, 0.30), Color("e74c3c"), true)
				vab._add_box(root, Vector3(0.02, 0.08, 0.22), Vector3(sx, 0.55, 0.30), Color("e74c3c"), true)
		"postal_mail_truck":
			# Corrugated rear roll-up shutter & blue cheatline
			vab._add_box(root, Vector3(b_wid + 0.02, 0.08, b_len), Vector3(0.0, 0.40, 0.0), Color("0984e3"))
		"express_courier_van":
			# High-roof fairing & orange parcel logo stripe
			vab._add_box(root, Vector3(b_wid * 0.92, 0.16, 0.55), Vector3(0.0, b_hgt + 0.22, -0.35), prim)
		"securitas_armored":
			# Ballistic armor plating with slit windows and 3-spoke vault handle
			vab._add_box(root, Vector3(b_wid + 0.06, 0.18, b_len * 0.85), Vector3(0.0, 0.48, 0.20), Color("2c3e50"))
			vab._add_cylinder(root, 0.12, 0.04, Vector3(0.0, 0.48, b_len * 0.5 + 0.06), Color("d2dae2"), Vector3(90, 0, 0))
	
	_apply_features(root, recipe, b_len, b_wid, b_hgt, b_len - 0.5, b_hgt, 0.25, prim, sec, vab)

# =============================================================================
# 6. ARCHETYPE: TRANSIT BUS
# =============================================================================
static func _build_bus(root: Node3D, car_id: String, recipe: Dictionary, vab: Node) -> void:
	var prim: Color = recipe.get("primary_color", Color("ffffff"))
	var sec: Color = recipe.get("secondary_color", Color("0984e3"))
	var win: Color = recipe.get("window_color", Color("1e272e"))
	var b_len: float = float(recipe.get("body_length", 3.40))
	var b_wid: float = float(recipe.get("body_width", 1.25))
	var b_hgt: float = float(recipe.get("body_height", 0.90))
	var tx: float = float(recipe.get("track_x", 0.66))
	
	# Wheels (front single, rear dual tandem)
	vab._add_wheels(root, 0.32, 0.22, tx, 1.05)
	for rx in [-tx, tx]:
		vab._add_cylinder(root, 0.32, 0.22, Vector3(rx, 0.14, 0.55), Color("1e272e"), Vector3(0, 0, 90))
	
	# Full bus body & lower skirt stripe
	vab._add_box(root, Vector3(b_wid, b_hgt, b_len), Vector3(0.0, 0.18 + b_hgt * 0.5, 0.0), prim)
	vab._add_box(root, Vector3(b_wid + 0.02, 0.24, b_len), Vector3(0.0, 0.30, 0.0), sec)
	
	# Continuous passenger window glass band with vertical mullions
	vab._add_box(root, Vector3(b_wid + 0.02, 0.32, b_len * 0.88), Vector3(0.0, 0.72, 0.05), win)
	for mz in range(-5, 6):
		vab._add_box(root, Vector3(b_wid + 0.03, 0.32, 0.04), Vector3(0.0, 0.72, mz * 0.26), prim)
	
	# Front LED destination display banner ("01 EXPRESS")
	vab._add_box(root, Vector3(b_wid * 0.75, 0.14, 0.06), Vector3(0.0, b_hgt + 0.10, -b_len * 0.5 - 0.02), Color("f1c40f"), true)
	
	# Roof AC Units & Escape Hatches
	vab._add_box(root, Vector3(0.70, 0.12, 0.80), Vector3(0.0, b_hgt + 0.22, -0.40), Color("d2dae2"))
	vab._add_box(root, Vector3(0.70, 0.12, 0.80), Vector3(0.0, b_hgt + 0.22, 0.60), Color("d2dae2"))
	
	# Folding Passenger Entrance Doors on curb side
	vab._add_box(root, Vector3(0.03, 0.72, 0.45), Vector3(b_wid * 0.5 + 0.02, 0.54, -b_len * 0.35), Color("2f3640"))
	vab._add_box(root, Vector3(0.04, 0.28, 0.16), Vector3(b_wid * 0.5 + 0.02, 0.65, -b_len * 0.35), win)
	
	match car_id:
		"double_decker_bus":
			# Second passenger story & upper deck window band
			vab._add_box(root, Vector3(b_wid, 0.65, b_len), Vector3(0.0, 1.35, 0.0), prim)
			vab._add_box(root, Vector3(b_wid + 0.02, 0.26, b_len * 0.88), Vector3(0.0, 1.40, 0.05), win)
			for mz in range(-5, 6):
				vab._add_box(root, Vector3(b_wid + 0.03, 0.26, 0.04), Vector3(0.0, 1.40, mz * 0.26), prim)
			vab._add_box(root, Vector3(b_wid * 0.75, 0.12, 0.06), Vector3(0.0, 1.72, -b_len * 0.5 - 0.02), Color("f1c40f"), true)

	# Mirrors, Lights, Plates, Bumpers
	_add_side_mirrors(root, b_wid + 0.15, 0.75, -b_len * 0.5 + 0.25, Color("1e272e"), vab)
	_add_headlights(root, b_wid, b_len, 0.28, vab)
	_add_taillights(root, b_wid, b_len, 0.28, vab)
	_add_license_plates(root, b_len, 0.18, 0.18, vab)
	
	_apply_features(root, recipe, b_len, b_wid, b_hgt, b_len, b_hgt, 0.0, prim, sec, vab)

# =============================================================================
# 7. ARCHETYPE: NOVELTY & SPECIAL VEHICLES
# =============================================================================
static func _build_novelty(root: Node3D, car_id: String, recipe: Dictionary, vab: Node) -> void:
	match car_id:
		"giant_donut_mobile":
			_build_coupe(root, car_id, recipe, vab)
			# Massive 3D Glazed Donut with Pink Strawberry Icing
			var donut = vab._add_torus(root, 0.22, 0.48, Vector3(0.0, 0.95, 0.35), Color("f3a683"), Vector3(0, 0, 90))
			vab._add_torus(donut, 0.24, 0.46, Vector3(0.02, 0.0, 0.0), Color("ff9ff3"), Vector3.ZERO, true)
			# Scattered 3D Rainbow Sprinkles (yellow, cyan, lime green, white)
			var sprinkle_cols = [Color("fff200"), Color("00d2d3"), Color("badc58"), Color("ffffff")]
			for sp_i in range(12):
				var ang: float = sp_i * (TAU / 12.0)
				var rad: float = 0.35
				var sx: float = cos(ang) * rad
				var sy: float = sin(ang) * rad
				vab._add_box(donut, Vector3(0.04, 0.08, 0.03), Vector3(0.03, sy, sx), sprinkle_cols[sp_i % sprinkle_cols.size()], true, Vector3(sp_i * 30, 0, 0))
		"hot_dog_express":
			_build_coupe(root, car_id, recipe, vab)
			# Long sausage cylinder running through bun
			vab._add_cylinder(root, 0.22, 2.50, Vector3(0.0, 0.65, 0.0), Color("c0392b"), Vector3(90, 0, 0))
			# Toasted Golden Bun Halves on left and right
			vab._add_cylinder(root, 0.18, 2.30, Vector3(-0.18, 0.62, 0.0), Color("e58e26"), Vector3(90, 0, 0))
			vab._add_cylinder(root, 0.18, 2.30, Vector3(0.18, 0.62, 0.0), Color("e58e26"), Vector3(90, 0, 0))
			# Yellow mustard zigzag wave atop hotdog
			for mz in range(-5, 6):
				var mx: float = 0.08 if mz % 2 == 0 else -0.08
				vab._add_box(root, Vector3(0.06, 0.06, 0.18), Vector3(mx, 0.88, mz * 0.22), Color("f1c40f"), true)
		"taco_loco_truck":
			_build_van(root, car_id, recipe, vab)
			# Fold-out side service serving window with awning
			vab._add_box(root, Vector3(0.04, 0.35, 0.85), Vector3(0.60, 0.55, 0.25), Color("2f3640"))
			vab._add_box(root, Vector3(0.18, 0.04, 0.88), Vector3(0.68, 0.74, 0.25), Color("e74c3c")) # Awning
			vab._add_box(root, Vector3(0.12, 0.03, 0.82), Vector3(0.65, 0.38, 0.25), Color("d2dae2")) # Serving counter shelf
		"street_sweeper_brush":
			_build_coupe(root, car_id, recipe, vab)
			# Twin rotating circular steel wire brooms on front
			for bx in [-0.55, 0.55]:
				vab._add_cylinder(root, 0.26, 0.08, Vector3(bx, 0.08, -1.18), Color("7f8c8d"), Vector3.ZERO)
				# Central hub spinner
				vab._add_cylinder(root, 0.08, 0.12, Vector3(bx, 0.12, -1.18), Color("f1c40f"), Vector3.ZERO)
		"airport_baggage_tug":
			_build_coupe(root, car_id, recipe, vab)
			# Thick rubber pushing pads & heavy multi-stage tow pin hitch
			vab._add_box(root, Vector3(1.10, 0.30, 0.16), Vector3(0.0, 0.18, -0.90), Color("1e272e"))
			vab._add_box(root, Vector3(0.25, 0.25, 0.18), Vector3(0.0, 0.22, 0.95), Color("2f3640"))
			vab._add_cylinder(root, 0.05, 0.24, Vector3(0.0, 0.30, 0.95), Color("d2dae2"))
		"warehouse_forklift":
			_build_coupe(root, car_id, recipe, vab)
			# Front vertical hydraulic mast & dual lifting forks
			vab._add_box(root, Vector3(0.08, 0.95, 0.08), Vector3(-0.35, 0.58, -1.05), Color("2f3640"))
			vab._add_box(root, Vector3(0.08, 0.95, 0.08), Vector3(0.35, 0.58, -1.05), Color("2f3640"))
			# Cross braces on mast
			vab._add_box(root, Vector3(0.65, 0.06, 0.04), Vector3(0.0, 0.35, -1.05), Color("2f3640"))
			vab._add_box(root, Vector3(0.65, 0.06, 0.04), Vector3(0.0, 0.75, -1.05), Color("2f3640"))
			# Dual horizontal lifting forks resting on floor
			vab._add_box(root, Vector3(0.12, 0.04, 0.65), Vector3(-0.25, 0.08, -1.35), Color("d2dae2"))
			vab._add_box(root, Vector3(0.12, 0.04, 0.65), Vector3(0.25, 0.08, -1.35), Color("d2dae2"))
		"vintage_beetle_bug":
			_build_coupe(root, car_id, recipe, vab)
			# Curved retro chrome bumpers with vertical overrider guards
			vab._add_cylinder(root, 0.04, 0.18, Vector3(-0.35, 0.20, -1.18), Color("d2dae2"))
			vab._add_cylinder(root, 0.04, 0.18, Vector3(0.35, 0.20, -1.18), Color("d2dae2"))
			vab._add_cylinder(root, 0.04, 0.18, Vector3(-0.35, 0.20, 1.18), Color("d2dae2"))
			vab._add_cylinder(root, 0.04, 0.18, Vector3(0.35, 0.20, 1.18), Color("d2dae2"))
			# Chrome headlight circular bezels
			vab._add_cylinder(root, 0.12, 0.04, Vector3(-0.42, 0.32, -1.08), Color("d2dae2"), Vector3(90, 0, 0))
			vab._add_cylinder(root, 0.12, 0.04, Vector3(0.42, 0.32, -1.08), Color("d2dae2"), Vector3(90, 0, 0))
		"vw_camper_kombi":
			_build_van(root, car_id, recipe, vab)
			# Split two-piece windshield ("splittie")
			vab._add_box(root, Vector3(0.06, 0.32, 0.10), Vector3(0.0, 0.55, -1.18 * 0.5 + 0.62), Color("ffffff"))
			# Front nose-mounted spare tire
			vab._add_cylinder(root, 0.22, 0.12, Vector3(0.0, 0.32, -1.15), Color("1e272e"), Vector3(90, 0, 0))
			vab._add_box(root, Vector3(0.24, 0.24, 0.03), Vector3(0.0, 0.32, -1.22), Color("f1c40f")) # Flower retro hub
		"woody_surf_wagon":
			_build_coupe(root, car_id, recipe, vab)
			# Sculpted 3D timber woodgrain exterior framing & dark wood door inserts
			for side_x in [-0.60, 0.60]:
				vab._add_box(root, Vector3(0.03, 0.28, 1.35), Vector3(side_x, 0.26, 0.15), Color("8b5a2b")) # Timber frame
				vab._add_box(root, Vector3(0.04, 0.20, 0.55), Vector3(side_x, 0.26, -0.15), Color("cd853f")) # Front insert
				vab._add_box(root, Vector3(0.04, 0.20, 0.55), Vector3(side_x, 0.26, 0.45), Color("cd853f")) # Rear insert
		"classic_mini_cooper":
			_build_coupe(root, car_id, recipe, vab)
			# Contrast white roof & twin white bonnet racing stripes
			vab._add_box(root, Vector3(0.86, 0.06, 1.05), Vector3(0.0, 0.72, 0.08), Color("ffffff"))
			vab._add_box(root, Vector3(0.08, 0.02, 0.65), Vector3(-0.18, 0.43, -0.72), Color("ffffff"))
			vab._add_box(root, Vector3(0.08, 0.02, 0.65), Vector3(0.18, 0.43, -0.72), Color("ffffff"))
			# Quad rally spotlamps across grille
			for qx in [-0.32, -0.11, 0.11, 0.32]:
				vab._add_cylinder(root, 0.07, 0.05, Vector3(qx, 0.26, -1.18), Color("fff200"), Vector3(90, 0, 0), true)
		"sedan_family_station":
			_build_coupe(root, car_id, recipe, vab)
			# Extended station wagon roofline & chrome roof luggage rails
			vab._add_box(root, Vector3(0.88, 0.32, 0.75), Vector3(0.0, 0.54, 0.65), Color("1e272e"))
			vab._add_cylinder(root, 0.02, 1.25, Vector3(-0.40, 0.72, 0.25), Color("d2dae2"), Vector3(90, 0, 0))
			vab._add_cylinder(root, 0.02, 1.25, Vector3(0.40, 0.72, 0.25), Color("d2dae2"), Vector3(90, 0, 0))
		"compact_city_smart":
			_build_coupe(root, car_id, recipe, vab)
			# Bubble silver Tridion safety cage curving around door and roof
			vab._add_box(root, Vector3(1.10, 0.50, 0.88), Vector3(0.0, 0.52, 0.05), Color("d2dae2"))
			# Panoramic dark glass roof insert
			vab._add_box(root, Vector3(0.86, 0.04, 0.65), Vector3(0.0, 0.78, 0.05), Color("1e272e"))
		"monowheel_gyro":
			# Enormous outer motorized tread ring & suspended inner gimbal cockpit
			var tread = vab._add_torus(root, 0.52, 0.90, Vector3(0.0, 0.65, 0.0), Color("1e272e"), Vector3(0, 0, 90))
			vab._add_torus(tread, 0.55, 0.85, Vector3(0.0, 0.0, 0.0), Color("00d2d3"), Vector3.ZERO, true)
			vab._add_sphere(root, 0.36, Vector3(0.0, 0.65, 0.0), Color("2f3640"))
			vab._add_cylinder(root, 0.10, 0.08, Vector3(0.0, 0.65, -0.42), Color("00d2d3"), Vector3(90, 0, 0), true)
			vab._add_box(root, Vector3(0.65, 0.04, 0.35), Vector3(0.0, 0.20, 0.0), Color("718093"))
		"coffin_dragster":
			# Polished dark mahogany casket body with brass handles, skull ornament, and organ pipe headers
			vab._add_box(root, Vector3(0.85, 0.38, 2.10), Vector3(0.0, 0.26, 0.10), Color("4a235a"))
			for hz in [-0.5, 0.0, 0.5]:
				vab._add_cylinder(root, 0.03, 0.15, Vector3(-0.45, 0.28, hz), Color("f1c40f"), Vector3(0, 0, 90))
				vab._add_cylinder(root, 0.03, 0.15, Vector3(0.45, 0.28, hz), Color("f1c40f"), Vector3(0, 0, 90))
			vab._add_sphere(root, 0.12, Vector3(0.0, 0.45, -0.95), Color("d2dae2"))
			vab._add_box(root, Vector3(0.06, 0.04, 0.04), Vector3(-0.04, 0.46, -1.04), Color("e74c3c"), true)
			vab._add_box(root, Vector3(0.06, 0.04, 0.04), Vector3(0.04, 0.46, -1.04), Color("e74c3c"), true)
			for p in range(4):
				var pz: float = -0.45 + p * 0.14
				var ph: float = 0.40 + p * 0.12
				vab._add_cylinder(root, 0.03, ph, Vector3(-0.35, 0.40 + ph * 0.5, pz), Color("d2dae2"))
				vab._add_cylinder(root, 0.03, ph, Vector3(0.35, 0.40 + ph * 0.5, pz), Color("d2dae2"))
			vab._add_cylinder(root, 0.40, 0.32, Vector3(-0.62, 0.25, 0.82), Color("1e272e"), Vector3(0, 0, 90))
			vab._add_cylinder(root, 0.40, 0.32, Vector3(0.62, 0.25, 0.82), Color("1e272e"), Vector3(0, 0, 90))
			vab._add_cylinder(root, 0.24, 0.08, Vector3(-0.48, 0.10, -0.85), Color("1e272e"), Vector3(0, 0, 90))
			vab._add_cylinder(root, 0.24, 0.08, Vector3(0.48, 0.10, -0.85), Color("1e272e"), Vector3(0, 0, 90))
		"quantum_hovercar":
			var prim: Color = recipe.get("primary_color", Color("6c5ce7"))
			var sec: Color = recipe.get("secondary_color", Color("00cec9"))
			var win: Color = recipe.get("window_color", Color("0a192f"))
			var b_len: float = float(recipe.get("body_length", 2.20))
			var b_wid: float = float(recipe.get("body_width", 1.20))
			# Teardrop hover pod, 4 glowing violet repulsor discs underneath & central dorsal stabilizer fin
			vab._add_sphere(root, 0.55, Vector3(0.0, 0.35, -0.45), prim)
			vab._add_box(root, Vector3(b_wid, 0.32, b_len * 0.85), Vector3(0.0, 0.30, 0.10), prim)
			vab._add_box(root, Vector3(b_wid * 0.85, 0.25, b_len * 0.55), Vector3(0.0, 0.48, 0.0), win)
			vab._add_box(root, Vector3(0.04, 0.35, 0.85), Vector3(0.0, 0.65, 0.35), sec)
			vab._add_box(root, Vector3(0.05, 0.30, 0.04), Vector3(0.0, 0.65, 0.78), Color("ffeaa7"), true)
			for hx in [-0.42, 0.42]:
				for hz in [-0.55, 0.55]:
					vab._add_cylinder(root, 0.24, 0.06, Vector3(hx, 0.08, hz), Color("2f3640"))
					vab._add_cylinder(root, 0.20, 0.04, Vector3(hx, 0.04, hz), Color("00cec9"), Vector3.ZERO, true)
		"anti_grav_speeder":
			var prim: Color = recipe.get("primary_color", Color("00d2d3"))
			var sec: Color = recipe.get("secondary_color", Color("2c3e50"))
			var win: Color = recipe.get("window_color", Color("0a3d62"))
			var b_len: float = float(recipe.get("body_length", 2.35))
			var b_wid: float = float(recipe.get("body_width", 1.18))
			# Anti-Grav Speeder: Wheel-less hover skimmer, 4 glowing magnetic repulsors, twin vector thrusters
			vab._add_box(root, Vector3(b_wid, 0.26, b_len * 0.85), Vector3(0.0, 0.22, 0.05), prim)
			vab._add_box(root, Vector3(b_wid * 0.75, 0.20, 0.55), Vector3(0.0, 0.20, -b_len * 0.45), prim)
			vab._add_box(root, Vector3(b_wid * 0.70, 0.22, 0.95), Vector3(0.0, 0.38, -0.05), win)
			for hx in [-0.44, 0.44]:
				for hz in [-0.60, 0.60]:
					vab._add_cylinder(root, 0.22, 0.05, Vector3(hx, 0.08, hz), Color("2f3640"))
					vab._add_cylinder(root, 0.18, 0.03, Vector3(hx, 0.05, hz), Color("54a0ff"), Vector3.ZERO, true)
			for tx_i in [-0.28, 0.28]:
				vab._add_cylinder(root, 0.11, 0.22, Vector3(tx_i, 0.22, b_len * 0.5 + 0.08), Color("2c3e50"), Vector3(90, 0, 0))
				vab._add_cylinder(root, 0.08, 0.04, Vector3(tx_i, 0.22, b_len * 0.5 + 0.18), Color("00d2d3"), Vector3(90, 0, 0), true)
			for side_x in [-1.0, 1.0]:
				vab._add_box(root, Vector3(0.24, 0.04, 0.45), Vector3((b_wid * 0.5 + 0.10) * side_x, 0.24, 0.35), prim, false, Vector3(0, 0, -20 * side_x))
			vab._add_box(root, Vector3(0.04, 0.32, 0.65), Vector3(0.0, 0.54, 0.35), sec)
		"tron_light_cycle":
			var prim: Color = recipe.get("primary_color", Color("10ac84"))
			var win: Color = recipe.get("window_color", Color("0a192f"))
			var wz: float = float(recipe.get("wheelbase_z", 0.80))
			# Tron Light-Cruiser: Hubless glowing neon wheels, enclosed aerodynamic canopy, laser projector
			vab._add_torus(root, 0.14, 0.38, Vector3(0.0, 0.38, -wz), Color("1e272e"), Vector3(0, 0, 90))
			vab._add_torus(root, 0.16, 0.36, Vector3(0.0, 0.38, -wz), Color("1dd1a1"), Vector3.ZERO, true)
			vab._add_torus(root, 0.14, 0.38, Vector3(0.0, 0.38, wz), Color("1e272e"), Vector3(0, 0, 90))
			vab._add_torus(root, 0.16, 0.36, Vector3(0.0, 0.38, wz), Color("1dd1a1"), Vector3.ZERO, true)
			vab._add_box(root, Vector3(0.65, 0.34, wz * 2.2), Vector3(0.0, 0.34, 0.0), Color("111111"))
			vab._add_box(root, Vector3(0.52, 0.24, 0.95), Vector3(0.0, 0.52, -0.10), win)
			for side_x in [-1.0, 1.0]:
				vab._add_box(root, Vector3(0.02, 0.04, wz * 1.8), Vector3(0.34 * side_x, 0.32, 0.0), Color("1dd1a1"), true)
			vab._add_box(root, Vector3(0.35, 0.16, 0.18), Vector3(0.0, 0.34, wz + 0.38), prim)
			vab._add_box(root, Vector3(0.28, 0.08, 0.04), Vector3(0.0, 0.34, wz + 0.48), Color("1dd1a1"), true)
		"bat_vigilante_tank":
			var prim: Color = recipe.get("primary_color", Color("222f3e"))
			var b_len: float = float(recipe.get("body_length", 2.60))
			var b_wid: float = float(recipe.get("body_width", 1.35))
			# Dark Bat Tumbler: Stealth assault tank, exposed front outrigger wheels, rear duallys, afterburner cone
			for side_x in [-1.0, 1.0]:
				vab._add_box(root, Vector3(0.25, 0.15, 0.65), Vector3(0.68 * side_x, 0.22, -0.75), Color("1e272e"), false, Vector3(0, -15 * side_x, 0))
				vab._add_cylinder(root, 0.42, 0.32, Vector3(0.85 * side_x, 0.22, -0.85), Color("111111"), Vector3(0, 0, 90))
				vab._add_cylinder(root, 0.22, 0.34, Vector3(0.85 * side_x, 0.22, -0.85), Color("353b48"), Vector3(0, 0, 90))
				vab._add_cylinder(root, 0.44, 0.48, Vector3(0.72 * side_x, 0.24, 0.82), Color("111111"), Vector3(0, 0, 90))
				vab._add_cylinder(root, 0.24, 0.50, Vector3(0.72 * side_x, 0.24, 0.82), Color("353b48"), Vector3(0, 0, 90))
			vab._add_box(root, Vector3(1.10, 0.42, 2.30), Vector3(0.0, 0.34, 0.0), prim)
			vab._add_box(root, Vector3(0.88, 0.30, 1.05), Vector3(0.0, 0.62, 0.05), Color("111111"))
			vab._add_cylinder(root, 0.035, 0.55, Vector3(-0.35, 0.64, -0.35), Color("1e272e"), Vector3(90, 0, 0))
			vab._add_cylinder(root, 0.035, 0.55, Vector3(0.35, 0.64, -0.35), Color("1e272e"), Vector3(90, 0, 0))
			for side_x in [-1.0, 1.0]:
				vab._add_box(root, Vector3(0.24, 0.05, 0.55), Vector3(0.42 * side_x, 0.72, 0.45), prim, false, Vector3(-15, 0, 18 * side_x))
			vab._add_cylinder(root, 0.20, 0.32, Vector3(0.0, 0.36, b_len * 0.5 + 0.10), Color("1e272e"), Vector3(90, 0, 0))
			vab._add_cylinder(root, 0.14, 0.08, Vector3(0.0, 0.36, b_len * 0.5 + 0.24), Color("ee5253"), Vector3(90, 0, 0), true)
		"rocket_sled_sonic":
			var prim: Color = recipe.get("primary_color", Color("f5f6fa"))
			var sec: Color = recipe.get("secondary_color", Color("e84118"))
			var b_len: float = float(recipe.get("body_length", 2.80))
			# Sonic Land Sled: Supersonic pitot needle, streamlined fuselage, twin solid rocket booster tanks
			vab._add_wheels(root, 0.30, 0.18, 0.64, 1.02)
			vab._add_box(root, Vector3(0.70, 0.28, b_len * 0.90), Vector3(0.0, 0.22, 0.05), prim)
			vab._add_box(root, Vector3(0.55, 0.22, 0.75), Vector3(0.0, 0.20, -b_len * 0.45), prim)
			vab._add_cylinder(root, 0.02, 0.75, Vector3(0.0, 0.20, -b_len * 0.5 - 0.35), Color("718093"), Vector3(90, 0, 0))
			vab._add_box(root, Vector3(0.50, 0.18, 0.85), Vector3(0.0, 0.40, -0.10), Color("2f3640"))
			for side_x in [-1.0, 1.0]:
				vab._add_cylinder(root, 0.16, 2.20, Vector3(0.52 * side_x, 0.26, 0.15), sec, Vector3(90, 0, 0))
				vab._add_cylinder(root, 0.18, 0.06, Vector3(0.52 * side_x, 0.26, -0.40), Color("718093"), Vector3(90, 0, 0))
				vab._add_cylinder(root, 0.18, 0.06, Vector3(0.52 * side_x, 0.26, 0.70), Color("718093"), Vector3(90, 0, 0))
				vab._add_cylinder(root, 0.12, 0.25, Vector3(0.52 * side_x, 0.26, 1.30), Color("2f3640"), Vector3(90, 0, 0))
				vab._add_cylinder(root, 0.08, 0.06, Vector3(0.52 * side_x, 0.26, 1.42), Color("f1c40f"), Vector3(90, 0, 0), true)
			vab._add_box(root, Vector3(0.04, 0.45, 0.75), Vector3(0.0, 0.54, b_len * 0.38), prim)
		"fire_dragon":
			var prim: Color = recipe.get("primary_color", Color("d63031"))
			var sec: Color = recipe.get("secondary_color", Color("e17055"))
			# Mythic Fire Dragon: Sculpted dragon jaws with fangs, glowing lava maw, slit eyes, dorsal horns, bat wings, segmented tail, quad flame exhausts
			vab._add_wheels(root, 0.34, 0.24, 0.68, 0.84)
			vab._add_flared_wheel_wells(root, 0.68, 0.84, prim)
			# Segmented abdominal undercarriage plates with glowing magma lines
			for iz in range(-4, 5):
				vab._add_box(root, Vector3(0.95, 0.04, 0.18), Vector3(0.0, 0.12, iz * 0.24), Color("e17055"), true)
			vab._add_box(root, Vector3(1.30, 0.28, 2.45), Vector3(0.0, 0.22, 0.05), prim)
			# Upper & Lower Dragon Jaws with Glowing Lava Maw
			vab._add_box(root, Vector3(0.92, 0.22, 0.95), Vector3(0.0, 0.32, -0.90), prim)
			vab._add_box(root, Vector3(0.82, 0.12, 0.85), Vector3(0.0, 0.16, -0.92), Color("2d3436"))
			for fx in [-0.36, -0.20, 0.20, 0.36]:
				vab._add_box(root, Vector3(0.05, 0.10, 0.06), Vector3(fx, 0.22, -1.36), Color("f5f6fa"))
				vab._add_box(root, Vector3(0.05, 0.08, 0.06), Vector3(fx, 0.21, -1.22), Color("f5f6fa"))
			# Glowing inner lava chamber between jaws
			vab._add_box(root, Vector3(0.60, 0.08, 0.45), Vector3(0.0, 0.24, -1.05), Color("ff3838"), true)
			# Ferocious glowing dragon eyes with vertical black pupil slits
			for side_x in [-1.0, 1.0]:
				vab._add_box(root, Vector3(0.18, 0.08, 0.24), Vector3(0.38 * side_x, 0.44, -0.80), Color("fff200"), true, Vector3(0, -18 * side_x, 15 * side_x))
				vab._add_box(root, Vector3(0.04, 0.08, 0.20), Vector3(0.38 * side_x, 0.45, -0.80), Color("000000"), false, Vector3(0, -18 * side_x, 15 * side_x))
				# Flared brow horns over cockpit
				vab._add_box(root, Vector3(0.08, 0.12, 0.45), Vector3(0.42 * side_x, 0.58, -0.35), Color("f1c40f"), false, Vector3(25, 15 * side_x, 0))
				vab._add_box(root, Vector3(0.06, 0.08, 0.35), Vector3(0.46 * side_x, 0.68, -0.15), Color("f1c40f"), false, Vector3(35, 20 * side_x, 0))
			# Glowing amber nostrils
			vab._add_box(root, Vector3(0.14, 0.06, 0.10), Vector3(-0.20, 0.38, -1.35), Color("ff9f43"), true)
			vab._add_box(root, Vector3(0.14, 0.06, 0.10), Vector3(0.20, 0.38, -1.35), Color("ff9f43"), true)
			# 5 Staggered golden dorsal spines
			for s in range(5):
				vab._add_box(root, Vector3(0.08, 0.20 + s * 0.04, 0.18), Vector3(0.0, 0.65 + s * 0.03, -0.40 + s * 0.30), Color("f1c40f"), false, Vector3(-15, 0, 0))
			# Dual Ribbed Dragon Bat-Wings with golden claws
			for side_x in [-1.0, 1.0]:
				vab._add_box(root, Vector3(0.60, 0.04, 0.95), Vector3(0.85 * side_x, 0.55, 0.60), sec, false, Vector3(15, -15 * side_x, -20 * side_x))
				vab._add_box(root, Vector3(0.08, 0.08, 1.10), Vector3(0.88 * side_x, 0.58, 0.60), prim, false, Vector3(15, -15 * side_x, -20 * side_x))
				vab._add_box(root, Vector3(0.12, 0.12, 0.15), Vector3(1.18 * side_x, 0.66, 0.75), Color("f1c40f"), true)
			# Articulated Segmented Dragon Tail with Flame Blade
			for t_seg in range(4):
				var tz: float = 1.10 + t_seg * 0.22
				var ty: float = 0.45 + sin(t_seg * 0.6) * 0.30
				vab._add_box(root, Vector3(0.24 - t_seg * 0.04, 0.20, 0.22), Vector3(0.0, ty, tz), prim)
				vab._add_box(root, Vector3(0.06, 0.15, 0.12), Vector3(0.0, ty + 0.16, tz), Color("f1c40f"))
			vab._add_box(root, Vector3(0.55, 0.06, 0.35), Vector3(0.0, 0.72, 1.95), Color("ff9f43"), true, Vector3(-20, 0, 0))
			vab._add_box(root, Vector3(0.12, 0.08, 0.45), Vector3(0.0, 0.72, 2.05), Color("f1c40f"), true, Vector3(-20, 0, 0))
			# Quad Magma Exhaust Cannons
			for ex in [-0.48, -0.22, 0.22, 0.48]:
				vab._add_cylinder(root, 0.09, 0.32, Vector3(ex, 0.28, 1.30), Color("2d3436"), Vector3(90, 0, 0))
				vab._add_cylinder(root, 0.06, 0.05, Vector3(ex, 0.28, 1.45), Color("ff3838"), Vector3(90, 0, 0), true)
		"dark_matter_phantom":
			var prim: Color = recipe.get("primary_color", Color("0f0c29"))
			var sec: Color = recipe.get("secondary_color", Color("302b63"))
			var win: Color = recipe.get("window_color", Color("8e44ad"))
			var acc: Color = recipe.get("accent_color", Color("9b59b6"))
			# Mythic Dark Matter Phantom: Hyper-faceted stealth fuselage, sunken graviton induction vortex, accretion ring & orbiting singularity shards
			vab._add_wheels(root, 0.33, 0.24, 0.68, 0.86)
			vab._add_flared_wheel_wells(root, 0.68, 0.86, prim)
			vab._add_box(root, Vector3(1.30, 0.26, 2.55), Vector3(0.0, 0.22, 0.0), prim)
			# Forward stealth arrow splitter & canards
			vab._add_box(root, Vector3(1.15, 0.08, 0.75), Vector3(0.0, 0.12, -1.35), sec)
			for side_x in [-1.0, 1.0]:
				vab._add_box(root, Vector3(0.35, 0.04, 0.40), Vector3(0.62 * side_x, 0.18, -1.25), sec, false, Vector3(-10, 0, 20 * side_x))
				vab._add_box(root, Vector3(0.38, 0.05, 0.04), Vector3(0.62 * side_x, 0.18, -1.45), acc, true, Vector3(-10, 0, 20 * side_x))
				# Rear lateral stabilizer fins with violet edge
				vab._add_box(root, Vector3(0.05, 0.24, 0.75), Vector3(0.64 * side_x, 0.40, 0.75), sec, false, Vector3(-10, 0, -15 * side_x))
				vab._add_box(root, Vector3(0.06, 0.06, 0.78), Vector3(0.64 * side_x, 0.52, 0.75), acc, true, Vector3(-10, 0, -15 * side_x))
			# Sunken Graviton Induction Vortex on Hood
			vab._add_cylinder(root, 0.32, 0.08, Vector3(0.0, 0.33, -0.65), Color("050505"))
			vab._add_torus(root, 0.22, 0.30, Vector3(0.0, 0.35, -0.65), acc, Vector3.ZERO, true)
			# Faceted stealth cockpit canopy & longitudinal roof energy spine
			vab._add_box(root, Vector3(0.74, 0.22, 1.15), Vector3(0.0, 0.42, -0.15), win)
			vab._add_box(root, Vector3(0.04, 0.06, 1.25), Vector3(0.0, 0.54, -0.15), acc, true)
			# Event Horizon Accretion Disk & Jet-Black Singularity Core
			vab._add_torus(root, 0.24, 0.44, Vector3(0.0, 0.52, 0.48), acc, Vector3(90, 0, 0), true)
			vab._add_torus(root, 0.18, 0.38, Vector3(0.0, 0.52, 0.48), Color("302b63"), Vector3(90, 0, 0))
			vab._add_sphere(root, 0.22, Vector3(0.0, 0.52, 0.48), Color("000000"))
			# 4 Orbiting Singularity Crystals
			for orb_i in range(4):
				var ang: float = orb_i * (PI / 2.0)
				vab._add_box(root, Vector3(0.08, 0.08, 0.08), Vector3(cos(ang) * 0.55, 0.52 + sin(ang) * 0.15, 0.48), acc, true)
			# Rear Multi-blade Diffuser & Quad Warp Exhausts
			for df in [-0.5, -0.25, 0.0, 0.25, 0.5]:
				vab._add_box(root, Vector3(0.03, 0.18, 0.45), Vector3(df, 0.16, 1.25), sec)
			for w_side in [-0.42, -0.18, 0.18, 0.42]:
				vab._add_cylinder(root, 0.09, 0.25, Vector3(w_side, 0.28, 1.28), Color("151528"), Vector3(90, 0, 0))
				vab._add_cylinder(root, 0.06, 0.04, Vector3(w_side, 0.28, 1.40), Color("e056fd"), Vector3(90, 0, 0), true)
		"ufo_flying_saucer":
			var prim: Color = recipe.get("primary_color", Color("2c3e50"))
			var sec: Color = recipe.get("secondary_color", Color("1abc9c"))
			var win: Color = recipe.get("window_color", Color("27ae60"))
			var acc: Color = recipe.get("accent_color", Color("2ecc71"))
			# Mythic UFO Flying Saucer: Multi-tier saucer disc, 12 perimeter flux emitters, visible alien pilot in dome, abduction tractor array
			vab._add_wheels(root, 0.24, 0.18, 0.72, 0.60)
			# Inverted cone base, wide flange disc, and mechanical tiered decks
			vab._add_cylinder(root, 1.25, 0.14, Vector3(0.0, 0.18, 0.0), Color("1e272e"))
			vab._add_cylinder(root, 1.55, 0.12, Vector3(0.0, 0.28, 0.0), prim)
			vab._add_cylinder(root, 1.30, 0.15, Vector3(0.0, 0.38, 0.0), sec)
			vab._add_cylinder(root, 0.95, 0.14, Vector3(0.0, 0.48, 0.0), prim)
			# 12 Perimeter Glowing Emerald Flux Emitters (every 30 degrees)
			for orb_i in range(12):
				var rad_ang: float = orb_i * (TAU / 12.0)
				vab._add_cylinder(root, 0.09, 0.07, Vector3(cos(rad_ang) * 1.50, 0.28, sin(rad_ang) * 1.50), acc, Vector3.ZERO, true)
				vab._add_cylinder(root, 0.12, 0.04, Vector3(cos(rad_ang) * 1.50, 0.28, sin(rad_ang) * 1.50), Color("1e272e"))
			# Transparent Emerald Glass Cockpit Dome with Visible Grey Alien Pilot!
			vab._add_sphere(root, 0.58, Vector3(0.0, 0.60, 0.0), win)
			# Mini Alien Pilot (pale head, large almond black eyes, silver suit, holo console)
			vab._add_sphere(root, 0.14, Vector3(0.0, 0.68, -0.05), Color("b2bec3"))
			vab._add_sphere(root, 0.05, Vector3(-0.06, 0.70, -0.16), Color("000000"))
			vab._add_sphere(root, 0.05, Vector3(0.06, 0.70, -0.16), Color("000000"))
			vab._add_box(root, Vector3(0.18, 0.16, 0.14), Vector3(0.0, 0.52, -0.05), Color("718093"))
			vab._add_box(root, Vector3(0.22, 0.12, 0.18), Vector3(0.0, 0.52, -0.22), acc, true)
			# Communication Antenna Mast & Pulsing Orb
			vab._add_cylinder(root, 0.02, 0.28, Vector3(0.0, 1.05, 0.0), Color("d2dae2"))
			vab._add_sphere(root, 0.08, Vector3(0.0, 1.20, 0.0), acc, true)
			# Underside Abduction Tractor Array (concentric rings and white lens)
			vab._add_cylinder(root, 0.65, 0.05, Vector3(0.0, 0.12, 0.0), acc, Vector3.ZERO, true)
			vab._add_torus(root, 0.45, 0.60, Vector3(0.0, 0.13, 0.0), Color("1abc9c"), Vector3.ZERO, true)
			vab._add_cylinder(root, 0.30, 0.06, Vector3(0.0, 0.11, 0.0), Color("ffffff"), Vector3.ZERO, true)
		"cosmic_hyper_star":
			var prim: Color = recipe.get("primary_color", Color("fd79a8"))
			var sec: Color = recipe.get("secondary_color", Color("6c5ce7"))
			var win: Color = recipe.get("window_color", Color("a29bfe"))
			var acc: Color = recipe.get("accent_color", Color("ffeaa7"))
			# Mythic Cosmic Hyper-Star: Prismatic celestial speeder, solar corona wings, floating mag-lev stardust fins, glowing star core engine, triple ion thrusters
			vab._add_wheels(root, 0.34, 0.25, 0.67, 0.88)
			vab._add_flared_wheel_wells(root, 0.67, 0.88, prim)
			vab._add_box(root, Vector3(1.28, 0.26, 2.60), Vector3(0.0, 0.22, 0.0), prim)
			# Dual Crystalline Dart Splitters with Solar Gold Flare
			vab._add_box(root, Vector3(1.18, 0.10, 0.70), Vector3(0.0, 0.14, -1.35), sec)
			vab._add_box(root, Vector3(1.05, 0.04, 0.15), Vector3(0.0, 0.12, -1.68), acc, true)
			for g in range(3):
				vab._add_box(root, Vector3(0.45, 0.03, 0.08), Vector3(0.0, 0.29, -0.75 + g * 0.18), Color("00d2d3"), true)
			# Swept Solar Corona Wings & Floating Mag-Lev Stardust Fins
			for side_x in [-1.0, 1.0]:
				vab._add_box(root, Vector3(0.42, 0.05, 0.95), Vector3(0.72 * side_x, 0.44, 0.70), sec, false, Vector3(12, 0, -25 * side_x))
				vab._add_box(root, Vector3(0.10, 0.07, 0.98), Vector3(0.90 * side_x, 0.50, 0.70), acc, true, Vector3(12, 0, -25 * side_x))
				# Detached Floating Stardust Wingtips
				vab._add_box(root, Vector3(0.06, 0.32, 0.55), Vector3(1.08 * side_x, 0.65, 0.85), prim, false, Vector3(-15, 0, 15 * side_x))
				vab._add_box(root, Vector3(0.08, 0.05, 0.58), Vector3(1.08 * side_x, 0.82, 0.85), Color("00d2d3"), true, Vector3(-15, 0, 15 * side_x))
			# Prismatic Crystalline Quartz Canopy & Glowing Star Core Engine
			vab._add_box(root, Vector3(0.72, 0.24, 1.15), Vector3(0.0, 0.42, -0.10), win)
			vab._add_sphere(root, 0.26, Vector3(0.0, 0.45, 0.48), Color("ffeaa7"), true)
			vab._add_torus(root, 0.28, 0.36, Vector3(0.0, 0.45, 0.48), Color("fd79a8"), Vector3(0, 0, 90), true)
			vab._add_torus(root, 0.28, 0.36, Vector3(0.0, 0.45, 0.48), Color("00d2d3"), Vector3(90, 0, 0), true)
			# Triple Lightspeed Ion Thrusters
			for ex_i in [-0.40, 0.0, 0.40]:
				vab._add_cylinder(root, 0.12, 0.26, Vector3(ex_i, 0.28, 1.32), Color("2c3e50"), Vector3(90, 0, 0))
				vab._add_cylinder(root, 0.08, 0.05, Vector3(ex_i, 0.28, 1.45), Color("ffeaa7"), Vector3(90, 0, 0), true)
				vab._add_cylinder(root, 0.04, 0.06, Vector3(ex_i, 0.28, 1.46), Color("00d2d3"), Vector3(90, 0, 0), true)
		_:
			_build_coupe(root, car_id, recipe, vab)

# =============================================================================
# COMPOSABLE ATTACHMENT DECORATORS
# =============================================================================
static func _apply_features(root: Node3D, recipe: Dictionary, b_len: float, b_wid: float, b_hgt: float, cab_len: float, cab_hgt: float, cab_z: float, prim: Color, sec: Color, vab: Node) -> void:
	var roof_feat: String = String(recipe.get("roof_feature", "NONE"))
	var hood_feat: String = String(recipe.get("hood_feature", "NONE"))
	var rear_feat: String = String(recipe.get("rear_feature", "NONE"))
	
	# ROOF ATTACHMENTS
	match roof_feat:
		"POLICE_LIGHTBAR":
			var bar = vab._add_box(root, Vector3(0.78, 0.08, 0.16), Vector3(0.0, 0.24 + b_hgt + cab_hgt * 0.90, cab_z), Color("2f3640"))
			# Left red LED bank + Right blue LED bank + Center white takedown
			vab._add_box(bar, Vector3(0.32, 0.08, 0.14), Vector3(-0.22, 0.0, 0.0), Color("ff3838"), true)
			vab._add_box(bar, Vector3(0.32, 0.08, 0.14), Vector3(0.22, 0.0, 0.0), Color("00d2d3"), true)
			vab._add_box(bar, Vector3(0.12, 0.08, 0.14), Vector3(0.0, 0.0, 0.0), Color("ffffff"), true)
		"TAXI_SIGN":
			# Illuminated 3D taxi dome with black TAXI text bar
			vab._add_box(root, Vector3(0.52, 0.15, 0.18), Vector3(0.0, 0.24 + b_hgt + cab_hgt * 0.92, cab_z), Color("f1c40f"), true)
			vab._add_box(root, Vector3(0.40, 0.08, 0.19), Vector3(0.0, 0.24 + b_hgt + cab_hgt * 0.92, cab_z), Color("1e272e"))
		"AMBULANCE_BEACONS":
			vab._add_cylinder(root, 0.09, 0.14, Vector3(-b_wid * 0.35, 0.24 + b_hgt + cab_hgt * 0.90, cab_z - 0.4), Color("00d2d3"), Vector3.ZERO, true)
			vab._add_cylinder(root, 0.09, 0.14, Vector3(b_wid * 0.35, 0.24 + b_hgt + cab_hgt * 0.90, cab_z - 0.4), Color("ff3838"), Vector3.ZERO, true)
		"GIANT_PIZZA_SLICE":
			# Triangular wedge pizza slice with crust, cheese, and pepperoni
			vab._add_box(root, Vector3(0.85, 0.12, 0.85), Vector3(0.0, 0.24 + b_hgt + cab_hgt * 0.92, cab_z), Color("f1c40f"), false, Vector3(-15, 0, 0))
			vab._add_box(root, Vector3(0.88, 0.14, 0.14), Vector3(0.0, 0.24 + b_hgt + cab_hgt * 0.94, cab_z + 0.40), Color("e67e22"), false, Vector3(-15, 0, 0)) # Crust
			vab._add_cylinder(root, 0.10, 0.06, Vector3(-0.15, 0.24 + b_hgt + cab_hgt * 0.97, cab_z - 0.10), Color("e74c3c")) # Pepperoni
			vab._add_cylinder(root, 0.10, 0.06, Vector3(0.18, 0.24 + b_hgt + cab_hgt * 0.97, cab_z + 0.15), Color("e74c3c"))
		"GIANT_TACO_SOMBRERO":
			vab._add_cylinder(root, 0.48, 0.06, Vector3(0.0, 0.24 + b_hgt + cab_hgt * 0.90, cab_z), Color("f9ca24")) # Sombrero brim
			vab._add_box(root, Vector3(0.70, 0.25, 0.24), Vector3(0.0, 0.24 + b_hgt + cab_hgt * 0.98, cab_z), Color("6ab04c")) # Taco shell & lettuce
			vab._add_box(root, Vector3(0.12, 0.08, 0.12), Vector3(-0.15, 0.24 + b_hgt + cab_hgt * 1.05, cab_z), Color("e74c3c")) # Tomato
			vab._add_box(root, Vector3(0.12, 0.08, 0.12), Vector3(0.15, 0.24 + b_hgt + cab_hgt * 1.05, cab_z), Color("f1c40f")) # Cheese
		"SURFBOARD_RACK", "WOOD_ROOF_RACK":
			# Wooden roof rack with colorful striped surfboard
			vab._add_box(root, Vector3(0.88, 0.05, 1.15), Vector3(0.0, 0.24 + b_hgt + cab_hgt * 0.90, cab_z), Color("d35400"))
			vab._add_box(root, Vector3(0.26, 0.06, 1.30), Vector3(0.12, 0.24 + b_hgt + cab_hgt * 0.95, cab_z), Color("00d2d3"))
			vab._add_box(root, Vector3(0.06, 0.07, 1.28), Vector3(0.12, 0.24 + b_hgt + cab_hgt * 0.96, cab_z), Color("f5f6fa")) # Center stringer
		"ROOF_SPOILER":
			vab._add_box(root, Vector3(b_wid * 0.88, 0.06, 0.24), Vector3(0.0, 0.24 + b_hgt + cab_hgt * 0.92, cab_z + cab_len * 0.5), prim)
			
	# HOOD ATTACHMENTS
	match hood_feat:
		"BLOWER_VALVES":
			# Roots Supercharger Blower with Triple Red Butterfly Valves
			vab._add_box(root, Vector3(0.35, 0.20, 0.45), Vector3(0.0, 0.44, -b_len * 0.25), Color("d2dae2"))
			vab._add_cylinder(root, 0.05, 0.12, Vector3(-0.09, 0.52, -b_len * 0.25), Color("ff3f34"), Vector3(90, 0, 0), true)
			vab._add_cylinder(root, 0.05, 0.12, Vector3(0.0, 0.52, -b_len * 0.25), Color("ff3f34"), Vector3(90, 0, 0), true)
			vab._add_cylinder(root, 0.05, 0.12, Vector3(0.09, 0.52, -b_len * 0.25), Color("ff3f34"), Vector3(90, 0, 0), true)
		"POPUP_LIGHTS":
			vab._add_box(root, Vector3(0.24, 0.12, 0.22), Vector3(-b_wid * 0.32, 0.42, -b_len * 0.42), Color("1e272e"))
			vab._add_box(root, Vector3(0.24, 0.12, 0.22), Vector3(b_wid * 0.32, 0.42, -b_len * 0.42), Color("1e272e"))
			vab._add_box(root, Vector3(0.18, 0.08, 0.04), Vector3(-b_wid * 0.32, 0.42, -b_len * 0.42 - 0.12), Color("fff200"), true)
			vab._add_box(root, Vector3(0.18, 0.08, 0.04), Vector3(b_wid * 0.32, 0.42, -b_len * 0.42 - 0.12), Color("fff200"), true)
		"PUSH_BUMPER":
			# Heavy Police Rambar with Siren Speakers
			vab._add_box(root, Vector3(0.70, 0.28, 0.08), Vector3(0.0, 0.25, -b_len * 0.5 - 0.14), Color("1e272e"))
			vab._add_box(root, Vector3(0.06, 0.36, 0.14), Vector3(-0.28, 0.26, -b_len * 0.5 - 0.10), Color("1e272e"))
			vab._add_box(root, Vector3(0.06, 0.36, 0.14), Vector3(0.28, 0.26, -b_len * 0.5 - 0.10), Color("1e272e"))
		"FOUR_SPOTLAMPS":
			for fx in [-0.36, -0.12, 0.12, 0.36]:
				vab._add_cylinder(root, 0.08, 0.06, Vector3(fx, 0.28, -b_len * 0.5 - 0.08), Color("fff200"), Vector3(90, 0, 0), true)
				
	# REAR ATTACHMENTS
	match rear_feat:
		"GT_WING":
			# Dual tall uprights + wide airfoil wing with endplates
			vab._add_box(root, Vector3(0.06, 0.22, 0.08), Vector3(-b_wid * 0.36, 0.46, b_len * 0.45), Color("1e272e"))
			vab._add_box(root, Vector3(0.06, 0.22, 0.08), Vector3(b_wid * 0.36, 0.46, b_len * 0.45), Color("1e272e"))
			vab._add_box(root, Vector3(b_wid * 0.98, 0.05, 0.24), Vector3(0.0, 0.57, b_len * 0.45), prim)
			# Endplates
			vab._add_box(root, Vector3(0.02, 0.12, 0.26), Vector3(-b_wid * 0.49, 0.57, b_len * 0.45), Color("1e272e"))
			vab._add_box(root, Vector3(0.02, 0.12, 0.26), Vector3(b_wid * 0.49, 0.57, b_len * 0.45), Color("1e272e"))
		"DUCKTAIL_SPOILER":
			vab._add_box(root, Vector3(b_wid * 0.92, 0.10, 0.14), Vector3(0.0, 0.42, b_len * 0.48), Color("1e272e"), false, Vector3(-20, 0, 0))
		"SMOKESTACK_EXHAUST":
			vab._add_cylinder(root, 0.06, 0.75, Vector3(-b_wid * 0.42, 0.90, 0.45), Color("d2dae2"))
			vab._add_cylinder(root, 0.06, 0.75, Vector3(b_wid * 0.42, 0.90, 0.45), Color("d2dae2"))
