shader_type canvas_item;

uniform float vignette_strength = 0.55;
uniform float grain_strength = 0.018;
uniform float warmth = 0.035;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float radius = length(centered) * 1.42;
	float vig = smoothstep(0.46, 1.05, radius) * vignette_strength;
	float grain = (hash21(UV * vec2(1920.0, 1080.0) + TIME * 0.3) - 0.5) * grain_strength;
	vec3 tint = vec3(warmth, warmth * 0.55, 0.0);
	COLOR = vec4(tint + vec3(grain), vig);
}
