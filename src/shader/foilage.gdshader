shader_type canvas_item;

uniform float wind_strength : hint_range(0.0, 1.0) = 0.25;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.3;
uniform float wind_frequency : hint_range(0.0, 10.0) = 4.0;

void vertex() {
    // Local position inside the tile.
    float height = UV.y;

    // World-ish position gives each tile a different phase.
    float tile_phase = VERTEX.x * 0.03 + VERTEX.y * 0.017;

    float wave = sin(
        TIME * wind_speed
        + height * wind_frequency
        + tile_phase
    );

    // Stronger movement toward the top of the plant.
    float bend = height * height;

    VERTEX.x += wave * wind_strength * bend * 20.0;
}