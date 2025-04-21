shader_type canvas_item;

uniform vec4 color1 : source_color = vec4(0.1, 0.2, 0.4, 1.0);
uniform vec4 color2 : source_color = vec4(0.4, 0.1, 0.3, 1.0);
uniform vec4 color3 : source_color = vec4(0.05, 0.3, 0.5, 1.0);
uniform float time_scale = 0.2;
uniform float shape_scale = 10.0;
uniform float circle_size = 0.3;
uniform float triangle_size = 0.35;
uniform float square_size = 0.35;
uniform float shape_blend = 0.1;

float rand(vec2 n) { 
    return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

float circle(vec2 p, float size) {
    return step(length(p), size);
}

float square(vec2 p, float size) {
    vec2 d = abs(p) - size;
    return 1.0 - step(max(d.x, d.y), 0.0);
}

float triangle(vec2 p, float size) {
    p.y += size * 0.66;
    const float k = sqrt(3.0);
    p.x = abs(p.x) - size;
    p.y = p.y + size / k;
    if (p.x + k * p.y > 0.0) p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
    p.x -= clamp(p.x, -2.0 * size, 0.0);
    return length(p) * sign(p.y);
}

void fragment() {
    // Create a grid and assign random shapes to each cell
    vec2 grid_uv = floor(UV * shape_scale) / shape_scale;
    float grid_id = rand(grid_uv);
    
    // Calculate center of each grid cell
    vec2 cell_center = grid_uv + vec2(1.0/shape_scale * 0.5);
    
    // Distance from current pixel to cell center
    vec2 dist_from_center = UV - cell_center;
    
    // Scale based on time for animation
    float scale = 0.7 + 0.3 * sin(TIME * time_scale + grid_id * 6.28);
    dist_from_center /= scale;
    
    // Choose a shape based on grid_id
    float shape_val = 0.0;
    if (grid_id < 0.33) {
        // Circle
        shape_val = step(length(dist_from_center), circle_size);
    } else if (grid_id < 0.66) {
        // Square
        vec2 q = abs(dist_from_center) - vec2(square_size);
        shape_val = 1.0 - step(max(q.x, q.y), 0.0);
    } else {
        // Triangle
        shape_val = step(triangle(dist_from_center, triangle_size), 0.0);
    }
    
    // Color selection based on grid_id
    vec4 shape_color;
    if (grid_id < 0.33) {
        shape_color = color1;
    } else if (grid_id < 0.66) {
        shape_color = color2;
    } else {
        shape_color = color3;
    }
    
    // Add subtle movement to the shapes
    float movement = sin(TIME * 0.5 + grid_id * 10.0) * 0.02;
    
    // Blend colors
    vec4 bg_color = mix(color1 * 0.5, color2 * 0.5, UV.x);
    bg_color = mix(bg_color, color3 * 0.5, UV.y);
    
    // Add glow effect
    float glow = (1.0 - shape_val) * 0.1;
    shape_color += glow;
    
    // Mix the shape with background
    COLOR = mix(bg_color, shape_color, shape_val * (0.8 + movement));
    
    // Add vignette effect
    float vignette = length(UV - vec2(0.5)) * 0.5;
    COLOR.rgb *= 1.0 - vignette;
} 