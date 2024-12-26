extends PanelContainer
class_name UiStatusIcon

@onready var texture: TextureRect = $VBoxContainer/TextureRect
@onready var label = $VBoxContainer/Label

@export var img: Texture2D:
	set(newimg):
		texture.texture = newimg
		img = newimg

@export var number: float = 1.0

func _physics_process(delta: float) -> void:
	if not visible: return
	
	number -= delta
	label.text = str(snapped(number, 0.1))
	
	if number < 0:
		queue_free()
