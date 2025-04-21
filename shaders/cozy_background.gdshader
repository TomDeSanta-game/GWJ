shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.6, 0.4, 0.3, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.3, 0.2, 0.15, 1.0);
uniform float noise_scale = 8.0;
uniform float glow_strength = 0.2;

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
    vec2 uv = UV;
    
    vec4 gradient = mix(bottom_color, top_color, uv.y);
    
    float large_noise = noise(uv * noise_scale) * 0.5;
    float medium_noise = noise(uv * noise_scale * 2.0) * 0.3;
    float small_noise = noise(uv * noise_scale * 4.0) * 0.2;
    
    float combined_noise = large_noise + medium_noise + small_noise;
    combined_noise *= 0.15;
    
    gradient.rgb += combined_noise * vec3(0.6, 0.4, 0.2);
    
    float center_glow = 1.0 - length(uv - vec2(0.5, 0.6)) * 1.5;
    center_glow = max(0.0, center_glow);
    center_glow = pow(center_glow, 2.0) * glow_strength;
    
    gradient.rgb += vec3(0.6, 0.4, 0.2) * center_glow;
    
    float vignette = 1.0 - length(uv - vec2(0.5, 0.5));
    vignette = smoothstep(0.0, 0.7, vignette);
    
    gradient.rgb = mix(gradient.rgb * 0.85, gradient.rgb, vignette);
    
    COLOR = gradient;
} 