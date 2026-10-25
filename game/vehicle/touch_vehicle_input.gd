class_name TouchVehicleInput
extends VehicleInputSource
## Vehicle controls from MobileInputController: steering, throttle, brake, and
## handbrake buttons (or keys), and the exit press (interact).

var input: MobileInputController


func fill_intent(intent: VehicleIntent, _vehicle: VehicleController) -> void:
	if input == null:
		return
	intent.steer = input.get_vehicle_steer()
	intent.throttle = input.get_vehicle_throttle()
	intent.brake = input.get_vehicle_brake()
	intent.handbrake = input.is_vehicle_handbrake_held()
	intent.exit = input.consume_action_press(&"interact")
