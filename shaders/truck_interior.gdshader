shader_type canvas_item;

uniform vec4 metal_color : source_color = vec4(0.3, 0.32, 0.34, 1.0);
uniform vec4 panel_color : source_color = vec4(0.25, 0.27, 0.29, 1.0);
uniform float vibration_speed = 2.0;
uniform float vibration_strength = 0.003;
uniform float time_scale = 0.5;
uniform float dirt_amount = 0.4;

void fragment() {
    vec2 uv = UV;
    
    vec2 vibration = vec2(
        sin(TIME * vibration_speed + uv.y * 10.0) * vibration_strength,
        cos(TIME * vibration_speed + uv.x * 10.0) * vibration_strength
    );
    uv += vibration;
    
    float panel_width = 0.2;
    float panel_line = step(mod(uv.x, panel_width), 0.005) + step(mod(uv.y, panel_width), 0.005);
    
    float rivet_size = 0.01;
    float rivet_spacing = panel_width;
    float rivets = 0.0;
    for (float i = 0.0; i < 6.0; i++) {
        for (float j = 0.0; j < 6.0; j++) {
            vec2 rivet_pos = vec2(rivet_spacing * i, rivet_spacing * j);
            rivets += 1.0 - smoothstep(rivet_size - 0.003, rivet_size + 0.003, length(uv - rivet_pos));
        }
    }
    
    float scratch = max(0.0, sin(uv.x * 100.0) * sin(uv.y * 100.0) * 0.1);
    
    float lighting = sin(TIME * 0.5) * 0.05 + 0.95;
    float light_gradient = 1.0 - distance(uv, vec2(0.5, 0.5)) * 0.5;
    light_gradient = pow(light_gradient, 2.0) * lighting;
    
    vec4 base_color = mix(metal_color, panel_color, panel_line);
    base_color = mix(base_color, vec4(1.0), rivets * 0.2);
    base_color = mix(base_color, vec4(0.9, 0.9, 0.9, 1.0), scratch);
    base_color.rgb *= light_gradient;
    
    float edge_dirt = (1.0 - uv.y) * dirt_amount;
    base_color.rgb = mix(base_color.rgb, vec3(0.1, 0.08, 0.06), edge_dirt);
    
    COLOR = base_color;
} 