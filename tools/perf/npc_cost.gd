extends SceneTree
## Physics step cost of the map's NPCs on this machine (headless): the
## physics step (Performance.TIME_PHYSICS_PROCESS) with the NPCs out of the
## simulation ("npcs": false), walking as in the game (in the far mode when
## farther than Npc.far_distance from the player, who stands at the spawn),
## and all under the full controller ("npc_far_mode": false), the player's
## physics paused and the parked vehicles asleep. Prints one line per mode and
## round and the cost per NPC against "off".
##   godot --headless --path . --script res://tools/perf/npc_cost.gd [-- --map=test_district --ticks=600 --rounds=3]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ticks := 600
	var rounds := 3
	var map := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ticks="):
			ticks = int(arg.trim_prefix("--ticks="))
		elif arg.begins_with("--rounds="):
			rounds = int(arg.trim_prefix("--rounds="))
		elif arg.begins_with("--map="):
			map = arg.trim_prefix("--map=")
	var game: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	game.requested_map = map
	root.add_child(game)
	await _frames(240)
	game.player.set_physics_process(false)
	var count: int = game.world.npcs.size()
	print("engine %s, map %s, %d NPCs, %d ticks per mode and round" % [Engine.get_version_info().string, game.map_definition.id, count, ticks])
	print("| Mode | Round | Physics step mean ms | Median ms | NPCs in the far mode |")
	print("|---|---|---|---|---|")
	var means := {"off": [], "game": [], "full": []}
	var far_distance: float = game.world.npcs[0].far_distance if count > 0 else 0.0
	for round in rounds:
		for mode in means:
			for npc in game.world.npcs:
				npc.far_distance = 0.0 if mode == "full" else far_distance
			game.apply_runtime_settings({"npcs": mode != "off"})
			await _frames(30)
			var samples: Array[float] = []
			for i in ticks:
				await physics_frame
				samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			samples.sort()
			var mean := 0.0
			for value in samples:
				mean += value / samples.size()
			means[mode].append(mean)
			var far: int = game.world.npcs.filter(func(npc: Npc) -> bool: return npc.far).size()
			print("| NPCs %s | %d | %.4f | %.4f | %d far |" % [mode, round + 1, mean, samples[samples.size() / 2], far])
	var medians := {}
	for mode in means:
		var sorted: Array = means[mode].duplicate()
		sorted.sort()
		medians[mode] = sorted[sorted.size() / 2]
	for mode in ["game", "full"]:
		var difference: float = medians[mode] - medians.off
		print("median of round means: %s %.4f ms, off %.4f ms, difference %.4f ms, per NPC %.4f ms" % [mode, medians[mode], medians.off, difference, difference / maxi(count, 1)])
	quit()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
