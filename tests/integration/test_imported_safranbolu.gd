extends "res://tests/integration/imported_map_case.gd"
## The user's Safranbolu package (Phase 6a) as a test input only: imported to
## tests/imported/safranbolu_test/ (out of Git and of every export) from the
## package's GLB, which has no normals and no colliders and whose roads run
## through buildings. Skipped without it.


func definition_path() -> String:
	return "res://tests/imported/safranbolu_test/safranbolu_test.tres"


func regenerate_hint() -> String:
	return "import the Safranbolu GLB as in docs/maps/imported/safranbolu_test.md"


func expected_categories() -> Dictionary:
	return {"buildings": 600, "facade_detail": 523, "ground": 50}
