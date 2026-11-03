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


## Category from the shape of a mesh placed in the map (docs/MAP_CONTRACT.md,
## R1): `box` is its box in the map, `stats` its face statistics
## (map_geometry.stats() with its rotation), `profile` how its vertices
## spread over its height (map_geometry.profile(); {} skips the rules that
## need it), `repeats` how many meshes of the map have the same shape. ""
## when no rule fits. In order:
## ground: wider than 20 m and at most a quarter as high as wide, or a flat
##   tile (at least 2 m by 1 m, at most 0.3 m or 5 % of its width thick: road
##   and grass tiles of a tiled town), with at least half of what can be seen
##   from above facing up (a closed slab's underside does not count) and walls
##   at most half of that up-facing area;
## trees: 1.5–40 m high, at most 25 m wide, a narrow trunk (its lowest
##   tenth at most 0.35 of the crown's width) under a round crown (the part
##   above 30 % of its height at least 1 m across both ways and at least half
##   as deep as wide);
## buildings: at least 2.5 m high, 2 m wide both ways, a quarter of its area
##   vertical, and either 3 m high or roofed (its upward faces cover half its
##   footprint);
## decor for an enclosure: at most 3.5 m high, mostly walls, open from above
##   (covering under a fifth of its footprint): a fence or wall round a yard;
## decor: a pole (at least 2 m high, its lowest quarter at most 0.6 m across,
##   at most 3 m wide: lamp posts, signs, traffic lights), a thin barrier (at
##   most 0.6 m thick, 0.3–3.5 m high, at least 1.5 m long: fences, low
##   walls), anything smaller than 2.5 m every way, a low object (under 2.5 m
##   high, at most 10 m wide: benches, planters, cars, kiosks), or an object
##   up to 6 m repeated at least 3 times;
## buildings again for a tall wall (over 3.5 m high, at most 2 m thick, at
##   least 3 m long, at least half of its area vertical) or a tall slender
##   block (at least 5 m high, under 2 m thick, three quarters of its area
##   vertical: towers, columns, chimneys), which must not vanish beyond a
##   visibility range like decor.
static func category_by_shape(box: AABB, stats: Dictionary, profile := {}, repeats := 1) -> String:
	var size := box.size
	var wide := maxf(size.x, size.z)
	var narrow := minf(size.x, size.z)
	var area: float = stats.area
	if area <= 0.0:
		return ""
	var seen_from_above: float = area - float(stats.get("down", 0.0))
	var flat_tile := wide >= 2.0 and narrow >= 1.0 and size.y <= maxf(0.3, 0.05 * wide)
	if (flat_tile or (wide > 20.0 and size.y <= 0.25 * wide)) and stats.up >= 0.5 * seen_from_above and stats.vertical <= 0.5 * stats.up:
		return "ground"
	if not profile.is_empty() and size.y >= 1.5 and size.y <= 40.0 and wide <= 25.0:
		var trunk: float = maxf(profile.low.x, profile.low.y)
		var crown_wide: float = maxf(profile.crown.x, profile.crown.y)
		var crown_narrow: float = minf(profile.crown.x, profile.crown.y)
		if crown_narrow >= 1.0 and crown_narrow >= 0.5 * crown_wide and trunk <= 0.35 * crown_wide:
			return "trees"
	var cover: float = float(stats.get("cover", 0.0)) / maxf(size.x * size.z, 1e-6)
	if size.y >= 2.5 and narrow >= 2.0 and stats.vertical >= 0.25 * area and (size.y >= 3.0 or cover >= 0.5):
		return "buildings"
	if size.y <= 3.5 and stats.vertical >= 0.5 * area and cover < 0.2:
		return "decor"
	if not profile.is_empty() and size.y >= 2.0 and maxf(profile.low.x, profile.low.y) <= 0.6 and wide <= 3.0:
		return "decor"
	if narrow <= 0.6 and size.y >= 0.3 and size.y <= 3.5 and wide >= 1.5:
		return "decor"
	if maxf(wide, size.y) < 2.5:
		return "decor"
	if size.y < 2.5 and wide <= 10.0:
		return "decor"
	if repeats >= 3 and maxf(wide, size.y) <= 6.0:
		return "decor"
	if size.y > 3.5 and narrow <= 2.0 and wide >= 3.0 and stats.vertical >= 0.5 * area:
		return "buildings"
	if size.y >= 5.0 and narrow < 2.0 and stats.vertical >= 0.75 * area:
		return "buildings"
	return ""


## A key that is equal for meshes of the same shape (triangle count and box
## size to 1 cm, the horizontal sides in either order), to count repeats.
static func shape_key(triangles: int, box: AABB) -> String:
	return "%d %.2f %.2f %.2f" % [triangles, minf(box.size.x, box.size.z), maxf(box.size.x, box.size.z), box.size.y]
