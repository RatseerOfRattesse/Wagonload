class_name SeedGenerator
extends Node
## An engine that creates a world-size heightmap, temperature map, humidity map, and biome map.
##
## These map images are then stored into the save folder and preloaded on loading a save. From there, the [WorldGenerator] upscales noisemaps deterministically to high-res active regions and decides which blocks go where.

var noise = FastNoiseLite.new()
var rng = RandomNumberGenerator.new()
var dimensions:Vector2i = Vector2i(2048, 1024)
var l0_seed_coords:Array[Vector2i] = []
var l0_pixel_map:Array[Array] = []
var heightmap:Image
var temp_map:Image
var humidity_map:Image
var biome_map:Image

## Core generator function.
func generate(inputSeed:int):
	rng.seed = inputSeed
	## LAYER 0 // VORONOI CONTINENTS
	l0_pixel_map.resize(dimensions.x)
	for line in dimensions.x:
		l0_pixel_map[line] = []
		l0_pixel_map[line].resize(dimensions.y)
		
	l0_seed_coords.clear()
	@warning_ignore("integer_division")
	for i in dimensions.x/8:
		l0_seed_coords.append(Vector2i(rng.randi() % (dimensions.x), rng.randi() % (dimensions.y)))
	
	for x in dimensions.x:
		for y in dimensions.y:
			var coords = Vector2i(x, y)
			var closest_seed_index:int
			var min_distance:float = INF
			for index in range(l0_seed_coords.size() - 1):
				var distance = coords.distance_to(l0_seed_coords[index])
				if distance < min_distance:
					min_distance = distance
					closest_seed_index = index
			l0_pixel_map[x][y] = closest_seed_index
		#print("finished generating seed for row " + str(x))
	
	heightmap = Image.create_empty(dimensions.x, dimensions.y, false, Image.FORMAT_RGB8)
	for x in dimensions.x:
		for y in dimensions.y:
			var coords = Vector2i(x, y)
			var max_diagonal = Vector2i(dimensions.x, dimensions.y).length()
			var normal_dist = coords.distance_to(l0_seed_coords[l0_pixel_map[x][y]]) / (max_diagonal * 0.065)
			var height = clamp(1.0 - normal_dist, 0.0, 1.0)
			
			heightmap.set_pixel(x, y, Color (height, height, height))
		#print("finished painting for row" + str(x))
			
	var error:Error = heightmap.save_png("user://saves/map.png")
	
	
	#noise.seed = inputSeed
	#noise.noise_type = FastNoiseLite.TYPE_CELLULAR; 
	#noise.frequency = 0.05
	#
	#var noise_texture = NoiseTexture2D.new()
	#noise_texture.width = dimensions.x
	#noise_texture.height = dimensions.y
	#noise_texture.noise = noise
	#
	# CRITICAL: Wait for the asynchronous generation thread to complete
	#await noise_texture.changed
	#
	# 3. Extract the Image data
	#var img: Image = noise_texture.get_image()
	#
	# 4. Save the file to your project directory
	#var save_path: String = "res://generated_noise.png"
	#var error = img.save_png("user://saves/")
	
	if error == OK:
		print("OK")
	else:
		print("ERROR: ", error)

func retrieve_closest_seed_id(pixel:Vector2i) ->  int:
	return l0_pixel_map[pixel.x][pixel.y]

func seed_from_id(index:int) -> Vector2i:
	return l0_seed_coords[index]

var value = noise.get_noise_2d(0, 0)
