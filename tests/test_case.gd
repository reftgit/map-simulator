extends RefCounted
## Base for headless tests run by tests/run_tests.gd. Test methods start with
## "test_" and may await. Each test gets a fresh instance; nodes added through
## add_node() are freed afterwards.

var tree: SceneTree
var failures: Array[String] = []

var _nodes: Array[Node] = []


func add_node(node: Node) -> Node:
	tree.root.add_child(node)
	_nodes.append(node)
	return node


func instantiate(path: String) -> Node:
	return add_node((load(path) as PackedScene).instantiate())


## Static box on the world layer. With default arguments, a 200 m floor whose top is at y = 0.
func add_static_box(size := Vector3(200, 1, 200), center := Vector3(0, -0.5, 0)) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	add_node(body)
	return body


func physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


func process_frames(count: int) -> void:
	for i in count:
		await tree.process_frame


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s (got %.4f, expected %.4f ± %.4f)" % [message, actual, expected, tolerance])


## Sends an event through Godot's real input pipeline (touch-to-mouse emulation,
## _input, GUI), the same path device input takes.
func send_input(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## Positions are in HUD canvas units; devices report window pixels, so they are
## converted with the root stretch transform (identity in headless runs).
func touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = tree.root.get_final_transform() * position
	event.pressed = pressed
	send_input(event)


func drag(index: int, from: Vector2, to: Vector2) -> void:
	var to_window := tree.root.get_final_transform()
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = to_window * to
	event.relative = to_window.basis_xform(to - from)
	send_input(event)


func cleanup() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	_nodes.clear()
	Input.action_release(&"move_forward")
	Input.action_release(&"move_back")
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"run")
	await tree.process_frame
	await tree.physics_frame
