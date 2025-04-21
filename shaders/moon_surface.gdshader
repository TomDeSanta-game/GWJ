shader_type canvas_item;

uniform vec4 moon_color : source_color = vec4(0.85, 0.87, 0.9, 1.0);
uniform vec4 crater_color : source_color = vec4(0.7, 0.72, 0.75, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.1, 0.12, 0.25, 1.0);
uniform vec4 sky_color : source_color = vec4(0.05, 0.07, 0.2, 1.0);

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    f = f * f * (3.0 - 2.0 * f);
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    
    float lunar_surface = smoothstep(0.4, 0.6, uv.y);
    
    float lunar_texture = noise(uv * 10.0) * 0.2 + 
                         noise(uv * 20.0) * 0.1 + 
                         noise(uv * 40.0) * 0.05;
    
    vec3 surface_color = mix(moon_color.rgb, crater_color.rgb, lunar_texture);
    
    float crater_mask = 0.0;
    for (int i = 0; i < 5; i++) {
        float size = 0.1 + 0.2 * hash(vec2(float(i), 12.34));
        vec2 pos = vec2(
            0.2 + 0.6 * hash(vec2(float(i), 45.67)),
            0.55 + 0.3 * hash(vec2(float(i), 78.91))
        );
        
        float crater = smoothstep(size, size * 0.8, distance(uv, pos));
        crater *= smoothstep(size * 1.2, size, distance(uv, pos));
        
        crater_mask = max(crater_mask, crater * 0.5);
    }
    
    surface_color = mix(surface_color, crater_color.rgb * 0.8, crater_mask);
    
    vec3 stars = vec3(0.0);
    if (uv.y < 0.5) {
        for (int i = 0; i < 3; i++) {
            float star_layer = 0.0;
            float scale = 150.0 + float(i) * 100.0;
            for (int j = 0; j < 20; j++) {
                vec2 star_pos = vec2(
                    hash(vec2(float(j) * 1.23, float(i) * 2.34)), 
                    hash(vec2(float(j) * 3.45, float(i) * 4.56)) * 0.5
                );
                float star_size = 0.001 + 0.002 * hash(vec2(float(j) * 5.67, float(i) * 6.78));
                star_layer += smoothstep(star_size, 0.0, distance(uv, star_pos));
            }
            stars += star_layer * vec3(0.8, 0.85, 1.0) * (0.2 + 0.1 * float(i));
        }
    }
    
    float horizon = smoothstep(0.45, 0.55, uv.y);
    
    float dust = noise(vec2(uv.x * 10.0 + TIME * 0.2, uv.y * 5.0)) * 0.1 * (1.0 - uv.y);
    
    vec3 final_color = mix(sky_color.rgb + stars, surface_color, horizon);
    final_color += dust * moon_color.rgb;
    
    float earth_glow = smoothstep(0.7, 0.0, distance(uv, vec2(0.8, 0.2))) * 0.1 * (1.0 - horizon);
    final_color += vec3(0.1, 0.3, 0.5) * earth_glow;
    
    COLOR = vec4(final_color, 1.0);
} 