extends RefCounted
## Category rules and shape classification of the import tool
## (docs/MAP_CONTRACT.md, R1): the default name vocabulary, the rules from a
## configuration, and the geometry rules for meshes no name rule matches.

## Default name vocabulary, in order (the first matching line wins); matched
## as CategoryRule kind "words".
const VOCABULARY := [
	["water", "water sea river lake pond ocean"],
	["decor", "traffic sign fence barrier bench cone dumpster bin hydrant mailbox pole wire planter prop car vehicle"],
	["lamps", "lamp light lantern"],
	["trees", "tree bush shrub hedge plant foliage vegetation palm leaves"],
	["facade_detail", "window door balcony timber beam trim cornice facade shutter awning railing detail frame"],
	["buildings", "building house wall roof tower dome drum minaret chimney church mosque shop skyscraper apartment office"],
	["ground", "ground terrain road street pavement sidewalk path grass land landcover floor plaza square tile parking driveway curb kerb dirt sand field bridge"],
]
## Group that holds the meshes the shape rules classified into `category`.
const GROUP_PREFIX := "map_category_"
## Rule keys a configuration's "category_rules" entries may use.
const RULE_KINDS := ["prefix", "regex", "words", "material", "group"]


## The default vocabulary as rules.
static func vocabulary_rules() -> Array[CategoryRule]:
	var rules: Array[CategoryRule] = []
	for line: Array in VOCABULARY:
		rules.append(CategoryRule.create(line[0], "words", line[1]))
	return rules


## One group rule per category, for the meshes the shape rules classified.
static func group_rules() -> Array[CategoryRule]:
	var rules: Array[CategoryRule] = []
	for category in CategoryRules.CATEGORIES:
		rules.append(CategoryRule.create(category, "group", GROUP_PREFIX + category))
	return rules


## Rules from a configuration's "category_rules" list, or an error message.
static func rules_from_config(entries: Array) -> Dictionary:
	var rules: Array[CategoryRule] = []
	for entry in entries:
		if not entry is Dictionary or not entry.has("category"):
			return {"error": "category_rules: every entry needs \"category\" and one of %s (%s)" % [RULE_KINDS, entry]}
		var kinds: Array = RULE_KINDS.filter(func(kind: String) -> bool: return entry.has(kind))
		if kinds.size() != 1 or entry.size() != 2:
			return {"error": "category_rules: entry %s needs exactly one of %s" % [entry, RULE_KINDS]}
		if str(entry.category) not in CategoryRules.CATEGORIES:
			return {"error": "category_rules: unknown category '%s' (known: %s)" % [entry.category, CategoryRules.CATEGORIES]}
		var pattern := str(entry[kinds[0]])
		if kinds[0] in ["regex", "material"] and RegEx.create_from_string(pattern) == null:
			return {"error": "category_rules: invalid regex '%s'" % pattern}
		rules.append(CategoryRule.create(str(entry.category), kinds[0], pattern))
	return {"rules": rules}


## Category from the shape of a mesh placed in the map: `box` is its box in
## the map, `stats` its face statistics (map_geometry.stats() with its
## rotation). "" when no shape rule fits (docs/MAP_CONTRACT.md, R1).
static func category_by_shape(box: AABB, stats: Dictionary) -> String:
	var size := box.size
	var wide := maxf(size.x, size.z)
	var narrow := minf(size.x, size.z)
	var area: float = stats.area
	if area <= 0.0:
		return ""
	if wide > 20.0 and size.y <= 0.25 * wide and stats.up >= 0.5 * area:
		return "ground"
	if size.y >= 2.5 and narrow >= 2.0 and stats.vertical >= 0.25 * area:
		return "buildings"
	if maxf(wide, size.y) < 2.5:
		return "decor"
	return ""
