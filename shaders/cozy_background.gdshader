shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.85, 0.6, 0.3, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.6, 0.4, 0.3, 1.0);
uniform float noise_scale = 5.0;
uniform float softness = 0.5;
uniform float time_scale = 0.1;

// Simple noise function
float noise(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

// Value noise
float value_noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    
    // Four corners
    float a = noise(i);
    float b = noise(i + vec2(1.0, 0.0));
    float c = noise(i + vec2(0.0, 1.0));
    float d = noise(i + vec2(1.0, 1.0));
    
    // Smooth interpolation
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
    // Base gradient
    vec4 gradient = mix(top_color, bottom_color, UV.y);
    
    // Add warm, gentle noise
    float time = TIME * time_scale;
    vec2 moving_uv = UV * noise_scale;
    moving_uv.x += sin(time * 0.2 + UV.y * 2.0) * 0.1;
    moving_uv.y += cos(time * 0.1 + UV.x * 2.0) * 0.1;
    
    // Layer of soft noise
    float noise1 = value_noise(moving_uv);
    float noise2 = value_noise(moving_uv * 2.0 + vec2(time * 0.05, 0.0));
    
    // Combine noises and make them subtle
    float combined_noise = mix(noise1, noise2, 0.5) * softness;
    
    // Add warm highlights to the gradient
    vec3 highlight = vec3(1.0, 0.8, 0.6) * combined_noise * 0.2;
    gradient.rgb += highlight;
    
    // Add a subtle warm glow in the center
    float center_glow = 1.0 - length(UV - vec2(0.5)) * 1.2;
    center_glow = max(0.0, center_glow);
    center_glow = smoothstep(0.0, 0.8, center_glow) * 0.3;
    gradient.rgb += vec3(0.9, 0.6, 0.3) * center_glow;
    
    // Add subtle, cozy vignette (warmer, not too dark)
    float vignette = smoothstep(0.5, 0.0, length(UV - vec2(0.5)) - 0.25);
    gradient.rgb = mix(gradient.rgb, gradient.rgb * vec3(0.8, 0.6, 0.5), vignette * 0.3);
    
    COLOR = gradient;
} 