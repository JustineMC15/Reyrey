shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float darkness : hint_range(0.0, 1.0) = 0.18;
uniform float contrast : hint_range(0.5, 2.0) = 1.15;
uniform float saturation : hint_range(0.0, 2.0) = 0.85;

uniform float shadow_strength : hint_range(0.0, 1.0) = 0.25;
uniform vec4 shadow_tint : source_color = vec4(0.82, 0.86, 1.0, 1.0);
uniform vec4 highlight_tint : source_color = vec4(1.0, 0.96, 0.86, 1.0);

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.20;
uniform float vignette_radius : hint_range(0.1, 1.0) = 0.70;

void fragment() {
    vec4 screen_color = texture(screen_texture, SCREEN_UV);

    vec3 color = screen_color.rgb;

    // Luminance.
    float luminance = dot(
        color,
        vec3(0.299, 0.587, 0.114)
    );

    // Slightly desaturate.
    color = mix(
        vec3(luminance),
        color,
        saturation
    );

    // Increase contrast.
    color = (color - 0.5) * contrast + 0.5;

    // Overall darkness.
    color *= 1.0 - darkness;

    // Cold shadows.
    float shadow_mask = 1.0 - smoothstep(
        0.15,
        0.65,
        luminance
    );

    color = mix(
        color,
        color * shadow_tint.rgb,
        shadow_mask * shadow_strength
    );

    // Slight warm tint on highlights.
    float highlight_mask = smoothstep(
        0.55,
        0.9,
        luminance
    );

    color = mix(
        color,
        color * highlight_tint.rgb,
        highlight_mask * 0.08
    );

    // Vignette.
    vec2 centered_uv = SCREEN_UV - vec2(0.5);
    float distance_from_center = length(centered_uv);

    float vignette = smoothstep(
        vignette_radius,
        vignette_radius - 0.25,
        distance_from_center
    );

    color *= mix(
        1.0 - vignette_strength,
        1.0,
        vignette
    );

    COLOR = vec4(
        clamp(color, 0.0, 1.0),
        screen_color.a
    );
}