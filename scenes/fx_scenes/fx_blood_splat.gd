extends FxScene

@onready var animator: AnimationPlayer = $AnimationPlayer

func _setup(origin_pos: Vector3, target_position: Vector3 = Vector3.ZERO, _data: Dictionary = {}):
	global_position = target_position
	rotation.y = deg_to_rad(randf_range(0, 360))
