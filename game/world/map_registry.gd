class_name MapRegistry
extends Resource
## The maps the game can load, found by MapDefinition.id. The first entry is
## the default: normal release builds always start there. Debug and Release
## Perf builds can start on another with --map=<id> or an experiment's "map"
## key; debug builds also cycle through them with the overlay's MAP button,
## skipping maps whose generated files are missing (MapDefinition.is_available()).

const PATH := "res://game/world/maps.tres"

@export var definitions: Array[MapDefinition] = []


static func load_default() -> MapRegistry:
	return load(PATH) as MapRegistry


func default_map() -> MapDefinition:
	return definitions[0] if not definitions.is_empty() else null


## The map with `id`, or null.
func find(id: String) -> MapDefinition:
	for definition in definitions:
		if definition.id == id:
			return definition
	return null


func ids() -> Array[String]:
	var found: Array[String] = []
	for definition in definitions:
		found.append(definition.id)
	return found


## The next available map after `definition`, wrapping around; the first
## available map when `definition` is not in the list.
func next_after(definition: MapDefinition) -> MapDefinition:
	var start := definitions.find(definition)
	for step in range(1, definitions.size() + 1):
		var candidate := definitions[(start + step) % definitions.size()]
		if candidate.is_available():
			return candidate
	return definition


## The id given as --map=<id> among the user arguments, or "".
static func id_from_args(args: PackedStringArray) -> String:
	for arg in args:
		if arg.begins_with("--map="):
			return arg.trim_prefix("--map=")
	return ""
