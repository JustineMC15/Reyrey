shader_type canvas_item;

uniform float health_ratio : hint_range(0.0, 1.0) = 1.0;

uniform vec4 glow_color : source_color = vec4(1.0, 0.90, 0.62, 1.0);

uniform float max_glow_strength : hint_range(0.0, 3.0) = 1.0;
uniform float min_glow_strength : hint_range(0.0, 3.0) = 0.02;

uniform float glow_radius : hint_range(1.0, 30.0) = 14.0;

uniform float inner_weight : hint_range(0.0, 2.0) = 0.90;
uniform float middle_weight : hint_range(0.0, 2.0) = 0.55;
uniform float outer_weight : hint_range(0.0, 2.0) = 0.20;

uniform float glow_falloff : hint_range(0.5, 5.0) = 1.35;


void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE;

	float source_alpha = texture(
		TEXTURE,
		UV
	).a;


	// =================================================
	// INNER HALO
	// =================================================
	//
	// Dense samples close to the star.
	// This establishes the recognizable star-shaped
	// glow immediately around the arms.
	//

	float inner = 0.0;

	float inner_radius = glow_radius * 0.20;

	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 offset = vec2(float(x), float(y));

			float distance_weight = 1.0 - (
				length(offset) / 3.0
			);

			distance_weight = max(
				distance_weight,
				0.0
			);

			inner += texture(
				TEXTURE,
				UV + offset * texel * inner_radius
			).a * distance_weight;
		}
	}

	inner /= 13.5;


	// =================================================
	// MIDDLE HALO
	// =================================================
	//
	// Wider blur that keeps the silhouette influence
	// but begins producing a soft atmospheric aura.
	//

	float middle = 0.0;

	float middle_radius = glow_radius * 0.50;

	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			vec2 offset = vec2(float(x), float(y));

			float distance_from_center = length(offset);

			float distance_weight = 1.0 - (
				distance_from_center / 4.5
			);

			distance_weight = max(
				distance_weight,
				0.0
			);

			middle += texture(
				TEXTURE,
				UV + offset * texel * middle_radius
			).a * distance_weight;
		}
	}

	middle /= 24.0;


	// =================================================
	// OUTER HALO
	// =================================================
	//
	// Broad, low-intensity blur.
	//
	// This is deliberately weak so the glow doesn't
	// become a visible second copy of the star.
	//

	float outer = 0.0;

	float outer_radius = glow_radius;

	for (int x = -4; x <= 4; x++) {
		for (int y = -4; y <= 4; y++) {
			vec2 offset = vec2(float(x), float(y));

			float distance_from_center = length(offset);

			float distance_weight = 1.0 - (
				distance_from_center / 6.0
			);

			distance_weight = max(
				distance_weight,
				0.0
			);

			outer += texture(
				TEXTURE,
				UV + offset * texel * outer_radius
			).a * distance_weight;
		}
	}

	outer /= 52.0;


	// =================================================
	// COMBINE THE HALOS
	// =================================================

	float glow =
		inner * inner_weight +
		middle * middle_weight +
		outer * outer_weight;


	// =================================================
	// REMOVE THE STAR ITSELF
	// =================================================
	//
	// HPStarGlow is behind the real HPStar.
	// We only want the surrounding light here.
	//

	glow *= 1.0 - source_alpha;


	// =================================================
	// SOFTEN THE COMPLETE RESULT
	// =================================================

	glow = clamp(
		glow,
		0.0,
		1.0
	);

	glow = pow(
		glow,
		glow_falloff
	);


	// =================================================
	// HP-BASED INTENSITY
	// =================================================

	float strength = mix(
		min_glow_strength,
		max_glow_strength,
		health_ratio
	);


	float final_alpha = glow * strength;


	// =================================================
	// FINAL COLOR
	// =================================================

	COLOR = vec4(
		glow_color.rgb,
		final_alpha
	);
}