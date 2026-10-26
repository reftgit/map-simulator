extends SceneTree
## Physics step cost of the parked vehicle in each rest state on the real map
## (headless, on this machine): awake (parking sleep off), asleep
## (RigidBody3D.sleeping, what VehicleController uses), frozen (freeze in
## static mode), and removed (out of the simulation: the Phase 4a
## "vehicles": false upper bound). The player's physics is paused so the
## vehicle is the only moving part. Prints one line per mode and round: mean
## and median physics step (Performance.TIME_PHYSICS_PROCESS) and the most
## active bodies the physics server reported. Then throws a 400 kg box at
## the asleep and at the frozen vehicle and reports what happens.
##   godot --headless --path . --script res://tools/perf/vehicle_sleep_cost.gd [-- --ticks=600 --rounds=3]

const MODES := ["awake", "asleep", "frozen", "removed"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ticks := 600
	var rounds := 3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ticks="):
			ticks = int(arg.trim_prefix("--ticks="))
		elif arg.begins_with("--rounds="):
			rounds = int(arg.trim_prefix("--rounds="))
	var game: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _frames(120)
	game.player.set_physics_process(false)
	var car: VehicleController = game.world.vehicles[0]
	# The tool sets each state itself.
	car.definition = car.definition.duplicate()
	car.definition.sleep_when_parked = false
	print("engine %s, %d ticks per mode and round" % [Engine.get_version_info().string, ticks])
	print("| Mode | Round | Physics step mean ms | Median ms | Active bodies |")
	print("|---|---|---|---|---|")
	for round in rounds:
		for mode in MODES:
			_set_mode(car, mode)
			await _frames(30)
			var samples: Array[float] = []
			var active := 0
			for i in ticks:
				await physics_frame
				samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
				active = maxi(active, PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS))
			samples.sort()
			var mean := 0.0
			for value in samples:
				mean += value / samples.size()
			print("| %s | %d | %.4f | %.4f | %d |" % [mode, round + 1, mean, samples[samples.size() / 2], active])
	for mode in ["asleep", "frozen"]:
		_set_mode(car, "awake")
		car.reset_to_spawn()
		await _frames(120)
		_set_mode(car, mode)
		await _frames(5)
		var start := car.global_position
		var box := RigidBody3D.new()
		box.mass = 400.0
		box.collision_mask = 9
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		box.add_child(shape)
		# Placed before entering the tree, 4 m behind the car, thrown at it.
		box.position = car.to_global(Vector3(0, 1.0, -4.0))
		box.linear_velocity = car.global_basis.z * 8.0
		root.add_child(box)
		await _frames(90)
		print("box hit, %s: vehicle moved %.3f m, simulated afterwards: %s" % [mode, car.global_position.distance_to(start), not car.is_asleep()])
		box.queue_free()
	quit()


func _set_mode(car: VehicleController, mode: String) -> void:
	car.process_mode = Node.PROCESS_MODE_INHERIT
	car.freeze = false
	car.sleeping = false
	match mode:
		"asleep":
			car.sleeping = true
		"frozen":
			car.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			car.freeze = true
		"removed":
			car.process_mode = Node.PROCESS_MODE_DISABLED


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
