class_name Hurtbox
extends Area3D
## Area that Hitboxes can hit (physics layer 3, "hurtbox"). Emits a signal and
## nothing else; damage, reactions, and NPC behaviour belong to the owner.

signal hit_received(attacker: Node3D)


func _ready() -> void:
	monitoring = false
	monitorable = true


func receive_hit(attacker: Node3D) -> void:
	hit_received.emit(attacker)
