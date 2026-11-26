shader_type spatial;
render_mode cull_disabled;
uniform vec3 rest_center;
uniform float exposure;
varying vec3 rest_position;
void vertex() {
	rest_position = VERTEX;
}
void fragment() {
	float grain = sin(rest_position.x*43.0+rest_position.y*27.0+rest_position.z*19.0);
	if (exposure > 0.008 && distance(rest_position,rest_center)/0.52+grain*0.09 < exposure - 0.07) {
		discard;
	}
	float mottling = sin(rest_position.x*22.0+rest_position.z*15.0)*sin(rest_position.y*31.0);
	vec3 bronze = mix(vec3(0.21,0.112,0.046),vec3(0.49,0.297,0.126),0.48+0.34*mottling);
	float patina = smoothstep(0.38,0.85,mottling+0.3*sin(rest_position.z*29.0));
	ALBEDO = mix(bronze,vec3(0.17,0.235,0.15),patina*0.61);
	METALLIC = 0.62;
	ROUGHNESS = 0.53+patina*0.19;
}
