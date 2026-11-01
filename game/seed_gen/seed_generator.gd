class_name SeedGenerator
extends Node
## An engine that creates a world-size heightmap, temperature map, humidity map, and biome map.
##
## These map images are then stored into the save folder and preloaded on loading a save. From there, the [WorldGenerator] upscales noisemaps deterministically to high-res active regions and decides which blocks go where.

@onready var worley = $WorleyNoise
@onready var worleyRect = $WorleyNoise/ColorRect
@onready var voronoi = $VoronoiNoise
@onready var voronoiRect = $VoronoiNoise/ColorRect

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
	
	shaderNoise(worleyRect, worley, "user://saves/worley.png", inputSeed)
	shaderNoise(voronoiRect, voronoi, "user://saves/voronoi.png", inputSeed)
	
func savePNG(image:Image, path:String):
	var error : Error = image.save_png(path)
	if error == OK:
		print("OK")
	else:
		print("ERROR: ", error)

func shaderNoise(rect:ColorRect, viewport:SubViewport, path:String, inputSeed:int):
	var material:ShaderMaterial = rect.material
	if material:
		for i in 4:
			@warning_ignore("integer_division")
			rng.seed = inputSeed + i
			material.set_shader_parameter("seed" + str(i), rng.randf()*1000)
			print(rng.randf()*1000)
		rng.seed = inputSeed
	await RenderingServer.frame_post_draw
	var texture = viewport.get_texture()
	var image = texture.get_image()
	savePNG(image, path)
