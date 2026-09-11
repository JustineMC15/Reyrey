shader_type canvas_item;
render_mode unshaded;

uniform vec3 fog_color : source_color = vec3(0.18, 0.42, 0.27);
uniform float fog_strength : hint_range(0.0, 5) = 0.18;
uniform float fog_speed : hint_range(0.0, 2.0) = 0.08;
uniform float fog_scale : hint_range(0.5, 10.0) = 2.2;

uniform vec3 fairy_color : source_color = vec3(1.0, 0.68, 0.20);
uniform float fairy_strength : hint_range(0.0, 10.0) = 1.0;
uniform float fairy_drift : hint_range(0.0, 150.0) = 70.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(
        mix(a, b, f.x),
        mix(c, d, f.x),
        f.y
    );
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;

    for (int i = 0; i < 5; i++) {
        value += noise(p) * amplitude;
        p = p * 2.03 + vec2(17.13, 9.71);
        amplitude *= 0.5;
    }

    return value;
}

vec2 rotate(vec2 p, float angle) {
    float s = sin(angle);
    float c = cos(angle);

    return vec2(
        p.x * c - p.y * s,
        p.x * s + p.y * c
    );
}

float fog_field(vec2 uv, float time) {
    vec2 p = uv - 0.5;

    p = rotate(p, -0.18);

    vec2 large_p = p * vec2(
        fog_scale * 2.0,
        fog_scale * 1.15
    );

    large_p += vec2(
        time * 0.16,
        time * 0.035
    );

    float large = fbm(large_p);

    vec2 medium_p = rotate(
        p * vec2(
            fog_scale * 4.0,
            fog_scale * 2.2
        ),
        0.31
    );

    medium_p += vec2(
        -time * 0.10,
        time * 0.025
    );

    float medium = fbm(medium_p);

    vec2 fine_p = rotate(
        p * vec2(
            fog_scale * 7.0,
            fog_scale * 3.8
        ),
        -0.42
    );

    fine_p += vec2(
        time * 0.055,
        -time * 0.018
    );

    float fine = fbm(fine_p);

    float density = large * 0.58;
    density += medium * 0.30;
    density += fine * 0.12;

    return density;
}

float fairy_light(vec2 uv, float id, vec2 viewport_size) {
    float seed_x = hash(vec2(id, 17.31));
    float seed_y = hash(vec2(id, 41.73));
    float seed_a = hash(vec2(id, 73.19));
    float seed_b = hash(vec2(id, 101.47));

    vec2 position = vec2(seed_x, seed_y);

    float motion_x =
        sin(TIME * (0.18 + seed_a * 0.16) + seed_b * 20.0) * 0.75 +
        sin(TIME * (0.07 + seed_b * 0.05) + seed_a * 30.0) * 0.25;

    float motion_y =
        cos(TIME * (0.14 + seed_b * 0.14) + seed_a * 24.0) * 0.75 +
        sin(TIME * (0.06 + seed_a * 0.05) + seed_b * 31.0) * 0.25;

    position.x += motion_x * fairy_drift / viewport_size.x;
    position.y += motion_y * fairy_drift / viewport_size.y;

    position = fract(position);

    vec2 pixel_distance = abs(
        (uv - position) * viewport_size
    );

    float core = 1.0 - smoothstep(
        0.0,
        1.0,
        length(pixel_distance / vec2(0.55, 1.0))
    );

    float glow = 1.0 - smoothstep(
        0.0,
        1.0,
        length(pixel_distance / vec2(2.0, 2.5))
    );

    float pulse = 0.78 + 0.22 * sin(
        TIME * (0.45 + seed_a * 0.65) +
        seed_b * 30.0
    );

    return (core + glow * 0.08) * pulse;
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 viewport_size = 1.0 / SCREEN_PIXEL_SIZE;

    float fog = fog_field(
        uv,
        TIME * fog_speed * 10.0
    );

    fog = fog * fog;

    fog = mix(
        0.0,
        fog,
        smoothstep(0.18, 0.82, fog)
    );

    fog *= fog_strength;

    float lower_atmosphere = smoothstep(
        0.0,
        0.85,
        uv.y
    );

    fog *= mix(
        0.45,
        1.0,
        lower_atmosphere
    );

    float lights = 0.0;

    for (int i = 0; i < 32; i++) {
        lights += fairy_light(
            uv,
            float(i),
            viewport_size
        );
    }

    lights *= fairy_strength;

    vec3 color = fog_color * fog;
    color += fairy_color * lights;

    COLOR = vec4(
        color,
        fog + lights
    );
}