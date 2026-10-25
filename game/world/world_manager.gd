class_name WorldManager
extends Node3D
## Loads the active map and keeps tracked bodies inside it: respawns them below
## the kill height and holds them inside the playable bounds. Parks the map's
## vehicles (which reset themselves). Knows nothing about input, camera, or UI.

signal map_loaded(definition: MapDefinition)
signal body_respawned(body: Node3D)

var definition: MapDefinition
var map_root: Node
## Vehicles placed by spawn_vehicles().
var vehicles: Array[VehicleController] = []

var _tracked: Array[Node3D] = []


func load_map(new_definition: MapDefinition) -> void:
	unload_map()
	definition = new_definition
	var packed := load(definition.scene_path) as PackedScene
	assert(packed != null, "Map scene failed to load: %s" % definition.scene_path)
	map_root = packed.instantiate()
	add_child(map_root)
	map_loaded.emit(definition)


func unload_map() -> void:
	if map_root:
		map_root.queue_free()
		map_root = null
	for vehicle in vehicles:
		vehicle.queue_free()
	vehicles.clear()
	definition = null


## Parks an instance of `scene` at each of the map's vehicle spawns; each
## resets there, and below the map's kill height.
func spawn_vehicles(scene: PackedScene) -> Array[VehicleController]:
	for spawn in definition.vehicle_spawns:
		var vehicle := scene.instantiate() as VehicleController
		add_child(vehicle)
		vehicle.place_at(spawn, true)
		vehicle.kill_height = definition.kill_height
		vehicles.append(vehicle)
	return vehicles


func get_spawn_transform() -> Transform3D:
	var facing := Basis(Vector3.UP, deg_to_rad(definition.player_spawn_yaw_degrees))
	return Transform3D(facing, definition.player_spawn_position)


func track(body: Node3D) -> void:
	if body not in _tracked:
		_tracked.append(body)


func untrack(body: Node3D) -> void:
	_tracked.erase(body)


func respawn(body: Node3D) -> void:
	if body.has_method(&"teleport"):
		body.teleport(get_spawn_transform())
	else:
		body.global_transform = get_spawn_transform()
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
