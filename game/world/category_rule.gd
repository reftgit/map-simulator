class_name CategoryRule
extends Resource
## One line of a map's CategoryRules: meshes that match `pattern` the way
## `kind` says belong to `category` (one of CategoryRules.CATEGORIES).

@export var category := ""
## prefix: the node name starts with the pattern. regex: the pattern (RegEx)
## is found in the node name. words: a word of the node name starts with one
## of the pattern's space-separated words, ignoring case (CategoryRules.words_of()).
## material: the pattern (RegEx) is found in the name of one of the mesh's
## surface materials. group: the node is in the Godot group named by the pattern.
@export_enum("prefix", "regex", "words", "material", "group") var kind := "prefix"
@export var pattern := ""

var _regex: RegEx
var _words := PackedStringArray()


static func create(rule_category: String, rule_kind: String, rule_pattern: String) -> CategoryRule:
	var rule := CategoryRule.new()
	rule.category = rule_category
	rule.kind = rule_kind
	rule.pattern = rule_pattern
	return rule


## Whether `node` (named `node_name`; usually a MeshInstance3D) matches.
func matches(node: Node, node_name: String) -> bool:
	match kind:
		"prefix":
			return node_name.begins_with(pattern)
		"regex":
			return _compiled().search(node_name) != null
		"words":
			if _words.is_empty():
				_words = pattern.to_lower().split(" ", false)
			for word in CategoryRules.words_of(node_name):
				for start in _words:
					if word.begins_with(start):
						return true
			return false
		"material":
			var mesh_instance := node as MeshInstance3D
			if mesh_instance == null or mesh_instance.mesh == null:
				return false
			for surface in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.get_active_material(surface)
				if material and _compiled().search(material.resource_name) != null:
					return true
			return false
		"group":
			return node.is_in_group(pattern)
	return false


func _compiled() -> RegEx:
	if _regex == null:
		_regex = RegEx.create_from_string(pattern)
	return _regex
