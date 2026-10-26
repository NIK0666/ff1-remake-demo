shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 stone_dark : source_color = vec3(0.30, 0.28, 0.25);
uniform vec3 stone_mid : source_color = vec3(0.55, 0.51, 0.44);
uniform vec3 stone_light : source_color = vec3(0.68, 0.61, 0.50);
uniform vec3 mortar : source_color = vec3(0.21, 0.19, 0.17);
uniform vec3 moss : source_color = vec3(0.30, 0.34, 0.24);
uniform float stone_scale = 2.35;
uniform float mortar_width = 0.055;
uniform float roughness_base = 0.9;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	float n = hash21(p);
	return vec2(n, hash21(p + 19.19));
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
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += vnoise(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.4);
		amplitude *= 0.5;
	}
	return value;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * stone_scale;
	vec2 cell_id = floor(p);
	vec2 local = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 nearest_id = vec2(0.0);

	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 offset = hash22(cell_id + g);
			vec2 r = g + offset - local;
			float dist = dot(r, r);
			if (dist < d1) {
				d2 = d1;
				d1 = dist;
				nearest_id = cell_id + g;
			} else if (dist < d2) {
				d2 = dist;
			}
		}
	}

	float edge = sqrt(d2) - sqrt(d1);
	float stone = smoothstep(mortar_width, mortar_width + 0.075, edge);
	float grain = fbm(world_pos.xz * 3.3);
	float pebble = fbm(world_pos.xz * 18.0);
	float tone = mix(0.38, 0.82, hash21(nearest_id * 1.37 + 4.2));
	vec3 stone_color = mix(stone_dark, stone_mid, tone);
	stone_color = mix(stone_color, stone_light, smoothstep(0.58, 0.94, grain) * 0.42);
	stone_color *= mix(0.82, 1.12, pebble);
	vec3 color = mix(mortar, stone_color, stone);

	float mottling = smoothstep(0.55, 0.78, fbm(world_pos.xz * 0.42 + vec2(3.3, 7.1)));
	color = mix(color, moss, mottling * 0.12);
	float damp = smoothstep(0.57, 0.72, fbm(world_pos.xz * 0.24 + 13.0));
	color *= 1.0 - damp * 0.16;

	ALBEDO = color;
	ROUGHNESS = mix(roughness_base, 0.72, stone);
	SPECULAR = 0.28;
}
