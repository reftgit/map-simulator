extends "res://tests/test_case.gd"
## The map generator's data folders stay out of Godot: without their
## .gdignore, Godot would import the elevation PNGs and pack the OSM extract
## and the JSON records into every build (PROJECT_CONTEXT.md, T39). The same
## holds for the import tool's committed source GLBs (the Kenney town of
## Phase 6a, the two blind-test maps of Phase 6b): only processed models are
## game files.

const FOLDERS := ["res://maps/istanbul_halic/source", "res://maps/istanbul_halic/reference", "res://maps/kenney_town/source",
		"res://maps/abstract_city/source", "res://maps/apollo11_site/source"]


func test_generator_data_folders_carry_a_gdignore() -> void:
	for folder: String in FOLDERS:
		check(DirAccess.dir_exists_absolute(folder), "%s exists" % folder)
		check(FileAccess.file_exists(folder.path_join(".gdignore")), "%s has a .gdignore" % folder)
	check(FileAccess.file_exists("res://build/.gdignore"), "build/ (generator output and exports) has a .gdignore")


func test_nothing_in_them_was_imported() -> void:
	var imported: Array[String] = []
	var pending: Array[String] = []
	pending.assign(FOLDERS)
	var files := 0
	while not pending.is_empty():
		var folder: String = pending.pop_back()
		for name in DirAccess.get_files_at(folder):
			files += 1
			if name.ends_with(".import"):
				imported.append(folder.path_join(name))
		for name in DirAccess.get_directories_at(folder):
			pending.append(folder.path_join(name))
	check(files >= 20, "the data files are there (%d)" % files)
	check(imported.is_empty(), "no .import files beside them: %s" % [imported])
