class_name MapRegistry
extends Resource
## The maps the game can load, found by MapDefinition.id. The first available
## entry is the default: normal release builds always start there. A map whose
## files are missing (MapDefinition.is_available(): its GLB is generated or
## copied in on each machine, so a fresh clone lacks it) is passed over. Debug
## and Release Perf builds can start on another with --map=<id> or an
## experiment's "map" key; debug builds also cycle through them with the
## overlay's MAP button, skipping unavailable maps. Every map is in PATH; the
## maps a release package carries are in RELEASE_PATH (for_build()).

const PATH := "res://game/world/maps.tres"
## The maps the release presets pack ("Android Release", "iOS Release";
## tools/release_package.gd), the default first.
const RELEASE_PATH := "res://game/world/maps_release.tres"

@export var definitions: Array[MapDefinition] = []


## Every map.
static func load_default() -> MapRegistry:
	return load(PATH) as MapRegistry


## The maps a release package carries.
static func load_release() -> MapRegistry:
	return load(RELEASE_PATH) as MapRegistry


## The registry a build loads (Main): every map in debug and Release Perf
## builds, the release maps in normal release builds, which only ever load the
## default (BuildFeatures). So a release package needs neither PATH nor the
## definitions of maps it does not carry.
static func for_build() -> MapRegistry:
	return load_default() if BuildFeatures.perf_enabled() else load_release()


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
