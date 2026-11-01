shader_type canvas_item;

uniform float cell_density = 10.0;
uniform float seed1 = 1.0;
uniform float seed2 = 1.0;
uniform float seed3 = 1.0;
uniform float seed4 = 1.0;

vec2 makeShitUp(vec2 p) {
	p = vec2(dot(p, vec2(seed1, seed2)), dot(p, vec2(seed3, seed4)));
	return -1.0 + 2.0 * fract(sin(p));
}

void fragment() {
	vec2 st = UV * cell_density;
	vec2 current_cell = floor(st);
	vec2 local_coords = fract(st);
	
	float min_dist = 1.0;
	vec2 winning_cell_id = vec2(0.0);
	
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor_offset = vec2(float(x), float(y));
			vec2 point = makeShitUp(current_cell + neighbor_offset);
			
			vec2 diff = neighbor_offset + 0.5 + 0.5 * sin(point) - local_coords;
			float dist = length(diff);

			if (dist < min_dist) {
				min_dist = dist;
				winning_cell_id = current_cell + neighbor_offset;
			}
		}
	}
	COLOR = vec4(vec3(min_dist), 1.0);
}