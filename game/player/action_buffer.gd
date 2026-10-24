class_name ActionBuffer
extends RefCounted
## Keeps one-shot action presses (punch, roll) for a short window, so a press
## that lands while another action runs still counts if that action ends or
## may be cancelled in time. Older presses are dropped, so nothing fires long
## after the tap. An action can be blocked (a roll during its cooldown);
## presses while it is blocked are ignored, not kept.

## Seconds a press is kept.
var window := 0.18

var _pending := {}  # action StringName -> seconds left
var _blocked := {}  # action StringName -> seconds left (INF until blocked again)


func press(action: StringName) -> void:
	if not is_blocked(action):
		_pending[action] = window


func has(action: StringName) -> bool:
	return _pending.has(action)


## Removes a pending press of `action`; true if there was one.
func take(action: StringName) -> bool:
	return _pending.erase(action)


## Ignores presses of `action` for `seconds` and drops a pending one.
func block(action: StringName, seconds: float) -> void:
	_blocked[action] = seconds
	_pending.erase(action)


func is_blocked(action: StringName) -> bool:
	return _blocked.get(action, 0.0) > 0.0


func tick(delta: float) -> void:
	for table: Dictionary in [_pending, _blocked]:
		for action: StringName in table.keys():
			table[action] -= delta
			if table[action] <= 0.0:
				table.erase(action)


## Drops pending presses; blocks stay.
func clear_presses() -> void:
	_pending.clear()
