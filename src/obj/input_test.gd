extends BaseNetInput

var movement: Vector3 = Vector3.ZERO

func _gather():
	movement = Vector3(
	Input.get_axis("input_left", "input_right"), 0,
	Input.get_axis("input_up", "input_down"))
