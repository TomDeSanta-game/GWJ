shader_type canvas_item;

uniform vec4 moon_color : source_color = vec4(0.8, 0.8, 0.85, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.1, 0.1, 0.15, 1.0);
uniform vec4 star_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float crater_density = 0.8;
uniform float dust_amount = 0.15;
uniform float star_density = 100.0;

// Noise functions for various effects
float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 ip = floor(p);
    vec2 u = fract(p);
    u = u * u * (3.0 - 2.0 * u);
    
    float res = mix(
        mix(rand(ip), rand(ip + vec2(1.0, 0.0)), u.x),
        mix(rand(ip + vec2(0.0, 1.0)), rand(ip + vec2(1.0, 1.0)), u.x), u.y);
    return res * res;
}

void fragment() {
    // Base moon surface with noise
    vec2 uv = UV;
    
    // Create moon surface texture
    float large_noise = noise(uv * 2.0) * 0.5;
    float medium_noise = noise(uv * 8.0) * 0.3;
    float small_noise = noise(uv * 32.0) * 0.2;
    
    // Combine noise for lunar surface
    float surface_texture = large_noise + medium_noise + small_noise;
    
    // Create craters
    float crater_value = 0.0;
    for (float i = 1.0; i < 5.0; i++) {
        vec2 crater_pos = vec2(
            rand(vec2(i * 0.1, 0.0)) * 0.8 + 0.1,
            rand(vec2(0.0, i * 0.1)) * 0.8 + 0.1
        );
        float size = rand(vec2(i, i)) * 0.1 + 0.02;
        float dist = distance(uv, crater_pos);
        float crater_shape = smoothstep(size, size * 0.8, dist) * smoothstep(0.0, size * 0.3, dist);
        crater_value += crater_shape * crater_density;
    }
    
    // Starry background (for the sky)
    float stars = 0.0;
    if (uv.y < 0.5) { // Only show stars in the "sky" part
        for (float i = 1.0; i < 5.0; i++) {
            vec2 star_pos = vec2(
                rand(vec2(i, 0.0)) * 2.0, 
                rand(vec2(0.0, i)) * 0.5
            );
            float size = 0.002;
            float star = 1.0 - smoothstep(0.0, size, distance(uv, star_pos));
            stars += star * rand(star_pos);
        }
        stars *= step(0.98, rand(floor(uv * star_density)));
    }
    
    // Add horizon line
    float horizon = smoothstep(0.45, 0.55, uv.y);
    
    // Lunar dust effect
    float dust = noise(uv * 50.0 + TIME * vec2(0.01, 0.0)) * dust_amount;
    
    // Combine all effects
    vec4 color = mix(star_color, moon_color, horizon);
    color = mix(color, shadow_color, crater_value);
    color.rgb = mix(color.rgb, moon_color.rgb, surface_texture);
    color.rgb += star_color.rgb * stars;
    color.rgb += vec3(dust);
    
    // Add a slight blue Earth glow near the horizon
    float earth_glow = (1.0 - horizon) * 0.1;
    color.rgb += vec3(0.0, 0.0, earth_glow);
    
    COLOR = color;
} 