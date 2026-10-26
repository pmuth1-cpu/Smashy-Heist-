class_name ValorantSkillVFX
extends RefCounted

## Valorant-Style Multi-State Skill Visual Effects Engine
## Implements tactical, stylized visual effects across the 4 states of matter:
## 1. 💨 GAS / VAPOR (Faceted smoke domes, ground perimeter rings, orbiting billows)
## 2. 🧪 LIQUID / VISCOUS (Wet specular multi-lobed puddles, parabolic droplets, tidal surges)
## 3. 🧊 SOLID / CRYSTALLINE (Snap-erupting rock spires, jade ice prisms, fracture decals)
## 4. ⚡ ENERGY / PLASMA / VOID (Cosmic accretion discs, laser ribbons, EMP shockwaves, dragon flame)

# -----------------------------------------------------------------------------
# CATEGORY A: 💨 GAS / VAPOR
# -----------------------------------------------------------------------------

## Spawns a Valorant-style faceted smoke dome with an emissive ground perimeter ring,
## internal churning billows, and top-venting wisps.
static func spawn_gas_smoke_dome(parent: Node, origin: Vector3, config: Dictionary = {}) -> Node3D:
	if not parent or not is_instance_valid(parent):
		return null
	
	var col: Color = config.get("color", Color(0.9, 0.9, 0.9, 0.85))
	var radius: float = config.get("radius", 6.0)
	var duration: float = config.get("duration", 4.0)
	var dome_height: float = config.get("dome_height", radius * 0.75)
	var hazard_type: String = config.get("hazard_type", "smoke") # smoke, sand, toxic, peace
	
	var root := Node3D.new()
	root.name = "ValorantGasSmokeDome"
	root.position = origin
	parent.add_child(root)
	
	# 1. Pavement Ground Projection Perimeter Ring (TorusMesh)
	var ring_mesh_inst := MeshInstance3D.new()
	ring_mesh_inst.name = "GroundPerimeterRing"
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(0.5, radius * 0.95)
	torus.outer_radius = radius * 1.05
	torus.rings = 24
	torus.ring_segments = 6
	ring_mesh_inst.mesh = torus
	ring_mesh_inst.position.y = 0.04
	
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = col
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.emission = col
	ring_mat.emission_energy_multiplier = 3.0
	ring_mesh_inst.material_override = ring_mat
	root.add_child(ring_mesh_inst)
	
	# Ring pop-in scale
	ring_mesh_inst.scale = Vector3(0.1, 1.0, 0.1)
	var ring_tw := ring_mesh_inst.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ring_tw.tween_property(ring_mesh_inst, "scale", Vector3.ONE, 0.3)
	
	# 2. Stylized Faceted Smoke Dome (Double-sided SphereMesh with low segments for cel/faceted look)
	var dome_mesh_inst := MeshInstance3D.new()
	dome_mesh_inst.name = "FacetedSmokeDome"
	var sphere := SphereMesh.new()
	sphere.radius = radius * 0.96
	sphere.height = dome_height * 2.0
	sphere.radial_segments = 14 # Crisp faceted silhouettes
	sphere.rings = 7
	sphere.is_hemisphere = true
	dome_mesh_inst.mesh = sphere
	dome_mesh_inst.position.y = 0.02
	
	var dome_mat := StandardMaterial3D.new()
	dome_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	dome_mat.cull_mode = BaseMaterial3D.CULL_DISABLED # Visible from inside & outside (like Brimstone/Omen)
	dome_mat.albedo_color = Color(col.r, col.g, col.b, 0.98) # Solid cel color
	dome_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dome_mat.rim_enabled = true # Crisp edge highlight
	dome_mat.rim = 1.0
	dome_mat.rim_tint = 0.8
	dome_mat.emission_enabled = true
	dome_mat.emission = col * 0.55
	dome_mat.roughness = 0.35
	dome_mesh_inst.material_override = dome_mat
	root.add_child(dome_mesh_inst)
	
	# Valorant-style Crisp Luminous Contour Highlight Ring on the dome upper curvature
	var contour_ring := MeshInstance3D.new()
	contour_ring.name = "DomeHighlightContourRing"
	var c_torus := TorusMesh.new()
	c_torus.inner_radius = radius * 0.70
	c_torus.outer_radius = radius * 0.76
	c_torus.rings = 20
	c_torus.ring_segments = 5
	contour_ring.mesh = c_torus
	contour_ring.position.y = dome_height * 0.62
	var c_mat := StandardMaterial3D.new()
	c_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	c_mat.albedo_color = Color.WHITE
	c_mat.emission_enabled = true
	c_mat.emission = Color.WHITE.lerp(col, 0.3)
	c_mat.emission_energy_multiplier = 4.0
	contour_ring.material_override = c_mat
	root.add_child(contour_ring)
	
	# Snappy dome inflation
	dome_mesh_inst.scale = Vector3(0.05, 0.05, 0.05)
	var dome_tw := dome_mesh_inst.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	dome_tw.tween_property(dome_mesh_inst, "scale", Vector3.ONE, 0.28)
	
	# 3. Internal Swirling Cloud Vortices (Orbiting billow clusters)
	var vortex_root := Node3D.new()
	vortex_root.name = "SwirlingCloudVortices"
	root.add_child(vortex_root)
	
	var billow_mat := StandardMaterial3D.new()
	billow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	billow_mat.albedo_color = Color(col.r * 1.1, col.g * 1.1, col.b * 1.1, 0.7)
	billow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	var billow_count: int = 5
	for i in range(billow_count):
		var angle: float = (TAU / float(billow_count)) * float(i)
		var dist: float = radius * 0.45
		var puff := MeshInstance3D.new()
		puff.name = "InternalBillow_%d" % i
		var p_sph := SphereMesh.new()
		p_sph.radius = radius * 0.26
		p_sph.height = radius * 0.48
		p_sph.radial_segments = 8
		p_sph.rings = 4
		puff.mesh = p_sph
		puff.material_override = billow_mat
		puff.position = Vector3(cos(angle) * dist, dome_height * 0.45 + randf_range(-0.3, 0.3), sin(angle) * dist)
		vortex_root.add_child(puff)
		
		# Individual billow breathing pulse
		var p_tw := puff.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		p_tw.tween_property(puff, "scale", Vector3(1.15, 1.1, 1.15), 1.2 + float(i) * 0.15)
		p_tw.tween_property(puff, "scale", Vector3(0.9, 0.95, 0.9), 1.2 + float(i) * 0.15)
	
	# Orbit the vortex root
	var orbit_tw := vortex_root.create_tween().set_loops()
	orbit_tw.tween_property(vortex_root, "rotation:y", TAU, 5.0).as_relative()
	
	# 4. Top-Venting Smoke Wisps (Rising and dissipating from dome apex)
	for w in range(3):
		var wisp := MeshInstance3D.new()
		wisp.name = "TopVentingWisp_%d" % w
		var w_sph := SphereMesh.new()
		w_sph.radius = radius * 0.14
		w_sph.height = radius * 0.28
		w_sph.radial_segments = 6
		wisp.mesh = w_sph
		wisp.material_override = billow_mat
		wisp.position = Vector3(randf_range(-0.4, 0.4), dome_height * 0.85, randf_range(-0.4, 0.4))
		root.add_child(wisp)
		
		var w_tw := wisp.create_tween().set_loops()
		w_tw.tween_property(wisp, "position:y", dome_height * 1.35, 1.4 + float(w) * 0.3)
		w_tw.parallel().tween_property(wisp, "scale", Vector3(1.8, 1.8, 1.8), 1.4 + float(w) * 0.3)
		w_tw.tween_callback(func():
			wisp.position.y = dome_height * 0.85
			wisp.scale = Vector3.ONE
		)
	
	# 5. Tactical Hazard Area3D
	var area := Area3D.new()
	area.name = "GasHazardArea"
	area.collision_layer = 0
	area.collision_mask = 4 # Police layer
	var cs := CollisionShape3D.new()
	var col_sph := SphereShape3D.new()
	col_sph.radius = radius
	cs.shape = col_sph
	area.add_child(cs)
	root.add_child(area)
	
	area.body_entered.connect(func(body: Node3D):
		if body is RigidBody3D and body.get_parent() is PoliceCar:
			var pc := body.get_parent() as PoliceCar
			if pc and not pc.is_wrecked:
				if pc.car_pivot:
					pc.car_pivot.rotation.y += randf_range(-1.6, 1.6)
				if pc.physics_sphere:
					pc.physics_sphere.linear_velocity *= 0.45
				if hazard_type == "toxic" or hazard_type == "sand":
					pc.take_damage(20.0)
	)
	
	# 6. Smooth Lifecycle Cleanup (Shrink and fade at 72% duration)
	var clean_tw := root.create_tween()
	clean_tw.tween_interval(duration * 0.72)
	clean_tw.parallel().tween_property(dome_mat, "albedo_color:a", 0.0, duration * 0.28)
	clean_tw.parallel().tween_property(ring_mat, "albedo_color:a", 0.0, duration * 0.28)
	clean_tw.parallel().tween_property(billow_mat, "albedo_color:a", 0.0, duration * 0.28)
	clean_tw.parallel().tween_property(dome_mesh_inst, "scale", Vector3(1.05, 0.2, 1.05), duration * 0.28)
	clean_tw.chain().tween_callback(root.queue_free)
	
	return root

# -----------------------------------------------------------------------------
# CATEGORY B: 🧪 LIQUID / VISCOUS
# -----------------------------------------------------------------------------

## Spawns a Valorant-style organic liquid puddle with wet specular sheen,
## 12+ flying parabolic splatter droplets, simmering bubbles, and caustic rim glow.
static func spawn_liquid_puddle(parent: Node, origin: Vector3, config: Dictionary = {}) -> Node3D:
	if not parent or not is_instance_valid(parent):
		return null
	
	var col: Color = config.get("color", Color("1e272e")) # Default asphalt tar
	var radius: float = config.get("radius", 3.2)
	var duration: float = config.get("duration", 4.5)
	var is_boiling: bool = config.get("is_boiling", false)
	var viscosity_slow: float = config.get("viscosity_slow", 0.35)
	var damage_amount: float = config.get("damage_amount", 25.0)
	
	var root := Node3D.new()
	root.name = "ValorantLiquidPuddle"
	root.position = origin
	parent.add_child(root)
	
	# Liquid Material (Solid vibrant cel color with wet specular highlight)
	var liq_mat := StandardMaterial3D.new()
	liq_mat.albedo_color = Color(col.r, col.g, col.b, 1.0) # Solid saturated color
	liq_mat.roughness = 0.08
	liq_mat.metallic = 0.25
	liq_mat.rim_enabled = true # Crisp rim highlight
	liq_mat.rim = 1.0
	liq_mat.rim_tint = 0.8
	if is_boiling:
		liq_mat.emission_enabled = true
		liq_mat.emission = col * 0.6
		liq_mat.emission_energy_multiplier = 2.5
	
	# 1. Multi-Lobed Ground Puddle Disc Container (Organic silhouette instead of plain circle)
	var mesh_container := Node3D.new()
	mesh_container.name = "PuddleMeshContainer"
	root.add_child(mesh_container)
	
	# Crisp Highlight Border Ring (Valorant stylized contour highlight)
	var rim_highlight := MeshInstance3D.new()
	rim_highlight.name = "PuddleHighlightBorder"
	var r_torus := TorusMesh.new()
	r_torus.inner_radius = radius * 0.82
	r_torus.outer_radius = radius * 0.87
	r_torus.rings = 24
	r_torus.ring_segments = 6
	rim_highlight.mesh = r_torus
	var rh_mat := StandardMaterial3D.new()
	rh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rh_mat.albedo_color = Color.WHITE.lerp(col, 0.2)
	rh_mat.emission_enabled = true
	rh_mat.emission = Color.WHITE.lerp(col, 0.3)
	rh_mat.emission_energy_multiplier = 3.5
	rim_highlight.material_override = rh_mat
	rim_highlight.position.y = 0.04
	mesh_container.add_child(rim_highlight)
	
	var main_puddle := MeshInstance3D.new()
	main_puddle.name = "PuddleCenterDisc"
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.8
	cyl.bottom_radius = radius * 0.85
	cyl.height = 0.04
	cyl.radial_segments = 16
	main_puddle.mesh = cyl
	main_puddle.material_override = liq_mat
	main_puddle.position.y = 0.03
	mesh_container.add_child(main_puddle)
	
	# Add 4 offset lobe discs
	var lobe_offsets = [
		Vector3(radius * 0.4, 0.0, radius * 0.25),
		Vector3(-radius * 0.35, 0.0, radius * 0.35),
		Vector3(radius * 0.25, 0.0, -radius * 0.4),
		Vector3(-radius * 0.38, 0.0, -radius * 0.28)
	]
	for i in range(lobe_offsets.size()):
		var lobe := MeshInstance3D.new()
		lobe.name = "PuddleLobe_%d" % i
		var l_cyl := CylinderMesh.new()
		l_cyl.top_radius = radius * 0.45
		l_cyl.bottom_radius = radius * 0.48
		l_cyl.height = 0.038
		l_cyl.radial_segments = 12
		lobe.mesh = l_cyl
		lobe.material_override = liq_mat
		lobe.position = lobe_offsets[i] + Vector3(0.0, 0.03, 0.0)
		mesh_container.add_child(lobe)
	
	# Snappy expansion with spring overshoot
	mesh_container.scale = Vector3(0.1, 1.0, 0.1)
	var exp_tw := mesh_container.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	exp_tw.tween_property(mesh_container, "scale", Vector3.ONE, 0.25)
	
	# 2. Parabolic Splatter Droplets (Arcing into the air and splashing on pavement)
	var droplet_mat := StandardMaterial3D.new()
	droplet_mat.albedo_color = col
	droplet_mat.roughness = 0.05
	droplet_mat.metallic = 0.3
	
	var drop_count: int = 14
	for d in range(drop_count):
		var drop := MeshInstance3D.new()
		drop.name = "FlyingDroplet_%d" % d
		var d_sph := SphereMesh.new()
		d_sph.radius = randf_range(0.08, 0.16)
		d_sph.height = d_sph.radius * 2.0
		drop.mesh = d_sph
		drop.material_override = droplet_mat
		root.add_child(drop)
		
		var arc_angle: float = randf_range(0.0, TAU)
		var arc_dist: float = randf_range(radius * 0.6, radius * 1.3)
		var target_pos := Vector3(cos(arc_angle) * arc_dist, 0.04, sin(arc_angle) * arc_dist)
		var apex_height: float = randf_range(1.2, 2.4)
		
		drop.position = Vector3(0.0, 0.3, 0.0)
		var d_tw := drop.create_tween().set_trans(Tween.TRANS_QUAD)
		# Arc upward to apex then slam down to road
		d_tw.tween_property(drop, "position:y", apex_height, 0.22).set_ease(Tween.EASE_OUT)
		d_tw.parallel().tween_property(drop, "position:x", target_pos.x * 0.5, 0.22)
		d_tw.parallel().tween_property(drop, "position:z", target_pos.z * 0.5, 0.22)
		d_tw.chain().tween_property(drop, "position:y", 0.04, 0.20).set_ease(Tween.EASE_IN)
		d_tw.parallel().tween_property(drop, "position:x", target_pos.x, 0.20)
		d_tw.parallel().tween_property(drop, "position:z", target_pos.z, 0.20)
		# Flatten upon hitting pavement like a wet splash splatter
		d_tw.chain().tween_property(drop, "scale", Vector3(2.2, 0.2, 2.2), 0.1)
	
	# 3. Simmering Bubbles (Pop up and burst on liquid surface)
	for b in range(6):
		var bub := MeshInstance3D.new()
		bub.name = "LiquidBubble_%d" % b
		var b_sph := SphereMesh.new()
		b_sph.radius = randf_range(0.12, 0.22)
		b_sph.height = b_sph.radius * 1.5
		bub.mesh = b_sph
		bub.material_override = liq_mat
		var b_angle: float = randf_range(0.0, TAU)
		var b_dist: float = randf_range(0.2, radius * 0.65)
		bub.position = Vector3(cos(b_angle) * b_dist, 0.05, sin(b_angle) * b_dist)
		root.add_child(bub)
		
		# Swell and pop loop
		var b_tw := bub.create_tween().set_loops()
		bub.scale = Vector3.ZERO
		b_tw.tween_interval(float(b) * 0.25)
		b_tw.tween_property(bub, "scale", Vector3(1.3, 1.4, 1.3), 0.45).set_trans(Tween.TRANS_SINE)
		b_tw.tween_property(bub, "scale", Vector3.ZERO, 0.08)
	
	# 4. Tactical Area3D (Police slowdown, skid wobble, damage)
	var area := Area3D.new()
	area.name = "LiquidHazardArea"
	area.collision_layer = 0
	area.collision_mask = 4
	var cs := CollisionShape3D.new()
	var col_cyl := CylinderShape3D.new()
	col_cyl.radius = radius * 1.05
	col_cyl.height = 1.0
	cs.shape = col_cyl
	area.add_child(cs)
	root.add_child(area)
	
	area.body_entered.connect(func(body: Node3D):
		if body is RigidBody3D and body.get_parent() is PoliceCar:
			var pc := body.get_parent() as PoliceCar
			if pc and not pc.is_wrecked:
				pc.take_damage(damage_amount)
				if pc.physics_sphere:
					pc.physics_sphere.linear_velocity *= viscosity_slow
				if pc.car_pivot:
					pc.car_pivot.rotation.y += randf_range(-2.2, 2.2)
	)
	
	# 5. Lifecycle Tween
	var clean_tw := root.create_tween()
	clean_tw.tween_interval(duration * 0.75)
	clean_tw.parallel().tween_property(liq_mat, "albedo_color:a", 0.0, duration * 0.25)
	clean_tw.parallel().tween_property(mesh_container, "scale", Vector3(0.05, 1.0, 0.05), duration * 0.25)
	clean_tw.chain().tween_callback(root.queue_free)
	
	return root

## Spawns a Harbor-style directional curling water surge wave with frothy foam crest
## and high-velocity hydrodynamic push.
static func spawn_water_torrent(parent: Node, origin: Vector3, forward_dir: Vector3, config: Dictionary = {}) -> Node3D:
	if not parent or not is_instance_valid(parent):
		return null
	
	var length: float = config.get("length", 12.0)
	var width: float = config.get("width", 5.0)
	var impulse_power: float = config.get("impulse_power", 38.0)
	
	var root := Node3D.new()
	root.name = "ValorantWaterTorrent"
	root.position = origin
	parent.add_child(root)
	
	var norm_fwd := forward_dir.normalized()
	if norm_fwd.length_squared() > 0.01:
		root.look_at(origin + norm_fwd, Vector3.UP)
	
	# Water Body Material (Translucent bright aqua with Fresnel shine)
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.0, 0.82, 0.83, 0.82)
	water_mat.roughness = 0.04
	water_mat.metallic = 0.1
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.0, 0.6, 0.7) * 0.5
	
	# Foam Crest Material (Frothy white)
	var foam_mat := StandardMaterial3D.new()
	foam_mat.albedo_color = Color.WHITE
	foam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	# Crested Wave Mesh (Forward sweeping wedge)
	var wave := MeshInstance3D.new()
	wave.name = "CurlingWaveBody"
	var prism := PrismMesh.new()
	prism.size = Vector3(width, 1.8, length * 0.4)
	wave.mesh = prism
	wave.material_override = water_mat
	wave.rotation_degrees.x = -90.0 # Point crest forward
	wave.position = Vector3(0.0, 0.9, -1.0)
	root.add_child(wave)
	
	# White Foam Cap along crest
	var foam_cap := MeshInstance3D.new()
	foam_cap.name = "FoamCrestCap"
	var box := BoxMesh.new()
	box.size = Vector3(width * 1.05, 0.22, 0.35)
	foam_cap.mesh = box
	foam_cap.material_override = foam_mat
	foam_cap.position = Vector3(0.0, 1.8, -length * 0.2)
	root.add_child(foam_cap)
	
	# Sweep Forward Animation
	var tw := root.create_tween()
	tw.tween_property(root, "position", origin + norm_fwd * length, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(root, "scale", Vector3(1.4, 1.2, 1.0), 0.45)
	tw.chain().tween_property(water_mat, "albedo_color:a", 0.0, 0.2)
	tw.chain().tween_callback(root.queue_free)
	
	# Hydro Impulse Area
	var area := Area3D.new()
	area.name = "TorrentPushArea"
	area.collision_layer = 0
	area.collision_mask = 4
	var cs := CollisionShape3D.new()
	var col_box := BoxShape3D.new()
	col_box.size = Vector3(width, 2.5, length * 0.5)
	cs.shape = col_box
	area.add_child(cs)
	root.add_child(area)
	
	area.body_entered.connect(func(body: Node3D):
		if body is RigidBody3D and body.get_parent() is PoliceCar:
			var pc := body.get_parent() as PoliceCar
			if pc and not pc.is_wrecked:
				pc.take_damage(35.0)
				if pc.physics_sphere:
					var blast_dir: Vector3 = (norm_fwd + Vector3.UP * 0.45).normalized()
					pc.physics_sphere.apply_central_impulse(blast_dir * (impulse_power * pc.physics_sphere.mass))
	)
	
	return root

# -----------------------------------------------------------------------------
# CATEGORY C: 🧊 SOLID / CRYSTALLINE
# -----------------------------------------------------------------------------

## Spawns Breach-style snap-erupting jagged rock slabs along a fault line,
## with road fracture decals and crumbling shard physics.
static func spawn_earth_spikes_rupture(parent: Node, origin: Vector3, forward_dir: Vector3, config: Dictionary = {}) -> Node3D:
	if not parent or not is_instance_valid(parent):
		return null
	
	var count: int = config.get("count", 5)
	var spacing: float = config.get("spacing", 2.2)
	var max_height: float = config.get("max_height", 2.6)
	var damage: float = config.get("damage", 45.0)
	
	var root := Node3D.new()
	root.name = "ValorantEarthSpikesRupture"
	root.position = origin
	parent.add_child(root)
	
	var norm_fwd := forward_dir.normalized()
	
	# Dark Fractured Rock Material
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color("2d3436")
	rock_mat.roughness = 0.75
	rock_mat.rim_enabled = true
	rock_mat.rim = 0.95
	rock_mat.rim_tint = 0.6
	
	# Molten/Ember Ridge Highlight Material
	var ridge_mat := StandardMaterial3D.new()
	ridge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ridge_mat.albedo_color = Color("f39c12")
	ridge_mat.emission_enabled = true
	ridge_mat.emission = Color("f1c40f")
	ridge_mat.emission_energy_multiplier = 4.2
	
	# Erupting Spire Sequence
	for i in range(count):
		var spire_pos := norm_fwd * (float(i + 1) * spacing) + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
		var spire := MeshInstance3D.new()
		spire.name = "EarthSpire_%d" % i
		var p_mesh := PrismMesh.new()
		var s_width := randf_range(1.1, 1.6)
		var s_height := max_height * randf_range(0.8, 1.15)
		p_mesh.size = Vector3(s_width, s_height, s_width * 0.9)
		spire.mesh = p_mesh
		spire.material_override = rock_mat
		spire.position = spire_pos
		spire.rotation_degrees = Vector3(randf_range(-15, 15), randf_range(-180, 180), randf_range(-15, 15))
		
		# Glowing Ember Ridge Highlight along spire apex
		var ridge := MeshInstance3D.new()
		ridge.name = "SpireHighlightRidge_%d" % i
		var r_box := BoxMesh.new()
		r_box.size = Vector3(0.08, s_height * 0.92, 0.08)
		ridge.mesh = r_box
		ridge.material_override = ridge_mat
		ridge.position = Vector3(0.0, s_height * 0.05, s_width * 0.38)
		spire.add_child(ridge)
		
		root.add_child(spire)
		
		# Initial state: subterranean
		spire.position.y = -s_height * 0.6
		spire.scale = Vector3(0.2, 0.2, 0.2)
		
		# Snappy vertical thrust with staggered delay
		var s_tw := spire.create_tween()
		s_tw.tween_interval(float(i) * 0.065)
		s_tw.tween_property(spire, "position:y", s_height * 0.45, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		s_tw.parallel().tween_property(spire, "scale", Vector3.ONE, 0.09)
		
		# Crumble down after 2.8s
		s_tw.tween_interval(2.8)
		s_tw.tween_property(spire, "position:y", -s_height, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		s_tw.parallel().tween_property(spire, "scale", Vector3(0.1, 0.1, 0.1), 0.25)
	
	# Radial Road Fracture Decal beneath spires
	var crack_inst := MeshInstance3D.new()
	crack_inst.name = "AsphaltFractureDecal"
	var crack_box := BoxMesh.new()
	crack_box.size = Vector3(3.2, 0.04, float(count) * spacing + 1.5)
	crack_inst.mesh = crack_box
	var crack_mat := StandardMaterial3D.new()
	crack_mat.albedo_color = Color("1e272e")
	crack_mat.roughness = 0.95
	crack_inst.material_override = crack_mat
	crack_inst.position = norm_fwd * (float(count) * spacing * 0.5) + Vector3(0, 0.02, 0)
	if norm_fwd.length_squared() > 0.01:
		crack_inst.basis = Basis.looking_at(norm_fwd, Vector3.UP)
	
	# Molten Lava/Chalk Center Highlight Seam
	var seam := MeshInstance3D.new()
	seam.name = "FractureHighlightSeam"
	var s_box := BoxMesh.new()
	s_box.size = Vector3(0.24, 0.045, float(count) * spacing + 1.4)
	seam.mesh = s_box
	seam.material_override = ridge_mat
	seam.position.y = 0.01
	crack_inst.add_child(seam)
	
	root.add_child(crack_inst)
	
	# Heavy Impact Area
	var area := Area3D.new()
	area.name = "RuptureImpactArea"
	area.collision_layer = 0
	area.collision_mask = 4
	var cs := CollisionShape3D.new()
	var b_shape := BoxShape3D.new()
	b_shape.size = Vector3(4.0, 3.5, float(count) * spacing + 2.0)
	cs.shape = b_shape
	cs.position = crack_inst.position
	area.add_child(cs)
	root.add_child(area)
	
	area.body_entered.connect(func(body: Node3D):
		if body is RigidBody3D and body.get_parent() is PoliceCar:
			var pc := body.get_parent() as PoliceCar
			if pc and not pc.is_wrecked:
				pc.take_damage(damage)
				if pc.physics_sphere:
					var blast := (Vector3.UP * 1.2 + norm_fwd * 0.4).normalized()
					pc.physics_sphere.apply_central_impulse(blast * (38.0 * pc.physics_sphere.mass))
				if pc.car_pivot:
					pc.car_pivot.rotation.x += randf_range(-0.5, 0.5)
	)
	
	# Cleanup
	var root_tw := root.create_tween()
	root_tw.tween_interval(3.4)
	root_tw.tween_callback(root.queue_free)
	
	return root

## Spawns a Sage-style crystalline frost field with translucent diamond jade/ice prisms,
## ground frost lattice, and police tire freeze locking.
static func spawn_crystal_ice_field(parent: Node, origin: Vector3, config: Dictionary = {}) -> Node3D:
	if not parent or not is_instance_valid(parent):
		return null
	
	var radius: float = config.get("radius", 4.2)
	var duration: float = config.get("duration", 4.0)
	var spire_count: int = config.get("spire_count", 6)
	
	var root := Node3D.new()
	root.name = "ValorantCrystalIceField"
	root.position = origin
	parent.add_child(root)
	
	# Solid Jade/Ice Material (Solid vibrant teal with bright cyan rim emission)
	var ice_mat := StandardMaterial3D.new()
	ice_mat.albedo_color = Color(0.25, 0.88, 0.95, 0.96) # Solid vibrant color
	ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice_mat.roughness = 0.08
	ice_mat.metallic = 0.2
	ice_mat.emission_enabled = true
	ice_mat.emission = Color("00d2d3")
	ice_mat.emission_energy_multiplier = 2.4
	ice_mat.rim_enabled = true
	ice_mat.rim = 1.0
	ice_mat.rim_tint = 0.9
	
	# Crisp Glowing White Ridge Cap on each ice prism
	var cap_mat := StandardMaterial3D.new()
	cap_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cap_mat.albedo_color = Color.WHITE
	cap_mat.emission_enabled = true
	cap_mat.emission = Color.WHITE
	cap_mat.emission_energy_multiplier = 4.5
	
	# 1. Ground Frost Lattice Disc
	var lattice := MeshInstance3D.new()
	lattice.name = "GroundFrostLattice"
	var lat_cyl := CylinderMesh.new()
	lat_cyl.top_radius = radius
	lat_cyl.bottom_radius = radius * 1.02
	lat_cyl.height = 0.04
	lat_cyl.radial_segments = 18
	lattice.mesh = lat_cyl
	lattice.material_override = ice_mat
	lattice.position.y = 0.02
	root.add_child(lattice)
	
	lattice.scale = Vector3(0.1, 1.0, 0.1)
	var lat_tw := lattice.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lat_tw.tween_property(lattice, "scale", Vector3.ONE, 0.25)
	
	# 2. Faceted Diamond Ice Prisms
	for i in range(spire_count):
		var prism_inst := MeshInstance3D.new()
		prism_inst.name = "IcePrism_%d" % i
		var p_mesh := PrismMesh.new()
		var p_size := randf_range(0.8, 1.4)
		var p_height := randf_range(1.6, 2.8)
		p_mesh.size = Vector3(p_size, p_height, p_size)
		prism_inst.mesh = p_mesh
		prism_inst.material_override = ice_mat
		
		# Glowing White Crest Highlight Cap
		var cap := MeshInstance3D.new()
		cap.name = "PrismHighlightCap_%d" % i
		var c_mesh := PrismMesh.new()
		c_mesh.size = Vector3(p_size * 0.35, p_height * 0.25, p_size * 0.35)
		cap.mesh = c_mesh
		cap.material_override = cap_mat
		cap.position = Vector3(0, p_height * 0.42, 0)
		prism_inst.add_child(cap)
		
		var angle: float = (TAU / float(spire_count)) * float(i) + randf_range(-0.2, 0.2)
		var dist: float = randf_range(radius * 0.25, radius * 0.75)
		prism_inst.position = Vector3(cos(angle) * dist, -p_height * 0.4, sin(angle) * dist)
		prism_inst.rotation_degrees = Vector3(randf_range(-12, 12), randf_range(0, 360), randf_range(-12, 12))
		root.add_child(prism_inst)
		
		# Snap-erupt
		var p_tw := prism_inst.create_tween()
		p_tw.tween_interval(float(i) * 0.05)
		p_tw.tween_property(prism_inst, "position:y", p_height * 0.45, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		# Shatter scale pop on exit
		p_tw.tween_interval(duration * 0.75)
		p_tw.tween_property(prism_inst, "scale", Vector3(1.3, 0.2, 1.3), 0.15)
		p_tw.parallel().tween_property(prism_inst, "position:y", 0.0, 0.15)
	
	# 3. Freeze Hazard Area
	var area := Area3D.new()
	area.name = "FreezeHazardArea"
	area.collision_layer = 0
	area.collision_mask = 4
	var cs := CollisionShape3D.new()
	var col_cyl := CylinderShape3D.new()
	col_cyl.radius = radius
	col_cyl.height = 2.0
	cs.shape = col_cyl
	area.add_child(cs)
	root.add_child(area)
	
	area.body_entered.connect(func(body: Node3D):
		if body is RigidBody3D and body.get_parent() is PoliceCar:
			var pc := body.get_parent() as PoliceCar
			if pc and not pc.is_wrecked:
				pc.take_damage(20.0)
				if pc.physics_sphere:
					pc.physics_sphere.linear_velocity *= 0.15 # Severe frost brake
	)
	
	# Lifecycle
	var root_tw := root.create_tween()
	root_tw.tween_interval(duration * 0.8)
	root_tw.parallel().tween_property(ice_mat, "albedo_color:a", 0.0, duration * 0.2)
	root_tw.chain().tween_callback(root.queue_free)
	
	return root

# -----------------------------------------------------------------------------
# CATEGORY D: ⚡ ENERGY / PLASMA / VOID
# -----------------------------------------------------------------------------

## Spawns an Astra/Fade-style cosmic gravity singularity vortex with a rotating spiral
## accretion disc, event horizon corona, dark matter core, and inward attraction force.
static func spawn_void_singularity_vortex(parent: Node, origin: Vector3, config: Dictionary = {}) -> Node3D:
	if not parent or not is_instance_valid(parent):
		return null
	
	var radius: float = config.get("radius", 14.0)
	var duration: float = config.get("duration", 4.5)
	var pull_force: float = config.get("pull_force", 45.0)
	
	var root := Node3D.new()
	root.name = "ValorantSingularityVortex"
	root.position = origin
	parent.add_child(root)
	
	# 1. Dark Matter Singularity Core (Pitch black central sphere)
	var core := MeshInstance3D.new()
	core.name = "SingularityCore"
	var core_sph := SphereMesh.new()
	core_sph.radius = 1.2
	core_sph.height = 2.4
	core.mesh = core_sph
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color("050505")
	core_mat.roughness = 0.1
	core.material_override = core_mat
	core.position.y = 1.2
	root.add_child(core)
	
	# Core pulsating scale
	var c_tw := core.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	c_tw.tween_property(core, "scale", Vector3(1.2, 1.2, 1.2), 0.6)
	c_tw.tween_property(core, "scale", Vector3(0.9, 0.9, 0.9), 0.6)
	
	# 2. Glowing Event Horizon Perimeter Ring
	var horizon_ring := MeshInstance3D.new()
	horizon_ring.name = "EventHorizonRing"
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.96
	torus.outer_radius = radius * 1.04
	torus.rings = 24
	horizon_ring.mesh = torus
	var horizon_mat := StandardMaterial3D.new()
	horizon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	horizon_mat.albedo_color = Color("9b59b6")
	horizon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	horizon_mat.emission_enabled = true
	horizon_mat.emission = Color("e056fd")
	horizon_mat.emission_energy_multiplier = 4.0
	horizon_ring.material_override = horizon_mat
	horizon_ring.position.y = 0.05
	root.add_child(horizon_ring)
	
	# 3. Rotating Spiral Accretion Disc
	var accretion_disc := MeshInstance3D.new()
	accretion_disc.name = "AccretionDisc"
	var disc_cyl := CylinderMesh.new()
	disc_cyl.top_radius = radius * 0.75
	disc_cyl.bottom_radius = radius * 0.78
	disc_cyl.height = 0.03
	disc_cyl.radial_segments = 20
	accretion_disc.mesh = disc_cyl
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(0.3, 0.05, 0.45, 0.75)
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.emission_enabled = true
	disc_mat.emission = Color("8c7ae6")
	disc_mat.emission_energy_multiplier = 2.5
	accretion_disc.material_override = disc_mat
	accretion_disc.position.y = 0.08
	root.add_child(accretion_disc)
	
	# Rapid accretion spin
	var spin_tw := accretion_disc.create_tween().set_loops()
	spin_tw.tween_property(accretion_disc, "rotation:y", TAU, 1.8).as_relative()
	
	# 4. Inward-Spiraling Void Tendril Nodes
	for t in range(8):
		var tendril := MeshInstance3D.new()
		tendril.name = "VoidTendril_%d" % t
		var t_box := BoxMesh.new()
		t_box.size = Vector3(0.3, 0.3, 0.8)
		tendril.mesh = t_box
		tendril.material_override = horizon_mat
		root.add_child(tendril)
		
		var start_angle: float = (TAU / 8.0) * float(t)
		var t_tw := tendril.create_tween().set_loops()
		tendril.position = Vector3(cos(start_angle) * radius * 0.85, 0.4, sin(start_angle) * radius * 0.85)
		# Spiral inwards to core
		t_tw.tween_property(tendril, "position", Vector3(0, 1.2, 0), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t_tw.parallel().tween_property(tendril, "scale", Vector3(0.1, 0.1, 0.1), 1.2)
		t_tw.tween_callback(func():
			tendril.position = Vector3(cos(start_angle) * radius * 0.85, 0.4, sin(start_angle) * radius * 0.85)
			tendril.scale = Vector3.ONE
		)
	
	# 5. Continuous Gravitational Pull Area
	var area := Area3D.new()
	area.name = "GravitationalPullArea"
	area.collision_layer = 0
	area.collision_mask = 4
	var cs := CollisionShape3D.new()
	var pull_sph := SphereShape3D.new()
	pull_sph.radius = radius
	cs.shape = pull_sph
	area.add_child(cs)
	root.add_child(area)
	
	# Physics process pull
	var pull_timer := root.get_tree().create_timer(duration)
	var interval_timer := root.create_tween().set_loops()
	interval_timer.tween_callback(func():
		if not is_instance_valid(root): return
		var overlapping = area.get_overlapping_bodies()
		for body in overlapping:
			if body is RigidBody3D and body.get_parent() is PoliceCar:
				var pc := body.get_parent() as PoliceCar
				if pc and not pc.is_wrecked:
					var pull_dir: Vector3 = (root.global_position - pc.global_position).normalized()
					if pc.physics_sphere:
						pc.physics_sphere.apply_central_impulse(pull_dir * (pull_force * 0.15 * pc.physics_sphere.mass))
					pc.take_damage(8.0)
	)
	interval_timer.tween_interval(0.1)
	
	# Lifecycle
	var root_tw := root.create_tween()
	root_tw.tween_interval(duration * 0.85)
	root_tw.parallel().tween_property(horizon_mat, "albedo_color:a", 0.0, duration * 0.15)
	root_tw.parallel().tween_property(disc_mat, "albedo_color:a", 0.0, duration * 0.15)
	root_tw.parallel().tween_property(root, "scale", Vector3(0.05, 0.05, 0.05), duration * 0.15)
	root_tw.chain().tween_callback(root.queue_free)
	
	return root

## Spawns a Neon Fast Lane-style twin vertical laser curtain wall with scrolling
## holographic scanline emission and ground burn sparks.
static func spawn_laser_curtain_wall(parent: Node, origin: Vector3, forward_dir: Vector3, config: Dictionary = {}) -> Node3D:
	if not parent or not is_instance_valid(parent):
		return null
	
	var length: float = config.get("length", 14.0)
	var height: float = config.get("height", 2.4)
	var width_spacing: float = config.get("width_spacing", 3.2)
	var duration: float = config.get("duration", 4.0)
	var col: Color = config.get("color", Color("00d2d3"))
	
	var root := Node3D.new()
	root.name = "ValorantLaserCurtainWall"
	root.position = origin
	parent.add_child(root)
	
	var norm_fwd := forward_dir.normalized()
	if norm_fwd.length_squared() > 0.01:
		root.look_at(origin + norm_fwd, Vector3.UP)
	
	# Laser Hologram Material (Solid vibrant color with crisp white highlight core)
	var laser_mat := StandardMaterial3D.new()
	laser_mat.albedo_color = Color(col.r, col.g, col.b, 0.96)
	laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	laser_mat.emission_enabled = true
	laser_mat.emission = col
	laser_mat.emission_energy_multiplier = 4.8
	laser_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	var laser_core_mat := StandardMaterial3D.new()
	laser_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	laser_core_mat.albedo_color = Color.WHITE
	laser_core_mat.emission_enabled = true
	laser_core_mat.emission = Color.WHITE
	laser_core_mat.emission_energy_multiplier = 5.0
	
	# Twin Left and Right Laser Ribbons
	var sides = [-width_spacing * 0.5, width_spacing * 0.5]
	for s in range(sides.size()):
		var ribbon := MeshInstance3D.new()
		ribbon.name = "LaserRibbon_%d" % s
		var box := BoxMesh.new()
		box.size = Vector3(0.12, height, length)
		ribbon.mesh = box
		ribbon.material_override = laser_mat
		ribbon.position = Vector3(sides[s], height * 0.5, -length * 0.5)
		
		# White Core Highlight Stripe running horizontally down center
		var core_strip := MeshInstance3D.new()
		core_strip.name = "LaserCoreHighlightStrip_%d" % s
		var cs_box := BoxMesh.new()
		cs_box.size = Vector3(0.04, 0.24, length * 0.98)
		core_strip.mesh = cs_box
		core_strip.material_override = laser_core_mat
		core_strip.position = Vector3(0, 0, 0)
		ribbon.add_child(core_strip)
		
		root.add_child(ribbon)
		
		# Snappy vertical laser activation
		ribbon.scale = Vector3(1.0, 0.05, 1.0)
		var r_tw := ribbon.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		r_tw.tween_property(ribbon, "scale", Vector3.ONE, 0.22)
		
		# Scorched ground burn line
		var burn := MeshInstance3D.new()
		burn.name = "LaserBurnLine_%d" % s
		var b_box := BoxMesh.new()
		b_box.size = Vector3(0.4, 0.02, length)
		burn.mesh = b_box
		var burn_mat := StandardMaterial3D.new()
		burn_mat.albedo_color = Color("1e272e")
		burn_mat.emission_enabled = true
		burn_mat.emission = col * 0.4
		burn.material_override = burn_mat
		burn.position = Vector3(sides[s], 0.02, -length * 0.5)
		root.add_child(burn)
	
	# Laser Hazard Area
	var area := Area3D.new()
	area.name = "LaserBarrierArea"
	area.collision_layer = 0
	area.collision_mask = 4
	var cs := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(width_spacing + 1.0, height, length)
	cs.shape = wall_box
	cs.position = Vector3(0.0, height * 0.5, -length * 0.5)
	area.add_child(cs)
	root.add_child(area)
	
	area.body_entered.connect(func(body: Node3D):
		if body is RigidBody3D and body.get_parent() is PoliceCar:
			var pc := body.get_parent() as PoliceCar
			if pc and not pc.is_wrecked:
				pc.take_damage(45.0)
				if pc.physics_sphere:
					pc.physics_sphere.linear_velocity *= 0.35
				if pc.car_pivot:
					pc.car_pivot.rotation.y += randf_range(-1.5, 1.5)
	)
	
	# Lifecycle
	var root_tw := root.create_tween()
	root_tw.tween_interval(duration * 0.78)
	root_tw.parallel().tween_property(laser_mat, "albedo_color:a", 0.0, duration * 0.22)
	root_tw.chain().tween_callback(root.queue_free)
	
	return root

## Spawns a KAY/O-style EMP shockwave pulse with expanding concentric horizontal rings
## and digital tech crosshair brackets.
static func spawn_emp_shockwave_ring(parent: Node, origin: Vector3, config: Dictionary = {}) -> Node3D:
	if not parent or not is_instance_valid(parent):
		return null
	
	var radius: float = config.get("radius", 15.0)
	var col: Color = config.get("color", Color("00d2d3"))
	
	var root := Node3D.new()
	root.name = "ValorantEMPShockwave"
	root.position = origin
	parent.add_child(root)
	
	var emp_mat := StandardMaterial3D.new()
	emp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emp_mat.albedo_color = col
	emp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	emp_mat.emission_enabled = true
	emp_mat.emission = col
	emp_mat.emission_energy_multiplier = 4.0
	
	# Concentric Shockwave Rings
	for r in range(2):
		var ring := MeshInstance3D.new()
		ring.name = "EMPRing_%d" % r
		var torus := TorusMesh.new()
		torus.inner_radius = 0.8
		torus.outer_radius = 1.1
		torus.rings = 20
		ring.mesh = torus
		ring.material_override = emp_mat
		ring.position.y = 0.3 + float(r) * 0.2
		root.add_child(ring)
		
		ring.scale = Vector3(0.1, 1.0, 0.1)
		var r_tw := ring.create_tween()
		r_tw.tween_interval(float(r) * 0.08)
		r_tw.tween_property(ring, "scale", Vector3.ONE * radius, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		r_tw.parallel().tween_property(emp_mat, "albedo_color:a", 0.0, 0.42)
	
	# EMP Disruption Area
	var area := Area3D.new()
	area.name = "EMPDetectionArea"
	area.collision_layer = 0
	area.collision_mask = 4
	var cs := CollisionShape3D.new()
	var col_sph := SphereShape3D.new()
	col_sph.radius = radius
	cs.shape = col_sph
	area.add_child(cs)
	root.add_child(area)
	
	area.body_entered.connect(func(body: Node3D):
		if body is RigidBody3D and body.get_parent() is PoliceCar:
			var pc := body.get_parent() as PoliceCar
			if pc and not pc.is_wrecked:
				pc.take_damage(30.0)
				if pc.physics_sphere:
					pc.physics_sphere.linear_velocity *= 0.2
	)
	
	var clean_tw := root.create_tween()
	clean_tw.tween_interval(0.65)
	clean_tw.tween_callback(root.queue_free)
	
	return root

## Spawns a roaring draconic plasma flame jet with incandescent white-hot core,
## directional fire plumes, and ground burn molly trails.
static func spawn_dragon_flame_jet(parent: Node, origin: Vector3, forward_dir: Vector3, config: Dictionary = {}) -> Node3D:
	if not parent or not is_instance_valid(parent):
		return null
	
	var length: float = config.get("length", 15.0)
	var cone_angle: float = config.get("cone_angle", 0.45)
	var duration: float = config.get("duration", 3.5)
	
	var root := Node3D.new()
	root.name = "ValorantDragonFlameJet"
	root.position = origin
	parent.add_child(root)
	
	var norm_fwd := forward_dir.normalized()
	if norm_fwd.length_squared() > 0.01:
		root.look_at(origin + norm_fwd, Vector3.UP)
	
	# Incandescent Plasma Material (Solid saturated orange)
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_color = Color(1.0, 0.42, 0.05, 0.98) # Solid saturated
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.25, 0.05)
	flame_mat.emission_energy_multiplier = 4.2
	
	# Crisp White-Hot Core Highlight Material
	var core_flame_mat := StandardMaterial3D.new()
	core_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_flame_mat.albedo_color = Color.WHITE
	core_flame_mat.emission_enabled = true
	core_flame_mat.emission = Color(1.0, 0.95, 0.7)
	core_flame_mat.emission_energy_multiplier = 5.5
	
	# Expanding Directional Flame Plumes
	for i in range(8):
		var plume := MeshInstance3D.new()
		plume.name = "DragonFlamePlume_%d" % i
		var sph := SphereMesh.new()
		sph.radius = 0.6 + float(i) * 0.28
		sph.height = sph.radius * 2.0
		sph.radial_segments = 10
		plume.mesh = sph
		plume.material_override = flame_mat
		
		# White-Hot Inner Core Highlight
		var inner_core := MeshInstance3D.new()
		inner_core.name = "WhiteHotCore_%d" % i
		var core_sph := SphereMesh.new()
		core_sph.radius = sph.radius * 0.42
		core_sph.height = core_sph.radius * 2.0
		core_sph.radial_segments = 8
		inner_core.mesh = core_sph
		inner_core.material_override = core_flame_mat
		plume.add_child(inner_core)
		
		root.add_child(plume)
		
		var dist: float = float(i + 1) * (length / 8.0)
		var lateral_offset := randf_range(-dist * cone_angle * 0.4, dist * cone_angle * 0.4)
		var target_pos := Vector3(lateral_offset, 0.6 + float(i) * 0.18, -dist)
		
		plume.position = Vector3(0, 0.5, 0)
		plume.scale = Vector3(0.2, 0.2, 0.2)
		var p_tw := plume.create_tween()
		p_tw.tween_interval(float(i) * 0.035)
		p_tw.tween_property(plume, "position", target_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		p_tw.parallel().tween_property(plume, "scale", Vector3.ONE, 0.35)
		p_tw.tween_interval(duration * 0.6)
		p_tw.tween_property(flame_mat, "albedo_color:a", 0.0, 0.3)
	
	# Ground Burn Molly Trail at impact
	spawn_liquid_puddle(parent, origin + norm_fwd * (length * 0.6), {
		"color": Color(0.95, 0.25, 0.05),
		"radius": 4.5,
		"duration": duration,
		"is_boiling": true,
		"damage_amount": 35.0
	})
	
	# Flame Damage Area
	var area := Area3D.new()
	area.name = "DragonFlameArea"
	area.collision_layer = 0
	area.collision_mask = 4
	var cs := CollisionShape3D.new()
	var col_box := BoxShape3D.new()
	col_box.size = Vector3(length * 0.6, 3.0, length)
	cs.shape = col_box
	cs.position = Vector3(0, 1.5, -length * 0.5)
	area.add_child(cs)
	root.add_child(area)
	
	area.body_entered.connect(func(body: Node3D):
		if body is RigidBody3D and body.get_parent() is PoliceCar:
			var pc := body.get_parent() as PoliceCar
			if pc and not pc.is_wrecked:
				pc.take_damage(65.0)
				if pc.physics_sphere:
					var blast := (norm_fwd * 0.8 + Vector3.UP * 0.6).normalized()
					pc.physics_sphere.apply_central_impulse(blast * (42.0 * pc.physics_sphere.mass))
	)
	
	var clean_tw := root.create_tween()
	clean_tw.tween_interval(duration)
	clean_tw.tween_callback(root.queue_free)
	
	return root
