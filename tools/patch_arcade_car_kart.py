with open("scripts/vehicles/arcade_car.gd", "r", encoding="utf-8") as f:
    text = f.read()

# 1. Add kart mode state variables
var_target = "var is_punctured: bool = false"
var_replacement = """var is_punctured: bool = false
var is_in_kart_offroad: bool = false
var slipstream_timer: float = 0.0
var wrong_way_timer: float = 0.0"""

assert var_target in text, "var_target not found!"
text = text.replace(var_target, var_replacement, 1)

# 2. Update grass & off-road drag calculation
drag_target = """	var chunk_px: float = fposmod(car_pivot.global_position.x, 48.0)
	var chunk_pz: float = fposmod(car_pivot.global_position.z, 48.0)
	var is_on_road: bool = (chunk_px >= 16.5 and chunk_px <= 31.5) or (chunk_pz >= 16.5 and chunk_pz <= 31.5)
	is_on_grass = not is_on_road
	var grass_drag: float = 0.72 if is_on_grass else 1.0
	var puncture_drag: float = 0.60 if is_punctured else 1.0"""

drag_replacement = """	var grass_drag: float = 1.0
	var in_kart_mode: bool = has_node("/root/GameModeManager") and int(get_node("/root/GameModeManager").current_mode) == 4
	if in_kart_mode:
		var is_boosting: bool = drift_boost_time > 0.0 or (has_node("KartItemSystem") and get_node("KartItemSystem").is_gold_star_active())
		if is_boosting:
			grass_drag = 1.0
		elif is_in_kart_offroad:
			grass_drag = 0.62
	else:
		var chunk_px: float = fposmod(car_pivot.global_position.x, 48.0)
		var chunk_pz: float = fposmod(car_pivot.global_position.z, 48.0)
		var is_on_road: bool = (chunk_px >= 16.5 and chunk_px <= 31.5) or (chunk_pz >= 16.5 and chunk_pz <= 31.5)
		is_on_grass = not is_on_road
		grass_drag = 0.72 if is_on_grass else 1.0
	var puncture_drag: float = 0.60 if is_punctured else 1.0"""

assert drag_target in text, "drag_target not found!"
text = text.replace(drag_target, drag_replacement, 1)

# 3. Update drift stages to 3 stages (Stage 3: >= 2.5s -> Electric Purple, 1.75x)
drift_target = """		if drift_hold_time >= 1.75:
			if drift_charge_stage < 2:
				drift_charge_stage = 2
				_pulse_car_mesh()
			_set_drift_sparks(Color("ff9f43"), 2) # GOLDEN-ORANGE
		elif drift_hold_time >= 0.85:
			if drift_charge_stage < 1:
				drift_charge_stage = 1
			_set_drift_sparks(Color("00d2d3"), 1) # CYAN-BLUE"""

drift_replacement = """		if drift_hold_time >= 2.5:
			if drift_charge_stage < 3:
				drift_charge_stage = 3
				_pulse_car_mesh()
			_set_drift_sparks(Color("a55eea"), 3) # ELECTRIC PURPLE/MAGENTA
		elif drift_hold_time >= 1.75:
			if drift_charge_stage < 2:
				drift_charge_stage = 2
				_pulse_car_mesh()
			_set_drift_sparks(Color("ff9f43"), 2) # GOLDEN-ORANGE
		elif drift_hold_time >= 0.85:
			if drift_charge_stage < 1:
				drift_charge_stage = 1
			_set_drift_sparks(Color("00d2d3"), 1) # CYAN-BLUE"""

assert drift_target in text, "drift_target not found!"
text = text.replace(drift_target, drift_replacement, 1)

# 4. Update _trigger_drift_boost to handle stage 3
boost_target = """	if stage == 1:
		drift_boost_multiplier = 1.35
		drift_boost_time = 1.2 + bonus_dur
	else:
		drift_boost_multiplier = 1.65
		drift_boost_time = 2.0 + bonus_dur
		_trigger_drift_shockwave()"""

boost_replacement = """	if stage == 1:
		drift_boost_multiplier = 1.35
		drift_boost_time = 1.2 + bonus_dur
	elif stage == 2:
		drift_boost_multiplier = 1.65
		drift_boost_time = 2.0 + bonus_dur
		_trigger_drift_shockwave()
	else:
		# Stage 3 Ultra Mini-Turbo
		drift_boost_multiplier = 1.75
		drift_boost_time = 2.6 + bonus_dur
		_trigger_drift_shockwave()
		var hud = get_tree().root.find_child("TouchHUD", true, false)
		if hud and hud.has_method("spawn_floating_text"):
			hud.spawn_floating_text(car_pivot.global_position + Vector3.UP, "⚡ ULTRA MINI-TURBO!", Color("a55eea"), 1.3)"""

assert boost_target in text, "boost_target not found!"
text = text.replace(boost_target, boost_replacement, 1)

# 5. Add helper methods at bottom
helpers = """
## Kart Mode Helpers & Combat Actions
func apply_kart_boost(multiplier: float, duration: float) -> void:
	drift_boost_multiplier = multiplier
	drift_boost_time = duration
	_pulse_car_mesh()

func spin_out(duration: float = 1.3, speed_factor: float = 0.45) -> void:
	if has_node("KartItemSystem") and get_node("KartItemSystem").is_gold_star_active():
		return
	if physics_sphere:
		physics_sphere.linear_velocity *= speed_factor
	if car_pivot:
		var tw := create_tween()
		tw.tween_property(car_pivot, "rotation:y", car_pivot.rotation.y + TAU * 2.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_tire_screech"):
			sfx.play_tire_screech()

func blast_flip(is_plasma: bool = false) -> void:
	if has_node("KartItemSystem") and get_node("KartItemSystem").is_gold_star_active():
		return
	if physics_sphere:
		var up_force: float = 28.0 if is_plasma else 18.0
		physics_sphere.linear_velocity = Vector3(physics_sphere.linear_velocity.x * 0.2, up_force, physics_sphere.linear_velocity.z * 0.2)
	if car_pivot:
		var tw := create_tween()
		tw.tween_property(car_pivot, "rotation:x", car_pivot.rotation.x + TAU, 0.75)
	if has_node("/root/SoundFX"):
		var sfx = get_node("/root/SoundFX")
		if sfx.has_method("play_explosion"):
			sfx.play_explosion()
"""

text += helpers

with open("scripts/vehicles/arcade_car.gd", "w", encoding="utf-8", newline="\n") as f:
    f.write(text)

print("arcade_car.gd successfully updated for Kart GP!")
