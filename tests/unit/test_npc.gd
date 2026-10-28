extends "res://tests/test_case.gd"
## NPCs (Phase 5) on a flat floor: the player's controller and states driven
## by AiPatrolInput along a PatrolRoute, the hit reaction, and the collision
## layers between NPCs and the player.

const NPC := "res://game/npc/npc.tscn"
const TICK := 1.0 / 60.0


class ScriptedInput extends PlayerInputSource:
	var move := Vector3.ZERO
	var _punch := false

	func press_punch() -> void:
		_punch = true

	func fill_intent(intent: PlayerIntent, _player: PlayerController) -> void:
		intent.move = move
		intent.punch = _punch
		_punch = false


func _route(points: Array, wait := 1.0) -> PatrolRoute:
	var route := PatrolRoute.new()
	route.points.assign(points)
	route.wait_seconds = wait
	return route


## Bodies get their transform before they enter the tree (Npc.start_transform()).
func _npc(route: PatrolRoute) -> Npc:
	var npc: Npc = (load(NPC) as PackedScene).instantiate()
	npc.transform = Npc.start_transform(route)
	add_node(npc)
	npc.patrol(route)
	return npc


func _player_at(position: Vector3) -> PlayerController:
	var player: PlayerController = (load("res://game/player/player.tscn") as PackedScene).instantiate()
	player.position = position
	add_node(player)
	return player


func _ticks_until(predicate: Callable, max_ticks: int) -> int:
	for i in max_ticks:
		if predicate.call():
			return i
		await tree.physics_frame
	return max_ticks if predicate.call() else -1


func _flat(npc: Npc) -> Vector3:
	return Vector3(npc.global_position.x, 0.0, npc.global_position.z)


func test_npc_is_the_player_controller_with_its_own_parts() -> void:
	add_static_box()
	var npc := _npc(_route([Vector3(0, 0.1, 0), Vector3(0, 0.1, -5)]))
	check(npc is PlayerController and npc.input_source == npc.patrol_input, "the player's controller, driven by the patrol input")
	var states: Array[StringName] = []
	for state in npc.state_machine.get_children():
		states.append(state.name)
	check(states == ([&"Idle", &"Walk", &"Run", &"Punch", &"Roll", &"HitReaction"] as Array[StringName]), "the player's states plus HitReaction (%s)" % [states])
	check(npc.collision_layer == 16 and npc.collision_mask == 1 | 2 | 8 | 16, "NPC layer; collides with world, player, vehicles, NPCs")
	check(npc.hurtbox.collision_layer == 4 and npc.hurtbox.monitorable, "hurtbox on the hurtbox layer")
	var player: PlayerController = instantiate("res://game/player/player.tscn")
	check(player.collision_mask & 16, "the player collides with NPCs")
	var body := npc.get_node("Visual/Pivot/Body") as MeshInstance3D
	var player_body := player.get_node("Visual/Pivot/Body") as MeshInstance3D
	check((body.mesh.material as StandardMaterial3D).albedo_color != (player_body.mesh.material as StandardMaterial3D).albedo_color, "its own colour")


func test_patrol_walks_waits_and_loops() -> void:
	add_static_box()
	var npc := _npc(_route([Vector3(0, 0.1, 0), Vector3(0, 0.1, -8)], 1.0))
	var arrivals: Array[int] = []
	npc.patrol_input.arrived.connect(func(index: int) -> void: arrivals.append(index))
	check(_flat(npc).distance_to(Vector3.ZERO) < 0.01 and (-npc.global_basis.z).dot(Vector3.FORWARD) > 0.99, "placed on the first point facing the second")
	await physics_frames(60)
	check(npc.state_machine.get_state_name() == &"Walk", "walking (%s)" % npc.state_machine.get_state_name())
	check_near(npc.get_horizontal_speed(), npc.walk_speed * npc.patrol_input.move_scale, 0.05, "walks at half the walk speed")
	var ticks := await _ticks_until(func() -> bool: return arrivals.size() == 1, 300)
	check(ticks >= 0 and arrivals[0] == 1, "reached the second point (%d ticks)" % ticks)
	check(_flat(npc).distance_to(Vector3(0, 0, -8)) < npc.patrol_input.arrive_distance + 0.1, "stands at it (%s)" % npc.global_position)
	await physics_frames(30)
	check(npc.patrol_input.is_waiting() and npc.get_horizontal_speed() < 0.3, "waits there")
	await physics_frames(60)
	check(npc.patrol_input.target_index == 0 and npc.state_machine.get_state_name() == &"Walk", "after the wait, back toward the first point")
	ticks = await _ticks_until(func() -> bool: return arrivals.size() == 2, 360)
	check(ticks >= 0 and arrivals[1] == 0, "loops to the first point")


func test_gives_up_a_blocked_point() -> void:
	add_static_box()
	add_static_box(Vector3(10, 3, 1), Vector3(0, 1.5, -4))
	var npc := _npc(_route([Vector3(0, 0.1, 0), Vector3(0, 0.1, -10), Vector3(6, 0.1, 0)], 0.5))
	var gave_up: Array[int] = []
	var arrivals: Array[int] = []
	npc.patrol_input.gave_up.connect(func(index: int) -> void: gave_up.append(index))
	npc.patrol_input.arrived.connect(func(index: int) -> void: arrivals.append(index))
	var ticks := await _ticks_until(func() -> bool: return not gave_up.is_empty(), 360)
	check(ticks >= 0 and gave_up[0] == 1, "gave up the point behind the wall (%d ticks)" % ticks)
	check(ticks * TICK >= npc.patrol_input.stuck_seconds, "only after %.1f s without progress (%.2f s)" % [npc.patrol_input.stuck_seconds, ticks * TICK])
	check(npc.global_position.z > -3.6, "stopped at the wall (%s)" % npc.global_position)
	ticks = await _ticks_until(func() -> bool: return arrivals.has(2), 480)
	check(ticks >= 0, "walked on to the next point")


func test_hit_reaction_then_patrol_resumes() -> void:
	add_static_box()
	var npc := _npc(_route([Vector3(0, 0.1, 0), Vector3(0, 0.1, -12)], 0.5))
	await physics_frames(30)
	var attacker := Node3D.new()
	add_node(attacker)
	attacker.global_position = npc.global_position + Vector3(0, 0, 1)
	var target_before: int = npc.patrol_input.target_index
	npc.hurtbox.receive_hit(attacker)
	check(npc.hits == 1 and npc.state_machine.get_state_name() == &"HitReaction", "a hit starts the reaction")
	var z_at_hit := npc.global_position.z
	await physics_frames(2)
	check(npc.velocity.z < -1.5 and npc.velocity.z > -2.1, "pushed away from the attacker (%s)" % npc.velocity)
	var samples: Array[StringName] = []
	for i in 40:
		await tree.physics_frame
		samples.append(npc.state_machine.get_state_name())
	var reacting := samples.count(&"HitReaction")
	check(reacting >= 26 and reacting <= 30, "reaction lasts about %.1f s (%d of 40 ticks after the first 2)" % [npc.hit_reaction.duration, reacting])
	check(samples.back() == &"Walk", "walks again afterwards (%s)" % samples.back())
	check(npc.global_position.z < z_at_hit - 0.3, "moved on along the route")
	check(npc.patrol_input.target_index == target_before, "still heading for the same point")
	var arrived := await _ticks_until(func() -> bool: return npc.patrol_input.target_index != target_before, 600)
	check(arrived >= 0, "reaches it after the reaction")


func test_second_hit_restarts_the_reaction() -> void:
	add_static_box()
	var npc := _npc(_route([Vector3(0, 0.1, 0), Vector3(0, 0.1, -12)], 0.5))
	await physics_frames(10)
	npc.hurtbox.receive_hit(null)
	await physics_frames(20)
	npc.hurtbox.receive_hit(null)
	check(npc.hits == 2, "both hits counted")
	await physics_frames(25)
	check(npc.state_machine.get_state_name() == &"HitReaction", "still reacting 0.75 s after the first hit")
	var ticks := await _ticks_until(func() -> bool: return npc.state_machine.get_state_name() != &"HitReaction", 30)
	check(ticks >= 0 and ticks <= 8, "ends about 0.5 s after the second hit (%d more ticks)" % ticks)


func test_player_punch_hits_once_and_the_npc_reacts() -> void:
	add_static_box()
	var player := _player_at(Vector3(0, 0.1, 0))
	var source := ScriptedInput.new()
	add_node(source)
	player.input_source = source
	# The NPC crosses in front of the player, 1.1 m ahead.
	var npc := _npc(_route([Vector3(-5, 0.1, -1.1), Vector3(5, 0.1, -1.1)], 0.5))
	var ready := await _ticks_until(func() -> bool: return npc.global_position.x > -0.35, 240)
	check(ready >= 0, "the NPC walks in front of the player")
	source.press_punch()
	var hit_tick := await _ticks_until(func() -> bool: return npc.hits > 0, 30)
	check(hit_tick >= 0, "the punch hits the NPC (%d ticks)" % hit_tick)
	check(npc.state_machine.get_state_name() == &"HitReaction", "and starts its reaction")
	await physics_frames(40)
	check(npc.hits == 1, "one hit for one punch although the NPC stayed in reach (%d)" % npc.hits)
	check(player.state_machine.get_state_name() == &"Idle", "the player's punch ended normally")
	await physics_frames(30)
	check(npc.state_machine.get_state_name() == &"Walk" and npc.patrol_input.target_index == 1, "the NPC walks on toward its point")


func test_npc_and_player_block_each_other() -> void:
	add_static_box()
	var player := _player_at(Vector3(0, 0.1, 3))
	var source := ScriptedInput.new()
	add_node(source)
	player.input_source = source
	var npc := _npc(_route([Vector3(0, 0.1, 0), Vector3(0, 0.1, -0.2)], 30.0))
	await physics_frames(60)
	source.move = Vector3(0, 0, -1)
	await physics_frames(90)
	check(player.global_position.z > npc.global_position.z + 0.6, "the player stops at the NPC instead of passing through (player z %.2f, NPC z %.2f)" % [player.global_position.z, npc.global_position.z])
	check(absf(npc.global_position.y) < 0.05 and absf(player.global_position.y) < 0.05, "both stay on the floor")
