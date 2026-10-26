shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform float contrast : hint_range(0.5, 2.5) = 1.35;
uniform float vignette_intensity : hint_range(0.0, 1.5) = 0.65;
uniform float vignette_radius : hint_range(0.1, 1.5) = 0.85;
uniform float police_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed = 8.0;
uniform float time_val = 0.0;

void fragment() {
	vec4 screen_col = texture(screen_texture, SCREEN_UV);
	
	// 1. Gritty desaturated black-and-white conversion
	// ITU-R BT.709 luma weights
	float luma = dot(screen_col.rgb, vec3(0.2126, 0.7152, 0.0722));
	// Apply gritty S-curve / high-contrast boost
	float gritty = clamp((luma - 0.5) * contrast + 0.5, 0.0, 1.0);
	vec3 desat_col = mix(vec3(gritty), screen_col.rgb, saturation);
	
	// 2. Dark Vignette around edges
	vec2 center_delta = SCREEN_UV - vec2(0.5);
	float dist = length(center_delta);
	float vig = smoothstep(vignette_radius, vignette_radius * 0.35, dist);
	vec3 vignetted_col = mix(desat_col * (1.0 - vignette_intensity), desat_col, vig);
	
	// 3. Subtle alternating Red / Blue police light edge pulse
	float cur_time = time_val > 0.0 ? time_val : TIME;
	float pulse_cycle = sin(cur_time * pulse_speed);
	
	// Red glow on left/top-left edge, Blue glow on right/bottom-right edge
	float left_glow = smoothstep(0.40, 0.0, SCREEN_UV.x);
	float right_glow = smoothstep(0.60, 1.0, SCREEN_UV.x);
	
	vec3 red_color = vec3(0.95, 0.08, 0.08) * left_glow * max(0.0, pulse_cycle);
	vec3 blue_color = vec3(0.08, 0.40, 1.0) * right_glow * max(0.0, -pulse_cycle);
	
	// Focus pulse on vignette edge perimeter
	float edge_mask = smoothstep(0.30, 0.75, dist);
	vec3 police_light = (red_color + blue_color) * edge_mask * police_pulse;
	
	COLOR = vec4(vignetted_col + police_light, 1.0);
}
