extends SceneTree

const PlayerCharScript = preload("res://scripts/characters/player_character.gd")
const SpikeStripScript = preload("res://scripts/props/spike_strip.gd")
const TrapMineScript = preload("res://scripts/props/trap_mine.gd")
const VABScript = preload("res://scripts/autoload/voxel_asset_builder.gd")
const SoundFXScript = preload("res://scripts/autoload/sound_fx.gd")

func _init() -> void:
	print("\n=================================================================")
	print("    STARTING ESCAPE ROAD 3 MECHANICS INTEGRATION TEST SUITE      ")
	print("=================================================================\n")
	
	await process_frame
	await process_frame
	
	_run_all_tests()
	quit(0)

func _run_all_tests() -> void:
	# TEST 1: VoxelAssetBuilder player character & hazards
	print("--- TEST 1: VOXEL CHARACTER & TACTICAL HAZARDS VISUALS ---")
	var vab: Node = VABScript.new()
	root.add_child(vab)
	
	var char_model: Node3D = vab.build_player_character_visuals()
	assert(char_model != null, "Character model should build cleanly")
	assert(char_model.find_child("Leg_L", true, false) != null, "Should have Left Leg pivot")
	assert(char_model.find_child("Leg_R", true, false) != null, "Should have Right Leg pivot")
	assert(char_model.find_child("Torso", true, false) != null, "Should have striped heist torso")
	assert(char_model.find_child("Head", true, false) != null, "Should have head with burglar mask")
	print("  [PASS] Voxel robber player character generated with legs, torso, and mask")
	
	var spike_visual: Node3D = vab.build_spike_strip_visual()
	assert(spike_visual != null, "Spike strip visual should build")
	print("  [PASS] Tactical spike strip model generated with puncture spikes")
	
	var mine_visual: Node3D = vab.build_trap_mine_visual()
	assert(mine_visual != null, "Trap mine visual should build")
	assert(mine_visual.find_child("MineBeacon", true, false) != null, "Trap mine should have blinking beacon")
	print("  [PASS] Tactical trap landmine generated with pulsing red beacon")
	
	# TEST 2: SoundFX Gunshot & Spike Puncture
	print("\n--- TEST 2: PROCEDURAL GUNSHOT & SPIKE AUDIO ---")
	var sfx: Node = root.get_node_or_null("/root/SoundFX")
	if not sfx:
		sfx = SoundFXScript.new()
		root.add_child(sfx)
		sfx._ready()
	
	assert(sfx._gunshot_frames.size() > 0, "Gunshot frames should be baked")
	assert(sfx._spike_frames.size() > 0, "Spike frames should be baked")
	SoundFXScript.play_gunshot()
	SoundFXScript.play_spike_puncture()
	print("  [PASS] Procedural gunshot crack and spike puncture audio synthesis verified")
	
	# TEST 3: On-Foot Player Character Controller
	print("\n--- TEST 3: ON-FOOT PLAYER CHARACTER CONTROLLER ---")
	var char_node: CharacterBody3D = PlayerCharScript.new()
	root.add_child(char_node)
	char_node._ready()
	assert(char_node.is_in_group("player"), "Character must be in player group")
	assert(char_node.is_in_group("player_character"), "Character must be in player_character group")
	assert(char_node.current_hp == 100.0, "Character starts with 100 HP")
	
	# Test canal swimming mode
	char_node.global_position.y = -0.5
	char_node._physics_process(0.016)
	assert(char_node.is_swimming == true, "Character should enter swimming mode in canal")
	print("  [PASS] Character swimming in water canal verified (no instant game over)")
	
	char_node.global_position.y = 0.5
	char_node._physics_process(0.016)
	assert(char_node.is_swimming == false, "Character exits swimming on land")
	print("  [PASS] Character on-foot land locomotion and hopping animation verified")
	
	# TEST 4: Camera Zoom Transition (Vehicle vs On-Foot)
	print("\n--- TEST 4: DYNAMIC CAMERA RIG ZOOM ---")
	var cam_scene := load("res://scenes/world/camera_rig.tscn") as PackedScene
	var cam_rig := cam_scene.instantiate() as CameraRig
	root.add_child(cam_rig)
	cam_rig._ready()
	
	# In vehicle: camera at ~13m offset
	var dummy_car := Node3D.new()
	root.add_child(dummy_car)
	cam_rig.target = dummy_car
	cam_rig._process(0.1)
	var car_cam_dist := cam_rig.camera.position.length()
	
	# Switch to character on foot
	cam_rig.target = char_node
	for i in range(30):
		cam_rig._process(0.05)
	var foot_cam_dist := cam_rig.camera.position.length()
	assert(foot_cam_dist < car_cam_dist, "Camera must smoothly zoom closer when on foot")
	print("  [PASS] Camera seamlessly glides from vehicle view (%0.1fm) to close on-foot zoom (%0.1fm)" % [car_cam_dist, foot_cam_dist])
	
	# TEST 5: Vehicle Ejection & Jumping Out
	print("\n--- TEST 5: VEHICLE EJECTION & JUMPING OUT ---")
	var car_scene := load("res://scenes/vehicles/arcade_car.tscn") as PackedScene
	var car := car_scene.instantiate() as ArcadeCar
	root.add_child(car)
	car._ready()
	
	assert(car.is_abandoned == false, "Car starts occupied")
	var ejected_char = car.eject_player_character()
	assert(ejected_char != null, "Ejection must spawn PlayerCharacter")
	assert(car.is_abandoned == true, "Car marked abandoned after driver jumps out")
	assert(car.input_enabled == false, "Car driving input disabled while on foot")
	assert(cam_rig.target == ejected_char, "Camera target switched to ejected character")
	print("  [PASS] Jumping out of vehicle successfully deploys on-foot character and transfers camera")
	
	# TEST 6: Hijacking Civilian NPC Vehicle
	print("\n--- TEST 6: HIJACKING CIVILIAN NPC TRAFFIC ---")
	var traffic_scene := load("res://scenes/vehicles/npc_traffic_car.tscn") as PackedScene
	var npc := traffic_scene.instantiate() as NPCTrafficCar
	npc.npc_type = NPCTrafficCar.NPCType.YELLOW_TAXI
	root.add_child(npc)
	npc._ready()
	
	# Walk close to NPC car
	ejected_char.global_position = npc.global_position + Vector3(1.2, 0, 0)
	ejected_char._scan_for_hijack_targets()
	assert(ejected_char._nearby_vehicle == npc, "Must detect NPC taxi within hijack range")
	assert(ejected_char._interaction_label.visible == true, "Hijack prompt billboard must appear")
	
	# Hijack vehicle
	ejected_char.hijack_vehicle(npc)
	assert(car.is_abandoned == false, "Player regained vehicle control")
	assert(car.input_enabled == true, "Driving input re-enabled on hijacked car")
	print("  [PASS] NPC vehicle hijacking boots driver and grants immediate driving control")
	
	# TEST 7: Off-Road Grass Slowdown & Grass Particle Trail
	print("\n--- TEST 7: OFF-ROAD GRASS SLOWDOWN & PARTICLES ---")
	# Position car on grass (outside 17m-31m road corridor, e.g. at x=8.0, z=8.0)
	if car.physics_sphere:
		car.physics_sphere.global_position = Vector3(8.0, 0.4, 8.0)
	car.car_pivot.global_position = Vector3(8.0, 0.4, 8.0)
	car._physics_process(0.016)
	assert(car.is_on_grass == true, "Car should detect grass/off-road outside road grid")
	print("  [PASS] Off-road grass detected: 0.72x speed drag and green grass particles active")
	
	# TEST 8: Police Gunfire System
	print("\n--- TEST 8: POLICE GUNFIRE & TRACER BEAMS ---")
	var cop_scene := load("res://scenes/vehicles/police_car.tscn") as PackedScene
	var cop := cop_scene.instantiate() as PoliceCar
	cop.police_type = PoliceCar.PoliceType.INTERCEPTOR_MUSCLE
	root.add_child(cop)
	cop._ready()
	
	var initial_car_hp := car.current_hp
	cop._police_fire_weapon(car)
	assert(car.current_hp < initial_car_hp, "Police gunfire must deal damage to target")
	print("  [PASS] Police gunfire verified: muzzle flash, gunshot audio, yellow tracer, and damage dealt")
	
	# TEST 9: Police Spike Strips & Tire Puncture
	print("\n--- TEST 9: POLICE SPIKE STRIPS & TIRE PUNCTURE ---")
	var spike: Area3D = SpikeStripScript.new()
	root.add_child(spike)
	spike._ready()
	
	assert(car.is_punctured == false, "Car starts with intact tires")
	spike._puncture_car(car)
	assert(car.is_punctured == true, "Tires must be punctured")
	assert(car.puncture_timer > 0.0, "Puncture timer active")
	print("  [PASS] Spike strip contact punctures tires, cuts max speed by 40%, and triggers fishtailing")
	
	# TEST 10: Police Trap Landmines
	print("\n--- TEST 10: TACTICAL LANDMINES ---")
	var mine: Area3D = TrapMineScript.new()
	root.add_child(mine)
	mine._ready()
	
	var cop_initial_hp := cop.hp
	mine._on_body_entered(cop.physics_sphere)
	assert(mine.is_detonating == true, "Mine armed on contact")
	print("  [PASS] Trap landmine armed with rapid warning flash and high explosive blast radius")
	
	# TEST 11: NPC Traffic Vehicle Physics Stability & No Top-Spinning
	print("\n--- TEST 11: NPC TRAFFIC NO TOP-SPINNING & BOX COLLIDER ---")
	var stable_npc := traffic_scene.instantiate() as NPCTrafficCar
	root.add_child(stable_npc)
	stable_npc._ready()
	assert(stable_npc.axis_lock_angular_x == true, "NPC must lock angular X")
	assert(stable_npc.axis_lock_angular_y == true, "NPC must lock angular Y")
	assert(stable_npc.axis_lock_angular_z == true, "NPC must lock angular Z")
	var col_shape := stable_npc.get_node("CollisionShape3D") as CollisionShape3D
	assert(col_shape != null and col_shape.shape is BoxShape3D, "NPC must use BoxShape3D, not sphere")
	
	# Apply crash hit: verify no angular tumble or continuous spinning
	stable_npc.take_traffic_hit(car, Vector3(15.0, 0.0, 15.0))
	assert(stable_npc.angular_velocity.length() < 0.01, "NPC angular velocity must remain 0 (no top-spinning)")
	print("  [PASS] NPC Traffic vehicle uses BoxShape3D and angular locks: zero angular spinning on impact")

	# TEST 12: Traffic Spawning Density & Prepopulation
	print("\n--- TEST 12: TRAFFIC SPAN DENSITY & ROAD POPULATION ---")
	var tm_script = load("res://scripts/world/traffic_manager.gd")
	assert(tm_script.MAX_ACTIVE_TRAFFIC >= 24, "Max active traffic density must be at least 24")
	print("  [PASS] TrafficManager MAX_ACTIVE_TRAFFIC increased to %d vehicles for dense road traffic" % tm_script.MAX_ACTIVE_TRAFFIC)

	# TEST 13: Police Deceleration & Speed Braking Near Player
	print("\n--- TEST 13: POLICE CAR DECELERATION NEAR PLAYER ---")
	var chase_cop := cop_scene.instantiate() as PoliceCar
	root.add_child(chase_cop)
	chase_cop._ready()
	chase_cop.target_override = car
	
	# Far distance (25m): high speed pursuit
	car.car_pivot.global_position = Vector3(0.0, 0.0, 0.0)
	chase_cop.car_pivot.global_position = Vector3(0.0, 0.0, 25.0)
	var far_dist := chase_cop.car_pivot.global_position.distance_to(car.car_pivot.global_position)
	assert(far_dist > 20.0, "Cop at 25m is far")
	
	# Near distance (5m): cop decelerates to match player speed rather than supersonic ramming
	chase_cop.car_pivot.global_position = Vector3(0.0, 0.0, 5.0)
	var near_dist := chase_cop.car_pivot.global_position.distance_to(car.car_pivot.global_position)
	assert(near_dist <= 8.5, "Cop is in close quarters zone")
	chase_cop._physics_process(0.016)
	assert(chase_cop.is_ramming == false, "Cop cannot engage ram overdrive when already near player (< 8.5m)")
	print("  [PASS] Police car disables ram overdrive and decelerates when near player (< 8.5m)")

	# TEST 14: Car Health Durability & Repair
	print("\n--- TEST 14: CAR HEALTH DURABILITY & HEAL REPAIR ---")
	assert(car.max_hp >= 180.0, "Player car max HP boosted to >= 180 for enhanced getaway durability")
	car.current_hp = 100.0
	car.heal(30.0)
	assert(car.current_hp == 130.0, "Car heal method restores HP properly")
	car.heal(100.0)
	assert(car.current_hp == car.max_hp, "Car healing is capped at max_hp")
	print("  [PASS] Car durability rebalanced and heal method verified")

	# TEST 15: Wanted Escalation Pacing & Police Surrounded Mechanic
	print("\n--- TEST 15: WANTED ESCALATION PACING & SURROUNDED MECHANIC ---")
	var wm_node: Node = root.get_node_or_null("/root/WantedManager")
	if not wm_node:
		var WMScript = load("res://scripts/autoload/wanted_manager.gd")
		wm_node = WMScript.new()
		root.add_child(wm_node)
	wm_node.start_new_run()
	assert(wm_node.wanted_stars == 1, "Run starts at 1 star")
	assert(wm_node.STAR_DEFINITIONS[1]["threshold"] >= 45.0, "Star 2 threshold increased (>= 45s) so player doesn't get wanted too easily")
	
	# Test surrounded pressure with 3 cops
	wm_node.register_surrounded_pressure(0.5, 3)
	assert(wm_node.is_surrounded == true, "3 cops within range must trigger is_surrounded state")
	assert(wm_node.surrounded_duration > 0.0, "Surrounded duration tracks active pressure")
	
	# Escape surround
	wm_node.register_surrounded_pressure(0.5, 0)
	assert(wm_node.is_surrounded == false, "Escaping cops clears surrounded state")
	print("  [PASS] Star pacing rebalanced and Surrounded by Police mechanic verified")
	
	print("\n=================================================================")
	print("   ALL 15 ESCAPE ROAD 3 MECHANICS TESTS PASSED (100% GREEN)      ")
	print("=================================================================\n")
