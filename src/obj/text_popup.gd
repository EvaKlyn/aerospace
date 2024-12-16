extends Node3D
class_name TextWorldPopup

var text: String = "Text"
var fill_color: Color = Color.WHITE
var outline_color: Color = Color.WHITE
var lifetime: float = 1.0
var size: float = 1.0
var size_mult: float = 1.0

@onready var label = $Label3D
@onready var animator = $AnimationPlayer

func _ready() -> void:
	size_mult = randf_range(0.8, 1.2)
	lifetime = lifetime * randf_range(0.8, 1.2)
	animator.speed_scale = lifetime
	scale = Vector3(1,1,1) * size * size_mult
	label.text = text
	label.modulate = fill_color
	label.outline_modulate = outline_color
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	scale = Vector3(1,1,1) * size * size_mult
	lifetime -= delta
	label.text = text
	label.modulate = fill_color
	label.outline_modulate = outline_color
	if lifetime < 0.0:
		queue_free()
