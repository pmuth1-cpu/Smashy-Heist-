class_name CityGenerator
extends Node3D

const SmashPropScene = preload("res://scenes/props/smash_prop.tscn")
const PowerupCrateScene = preload("res://scenes/props/powerup_crate.tscn")

signal player_busted_in_water(chunk_coord: Vector2i)
signal player_submerged_in_water(chunk_coord: Vector2i)
signal player_hit_boost_pad(boost_position: Vector3)
signal biome_entered(biome: BiomeType, biome_name: String)

enum BiomeType {
	DOWNTOWN_METRO = 0,
	NEON_CHINATOWN = 1,
	DESERT_CANYON_ROUTE66 = 2,
	CARGO_HARBOR_DOCKS = 3,
	FARMLAND_COUNTRYSIDE = 4
}

enum ChunkArchetype {
	SAFE_STARTING_PLAZA,
	INTERSECTION_BLOCK,
	PARK_SHORTCUT,
	RIVER_JUMP_BRIDGE,
	HIGHWAY_OVERPASS,
	FARMLAND_FIELDS,
	RAILWAY_CORRIDOR,
	RAILWAY_RIVER_BRIDGE,
	SKYSCRAPER_PLAZA
}

const CHUNK_SIZE: int = 48
const ACTIVE_RADIUS: int = 1
const DESPAWN_RADIUS: int = 2

@export var target_player: Node3D:
	set(value):
		target_player = value
		if is_inside_tree() and target_player:
			_check_and_update_chunks()

var chunks_container: Node3D

func _ensure_chunks_container() -> void:
	if not chunks_container:
		chunks_container = get_node_or_null("Chunks")
		if not chunks_container:
			chunks_container = Node3D.new()
			chunks_container.name = "Chunks"
			add_child(chunks_container)

var _active_chunks: Dictionary = {} # Vector2i -> Node3D
var _current_chunk_coord: Vector2i = Vector2i(999999, 999999)
var current_biome: BiomeType = BiomeType.DOWNTOWN_METRO

# Active Moving Freight Train & Level Crossing Systems
var _active_train: Node3D = null
var _active_train_rail_x: int = -9999
var _train_speed: float = 24.0
var _train_z: float = 0.0
var _train_dir: float = 1.0
var _level_crossings: Array[Dictionary] = []

# Shared Materials for draw-call batching
var _mat_asphalt: StandardMaterial3D
var _mat_curb: StandardMaterial3D
var _mat_marking_white: StandardMaterial3D
var _mat_marking_yellow: StandardMaterial3D
var _mat_grass: StandardMaterial3D
var _mat_sand: StandardMaterial3D
var _mat_dirt: StandardMaterial3D
var _mat_water: StandardMaterial3D
var _mat_bridge: StandardMaterial3D
var _mat_ramp: StandardMaterial3D
var _mat_boost: StandardMaterial3D
var _mat_tree_trunk: StandardMaterial3D
var _mat_tree_foliage: StandardMaterial3D
var _building_mats: Array[StandardMaterial3D] = []
var _roof_mats: Array[StandardMaterial3D] = []

func _ready() -> void:
	_ensure_chunks_container()
	_init_shared_materials()
	if target_player:
		_check_and_update_chunks()

func _process(delta: float) -> void:
	_check_and_update_chunks()
	_update_active_train(delta)

func is_river_chunk(coord: Vector2i) -> bool:
	if coord == Vector2i(0, 0):
		return false
	return posmod(coord.y, 8) == 3

func is_rail_corridor(coord: Vector2i) -> bool:
	if coord == Vector2i(0, 0):
		return false
	return posmod(coord.x, 8) == 5

func get_biome_for_chunk(coord: Vector2i) -> BiomeType:
	var district_x: int = int(floor(float(coord.x) / 3.0))
	var district_z: int = int(floor(float(coord.y) / 3.0))
	var idx: int = posmod(district_x + district_z, 5)
	return idx as BiomeType

func get_biome_name(biome: BiomeType) -> String:
	match biome:
		BiomeType.NEON_CHINATOWN:
			return "NEON NIGHT MARKET"
		BiomeType.DESERT_CANYON_ROUTE66:
			return "ROUTE 66 DESERT CANYON"
		BiomeType.CARGO_HARBOR_DOCKS:
			return "CARGO HARBOR DOCKS"
		BiomeType.FARMLAND_COUNTRYSIDE:
			return "SUNSHINE FARMLAND & COUNTRYSIDE"
		_:
			return "DOWNTOWN METRO"

func get_biome_ground_material(coord: Vector2i) -> StandardMaterial3D:
	var biome := get_biome_for_chunk(coord)
	if biome == BiomeType.DESERT_CANYON_ROUTE66:
		return _mat_sand if _mat_sand else _mat_grass
	return _mat_grass

func _check_and_update_chunks() -> void:
	if not target_player or not is_instance_valid(target_player):
		return
	
	var pos = target_player.global_position
	var new_chunk_coord := Vector2i(
		int(floor(pos.x / float(CHUNK_SIZE))),
		int(floor(pos.z / float(CHUNK_SIZE)))
	)
	
	if new_chunk_coord != _current_chunk_coord:
		_current_chunk_coord = new_chunk_coord
		var new_b: BiomeType = get_biome_for_chunk(_current_chunk_coord)
		if new_b != current_biome:
			current_biome = new_b
			biome_entered.emit(current_biome, get_biome_name(current_biome))
		_update_chunks()

func _update_chunks() -> void:
	# 1. Spawn chunks within ACTIVE_RADIUS
	for dx in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
		for dz in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
			var coord = _current_chunk_coord + Vector2i(dx, dz)
			if not _active_chunks.has(coord):
				_spawn_chunk(coord)
	
	# 2. Despawn chunks beyond DESPAWN_RADIUS (preserving any chunk with a player vehicle!)
	var protected_chunks: Array[Vector2i] = []
	var p_cars := get_tree().get_nodes_in_group("player_vehicles")
	for p_car in p_cars:
		if is_instance_valid(p_car) and p_car is Node3D:
			var p3d := p_car as Node3D
			var c_pos: Vector3 = p3d.global_position
			if "car_pivot" in p3d and p3d.car_pivot:
				c_pos = p3d.car_pivot.global_position
			protected_chunks.append(Vector2i(int(floor(c_pos.x / CHUNK_SIZE)), int(floor(c_pos.z / CHUNK_SIZE))))
	
	var to_remove: Array[Vector2i] = []
	for coord in _active_chunks.keys():
		if protected_chunks.has(coord):
			continue
		var dist_x = absi(coord.x - _current_chunk_coord.x)
		var dist_z = absi(coord.y - _current_chunk_coord.y)
		if dist_x > DESPAWN_RADIUS or dist_z > DESPAWN_RADIUS:
			to_remove.append(coord)
	
	for coord in to_remove:
		var chunk_node: Node3D = _active_chunks[coord]
		_active_chunks.erase(coord)
		chunk_node.queue_free()
	
	if not to_remove.is_empty():
		_level_crossings = _level_crossings.filter(func(c): return not to_remove.has(c.get("chunk_coord", Vector2i(-999, -999))))

func _spawn_chunk(coord: Vector2i) -> void:
	var rng: RandomNumberGenerator
	if has_node("/root/DailySeedManager"):
		var mgr = get_node("/root/DailySeedManager")
		rng = mgr.get_chunk_rng(coord)
	else:
		rng = RandomNumberGenerator.new()
		rng.seed = hash(Vector3i(coord.x, coord.y, 12345))
	
	var chunk_root = Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk_root.position = Vector3(coord.x * CHUNK_SIZE, 0.0, coord.y * CHUNK_SIZE)
	
	# Archetype Selection
	if coord == Vector2i(0, 0):
		_build_safe_plaza(chunk_root, rng)
	elif is_rail_corridor(coord) and is_river_chunk(coord):
		_build_railway_river_bridge(chunk_root, rng, coord)
	elif is_river_chunk(coord):
		var r_var := posmod(coord.x, 3)
		if r_var == 0:
			_build_river_arched_bridge(chunk_root, rng, coord)
		elif r_var == 1:
			_build_river_jump_bridge(chunk_root, rng, coord)
		else:
			_build_river_quay_canal(chunk_root, rng, coord)
	elif is_rail_corridor(coord):
		_build_railway_corridor(chunk_root, rng, coord)
	else:
		var b_type := get_biome_for_chunk(coord)
		if b_type == BiomeType.FARMLAND_COUNTRYSIDE:
			_build_farmland_chunk(chunk_root, rng, coord)
		else:
			var roll = rng.randf()
			if roll < 0.40:
				_build_intersection_block(chunk_root, rng, coord)
			elif roll < 0.60:
				_build_park_shortcut(chunk_root, rng, coord)
			elif roll < 0.80:
				_build_skyscraper_plaza(chunk_root, rng, coord)
			else:
				_build_highway_overpass(chunk_root, rng)
	
	# Spawn 1-2 Power-Up Crates along open road coordinates (except chunk 0,0)
	if coord != Vector2i(0, 0):
		var num_crates: int = rng.randi_range(1, 2)
		for c_idx in range(num_crates):
			var on_ns_road: bool = rng.randf() < 0.5
			var crate_pos: Vector3
			if on_ns_road:
				crate_pos = Vector3(rng.randf_range(21.0, 27.0), 0.8, rng.randf_range(6.0, 42.0))
			else:
				crate_pos = Vector3(rng.randf_range(6.0, 42.0), 0.8, rng.randf_range(21.0, 27.0))
			_spawn_powerup_crate(chunk_root, crate_pos)
		
		# Spawn 1 Biome Landmark per chunk (only if not on river or rail)
		if not is_river_chunk(coord) and not is_rail_corridor(coord):
			var b_type := get_biome_for_chunk(coord)
			_spawn_chunk_landmark(chunk_root, b_type, coord, rng)
	
	_ensure_chunks_container()
	chunks_container.add_child(chunk_root)
	_active_chunks[coord] = chunk_root

func _spawn_chunk_landmark(root: Node3D, biome: BiomeType, _coord: Vector2i, rng: RandomNumberGenerator) -> void:
	var vab = null
	if is_inside_tree():
		vab = get_node_or_null("/root/VoxelAssetBuilder")
	elif Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st and st.root:
			vab = st.root.get_node_or_null("VoxelAssetBuilder")
	
	if not vab or not vab.has_method("build_biome_landmark"):
		return
	
	var landmark_type: int = rng.randi() % 2
	var landmark: Node3D = vab.build_biome_landmark(int(biome), landmark_type, rng)
	if not landmark:
		return
	
	# Place at a landmark corner
	var corner_pos := Vector3(9.0, 0.2, 9.0) if rng.randf() > 0.5 else Vector3(39.0, 0.2, 39.0)
	landmark.position = corner_pos
	
	# If Donut Shop: continuous rotation
	var donut_pivot = landmark.find_child("DonutPivot", true, false)
	if donut_pivot:
		var tw := create_tween().set_loops()
		tw.tween_property(donut_pivot, "rotation:y", TAU, 4.0).as_relative()
	
	# If Gas Station: explosive pumps
	var pumps: Array[Node] = landmark.find_children("FuelPump*", "Node3D", true, false)
	for p in pumps:
		var p_node := p as Node3D
		var area := Area3D.new()
		area.collision_layer = 0
		area.collision_mask = 2 | 4 # PlayerCar, PoliceCar
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.2, 2.0, 1.2)
		cs.shape = box
		area.add_child(cs)
		area.body_entered.connect(func(_body: Node3D):
			_trigger_gas_pump_explosion(p_node.global_position)
			p_node.queue_free()
		)
		p_node.add_child(area)
	
	# If Freight Train: active train mover
	var train = landmark.find_child("FreightTrain", true, false)
	if train:
		var tw := create_tween().set_loops()
		tw.tween_interval(14.0)
		tw.tween_callback(func():
			if is_instance_valid(train):
				train.position.z = -24.0
		)
		tw.tween_property(train, "position:z", 24.0, 48.0 / 38.0)
	
	root.add_child(landmark)

func _trigger_gas_pump_explosion(pos: Vector3) -> void:
	var blast_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	blast_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("e74c3c")
	mat.emission_enabled = true
	mat.emission = Color("f39c12")
	mat.emission_energy_multiplier = 4.5
	blast_mesh.material_override = mat
	blast_mesh.position = pos + Vector3.UP * 0.8
	add_child(blast_mesh)
	
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(blast_mesh, "scale", Vector3(10.0, 10.0, 10.0), 0.4)
	tw.tween_property(blast_mesh, "transparency", 1.0, 0.4)
	tw.chain().tween_callback(blast_mesh.queue_free)
	
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var blast_sphere := SphereShape3D.new()
	blast_sphere.radius = 10.0
	query.shape = blast_sphere
	query.transform = Transform3D(Basis(), pos)
	query.collision_mask = 4 # PoliceCar
	var hits := space.intersect_shape(query, 16)
	for hit in hits:
		var collider: Object = hit.get("collider")
		if collider is RigidBody3D:
			(collider as RigidBody3D).apply_central_impulse(Vector3.UP * 25.0 + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10)))
			if collider.has_method("wreck_car"):
				collider.wreck_car()

func _spawn_powerup_crate(root: Node3D, pos: Vector3) -> void:
	if not PowerupCrateScene:
		return
	var crate = PowerupCrateScene.instantiate()
	crate.position = pos
	root.add_child(crate)

# ==============================================================================
# CHUNK ARCHETYPE BUILDERS
# ==============================================================================

## Safe Starting Plaza at Chunk (0, 0)
func _build_safe_plaza(root: Node3D, rng: RandomNumberGenerator) -> void:
	# 1. Full asphalt ground base (48x48)
	_create_ground_box(root, Vector3(24, -0.5, 24), Vector3(48, 1, 48), _mat_asphalt)
	
	# 2. Road markings
	_add_road_markings(root)
	
	# 3. Starting grid decals & check plaza
	var start_line = _create_mesh_box(Vector3(12, 0.05, 1.2), _mat_marking_white)
	start_line.position = Vector3(24, 0.02, 24)
	root.add_child(start_line)
	
	# 4. Corner sidewalks (open, no blocking buildings)
	var corners = [
		Vector3(9, 0.1, 9),
		Vector3(39, 0.1, 9),
		Vector3(9, 0.1, 39),
		Vector3(39, 0.1, 39)
	]
	for pos in corners:
		_create_ground_box(root, pos, Vector3(18, 0.2, 18), _mat_curb)
		# Add decorative corner trees away from road
		var tree_offset = Vector3(
			-4.0 if pos.x < 24 else 4.0,
			0.2,
			-4.0 if pos.z < 24 else 4.0
		)
		_create_tree(root, pos + tree_offset, rng)

	# 5. Street props for safe plaza
	# Streetlamps at the 4 inner curb corners facing inward
	_spawn_smash_prop(root, Vector3(17.2, 0.2, 17.2), SmashProp.PropType.STREETLAMP, 45.0)
	_spawn_smash_prop(root, Vector3(30.8, 0.2, 17.2), SmashProp.PropType.STREETLAMP, -45.0)
	_spawn_smash_prop(root, Vector3(17.2, 0.2, 30.8), SmashProp.PropType.STREETLAMP, 135.0)
	_spawn_smash_prop(root, Vector3(30.8, 0.2, 30.8), SmashProp.PropType.STREETLAMP, -135.0)
	
	# Curb fire hydrants
	_spawn_smash_prop(root, Vector3(17.2, 0.2, 12.0), SmashProp.PropType.HYDRANT)
	_spawn_smash_prop(root, Vector3(30.8, 0.2, 36.0), SmashProp.PropType.HYDRANT)
	
	# Decorative smashable potted plants around plaza sidewalks
	_spawn_smash_prop(root, Vector3(17.2, 0.2, 20.0), SmashProp.PropType.PLANT)
	_spawn_smash_prop(root, Vector3(30.8, 0.2, 20.0), SmashProp.PropType.PLANT)
	_spawn_smash_prop(root, Vector3(17.2, 0.2, 28.0), SmashProp.PropType.PLANT)
	_spawn_smash_prop(root, Vector3(30.8, 0.2, 28.0), SmashProp.PropType.PLANT)
	
	# Spawn 2 parked fleet cars from the 100-car fleet with varied rarity and unique gadgets
	_spawn_parked_fleet_car(root, Vector3(10.0, 0.2, 10.0), 45.0)
	_spawn_parked_fleet_car(root, Vector3(38.0, 0.2, 38.0), -135.0)

## Archetype 1: INTERSECTION_BLOCK (55% chance)
func _build_intersection_block(root: Node3D, rng: RandomNumberGenerator, coord: Vector2i = Vector2i.ZERO) -> void:
	# Base asphalt crossing
	_create_ground_box(root, Vector3(24, -0.5, 24), Vector3(48, 1, 48), _mat_asphalt)
	_add_road_markings(root)
	
	# 4 Corner Blocks: NW (0-18, 0-18), NE (30-48, 0-18), SW (0-18, 30-48), SE (30-48, 30-48)
	var corner_centers = [
		Vector3(9, 0.1, 9),
		Vector3(39, 0.1, 9),
		Vector3(9, 0.1, 39),
		Vector3(39, 0.1, 39)
	]
	
	var ground_mat := get_biome_ground_material(coord)
	
	for center in corner_centers:
		# Sidewalk base
		_create_ground_box(root, center, Vector3(18, 0.2, 18), _mat_curb)
		
		# Corner landscape verge: vibrant green grass in city or golden sand in desert biome
		var verge_x: float = center.x + (-6.5 if center.x < 24 else 6.5)
		var verge_z: float = center.z + (-6.5 if center.z < 24 else 6.5)
		_create_ground_box(root, Vector3(verge_x, 0.15, verge_z), Vector3(4.5, 0.12, 4.5), ground_mat)
		
		# Camera-Friendly Building Architecture (Escape Road 3)
		# SE Corner (closest to camera) is strictly low-profile (3.2m - 5.0m) to guarantee clear road view.
		var is_se_camera_corner: bool = (center.x > 24 and center.z > 24)
		var style = rng.randi() % 4
		
		if is_se_camera_corner or style == 0:
			# Style 0: Stepped Low-Rise Corner Store with Setback (3.5m front, 6.0m rear)
			var h_main = rng.randf_range(3.5, 5.0) if is_se_camera_corner else rng.randf_range(5.0, 7.5)
			var b_size = Vector3(12.0, h_main, 12.0)
			# Offset away from the road curb towards corner
			var b_offset = Vector3(-1.5 if center.x < 24 else 1.5, 0.0, -1.5 if center.z < 24 else 1.5)
			_create_building(root, Vector3(center.x + b_offset.x, b_size.y * 0.5 + 0.2, center.z + b_offset.z), b_size, rng)
			
			# Low-profile storefront awning on street side
			var crate_pos = Vector3(
				center.x + (6.2 if center.x < 24 else -6.2),
				0.2,
				center.z + (6.2 if center.z < 24 else -6.2)
			)
			_spawn_smash_prop(root, crate_pos, SmashProp.PropType.FRUIT_CRATE)
			if rng.randf() < 0.6:
				_spawn_smash_prop(root, crate_pos + Vector3(0.0, 0.0, 1.2 if center.z < 24 else -1.2), SmashProp.PropType.FRUIT_CRATE)
		
		elif style == 1:
			# Style 1: Getaway Alleyway (Twin boutique shops separated by 4.0m drive-through alley)
			var h1 = rng.randf_range(4.5, 7.0)
			var h2 = rng.randf_range(4.5, 7.0)
			var b_size1 = Vector3(5.8, h1, 12.0)
			var b_size2 = Vector3(5.8, h2, 12.0)
			_create_building(root, Vector3(center.x - 4.2, b_size1.y * 0.5 + 0.2, center.z), b_size1, rng)
			_create_building(root, Vector3(center.x + 4.2, b_size2.y * 0.5 + 0.2, center.z), b_size2, rng)
			# Smashable crates and trash cans inside the alley shortcut
			_spawn_smash_prop(root, Vector3(center.x, 0.2, center.z), SmashProp.PropType.FRUIT_CRATE)
			if rng.randf() < 0.7:
				_spawn_smash_prop(root, Vector3(center.x, 0.2, center.z + 3.0), SmashProp.PropType.EXPLOSIVE_BARREL)
		
		elif style == 2:
			# Style 2: Gas Station / Drive-Through Canopy (Open clearance at 4.2m, zero road obstruction)
			var canopy = Node3D.new()
			canopy.position = Vector3(center.x, 0.0, center.z)
			# 4 thin steel support pillars
			var pillar_mat = StandardMaterial3D.new()
			pillar_mat.albedo_color = Color("718093")
			for px in [-4.2, 4.2]:
				for pz in [-4.2, 4.2]:
					var pillar = _create_mesh_box(Vector3(0.4, 4.2, 0.4), pillar_mat)
					pillar.position = Vector3(px, 2.1, pz)
					canopy.add_child(pillar)
					_create_building_collider(canopy, Vector3(px, 2.1, pz), Vector3(0.5, 4.2, 0.5))
			# Canopy Roof
			var roof_mat = StandardMaterial3D.new()
			roof_mat.albedo_color = Color("e74c3c") # Red fuel canopy
			var roof_mesh = _create_mesh_box(Vector3(12.0, 0.6, 12.0), roof_mat)
			roof_mesh.position = Vector3(0.0, 4.2, 0.0)
			canopy.add_child(roof_mesh)
			root.add_child(canopy)
			# Explosive gas pump in center
			_spawn_smash_prop(root, Vector3(center.x, 0.2, center.z), SmashProp.PropType.EXPLOSIVE_BARREL)
			if rng.randf() < 0.6:
				_spawn_smash_prop(root, Vector3(center.x, 0.2, center.z + 2.5), SmashProp.PropType.EXPLOSIVE_BARREL)
		
		else:
			# Style 3: Open Parking Plaza & Mini Kiosk (3.2m height)
			var kiosk_size = Vector3(5.5, 3.2, 5.5)
			var kiosk_pos = Vector3(
				center.x + (-4.0 if center.x < 24 else 4.0),
				kiosk_size.y * 0.5 + 0.2,
				center.z + (-4.0 if center.z < 24 else 4.0)
			)
			_create_building(root, kiosk_pos, kiosk_size, rng)
			# Parking stalls on the open pavement
			var p_line = _create_mesh_box(Vector3(0.2, 0.04, 4.5), _mat_marking_white)
			p_line.position = Vector3(center.x + (1.5 if center.x < 24 else -1.5), 0.22, center.z)
			root.add_child(p_line)
			
			# Potted plants outside kiosk
			_spawn_smash_prop(root, Vector3(center.x + (-1.5 if center.x < 24 else 1.5), 0.2, center.z - 3.5), SmashProp.PropType.PLANT)
			
			# Parked fleet car in open stall
			if rng.randf() < 0.7:
				var park_pos = Vector3(center.x + (3.0 if center.x < 24 else -3.0), 0.2, center.z)
				_spawn_parked_fleet_car(root, park_pos, 0.0)
		
		# Street props per corner
		var cx_inner = 17.2 if center.x < 24 else 30.8
		var cz_inner = 17.2 if center.z < 24 else 30.8
		
		# Streetlamp at curb corner
		var lamp_rot = 45.0 if (center.x < 24 and center.z < 24) else (-45.0 if (center.x > 24 and center.z < 24) else (135.0 if (center.x < 24 and center.z > 24) else -135.0))
		_spawn_smash_prop(root, Vector3(cx_inner, 0.2, cz_inner), SmashProp.PropType.STREETLAMP, lamp_rot)
		
		# Curb fire hydrant along one of the roads
		if rng.randf() < 0.65:
			var hyd_pos = Vector3(cx_inner, 0.2, center.z) if rng.randf() < 0.5 else Vector3(center.x, 0.2, cz_inner)
			_spawn_smash_prop(root, hyd_pos, SmashProp.PropType.HYDRANT)
		
		# Fence row along outer sidewalk perimeter
		if rng.randf() < 0.55:
			var fence_start = Vector3(
				center.x - 3.6,
				0.2,
				1.0 if center.z < 24 else 47.0
			)
			_spawn_fence_row(root, fence_start, 3, Vector3(2.4, 0.0, 0.0), 0.0)
		
		# Explosive barrel in alley behind or beside building
		if rng.randf() < 0.35:
			var barrel_pos = Vector3(
				center.x + (7.2 if center.x > 24 else -7.2),
				0.2,
				center.z + rng.randf_range(-3.0, 3.0)
			)
			_spawn_smash_prop(root, barrel_pos, SmashProp.PropType.EXPLOSIVE_BARREL)

## Archetype 2: PARK_SHORTCUT (20% chance)
func _build_park_shortcut(root: Node3D, rng: RandomNumberGenerator, coord: Vector2i = Vector2i.ZERO) -> void:
	# Grass ground base in city or golden sand in desert biome
	var ground_mat := get_biome_ground_material(coord)
	_create_ground_box(root, Vector3(24, -0.5, 24), Vector3(48, 1, 48), ground_mat)
	
	# Crossing asphalt roads still exist on the edges/axis
	_create_ground_box(root, Vector3(24, -0.45, 24), Vector3(48, 1, 12), _mat_asphalt)
	_create_ground_box(root, Vector3(24, -0.45, 24), Vector3(12, 1, 48), _mat_asphalt)
	
	# Diagonal drivable dirt paths cutting through corners
	var path1 = _create_mesh_box(Vector3(34.0, 0.1, 6.0), _mat_dirt)
	path1.position = Vector3(24, 0.05, 24)
	path1.rotation_degrees = Vector3(0, 45, 0)
	root.add_child(path1)
	
	var path2 = _create_mesh_box(Vector3(34.0, 0.1, 6.0), _mat_dirt)
	path2.position = Vector3(24, 0.05, 24)
	path2.rotation_degrees = Vector3(0, -45, 0)
	root.add_child(path2)
	
	# Scatter trees in park corners
	for i in range(8):
		var tx = rng.randf_range(4.0, 44.0)
		var tz = rng.randf_range(4.0, 44.0)
		# Keep road clear
		if (tz >= 18 and tz <= 30) or (tx >= 18 and tx <= 30):
			continue
		_create_tree(root, Vector3(tx, 0.0, tz), rng)
	
	# Central Jump Fountain
	_create_jump_fountain(root, Vector3(24, 0.0, 24))
	_spawn_stunt_ring(root, Vector3(24.0, 3.8, 24.0), 0.0)
	
	# White picket fences bordering park grass along road edges
	_spawn_fence_row(root, Vector3(3.0, 0.0, 17.5), 5, Vector3(2.4, 0.0, 0.0), 0.0)
	_spawn_fence_row(root, Vector3(33.0, 0.0, 17.5), 5, Vector3(2.4, 0.0, 0.0), 0.0)
	_spawn_fence_row(root, Vector3(3.0, 0.0, 30.5), 5, Vector3(2.4, 0.0, 0.0), 0.0)
	_spawn_fence_row(root, Vector3(33.0, 0.0, 30.5), 5, Vector3(2.4, 0.0, 0.0), 0.0)
	
	# Streetlamps near park trail entrances
	_spawn_smash_prop(root, Vector3(18.5, 0.0, 18.5), SmashProp.PropType.STREETLAMP, 45.0)
	_spawn_smash_prop(root, Vector3(29.5, 0.0, 18.5), SmashProp.PropType.STREETLAMP, -45.0)
	_spawn_smash_prop(root, Vector3(18.5, 0.0, 29.5), SmashProp.PropType.STREETLAMP, 135.0)
	_spawn_smash_prop(root, Vector3(29.5, 0.0, 29.5), SmashProp.PropType.STREETLAMP, -135.0)
	
	# Hydrants along main street curbs
	_spawn_smash_prop(root, Vector3(17.2, 0.0, 10.0), SmashProp.PropType.HYDRANT)
	_spawn_smash_prop(root, Vector3(30.8, 0.0, 38.0), SmashProp.PropType.HYDRANT)
	
	# Occasional explosive barrels or fruit crates tucked near park trees
	if rng.randf() < 0.45:
		_spawn_smash_prop(root, Vector3(rng.randf_range(6.0, 12.0), 0.0, rng.randf_range(6.0, 12.0)), SmashProp.PropType.EXPLOSIVE_BARREL)
	if rng.randf() < 0.45:
		_spawn_smash_prop(root, Vector3(rng.randf_range(36.0, 42.0), 0.0, rng.randf_range(36.0, 42.0)), SmashProp.PropType.FRUIT_CRATE)
	
	# Decorative smashable potted plants around fountain & promenade
	_spawn_smash_prop(root, Vector3(20.5, 0.0, 24.0), SmashProp.PropType.PLANT)
	_spawn_smash_prop(root, Vector3(27.5, 0.0, 24.0), SmashProp.PropType.PLANT)
	_spawn_smash_prop(root, Vector3(24.0, 0.0, 20.5), SmashProp.PropType.PLANT)
	_spawn_smash_prop(root, Vector3(24.0, 0.0, 27.5), SmashProp.PropType.PLANT)
	
	# Parked fleet car at the park trailhead
	if rng.randf() < 0.65:
		_spawn_parked_fleet_car(root, Vector3(10.0, 0.2, 38.0), 90.0)

## Archetype 3: RIVER_JUMP_BRIDGE (15% chance)
func _build_river_jump_bridge(root: Node3D, rng: RandomNumberGenerator, coord: Vector2i) -> void:
	# 1. Road segments leading up to river (Z: 0 to 17, and 31 to 48)
	_create_ground_box(root, Vector3(24, -0.5, 8.5), Vector3(48, 1, 17), _mat_asphalt)
	_create_ground_box(root, Vector3(24, -0.5, 39.5), Vector3(48, 1, 17), _mat_asphalt)
	
	# Sunken canal riverbed (Z from 17 to 31, 14m wide)
	_create_ground_box(root, Vector3(24, -2.5, 24), Vector3(48, 1, 14), _mat_dirt)
	
	# River water plane across canal
	var water_mesh = _create_mesh_box(Vector3(48, 0.2, 14), _mat_water)
	water_mesh.position = Vector3(24, -0.7, 24)
	root.add_child(water_mesh)
	
	# Stone Quay Retaining Walls along North & South banks
	var vab = _get_vab()
	if vab and vab.has_method("build_canal_quay_wall"):
		var q_south: Node3D = vab.build_canal_quay_wall(48.0)
		q_south.name = "CanalQuaySouth"
		q_south.position = Vector3(24.0, 0.0, 17.0)
		root.add_child(q_south)
		var q_north: Node3D = vab.build_canal_quay_wall(48.0)
		q_north.name = "CanalQuayNorth"
		q_north.position = Vector3(24.0, 0.0, 31.0)
		q_north.rotation_degrees.y = 180.0
		root.add_child(q_north)
	
	# 2. Split Water Hazard Areas (Excluded from central bridge deck at X=18..30)
	var wa_idx = 0
	for w_offset in [Vector3(8.5, -0.8, 24.0), Vector3(39.5, -0.8, 24.0)]:
		wa_idx += 1
		var water_area = Area3D.new()
		water_area.name = "WaterHazardArea_%d" % wa_idx
		water_area.position = w_offset
		water_area.collision_layer = 0
		water_area.collision_mask = 2 # PlayerCar
		
		var w_col = CollisionShape3D.new()
		var w_box = BoxShape3D.new()
		w_box.size = Vector3(17.0, 1.2, 13.5)
		w_col.shape = w_box
		water_area.add_child(w_col)
		water_area.body_entered.connect(func(body: Node3D):
			_handle_car_entered_water(body, coord)
		)
		root.add_child(water_area)
	
	# 3. Proper 2-Lane Elevated Bridge Deck (12m wide, perfectly flush with road at Y=0.0)
	_create_ground_box(root, Vector3(24.0, -0.3, 24.0), Vector3(12.0, 0.6, 14.0), _mat_bridge)
	
	# Concrete Bridge Piers underneath supporting the deck
	var pier1 = _create_mesh_box(Vector3(1.8, 2.2, 4.0), _mat_curb)
	pier1.position = Vector3(20.0, -1.6, 24.0)
	root.add_child(pier1)
	var pier2 = _create_mesh_box(Vector3(1.8, 2.2, 4.0), _mat_curb)
	pier2.position = Vector3(28.0, -1.6, 24.0)
	root.add_child(pier2)
	
	# Yellow Center Marking Line on Bridge
	var center_stripe = _create_mesh_box(Vector3(0.3, 0.04, 14.0), _mat_marking_yellow)
	center_stripe.position = Vector3(24.0, 0.02, 24.0)
	root.add_child(center_stripe)
	
	# Bridge Guardrails (Layer 4 Buildings)
	_create_guardrail(root, Vector3(17.7, 0.5, 24.0), Vector3(0.5, 1.0, 14.0))
	_create_guardrail(root, Vector3(30.3, 0.5, 24.0), Vector3(0.5, 1.0, 14.0))
	
	# Iconic Voxel Truss Arch Pillars along Bridge Sides
	var truss_mat = StandardMaterial3D.new()
	truss_mat.albedo_color = Color("e17055") # Warm Industrial Orange-Red
	truss_mat.roughness = 0.4
	for side_x in [17.7, 30.3]:
		for z_pos in [18.0, 24.0, 30.0]:
			var pillar = _create_mesh_box(Vector3(0.4, 2.6, 0.4), truss_mat)
			pillar.position = Vector3(side_x, 1.3, z_pos)
			root.add_child(pillar)
		# Overhead connecting beam
		var beam = _create_mesh_box(Vector3(0.4, 0.35, 12.4), truss_mat)
		beam.position = Vector3(side_x, 2.5, 24.0)
		root.add_child(beam)
	
	# 4. Dedicated Stunt Jump Ramps on Left Flank (X = 9.0)
	# South Approach Launch Ramp (slopes smoothly UP from Y=0 at Z=12.6 to lip Y=1.15 at Z=17.0)
	_create_launch_ramp(root, Vector3(9.0, 0.45, 14.8), Vector3(5.0, 0.7, 4.4), -18.0)
	# North Approach Launch Ramp (slopes smoothly UP from Y=0 at Z=35.4 to lip Y=1.15 at Z=31.0)
	_create_launch_ramp(root, Vector3(9.0, 0.45, 33.2), Vector3(5.0, 0.7, 4.4), 18.0)
	# Glowing Flaming Stunt Ring over the canal at the stunt jump lane
	_spawn_stunt_ring(root, Vector3(9.0, 3.8, 24.0), 0.0)
	
	# 5. Streetlamps flanking bridge entrances
	_spawn_smash_prop(root, Vector3(16.5, 0.0, 15.5), SmashProp.PropType.STREETLAMP, 90.0)
	_spawn_smash_prop(root, Vector3(31.5, 0.0, 15.5), SmashProp.PropType.STREETLAMP, -90.0)
	_spawn_smash_prop(root, Vector3(16.5, 0.0, 32.5), SmashProp.PropType.STREETLAMP, 90.0)
	_spawn_smash_prop(root, Vector3(31.5, 0.0, 32.5), SmashProp.PropType.STREETLAMP, -90.0)
	
	# Hydrants along approach roads
	_spawn_smash_prop(root, Vector3(16.2, 0.0, 8.0), SmashProp.PropType.HYDRANT)
	_spawn_smash_prop(root, Vector3(31.8, 0.0, 40.0), SmashProp.PropType.HYDRANT)
	
	# Fences blocking open river banks
	_spawn_fence_row(root, Vector3(4.0, 0.0, 16.8), 5, Vector3(2.4, 0.0, 0.0))
	_spawn_fence_row(root, Vector3(32.0, 0.0, 16.8), 5, Vector3(2.4, 0.0, 0.0))
	_spawn_fence_row(root, Vector3(4.0, 0.0, 31.2), 5, Vector3(2.4, 0.0, 0.0))
	_spawn_fence_row(root, Vector3(32.0, 0.0, 31.2), 5, Vector3(2.4, 0.0, 0.0))
	
	# Explosive barrels flanking river banks
	if rng.randf() < 0.65:
		_spawn_smash_prop(root, Vector3(15.5, 0.0, 16.0), SmashProp.PropType.EXPLOSIVE_BARREL)
	if rng.randf() < 0.65:
		_spawn_smash_prop(root, Vector3(32.5, 0.0, 32.0), SmashProp.PropType.EXPLOSIVE_BARREL)

func _handle_car_entered_water(body: Node3D, coord: Vector2i) -> void:
	var target_car: ArcadeCar = null
	if body is ArcadeCar:
		target_car = body
	elif body.owner and body.owner is ArcadeCar:
		target_car = body.owner as ArcadeCar
	elif body.get_parent() and body.get_parent() is ArcadeCar:
		target_car = body.get_parent() as ArcadeCar
	elif body.name == "PhysicsSphere":
		var p = body.get_parent()
		if p and p is ArcadeCar:
			target_car = p
	
	if target_car and is_instance_valid(target_car):
		if not target_car.is_abandoned and target_car.has_method("submerge_in_water"):
			target_car.submerge_in_water()
		player_submerged_in_water.emit(coord)
	elif body is PlayerCharacter or (body.get_parent() and body.get_parent() is PlayerCharacter) or body.is_in_group("player_character"):
		var p_char: PlayerCharacter = body as PlayerCharacter if body is PlayerCharacter else (body.get_parent() as PlayerCharacter)
		if p_char and is_instance_valid(p_char):
			p_char.is_swimming = true
	elif body is RigidBody3D:
		(body as RigidBody3D).linear_velocity *= 0.25

## Archetype 4: HIGHWAY_OVERPASS (10% chance)
func _build_highway_overpass(root: Node3D, rng: RandomNumberGenerator) -> void:
	# Full asphalt ground
	_create_ground_box(root, Vector3(24, -0.5, 24), Vector3(48, 1, 48), _mat_asphalt)
	
	# Wide highway boulevard markings (4 lanes along Z)
	for lane_x in [16.0, 20.0, 28.0, 32.0]:
		for z_step in range(0, 48, 6):
			var dash = _create_mesh_box(Vector3(0.3, 0.05, 3.0), _mat_marking_white)
			dash.position = Vector3(lane_x, 0.02, z_step + 1.5)
			root.add_child(dash)
	
	# Center Concrete Median Barrier (Layer 4 Buildings)
	_create_guardrail(root, Vector3(24.0, 0.45, 24.0), Vector3(0.8, 0.9, 48.0))
	
	# Boost Pads in left and right lanes
	_create_boost_pad(root, Vector3(18.0, 0.05, 12.0), Vector3(0, 0, -1))
	_create_boost_pad(root, Vector3(30.0, 0.05, 36.0), Vector3(0, 0, 1))
	
	# Streetlamps along outer highway shoulders
	for z_pos in [8.0, 24.0, 40.0]:
		_spawn_smash_prop(root, Vector3(12.0, 0.0, z_pos), SmashProp.PropType.STREETLAMP, 90.0)
		_spawn_smash_prop(root, Vector3(36.0, 0.0, z_pos), SmashProp.PropType.STREETLAMP, -90.0)
	
	# Explosive barrels and fruit crates along highway shoulders
	_spawn_smash_prop(root, Vector3(14.0, 0.0, 12.0), SmashProp.PropType.EXPLOSIVE_BARREL)
	_spawn_smash_prop(root, Vector3(34.0, 0.0, 36.0), SmashProp.PropType.EXPLOSIVE_BARREL)
	if rng.randf() < 0.6:
		_spawn_smash_prop(root, Vector3(22.0, 0.0, 24.0), SmashProp.PropType.FRUIT_CRATE)

# ==============================================================================
# REALISTIC CITY ARCHETYPE BUILDERS (RIVER, RAILWAY, FARMLAND, SKYSCRAPERS)
# ==============================================================================

func _get_vab() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/VoxelAssetBuilder")
	elif Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st and st.root:
			return st.root.get_node_or_null("VoxelAssetBuilder")
	return null

func _get_vdb() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/VehicleDatabase")
	elif Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st and st.root:
			return st.root.get_node_or_null("VehicleDatabase")
	return null

func _spawn_parked_fleet_car(parent: Node3D, pos: Vector3, rot_y_deg: float = 0.0, preferred_car_id: String = "") -> ArcadeCar:
	var car_scene := load("res://scenes/vehicles/arcade_car.tscn") as PackedScene
	if not car_scene:
		return null
	var car := car_scene.instantiate() as ArcadeCar
	car.name = "FleetCar_%d_%d" % [int(pos.x), int(pos.z)]
	
	var chosen_id := preferred_car_id
	var vdb = _get_vdb()
	if chosen_id.is_empty() and vdb and vdb.has_method("get_all_car_ids"):
		var all_ids: Array = vdb.get_all_car_ids()
		if not all_ids.is_empty():
			chosen_id = String(all_ids[randi() % all_ids.size()])
	if chosen_id.is_empty():
		chosen_id = "default_coupe"
	
	car.car_id = chosen_id
	car.is_abandoned = true
	car.input_enabled = false
	car.driving_forces_frozen = true
	
	parent.add_child(car)
	
	if car.has_method("set_car_profile"):
		car.set_car_profile(chosen_id)
	
	var rot_y := deg_to_rad(rot_y_deg)
	car.position = pos
	car.rotation.y = rot_y
	if car.physics_sphere:
		car.physics_sphere.position = pos + Vector3(0.0, 0.45, 0.0)
		car.physics_sphere.linear_velocity = Vector3.ZERO
		car.physics_sphere.angular_velocity = Vector3.ZERO
	if car.car_pivot:
		car.car_pivot.position = pos + Vector3(0.0, 0.45, 0.0)
		car.car_pivot.rotation.y = rot_y
	
	return car

func _create_building_collider(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var sb = StaticBody3D.new()
	sb.position = pos
	sb.collision_layer = 8 # Layer 4: Buildings
	sb.collision_mask = 0
	var cs = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	cs.shape = box
	sb.add_child(cs)
	parent.add_child(sb)
	return sb

## River Variation 0: 4-Lane Arched Stone Roadway Bridge
func _build_river_arched_bridge(root: Node3D, rng: RandomNumberGenerator, coord: Vector2i) -> void:
	# 1. Approach roads (Z: 0..17 and 31..48)
	_create_ground_box(root, Vector3(24, -0.5, 8.5), Vector3(48, 1, 17), _mat_asphalt)
	_create_ground_box(root, Vector3(24, -0.5, 39.5), Vector3(48, 1, 17), _mat_asphalt)
	
	# 2. Continuous sunken riverbed & water plane
	_create_ground_box(root, Vector3(24, -2.5, 24), Vector3(48, 1, 14), _mat_dirt)
	var water_mesh = _create_mesh_box(Vector3(48, 0.2, 14), _mat_water)
	water_mesh.position = Vector3(24, -0.7, 24)
	root.add_child(water_mesh)
	
	# 3. Stone Quay Retaining Walls along North & South banks
	var vab = _get_vab()
	if vab and vab.has_method("build_canal_quay_wall"):
		var q_south: Node3D = vab.build_canal_quay_wall(48.0)
		q_south.name = "CanalQuaySouth"
		q_south.position = Vector3(24.0, 0.0, 17.0)
		root.add_child(q_south)
		var q_north: Node3D = vab.build_canal_quay_wall(48.0)
		q_north.name = "CanalQuayNorth"
		q_north.position = Vector3(24.0, 0.0, 31.0)
		q_north.rotation_degrees.y = 180.0
		root.add_child(q_north)
	
	# 4. Split Water Hazard Areas (Left X: 0..17 and Right X: 31..48)
	var wa_idx = 0
	for w_offset in [Vector3(8.5, -0.8, 24.0), Vector3(39.5, -0.8, 24.0)]:
		wa_idx += 1
		var water_area = Area3D.new()
		water_area.name = "WaterHazardArea_%d" % wa_idx
		water_area.position = w_offset
		water_area.collision_layer = 0
		water_area.collision_mask = 2 # PlayerCar
		var w_col = CollisionShape3D.new()
		var w_box = BoxShape3D.new()
		w_box.size = Vector3(17.0, 1.2, 13.5)
		w_col.shape = w_box
		water_area.add_child(w_col)
		water_area.body_entered.connect(func(body: Node3D):
			_handle_car_entered_water(body, coord)
		)
		root.add_child(water_area)
	
	# 5. Arched Stone Roadway Bridge (14m wide)
	if vab and vab.has_method("build_arched_stone_bridge"):
		var stone_bridge: Node3D = vab.build_arched_stone_bridge(14.0, 14.0)
		stone_bridge.position = Vector3(24.0, 0.0, 24.0)
		root.add_child(stone_bridge)
	_create_ground_box(root, Vector3(24.0, -0.2, 24.0), Vector3(14.0, 0.4, 14.0), _mat_asphalt)
	
	# Yellow Center Line
	var center_stripe = _create_mesh_box(Vector3(0.3, 0.04, 14.0), _mat_marking_yellow)
	center_stripe.position = Vector3(24.0, 0.02, 24.0)
	root.add_child(center_stripe)
	
	# Stone Balustrade Guardrails
	_create_guardrail(root, Vector3(16.8, 0.5, 24.0), Vector3(0.6, 1.0, 14.0))
	_create_guardrail(root, Vector3(31.2, 0.5, 24.0), Vector3(0.6, 1.0, 14.0))
	
	# Streetlamps at bridge approaches
	_spawn_smash_prop(root, Vector3(16.0, 0.0, 15.5), SmashProp.PropType.STREETLAMP, 90.0)
	_spawn_smash_prop(root, Vector3(32.0, 0.0, 15.5), SmashProp.PropType.STREETLAMP, -90.0)
	_spawn_smash_prop(root, Vector3(16.0, 0.0, 32.5), SmashProp.PropType.STREETLAMP, 90.0)
	_spawn_smash_prop(root, Vector3(32.0, 0.0, 32.5), SmashProp.PropType.STREETLAMP, -90.0)

## River Variation 2: Open Canal with Stone Quays and Stunt Ramp
func _build_river_quay_canal(root: Node3D, rng: RandomNumberGenerator, coord: Vector2i) -> void:
	# Approach roads
	_create_ground_box(root, Vector3(24, -0.5, 8.5), Vector3(48, 1, 17), _mat_asphalt)
	_create_ground_box(root, Vector3(24, -0.5, 39.5), Vector3(48, 1, 17), _mat_asphalt)
	
	# Sunken canal & water plane across whole chunk
	_create_ground_box(root, Vector3(24, -2.5, 24), Vector3(48, 1, 14), _mat_dirt)
	var water_mesh = _create_mesh_box(Vector3(48, 0.2, 14), _mat_water)
	water_mesh.position = Vector3(24, -0.7, 24)
	root.add_child(water_mesh)
	
	# Stone Quay Retaining Walls
	var vab = _get_vab()
	if vab and vab.has_method("build_canal_quay_wall"):
		var q_south: Node3D = vab.build_canal_quay_wall(48.0)
		q_south.name = "CanalQuaySouth"
		q_south.position = Vector3(24.0, 0.0, 17.0)
		root.add_child(q_south)
		var q_north: Node3D = vab.build_canal_quay_wall(48.0)
		q_north.name = "CanalQuayNorth"
		q_north.position = Vector3(24.0, 0.0, 31.0)
		q_north.rotation_degrees.y = 180.0
		root.add_child(q_north)
	
	# Full Water Hazard Area across canal
	var water_area = Area3D.new()
	water_area.name = "WaterHazardArea_Full"
	water_area.position = Vector3(24.0, -0.8, 24.0)
	water_area.collision_layer = 0
	water_area.collision_mask = 2 # PlayerCar
	var w_col = CollisionShape3D.new()
	var w_box = BoxShape3D.new()
	w_box.size = Vector3(48.0, 1.2, 13.5)
	w_col.shape = w_box
	water_area.add_child(w_col)
	water_area.body_entered.connect(func(body: Node3D):
		_handle_car_entered_water(body, coord)
	)
	root.add_child(water_area)
	
	# Stunt Ramps for jumping across the open canal (Center X = 24.0)
	_create_launch_ramp(root, Vector3(24.0, 0.45, 14.8), Vector3(6.0, 0.7, 4.4), -18.0)
	_create_launch_ramp(root, Vector3(24.0, 0.45, 33.2), Vector3(6.0, 0.7, 4.4), 18.0)
	_spawn_stunt_ring(root, Vector3(24.0, 3.8, 24.0), 0.0)
	
	# Riverside bollards and fences
	_spawn_fence_row(root, Vector3(3.0, 0.0, 16.8), 6, Vector3(2.4, 0.0, 0.0))
	_spawn_fence_row(root, Vector3(32.0, 0.0, 16.8), 6, Vector3(2.4, 0.0, 0.0))
	_spawn_fence_row(root, Vector3(3.0, 0.0, 31.2), 6, Vector3(2.4, 0.0, 0.0))
	_spawn_fence_row(root, Vector3(32.0, 0.0, 31.2), 6, Vector3(2.4, 0.0, 0.0))
	
	if rng.randf() < 0.65:
		_spawn_smash_prop(root, Vector3(15.5, 0.0, 16.0), SmashProp.PropType.EXPLOSIVE_BARREL)
	if rng.randf() < 0.65:
		_spawn_smash_prop(root, Vector3(32.5, 0.0, 32.0), SmashProp.PropType.FRUIT_CRATE)

## Railway Corridor crossing over River: Steel Warren Through-Truss Bridge
func _build_railway_river_bridge(root: Node3D, rng: RandomNumberGenerator, coord: Vector2i) -> void:
	# Approaches
	_create_ground_box(root, Vector3(24, -0.5, 8.5), Vector3(48, 1, 17), _mat_asphalt)
	_create_ground_box(root, Vector3(24, -0.5, 39.5), Vector3(48, 1, 17), _mat_asphalt)
	
	# River channel & water
	_create_ground_box(root, Vector3(24, -2.5, 24), Vector3(48, 1, 14), _mat_dirt)
	var water_mesh = _create_mesh_box(Vector3(48, 0.2, 14), _mat_water)
	water_mesh.position = Vector3(24, -0.7, 24)
	root.add_child(water_mesh)
	
	var vab = _get_vab()
	if vab and vab.has_method("build_canal_quay_wall"):
		var q_south: Node3D = vab.build_canal_quay_wall(48.0)
		q_south.name = "CanalQuaySouth"
		q_south.position = Vector3(24.0, 0.0, 17.0)
		root.add_child(q_south)
		var q_north: Node3D = vab.build_canal_quay_wall(48.0)
		q_north.name = "CanalQuayNorth"
		q_north.position = Vector3(24.0, 0.0, 31.0)
		q_north.rotation_degrees.y = 180.0
		root.add_child(q_north)
	
	# Split Water Hazard Areas (Left X: 0..19 and Right X: 29..48)
	var wa_idx = 0
	for w_offset in [Vector3(9.5, -0.8, 24.0), Vector3(38.5, -0.8, 24.0)]:
		wa_idx += 1
		var water_area = Area3D.new()
		water_area.name = "WaterHazardArea_Rail_%d" % wa_idx
		water_area.position = w_offset
		water_area.collision_layer = 0
		water_area.collision_mask = 2 # PlayerCar
		var w_col = CollisionShape3D.new()
		var w_box = BoxShape3D.new()
		w_box.size = Vector3(19.0, 1.2, 13.5)
		w_col.shape = w_box
		water_area.add_child(w_col)
		water_area.body_entered.connect(func(body: Node3D):
			_handle_car_entered_water(body, coord)
		)
		root.add_child(water_area)
	
	# Steel Girder Bridge across water
	if vab and vab.has_method("build_railway_girder_bridge"):
		var g_bridge: Node3D = vab.build_railway_girder_bridge(14.0)
		g_bridge.position = Vector3(24.0, 0.0, 24.0)
		root.add_child(g_bridge)
	_create_ground_box(root, Vector3(24.0, -0.2, 24.0), Vector3(7.4, 0.4, 14.0), _mat_bridge)
	
	# Dual tracks on approach banks (Z: 0..17 and 31..48)
	if vab and vab.has_method("build_rail_tracks"):
		var t1: Node3D = vab.build_rail_tracks(17.0)
		t1.name = "RailTracksSouth"
		t1.position = Vector3(24.0, 0.0, 8.5)
		root.add_child(t1)
		var t2: Node3D = vab.build_rail_tracks(17.0)
		t2.name = "RailTracksNorth"
		t2.position = Vector3(24.0, 0.0, 39.5)
		root.add_child(t2)
	
	# Girder Guardrails
	_create_guardrail(root, Vector3(20.2, 1.5, 24.0), Vector3(0.5, 3.0, 14.0))
	_create_guardrail(root, Vector3(27.8, 1.5, 24.0), Vector3(0.5, 3.0, 14.0))

## Continuous Dedicated North-South Railway Line & Automated Level Crossing
func _build_railway_corridor(root: Node3D, rng: RandomNumberGenerator, coord: Vector2i) -> void:
	# 1. Base ground
	_create_ground_box(root, Vector3(24, -0.5, 24), Vector3(48, 1, 48), _mat_asphalt)
	
	# 2. Dual Ballasted Railway Tracks along Z at X=24
	var vab = _get_vab()
	if vab and vab.has_method("build_rail_tracks"):
		var tracks: Node3D = vab.build_rail_tracks(48.0)
		tracks.position = Vector3(24.0, 0.0, 24.0)
		root.add_child(tracks)
	_create_ground_box(root, Vector3(24.0, 0.05, 24.0), Vector3(7.4, 0.18, 48.0), _mat_curb)
	
	# 3. East-West Roadway Crossing Markings
	for x in range(0, 18, 6):
		var dash = _create_mesh_box(Vector3(3.0, 0.05, 0.3), _mat_marking_yellow)
		dash.position = Vector3(x + 1.5, 0.02, 24.0)
		root.add_child(dash)
	for x in range(30, 48, 6):
		var dash = _create_mesh_box(Vector3(3.0, 0.05, 0.3), _mat_marking_yellow)
		dash.position = Vector3(x + 1.5, 0.02, 24.0)
		root.add_child(dash)
	
	# Stop lines on approaches
	var stop_w = _create_mesh_box(Vector3(0.6, 0.05, 12.0), _mat_marking_white)
	stop_w.position = Vector3(18.5, 0.02, 24.0)
	root.add_child(stop_w)
	var stop_e = _create_mesh_box(Vector3(0.6, 0.05, 12.0), _mat_marking_white)
	stop_e.position = Vector3(29.5, 0.02, 24.0)
	root.add_child(stop_e)
	
	# 4. Automated Level Crossing Barriers
	var b_west: Node3D = null
	var b_east: Node3D = null
	if vab and vab.has_method("build_level_crossing_barrier"):
		b_west = vab.build_level_crossing_barrier()
		b_west.name = "CrossingBarrierWest"
		b_west.position = Vector3(19.0, 0.0, 30.5)
		root.add_child(b_west)
		
		b_east = vab.build_level_crossing_barrier()
		b_east.name = "CrossingBarrierEast"
		b_east.position = Vector3(29.0, 0.0, 17.5)
		b_east.rotation_degrees.y = 180.0
		root.add_child(b_east)
	
	# Smashable Rail Gate props on the barrier positions
	_spawn_smash_prop(root, Vector3(19.0, 0.5, 27.0), SmashProp.PropType.RAIL_GATE)
	_spawn_smash_prop(root, Vector3(29.0, 0.5, 21.0), SmashProp.PropType.RAIL_GATE)
	
	# Register Level Crossing
	_level_crossings.append({
		"barrier_left": b_west,
		"barrier_right": b_east,
		"global_pos": root.position + Vector3(24.0, 0.0, 24.0),
		"chunk_coord": coord,
		"is_closed": false
	})
	
	# 5. Streetlamps along road
	_spawn_smash_prop(root, Vector3(16.5, 0.0, 17.0), SmashProp.PropType.STREETLAMP, 90.0)
	_spawn_smash_prop(root, Vector3(31.5, 0.0, 31.0), SmashProp.PropType.STREETLAMP, -90.0)

## Farmland & Countryside Biome Chunk
func _build_farmland_chunk(root: Node3D, rng: RandomNumberGenerator, coord: Vector2i) -> void:
	# 1. Pastoral Green Ground
	_create_ground_box(root, Vector3(24, -0.5, 24), Vector3(48, 1, 48), _mat_grass)
	
	# 2. Narrow 2-lane country road crossing with dirt shoulders
	_create_ground_box(root, Vector3(24, 0.005, 24), Vector3(48, 0.01, 10.0), _mat_dirt)
	_create_ground_box(root, Vector3(24, 0.005, 24), Vector3(10.0, 0.01, 48), _mat_dirt)
	_create_ground_box(root, Vector3(24, 0.01, 24), Vector3(48, 0.02, 6.0), _mat_asphalt)
	_create_ground_box(root, Vector3(24, 0.01, 24), Vector3(6.0, 0.02, 48), _mat_asphalt)
	
	var vab = _get_vab()
	
	# 3. Quadrant 1 (NW: X=9, Z=9): Furrowed Golden Wheat Field
	if vab and vab.has_method("build_crop_field"):
		var wheat = vab.build_crop_field(15.0, 15.0, 0, rng)
		wheat.name = "CropFieldWheat"
		wheat.position = Vector3(9.0, 0.05, 9.0)
		root.add_child(wheat)
	_spawn_smash_prop(root, Vector3(15.5, 0.0, 14.0), SmashProp.PropType.HAY_BALE)
	_spawn_smash_prop(root, Vector3(14.0, 0.0, 15.5), SmashProp.PropType.HAY_BALE)
	_spawn_smash_prop(root, Vector3(15.5, 0.9, 15.5), SmashProp.PropType.HAY_BALE)
	_spawn_smash_prop(root, Vector3(3.0, 0.0, 17.5), SmashProp.PropType.RUSTIC_FENCE)
	_spawn_smash_prop(root, Vector3(6.0, 0.0, 17.5), SmashProp.PropType.RUSTIC_FENCE)
	_spawn_smash_prop(root, Vector3(9.0, 0.0, 17.5), SmashProp.PropType.RUSTIC_FENCE)
	
	# 4. Quadrant 2 (NE: X=39, Z=9): Sweet Corn or Pumpkin Patch
	var crop_t: int = 1 if rng.randf() > 0.5 else 2
	if vab and vab.has_method("build_crop_field"):
		var patch = vab.build_crop_field(15.0, 15.0, crop_t, rng)
		patch.name = "CropFieldPatch"
		patch.position = Vector3(39.0, 0.05, 9.0)
		root.add_child(patch)
	_spawn_smash_prop(root, Vector3(33.0, 0.0, 14.0), SmashProp.PropType.HAY_BALE)
	_spawn_smash_prop(root, Vector3(39.0, 0.0, 17.5), SmashProp.PropType.RUSTIC_FENCE)
	_spawn_smash_prop(root, Vector3(42.0, 0.0, 17.5), SmashProp.PropType.RUSTIC_FENCE)
	
	# Spawn juicy smashable pumpkins throughout the crop field
	for px in [33.0, 36.5, 40.0, 43.5]:
		for pz in [5.5, 9.5, 13.5]:
			if rng.randf() < 0.8:
				_spawn_smash_prop(root, Vector3(px, 0.0, pz), SmashProp.PropType.PUMPKIN, rng.randf_range(-30, 30))
	
	# 5. Quadrant 3 (SW: X=9, Z=39): Red Gambrel Barn, Silo & Tractor
	if vab and vab.has_method("build_red_barn_and_silo"):
		var barn = vab.build_red_barn_and_silo(rng)
		barn.position = Vector3(9.0, 0.0, 39.0)
		root.add_child(barn)
		_create_building_collider(root, Vector3(9.0, 3.5, 39.0), Vector3(14.0, 7.0, 10.0))
		_create_building_collider(root, Vector3(18.5, 5.5, 38.5), Vector3(4.4, 11.0, 4.4))
	
	if vab and vab.has_method("build_farm_tractor"):
		var tractor = vab.build_farm_tractor()
		tractor.position = Vector3(16.0, 0.0, 32.0)
		root.add_child(tractor)
	
	_spawn_smash_prop(root, Vector3(13.0, 0.0, 31.0), SmashProp.PropType.FRUIT_CRATE)
	_spawn_smash_prop(root, Vector3(14.2, 0.0, 31.0), SmashProp.PropType.FRUIT_CRATE)
	_spawn_smash_prop(root, Vector3(11.5, 0.0, 32.5), SmashProp.PropType.PLANT)
	_spawn_smash_prop(root, Vector3(16.5, 0.0, 32.5), SmashProp.PropType.PLANT)
	# Parked fleet car at the farm
	_spawn_parked_fleet_car(root, Vector3(11.0, 0.0, 35.5), 0.0)
	# Stunt launch ramp over the tractor!
	_create_launch_ramp(root, Vector3(16.0, 0.45, 27.5), Vector3(4.2, 0.7, 3.5), -20.0)
	
	# 6. Quadrant 4 (SE: X=39, Z=39): Spinning Country Windmill & Pasture
	if vab and vab.has_method("build_country_windmill"):
		var windmill = vab.build_country_windmill(rng)
		windmill.position = Vector3(39.0, 0.0, 39.0)
		root.add_child(windmill)
		_create_building_collider(root, Vector3(39.0, 4.5, 39.0), Vector3(5.6, 9.0, 5.6))
	
	_create_tree(root, Vector3(32.0, 0.0, 32.0), rng)
	_create_tree(root, Vector3(44.0, 0.0, 44.0), rng)
	_spawn_smash_prop(root, Vector3(34.0, 0.0, 37.0), SmashProp.PropType.HAY_BALE)
	_spawn_smash_prop(root, Vector3(36.0, 0.0, 37.0), SmashProp.PropType.HAY_BALE)
	_spawn_smash_prop(root, Vector3(37.5, 0.0, 34.0), SmashProp.PropType.PUMPKIN)

## Skyscraper Plaza: Tiered Skyscraper with Helipad & Parking Garage with Rooftop Stunt
func _build_skyscraper_plaza(root: Node3D, rng: RandomNumberGenerator, coord: Vector2i) -> void:
	_create_ground_box(root, Vector3(24, -0.5, 24), Vector3(48, 1, 48), _mat_asphalt)
	_add_road_markings(root)
	
	var vab = _get_vab()
	
	# NW: Tiered Skyscraper (X=9, Z=9)
	var sky_col = _building_mats[rng.randi() % _building_mats.size()].albedo_color
	if vab and vab.has_method("build_skyscraper_tiered"):
		var sky = vab.build_skyscraper_tiered(14.0, 14.0, 20.0, sky_col, rng)
		sky.position = Vector3(9.0, 0.0, 9.0)
		root.add_child(sky)
		_create_building_collider(root, Vector3(9.0, 10.0, 9.0), Vector3(14.0, 20.0, 14.0))
	else:
		_create_building(root, Vector3(9.0, 10.0, 9.0), Vector3(14.0, 20.0, 14.0), rng)
	
	# NE: Drivable 2-Story Parking Garage with Rooftop Launch Lip (X=39, Z=9)
	if vab and vab.has_method("build_parking_garage_with_ramp"):
		var garage = vab.build_parking_garage_with_ramp(rng)
		garage.position = Vector3(39.0, 0.0, 9.0)
		root.add_child(garage)
	
	# Solid Drivable Colliders for Garage Decks & Ramps
	_create_ground_box(root, Vector3(39.0, 0.1, 9.0), Vector3(18.0, 0.2, 18.0), _mat_curb)
	_create_ground_box(root, Vector3(39.0, 3.8, 9.0), Vector3(16.0, 0.4, 16.0), _mat_bridge)
	_create_ground_box(root, Vector3(39.0, 7.6, 9.0), Vector3(16.0, 0.4, 16.0), _mat_bridge)
	# Drivable Ramp up to roof
	_create_launch_ramp(root, Vector3(49.2, 1.9, 9.0), Vector3(4.2, 0.4, 10.5), -20.0)
	# Rooftop Launch Lip facing South off the roof toward the street
	_create_launch_ramp(root, Vector3(39.0, 8.1, 2.5), Vector3(4.5, 0.6, 3.2), -24.0)
	_create_boost_pad(root, Vector3(39.0, 8.35, 3.2), Vector3(0, 0, 1))
	# Parked fleet car on garage ground floor
	_spawn_parked_fleet_car(root, Vector3(39.0, 0.2, 12.0), 90.0)
	
	# SW: Boutique Shops with Alleyway Shortcut (X=9, Z=39)
	var b1 = Vector3(5.8, 6.0, 12.0)
	var b2 = Vector3(5.8, 6.0, 12.0)
	_create_building(root, Vector3(4.8, 3.2, 39.0), b1, rng)
	_create_building(root, Vector3(13.2, 3.2, 39.0), b2, rng)
	_spawn_smash_prop(root, Vector3(9.0, 0.2, 39.0), SmashProp.PropType.FRUIT_CRATE)
	_spawn_smash_prop(root, Vector3(9.0, 0.2, 42.0), SmashProp.PropType.EXPLOSIVE_BARREL)
	# Parked fleet car in alleyway
	_spawn_parked_fleet_car(root, Vector3(9.0, 0.2, 34.0), 0.0)
	
	# SE: Low-profile Plaza (Camera Safe, X=39, Z=39)
	_create_ground_box(root, Vector3(39.0, 0.1, 39.0), Vector3(18.0, 0.2, 18.0), _mat_curb)
	_create_building(root, Vector3(40.5, 2.2, 40.5), Vector3(10.0, 4.0, 10.0), rng)
	_create_tree(root, Vector3(33.0, 0.2, 33.0), rng)
	_create_tree(root, Vector3(33.0, 0.2, 45.0), rng)
	_spawn_smash_prop(root, Vector3(36.0, 0.2, 34.0), SmashProp.PropType.PLANT)
	_spawn_smash_prop(root, Vector3(42.0, 0.2, 34.0), SmashProp.PropType.PLANT)
	
	# Streetlamps at corners
	_spawn_smash_prop(root, Vector3(17.2, 0.2, 17.2), SmashProp.PropType.STREETLAMP, 45.0)
	_spawn_smash_prop(root, Vector3(30.8, 0.2, 17.2), SmashProp.PropType.STREETLAMP, -45.0)
	_spawn_smash_prop(root, Vector3(17.2, 0.2, 30.8), SmashProp.PropType.STREETLAMP, 135.0)
	_spawn_smash_prop(root, Vector3(30.8, 0.2, 30.8), SmashProp.PropType.STREETLAMP, -135.0)

# ==============================================================================
# MOVING TRAIN SYSTEM & LEVEL CROSSINGS
# ==============================================================================

func _update_active_train(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		return
	
	var player_x := _current_chunk_coord.x
	var base_r := player_x - posmod(player_x - 5, 8)
	var candidate_rails := [base_r, base_r + 8, base_r - 8]
	var closest_rail_x: int = candidate_rails[0]
	var min_dist: int = absi(closest_rail_x - player_x)
	for rx in candidate_rails:
		if absi(rx - player_x) < min_dist:
			min_dist = absi(rx - player_x)
			closest_rail_x = rx
	
	if min_dist > ACTIVE_RADIUS + 1:
		if _active_train and is_instance_valid(_active_train):
			_active_train.visible = false
		return
	
	if _active_train == null or not is_instance_valid(_active_train):
		_spawn_train_entity(closest_rail_x)
	elif _active_train_rail_x != closest_rail_x:
		_active_train_rail_x = closest_rail_x
		_active_train.global_position.x = closest_rail_x * CHUNK_SIZE + 24.0
	
	if not _active_train:
		return
	_active_train.visible = true
	
	_train_z += _train_speed * _train_dir * delta
	var player_pos_z: float = target_player.global_position.z
	var range_limit: float = float(ACTIVE_RADIUS + 2) * float(CHUNK_SIZE)
	if _train_z > player_pos_z + range_limit:
		_train_z = player_pos_z - range_limit
	elif _train_z < player_pos_z - range_limit:
		_train_z = player_pos_z + range_limit
	
	_active_train.global_position = Vector3(closest_rail_x * CHUNK_SIZE + 24.0, 0.0, _train_z)
	
	for crossing in _level_crossings:
		var crossing_z: float = crossing["global_pos"].z
		var dist: float = absf(_train_z - crossing_z)
		if dist < 65.0:
			_set_crossing_closed(crossing, true)
		elif dist > 75.0 and crossing["is_closed"]:
			_set_crossing_closed(crossing, false)

func _spawn_train_entity(rail_x: int) -> void:
	if _active_train and is_instance_valid(_active_train):
		_active_train.queue_free()
	
	var vab = _get_vab()
	if not vab or not vab.has_method("build_freight_train_multi_car"):
		return
	
	_active_train_rail_x = rail_x
	_active_train = vab.build_freight_train_multi_car()
	_active_train.name = "ActiveFreightTrain"
	
	var loco = _active_train.find_child("Locomotive", true, false)
	if loco:
		var area := Area3D.new()
		area.name = "TrainCowcatcher"
		area.collision_layer = 0
		area.collision_mask = 2 | 4 | 16 # PlayerCar, PoliceCar, SmashProps
		
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.2, 2.5, 4.0)
		cs.shape = box
		cs.position = Vector3(0.0, 1.25, -5.0)
		area.add_child(cs)
		
		area.body_entered.connect(func(body: Node3D):
			_on_train_hit_body(body)
		)
		loco.add_child(area)
	
	var pz: float = target_player.global_position.z if target_player else 0.0
	_train_z = pz - 80.0
	_active_train.position = Vector3(rail_x * CHUNK_SIZE + 24.0, 0.0, _train_z)
	add_child(_active_train)

func _on_train_hit_body(body: Node3D) -> void:
	var target_rb: RigidBody3D = null
	var target_car = null
	
	if body is RigidBody3D:
		target_rb = body as RigidBody3D
	elif body.get_node_or_null("PhysicsSphere") is RigidBody3D:
		target_rb = body.get_node("PhysicsSphere") as RigidBody3D
	elif body.get_parent() and body.get_parent() is RigidBody3D:
		target_rb = body.get_parent() as RigidBody3D
	
	if body.has_method("wreck") or body.has_method("wreck_car") or body.has_method("take_damage"):
		target_car = body
	elif body.get_parent() and (body.get_parent().has_method("wreck") or body.get_parent().has_method("wreck_car") or body.get_parent().has_method("take_damage")):
		target_car = body.get_parent()
	elif body.owner and (body.owner.has_method("wreck") or body.owner.has_method("wreck_car") or body.owner.has_method("take_damage")):
		target_car = body.owner
	
	if target_rb:
		var knockback = Vector3(0.0, 0.35, _train_dir).normalized() * (60.0 * target_rb.mass) + Vector3.UP * (24.0 * target_rb.mass)
		target_rb.apply_central_impulse(knockback)
	
	if target_car:
		if target_car.has_method("wreck"):
			target_car.wreck()
		elif target_car.has_method("wreck_car"):
			target_car.wreck_car()
		elif target_car.has_method("take_damage"):
			target_car.take_damage(65.0)

func _set_crossing_closed(crossing: Dictionary, closed: bool) -> void:
	if crossing["is_closed"] == closed:
		return
	crossing["is_closed"] = closed
	var b_left: Node3D = crossing.get("barrier_left")
	var b_right: Node3D = crossing.get("barrier_right")
	
	var target_rot = deg_to_rad(-85.0) if closed else 0.0
	for b in [b_left, b_right]:
		if not is_instance_valid(b):
			continue
		var pivot = b.find_child("GatePivot", true, false)
		if pivot:
			var tw = create_tween()
			tw.tween_property(pivot, "rotation:z", target_rot, 0.8)
		var lamp_l = b.find_child("FlasherLeft", true, false)
		var lamp_r = b.find_child("FlasherRight", true, false)
		if lamp_l and lamp_r:
			lamp_l.visible = true
			lamp_r.visible = not closed

# ==============================================================================
# HELPER BUILDERS & GEOMETRY
# ==============================================================================

func _create_ground_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var sb = StaticBody3D.new()
	sb.position = pos
	sb.collision_layer = 1 # Ground
	sb.collision_mask = 0
	
	var cs = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	cs.shape = box
	sb.add_child(cs)
	
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	sb.add_child(mi)
	
	parent.add_child(sb)
	return sb

func _create_building(parent: Node3D, pos: Vector3, size: Vector3, rng: RandomNumberGenerator) -> StaticBody3D:
	var sb = StaticBody3D.new()
	sb.position = pos
	sb.collision_layer = 8 # Layer 4: Buildings
	sb.collision_mask = 0
	
	var cs = CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var box = BoxShape3D.new()
	box.size = size
	cs.shape = box
	sb.add_child(cs)
	
	var b_mat = _building_mats[rng.randi() % _building_mats.size()]
	var vab = get_node_or_null("/root/VoxelAssetBuilder")
	if vab and vab.has_method("build_detailed_building"):
		var b_visual: Node3D = vab.build_detailed_building(size.x, size.z, size.y, b_mat.albedo_color, rng)
		sb.add_child(b_visual)
	else:
		var mi = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = size
		bm.material = b_mat
		mi.mesh = bm
		sb.add_child(mi)
		
		# Roof accent rim
		var roof = MeshInstance3D.new()
		var r_mesh = BoxMesh.new()
		r_mesh.size = Vector3(size.x * 0.92, 0.5, size.z * 0.92)
		var r_mat = _roof_mats[rng.randi() % _roof_mats.size()]
		r_mesh.material = r_mat
		roof.mesh = r_mesh
		roof.position = Vector3(0.0, size.y * 0.5 + 0.25, 0.0)
		sb.add_child(roof)
	
	parent.add_child(sb)
	return sb

func _create_tree(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var tree = Node3D.new()
	tree.position = pos
	
	# Trunk
	var trunk = MeshInstance3D.new()
	var t_mesh = BoxMesh.new()
	t_mesh.size = Vector3(0.5, 2.0, 0.5)
	t_mesh.material = _mat_tree_trunk
	trunk.mesh = t_mesh
	trunk.position = Vector3(0.0, 1.0, 0.0)
	tree.add_child(trunk)
	
	# Foliage
	var foliage = MeshInstance3D.new()
	var f_mesh = BoxMesh.new()
	var f_size = rng.randf_range(2.0, 3.2)
	f_mesh.size = Vector3(f_size, f_size * 1.2, f_size)
	f_mesh.material = _mat_tree_foliage
	foliage.mesh = f_mesh
	foliage.position = Vector3(0.0, 2.0 + f_size * 0.5, 0.0)
	tree.add_child(foliage)
	
	# Smash collider on Layer 5 SmashProps
	var sb = StaticBody3D.new()
	sb.collision_layer = 16 # SmashProps
	sb.collision_mask = 0
	var cs = CollisionShape3D.new()
	var col_box = BoxShape3D.new()
	col_box.size = Vector3(0.6, 2.0, 0.6)
	cs.shape = col_box
	cs.position = Vector3(0.0, 1.0, 0.0)
	sb.add_child(cs)
	tree.add_child(sb)
	
	parent.add_child(tree)
	return tree

func _create_jump_fountain(parent: Node3D, pos: Vector3) -> Node3D:
	var fountain = Node3D.new()
	fountain.position = pos
	
	# Fountain basin (8x8 m)
	_create_ground_box(fountain, Vector3(0, 0.25, 0), Vector3(7.5, 0.5, 7.5), _mat_curb)
	
	# Blue water center
	var water = _create_mesh_box(Vector3(6.5, 0.1, 6.5), _mat_water)
	water.position = Vector3(0, 0.52, 0)
	fountain.add_child(water)
	
	# Approach launch ramps on 4 sides
	_create_launch_ramp(fountain, Vector3(0, 0.25, 4.2), Vector3(5.0, 0.5, 1.8), 22.0)
	_create_launch_ramp(fountain, Vector3(0, 0.25, -4.2), Vector3(5.0, 0.5, 1.8), -22.0)
	_create_launch_ramp(fountain, Vector3(4.2, 0.25, 0), Vector3(1.8, 0.5, 5.0), 0.0, -22.0)
	_create_launch_ramp(fountain, Vector3(-4.2, 0.25, 0), Vector3(1.8, 0.5, 5.0), 0.0, 22.0)
	
	parent.add_child(fountain)
	return fountain

func _create_launch_ramp(parent: Node3D, pos: Vector3, size: Vector3, rot_x_deg: float, rot_z_deg: float = 0.0) -> StaticBody3D:
	var sb = StaticBody3D.new()
	sb.position = pos
	sb.rotation_degrees = Vector3(rot_x_deg, 0.0, rot_z_deg)
	sb.collision_layer = 1 # Ground
	sb.collision_mask = 0
	
	var cs = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	cs.shape = box
	sb.add_child(cs)
	
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	bm.material = _mat_ramp
	mi.mesh = bm
	sb.add_child(mi)
	
	parent.add_child(sb)
	return sb

func _create_guardrail(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var sb = StaticBody3D.new()
	sb.position = pos
	sb.collision_layer = 8 # Layer 4: Buildings
	sb.collision_mask = 0
	
	var cs = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	cs.shape = box
	sb.add_child(cs)
	
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	bm.material = _mat_curb
	mi.mesh = bm
	sb.add_child(mi)
	
	parent.add_child(sb)
	return sb

func _create_boost_pad(parent: Node3D, pos: Vector3, boost_dir: Vector3) -> Area3D:
	var area = Area3D.new()
	area.name = "BoostPadArea"
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 2 # PlayerCar
	
	var cs = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(3.2, 0.6, 3.2)
	cs.shape = box
	area.add_child(cs)
	
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(2.8, 0.08, 2.8)
	bm.material = _mat_boost
	mi.mesh = bm
	area.add_child(mi)
	
	area.body_entered.connect(func(body: Node3D):
		if body is RigidBody3D:
			body.apply_central_impulse(boost_dir.normalized() * (22.0 * body.mass))
			player_hit_boost_pad.emit(area.global_position)
	)
	
	parent.add_child(area)
	return area

func _spawn_smash_prop(parent: Node3D, pos: Vector3, type: SmashProp.PropType, rot_y_deg: float = 0.0) -> SmashProp:
	var prop = SmashPropScene.instantiate() as SmashProp
	prop.prop_type = type
	prop.position = pos
	prop.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	parent.add_child(prop)
	return prop

func _spawn_fence_row(parent: Node3D, start_pos: Vector3, count: int, step_dir: Vector3, rot_y_deg: float = 0.0) -> void:
	for i in range(count):
		_spawn_smash_prop(parent, start_pos + step_dir * float(i), SmashProp.PropType.FENCE, rot_y_deg)

const FlamingStuntRingScript = preload("res://scripts/world/flaming_stunt_ring.gd")

func _spawn_stunt_ring(parent: Node3D, pos: Vector3, rot_y_deg: float = 0.0) -> Node3D:
	var ring: Node3D = FlamingStuntRingScript.new()
	ring.name = "FlamingStuntRing"
	ring.position = pos
	ring.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	parent.add_child(ring)
	return ring

func _create_smash_crate(parent: Node3D, pos: Vector3) -> SmashProp:
	return _spawn_smash_prop(parent, pos, SmashProp.PropType.FRUIT_CRATE)

func _add_road_markings(root: Node3D) -> void:
	# Yellow center dashed lines along X road
	for x_pos in [Vector2(0, 18), Vector2(30, 48)]:
		for x in range(int(x_pos.x), int(x_pos.y), 6):
			var dash = _create_mesh_box(Vector3(3.0, 0.05, 0.3), _mat_marking_yellow)
			dash.position = Vector3(x + 1.5, 0.02, 24.0)
			root.add_child(dash)
	
	# Yellow center dashed lines along Z road
	for z_pos in [Vector2(0, 18), Vector2(30, 48)]:
		for z in range(int(z_pos.x), int(z_pos.y), 6):
			var dash = _create_mesh_box(Vector3(0.3, 0.05, 3.0), _mat_marking_yellow)
			dash.position = Vector3(24.0, 0.02, z + 1.5)
			root.add_child(dash)

func _create_mesh_box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	return mi

# ==============================================================================
# SHARED MATERIALS INITIALIZATION
# ==============================================================================

func _init_shared_materials() -> void:
	_mat_asphalt = StandardMaterial3D.new()
	_mat_asphalt.albedo_color = Color(0.20, 0.22, 0.25)
	_mat_asphalt.roughness = 0.7
	
	_mat_curb = StandardMaterial3D.new()
	_mat_curb.albedo_color = Color(0.72, 0.74, 0.76)
	_mat_curb.roughness = 0.55
	
	_mat_marking_white = StandardMaterial3D.new()
	_mat_marking_white.albedo_color = Color(0.95, 0.95, 0.95)
	_mat_marking_white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	_mat_marking_yellow = StandardMaterial3D.new()
	_mat_marking_yellow.albedo_color = Color(0.96, 0.80, 0.15)
	_mat_marking_yellow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	_mat_grass = StandardMaterial3D.new()
	_mat_grass.albedo_color = Color(0.24, 0.72, 0.22) # Vibrant arcade green grass
	_mat_grass.roughness = 0.85
	
	_mat_sand = StandardMaterial3D.new()
	_mat_sand.albedo_color = Color(0.92, 0.78, 0.45) # Warm golden desert sand
	_mat_sand.roughness = 0.90
	
	_mat_dirt = StandardMaterial3D.new()
	_mat_dirt.albedo_color = Color(0.60, 0.50, 0.36)
	_mat_dirt.roughness = 0.9
	
	_mat_water = StandardMaterial3D.new()
	_mat_water.albedo_color = Color(0.12, 0.45, 0.82, 0.85)
	_mat_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_water.roughness = 0.15
	
	_mat_bridge = StandardMaterial3D.new()
	_mat_bridge.albedo_color = Color(0.32, 0.35, 0.38)
	_mat_bridge.roughness = 0.6
	
	_mat_ramp = StandardMaterial3D.new()
	_mat_ramp.albedo_color = Color(0.92, 0.48, 0.12)
	_mat_ramp.roughness = 0.5
	
	_mat_boost = StandardMaterial3D.new()
	_mat_boost.albedo_color = Color(0.1, 0.9, 1.0)
	_mat_boost.emission_enabled = true
	_mat_boost.emission = Color(0.1, 0.9, 1.0)
	_mat_boost.emission_energy_multiplier = 2.0
	
	_mat_tree_trunk = StandardMaterial3D.new()
	_mat_tree_trunk.albedo_color = Color(0.42, 0.28, 0.16)
	_mat_tree_trunk.roughness = 0.8
	
	_mat_tree_foliage = StandardMaterial3D.new()
	_mat_tree_foliage.albedo_color = Color(0.20, 0.52, 0.20)
	_mat_tree_foliage.roughness = 0.75
	
	# Pastel building palettes
	var b_colors = [
		Color(0.92, 0.88, 0.82),
		Color(0.72, 0.82, 0.88),
		Color(0.88, 0.76, 0.72),
		Color(0.78, 0.88, 0.78),
		Color(0.85, 0.78, 0.92),
		Color(0.95, 0.85, 0.68)
	]
	for c in b_colors:
		var m = StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.5
		_building_mats.append(m)
	
	# Roof accent palettes
	var r_colors = [
		Color(0.24, 0.26, 0.32),
		Color(0.88, 0.25, 0.30),
		Color(0.18, 0.65, 0.85),
		Color(0.85, 0.65, 0.15),
		Color(0.55, 0.28, 0.65)
	]
	for c in r_colors:
		var m = StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.4
		_roof_mats.append(m)
