shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 grass_dark : source_color = vec3(0.21, 0.32, 0.17);
uniform vec3 grass_mid : source_color = vec3(0.34, 0.45, 0.23);
uniform vec3 grass_light : source_color = vec3(0.49, 0.56, 0.31);
uniform vec3 earth : source_color = vec3(0.36, 0.31, 0.22);
uniform float scale = 3.2;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(127.31, 311.7));
	p += dot(p, p + 24.51);
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
	for (int i = 0; i < 5; i++) {
		v += vnoise(p) * a;
		p = p * 2.01 + vec2(11.3, 5.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float broad = fbm(p * 0.08);
	float detail = fbm(p * 0.8 + vec2(8.0, 2.0));
	float blades = fbm(p * 7.0 + vec2(-5.0, 3.0));
	float wear = smoothstep(0.55, 0.85, fbm(p * 0.18 + 31.0));

	vec3 color = mix(grass_dark, grass_mid, broad * 0.8 + 0.2);
	color = mix(color, grass_light, smoothstep(0.45, 0.82, detail) * 0.55);
	color = mix(color, earth, wear * 0.28);
	color *= mix(0.88, 1.06, blades);
	float flowers = smoothstep(0.87, 0.97, fbm(p * 1.4 + 72.0));
	color = mix(color, vec3(0.88, 0.81, 0.55), flowers * 0.22);

	ALBEDO = color;
	ROUGHNESS = 0.97;
	SPECULAR = 0.12;
}
