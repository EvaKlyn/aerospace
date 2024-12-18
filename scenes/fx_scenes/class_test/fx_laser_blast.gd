extends FxScene

@onready var beam: Node3D = $Beam
@onready var animator: AnimationPlayer = $AnimationPlayer
@onready var ball: MeshInstance3D = $MeshInstance3D

func _setup(origin_pos: Vector3, target_position: Vector3 = Vector3.ZERO, data: Dictionary = {}):
	beam.global_position = origin_pos
	ball.global_position = target_position
	beam.scale.z = -1 * origin_pos.distance_to(target_position)
	beam.look_at(target_position)
	
