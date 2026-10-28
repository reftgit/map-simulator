class_name Npc
extends PlayerController
## Non-player character: the player's controller, states, and placeholder
## visual (in its own colour), driven by an AiPatrolInput along a
## PatrolRoute instead of touch. A punch on its Hurtbox starts the
## HitReaction state, after which it walks on. No damage, health, attacks,
## or pursuit. WorldManager places it (patrol()), respawns it at its own
## start below the kill height, and keeps it inside the bounds.
##
## Physics level of detail: farther than far_distance from `focus` (the
## player, set by Main) the NPC leaves the controller and is moved along its
## route by a Tween (the "far" mode: no script and no collision tests per
## tick; rays sample the floor once per segment); closer than near_distance
## the controller takes over again where it is. On the Galaxy Tab A7 a walking
## NPC under the controller cost about 1.7 ms per physics step, most of it
## script time, and a per-tick scripted far walk still about 0.7 ms (Phase 5).
## Far NPCs pass through walls and cars, so routes must be clear.

## A punch landed: `count` since the NPC was placed (one per punch, by the
## Hitbox rule).
signal hit(count: int)

## Far mode: the floor is sampled this often along a segment (m), and the
## distance to the player is checked this often (s).
const FLOOR_SAMPLE_SPACING := 2.0
const FAR_CHECK_INTERVAL := 0.25

## Distance from `focus` beyond which the NPC goes into the far mode (m); 0
## keeps the full controller at any distance.
@export var far_distance := 10.0
## Distance from `focus` within which it returns to the full controller (m).
@export var near_distance := 8.0

var hits := 0
## The body whose distance switches the far mode (the player); null keeps
## the full controller.
var focus: Node3D
## True while the Tween walks the NPC (far mode).
var far := false

var _far_check_in := 0.0
var _far_tween: Tween

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


## Also ends the far mode's walk (respawn, a new route); the next distance
## check starts it again from the new place.
func teleport(target: Transform3D) -> void:
	_leave_far()
	_far_check_in = 0.0
	super(target)


## The route's first point, facing the second. Set it as the transform before
## the NPC enters the tree: GodotPhysics3D moves a character body that is
## already in the space to a new transform only during the next physics step,
## so for that step other bodies would still meet it where it was.
static func start_transform(route: PatrolRoute) -> Transform3D:
	var ahead := route.points[1] - route.points[0] if route.points.size() > 1 else Vector3.FORWARD
	return Transform3D(Basis(Vector3.UP, atan2(-ahead.x, -ahead.z)), route.points[0])


func _physics_process(delta: float) -> void:
	_far_check_in -= delta
	if _far_check_in <= 0.0:
		_far_check_in = FAR_CHECK_INTERVAL
		_update_far()
	if not far:
		super(delta)


## Leaves the controller only from Idle or Walk, so a hit reaction plays out
## under it. Without a focus or with far_distance 0 it returns to the
## controller.
func _update_far() -> void:
	if focus == null or far_distance <= 0.0:
		if far:
			_leave_far()
		return
	var offset := focus.global_position - global_position
	var distance := Vector2(offset.x, offset.z).length()
	if far and distance < near_distance:
		_leave_far()
	elif not far and distance > far_distance and state_machine.get_state_name() in [&"Idle", &"Walk"] and patrol_input.route:
		far = true
		velocity = Vector3.ZERO
		_far_after_wait(patrol_input.wait_left())


func _leave_far() -> void:
	far = false
	if _far_tween:
		_far_tween.kill()
		_far_tween = null


## Far mode: stands for `seconds`, then walks to the patrol input's point.
func _far_after_wait(seconds: float) -> void:
	state_machine.transition_to(&"Idle")
	visual.set_locomotion(0.0, true)
	_far_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_far_tween.tween_interval(maxf(seconds, 0.0))
	_far_tween.tween_callback(_far_walk_segment)


## Far mode: walks straight to the patrol input's point at the speed the
## controller would walk, the feet on the floor sampled along the way, then
## reaches the point (the patrol input moves on) and waits there.
func _far_walk_segment() -> void:
	patrol_input.end_wait()
	var target: Vector3 = patrol_input.route.points[patrol_input.target_index]
	var start := global_position
	var flat := Vector3(target.x - start.x, 0.0, target.z - start.z)
	var length := flat.length()
	var speed := walk_speed * patrol_input.move_scale
	if length > 0.01:
		rotation.y = atan2(-flat.x, -flat.z)
	velocity = flat.normalized() * speed
	state_machine.transition_to(&"Walk")
	visual.set_locomotion(speed, true)
	_far_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var steps := maxi(1, ceili(length / FLOOR_SAMPLE_SPACING))
	var space := get_world_3d().direct_space_state
	for i in range(1, steps + 1):
		var point := start + flat * (float(i) / steps)
		point.y = lerpf(start.y, target.y, float(i) / steps)
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 3.0, 1, [get_rid()])
		var floor_hit := space.intersect_ray(ray)
		if not floor_hit.is_empty():
			point.y = floor_hit.position.y
		_far_tween.tween_property(self, "global_position", point, length / steps / speed)
	_far_tween.tween_callback(_far_reached)


func _far_reached() -> void:
	velocity = Vector3.ZERO
	patrol_input.reach_point()
	_far_after_wait(patrol_input.wait_left())


func _on_hit_received(attacker: Node3D) -> void:
	hits += 1
	hit_reaction.react(attacker)
	hit.emit(hits)
