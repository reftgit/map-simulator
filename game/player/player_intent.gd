class_name PlayerIntent
extends RefCounted
## What the character should do this physics tick, independent of the input
## device. Filled by a PlayerInputSource, read by PlayerController and its states.

## World-space direction on the XZ plane, length 0..1.
var move := Vector3.ZERO
var run := false
## One-shot presses: true only on the tick the press arrives, never while a
## button is held. PlayerController keeps them briefly in its action buffer.
var punch := false
var roll := false
## One-shot: get into a nearby vehicle.
var interact := false


func clear() -> void:
	move = Vector3.ZERO
	run = false
	punch = false
	roll = false
	interact = false


func has_move() -> bool:
	return move.length_squared() > 0.0025
