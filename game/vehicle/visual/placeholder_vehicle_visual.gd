class_name PlaceholderVehicleVisual
extends VehicleVisual
## Box body and cylinder wheels until a car model exists. Wheel meshes follow
## the physics wheels; brake and reverse lights show the drive state.

## Cylinder meshes stand along Y; wheels spin around X.
const WHEEL_UPRIGHT := Basis(Vector3.BACK, PI * 0.5)

## Wheel meshes in the order of VehicleController.wheels.
@export var wheel_meshes: Array[Node3D] = []
@export var brake_lights: Node3D
@export var reverse_lights: Node3D


func set_drive_state(_speed: float, _steer: float, braking: bool, reversing: bool) -> void:
	if brake_lights:
		brake_lights.visible = braking
	if reverse_lights:
		reverse_lights.visible = reversing


func set_wheel_transforms(transforms: Array[Transform3D]) -> void:
	for i in mini(transforms.size(), wheel_meshes.size()):
		wheel_meshes[i].transform = transforms[i] * Transform3D(WHEEL_UPRIGHT, Vector3.ZERO)
