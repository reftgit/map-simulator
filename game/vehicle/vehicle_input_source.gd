class_name VehicleInputSource
extends Node
## Base for anything that drives a VehicleController: touch and keyboard
## today, AI later. Called once per physics tick by the vehicle.


func fill_intent(_intent: VehicleIntent, _vehicle: VehicleController) -> void:
	pass
