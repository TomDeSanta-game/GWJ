shader_type canvas_item;

uniform vec4 color1 : source_color = vec4(0.1, 0.1, 0.2, 1.0);
uniform vec4 color2 : source_color = vec4(0.05, 0.05, 0.1, 1.0);
uniform vec4 color3 : source_color = vec4(0.2, 0.1, 0.3, 1.0);
uniform vec4 color4 : source_color = vec4(0.1, 0.2, 0.3, 1.0);
uniform float grid_size = 5.0;
uniform float time_scale = 0.5;
uniform float shape_size = 0.4;
uniform float glow_amount = 0.2;

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float shape_circle(vec2 st, float size) {
    return 1.0 - step(size, length(st * 2.0 - 1.0));
}

float shape_square(vec2 st, float size) {
    vec2 bl = step(vec2(0.5 - size/2.0), st);
    vec2 tr = step(vec2(0.5 - size/2.0), 1.0 - st);
    return bl.x * bl.y * tr.x * tr.y;
}

float shape_triangle(vec2 st, float size) {
    float d1 = st.x * 2.0;
    float d2 = 2.0 - st.x * 2.0 - st.y * 2.0;
    float d3 = st.y * 2.0;
    return 1.0 - step(size, min(min(d1, d2), d3));
}

void fragment() {
    vec2 st = UV;
    
    vec2 grid_uv = fract(st * grid_size);
    vec2 grid_id = floor(st * grid_size);
    
    float grid_random = random(grid_id);
    vec2 grid_center = vec2(0.5);
    
    float dist = distance(grid_uv, grid_center);
    
    float time = TIME * time_scale;
    float size = shape_size * (0.8 + 0.2 * sin(time + grid_random * 6.28));
    
    float shape = 0.0;
    float shape_type = fract(grid_random * 7.919) * 3.0;
    
    if (shape_type < 1.0) {
        shape = shape_circle(grid_uv, size);
    } 
    else if (shape_type < 2.0) {
        shape = shape_square(grid_uv, size);
    } 
    else {
        shape = shape_triangle(grid_uv, size);
    }
    
    float hue = fract(grid_random + time * 0.05);
    vec4 shape_color;
    
    if (hue < 0.25) {
        shape_color = color1;
    } else if (hue < 0.5) {
        shape_color = color2;
    } else if (hue < 0.75) {
        shape_color = color3;
    } else {
        shape_color = color4;
    }
    
    grid_uv = grid_uv * 2.0 - 1.0;
    grid_uv.x += sin(time + grid_id.y * 0.2) * 0.1;
    grid_uv.y += cos(time + grid_id.x * 0.2) * 0.1;
    
    float background = mix(0.1, 0.2, random(grid_id));
    
    float glow = smoothstep(0.5, 0.0, dist);
    
    vec4 final_color = mix(vec4(vec3(background), 1.0), shape_color, shape);
    final_color.rgb += glow * glow_amount * shape_color.rgb;
    
    float vignette = 1.0 - smoothstep(0.4, 1.4, length(UV - vec2(0.5)));
    final_color.rgb *= vignette;
    
    COLOR = final_color;
} 