extends SceneTree
## Compares two imports of the same map mesh by mesh (Phase 6b, the
## classification accuracy): the categories of a reference import (e.g. by
## the default name vocabulary, or hand labels) against a test import (e.g.
## by shape alone, "use_default_name_rules": false). Meshes split by the
## test import ("<name>_000" …) count as their source mesh. Prints the
## confusion table and writes it as TSV.
##   godot --headless --path . --script res://tools/map_import/compare_categories.gd -- --reference=<map .tres> --test=<map .tres> [--out=<file.tsv>]

var _options := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var reference := _categories(load(_options.get("reference", "")) as MapDefinition)
	var test := _categories(load(_options.get("test", "")) as MapDefinition)
	var split := RegEx.create_from_string("^(.*)_\\d{3,}$")
	var table := {}  # "reference\ttest" -> count
	var right := 0
	var total := 0
	for name: String in test:
		var source := name
		if not reference.has(source):
			var found := split.search(name)
			source = found.get_string(1) if found else name
		if not reference.has(source):
			continue
		var key := "%s\t%s" % [_shown(reference[source]), _shown(test[name])]
		table[key] = table.get(key, 0) + 1
		total += 1
		right += int(reference[source] == test[name])
	var keys := table.keys()
	keys.sort()
	var lines := PackedStringArray(["reference\ttest\tmeshes"])
	for key: String in keys:
		lines.append("%s\t%d" % [key, table[key]])
	print("\n".join(lines))
	print("COMPARE %d of %d meshes in the same category (%.1f %%)" % [right, total, 100.0 * right / maxi(total, 1)])
	if _options.has("out"):
		var file := FileAccess.open(_options.out, FileAccess.WRITE)
		file.store_string("\n".join(lines) + "\n")
	quit(0)


static func _categories(definition: MapDefinition) -> Dictionary:
	var result := {}
	var model := (load(definition.required_files[0]) as PackedScene).instantiate()
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		result[str(node.name)] = definition.category_rules.category_of(node)
	model.free()
	return result


static func _shown(category: String) -> String:
	return category if not category.is_empty() else "(none)"
