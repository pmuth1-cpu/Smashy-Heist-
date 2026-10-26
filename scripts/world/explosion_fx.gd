class_name ExplosionFX
extends RefCounted

## Punchy Arcade Bomb Explosion Effect for Smashy Heist.
## Balanced for clean gameplay readability, crisp feedback, and punchy visual impact:
## - Snappy flash light (moderate intensity, fades out quickly without blinding the screen)
## - Tight cluster of burning voxel shrapnel blocks with realistic gravity
## - Secondary yellow-hot ember sparks
## - Snappy ground shockwave ring that clears cleanly
## - Compact expanding spherical fireball that pops and dissipates
## - Soft, fast-fading smoke puffs that preserve player visibility
## - Balanced radial physics impulse and punchy screen trauma

static func spawn(parent: Node, pos: Vector3, scale_mult: float = 1.0, is_mega: bool = false) -> Node3D:
	return _spawn_internal(parent, pos, scale_mult, is_mega, false)

## Spawns an asymmetrical Valorant-style debris & liquid splash explosion (no circular rings or sphere balls)
static func spawn_splash(parent: Node, pos: Vector3, scale_mult: float = 1.0, is_mega: bool = false) -> Node3D:
	return _spawn_internal(parent, pos, scale_mult, is_mega, true)

static func _spawn_internal(parent: Node, pos: Vector3, scale_mult: float, is_mega: bool, is_splash: bool) -> Node3D:
	if not parent or not is_instance_valid(parent):
		return null
	
	var root := Node3D.new()
	root.name = "ExplosionFX"
	root.position = pos
	parent.add_child(root)
	_build_explosion(root, scale_mult, is_mega, is_splash)
	return root

static func _build_explosion(root: Node3D, scale_mult: float, is_mega: bool, is_splash: bool = false) -> void:
	if not root or not is_instance_valid(root):
		return
	
	# 1. Screen Trauma & Impact Audio Punch (Crisp and punchy, not disorienting)
	var cam_rig = root.get_tree().root.find_child("CameraRig", true, false) if (root.get_tree() and root.get_tree().root) else null
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.38 if is_mega else 0.26)
	
	var sound_node = root.get_node_or_null("/root/SoundFX") if (root.get_tree() and root.get_tree().root) else null
	if sound_node:
		if sound_node.has_method("play_explosion"):
			sound_node.play_explosion()
		if sound_node.has_method("play_bass_impact"):
			sound_node.play_bass_impact()
	
	# 2. Flash Light (Moderate, snappy pop that does not wash out the screen)
	var flash := OmniLight3D.new()
	flash.name = "BlastLight"
	flash.light_color = Color("fff200") if is_mega else Color("ff9f1a")
	flash.light_energy = 4.2 if is_mega else 3.2
	flash.omni_range = 8.5 * scale_mult
	root.add_child(flash)
	
	# 3. Voxel Shrapnel Burst (Tight, readable arcade debris)
	var particles := GPUParticles3D.new()
	particles.name = "BombShrapnelBurst"
	var p_mat := ParticleProcessMaterial.new()
	p_mat.direction = Vector3(0.0, 1.0, 0.0)
	p_mat.spread = 60.0
	p_mat.initial_velocity_min = 6.0 * scale_mult
	p_mat.initial_velocity_max = 11.0 * scale_mult
	p_mat.gravity = Vector3(0.0, -11.0, 0.0)
	p_mat.scale_min = 0.15 * scale_mult
	p_mat.scale_max = 0.24 * scale_mult
	p_mat.color = Color("ff793f") if is_mega else Color("ff9f43")
	particles.process_material = p_mat
	
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(0.18, 0.18, 0.18) * scale_mult
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("ff5252") if is_mega else Color("ff9f1a")
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_mesh.material = bm
	particles.draw_pass_1 = b_mesh
	
	particles.amount = 18 if is_mega else 14
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.position = Vector3(0.0, 0.35 * scale_mult, 0.0)
	root.add_child(particles)
	particles.emitting = true
	
	# 4. Secondary Fire Embers (Lightweight high-speed sparks)
	var embers := GPUParticles3D.new()
	embers.name = "FireEmbers"
	var e_mat := ParticleProcessMaterial.new()
	e_mat.direction = Vector3(0.0, 1.0, 0.0)
	e_mat.spread = 70.0
	e_mat.initial_velocity_min = 7.0 * scale_mult
	e_mat.initial_velocity_max = 13.0 * scale_mult
	e_mat.gravity = Vector3(0.0, -14.0, 0.0)
	e_mat.scale_min = 0.06 * scale_mult
	e_mat.scale_max = 0.12 * scale_mult
	e_mat.color = Color("fff200")
	embers.process_material = e_mat
	
	var em_mesh := BoxMesh.new()
	em_mesh.size = Vector3(0.08, 0.08, 0.08) * scale_mult
	var emm := StandardMaterial3D.new()
	emm.albedo_color = Color("fff200")
	emm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em_mesh.material = emm
	embers.draw_pass_1 = em_mesh
	
	embers.amount = 12 if is_mega else 8
	embers.lifetime = 0.45
	embers.one_shot = true
	embers.explosiveness = 0.92
	embers.position = Vector3(0.0, 0.35 * scale_mult, 0.0)
	root.add_child(embers)
	embers.emitting = true
	
	var ring: MeshInstance3D = null
	var fireball: MeshInstance3D = null
	var splash_group: Node3D = null
	
	if is_splash:
		# 5. Stylized Valorant Directional Splash Spikes & Asymmetric Ground Splatter (NO CIRCLES)
		splash_group = Node3D.new()
		splash_group.name = "SplashBurstGroup"
		root.add_child(splash_group)
		
		# 8 Directional Angular Splash Spires erupting upward and outward in a jagged geyser
		var splash_mat := StandardMaterial3D.new()
		splash_mat.albedo_color = Color("ff4757")
		splash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		splash_mat.emission_enabled = true
		splash_mat.emission = Color("ffa502")
		splash_mat.emission_energy_multiplier = 2.4
		
		var rim_mat := StandardMaterial3D.new()
		rim_mat.albedo_color = Color("ffffff")
		rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rim_mat.emission_enabled = true
		rim_mat.emission = Color("ffffff")
		rim_mat.emission_energy_multiplier = 3.5
		
		for sp in range(8):
			var spire := MeshInstance3D.new()
			spire.name = "SplashSpire_%d" % sp
			var pm := PrismMesh.new()
			var p_len: float = randf_range(1.2, 2.4) * scale_mult
			pm.size = Vector3(0.35, p_len, 0.28) * scale_mult
			spire.mesh = pm
			spire.material_override = splash_mat
			
			var ang := (float(sp) / 8.0) * TAU + randf_range(-0.25, 0.25)
			var tilt_x := randf_range(25.0, 55.0)
			spire.rotation_degrees = Vector3(tilt_x, rad_to_deg(ang), randf_range(-15.0, 15.0))
			spire.position = Vector3(sin(ang) * 0.4, 0.35 * scale_mult, cos(ang) * 0.4)
			spire.scale = Vector3(0.15, 0.15, 0.15)
			splash_group.add_child(spire)
			
			# High-contrast bright tip highlight on every spire (Valorant accent)
			var tip := MeshInstance3D.new()
			tip.name = "TipHighlight"
			var tip_box := BoxMesh.new()
			tip_box.size = Vector3(0.12, 0.25, 0.12) * scale_mult
			tip.mesh = tip_box
			tip.material_override = rim_mat
			tip.position = Vector3(0.0, p_len * 0.45, 0.0)
			spire.add_child(tip)
			
			var stw := root.create_tween().set_parallel(true)
			var out_pos := spire.position + Vector3(sin(ang) * 2.8, 1.4 + randf() * 0.8, cos(ang) * 2.8) * scale_mult
			stw.tween_property(spire, "position", out_pos, 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			stw.tween_property(spire, "scale", Vector3(1.15, 1.35, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			stw.tween_property(spire, "scale", Vector3(0.01, 0.01, 0.01), 0.16).set_delay(0.18)
		
		# Asymmetrical Ground Splatter Decal Lobes (Irregular starburst splatter on pavement)
		var splatter_root := Node3D.new()
		splatter_root.name = "GroundSplatterStarburst"
		splatter_root.position.y = 0.05
		splash_group.add_child(splatter_root)
		
		var splat_mat := StandardMaterial3D.new()
		splat_mat.albedo_color = Color("ff6348")
		splat_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		splat_mat.emission_enabled = true
		splat_mat.emission = Color("ff7f50")
		splat_mat.emission_energy_multiplier = 2.0
		
		for sb in range(7):
			var lobe := MeshInstance3D.new()
			var l_box := BoxMesh.new()
			var l_len: float = randf_range(1.4, 2.8) * scale_mult
			l_box.size = Vector3(randf_range(0.25, 0.5), 0.04, l_len)
			lobe.mesh = l_box
			lobe.material_override = splat_mat
			var s_ang := (float(sb) / 7.0) * TAU + randf_range(-0.3, 0.3)
			lobe.rotation.y = s_ang
			lobe.position = Vector3(sin(s_ang) * (l_len * 0.45), 0.0, cos(s_ang) * (l_len * 0.45))
			lobe.scale = Vector3(0.1, 1.0, 0.1)
			splatter_root.add_child(lobe)
			
			var ltw := root.create_tween().set_parallel(true)
			ltw.tween_property(lobe, "scale", Vector3(1.2, 1.0, 1.2), 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			ltw.tween_property(lobe, "scale", Vector3(0.01, 1.0, 0.01), 0.15).set_delay(0.22)
	else:
		# 5. Expanding Ground Shockwave Ring (Snappy circular ground blast)
		ring = MeshInstance3D.new()
		ring.name = "ShockwaveRing"
		var torus := TorusMesh.new()
		torus.inner_radius = 0.35
		torus.outer_radius = 0.55
		torus.rings = 20
		torus.ring_segments = 14
		ring.mesh = torus
		
		var r_mat := StandardMaterial3D.new()
		r_mat.albedo_color = Color("ff5252")
		r_mat.emission_enabled = true
		r_mat.emission = Color("ff9f43")
		r_mat.emission_energy_multiplier = 2.8
		r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = r_mat
		ring.position.y = 0.08
		root.add_child(ring)
		
		# 6. Central Expanding Fireball Sphere (Snappy pop & fast fade)
		fireball = MeshInstance3D.new()
		fireball.name = "Fireball"
		var sphere := SphereMesh.new()
		sphere.radius = 0.55 * scale_mult
		sphere.height = 1.1 * scale_mult
		fireball.mesh = sphere
		
		var f_mat := StandardMaterial3D.new()
		f_mat.albedo_color = Color("ff5252")
		f_mat.emission_enabled = true
		f_mat.emission = Color("f368e0") if is_mega else Color("ff793f")
		f_mat.emission_energy_multiplier = 3.2
		f_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		f_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fireball.material_override = f_mat
		fireball.position.y = 0.45 * scale_mult
		root.add_child(fireball)
	
	# 7. Fast-Dissipating Soft Smoke Puffs (Preserves screen visibility)
	for s in range(2):
		var smoke := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = (0.38 + s * 0.15) * scale_mult
		sph.height = (0.76 + s * 0.30) * scale_mult
		smoke.mesh = sph
		
		var s_mat := StandardMaterial3D.new()
		s_mat.albedo_color = Color("2d3436")
		s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		s_mat.roughness = 0.95
		smoke.material_override = s_mat
		smoke.position = Vector3(randf_range(-0.3, 0.3), 0.4 + s * 0.25, randf_range(-0.3, 0.3))
		root.add_child(smoke)
		
		var s_tw := root.create_tween().set_parallel(true)
		s_tw.tween_property(smoke, "position:y", smoke.position.y + 1.2 * scale_mult, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		s_tw.tween_property(smoke, "scale", Vector3(1.4, 1.4, 1.4), 0.40)
		s_tw.tween_property(smoke, "transparency", 1.0, 0.35).set_delay(0.08)
	
	# 8. Radial Physical Blast Wave (Balanced push for cars and props)
	var blast_radius: float = (5.8 if is_mega else 4.4) * scale_mult
	if root.is_inside_tree() and root.get_world_3d():
		var space_state := root.get_world_3d().direct_space_state
		var shape_query := PhysicsShapeQueryParameters3D.new()
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = blast_radius
		shape_query.shape = sphere_shape
		shape_query.transform = Transform3D(Basis(), root.global_position)
		shape_query.collision_mask = 31 # Cars, cops, props
		
		var hits := space_state.intersect_shape(shape_query, 16)
		for hit in hits:
			var collider: Object = hit.get("collider")
			if collider and collider is RigidBody3D:
				var rb := collider as RigidBody3D
				var dir: Vector3 = (rb.global_position - root.global_position)
				dir.y += 0.35
				dir = dir.normalized()
				var dist: float = root.global_position.distance_to(rb.global_position)
				var factor: float = clampf(1.0 - (dist / blast_radius), 0.25, 1.0)
				rb.apply_central_impulse(dir * ((20.0 if is_mega else 14.0) * factor * rb.mass))
	
	# 9. Main Tween sequence for flash, ring, and fireball animation
	var tw := root.create_tween().set_parallel(true)
	# Flash fade (quick 0.20s fade)
	tw.tween_property(flash, "light_energy", 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	if ring:
		# Shockwave ring expansion (snappy 3.8m ring)
		var ring_target_scale := Vector3(3.8, 1.0, 3.8) * scale_mult
		tw.tween_property(ring, "scale", ring_target_scale, 0.28).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(ring, "transparency", 1.0, 0.28)
	
	if fireball:
		# Fireball expansion and fade (clean 2.2m pop)
		var fireball_target_scale := Vector3(2.2, 2.2, 2.2) * scale_mult
		tw.tween_property(fireball, "scale", fireball_target_scale, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(fireball, "transparency", 1.0, 0.28)
	
	# Auto-cleanup after particles and animations finish
	tw.chain().tween_interval(0.55)
	tw.chain().tween_callback(func():
		if is_instance_valid(root):
			root.queue_free()
	)
