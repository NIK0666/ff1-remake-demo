shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx, shadows_disabled;

uniform vec3 shallow_color : source_color = vec3(0.34, 0.53, 0.50);
uniform vec3 deep_color : source_color = vec3(0.08, 0.20, 0.26);
uniform vec3 foam_color : source_color = vec3(0.82, 0.89, 0.83);
uniform vec3 sky_tint : source_color = vec3(0.36, 0.48, 0.52);
uniform float wave_height = 0.11;
uniform float alpha_base = 0.94;
uniform float flow_speed = 0.34;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p = p * 2.03 + 8.4;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave_a = sin(world_pos.x * 0.65 + TIME * 0.9) * 0.5 + 0.5;
	float wave_b = sin(world_pos.z * 1.15 + TIME * 1.35 + 1.3) * 0.5 + 0.5;
	VERTEX.y += (wave_a * 0.55 + wave_b * 0.45 - 0.5) * wave_height * 2.0;
}

void fragment() {
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	float fresnel = pow(1.0 - clamp(dot(view_dir, vec3(0.0, 1.0, 0.0)), 0.0, 1.0), 2.6);
	float flow = fbm(world_pos.xz * 0.35 + vec2(TIME * flow_speed, TIME * flow_speed * 0.43));
	float ripple = fbm(world_pos.xz * 1.7 + vec2(-TIME * 0.5, TIME * 0.8));
	vec3 color = mix(deep_color, shallow_color, flow * 0.8 + 0.08);
	color = mix(color, sky_tint, fresnel * 0.42);
	color += foam_color * smoothstep(0.72, 0.9, ripple) * 0.08;
	ALBEDO = color;
	ALPHA = mix(alpha_base, 1.0, fresnel);
	ROUGHNESS = mix(0.52, 0.78, flow);
	METALLIC = 0.0;
	SPECULAR = 0.08;
	NORMAL = normalize(NORMAL + vec3(flow - 0.5, 0.0, ripple - 0.5) * 0.12);
}
