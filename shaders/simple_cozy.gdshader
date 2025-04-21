shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.85, 0.6, 0.3, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.6, 0.4, 0.3, 1.0);
uniform float speed = 0.1;

void fragment() {
    // Base gradient - warm, cozy colors
    vec4 gradient = mix(top_color, bottom_color, UV.y);
    
    // Add gentle, warm noise
    float noise1 = sin(UV.x * 10.0 + TIME * speed) * sin(UV.y * 8.0 + TIME * speed * 0.8) * 0.02;
    float noise2 = sin(UV.x * 5.0 - TIME * speed * 0.7) * sin(UV.y * 7.0 - TIME * speed * 0.5) * 0.02;
    
    // Combine for subtle texture
    vec3 warm_glow = vec3(1.0, 0.8, 0.6) * (noise1 + noise2);
    gradient.rgb += warm_glow;
    
    // Add warm glow in center
    float center_glow = 1.0 - length(UV - vec2(0.5)) * 1.2;
    center_glow = max(0.0, center_glow);
    center_glow = pow(center_glow, 2.0) * 0.15;
    gradient.rgb += vec3(0.8, 0.5, 0.3) * center_glow;
    
    // Soft vignette
    float vignette = smoothstep(1.4, 0.2, length(UV - vec2(0.5)));
    gradient.rgb *= mix(vec3(1.0), vec3(0.9, 0.8, 0.7), vignette * 0.3);
    
    COLOR = gradient;
} 