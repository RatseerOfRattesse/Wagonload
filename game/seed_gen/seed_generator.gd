class_name SeedGenerator
extends Node
## An engine that creates a world-size heightmap, temperature map, humidity map, and biome map.
##
## These map images are then stored into the save folder and preloaded on loading a save. From there, the [WorldGenerator] upscales noisemaps deterministically to high-res active regions and decides which blocks go where.

var noise = FastNoiseLite.new()
var rng = RandomNumberGenerator.new()
var dimensions:Vector2i = Vector2i(2048, 2048)
var seed_count:int = 50
var l0_seed_coords:Array[Vector2i] = []
var l0_pixel_map:Array[Array] = []
var noise_texture:NoiseTexture2D

var heightmap:Image
var temp_map:Image
var humidity_map:Image
var biome_map:Image

var rendering_device = RenderingServer.create_local_rendering_device()
var shader_file: RDShaderFile
var shader_spirv: RDShaderSPIRV
var shader: RID
var gpu_buffer: PackedByteArray

## Core generator function.
func generate(inputSeed:int):
	rng.seed = inputSeed
	## LAYER 0 // VORONOI CONTINENTS
	gpu_buffer = run_jfa_pipeline()
	heightmap = Image.create_from_data(dimensions.x, dimensions.y, false, Image.FORMAT_RGB8, gpu_buffer)
	var error:Error = heightmap.save_png("user://saves/map.png")

	if error == OK:
		print("OK")
	else:
		print("ERROR: ", error)

	#l0_pixel_map.resize(dimensions.x)
	#for line in dimensions.x:
		#l0_pixel_map[line] = []
		#l0_pixel_map[line].resize(dimensions.y)
		#
	#l0_seed_coords.clear()
	#@warning_ignore("integer_division")
	#for i in dimensions.x/8:
		#l0_seed_coords.append(Vector2i(rng.randi() % (dimensions.x), rng.randi() % (dimensions.y)))
	#
	#for x in dimensions.x:
		#for y in dimensions.y:
			#var coords = Vector2i(x, y)
			#var closest_seed_index:int
			#var min_distance:float = INF
			#for index in range(l0_seed_coords.size() - 1):
				#var distance = coords.distance_to(l0_seed_coords[index])
				#if distance < min_distance:
					#min_distance = distance
					#closest_seed_index = index
			#l0_pixel_map[x][y] = closest_seed_index
		#print("finished generating seed for row " + str(x))
		#
	#heightmap = Image.create_empty(dimensions.x, dimensions.y, false, Image.FORMAT_RGB8)
	#for x in dimensions.x:
		#for y in dimensions.y:
			#var coords = Vector2i(x, y)
			#var max_diagonal = Vector2i(dimensions.x, dimensions.y).length()
			#var normal_dist = coords.distance_to(l0_seed_coords[l0_pixel_map[x][y]]) / (max_diagonal * 0.065)
			#var height = clamp(1.0 - normal_dist, 0.0, 1.0)
			#
			#heightmap.set_pixel(x, y, Color (height, height, height))
		#print("finished painting for row" + str(x))
	
	#noise.seed = inputSeed
	#noise.noise_type = FastNoiseLite.TYPE_SIMPLEX; 
	#noise.frequency = 0.05
	#
	#noise_texture = NoiseTexture2D.new()
	#noise_texture.width = dimensions.x
	#noise_texture.height = dimensions.y
	#noise_texture.noise = noise
	#
	#await noise_texture.changed
	#
	#var landmassMap: Image = noise_texture.get_image()

func retrieve_closest_seed_id(pixel:Vector2i) ->  int:
	return l0_pixel_map[pixel.x][pixel.y]

func seed_from_id(index:int) -> Vector2i:
	return l0_seed_coords[index]
	
func run_jfa_pipeline():
	refreshShader("res://game/seed_gen/voronoi_jump_flood.glsl")
	# Initialize array
	var inbytes = PackedFloat32Array()
	inbytes.resize(dimensions.x * dimensions.y * 4)
	
	# Set each pixel up with data to transfer to GPU
	for i in range(0, inbytes.size(), 4):
		inbytes[i] = -1.0
		inbytes[i+1] = -1.0
		inbytes[i+2] = -1.0
		inbytes[i+3] = 1.0
		
	# Generate seeds and their indexes
	for seedIndex in range(seed_count):
		var x = rng.randi() % dimensions.x
		var y = rng.randi() % dimensions.y
		var index = (y * dimensions.x + x) * 4
		inbytes[index] = float(x)
		inbytes[index + 1] = float(y)
		inbytes[index + 2] = float(seedIndex)
	
	var textureFormat = RDTextureFormat.new()
	textureFormat.width = dimensions.x
	textureFormat.height = dimensions.y
	textureFormat.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	textureFormat.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	var texture_a = rendering_device.texture_create(textureFormat, RDTextureView.new(), inbytes.to_byte_array())
	var texture_b = rendering_device.texture_create(textureFormat, RDTextureView.new(), [])
	
	var step = dimensions.x/2.0
	var textures = [texture_a, texture_b]
	var toggle = 0
	
	while step >= 1:
		var intex = textures[toggle]
		var outex = textures[1-toggle]
		
		var push_constants = PackedInt32Array([step, dimensions.x, dimensions.y]).to_byte_array()
		
		var uniform_in = RDUniform.new()
		uniform_in.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform_in.binding = 0
		uniform_in.add_id(intex)
		
		var uniform_out = RDUniform.new()
		uniform_out.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform_out.binding = 0
		uniform_out.add_id(outex)
		
		var uniform_set = rendering_device.uniform_set_create([uniform_in, uniform_out], shader, 0)
		
		var pipeline = rendering_device.compute_pipeline_create(shader,)
		var compute_list = rendering_device.compute_list_begin()
		rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		rendering_device.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
		
		var groupsX = ceil(float(dimensions.x) / 16.0)
		var groupsY = ceil(float(dimensions.y) / 16.0)
		rendering_device.compute_list_dispatch(compute_list, groupsX, groupsY, 1)
		rendering_device.compute_list_end()
		
		step /= 2
		toggle = 1 - toggle
	
	rendering_device.submit()
	rendering_device.sync()
	
	var final_texture = textures[toggle]
	return rendering_device.texture_get_data(final_texture, 0)

func get_nearest_seed_id(bytes:PackedByteArray, x:int, y:int) -> float:
	return parse_voronoi(bytes, x, y).z
	
func get_nearest_seed_coord(bytes:PackedByteArray, x:int, y:int) -> Vector2:
	var data = parse_voronoi(bytes, x, y)
	return Vector2(data.x, data.y)

func parse_voronoi(bytes:PackedByteArray, x:int, y:int) -> Vector3:
	var floats = bytes.to_float32_array()
	var index = (y * dimensions.y + x) * 4
	
	return Vector3(floats[index], floats[index+1], floats[index+2])
	

func refreshShader(path:String):
	shader_file = load(path)
	shader_spirv = shader_file.get_spirv()
	shader = rendering_device.shader_create_from_spirv(shader_spirv)

var value = noise.get_noise_2d(0, 0)
	
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
	
