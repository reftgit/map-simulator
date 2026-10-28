class_name PatrolRoute
extends Resource
## Points an NPC walks between in order, starting over after the last, with
## a pause at each (AiPatrolInput). Part of a MapDefinition: one NPC per route.

## World positions; the NPC is placed on the first. Only x and z steer it;
## y is where it is placed and should be on the floor.
@export var points: Array[Vector3] = []
## Seconds the NPC stands at each point before walking on.
@export var wait_seconds := 1.5
