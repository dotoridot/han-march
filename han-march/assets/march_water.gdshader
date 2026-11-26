shader_type spatial;
render_mode cull_disabled;
uniform vec4 deep_tint : source_color = vec4(0.3,0.4,0.4,1.0);
uniform float flow_phase;
void fragment() {
	float ripple = sin(UV.x * 125.0 + UV.y * 71.0 + flow_phase * 0.7);
	float current = sin(UV.y * 203.0 - UV.x * 46.0 - flow_phase * 0.45);
	float streak = smoothstep(1.0, 1.85, ripple + current);
	ALBEDO = deep_tint.rgb * (0.83 + streak * 0.24);
	ROUGHNESS = 0.68;
}
