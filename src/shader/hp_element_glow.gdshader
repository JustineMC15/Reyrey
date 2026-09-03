shader_type canvas_item;

// 1.0 = full health, 0.0 = empty. Drive this from GDScript with a tween,
// never set it instantly except at initial _ready().
uniform float health_ratio : hint_range(0.0, 1.0) = 1.0;

// How far the hue rotates by the time health hits 0. Gold sits around
// hue 45-50 deg, orange around hue 25-35 deg, so this should be negative.
uniform float max_hue_shift_deg : hint_range(-60.0, 0.0) = -18.0;

// Brightness floor at 0 health (fraction of original Value). Must stay
// above 0 so the element never truly goes black/loses its glow.
uniform float min_value_mult : hint_range(0.1, 1.0) = 0.65;

// Slight saturation boost as it goes orange, keeps it reading as "warm"
// instead of "washed out."
uniform float min_saturation_mult : hint_range(0.5, 2.0) = 1.1;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	if (tex.a <= 0.001) {
		COLOR = tex;
	} else {
		vec3 hsv = rgb2hsv(tex.rgb);

		float t = 1.0 - health_ratio;

		hsv.x = fract(hsv.x + (max_hue_shift_deg / 360.0) * t);
		hsv.y = clamp(hsv.y * mix(1.0, min_saturation_mult, t), 0.0, 1.0);
		hsv.z = hsv.z * mix(1.0, min_value_mult, t);

		COLOR = vec4(hsv2rgb(hsv), tex.a);
	}
}