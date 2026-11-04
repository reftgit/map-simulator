class_name WorldManager
extends Node3D
## Loads the active map and keeps tracked bodies inside it: respawns them below
## the kill height (at their own spawn, or the map's player spawn) and holds
## them inside the playable bounds. Parks the map's vehicles (which reset
## themselves) and places its NPCs. A map with a streaming index loads its
## resident scene and a MapStreamer for its cells (docs/STREAMING.md). Knows
## nothing about input, camera, or UI.

signal map_loaded(definition: MapDefinition)
## unload_map_and_wait() has seen the map `id`, its vehicles, and its NPCs freed.
signal map_unloaded(id: String)
signal body_respawned(body: Node3D)

## Frames unload_map_and_wait() waits after the old map's nodes are gone: the
## rendering device keeps freed meshes and textures until the frames still in
## flight (two by default) have finished with them.
const RELEASE_FRAMES := 3

var definition: MapDefinition
var map_root: Node
## Streams the loaded map's visibility-range meshes; null when the map loaded
## whole (no usable index, or `streaming` off).
var streamer: MapStreamer
## Whether load_map() may stream (measurement: false loads every map whole).
var streaming := true
## Measurement: an index to use instead of the definition's (another cell size).
var streaming_index_override := ""
## The last load_map(): whether it streamed, and the milliseconds for the
## streaming index's check, loading the scene, and instancing it.
var load_report := {}
## Vehicles placed by spawn_vehicles().
var vehicles: Array[VehicleController] = []
## NPCs placed by spawn_npcs().
var npcs: Array[Npc] = []

var _tracked: Array[Node3D] = []
## Respawn transform per tracked body that has its own (track()).
var _spawns := {}


func load_map(new_definition: MapDefinition) -> void:
	unload_map()
	definition = new_definition
	var started := Time.get_ticks_usec()
	var index := _streaming_index() if streaming else null
	var checked := Time.get_ticks_usec()
	var scene_path := index.resident_scene if index else definition.scene_path
	var packed := load(scene_path) as PackedScene
	assert(packed != null, "Map scene failed to load: %s" % scene_path)
	var loaded := Time.get_ticks_usec()
	map_root = packed.instantiate()
	add_child(map_root)
	load_report = {"streamed": index != null, "index_ms": snappedf((checked - started) / 1000.0, 0.1),
			"scene_ms": snappedf((loaded - checked) / 1000.0, 0.1), "instantiate_ms": snappedf((Time.get_ticks_usec() - loaded) / 1000.0, 0.1)}
	if index:
		streamer = MapStreamer.new()
		streamer.name = "MapStreamer"
		add_child(streamer)
		streamer.setup(map_root, index)
	map_loaded.emit(definition)


## The definition's streaming index (or the override), if it can be used.
func _streaming_index() -> MapStreamingIndex:
	if streaming_index_override.is_empty():
		return MapStreamingIndex.load_for(definition)
	var override := definition.duplicate() as MapDefinition
	override.streaming_index_path = streaming_index_override
	return MapStreamingIndex.load_for(override)


func unload_map() -> void:
	if streamer:
		streamer.shutdown()
		streamer.queue_free()
		streamer = null
	if map_root:
		map_root.queue_free()
		map_root = null
	for vehicle in vehicles:
		vehicle.queue_free()
	vehicles.clear()
	for npc in npcs:
		untrack(npc)
		npc.queue_free()
	npcs.clear()
	definition = null


## unload_map(), then waits until the map, its vehicles, and its NPCs are
## freed (queue_free() frees them at the end of the frame) and RELEASE_FRAMES
## more frames. A map switch loads the next map only after this, so two maps
## are never in memory at once (loading one beside the other got the app
## killed for memory on a 3 GB tablet). Returns the frames it waited.
func unload_map_and_wait() -> int:
	var freed := []
	freed.append_array(vehicles)
	freed.append_array(npcs)
	if map_root:
		freed.append(map_root)
	if streamer:
		freed.append(streamer)
	var id := definition.id if definition else ""
	unload_map()
	var frames := 0
	while freed.any(func(node: Variant) -> bool: return is_instance_valid(node)):
		await get_tree().process_frame
		frames += 1
	for i in RELEASE_FRAMES:
		await get_tree().process_frame
	map_unloaded.emit(id)
	return frames + RELEASE_FRAMES


## Parks a vehicle at each of the map's vehicle spawns: the spawn's type
## from MapDefinition.vehicle_scenes, else `scene`. Each resets there, and
## below the map's kill height.
func spawn_vehicles(scene: PackedScene) -> Array[VehicleController]:
	for i in definition.vehicle_spawns.size():
		var typed := i < definition.vehicle_scenes.size() and definition.vehicle_scenes[i] != null
		var vehicle := (definition.vehicle_scenes[i] if typed else scene).instantiate() as VehicleController
		add_child(vehicle)
		vehicle.place_at(definition.vehicle_spawns[i], true)
		vehicle.kill_height = definition.kill_height
		vehicles.append(vehicle)
	return vehicles


## Places an instance of `scene` on each of the map's NPC routes and tracks
## it, so it respawns at its own start below the kill height and stays
## inside the bounds.
func spawn_npcs(scene: PackedScene) -> Array[Npc]:
	for route in definition.npc_routes:
		var npc := scene.instantiate() as Npc
		npc.name = "Npc%d" % (npcs.size() + 1)
		npc.transform = Npc.start_transform(route)
		add_child(npc)
		npc.patrol(route)
		track(npc, npc.global_transform)
		npcs.append(npc)
	return npcs


func get_spawn_transform() -> Transform3D:
	var facing := Basis(Vector3.UP, deg_to_rad(definition.player_spawn_yaw_degrees))
	return Transform3D(facing, definition.player_spawn_position)


## Keeps `body` inside the map; it respawns at `spawn` (a Transform3D) if
## given, else at the map's player spawn.
func track(body: Node3D, spawn: Variant = null) -> void:
	if body not in _tracked:
		_tracked.append(body)
	if spawn is Transform3D:
		_spawns[body] = spawn


func untrack(body: Node3D) -> void:
	_tracked.erase(body)
	_spawns.erase(body)


func respawn(body: Node3D) -> void:
	var target: Transform3D = _spawns.get(body, get_spawn_transform())
	if body.has_method(&"teleport"):
		body.teleport(target)
	else:
		body.global_transform = target
		body.reset_physics_interpolation()
	body_respawned.emit(body)


func _physics_process(_delta: float) -> void:
	if definition == null:
		return
	var area := definition.bounds
	for body in _tracked:
		if not is_instance_valid(body):
			continue
		var p := body.global_position
		if p.y < definition.kill_height:
			respawn(body)
		elif area.has_area():
			var inside := Vector3(clampf(p.x, area.position.x, area.end.x), p.y, clampf(p.z, area.position.y, area.end.y))
			if inside != p:
				body.global_position = inside
				body.reset_physics_interpolation()
