shader_type canvas_item;

// ---------- COSMIC COLOR ----------

uniform vec3 cosmic_color : source_color = vec3(0.08, 0.05, 0.20);
uniform float cosmic_strength : hint_range(0.0, 1.0) = 0.35;


// ---------- NEBULA ----------

uniform float nebula_strength : hint_range(0.0, 1.0) = 0.25;
uniform float nebula_scale : hint_range(1.0, 20.0) = 6.0;
uniform float nebula_speed : hint_range(0.0, 1.0) = 0.15;


// ---------- STARS ----------

uniform float star_density : hint_range(5.0, 150.0) = 45.0;
uniform float star_threshold : hint_range(0.9, 0.999) = 0.985;
uniform float star_brightness : hint_range(0.0, 3.0) = 0.8;
uniform float star_speed : hint_range(0.0, 3.0) = 0.8;


// ---------- DISTORTION ----------

uniform float distortion_strength : hint_range(0.0, 0.02) = 0.003;
uniform float distortion_speed : hint_range(0.0, 2.0) = 0.25;


// ---------- RANDOM HASH ----------

float hash(vec2 p) {
	return fract(
		sin(dot(p, vec2(127.1, 311.7))) * 43758.5453
	);
}


// ---------- MAIN ----------

void fragment() {

	// --------------------------------------------------
	// Base tile texture
	// --------------------------------------------------

	vec2 uv = UV;

	// Very subtle movement in the texture.
	// Keep this low so the terrain doesn't look like water.
	uv.x += sin(
		uv.y * 8.0 +
		TIME * distortion_speed
	) * distortion_strength;

	uv.y += cos(
		uv.x * 7.0 +
		TIME * distortion_speed
	) * distortion_strength;

	vec4 tex = texture(TEXTURE, uv);


	// --------------------------------------------------
	// Cosmic color
	// --------------------------------------------------

	tex.rgb = mix(
		tex.rgb,
		tex.rgb + cosmic_color,
		cosmic_strength
	);


	// --------------------------------------------------
	// Continuous screen-space coordinates
	// --------------------------------------------------

	vec2 screen_uv = SCREEN_UV;


	// --------------------------------------------------
	// Nebula
	// --------------------------------------------------

	float nebula = sin(
		screen_uv.x * nebula_scale +
		screen_uv.y * (nebula_scale * 0.7) +
		TIME * nebula_speed
	);

	nebula = nebula * 0.5 + 0.5;

	// Make the nebula less uniform.
	nebula *= 0.5 + 0.5 * sin(
		screen_uv.y * 11.0 -
		TIME * nebula_speed * 0.5
	);

	vec3 nebula_color = vec3(
		0.10,
		0.06,
		0.25
	);

	tex.rgb += nebula_color * nebula * nebula_strength;


	// --------------------------------------------------
	// Stars
	// --------------------------------------------------

	vec2 grid = floor(screen_uv * star_density);

	float random = hash(grid);

	// Only some grid cells become stars.
	float star = step(
		star_threshold,
		random
	);

	// Give every star its own twinkle timing.
	float twinkle = sin(
		TIME * star_speed +
		random * 40.0
	);

	twinkle = twinkle * 0.5 + 0.5;

	// Prevent stars from becoming completely invisible.
	twinkle = mix(
		0.35,
		1.0,
		twinkle
	);

	star *= twinkle;


	// Slightly blue-white stars.
	vec3 star_color = vec3(
		0.55,
		0.70,
		1.0
	);

	tex.rgb += star_color * star * star_brightness;


	// --------------------------------------------------
	// Output
	// --------------------------------------------------

	COLOR = tex;
}