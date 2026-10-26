shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 marble_light : source_color = vec3(0.43, 0.41, 0.38);
uniform vec3 marble_dark : source_color = vec3(0.24, 0.23, 0.23);
uniform vec3 vein_color : source_color = vec3(0.63, 0.55, 0.42);
uniform vec3 gold_inlay : source_color = vec3(0.47, 0.36, 0.19);
uniform float tile_size = 4.0;

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
	for (int i = 0; i < 5; i++) {
		v += vnoise(p) * a;
		p = p * 2.02 + vec2(9.2, 4.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float broad = fbm(p * 0.22);
	float veins = abs(fbm(p * 0.75 + vec2(13.0, 7.0)) - 0.5);
	veins = smoothstep(0.035, 0.0, veins);
	vec3 color = mix(marble_dark, marble_light, broad);
	color = mix(color, vein_color, veins * 0.5);
	color *= mix(0.94, 1.05, fbm(p * 2.3));

	vec2 tile_uv = abs(fract(p / tile_size) - 0.5);
	float seam = smoothstep(0.5, 0.485, max(tile_uv.x, tile_uv.y));
	color = mix(color, gold_inlay, (1.0 - seam) * 0.36);

	ALBEDO = color;
	ROUGHNESS = mix(0.42, 0.24, broad);
	METALLIC = 0.02;
	SPECULAR = 0.55;
}
