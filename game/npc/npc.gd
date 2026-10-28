class_name Npc
extends PlayerController
## Non-player character: the player's controller, states, and placeholder
## visual (in its own colour), driven by an AiPatrolInput along a
## PatrolRoute instead of touch. A punch on its Hurtbox starts the
## HitReaction state, after which it walks on. No damage, health, attacks,
## or pursuit. WorldManager places it (patrol()), respawns it at its own
## start below the kill height, and keeps it inside the bounds.

## A punch landed: `count` since the NPC was placed (one per punch, by the
## Hitbox rule).
signal hit(count: int)

var hits := 0

@onready var patrol_input: AiPatrolInput = $AiPatrolInput
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hit_reaction: HitReactionState = $StateMachine/HitReaction


func _ready() -> void:
	super()
	input_source = patrol_input
	hurtbox.hit_received.connect(_on_hit_received)


## Puts the NPC on the route's first point, facing the second, and walks
## the route from there.
func patrol(route: PatrolRoute) -> void:
	patrol_input.route = route
	teleport(start_transform(route))


## The route's first point, facing the second. Set it as the transform before
## the NPC enters the tree: GodotPhysics3D moves a character body that is
## already in the space to a new transform only during the next physics step,
## so for that step other bodies would still meet it where it was.
static func start_transform(route: PatrolRoute) -> Transform3D:
	var ahead := route.points[1] - route.points[0] if route.points.size() > 1 else Vector3.FORWARD
	return Transform3D(Basis(Vector3.UP, atan2(-ahead.x, -ahead.z)), route.points[0])


func _on_hit_received(attacker: Node3D) -> void:
	hits += 1
	hit_reaction.react(attacker)
	hit.emit(hits)
