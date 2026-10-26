extends Node

## Global Brawl Stars UI Theme & Outlined Typography Factory
## Registered as Autoload "BrawlUITheme" in project.godot
## Provides high-contrast comic-styled typography, 3D slanted card styleboxes,
## and universal elastic button bounce animations with procedural tactile sound effects.

const COLOR_DEEP_BLACK: Color = Color("0d1117")
const COLOR_GOLD: Color = Color("f39c12")
const COLOR_YELLOW: Color = Color("fbc531")
const COLOR_BLUE: Color = Color("0984e3")
const COLOR_GREEN: Color = Color("44bd32")
const COLOR_PURPLE: Color = Color("8c7ae6")
const COLOR_RED: Color = Color("e84118")
const COLOR_CYAN: Color = Color("00d2d3")
const COLOR_DARK_CARD: Color = Color("1e272e")

## 1. Typography Helper — creates high-contrast comic outlined LabelSettings
static func make_label_settings(font_size: int, font_color: Color = Color.WHITE, outline_px: int = 8, shadow_offset_y: int = 4) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.font_color = font_color
	ls.outline_size = outline_px
	ls.outline_color = COLOR_DEEP_BLACK
	ls.shadow_size = 4
	ls.shadow_color = Color(0.0, 0.0, 0.0, 0.75)
	ls.shadow_offset = Vector2(2.0, float(shadow_offset_y))
	return ls

## 2. 3D Slanted Button StyleBox Helper
static func make_card_style(bg_color: Color, lip_color: Color = Color("0d1117"), skew_x: float = 0.06, corner_px: int = 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.skew = Vector2(skew_x, 0.0)
	sb.border_color = lip_color if lip_color != Color.TRANSPARENT else COLOR_DEEP_BLACK
	sb.border_width_left = 4
	sb.border_width_top = 4
	sb.border_width_right = 4
	sb.border_width_bottom = 10
	sb.corner_radius_top_left = corner_px
	sb.corner_radius_top_right = corner_px
	sb.corner_radius_bottom_left = corner_px
	sb.corner_radius_bottom_right = corner_px
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 16.0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0.0, 5.0)
	return sb

## Neumorphic / Tactile Soft UI Button StyleBox Helper
## Implements authentic soft UI neumorphism: dual directional soft illumination,
## smoothly blended relief borders, extruded elevation in normal/hover states,
## and sunken concave cavity in pressed state without harsh comic borders.
static func make_neumorphic_style(bg_color: Color, accent_color: Color = Color.WHITE, is_pressed: bool = false, corner_radius: int = 18, is_hover: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var base := bg_color
	
	if is_pressed:
		# Concave / Sunken Inset State: darker interior cavity, soft inner depression
		sb.bg_color = base.darkened(0.14)
		sb.border_blend = true
		sb.border_width_top = 2
		sb.border_width_left = 2
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = base.darkened(0.40)
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.20)
		sb.shadow_size = 2
		sb.shadow_offset = Vector2(1.0, 1.0)
		sb.content_margin_top = 16.0
		sb.content_margin_bottom = 12.0
	elif is_hover:
		# Elevated / Floating Hover State: amplified top-left illumination & soft deep shadow
		sb.bg_color = base.lightened(0.07)
		sb.border_blend = true
		sb.border_width_top = 2
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		var hi_col: Color = accent_color.lerp(Color.WHITE, 0.40) if accent_color != Color.WHITE else base.lightened(0.35)
		sb.border_color = hi_col
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
		sb.shadow_size = 14
		sb.shadow_offset = Vector2(4.0, 6.0)
		sb.content_margin_top = 13.0
		sb.content_margin_bottom = 15.0
	else:
		# Extruded / Raised Normal State: soft top-left directional highlight & bottom-right soft shadow
		sb.bg_color = base
		sb.border_blend = true
		sb.border_width_top = 2
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = base.lightened(0.24)
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(4.0, 5.0)
		sb.content_margin_top = 14.0
		sb.content_margin_bottom = 14.0
	
	sb.corner_radius_top_left = corner_radius
	sb.corner_radius_top_right = corner_radius
	sb.corner_radius_bottom_left = corner_radius
	sb.corner_radius_bottom_right = corner_radius
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	return sb

## Sci-Fi Dark Translucent Neon Card Style (Mockup side cards & containers)
static func make_neon_card_style(bg_color: Color = Color("081426eb"), border_color: Color = Color("00d2d3"), corner_px: int = 14, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.border_width_left = border_w
	sb.border_width_top = border_w
	sb.border_width_right = border_w
	sb.border_width_bottom = border_w
	sb.corner_radius_top_left = corner_px
	sb.corner_radius_top_right = corner_px
	sb.corner_radius_bottom_left = corner_px
	sb.corner_radius_bottom_right = corner_px
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	sb.shadow_color = border_color * Color(1.0, 1.0, 1.0, 0.25)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0.0, 2.0)
	return sb

## Convenience Capsule Helper for top bar status counters and pills
static func make_capsule_style(bg_color: Color = Color("06111f"), border_color: Color = Color("0084a8"), corner_px: int = 24) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = corner_px
	sb.corner_radius_top_right = corner_px
	sb.corner_radius_bottom_left = corner_px
	sb.corner_radius_bottom_right = corner_px
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	sb.shadow_size = 5
	return sb

## Convenience Pill Helper for status counters and badges
static func make_pill_style(bg_color: Color, border_color: Color = Color("0d1117"), skew_x: float = 0.04, corner_px: int = 20) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.skew = Vector2(skew_x, 0.0)
	sb.border_color = border_color
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 6
	sb.corner_radius_top_left = corner_px
	sb.corner_radius_top_right = corner_px
	sb.corner_radius_bottom_left = corner_px
	sb.corner_radius_bottom_right = corner_px
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 10.0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0.0, 3.0)
	return sb

## Active Glowing Tab Style (Neumorphic Extruded Amber/Gold Tab)
static func make_active_tab_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1e2736")
	sb.border_blend = true
	sb.border_color = Color("f39c12")
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	sb.shadow_color = Color("f39c12", 0.40)
	sb.shadow_size = 9
	sb.shadow_offset = Vector2(0.0, 3.0)
	return sb

## Inactive Tab Style (Recessed Neumorphic Surface)
static func make_inactive_tab_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0d152066")
	sb.border_blend = true
	sb.border_color = Color("1e2c3d55")
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 8.0
	return sb

## 3. Universal Elastic Button Animator (Tactile Neumorphic 3D styling + Mobile Touch Scaling)
static func attach_button_juice(btn: BaseButton, primary_color: Color) -> void:
	if not btn:
		return
	
	var normal_sb := make_neumorphic_style(primary_color, Color.WHITE, false, 18, false)
	var hover_sb := make_neumorphic_style(primary_color, Color.WHITE, false, 18, true)
	var pressed_sb := make_neumorphic_style(primary_color, Color.WHITE, true, 18, false)
	var disabled_sb := make_neumorphic_style(Color("3d4852"), Color("1e272e"), false, 18, false)
	
	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("focus", hover_sb)
	btn.add_theme_stylebox_override("disabled", disabled_sb)
	
	# Scale button bigger for comfortable mobile touch
	btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, 60.0)
	btn.custom_minimum_size.x = maxf(btn.custom_minimum_size.x, 64.0)
	
	btn.pivot_offset = btn.size * 0.5
	if not btn.resized.is_connected(_static_on_button_resized.bind(btn)):
		btn.resized.connect(_static_on_button_resized.bind(btn))
	
	# Connect elastic scale tweens and click audio
	btn.button_down.connect(func():
		var tw: Tween = btn.get_meta("__juice_tween", null) as Tween
		if tw and tw.is_valid():
			tw.kill()
		btn.pivot_offset = btn.size * 0.5
		tw = btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.07)
		btn.set_meta("__juice_tween", tw)
		
		var sfx = btn.get_node_or_null("/root/SoundFX")
		if sfx and sfx.has_method("play_ui_click"):
			sfx.play_ui_click()
	)
	
	btn.button_up.connect(func():
		var tw: Tween = btn.get_meta("__juice_tween", null) as Tween
		if tw and tw.is_valid():
			tw.kill()
		btn.pivot_offset = btn.size * 0.5
		tw = btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.09)
		tw.chain().tween_property(btn, "scale", Vector2.ONE, 0.09)
		btn.set_meta("__juice_tween", tw)
	)
	
	btn.mouse_exited.connect(func():
		if btn.scale != Vector2.ONE:
			var tw: Tween = btn.get_meta("__juice_tween", null) as Tween
			if tw and tw.is_valid():
				tw.kill()
			tw = btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2.ONE, 0.1)
			btn.set_meta("__juice_tween", tw)
	)

## 9-Slice Textured Button Styler with Procedural Fallback
## Loads high-res textured button assets (e.g. Nanobanana generated 3D arcade buttons)
## and constructs high-performance 9-slice StyleBoxTexture instances.
static func make_texture_stylebox(tex_path: String, margin_h: float = 60.0, margin_top: float = -1.0, margin_bottom: float = -1.0, modulate_col: Color = Color.WHITE) -> StyleBoxTexture:
	var tex: Texture2D = load_texture_safe(tex_path)
	if not tex:
		return null
	
	var m_top: float = margin_h if margin_top < 0.0 else margin_top
	var m_bottom: float = margin_h if margin_bottom < 0.0 else margin_bottom
	
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = margin_h
	sb.texture_margin_right = margin_h
	sb.texture_margin_top = m_top
	sb.texture_margin_bottom = m_bottom
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.modulate_color = modulate_col
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 16.0
	return sb

## Applies high-res 9-slice textured styling and elastic juice to an action button.
## If textures are missing on disk, automatically falls back to clean neumorphic styleboxes.
static func attach_textured_button_juice(btn: BaseButton, normal_path: String, fallback_color: Color = Color("2ecc71"), margin_h: float = 60.0, margin_top: float = -1.0, margin_bottom: float = -1.0) -> void:
	if not btn:
		return
	
	var normal_sb := make_texture_stylebox(normal_path, margin_h, margin_top, margin_bottom, Color.WHITE)
	if normal_sb:
		var hover_sb := make_texture_stylebox(normal_path, margin_h, margin_top, margin_bottom, Color(1.15, 1.15, 1.15))
		var pressed_sb := make_texture_stylebox(normal_path, margin_h, margin_top, margin_bottom, Color(0.82, 0.82, 0.82))
		var disabled_sb := make_texture_stylebox(normal_path, margin_h, margin_top, margin_bottom, Color(0.4, 0.4, 0.4, 0.6))
		
		btn.add_theme_stylebox_override("normal", normal_sb)
		btn.add_theme_stylebox_override("hover", hover_sb if hover_sb else normal_sb)
		btn.add_theme_stylebox_override("pressed", pressed_sb if pressed_sb else normal_sb)
		btn.add_theme_stylebox_override("focus", hover_sb if hover_sb else normal_sb)
		if disabled_sb:
			btn.add_theme_stylebox_override("disabled", disabled_sb)
		
		# Comic typography styling
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color(0.92, 0.92, 0.92))
		btn.add_theme_color_override("font_outline_color", Color("0f141e"))
		btn.add_theme_constant_override("outline_size", 6)
		
		# Ensure touch target size
		btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, 60.0)
		btn.custom_minimum_size.x = maxf(btn.custom_minimum_size.x, 64.0)
		
		btn.pivot_offset = btn.size * 0.5
		if not btn.resized.is_connected(_static_on_button_resized.bind(btn)):
			btn.resized.connect(_static_on_button_resized.bind(btn))
		
		# Elastic bounce tween
		btn.button_down.connect(func():
			var tw: Tween = btn.get_meta("__juice_tween", null) as Tween
			if tw and tw.is_valid():
				tw.kill()
			btn.pivot_offset = btn.size * 0.5
			tw = btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.07)
			btn.set_meta("__juice_tween", tw)
			
			var sfx = btn.get_node_or_null("/root/SoundFX")
			if sfx and sfx.has_method("play_ui_click"):
				sfx.play_ui_click()
		)
		btn.button_up.connect(func():
			var tw: Tween = btn.get_meta("__juice_tween", null) as Tween
			if tw and tw.is_valid():
				tw.kill()
			btn.pivot_offset = btn.size * 0.5
			tw = btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.09)
			tw.chain().tween_property(btn, "scale", Vector2.ONE, 0.09)
			btn.set_meta("__juice_tween", tw)
		)
		btn.mouse_exited.connect(func():
			if btn.scale != Vector2.ONE:
				var tw: Tween = btn.get_meta("__juice_tween", null) as Tween
				if tw and tw.is_valid():
					tw.kill()
				tw = btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(btn, "scale", Vector2.ONE, 0.1)
				btn.set_meta("__juice_tween", tw)
		)
	else:
		attach_button_juice(btn, fallback_color)

## 5. Modern Cute Cartoon Board & Candy 3D Button Helpers

static func make_cartoon_board_style(bg_color: Color = Color("0d1726f2"), border_color: Color = Color("f39c12"), corner_px: int = 28, border_w: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.border_width_left = border_w
	sb.border_width_top = border_w
	sb.border_width_right = border_w
	sb.border_width_bottom = border_w + 4
	sb.corner_radius_top_left = corner_px
	sb.corner_radius_top_right = corner_px
	sb.corner_radius_bottom_left = corner_px
	sb.corner_radius_bottom_right = corner_px
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 24.0
	sb.shadow_color = Color(0, 0, 0, 0.65)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0.0, 8.0)
	return sb

## Attaches a Modern Cute 3D Candy Button to any BaseButton
## color_type can be: "green", "yellow", "red", "blue", "purple"
static func attach_candy_button_juice(btn: BaseButton, color_type: String = "green") -> void:
	var tex_path := "res://assets/ui/btn_candy_%s.png" % color_type
	var fallback_col := Color("2ecc71")
	match color_type:
		"yellow": fallback_col = Color("f1c40f")
		"red": fallback_col = Color("ff4757")
		"blue": fallback_col = Color("0984e3")
		"purple": fallback_col = Color("8e44ad")
		"green": fallback_col = Color("2ecc71")
	
	# Blank 3D candy buttons are 384x120. Pill caps are 60px wide, top rim is 34px, bottom drop rim is 44px
	attach_textured_button_juice(btn, tex_path, fallback_col, 60.0, 34.0, 44.0)

## Attaches a cute circular 3D bubble button (with round texture & squash bounce)
static func attach_round_bubble_button(btn: BaseButton, tex_path: String, fallback_col: Color) -> void:
	if not btn:
		return
	btn.text = ""
	btn.custom_minimum_size = Vector2(56, 56)
	var tex: Texture2D = load_texture_safe(tex_path)
	if tex:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		btn.add_theme_stylebox_override("normal", sb)
		
		var hsb := StyleBoxTexture.new()
		hsb.texture = tex
		hsb.modulate_color = Color(1.15, 1.15, 1.15)
		hsb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		hsb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		btn.add_theme_stylebox_override("hover", hsb)
		
		var psb := StyleBoxTexture.new()
		psb.texture = tex
		psb.modulate_color = Color(0.85, 0.85, 0.85)
		psb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		psb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		btn.add_theme_stylebox_override("pressed", psb)
		btn.add_theme_stylebox_override("focus", hsb)
	else:
		attach_button_juice(btn, fallback_col)
	
	btn.pivot_offset = btn.size * 0.5
	if not btn.resized.is_connected(_static_on_button_resized.bind(btn)):
		btn.resized.connect(_static_on_button_resized.bind(btn))
	
	btn.button_down.connect(func():
		var tw := btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.88, 0.88), 0.06)
		var sfx = btn.get_node_or_null("/root/SoundFX")
		if sfx and sfx.has_method("play_ui_click"):
			sfx.play_ui_click()
	)
	btn.button_up.connect(func():
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.1)
		tw.chain().tween_property(btn, "scale", Vector2.ONE, 0.08)
	)

## Attaches a cute circular 3D close button (X)
static func attach_bubble_close_button(btn: BaseButton) -> void:
	attach_round_bubble_button(btn, "res://assets/ui/btn_round_close_x.png", Color("ff4757"))

## Attaches a cute circular 3D pause button (||)
static func attach_bubble_pause_button(btn: BaseButton) -> void:
	attach_round_bubble_button(btn, "res://assets/ui/btn_round_pause.png", Color("0984e3"))

## Arcade Secondary/Utility Button Styling (Tactile Neumorphic Dark Cyber Styling)
static func attach_arcade_button_juice(btn: BaseButton, accent_color: Color = Color("00d2d3")) -> void:
	if not btn:
		return
	var normal_sb := make_neumorphic_style(Color("101b2a"), accent_color, false, 16, false)
	var hover_sb := make_neumorphic_style(Color("162438"), accent_color, false, 16, true)
	var pressed_sb := make_neumorphic_style(Color("09101a"), accent_color, true, 16, false)
	var disabled_sb := make_neumorphic_style(Color("0a101ae0"), Color("1f2d3d"), false, 16, false)
	
	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("focus", hover_sb)
	btn.add_theme_stylebox_override("disabled", disabled_sb)
	
	# Scale button bigger for mobile touch
	btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, 56.0)
	btn.custom_minimum_size.x = maxf(btn.custom_minimum_size.x, 60.0)
	
	btn.pivot_offset = btn.size * 0.5
	if not btn.resized.is_connected(_static_on_button_resized.bind(btn)):
		btn.resized.connect(_static_on_button_resized.bind(btn))
	
	btn.mouse_entered.connect(func():
		var tw: Tween = btn.get_meta("__juice_tween", null) as Tween
		if tw and tw.is_valid():
			tw.kill()
		btn.pivot_offset = btn.size * 0.5
		tw = btn.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1)
		btn.set_meta("__juice_tween", tw)
	)
	
	btn.mouse_exited.connect(func():
		var tw: Tween = btn.get_meta("__juice_tween", null) as Tween
		if tw and tw.is_valid():
			tw.kill()
		btn.pivot_offset = btn.size * 0.5
		tw = btn.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.1)
		btn.set_meta("__juice_tween", tw)
	)
	
	btn.button_down.connect(func():
		var tw: Tween = btn.get_meta("__juice_tween", null) as Tween
		if tw and tw.is_valid():
			tw.kill()
		btn.pivot_offset = btn.size * 0.5
		tw = btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.06)
		btn.set_meta("__juice_tween", tw)
		var sfx = btn.get_node_or_null("/root/SoundFX")
		if sfx and sfx.has_method("play_ui_click"):
			sfx.play_ui_click()
	)
	
	btn.button_up.connect(func():
		var tw: Tween = btn.get_meta("__juice_tween", null) as Tween
		if tw and tw.is_valid():
			tw.kill()
		btn.pivot_offset = btn.size * 0.5
		tw = btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.08)
		tw.chain().tween_property(btn, "scale", Vector2.ONE, 0.08)
		btn.set_meta("__juice_tween", tw)
	)

static func _static_on_button_resized(btn: BaseButton) -> void:
	if is_instance_valid(btn):
		btn.pivot_offset = btn.size * 0.5

## Rarity Tier Card Styling (Common, Rare, Epic, Legendary, Mythic)
static func get_tier_color(tier: String) -> Color:
	match tier.to_upper():
		"COMMON": return Color("74b9ff")
		"RARE": return Color("00d2d3")
		"EPIC": return Color("a55eea")
		"LEGENDARY": return Color("f1c40f")
		"MYTHIC": return Color("ff4757")
		_: return Color("3498db")

static func make_tier_card_style(tier: String, is_selected: bool = false, corner_radius: int = 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var tier_up := tier.to_upper()
	
	match tier_up:
		"COMMON":
			sb.bg_color = Color("1c2838") if is_selected else Color("121b27")
			sb.border_color = Color("f1c40f") if is_selected else Color("475569")
			sb.shadow_color = Color("000000", 0.4)
			sb.shadow_size = 6
		"RARE":
			sb.bg_color = Color("0d3056") if is_selected else Color("081f38")
			sb.border_color = Color("f1c40f") if is_selected else Color("00d2d3")
			sb.shadow_color = Color("00d2d3", 0.5 if is_selected else 0.25)
			sb.shadow_size = 10
		"EPIC":
			sb.bg_color = Color("311252") if is_selected else Color("200938")
			sb.border_color = Color("f1c40f") if is_selected else Color("a55eea")
			sb.shadow_color = Color("a55eea", 0.55 if is_selected else 0.3)
			sb.shadow_size = 12
		"LEGENDARY":
			sb.bg_color = Color("422204") if is_selected else Color("2c1502")
			sb.border_color = Color("f1c40f") if is_selected else Color("f39c12")
			sb.shadow_color = Color("f1c40f", 0.65 if is_selected else 0.38)
			sb.shadow_size = 14
		"MYTHIC":
			sb.bg_color = Color("480d19") if is_selected else Color("2d060f")
			sb.border_color = Color("f1c40f") if is_selected else Color("ff4757")
			sb.shadow_color = Color("ff4757", 0.6 if is_selected else 0.35)
			sb.shadow_size = 14
		_:
			sb.bg_color = Color("142236") if is_selected else Color("0a1524")
			sb.border_color = Color("f1c40f") if is_selected else Color("00d2d3")
			sb.shadow_color = Color("00d2d3", 0.3)
			sb.shadow_size = 8
	
	sb.set_border_width_all(3 if is_selected else 2)
	sb.set_corner_radius_all(corner_radius)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb

## Safe Texture Loader that handles both imported resources and raw image files seamlessly
static func load_texture_safe(path: String) -> Texture2D:
	var global_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		var img := Image.load_from_file(global_path)
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	return null

## Triggers a bright arcade white damage flash on any Node3D character or vehicle
static func flash_white(node: Node3D, duration: float = 0.09) -> void:
	if not node or not is_instance_valid(node):
		return
	
	var white_mat := StandardMaterial3D.new()
	white_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white_mat.albedo_color = Color.WHITE
	
	var mesh_instances: Array[MeshInstance3D] = []
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var cur = stack.pop_back()
		if cur is MeshInstance3D:
			mesh_instances.append(cur as MeshInstance3D)
		for child in cur.get_children():
			stack.push_back(child)
	
	var orig_mats: Dictionary = {}
	for mi in mesh_instances:
		if is_instance_valid(mi):
			# If already flashing white, preserve its stored original material
			if mi.has_meta("__orig_mat"):
				orig_mats[mi] = mi.get_meta("__orig_mat")
			else:
				orig_mats[mi] = mi.material_override
				mi.set_meta("__orig_mat", mi.material_override)
			mi.material_override = white_mat
	
	var tree = node.get_tree()
	if tree:
		tree.create_timer(duration, true, false, true).timeout.connect(func():
			for mi in mesh_instances:
				if is_instance_valid(mi):
					var saved = orig_mats.get(mi, null)
					mi.material_override = saved
					if mi.has_meta("__orig_mat"):
						mi.remove_meta("__orig_mat")
		)

# ==============================================================================
# PROCEDURAL 3D TEXTURE GENERATORS (For 3D Stage & Models in Cars and Gear Tabs)
# ==============================================================================

static var _cached_carbon_tex: ImageTexture = null
static var _cached_hex_tex: ImageTexture = null
static var _cached_tech_panel_tex: ImageTexture = null
static var _cached_brushed_metal_tex: ImageTexture = null
static var _cached_tire_tread_tex: ImageTexture = null

## Generates a seamless 32x32 Carbon Fiber twill weave texture
static func get_carbon_fiber_texture() -> ImageTexture:
	if _cached_carbon_tex != null:
		return _cached_carbon_tex
	
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var col_dark := Color("14181f")
	var col_mid := Color("232932")
	var col_light := Color("38414e")
	
	for y in range(32):
		for x in range(32):
			var block_x := int(x / 4)
			var block_y := int(y / 4)
			var is_alt := (block_x + block_y) % 2 == 0
			var local_diag := (x % 4 + y % 4) % 2 == 0
			
			if is_alt:
				img.set_pixel(x, y, col_light if local_diag else col_mid)
			else:
				img.set_pixel(x, y, col_mid if local_diag else col_dark)
	
	_cached_carbon_tex = ImageTexture.create_from_image(img)
	return _cached_carbon_tex

## Generates a high-tech 64x64 Sci-Fi Hex/Circuit Grid texture
static func get_hex_grid_texture() -> ImageTexture:
	if _cached_hex_tex != null:
		return _cached_hex_tex
	
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var col_bg := Color("08111d")
	var col_line := Color("008da8")
	var col_glow := Color("00e5ff")
	var col_dot := Color("f1c40f")
	
	img.fill(col_bg)
	for y in range(64):
		for x in range(64):
			# 16px grid lines
			var on_grid := (x % 16 == 0) or (y % 16 == 0)
			# 8px inner subtle grid
			var on_sub := (x % 8 == 0) or (y % 8 == 0)
			# Diagonal tech chamfer
			var on_diag := ((x + y) % 16 == 0)
			
			if (x % 16 == 0) and (y % 16 == 0):
				img.set_pixel(x, y, col_dot) # Gold circuit junction
			elif on_grid:
				img.set_pixel(x, y, col_glow)
			elif on_sub and on_diag:
				img.set_pixel(x, y, col_line)
			elif on_sub:
				img.set_pixel(x, y, col_bg.lightened(0.12))
	
	_cached_hex_tex = ImageTexture.create_from_image(img)
	return _cached_hex_tex

## Generates a 64x64 Reinforced Titanium Tech Armor Plating texture
static func get_tech_panel_texture() -> ImageTexture:
	if _cached_tech_panel_tex != null:
		return _cached_tech_panel_tex
	
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var col_plate := Color("242d38")
	var col_seam := Color("0d1117")
	var col_bevel := Color("3d4b5c")
	var col_bolt := Color("bdc3c7")
	var col_bolt_rim := Color("1e272e")
	
	img.fill(col_plate)
	for y in range(64):
		for x in range(64):
			# Seams around outer borders and center cross
			var is_edge: bool = (x < 2 or x > 61 or y < 2 or y > 61)
			var is_center_seam: bool = (absi(x - 32) <= 1 or absi(y - 32) <= 1)
			
			if is_edge or is_center_seam:
				img.set_pixel(x, y, col_seam)
			elif (x == 2 or x == 34 or y == 2 or y == 34):
				img.set_pixel(x, y, col_bevel) # Bevel highlight on top/left
	
	# Add rivet bolts near corners of each sub-quadrant
	var bolt_positions: Array[Vector2i] = [
		Vector2i(6, 6), Vector2i(27, 6), Vector2i(6, 27), Vector2i(27, 27),
		Vector2i(37, 6), Vector2i(58, 6), Vector2i(37, 27), Vector2i(58, 27),
		Vector2i(6, 37), Vector2i(27, 37), Vector2i(6, 58), Vector2i(27, 58),
		Vector2i(37, 37), Vector2i(58, 37), Vector2i(37, 58), Vector2i(58, 58)
	]
	
	for bp in bolt_positions:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var px: int = bp.x + dx
				var py: int = bp.y + dy
				if px >= 0 and px < 64 and py >= 0 and py < 64:
					if dx == 0 and dy == 0:
						img.set_pixel(px, py, col_bolt)
					else:
						img.set_pixel(px, py, col_bolt_rim)
	
	_cached_tech_panel_tex = ImageTexture.create_from_image(img)
	return _cached_tech_panel_tex

## Generates a 64x64 Brushed Metal / Titanium texture with directional micro-grooves
static func get_brushed_metal_texture() -> ImageTexture:
	if _cached_brushed_metal_tex != null:
		return _cached_brushed_metal_tex
	
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var base_col := Color("404d5a")
	
	for y in range(64):
		var y_val := sin(float(y) * 1.8) * 0.08 + sin(float(y) * 4.3) * 0.04
		for x in range(64):
			var x_val := sin(float(x) * 0.3) * 0.02
			var grain: float = y_val + x_val
			var col := Color(
				clampf(base_col.r + grain, 0.0, 1.0),
				clampf(base_col.g + grain, 0.0, 1.0),
				clampf(base_col.b + grain * 1.1, 0.0, 1.0),
				1.0
			)
			img.set_pixel(x, y, col)
	
	_cached_brushed_metal_tex = ImageTexture.create_from_image(img)
	return _cached_brushed_metal_tex

## Generates a 32x32 Rubber Tire Chevron Tread texture
static func get_tire_tread_texture() -> ImageTexture:
	if _cached_tire_tread_tex != null:
		return _cached_tire_tread_tex
	
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var col_rubber := Color("23272e")
	var col_groove := Color("0a0c0e")
	var col_siping := Color("2f3540")
	
	img.fill(col_rubber)
	for y in range(32):
		for x in range(32):
			# Center circumferential groove
			if absi(x - 16) <= 1:
				img.set_pixel(x, y, col_groove)
				continue
			
			# Angled chevron blocks
			var dist_center: int = absi(x - 16)
			var angle_row: int = (y + dist_center) % 8
			if angle_row == 0:
				img.set_pixel(x, y, col_groove)
			elif angle_row == 4:
				img.set_pixel(x, y, col_siping)
	
	_cached_tire_tread_tex = ImageTexture.create_from_image(img)
	return _cached_tire_tread_tex



