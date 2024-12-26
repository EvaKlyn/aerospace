extends Node3D

@export var vis: Node3D
@export var physics_body: CharacterBody3D
@onready var label: Label3D = $Label3D
@onready var unit: GameUnit = $GameUnit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	vis.position = physics_body.position
	label.text = unit.unit_name
	unit.unit_positon = physics_body.global_position
	
