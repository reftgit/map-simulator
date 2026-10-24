class_name TrainingDummy
extends StaticBody3D
## Debug-build punching target. Counts the hits its Hurtbox receives, flashes,
## shows the count above itself, and logs "DUMMY hits=<n>". No damage and no
## knockback; it is a static obstacle on the world layer.

signal hit(count: int)

var hits := 0

var _snap_to_floor := false
var _material: StandardMaterial3D
var _flash: Tween

@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _body: MeshInstance3D = $Body
@onready var _label: Label3D = $Label


func _ready() -> void:
	_hurtbox.hit_received.connect(_on_hit_received)
	_material = (_body.mesh as PrimitiveMesh).material.duplicate()
	_body.material_override = _material
	_label.text = "HITS 0"


## Places the dummy above `point`; it drops onto the floor below on the next
## physics tick.
func place_above_floor(point: Vector3) -> void:
	global_position = point
	_snap_to_floor = true


func _physics_process(_delta: float) -> void:
	if not _snap_to_floor:
		return
	_snap_to_floor = false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 3.0, global_position + Vector3.DOWN * 10.0, 1, [get_rid()])
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not floor_hit.is_empty():
		global_position = floor_hit.position


func _on_hit_received(_attacker: Node3D) -> void:
	hits += 1
	_label.text = "HITS %d" % hits
	print("DUMMY hits=%d" % hits)
	if _flash:
		_flash.kill()
	_material.albedo_color = Color(1.0, 0.95, 0.6)
	_flash = create_tween()
	_flash.tween_property(_material, "albedo_color", Color(0.78, 0.6, 0.38), 0.25)
	hit.emit(hits)
