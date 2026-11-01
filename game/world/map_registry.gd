class_name MapRegistry
extends Resource
## The maps the game can load, found by MapDefinition.id. The first available
## entry is the default: normal release builds always start there. A map whose
## files are missing (MapDefinition.is_available(): its GLB is generated or
## copied in on each machine, so a fresh clone lacks it) is passed over. Debug
## and Release Perf builds can start on another with --map=<id> or an
## experiment's "map" key; debug builds also cycle through them with the
## overlay's MAP button, skipping unavailable maps.

const PATH := "res://game/world/maps.tres"

@export var definitions: Array[MapDefinition] = []


static func load_default() -> MapRegistry:
	return load(PATH) as MapRegistry


## The first available map; null when none is available.
func default_map() -> MapDefinition:
	for definition in definitions:
		if definition.is_available():
			return definition
	return null


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
