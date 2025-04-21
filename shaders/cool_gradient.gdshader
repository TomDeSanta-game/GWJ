shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.05, 0.15, 0.35, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.15, 0.05, 0.25, 1.0);
uniform float wave_speed = 0.1;
uniform float wave_amplitude = 0.05;
uniform float wave_frequency = 2.0;

// Shape functions
float circle(vec2 uv, vec2 pos, float size) {
    return 1.0 - smoothstep(size - 0.01, size + 0.01, length(uv - pos));
}

float triangle(vec2 uv, vec2 pos, float size) {
    vec2 q = abs(uv - pos) - size;
    return max(q.x * 0.866025 + q.y * 0.5, -q.y);
}

float square(vec2 uv, vec2 pos, float size) {
    vec2 d = abs(uv - pos) - size;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void fragment() {
    // Create a moving gradient
    float wave = sin(UV.x * wave_frequency * 10.0 + TIME * wave_speed) * wave_amplitude;
    vec2 distorted_uv = vec2(UV.x, UV.y + wave);
    
    // Gradient from top to bottom with waves
    vec4 gradient = mix(top_color, bottom_color, distorted_uv.y);
    
    // Add more energy with a subtle horizontal wave pattern
    float horizontal_wave = 0.03 * sin(UV.y * 20.0 + TIME * 0.2);
    gradient.rgb += vec3(horizontal_wave);
    
    // Add subtle shape patterns that move
    float time = TIME * 0.2;
    
    // Add subtle circles
    for (float i = 0.0; i < 3.0; i++) {
        vec2 pos = vec2(
            0.3 + 0.4 * sin(time * (0.2 + i * 0.1) + i * 1.5),
            0.3 + 0.4 * cos(time * (0.3 + i * 0.1) + i * 1.2)
        );
        float c = circle(UV, pos, 0.1 + 0.03 * sin(TIME + i));
        gradient.rgb += vec3(c * 0.03);
    }
    
    // Add subtle triangles
    for (float i = 0.0; i < 3.0; i++) {
        vec2 pos = vec2(
            0.7 + 0.2 * cos(time * (0.3 + i * 0.12) + i * 0.8),
            0.6 + 0.3 * sin(time * (0.2 + i * 0.1) + i * 0.9)
        );
        float t = 1.0 - smoothstep(0.0, 0.01, triangle(UV, pos, 0.08 + 0.02 * cos(TIME * 0.5 + i)));
        gradient.rgb += vec3(t * 0.04);
    }
    
    // Add subtle squares
    for (float i = 0.0; i < 2.0; i++) {
        vec2 pos = vec2(
            0.5 + 0.4 * sin(time * (0.2 + i * 0.1) + i * 2.0),
            0.5 + 0.4 * cos(time * (0.3 + i * 0.1) + i * 1.7)
        );
        float s = 1.0 - smoothstep(0.0, 0.01, square(UV, pos, 0.07 + 0.02 * sin(TIME * 0.3 + i)));
        gradient.rgb += vec3(s * 0.05);
    }
    
    // Add cannon-like light beams occasionally
    float beam = pow(sin(UV.y * 5.0 + TIME) * 0.5 + 0.5, 8.0) * pow(sin(TIME * 0.2) * 0.5 + 0.5, 4.0) * 0.1;
    gradient.rgb += vec3(beam);
    
    // Add vignette effect (darker corners)
    float vignette = smoothstep(0.5, 0.0, length(UV - vec2(0.5)) - 0.2);
    gradient.rgb *= 0.8 + 0.2 * vignette;
    
    COLOR = gradient;
} 