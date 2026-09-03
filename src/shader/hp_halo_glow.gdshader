shader_type canvas_item;
render_mode blend_add;

// Health-driven brightness of the halo. Tween this from GDScript.
// Keep the low end above 0 — none of these should ever fully go dark.
uniform float intensity : hint_range(0.0, 3.0) = 1.0;

// How far the blur reaches, in UV units (0-1 across the node's own
// texture rect). Bigger node = bigger on-screen blur for the same value.
uniform float blur_radius : hint_range(0.0, 0.08) = 0.02;

// Color of the radiance itself — this is a real light color, not a tint
// of the source texture, so it's fine that this differs from the base
// sprite's colors.
uniform vec4 glow_tint : source_color = vec4(1.0, 0.85, 0.4, 1.0);

const int TAPS = 12;
const float PI2 = 6.28318530718;

void fragment() {
	vec4 accum = texture(TEXTURE, UV);
	float total_weight = 1.0;

	for (int i = 0; i < TAPS; i++) {
		float angle = (float(i) / float(TAPS)) * PI2;
		vec2 dir = vec2(cos(angle), sin(angle));

		vec4 s1 = texture(TEXTURE, UV + dir * blur_radius * 0.33);
		vec4 s2 = texture(TEXTURE, UV + dir * blur_radius * 0.66);
		vec4 s3 = texture(TEXTURE, UV + dir * blur_radius);

		accum += s1 * 0.6 + s2 * 0.35 + s3 * 0.2;
		total_weight += 0.6 + 0.35 + 0.2;
	}

	// Alpha of the blurred sample = the "vague shape" mask, softer and
	// bigger than the source silhouette.
	float mask = accum.a / total_weight;

	COLOR = vec4(glow_tint.rgb, mask * glow_tint.a * intensity);
}
