# 1. Fix smashy_kart_mode.gd to add BrawlUITheme preload
with open("scripts/world/smashy_kart_mode.gd", "r", encoding="utf-8") as f:
    text = f.read()

target = 'const KartItemSystemScript = preload("res://scripts/vehicles/kart_item_system.gd")'
replacement = """const KartItemSystemScript = preload("res://scripts/vehicles/kart_item_system.gd")
const BrawlUITheme = preload("res://scripts/autoload/brawl_ui_theme.gd")"""

assert target in text, "target not found in smashy_kart_mode.gd"
text = text.replace(target, replacement, 1)

with open("scripts/world/smashy_kart_mode.gd", "w", encoding="utf-8", newline="\n") as f:
    f.write(text)
print("smashy_kart_mode.gd updated with BrawlUITheme!")

# 2. Fix kart_track_builder.gd for 780m scaling and add_child order
with open("scripts/world/kart_track_builder.gd", "r", encoding="utf-8") as f:
    t_text = f.read()

old_curve_build = """	for pt_data in raw_points:
		curve.add_point(pt_data["p"], pt_data["in"], pt_data["out"])
	
	# Close loop by adding first point
	curve.add_point(raw_points[0]["p"], raw_points[0]["in"], raw_points[0]["out"])
	
	track_path.curve = curve
	baked_length = curve.get_baked_length()
	print("KartTrackBuilder: Track generated with baked length %.1fm" % baked_length)"""

new_curve_build = """	for pt_data in raw_points:
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
	print("KartTrackBuilder: Track generated with baked length %.1fm" % baked_length)"""

assert old_curve_build in t_text, "old_curve_build not found"
t_text = t_text.replace(old_curve_build, new_curve_build, 1)

# Fix apron
old_apron = """		apron.global_position = apron_center
		add_child(apron)
		offroad_areas.append(apron)"""

new_apron = """		add_child(apron)
		apron.global_position = apron_center
		offroad_areas.append(apron)"""
assert old_apron in t_text, "old_apron not found"
t_text = t_text.replace(old_apron, new_apron, 1)

# Fix checkpoints
old_cp = """		# Align gate with track forward direction
		gate.global_position = pos + Vector3(0, 4.0, 0)
		if fwd.length_squared() > 0.01:
			gate.look_at(gate.global_position + fwd, Vector3.UP)
		
		add_child(gate)"""

new_cp = """		add_child(gate)
		gate.global_position = pos + Vector3(0, 4.0, 0)
		if fwd.length_squared() > 0.01:
			gate.look_at(gate.global_position + fwd, Vector3.UP)"""
assert old_cp in t_text, "old_cp not found"
t_text = t_text.replace(old_cp, new_cp, 1)

# Fix gantry
old_gantry = """	var gantry := Node3D.new()
	gantry.name = "StartFinishGantry"
	gantry.global_position = pos
	if fwd.length_squared() > 0.01:
		gantry.look_at(pos + fwd, Vector3.UP)
	add_child(gantry)"""

new_gantry = """	var gantry := Node3D.new()
	gantry.name = "StartFinishGantry"
	add_child(gantry)
	gantry.global_position = pos
	if fwd.length_squared() > 0.01:
		gantry.look_at(pos + fwd, Vector3.UP)"""
assert old_gantry in t_text, "old_gantry not found"
t_text = t_text.replace(old_gantry, new_gantry, 1)

# Fix boost pad
old_pad = """		pad.global_position = pos + Vector3(0, 0.05, 0)
		if fwd.length_squared() > 0.01:
			pad.look_at(pad.global_position + fwd, Vector3.UP)
		
		pad.body_entered.connect(func(body):
			_on_boost_pad_entered(body)
		)
		
		add_child(pad)"""

new_pad = """		add_child(pad)
		pad.global_position = pos + Vector3(0, 0.05, 0)
		if fwd.length_squared() > 0.01:
			pad.look_at(pad.global_position + fwd, Vector3.UP)
		
		pad.body_entered.connect(func(body):
			_on_boost_pad_entered(body)
		)"""
assert old_pad in t_text, "old_pad not found"
t_text = t_text.replace(old_pad, new_pad, 1)

# Fix pagoda
old_pagoda = """		var pagoda := Node3D.new()
		pagoda.name = "PagodaArch"
		pagoda.global_position = pos
		if fwd.length_squared() > 0.01:
			pagoda.look_at(pos + fwd, Vector3.UP)"""

new_pagoda = """		var pagoda := Node3D.new()
		pagoda.name = "PagodaArch"
		add_child(pagoda)
		pagoda.global_position = pos
		if fwd.length_squared() > 0.01:
			pagoda.look_at(pos + fwd, Vector3.UP)"""
assert old_pagoda in t_text, "old_pagoda not found"
t_text = t_text.replace(old_pagoda, new_pagoda, 1)

with open("scripts/world/kart_track_builder.gd", "w", encoding="utf-8", newline="\n") as f:
    f.write(t_text)
print("kart_track_builder.gd successfully updated with 780m scaling and add_child order!")
