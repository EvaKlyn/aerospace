extends Node3D
class_name FxScene

## Hopefully pretty set-and-forget node for doing effects sync'd across stuff

@export var lifetime = 1.5
@export var needs_target_position: bool = false

func _ready() -> void:
	start()
	await get_tree().create_timer(lifetime).timeout
	end()

@rpc("call_local", "reliable")
func setup(origin_pos: Vector3, target_position: Vector3 = Vector3.ZERO, data: Dictionary = {}) -> bool:
	if needs_target_position and !target_position:
		push_error("No target position for FXScene which requires it: ", name)
		return false
	if not origin_pos:
		push_error("No origin position for FXScene which requires it: ", name)
		return false
	
	_setup(origin_pos, target_position, data)
	
	return true

## ok actually do ur setup in an override
func _setup(origin_pos: Vector3, target_position: Vector3 = Vector3.ZERO, data: Dictionary = {}):
	pass

## Override this when starting
func start():
	pass

## Override this for custom ending logic
func end() -> void:
	queue_free()
