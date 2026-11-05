class_name CategoryRules
extends Resource
## Which render category each mesh of a map belongs to: part of the map's data
## (MapDefinition.category_rules), read by RenderSettings for the quality
## profiles' visibility ranges and hidden categories, and for occluders. The
## categories are the game's vocabulary (CATEGORIES); the rules that map a
## map's meshes onto them belong to the map. Rules are tried in order and the
## first match wins; a mesh no rule matches gets default_category ("" = none:
## always drawn, no visibility range).

## The render categories the quality profiles and experiments know.
const CATEGORIES: Array[String] = ["facade_detail", "decor", "lamps", "trees", "buildings", "ground", "water"]
const DEFAULT_OCCLUDER_CATEGORIES: Array[String] = ["buildings", "ground"]

@export var rules: Array[CategoryRule] = []
@export var default_category := ""
## Collision under meshes of these categories becomes occluders
## (RenderSettings.build_occluders()).
@export var occluder_categories: Array[String] = DEFAULT_OCCLUDER_CATEGORIES.duplicate()


## Category of `node` (a MeshInstance3D of the map), or default_category.
func category_of(node: Node) -> String:
	var node_name := str(node.name)
	for rule in rules:
		if rule.matches(node, node_name):
			return rule.category
	return default_category


## The map's MeshInstance3D nodes under `map_root`, grouped by category
## (every category of CATEGORIES is a key; meshes in no category are left out).
func meshes_by_category(map_root: Node) -> Dictionary:
	var groups := empty_groups()
	add_to_groups(groups, map_root.find_children("*", "MeshInstance3D", true, false))
	return groups


## Every category of CATEGORIES, with no meshes yet (add_to_groups()).
static func empty_groups() -> Dictionary:
	var groups := {}
	for category in CATEGORIES:
		groups[category] = []
	return groups


## Adds `nodes` (MeshInstance3D) to their categories' lists in `groups`; a
## map's meshes can be grouped a part at a time (Main, behind the loading screen).
func add_to_groups(groups: Dictionary, nodes: Array) -> void:
	for node in nodes:
		var category := category_of(node)
		if groups.has(category):
			groups[category].append(node)


## Problems with the rules themselves: unknown categories. Empty when valid.
func validate() -> Array[String]:
	var problems: Array[String] = []
	for rule in rules:
		if rule.category not in CATEGORIES:
			problems.append("rule '%s %s' names unknown category '%s'" % [rule.kind, rule.pattern, rule.category])
	if not default_category.is_empty() and default_category not in CATEGORIES:
		problems.append("unknown default category '%s'" % default_category)
	for category in occluder_categories:
		if category not in CATEGORIES:
			problems.append("unknown occluder category '%s'" % category)
	return problems


## The lowercase words of a node name: runs of letters, split also where a
## lowercase letter is followed by an uppercase one ("StreetLamps_3" -> street,
## lamps; "osm_12_walls" -> osm, walls).
static func words_of(node_name: String) -> PackedStringArray:
	var words := PackedStringArray()
	var word := ""
	var previous_lower := false
	for i in node_name.length():
		var c := node_name[i]
		var letter := c.to_lower() != c.to_upper()
		var upper := letter and c == c.to_upper()
		if not letter or (upper and previous_lower):
			if not word.is_empty():
				words.append(word.to_lower())
			word = ""
		if letter:
			word += c
		previous_lower = letter and not upper
	if not word.is_empty():
		words.append(word.to_lower())
	return words
