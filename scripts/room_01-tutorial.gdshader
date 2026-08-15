shader_type canvas_item;

// Godot 4.7 CanvasItem hints
uniform float desaturation : hint_range(0.0, 1.0) = 0.65;
uniform float contrast : hint_range(0.0, 2.0) = 1.25;
uniform float darken : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_strength : hint_range(0.0, 2.0) = 1.0;
uniform float grain_amount : hint_range(0.0, 0.1) = 0.03;

// Fast GPU pseudo-random noise generator
float noise(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Grayscale / Desaturation
    float gray = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
    vec3 grim_color = mix(tex_color.rgb, vec3(gray), desaturation);
    
    // Contrast and Darkening
    grim_color = (grim_color - 0.5) * contrast + 0.5;
    grim_color -= vec3(darken);
    
    // Vignette calculation
    float uv_dist = distance(UV, vec2(0.5));
    float vignette = smoothstep(0.8, 0.2 * vignette_strength, uv_dist);
    grim_color *= vignette;
    
    // Godot 4.7 Dynamic Grain (utilizes TIME for constant movement)
    float grain = (noise(UV * TIME) - 0.5) * grain_amount;
    grim_color += vec3(grain);
    
    // Final output clamping (prevents breaking if HDR output mode is active)
    COLOR.rgb = max(grim_color, vec3(0.0));
    COLOR.a = tex_color.a;
}