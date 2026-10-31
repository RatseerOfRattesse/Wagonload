#[compute]
#version 450

// Hey hey repo viewers, I've absolutely bloody covered this script in ramblings and notes so I can attempt to decode it later. This is frankensteined up with a bunch of random code fragments from a billion places, and I frankly barely understand the syntax and only somewhat comprehend the actual logic.
// Therefore, I've done a bunch of notes all over this in my bullshittery writing that are probably inaccurate, but sum up that aforementioned somewhat comprehended logic.

//This script should only be procesing a single pixel and throwing the Jump Flood Algorithm at it. Its purview ends there.

// 2 dimensional, so only two axes are set to non-1 values. The program processes in 16x16 sections, so that's why x and y are 16. I hope.
layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

// Inputs and output textures/other data. The seed data is coupled into these... because of technical limitations?
// Also, shown here my incessant need to create unnecessarily convoluted abbreviations for simply things to make me sound cool when I talk about em.
layout(rgba32f, binding = 0) uniform image2D intex;
layout(rgba32f, binding = 1) uniform image2D outex;

// Push constants are lightweight data transmission vehicles I think? For CPU to GPU. These I can think of as parameters of the shader, submitted dynamically by the GDScript based on the progress of the generation.
layout(push_constant) uniform PushConstants {
	int step_size;
	int width;
	int height;
} push_constants;

// I think I know what this is
void main() {
	// Store the pixel's coordinates.
	ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
	
	// Ensure we're not laughably outside the image and wasting processing power.
	if (coords.x >= push_constants.width || coords.y >= push_constants.height) {
		return;
	}
	
	// Store the data transferred to this instance of the shader. I believe the fourth vector is not in use, but the imageLoad method just outputs vec4's. There's probably a better and more intuitive way to do this, but this is the first one I found and I need 16 hours in by Sunday so please make it stop.
	// We just ignore it. x and y contain the pixel's coordinates, whilst the other contains the index of the nearest seed - unset at the first run.
	vec4 inputex = imageLoad(intex, coords);
	
	// Set up the variables for the Jump Flood Algorithm. 
	vec2 nearest_seed_coords = vec2(inputex.xy);
	float nearest_seed_id = inputex.z;
	// This is infinity because we want to start without any of the limits and every time a better seed is discovered, we change this distance as well as the above variables.
	float current_nearest_dist = 1.0/0.0;
	
	// Check for existing seeds stored in the data.
	if (nearest_seed_id >= 0.0) {
		current_nearest_dist = distance(coords, nearest_seed_coords);
	}

	// Sample in rays in each of eight diagonal + cardinal directions, at a distance of the current step-size parameter.
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			ivec2 neighbor_coords = coords + ivec2(x, y) * push_constants.step_size;
			//Confirm this thing is in bounds. Ex. the program could try sampling the neighbours of a pixel at the edge of the board, and then weird shit would go down.
			if (neighbor_coords.x >= 0 && neighbor_coords.x < push_constants.width &&
				neighbor_coords.y >= 0 && neighbor_coords.y < push_constants.height) {
				
				// Equivalent of the earlier inputex vec4 for the neighbour
				vec4 neighbor_data = imageLoad(intex, neighbor_coords);
				float neighbor_seed_id = neighbor_data.z;
				
				// Check neighbour's seed storage and hope it has something useful in it
				if (neighbor_seed_id >= 0.0) {
					// Grab the neighbour's closest seed data etc. etc. think I can guess pleasse tell me I vaguely understood it
					vec2 neighbor_seed_coords = neighbor_data.xy;
					float dist = distance(coords, neighbor_seed_coords);
					
					// Compare the pixel's coords to the neighbour's known seed, swap out if closer.
					if (dist < current_nearest_dist) {
						current_nearest_dist = dist;
						nearest_seed_coords = neighbor_seed_coords;
						nearest_seed_id = neighbor_seed_id;
					}
				}
			}
		}
	}

	// Throw the newly refreshed seed data back to the SeedGenerator and hopefully it works
	imageStore(outex, coords, vec4(nearest_seed_coords, nearest_seed_id, 1.0));
}
