class_name MapRegistry
extends Resource
## The maps the game can load, found by MapDefinition.id. The first entry is
## the default: normal release builds always start there. Debug and Release
## Perf builds can start on another with --map=<id> or an experiment's "map"
## key; debug builds also cycle through them with the overlay's MAP button.

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


## The map after `definition`, wrapping around; the first map when
## `definition` is not in the list.
func next_after(definition: MapDefinition) -> MapDefinition:
	return definitions[(definitions.find(definition) + 1) % definitions.size()]


## The id given as --map=<id> among the user arguments, or "".
static func id_from_args(args: PackedStringArray) -> String:
	for arg in args:
		if arg.begins_with("--map="):
			return arg.trim_prefix("--map=")
	return ""
