shader_type canvas_item;

uniform vec4 metal_color : source_color = vec4(0.5, 0.52, 0.55, 1.0);
uniform vec4 accent_color : source_color = vec4(0.3, 0.32, 0.35, 1.0);
uniform float vibration_amount = 0.005;
uniform float vibration_speed = 2.0;
uniform float light_flicker = 0.1;

void fragment() {
    // Base metal background with noise
    vec2 uv = UV;
    
    // Add subtle truck vibration
    float vibration = sin(TIME * vibration_speed) * vibration_amount;
    uv.y += vibration;
    
    // Create metal panel effect with lines
    float panel_size = 30.0;
    vec2 panel_uv = fract(uv * panel_size);
    float panel_edge = smoothstep(0.95, 1.0, panel_uv.x) + smoothstep(0.95, 1.0, panel_uv.y);
    
    // Rivets along panel edges
    float rivet_x = step(0.97, panel_uv.x) * step(panel_uv.y, 0.98) * step(0.02, panel_uv.y);
    float rivet_y = step(0.97, panel_uv.y) * step(panel_uv.x, 0.98) * step(0.02, panel_uv.x);
    float rivets = max(rivet_x, rivet_y);
    
    // Create scratched metal effect
    float scratches = fract(sin(dot(floor(uv * 50.0), vec2(12.9898, 78.233))) * 43758.5453);
    scratches = smoothstep(0.4, 0.6, scratches) * 0.1;
    
    // Interior lighting with flicker
    float light_y = sin(uv.x * 3.14) * 0.5 + 0.5;
    float light = light_y * (1.0 - abs(uv.y - 0.5) * 2.0) * 0.5;
    light *= 1.0 + sin(TIME * 10.0) * light_flicker;
    
    // Combine all effects
    vec4 color = mix(metal_color, accent_color, panel_edge + rivets);
    color.rgb += scratches;
    color.rgb += vec3(0.2, 0.18, 0.15) * light;
    
    // Add some dirt near edges
    float edge_dirt = (1.0 - panel_edge) * 0.05;
    color.rgb -= edge_dirt;
    
    COLOR = color;
} 