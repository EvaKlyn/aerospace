extends PanelContainer
class_name UiCharacterThumbnail

@export var name_label: Label
@export var level_label: Label
@export var button: Button

var data = {}

func _on_button_pressed() -> void:
	var main: GameMainNode = get_node("/root/Main")
	main.my_character_data = data

func _on_button_2_pressed() -> void:
	var chars: Array = SaveSystem.get_var("characters")
	var idx = chars.find(data)
	if idx == -1:
		queue_free()
		return
	chars.remove_at(idx)
	SaveSystem.set_var("characters", chars)
	SaveSystem.save()
	queue_free()
