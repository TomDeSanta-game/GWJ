shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.75, 0.25, 0.1, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.35, 0.1, 0.05, 1.0);
uniform float noise_scale = 10.0;
uniform float glow_power = 1.5;

void fragment() {
    vec2 uv = UV;
    
    vec4 gradient = mix(top_color, bottom_color, uv.y);
    
    float noise = fract(sin(dot(uv * noise_scale, vec2(12.9898, 78.233))) * 43758.5453) * 0.1;
    gradient.rgb += vec3(noise) * vec3(0.3, 0.1, 0.05);
    
    float noise2 = fract(sin(dot(uv * noise_scale * 2.0, vec2(35.9898, 28.233))) * 13758.5453) * 0.05;
    gradient.rgb += vec3(noise2) * vec3(0.3, 0.1, 0.03);
    
    vec3 warm_noise = vec3(noise + noise2) * vec3(0.3, 0.1, 0.05);
    gradient.rgb += warm_noise * 0.5;
    
    float center_glow = 1.0 - length(uv - vec2(0.5, 0.5)) * 1.2;
    center_glow = max(0.0, pow(center_glow, glow_power));
    gradient.rgb += vec3(center_glow) * vec3(0.2, 0.1, 0.05);
    
    float vignette = 1.0 - length(uv - vec2(0.5, 0.5));
    vignette = smoothstep(0.0, 0.5, vignette);
    gradient.rgb = mix(gradient.rgb * 0.8, gradient.rgb, vignette);
    
    COLOR = gradient;
} 