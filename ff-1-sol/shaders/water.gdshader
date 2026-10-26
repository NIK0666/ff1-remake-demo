shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 deep_color : source_color;
uniform vec4 foam_color : source_color;
uniform float wave_scale;
uniform float wave_speed;
uniform float wave_threshold;
uniform float wave_slant;
uniform float wave_cross_scale;
uniform float wave_distortion;
uniform float streak_scale;
uniform float streak_speed;
uniform float zero;
uniform float unit;
varying vec2 water_position;
void vertex() {
	water_position = (MODEL_MATRIX * vec4(VERTEX, unit)).xz;
}
void fragment() {
	float wave = sin(water_position.x * wave_scale + water_position.y * wave_slant
		+ sin(water_position.y * wave_cross_scale + TIME * wave_speed) * wave_distortion
		+ TIME * wave_speed);
	float streak = smoothstep(wave_threshold, unit, wave)
		* smoothstep(zero, unit, sin(water_position.x * streak_scale + TIME * streak_speed));
	ALBEDO = mix(deep_color.rgb, foam_color.rgb, streak);
}
