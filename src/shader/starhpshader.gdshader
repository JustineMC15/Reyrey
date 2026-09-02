shader_type canvas_item;

uniform float health_ratio : hint_range(0.0, 1.0) = 1.0;

uniform vec4 high_health_color : source_color = vec4(1.0, 0.90, 0.50, 1.0);
uniform vec4 low_health_color : source_color = vec4(1.0, 0.70, 0.30, 1.0);

uniform float high_health_brightness : hint_range(0.0, 3.0) = 1.35;
uniform float low_health_brightness : hint_range(0.0, 3.0) = 0.85;

uniform float high_health_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float low_health_alpha : hint_range(0.0, 1.0) = 0.90;


void fragment() {
	vec4 texture_color = texture(TEXTURE, UV);

	float ratio = clamp(
		health_ratio,
		0.0,
		1.0
	);

	// High HP is the star's brightest state.
	// Low HP remains clearly luminous, but weaker.
	vec3 star_color = mix(
		low_health_color.rgb,
		high_health_color.rgb,
		ratio
	);

	float brightness = mix(
		low_health_brightness,
		high_health_brightness,
		ratio
	);

	float alpha = mix(
		low_health_alpha,
		high_health_alpha,
		ratio
	);

	star_color *= brightness;

	COLOR = vec4(
		star_color,
		texture_color.a * alpha
	);
}