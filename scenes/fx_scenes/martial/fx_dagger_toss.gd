extends FxScene

@onready var dagger: Node3D = $Node3D
@export var bloodsplat: PackedScene

var target: Vector3 = Vector3.ZERO
var origin: Vector3 = Vector3.ZERO

var hit: bool = false

func _setup(origin_pos: Vector3, target_position: Vector3 = Vector3.ZERO, _data: Dictionary = {}):
	dagger.global_position = origin_pos
	origin = origin_pos
	target = target_position

func _physics_process(delta: float) -> void:
	if hit:
		return
	
	dagger.global_position = dagger.global_position.move_toward(target, delta*45)
	if dagger.global_position.distance_to(target) < 0.5:
		hit = true
		MmoUtils.do_fx(bloodsplat.resource_path, origin, target)
		return
	dagger.look_at(target)
	
