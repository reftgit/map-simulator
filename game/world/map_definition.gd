class_name MapDefinition
extends Resource
## What gameplay needs to know about a map. A new map is a scene plus one of
## these resources; player, camera, and input code stay unchanged.

## Short name for --map=<id>, experiments, and logs (MapRegistry).
@export var id := ""
@export var display_name := ""
@export_file("*.tscn") var scene_path := ""
@export var player_spawn_position := Vector3.ZERO
## Facing at spawn; 0 looks north (-Z).
@export var player_spawn_yaw_degrees := 0.0
## Playable area on the ground plane: x is world X, y is world Z.
@export var bounds := Rect2()
## Bodies that fall below this height are respawned.
@export var kill_height := -5.0
## Vehicles parked at load, one per entry; they reset here. Like the player
## spawn, a transform faces its -Z; VehicleController.place_at() turns the
## vehicle body, which drives along +Z, to match.
@export var vehicle_spawns: Array[Transform3D] = []
## Vehicle type per entry of vehicle_spawns, in the same order; a missing or
## empty entry parks Main.vehicle_scene there.
@export var vehicle_scenes: Array[PackedScene] = []
## Baked OccluderInstance3D scene (tools/bake_occluders.gd). Without it,
## occluders are built from the map's collision at load and a warning is logged.
@export_file("*.scn", "*.tscn") var occluders_path := ""

@export_group("Debug")
## Fixed player positions for repeatable performance measurements, cycled
## with the debug overlay's VIEW button in debug builds.
@export var debug_viewpoints: Array[Transform3D] = []
## Array[String], not PackedStringArray: Godot 4.7.2's export conversion of
## text resources dropped a PackedStringArray here (seen on device 2026-10-24).
@export var debug_viewpoint_names: Array[String] = []
