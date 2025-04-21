shader_type canvas_item;

uniform vec4 color1 : source_color = vec4(0.1, 0.2, 0.3, 1.0);
uniform vec4 color2 : source_color = vec4(0.05, 0.05, 0.1, 1.0);
uniform float time_scale = 0.5;
uniform float wave_size = 10.0;
uniform float distortion = 0.1;
uniform float brightness = 0.8;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    float time = TIME * time_scale;
    
    vec2 moving_uv = uv + vec2(sin(time) * 0.01, cos(time) * 0.01);
    
    float wave = sin(moving_uv.x * wave_size + time) * sin(moving_uv.y * wave_size + time) * distortion;
    moving_uv += vec2(wave, wave);
    
    float pattern = sin(moving_uv.x * 20.0) * sin(moving_uv.y * 20.0);
    
    vec4 color = mix(color1, color2, pattern * 0.5 + 0.5);
    
    float pulse = sin(time) * 0.05 + 0.95;
    color.rgb *= (brightness + wave) * pulse;
    
    COLOR = color;
} 