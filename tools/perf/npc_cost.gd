extends SceneTree
## Physics step cost of the map's NPCs on this machine (headless): the
## physics step (Performance.TIME_PHYSICS_PROCESS) with the NPCs walking
## their routes and with them out of the simulation (the "npcs": false
## runtime key), the player's physics paused and the parked vehicles asleep.
## Prints one line per mode and round and the cost per NPC.
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
	print("| Mode | Round | Physics step mean ms | Median ms |")
	print("|---|---|---|---|")
	var means := {"on": [], "off": []}
	for round in rounds:
		for mode in ["on", "off"]:
			game.apply_runtime_settings({"npcs": mode == "on"})
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
			print("| NPCs %s | %d | %.4f | %.4f |" % [mode, round + 1, mean, samples[samples.size() / 2]])
	var on: Array = means.on.duplicate()
	var off: Array = means.off.duplicate()
	on.sort()
	off.sort()
	var difference: float = on[on.size() / 2] - off[off.size() / 2]
	print("median of round means: on %.4f ms, off %.4f ms, difference %.4f ms, per NPC %.4f ms" % [on[on.size() / 2], off[off.size() / 2], difference, difference / maxi(count, 1)])
	quit()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
