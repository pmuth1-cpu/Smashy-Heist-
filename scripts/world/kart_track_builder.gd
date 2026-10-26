class_name KartTrackBuilder
extends Node3D

## Procedural 3-Lap 3D Circuit Track Generator for Smashy Kart Grand Prix.
## Builds a ~780-meter closed-loop Path3D / Curve3D with:
## - 18.0m wide dark asphalt road ribbon with dashed centerlines
## - Red & white apex rumble strips on corners (9.0m to 10.4m)
## - Outer asphalt runoff apron (10.4m to 11.55m) seamlessly sealed to barrier base
## - Thick 3D solid concrete crash barriers (11.5m to 12.3m, 2.4m tall, 0.8m thick)
## - 5.0m safety chainlink catch-fences atop barriers (7.4m total containment height)
## - WorldBoundaryShape3D solid ground floor at y = 0.0 on Layer 1 (Ground)
## - Start/Finish checkered gantry archway
## - 4 Sequential anti-cheat checkpoint gates (0%, 25%, 50%, 75%)
## - 6 Rainbow chevron boost pads (1.45x boost for 1.2s)
## - 4 Item box rows (5 boxes each at 15%, 40%, 65%, 85%)
## - Roadside Grandstands with 48 animated cheering spectators at Start/Finish
## - Curved steel street lamp poles every 28m with emissive downward lighting
## - Corner apex 3-tier tire walls with high-visibility hazard chevrons
## - Animated neon drift arrow signs at key drift turns
## - Themed cup aesthetics (Downtown Neon, Chinatown Dragon, Canyon Highway)

const KartItemBoxScene = preload("res://scenes/props/kart_item_box.tscn")

@export var track_path: Path3D = null
var baked_length: float = 0.0

var checkpoints: Array[Area3D] = []
var boost_pads: Array[Area3D] = []
var offroad_areas: Array[Area3D] = []
var item_boxes: Array[Node3D] = []
var roadside_props: Array[Node3D] = []

var road_body: StaticBody3D = null
var barrier_body: StaticBody3D = null
var ground_body: StaticBody3D = null

func _ready() -> void:
	if track_path == null:
		build_track()

func build_track() -> void:
	_clear_existing()
	
	var cup_track: int = 0
	if has_node("/root/GameModeManager"):
		var gmm = get_node("/root/GameModeManager")
		cup_track = int(gmm.selected_cup_track)
	
	_generate_track_curve(cup_track)
	_generate_track_ground(cup_track)
	_generate_road_and_barriers(cup_track)
	_generate_checkpoints()
	_generate_boost_pads()
	_generate_item_boxes()
	_generate_roadside_props(cup_track)
	_generate_scenery(cup_track)

func _clear_existing() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	checkpoints.clear()
	boost_pads.clear()
	offroad_areas.clear()
	item_boxes.clear()
	roadside_props.clear()
	track_path = null
	road_body = null
	barrier_body = null
	ground_body = null

func _generate_track_ground(cup_track: int) -> void:
	# Add solid infinite ground plane physics body on Layer 1 (Ground) so falling into void is impossible
	ground_body = StaticBody3D.new()
	ground_body.name = "KartTrackGroundBody"
	ground_body.collision_layer = 1 # Ground
	ground_body.collision_mask = 0
	add_child(ground_body)
	
	var col := CollisionShape3D.new()
	col.name = "WorldBoundaryCollision"
	var world_plane := WorldBoundaryShape3D.new()
	world_plane.plane = Plane(Vector3.UP, 0.0)
	col.shape = world_plane
	ground_body.add_child(col)
	
	var ground := MeshInstance3D.new()
	ground.name = "KartTrackGround"
	var pmesh := PlaneMesh.new()
	pmesh.size = Vector2(1600.0, 1600.0)
	ground.mesh = pmesh
	ground.position = Vector3(50.0, -0.05, -20.0)
	
	var gmat := StandardMaterial3D.new()
	gmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	match cup_track:
		1: # CHINATOWN: Deep green oriental park grass & stone pathing
			gmat.albedo_color = Color("1e382b")
		2: # CANYON: Warm terracotta desert sand & rock
			gmat.albedo_color = Color("8c4420")
		_: # DOWNTOWN NEON: Dark night asphalt with grid styling
			gmat.albedo_color = Color("0d131f")
	
	gmat.roughness = 0.95
	ground.material_override = gmat
	add_child(ground)

## 1. Closed-Loop Path3D & Curve3D Generation (16 Bezier control points, ~780m)
func _generate_track_curve(cup_track: int) -> void:
	track_path = Path3D.new()
	track_path.name = "TrackPath"
	add_child(track_path)
	
	var curve := Curve3D.new()
	curve.bake_interval = 2.0
	
	var raw_points: Array[Dictionary] = []
	
	match cup_track:
		1: # CHINATOWN_DRAGON_LOOP (270-degree spiral drift + pagoda arches)
			raw_points = [
				{"p": Vector3(0, 0, 0), "in": Vector3(0, 0, -25), "out": Vector3(0, 0, 30)},
				{"p": Vector3(0, 0, 85), "in": Vector3(0, 0, -25), "out": Vector3(10, 0, 25)},
				{"p": Vector3(35, 0, 140), "in": Vector3(-20, 0, -15), "out": Vector3(25, 0, 15)},
				{"p": Vector3(95, 0, 165), "in": Vector3(-25, 0, -5), "out": Vector3(30, 0, 5)},
				# Dragon 270-degree Spiral Coiling Drift Corner
				{"p": Vector3(160, 0, 145), "in": Vector3(-25, 0, 15), "out": Vector3(25, 0, -15)},
				{"p": Vector3(185, 0, 95), "in": Vector3(0, 0, 25), "out": Vector3(0, 0, -25)},
				{"p": Vector3(160, 0, 45), "in": Vector3(25, 0, 15), "out": Vector3(-25, 0, -15)},
				{"p": Vector3(105, 0, 35), "in": Vector3(25, 0, 0), "out": Vector3(-25, 0, 0)},
				{"p": Vector3(65, 0, -15), "in": Vector3(15, 0, 20), "out": Vector3(-15, 0, -25)},
				{"p": Vector3(75, 2.0, -85), "in": Vector3(-5, -1, 25), "out": Vector3(5, 1, -25)},
				{"p": Vector3(95, 0.0, -145), "in": Vector3(-10, 1, 20), "out": Vector3(10, -1, -20)},
				{"p": Vector3(60, 0, -205), "in": Vector3(25, 0, 15), "out": Vector3(-25, 0, -15)},
				{"p": Vector3(-10, 0, -215), "in": Vector3(25, 0, 0), "out": Vector3(-25, 0, 0)},
				{"p": Vector3(-70, 0, -165), "in": Vector3(15, 0, -25), "out": Vector3(-15, 0, 25)},
				{"p": Vector3(-50, 0, -100), "in": Vector3(-10, 0, -25), "out": Vector3(15, 0, 25)},
				{"p": Vector3(0, 0, -50), "in": Vector3(0, 0, -25), "out": Vector3(0, 0, 25)}
			]
		2: # CANYON_HIGHWAY_SPEEDWAY (Sweeping high-banked curves & desert bridge chasm jump)
			raw_points = [
				{"p": Vector3(0, 0, 0), "in": Vector3(0, 0, -30), "out": Vector3(0, 0, 35)},
				{"p": Vector3(0, 0, 105), "in": Vector3(0, 0, -30), "out": Vector3(10, 0, 35)},
				{"p": Vector3(60, 0, 175), "in": Vector3(-25, 0, -20), "out": Vector3(30, 0, 25)},
				{"p": Vector3(135, 0, 195), "in": Vector3(-35, 0, -5), "out": Vector3(35, 0, 5)},
				{"p": Vector3(205, 0, 150), "in": Vector3(-25, 0, 25), "out": Vector3(25, 0, -25)},
				{"p": Vector3(225, 0, 65), "in": Vector3(0, 0, 30), "out": Vector3(0, 0, -30)},
				{"p": Vector3(180, 0, -15), "in": Vector3(25, 0, 25), "out": Vector3(-25, 0, -25)},
				# Broken-Bridge Canyon Jump approach
				{"p": Vector3(145, 3.2, -85), "in": Vector3(15, -1.5, 25), "out": Vector3(-15, 1.5, -25)},
				{"p": Vector3(130, 0.0, -145), "in": Vector3(10, 1.5, 25), "out": Vector3(-10, -1.0, -25)},
				{"p": Vector3(90, 0, -200), "in": Vector3(25, 0, 15), "out": Vector3(-25, 0, -15)},
				{"p": Vector3(15, 0, -225), "in": Vector3(30, 0, 0), "out": Vector3(-30, 0, 0)},
				{"p": Vector3(-65, 0, -195), "in": Vector3(25, 0, -20), "out": Vector3(-25, 0, 20)},
				{"p": Vector3(-105, 0, -125), "in": Vector3(10, 0, -30), "out": Vector3(-10, 0, 30)},
				{"p": Vector3(-90, 0, -55), "in": Vector3(-15, 0, -25), "out": Vector3(15, 0, 25)},
				{"p": Vector3(-60, 0, -110), "in": Vector3(-15, 0, -25), "out": Vector3(15, 0, 25)},
				{"p": Vector3(0, 0, -55), "in": Vector3(0, 0, -25), "out": Vector3(0, 0, 25)}
			]
		_: # 0: DOWNTOWN_NEON_CIRCUIT (Default)
			raw_points = [
				{"p": Vector3(0, 0, 0), "in": Vector3(0, 0, -30), "out": Vector3(0, 0, 35)},
				{"p": Vector3(0, 0, 95), "in": Vector3(0, 0, -30), "out": Vector3(5, 0, 30)},
				{"p": Vector3(25, 0, 160), "in": Vector3(-15, 0, -25), "out": Vector3(25, 0, 25)},
				{"p": Vector3(90, 0, 195), "in": Vector3(-30, 0, -5), "out": Vector3(30, 0, 5)},
				{"p": Vector3(155, 0, 165), "in": Vector3(-25, 0, 20), "out": Vector3(25, 0, -20)},
				{"p": Vector3(175, 0, 95), "in": Vector3(5, 0, 30), "out": Vector3(-5, 0, -30)},
				{"p": Vector3(145, 0, 25), "in": Vector3(15, 0, 25), "out": Vector3(-15, 0, -25)},
				{"p": Vector3(165, 0, -45), "in": Vector3(-10, 0, 25), "out": Vector3(10, 0, -25)},
				# River Jump approach and landing
				{"p": Vector3(180, 2.8, -115), "in": Vector3(-5, -1.2, 25), "out": Vector3(5, 1.2, -25)},
				{"p": Vector3(165, 0.0, -165), "in": Vector3(10, 1.2, 20), "out": Vector3(-10, -1.0, -20)},
				{"p": Vector3(115, 0, -215), "in": Vector3(25, 0, 15), "out": Vector3(-25, 0, -15)},
				{"p": Vector3(35, 0, -235), "in": Vector3(30, 0, 0), "out": Vector3(-30, 0, 0)},
				{"p": Vector3(-45, 0, -205), "in": Vector3(25, 0, -20), "out": Vector3(-25, 0, 20)},
				{"p": Vector3(-80, 0, -125), "in": Vector3(10, 0, -30), "out": Vector3(-10, 0, 30)},
				{"p": Vector3(-55, 0, -95), "in": Vector3(-15, 0, -20), "out": Vector3(15, 0, 20)},
				{"p": Vector3(0, 0, -55), "in": Vector3(0, 0, -25), "out": Vector3(0, 0, 25)}
			]
	
	for pt_data in raw_points:
		curve.add_point(pt_data["p"], pt_data["in"], pt_data["out"])
	curve.add_point(raw_points[0]["p"], raw_points[0]["in"], raw_points[0]["out"])
	
	var initial_len := curve.get_baked_length()
	if initial_len > 0.0:
		var scale_factor: float = 780.0 / initial_len
		curve.clear_points()
		for pt_data in raw_points:
			curve.add_point(pt_data["p"] * scale_factor, pt_data["in"] * scale_factor, pt_data["out"] * scale_factor)
		curve.add_point(raw_points[0]["p"] * scale_factor, raw_points[0]["in"] * scale_factor, raw_points[0]["out"] * scale_factor)

	track_path.curve = curve
	baked_length = curve.get_baked_length()
	print("KartTrackBuilder: Track generated with baked length %.1fm" % baked_length)

## 2. 3D Road Surface, Curbs, Outer Sealed Apron, 3D Solid Barriers & Catch-Fences
func _generate_road_and_barriers(cup_track: int) -> void:
	road_body = StaticBody3D.new()
	road_body.name = "RoadSurfaceBody"
	road_body.collision_layer = 1 # Ground
	road_body.collision_mask = 0
	add_child(road_body)
	
	barrier_body = StaticBody3D.new()
	barrier_body.name = "BarrierBody"
	barrier_body.collision_layer = 8 # Layer 4 (Buildings)
	barrier_body.collision_mask = 0
	add_child(barrier_body)
	
	var curve := track_path.curve
	var step_size: float = 3.5
	var steps: int = int(ceil(baked_length / step_size))
	
	var road_st := SurfaceTool.new()
	road_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var barrier_st := SurfaceTool.new()
	barrier_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var fence_st := SurfaceTool.new()
	fence_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var curb_st := SurfaceTool.new()
	curb_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var dash_st := SurfaceTool.new()
	dash_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var road_half_w: float = 9.0 # 18m total width
	var curb_outer: float = 10.4
	var barrier_inner: float = 11.55
	var barrier_outer: float = 12.35 # 0.8m thick solid crash wall
	var barrier_h: float = 2.4 # 2.4m concrete barrier
	var fence_h: float = 5.0 # 5.0m safety catch-fence atop barrier (7.4m total)
	
	# Precompute frame points along the curve
	var frames: Array[Dictionary] = []
	for i in range(steps + 1):
		var d: float = fposmod(float(i) * step_size, baked_length)
		var pos: Vector3 = curve.sample_baked(d)
		var next_pos: Vector3 = curve.sample_baked(fposmod(d + 1.0, baked_length))
		var fwd: Vector3 = (next_pos - pos).normalized()
		if fwd.length_squared() < 0.001:
			fwd = Vector3.FORWARD
		var right: Vector3 = fwd.cross(Vector3.UP).normalized()
		var up: Vector3 = right.cross(fwd).normalized()
		frames.append({"pos": pos, "fwd": fwd, "right": right, "up": up, "dist": d})
	
	for i in range(steps):
		var f0: Dictionary = frames[i]
		var f1: Dictionary = frames[i + 1]
		
		var p0: Vector3 = f0["pos"]
		var r0: Vector3 = f0["right"]
		var u0: Vector3 = f0["up"]
		
		var p1: Vector3 = f1["pos"]
		var r1: Vector3 = f1["right"]
		var u1: Vector3 = f1["up"]
		
		# ---------------------------------------------------------------------
		# A. Main Road Surface (18m wide, elevated 0.12m above ground)
		# ---------------------------------------------------------------------
		var r_left0: Vector3 = p0 - r0 * road_half_w + u0 * 0.12
		var r_right0: Vector3 = p0 + r0 * road_half_w + u0 * 0.12
		var r_left1: Vector3 = p1 - r1 * road_half_w + u1 * 0.12
		var r_right1: Vector3 = p1 + r1 * road_half_w + u1 * 0.12
		
		road_st.set_normal(u0)
		road_st.set_color(Color(0.12, 0.13, 0.16))
		
		road_st.add_vertex(r_left0)
		road_st.add_vertex(r_left1)
		road_st.add_vertex(r_right0)
		
		road_st.add_vertex(r_right0)
		road_st.add_vertex(r_left1)
		road_st.add_vertex(r_right1)
		
		# ---------------------------------------------------------------------
		# B. Dashed Centerline (elevated 0.15m)
		# ---------------------------------------------------------------------
		if (i % 2) == 0:
			var dash_w: float = 0.35
			dash_st.set_normal(u0)
			dash_st.set_color(Color.WHITE)
			var d_l0: Vector3 = p0 - r0 * dash_w + u0 * 0.15
			var d_r0: Vector3 = p0 + r0 * dash_w + u0 * 0.15
			var d_l1: Vector3 = p1 - r1 * dash_w + u1 * 0.15
			var d_r1: Vector3 = p1 + r1 * dash_w + u1 * 0.15
			
			dash_st.add_vertex(d_l0)
			dash_st.add_vertex(d_l1)
			dash_st.add_vertex(d_r0)
			
			dash_st.add_vertex(d_r0)
			dash_st.add_vertex(d_l1)
			dash_st.add_vertex(d_r1)
		
		# ---------------------------------------------------------------------
		# C. Alternating Red & White Rumble Curbs (9.0m to 10.4m)
		# ---------------------------------------------------------------------
		var curb_col: Color = Color("e74c3c") if (i % 2 == 0) else Color("f5f6fa")
		curb_st.set_normal(u0)
		curb_st.set_color(curb_col)
		
		# Left rumble strip
		var c_l_in0: Vector3 = p0 - r0 * road_half_w + u0 * 0.13
		var c_l_out0: Vector3 = p0 - r0 * curb_outer + u0 * 0.22
		var c_l_in1: Vector3 = p1 - r1 * road_half_w + u1 * 0.13
		var c_l_out1: Vector3 = p1 - r1 * curb_outer + u1 * 0.22
		
		curb_st.add_vertex(c_l_in0)
		curb_st.add_vertex(c_l_in1)
		curb_st.add_vertex(c_l_out0)
		
		curb_st.add_vertex(c_l_out0)
		curb_st.add_vertex(c_l_in1)
		curb_st.add_vertex(c_l_out1)
		
		# Right rumble strip
		var c_r_in0: Vector3 = p0 + r0 * road_half_w + u0 * 0.13
		var c_r_out0: Vector3 = p0 + r0 * curb_outer + u0 * 0.22
		var c_r_in1: Vector3 = p1 + r1 * road_half_w + u1 * 0.13
		var c_r_out1: Vector3 = p1 + r1 * curb_outer + u1 * 0.22
		
		curb_st.add_vertex(c_r_out0)
		curb_st.add_vertex(c_r_out1)
		curb_st.add_vertex(c_r_in0)
		
		curb_st.add_vertex(c_r_in0)
		curb_st.add_vertex(c_r_out1)
		curb_st.add_vertex(c_r_in1)
		
		# ---------------------------------------------------------------------
		# D. Continuous Outer Apron (10.4m to 11.55m) — SEALS GAP TO BARRIER!
		# ---------------------------------------------------------------------
		road_st.set_normal(u0)
		road_st.set_color(Color(0.18, 0.20, 0.24)) # Dark runoff tarmac
		
		# Left Apron
		var ap_l_in0: Vector3 = c_l_out0
		var ap_l_out0: Vector3 = p0 - r0 * barrier_inner + u0 * 0.12
		var ap_l_in1: Vector3 = c_l_out1
		var ap_l_out1: Vector3 = p1 - r1 * barrier_inner + u1 * 0.12
		
		road_st.add_vertex(ap_l_in0)
		road_st.add_vertex(ap_l_in1)
		road_st.add_vertex(ap_l_out0)
		
		road_st.add_vertex(ap_l_out0)
		road_st.add_vertex(ap_l_in1)
		road_st.add_vertex(ap_l_out1)
		
		# Right Apron
		var ap_r_in0: Vector3 = c_r_out0
		var ap_r_out0: Vector3 = p0 + r0 * barrier_inner + u0 * 0.12
		var ap_r_in1: Vector3 = c_r_out1
		var ap_r_out1: Vector3 = p1 + r1 * barrier_inner + u1 * 0.12
		
		road_st.add_vertex(ap_r_out0)
		road_st.add_vertex(ap_r_out1)
		road_st.add_vertex(ap_r_in0)
		
		road_st.add_vertex(ap_r_in0)
		road_st.add_vertex(ap_r_out1)
		road_st.add_vertex(ap_r_in1)
		
		# ---------------------------------------------------------------------
		# E. 3D Solid Concrete Barriers (11.55m to 12.35m, height 2.4m)
		# ---------------------------------------------------------------------
		var b_col: Color = Color("00d2d3") if cup_track == 0 else (Color("e84118") if cup_track == 1 else Color("e67e22"))
		barrier_st.set_color(b_col)
		
		# --- LEFT BARRIER 3D SOLID ---
		var bl_in_b0: Vector3 = p0 - r0 * barrier_inner
		var bl_in_t0: Vector3 = bl_in_b0 + u0 * barrier_h
		var bl_out_b0: Vector3 = p0 - r0 * barrier_outer
		var bl_out_t0: Vector3 = bl_out_b0 + u0 * barrier_h
		
		var bl_in_b1: Vector3 = p1 - r1 * barrier_inner
		var bl_in_t1: Vector3 = bl_in_b1 + u1 * barrier_h
		var bl_out_b1: Vector3 = p1 - r1 * barrier_outer
		var bl_out_t1: Vector3 = bl_out_b1 + u1 * barrier_h
		
		# Left Inner Face (facing track)
		barrier_st.set_normal(r0)
		barrier_st.add_vertex(bl_in_b0)
		barrier_st.add_vertex(bl_in_t0)
		barrier_st.add_vertex(bl_in_b1)
		barrier_st.add_vertex(bl_in_b1)
		barrier_st.add_vertex(bl_in_t0)
		barrier_st.add_vertex(bl_in_t1)
		
		# Left Top Cap
		barrier_st.set_normal(u0)
		barrier_st.add_vertex(bl_in_t0)
		barrier_st.add_vertex(bl_out_t0)
		barrier_st.add_vertex(bl_in_t1)
		barrier_st.add_vertex(bl_in_t1)
		barrier_st.add_vertex(bl_out_t0)
		barrier_st.add_vertex(bl_out_t1)
		
		# Left Outer Face
		barrier_st.set_normal(-r0)
		barrier_st.add_vertex(bl_out_b1)
		barrier_st.add_vertex(bl_out_t1)
		barrier_st.add_vertex(bl_out_b0)
		barrier_st.add_vertex(bl_out_b0)
		barrier_st.add_vertex(bl_out_t1)
		barrier_st.add_vertex(bl_out_t0)
		
		# --- RIGHT BARRIER 3D SOLID ---
		var br_in_b0: Vector3 = p0 + r0 * barrier_inner
		var br_in_t0: Vector3 = br_in_b0 + u0 * barrier_h
		var br_out_b0: Vector3 = p0 + r0 * barrier_outer
		var br_out_t0: Vector3 = br_out_b0 + u0 * barrier_h
		
		var br_in_b1: Vector3 = p1 + r1 * barrier_inner
		var br_in_t1: Vector3 = br_in_b1 + u1 * barrier_h
		var br_out_b1: Vector3 = p1 + r1 * barrier_outer
		var br_out_t1: Vector3 = br_out_b1 + u1 * barrier_h
		
		# Right Inner Face (facing track)
		barrier_st.set_normal(-r0)
		barrier_st.add_vertex(br_in_b0)
		barrier_st.add_vertex(br_in_b1)
		barrier_st.add_vertex(br_in_t0)
		barrier_st.add_vertex(br_in_t0)
		barrier_st.add_vertex(br_in_b1)
		barrier_st.add_vertex(br_in_t1)
		
		# Right Top Cap
		barrier_st.set_normal(u0)
		barrier_st.add_vertex(br_in_t0)
		barrier_st.add_vertex(br_in_t1)
		barrier_st.add_vertex(br_out_t0)
		barrier_st.add_vertex(br_out_t0)
		barrier_st.add_vertex(br_in_t1)
		barrier_st.add_vertex(br_out_t1)
		
		# Right Outer Face
		barrier_st.set_normal(r0)
		barrier_st.add_vertex(br_out_b0)
		barrier_st.add_vertex(br_out_t0)
		barrier_st.add_vertex(br_out_b1)
		barrier_st.add_vertex(br_out_b1)
		barrier_st.add_vertex(br_out_t0)
		barrier_st.add_vertex(br_out_t1)
		
		# ---------------------------------------------------------------------
		# F. 5.0m Semi-Transparent Safety Catch-Fences (Atop Barrier to 7.4m)
		# ---------------------------------------------------------------------
		fence_st.set_color(Color(0.2, 0.25, 0.3, 0.65))
		
		# Left Catch Fence
		var fl_b0: Vector3 = bl_in_t0
		var fl_t0: Vector3 = bl_in_t0 + u0 * fence_h
		var fl_b1: Vector3 = bl_in_t1
		var fl_t1: Vector3 = bl_in_t1 + u1 * fence_h
		
		fence_st.set_normal(r0)
		fence_st.add_vertex(fl_b0)
		fence_st.add_vertex(fl_t0)
		fence_st.add_vertex(fl_b1)
		fence_st.add_vertex(fl_b1)
		fence_st.add_vertex(fl_t0)
		fence_st.add_vertex(fl_t1)
		
		# Right Catch Fence
		var fr_b0: Vector3 = br_in_t0
		var fr_t0: Vector3 = br_in_t0 + u0 * fence_h
		var fr_b1: Vector3 = br_in_t1
		var fr_t1: Vector3 = br_in_t1 + u1 * fence_h
		
		fence_st.set_normal(-r0)
		fence_st.add_vertex(fr_b0)
		fence_st.add_vertex(fr_b1)
		fence_st.add_vertex(fr_t0)
		fence_st.add_vertex(fr_t0)
		fence_st.add_vertex(fr_b1)
		fence_st.add_vertex(fr_t1)
	
	# Commit Road Mesh & Collision
	var road_mesh := road_st.commit()
	var road_mi := MeshInstance3D.new()
	road_mi.mesh = road_mesh
	var rmat := StandardMaterial3D.new()
	rmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	rmat.vertex_color_use_as_albedo = true
	rmat.roughness = 0.82
	road_mi.material_override = rmat
	road_body.add_child(road_mi)
	
	var road_col := CollisionShape3D.new()
	road_col.shape = road_mesh.create_trimesh_shape()
	road_body.add_child(road_col)
	
	# Commit Dashes
	var dash_mesh := dash_st.commit()
	var dash_mi := MeshInstance3D.new()
	dash_mi.name = "DashLines"
	dash_mi.mesh = dash_mesh
	var dmat := StandardMaterial3D.new()
	dmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.albedo_color = Color.WHITE
	dash_mi.material_override = dmat
	road_body.add_child(dash_mi)
	
	# Commit Rumble Curbs
	var curb_mesh := curb_st.commit()
	var curb_mi := MeshInstance3D.new()
	curb_mi.name = "RumbleCurbs"
	curb_mi.mesh = curb_mesh
	var cmat := StandardMaterial3D.new()
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cmat.vertex_color_use_as_albedo = true
	cmat.roughness = 0.55
	curb_mi.material_override = cmat
	road_body.add_child(curb_mi)
	
	# Commit Barriers & Collision
	var bar_mesh := barrier_st.commit()
	var bar_mi := MeshInstance3D.new()
	bar_mi.mesh = bar_mesh
	var bmat := StandardMaterial3D.new()
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bmat.vertex_color_use_as_albedo = true
	bmat.emission_enabled = true
	bmat.emission = Color("00d2d3") if cup_track == 0 else (Color("e84118") if cup_track == 1 else Color("e67e22"))
	bmat.emission_energy_multiplier = 0.95
	bar_mi.material_override = bmat
	barrier_body.add_child(bar_mi)
	
	var bar_col := CollisionShape3D.new()
	bar_col.shape = bar_mesh.create_trimesh_shape()
	barrier_body.add_child(bar_col)
	
	# Commit Catch Fences
	var fence_mesh := fence_st.commit()
	var fence_mi := MeshInstance3D.new()
	fence_mi.name = "SafetyCatchFences"
	fence_mi.mesh = fence_mesh
	var fmat := StandardMaterial3D.new()
	fmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.albedo_color = Color(0.2, 0.25, 0.32, 0.58)
	fmat.metallic = 0.75
	fmat.roughness = 0.4
	fence_mi.material_override = fmat
	barrier_body.add_child(fence_mi)
	
	# Also add Catch Fence Trimesh collision to barrier body to ensure 7.4m containment
	var fence_col := CollisionShape3D.new()
	fence_col.shape = fence_mesh.create_trimesh_shape()
	barrier_body.add_child(fence_col)
	
	# Off-Road Inner Apron Shortcut Zones (inside hairpin curves)
	_build_offroad_aprons(cup_track)

func _build_offroad_aprons(cup_track: int) -> void:
	var apron_offsets: Array[float] = [baked_length * 0.22, baked_length * 0.72]
	var curve := track_path.curve
	
	for off in apron_offsets:
		var pos := curve.sample_baked(off)
		var next_pos := curve.sample_baked(off + 2.0)
		var fwd := (next_pos - pos).normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		
		# Place apron inside the curve (e.g. -14m inside)
		var apron_center := pos - right * 14.0
		
		var apron := Area3D.new()
		apron.name = "KartOffroadApron"
		apron.collision_layer = 0
		apron.collision_mask = 2 | 4 # Cars
		apron.add_to_group("kart_offroad")
		
		var cshape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(14.0, 1.5, 24.0)
		cshape.shape = box
		apron.add_child(cshape)
		
		# Visual apron mesh (Grass or Sand)
		var m_inst := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = Vector3(14.0, 0.1, 24.0)
		m_inst.mesh = bmesh
		var amat := StandardMaterial3D.new()
		amat.albedo_color = Color("27ae60") if cup_track != 2 else Color("e67e22") # Green grass or desert sand
		m_inst.material_override = amat
		apron.add_child(m_inst)
		
		add_child(apron)
		apron.global_position = apron_center
		offroad_areas.append(apron)

## 3. Checkpoints & Start/Finish Gantry Archway
func _generate_checkpoints() -> void:
	var curve := track_path.curve
	var fractions := [0.0, 0.25, 0.50, 0.75]
	
	for idx in range(fractions.size()):
		var frac: float = fractions[idx]
		var offset_m: float = frac * baked_length
		var pos := curve.sample_baked(offset_m)
		var next_pos := curve.sample_baked(fposmod(offset_m + 2.0, baked_length))
		var fwd := (next_pos - pos).normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		
		var gate := Area3D.new()
		gate.name = "Checkpoint_%d" % idx
		gate.set_meta("checkpoint_index", idx)
		gate.collision_layer = 0
		gate.collision_mask = 2 | 4
		gate.add_to_group("kart_checkpoint")
		
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(26.0, 9.0, 4.0)
		col.shape = box
		gate.add_child(col)
		
		add_child(gate)
		gate.global_position = pos + Vector3(0, 4.0, 0)
		if fwd.length_squared() > 0.01:
			gate.look_at(gate.global_position + fwd, Vector3.UP)
		checkpoints.append(gate)
		
		# If Start/Finish line (idx == 0), build Giant Checkered Gantry Archway
		if idx == 0:
			_build_start_finish_gantry(pos, fwd, right)

func _build_start_finish_gantry(pos: Vector3, fwd: Vector3, right: Vector3) -> void:
	var gantry := Node3D.new()
	gantry.name = "StartFinishGantry"
	add_child(gantry)
	gantry.global_position = pos
	if fwd.length_squared() > 0.01:
		gantry.look_at(pos + fwd, Vector3.UP)
	
	var truss_h: float = 7.5
	var truss_w: float = 23.0
	
	# Metal Pillars
	for px in [-truss_w * 0.5, truss_w * 0.5]:
		var pillar := MeshInstance3D.new()
		var pmesh := BoxMesh.new()
		pmesh.size = Vector3(1.2, truss_h, 1.2)
		pillar.mesh = pmesh
		pillar.position = Vector3(px, truss_h * 0.5, 0)
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.2, 0.22, 0.25)
		pmat.metallic = 0.8
		pillar.material_override = pmat
		gantry.add_child(pillar)
	
	# Top Crossbar Banner
	var crossbar := MeshInstance3D.new()
	var cmesh := BoxMesh.new()
	cmesh.size = Vector3(truss_w + 1.0, 2.2, 0.6)
	crossbar.mesh = cmesh
	crossbar.position = Vector3(0, truss_h, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.1, 0.12, 0.15)
	crossbar.material_override = bmat
	gantry.add_child(crossbar)
	
	# Checkered Banner Label
	var banner_lbl := Label3D.new()
	banner_lbl.text = "🏁 START / FINISH 🏁"
	banner_lbl.font_size = 72
	banner_lbl.outline_size = 20
	banner_lbl.modulate = Color("f1c40f")
	banner_lbl.outline_modulate = Color.BLACK
	banner_lbl.position = Vector3(0, truss_h, 0.35)
	gantry.add_child(banner_lbl)
	
	# Starting Grid Traffic Lights (3 Red, 1 Green)
	var light_colors := [Color("e74c3c"), Color("e74c3c"), Color("e74c3c"), Color("2ecc71")]
	for li in range(4):
		var lamp := MeshInstance3D.new()
		var lmesh := SphereMesh.new()
		lmesh.radius = 0.4
		lmesh.height = 0.8
		lamp.mesh = lmesh
		lamp.position = Vector3(-4.5 + float(li) * 3.0, truss_h - 1.6, 0.2)
		var lmat := StandardMaterial3D.new()
		lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lmat.albedo_color = light_colors[li]
		lamp.material_override = lmat
		gantry.add_child(lamp)

## 4. Rainbow Chevron Boost Pads (6 floor pads, Area3D)
func _generate_boost_pads() -> void:
	var curve := track_path.curve
	var pad_fractions := [0.08, 0.22, 0.38, 0.52, 0.68, 0.88]
	
	for i in range(pad_fractions.size()):
		var frac: float = pad_fractions[i]
		var offset_m: float = frac * baked_length
		var pos := curve.sample_baked(offset_m)
		var next_pos := curve.sample_baked(fposmod(offset_m + 2.0, baked_length))
		var fwd := (next_pos - pos).normalized()
		
		var pad := Area3D.new()
		pad.name = "BoostPad_%d" % i
		pad.collision_layer = 0
		pad.collision_mask = 2 | 4
		pad.add_to_group("kart_boost_pads")
		
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(7.5, 0.8, 5.5)
		col.shape = box
		pad.add_child(col)
		
		# Glowing Chevron Floor Mesh
		var pmesh := BoxMesh.new()
		pmesh.size = Vector3(7.5, 0.08, 5.5)
		var mi := MeshInstance3D.new()
		mi.mesh = pmesh
		
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("f39c12")
		mat.emission_enabled = true
		mat.emission = Color("ff9f43")
		mat.emission_energy_multiplier = 2.5
		mi.material_override = mat
		pad.add_child(mi)
		
		# Chevron Label
		var clbl := Label3D.new()
		clbl.text = "▲ ▲ ▲"
		clbl.font_size = 90
		clbl.modulate = Color("f1c40f")
		clbl.rotation_degrees.x = -90
		clbl.position = Vector3(0, 0.06, 0)
		pad.add_child(clbl)
		
		add_child(pad)
		pad.global_position = pos + Vector3(0, 0.05, 0)
		if fwd.length_squared() > 0.01:
			pad.look_at(pad.global_position + fwd, Vector3.UP)
		
		pad.body_entered.connect(func(body):
			_on_boost_pad_entered(body)
		)
		boost_pads.append(pad)

func _on_boost_pad_entered(body: Node) -> void:
	var car: ArcadeCar = null
	if body is ArcadeCar:
		car = body as ArcadeCar
	elif body.get_parent() is ArcadeCar:
		car = body.get_parent() as ArcadeCar
	elif body.owner is ArcadeCar:
		car = body.owner as ArcadeCar
	
	if car and car.has_method("apply_kart_boost"):
		car.apply_kart_boost(1.45, 1.2)
	elif car and "drift_boost_time" in car:
		car.drift_boost_time = 1.2
		car.drift_boost_multiplier = 1.45
		if has_node("/root/SoundFX"):
			get_node("/root/SoundFX").play_nitro_boost()

## 5. 4 Item Box Lines (5 boxes each across road width)
func _generate_item_boxes() -> void:
	var curve := track_path.curve
	var box_line_fractions := [0.15, 0.40, 0.65, 0.85]
	var x_offsets := [-7.0, -3.5, 0.0, 3.5, 7.0]
	
	for line_idx in range(box_line_fractions.size()):
		var frac: float = box_line_fractions[line_idx]
		var offset_m: float = frac * baked_length
		var pos := curve.sample_baked(offset_m)
		var next_pos := curve.sample_baked(fposmod(offset_m + 2.0, baked_length))
		var fwd := (next_pos - pos).normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		
		for bx in x_offsets:
			var item_box: KartItemBox = KartItemBoxScene.instantiate() as KartItemBox
			item_box.name = "ItemBox_L%d_X%d" % [line_idx, int(bx * 10)]
			var b_pos: Vector3 = pos + right * bx + Vector3(0, 0.1, 0)
			item_box.position = b_pos
			add_child(item_box)
			item_boxes.append(item_box)

## 6. Comprehensive Roadside Details: Grandstands, Street Lamps, Tire Walls & Neon Signs
func _generate_roadside_props(cup_track: int) -> void:
	var curve := track_path.curve
	
	# A. Dual Grandstands with Spectator Crowds at Start/Finish Straight
	_build_grandstands()
	
	# B. Curved Steel Street Lamps every 28m along track
	_build_trackside_street_lamps(cup_track)
	
	# C. Corner Apex Stacked Tire Walls & Directional Hazard Chevrons
	_build_corner_apex_tire_walls()
	
	# D. Animated Neon Drift Turn Billboards
	_build_neon_drift_signs()

func _build_grandstands() -> void:
	var curve := track_path.curve
	# Position at track distance 12m (just past start/finish line)
	var g_pos := curve.sample_baked(12.0)
	var next_p := curve.sample_baked(14.0)
	var fwd := (next_p - g_pos).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	
	# Left & Right Grandstands
	var sides := [-18.5, 18.5]
	for side_x in sides:
		var grandstand := Node3D.new()
		grandstand.name = "Grandstand_%s" % ("Left" if side_x < 0 else "Right")
		add_child(grandstand)
		roadside_props.append(grandstand)
		
		var root_pos: Vector3 = g_pos + right * side_x
		grandstand.global_position = root_pos
		var look_dir: Vector3 = -right if side_x < 0 else right
		grandstand.look_at(root_pos + fwd, Vector3.UP)
		
		# 4 Bleacher Tiers
		var tiers := 4
		for t in range(tiers):
			var tier_h: float = 0.75 + float(t) * 0.8
			var tier_depth: float = 1.4
			var tier_offset_z: float = float(t) * tier_depth * (1.0 if side_x < 0 else -1.0)
			
			var bench := MeshInstance3D.new()
			var bmesh := BoxMesh.new()
			bmesh.size = Vector3(28.0, 0.45, tier_depth)
			bench.mesh = bmesh
			bench.position = Vector3(0, tier_h, tier_offset_z)
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color("2c3e50") if (t % 2 == 0) else Color("34495e")
			bench.material_override = bmat
			grandstand.add_child(bench)
			
			# Cheering Spectators along the bench (6 spectators per tier)
			for s in range(6):
				var spec := Node3D.new()
				spec.position = Vector3(-11.5 + float(s) * 4.6, tier_h + 0.35, tier_offset_z)
				
				# Voxel Body
				var spec_body := MeshInstance3D.new()
				var smesh := BoxMesh.new()
				smesh.size = Vector3(0.55, 0.75, 0.4)
				spec_body.mesh = smesh
				var smat := StandardMaterial3D.new()
				var shirt_colors := [Color("e74c3c"), Color("f1c40f"), Color("2ecc71"), Color("3498db"), Color("e67e22"), Color("9b59b6")]
				smat.albedo_color = shirt_colors[(t + s) % shirt_colors.size()]
				spec_body.material_override = smat
				spec.add_child(spec_body)
				
				# Head
				var spec_head := MeshInstance3D.new()
				var hmesh := SphereMesh.new()
				hmesh.radius = 0.22
				hmesh.height = 0.44
				spec_head.mesh = hmesh
				spec_head.position = Vector3(0, 0.58, 0)
				var hmat := StandardMaterial3D.new()
				hmat.albedo_color = Color("ffeaa7")
				spec_head.material_override = hmat
				spec.add_child(spec_head)
				
				# Animated Cheering Flag / Emoji
				var flag := Label3D.new()
				flag.text = ["🏁", "🔥", "🏎️", "⭐", "🏆", "💥"][(s + t) % 6]
				flag.font_size = 46
				flag.position = Vector3(0.25, 0.85, 0)
				spec.add_child(flag)
				
				grandstand.add_child(spec)
		
		# Overhead Canopy Roof
		var roof := MeshInstance3D.new()
		var rmesh := BoxMesh.new()
		rmesh.size = Vector3(30.0, 0.4, 7.5)
		roof.mesh = rmesh
		roof.position = Vector3(0, 6.2, 2.0 if side_x < 0 else -2.0)
		roof.rotation_degrees.x = -8.0 if side_x < 0 else 8.0
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color("c0392b") if side_x < 0 else Color("2980b9")
		roof.material_override = rmat
		grandstand.add_child(roof)
		
		# Steel Canopy Support Pillars
		for px in [-13.5, 13.5]:
			var pillar := MeshInstance3D.new()
			var pmesh := CylinderMesh.new()
			pmesh.top_radius = 0.25
			pmesh.bottom_radius = 0.25
			pmesh.height = 6.2
			pillar.mesh = pmesh
			pillar.position = Vector3(px, 3.1, 4.5 if side_x < 0 else -4.5)
			var pmat := StandardMaterial3D.new()
			pmat.albedo_color = Color(0.25, 0.28, 0.32)
			pmat.metallic = 0.85
			pillar.material_override = pmat
			grandstand.add_child(pillar)
		
		# Grandstand Banner
		var banner := Label3D.new()
		banner.text = "🏆 SMASHY KART GRAND PRIX 🏆"
		banner.font_size = 58
		banner.modulate = Color("f1c40f")
		banner.outline_size = 14
		banner.outline_modulate = Color.BLACK
		banner.position = Vector3(0, 4.2, -0.6 if side_x < 0 else 0.6)
		grandstand.add_child(banner)

func _build_trackside_street_lamps(cup_track: int) -> void:
	var curve := track_path.curve
	var lamp_spacing: float = 28.0
	var lamp_count: int = int(floor(baked_length / lamp_spacing))
	
	var glow_colors := [
		Color("00d2d3"), # Downtown Neon Cyan
		Color("ff9ff3"), # Downtown Neon Pink
		Color("f1c40f"), # Chinatown Warm Lantern Gold
		Color("f39c12")  # Canyon Amber Halogen
	]
	
	for li in range(lamp_count):
		var d: float = float(li) * lamp_spacing
		var pos := curve.sample_baked(d)
		var next_p := curve.sample_baked(fposmod(d + 2.0, baked_length))
		var fwd := (next_p - pos).normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		
		# Alternate left and right placement just behind the barrier (13.2m offset)
		var is_left: bool = (li % 2 == 0)
		var side_mult: float = -1.0 if is_left else 1.0
		var lamp_root := pos + right * (13.2 * side_mult)
		
		var lamp := Node3D.new()
		lamp.name = "StreetLamp_%d" % li
		add_child(lamp)
		roadside_props.append(lamp)
		lamp.global_position = lamp_root
		lamp.look_at(lamp_root + fwd, Vector3.UP)
		
		# Vertical Steel Pole (6.6m tall)
		var pole := MeshInstance3D.new()
		var pmesh := CylinderMesh.new()
		pmesh.top_radius = 0.12
		pmesh.bottom_radius = 0.18
		pmesh.height = 6.6
		pole.mesh = pmesh
		pole.position = Vector3(0, 3.3, 0)
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.25, 0.28, 0.32)
		pmat.metallic = 0.85
		pmat.roughness = 0.3
		pole.material_override = pmat
		lamp.add_child(pole)
		
		# Arched Arm extending 3.2m inward over track barrier
		var arm := MeshInstance3D.new()
		var amesh := BoxMesh.new()
		amesh.size = Vector3(0.16, 0.16, 3.2)
		arm.mesh = amesh
		# Inward towards track
		arm.position = Vector3(1.5 * (-side_mult), 6.4, 0)
		arm.rotation_degrees.z = 18.0 * side_mult
		arm.material_override = pmat
		lamp.add_child(arm)
		
		# Glowing Luminaire Light Head
		var head := MeshInstance3D.new()
		var hmesh := BoxMesh.new()
		hmesh.size = Vector3(0.5, 0.22, 1.2)
		head.mesh = hmesh
		head.position = Vector3(2.8 * (-side_mult), 6.1, 0)
		
		var lmat := StandardMaterial3D.new()
		var chosen_glow: Color = glow_colors[li % 2] if cup_track == 0 else (glow_colors[2] if cup_track == 1 else glow_colors[3])
		lmat.albedo_color = chosen_glow
		lmat.emission_enabled = true
		lmat.emission = chosen_glow
		lmat.emission_energy_multiplier = 3.2
		head.material_override = lmat
		lamp.add_child(head)
		
		# Downward Omnidirectional Light
		var omni := OmniLight3D.new()
		omni.light_color = chosen_glow
		omni.light_energy = 2.4
		omni.omni_range = 16.0
		omni.position = Vector3(2.8 * (-side_mult), 5.7, 0)
		lamp.add_child(omni)

func _build_corner_apex_tire_walls() -> void:
	var curve := track_path.curve
	# Apex locations along the 780m circuit (sharp drift corners)
	var apex_offsets: Array[float] = [
		baked_length * 0.18,
		baked_length * 0.34,
		baked_length * 0.58,
		baked_length * 0.82
	]
	
	for ai in range(apex_offsets.size()):
		var off: float = apex_offsets[ai]
		var pos := curve.sample_baked(off)
		var next_p := curve.sample_baked(fposmod(off + 2.0, baked_length))
		var fwd := (next_p - pos).normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		
		# Place along outer barrier (11.8m offset)
		var wall_root := pos + right * 11.8
		var tire_wall := Node3D.new()
		tire_wall.name = "ApexTireWall_%d" % ai
		add_child(tire_wall)
		roadside_props.append(tire_wall)
		tire_wall.global_position = wall_root
		tire_wall.look_at(wall_root + fwd, Vector3.UP)
		
		# 3-Tiers of 8 Stacked Crash Tires
		var tire_colors := [Color("e74c3c"), Color("f5f6fa"), Color("1e272e")]
		for ti in range(8):
			var z_off: float = -5.0 + float(ti) * 1.45
			for tier in range(3):
				var tire := MeshInstance3D.new()
				var tmesh := CylinderMesh.new()
				tmesh.top_radius = 0.55
				tmesh.bottom_radius = 0.55
				tmesh.height = 0.45
				tire.mesh = tmesh
				tire.position = Vector3(0, 0.28 + float(tier) * 0.48, z_off)
				tire.rotation_degrees.z = 90
				
				var tmat := StandardMaterial3D.new()
				tmat.albedo_color = tire_colors[(ti + tier) % 3]
				tmat.roughness = 0.85
				tire.material_override = tmat
				tire_wall.add_child(tire)
		
		# High-Visibility Diagonal Hazard Chevron Billboard (<<< / >>>)
		var chevron_sign := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = Vector3(0.3, 1.8, 8.0)
		chevron_sign.mesh = bmesh
		chevron_sign.position = Vector3(0.6, 2.2, 0)
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color("f1c40f") # Vivid hazard yellow
		cmat.emission_enabled = true
		cmat.emission = Color("f39c12")
		cmat.emission_energy_multiplier = 1.2
		chevron_sign.material_override = cmat
		tire_wall.add_child(chevron_sign)
		
		var chevron_lbl := Label3D.new()
		chevron_lbl.text = ">>> HAZARD >>>" if (ai % 2 == 0) else "<<< HAZARD <<<"
		chevron_lbl.font_size = 64
		chevron_lbl.outline_size = 18
		chevron_lbl.modulate = Color("1e272e")
		chevron_lbl.outline_modulate = Color("f1c40f")
		chevron_lbl.position = Vector3(0.8, 2.2, 0)
		chevron_lbl.rotation_degrees.y = -90
		tire_wall.add_child(chevron_lbl)

func _build_neon_drift_signs() -> void:
	var curve := track_path.curve
	var drift_offsets: Array[float] = [
		baked_length * 0.16,
		baked_length * 0.32,
		baked_length * 0.70
	]
	
	for di in range(drift_offsets.size()):
		var off: float = drift_offsets[di]
		var pos := curve.sample_baked(off)
		var next_p := curve.sample_baked(fposmod(off + 2.0, baked_length))
		var fwd := (next_p - pos).normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		
		var arch := Node3D.new()
		arch.name = "NeonDriftArch_%d" % di
		add_child(arch)
		roadside_props.append(arch)
		arch.global_position = pos + Vector3(0, 6.5, 0)
		arch.look_at(arch.global_position + fwd, Vector3.UP)
		
		# Glowing Neon Banner
		var neon_lbl := Label3D.new()
		neon_lbl.text = "⚡ DRIFT >>>" if (di % 2 == 0) else "<<< DRIFT ⚡"
		neon_lbl.font_size = 80
		neon_lbl.outline_size = 22
		neon_lbl.modulate = Color("00d2d3") if (di % 2 == 0) else Color("ff9ff3")
		neon_lbl.outline_modulate = Color.BLACK
		arch.add_child(neon_lbl)

## 7. Themed Scenery Props
func _generate_scenery(cup_track: int) -> void:
	match cup_track:
		1: # CHINATOWN: Pagoda arches, red lantern posts
			_build_chinatown_props()
		2: # CANYON: Desert cliffs, canyon jump chasm
			_build_canyon_props()
		_: # DOWNTOWN: Grandstands, skyscrapers, central park fountain
			_build_downtown_props()

func _build_downtown_props() -> void:
	# Central Park Fountain Shortcut at center of hairpin (~ (35, 0, -200))
	var fountain := Node3D.new()
	fountain.name = "ParkFountain"
	fountain.position = Vector3(35, 0, -200)
	
	var fmesh := CylinderMesh.new()
	fmesh.top_radius = 5.0
	fmesh.bottom_radius = 5.5
	fmesh.height = 1.4
	var f_inst := MeshInstance3D.new()
	f_inst.mesh = fmesh
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color("74b9ff")
	fmat.metallic = 0.3
	f_inst.material_override = fmat
	fountain.add_child(f_inst)
	add_child(fountain)
	roadside_props.append(fountain)
	
	# Background Neon Skyscraper Towers in the outer skyline
	var tower_positions := [
		Vector3(-140, 0, -180),
		Vector3(-160, 0, 50),
		Vector3(-110, 0, 220),
		Vector3(120, 0, 260),
		Vector3(240, 0, 160),
		Vector3(260, 0, -80),
		Vector3(190, 0, -240),
		Vector3(0, 0, -280)
	]
	
	for ti in range(tower_positions.size()):
		var t_pos: Vector3 = tower_positions[ti]
		var tower := Node3D.new()
		tower.name = "NeonTower_%d" % ti
		tower.position = t_pos
		
		var t_height: float = 45.0 + float(ti % 3) * 15.0
		var t_width: float = 16.0 + float(ti % 2) * 6.0
		
		var bmesh := BoxMesh.new()
		bmesh.size = Vector3(t_width, t_height, t_width)
		var t_inst := MeshInstance3D.new()
		t_inst.mesh = bmesh
		t_inst.position = Vector3(0, t_height * 0.5, 0)
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color("0a101d")
		tmat.roughness = 0.4
		t_inst.material_override = tmat
		tower.add_child(t_inst)
		
		# Glowing Rooftop Spire & Edge Trim
		var spire := MeshInstance3D.new()
		var smesh := CylinderMesh.new()
		smesh.top_radius = 0.2
		smesh.bottom_radius = 1.2
		smesh.height = 12.0
		spire.mesh = smesh
		spire.position = Vector3(0, t_height + 6.0, 0)
		var smat := StandardMaterial3D.new()
		var spire_col: Color = Color("00d2d3") if (ti % 2 == 0) else Color("ff9ff3")
		smat.albedo_color = spire_col
		smat.emission_enabled = true
		smat.emission = spire_col
		smat.emission_energy_multiplier = 3.0
		spire.material_override = smat
		tower.add_child(spire)
		
		add_child(tower)
		roadside_props.append(tower)

func _build_chinatown_props() -> void:
	# Crimson Pagoda Arches at track offset 30% and 70%
	var curve := track_path.curve
	for frac in [0.30, 0.70]:
		var pos := curve.sample_baked(frac * baked_length)
		var next_pos := curve.sample_baked(fposmod(frac * baked_length + 2.0, baked_length))
		var fwd := (next_pos - pos).normalized()
		
		var pagoda := Node3D.new()
		pagoda.name = "PagodaArch"
		add_child(pagoda)
		roadside_props.append(pagoda)
		pagoda.global_position = pos
		if fwd.length_squared() > 0.01:
			pagoda.look_at(pos + fwd, Vector3.UP)
		
		# Crimson Arch Roof
		var rmesh := BoxMesh.new()
		rmesh.size = Vector3(24.0, 1.8, 4.0)
		var r_inst := MeshInstance3D.new()
		r_inst.mesh = rmesh
		r_inst.position = Vector3(0, 7.0, 0)
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color("c0392b") # Crimson red
		r_inst.material_override = rmat
		pagoda.add_child(r_inst)

func _build_canyon_props() -> void:
	# Giant Terracotta Canyon Walls flanking the track
	for ci in range(6):
		var ang := float(ci) * (TAU / 6.0)
		var wall := MeshInstance3D.new()
		var wmesh := BoxMesh.new()
		wmesh.size = Vector3(60.0, 25.0, 30.0)
		wall.mesh = wmesh
		wall.position = Vector3(cos(ang) * 160.0, 12.0, sin(ang) * 160.0)
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color("d35400") # Terracotta Orange
		cmat.roughness = 0.95
		wall.material_override = cmat
		add_child(wall)
		roadside_props.append(wall)
