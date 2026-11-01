extends Node

# MAIN ENTRYPOINT:
# Will use a GameContext to derive what children to run.
# Active children: UI, World. Entrypoints; swap their children from UIContext.
# Ethereal children: WorldGenerator

@onready var seedGenerator = $SeedGenerator

func _ready() -> void:
	var error:Error = DirAccess.make_dir_recursive_absolute("user://saves/")
	if error == OK:
		print("OK")
	else:
		print("ERROR: ", error)
	seedGenerator.generate(8331)
