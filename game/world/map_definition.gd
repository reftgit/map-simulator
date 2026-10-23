class_name MapDefinition
extends Resource
## What gameplay needs to know about a map. A new map is a scene plus one of
## these resources; player, camera, and input code stay unchanged.

@export var display_name := ""
@export_file("*.tscn") var scene_path := ""
@export var player_spawn_position := Vector3.ZERO
## Facing at spawn; 0 looks north (-Z).
@export var player_spawn_yaw_degrees := 0.0
## Playable area on the ground plane: x is world X, y is world Z.
@export var bounds := Rect2()
## Bodies that fall below this height are respawned.
@export var kill_height := -5.0
