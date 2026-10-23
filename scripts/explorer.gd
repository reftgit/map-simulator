extends CharacterBody3D
## Small inspection controller. One metre = one Godot unit.
var flying := true
var map_bounds := Rect2(-1940, -1560, 2700, 2680)
var camera: Camera3D
var pitch := -0.30
var yaw := 0.0
var walk_spawn := Vector3(-100.0, 8.0, 250.0)

func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.far = 8000.0
	camera.near = 0.1
	camera.fov = 68.0
	camera.position.y = 1.7
	add_child(camera)
	camera.current = true
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)
	set_view(Vector3(140, 380, -740), Vector3(-95, 0, -10))

func set_view(eye: Vector3, target: Vector3) -> void:
	flying = true
	velocity = Vector3.ZERO
	global_position = eye
	rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.look_at(target)
	var euler := camera.rotation
	yaw = euler.y
	pitch = euler.x
	rotation.y = yaw
	camera.rotation = Vector3(pitch, 0, 0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0024
		pitch = clampf(pitch - event.relative.y * 0.0024, -1.50, 1.50)
		rotation.y = yaw
		camera.rotation.x = pitch
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if event.keycode == KEY_F:
			flying = not flying
			velocity = Vector3.ZERO
			if not flying:
				global_position = walk_spawn
				pitch = 0.0
				camera.rotation.x = pitch
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if event.keycode == KEY_R:
			global_position = walk_spawn
			velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): direction.z -= 1
	if Input.is_physical_key_pressed(KEY_S): direction.z += 1
	if Input.is_physical_key_pressed(KEY_A): direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D): direction.x += 1
	var fast := Input.is_physical_key_pressed(KEY_SHIFT)
	if flying:
		var movement := camera.global_basis * direction
		if Input.is_physical_key_pressed(KEY_E): movement.y += 1
		if Input.is_physical_key_pressed(KEY_Q): movement.y -= 1
		global_position += movement.normalized() * (130.0 if fast else 38.0) * delta
	else:
		var movement := global_basis * direction.normalized()
		velocity.x = movement.x * (8.0 if fast else 4.5)
		velocity.z = movement.z * (8.0 if fast else 4.5)
		if not is_on_floor(): velocity.y -= 24.0 * delta
		elif Input.is_physical_key_pressed(KEY_SPACE): velocity.y = 7.5
		else: velocity.y = -0.4
		move_and_slide()
		if global_position.y < -5.0:
			global_position = walk_spawn
			velocity = Vector3.ZERO
		global_position.x = clampf(global_position.x, map_bounds.position.x+3, map_bounds.end.x-3)
		global_position.z = clampf(global_position.z, map_bounds.position.y+3, map_bounds.end.y-3)
