extends Node3D
class_name GameCharacterBodyType

@export var clothes_parts: Array[VisualInstance3D]
@export var right_hand: Node3D
@export var left_hand: Node3D
@export var hand_container: Node3D
@export var head: Node3D
@export var animator: AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
