class_name Hitbox
extends Area3D
## Attack area (a punch's fist). Open only while activated; each Hurtbox it
## touches is hit at most once per activation. No damage or knockback: the
## hurtbox owner decides what a hit means.

signal hit(hurtbox: Hurtbox)

var _hit_this_activation: Array[Hurtbox] = []


func _ready() -> void:
	monitorable = false
	monitoring = false
	area_entered.connect(_on_area_entered)


func activate() -> void:
	_hit_this_activation.clear()
	monitoring = true


func deactivate() -> void:
	monitoring = false


func is_active() -> bool:
	return monitoring


func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null or hurtbox in _hit_this_activation:
		return
	_hit_this_activation.append(hurtbox)
	hurtbox.receive_hit(get_parent() as Node3D)
	hit.emit(hurtbox)
