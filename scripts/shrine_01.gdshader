shader_type canvas_item;

uniform vec4 nebula_dark : source_color = vec4(0.025, 0.035, 0.09, 1.0);
uniform vec4 nebula_blue : source_color = vec4(0.10, 0.16, 0.35, 1.0);
uniform vec4 nebula_violet : source_color = vec4(0.16, 0.08, 0.28, 1.0);

uniform float animation_speed : hint_range(0.0, 2.0) = 0.12;
uniform float cloud_scale : hint_range(1.0, 20.0) = 5.0;
uniform float intensity : hint_range(0.0, 2.0) = 0.65;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    float t = TIME * animation_speed;

    // Horizontal flowing nebula.
    // Primarily driven by X so it doesn't create
    // obvious bands between vertically stacked tiles.
    float cloud1 = sin(
        UV.x * cloud_scale
        + sin(UV.x * 2.0 + t) * 1.5
        - t
    );

    float cloud2 = sin(
        UV.x * cloud_scale * 0.45
        + sin(UV.x * 1.5 - t * 0.5) * 2.0
        + t
    );

    float cloud = (cloud1 + cloud2) * 0.5;
    cloud = cloud * 0.5 + 0.5;

    cloud = smoothstep(0.2, 0.8, cloud);

    // Deep blue nebula
    vec3 nebula = mix(
        nebula_dark.rgb,
        nebula_blue.rgb,
        cloud
    );

    // Slight violet presence
    nebula = mix(
        nebula,
        nebula_violet.rgb,
        cloud * 0.3
    );

    // Apply to original wall texture
    vec3 result = mix(
        tex.rgb,
        tex.rgb * nebula,
        intensity
    );

    COLOR = vec4(result, tex.a);
}