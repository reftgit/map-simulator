extends SceneTree
## Checks a release preset before tools/build_release.sh exports it
## (tools/release_package.gd): its exclude filter is the one written from the
## release registry, it packs exactly what the maps of the release registry
## need, without perf_bench, and every release map's cells are written and
## current against its model on this machine. When they are not, it says
## which command writes them.
##   godot --headless --path . --script res://tools/check_release.gd -- "Android Release" [--list=<file>]
## --list=<file> (a path on disk) writes the project files the package should
## hold, one res:// path per line, for tools/release_contents.py to compare
## with the package. Exit code 0 when the preset can be exported, 1 when not,
## 2 for bad arguments.

const ReleasePackage := preload("res://tools/release_package.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var name := ""
	var list := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--list="):
			list = arg.trim_prefix("--list=")
		elif not arg.begins_with("--"):
			name = arg
	if name not in ReleasePackage.RELEASE_PRESETS:
		printerr("usage: -- \"%s\" [--list=<file>]" % "\" | \"".join(ReleasePackage.RELEASE_PRESETS))
		quit(2)
		return
	var problems := ReleasePackage.problems(name, true)
	for problem in problems:
		printerr("RELEASE ", problem)
	if not problems.is_empty():
		printerr("RELEASE %s: not ready to export (%d problems)" % [name, problems.size()])
		quit(1)
		return
	var packed := ReleasePackage.packed_files(ReleasePackage.preset(name).exclude)
	if not list.is_empty():
		var file := FileAccess.open(list, FileAccess.WRITE)
		if file == null:
			printerr("RELEASE cannot write %s" % list)
			quit(1)
			return
		file.store_string("\n".join(packed) + "\n")
	var registry := load(MapRegistry.RELEASE_PATH) as MapRegistry
	print("RELEASE %s: ready; maps %s; %d project files" % [name, registry.ids(), packed.size()])
	quit(0)
