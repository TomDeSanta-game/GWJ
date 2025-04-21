shader_type canvas_item;

uniform vec2 direction = vec2(1.0, 0.0);
uniform float speed_scale = 0.1;
uniform vec4 color1 : source_color = vec4(0.0, 0.1, 0.2, 1.0);
uniform vec4 color2 : source_color = vec4(0.1, 0.3, 0.5, 1.0);
uniform float pattern_size = 32.0;
uniform float wave_amplitude = 0.1;
uniform float wave_frequency = 5.0;
uniform float wave_speed = 1.0;

float hex_pattern(vec2 p, float size) {
    p = abs(fract(p / size) - 0.5);
    return abs(max(p.x * 1.5 + p.y, p.y * 2.0) - 1.0);
}

void fragment() {
    // Moving coordinates
    vec2 moving_uv = UV + TIME * direction * speed_scale;
    
    // Apply wave distortion
    float wave = sin(moving_uv.x * wave_frequency + TIME * wave_speed) * wave_amplitude;
    moving_uv.y += wave;
    
    // Create pattern
    float pattern = hex_pattern(moving_uv, pattern_size / TEXTURE_PIXEL_SIZE.x);
    
    // Mix colors based on pattern
    vec4 color = mix(color1, color2, pattern);
    
    // Add subtle pulse
    float pulse = 0.5 + 0.5 * sin(TIME * 0.5);
    color = mix(color, color * 1.2, pulse * 0.1);
    
    COLOR = color;
} 