shader_type canvas_item;

uniform float health_ratio : hint_range(0.0, 1.0) = 1.0;

uniform vec4 color_high : source_color = vec4(1.0, 1.0, 1.0, 0.35); // white translucent
uniform vec4 color_mid  : source_color = vec4(0.55, 0.55, 0.55, 0.35); // gray translucent
uniform vec4 color_low  : source_color = vec4(0.0, 0.0, 0.0, 0.45); // black translucent

// Ratio at/above which the track is fully "high" (white).
uniform float mid_point : hint_range(0.0, 1.0) = 0.5;
// Ratio at/below which the track is fully "low" (black).
uniform float low_point : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	if (tex.a <= 0.001) {
		COLOR = tex;
	} else {
		vec4 target;

		if (health_ratio >= mid_point) {
			target = color_high;
		} else if (health_ratio >= low_point) {
			float t = (health_ratio - low_point) / max(mid_point - low_point, 0.0001);
			target = mix(color_mid, color_high, t);
		} else {
			float t = health_ratio / max(low_point, 0.0001);
			target = mix(color_low, color_mid, t);
		}

		// The source art's own alpha falloff is kept as the mask; only the
		// RGB + overall translucency come from the target stop.
		COLOR = vec4(target.rgb, tex.a * target.a);
	}
}