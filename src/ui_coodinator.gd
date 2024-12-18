extends Node

@export var chat_log: RichTextLabel
@export var chat_line_edit: LineEdit
@export var chat_button: Button

@export var hotbar: PanelContainer
@export var hp_text: Label
@export var hp_bar: ProgressBar
@export var atb_text: Label
@export var atb_bar: ProgressBar
@export var skills_area: Control

@export var spell_bar: ProgressBar
@export var spell_text: Label

@export_category("customization_menu")
@export var ancestry_dropdown: OptionButton
@export var color_picker: ColorPickerButton
@export var head_slider: HSlider
@export var hands_slider: HSlider

var base_player: BasePlayer
var unitinfo: UnitInfo
var unit: GameUnit
var dict_hash

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hotbar.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not unitinfo or not base_player:
		return
	hotbar.visible = true
	hp_text.text = "HEALTH: " + str(unitinfo.current_hp) + "/" + str(unitinfo.max_hp)
	atb_text.text = "ATB: " + str(ceil(unitinfo.atb)) + "/100"
	hp_bar.value = unitinfo.current_hp
	hp_bar.max_value = unitinfo.max_hp
	atb_bar.value = unitinfo.atb
	
	if unitinfo.cast_time_left > 0:
		spell_bar.max_value = unitinfo.full_cast_time
		spell_bar.value = unitinfo.full_cast_time - unitinfo.cast_time_left
		spell_text.text = str(unitinfo.cast_time_left).left(4) + "!"
		spell_bar.visible = true
		spell_text.visible = true
	else:
		spell_bar.visible = false
		spell_text.visible = false
	
	var last_hash = dict_hash
	dict_hash = unitinfo.skills_dict.hash()
	if last_hash != dict_hash:
		for child in skills_area.get_children():
			child.queue_free()
		
		var i = 1
		for key in unitinfo.skills_dict:
			var new_button: Button = Button.new()
			new_button.focus_mode = Control.FOCUS_NONE
			new_button.text = "[{0}] ".format([i], "{_}") + key
			var keypress = InputEventKey.new()
			keypress.keycode = str(i).unicode_at(0)
			new_button.shortcut = Shortcut.new()
			new_button.shortcut.events = [keypress]
			new_button.pressed.connect(_on_skill_button_pressed.bind(new_button))
			skills_area.add_child(new_button)
			i += 1

func _on_chat_button_pressed() -> void:
	if NetworkTime._is_active():
		MmoUtils.rpc("sendchat", chat_line_edit.text)
		chat_line_edit.clear()

func _on_skill_button_pressed(skillbutton: Button):
	base_player.rpc("do_skill", unitinfo.skills_dict[skillbutton.text.substr(4)])


#var customization: Dictionary = {
	#ancestry = "human",
	#clothes_color = Color.WHITE,
	#head_scale = 1.0,
	#hand_scale = 1.0
#}

func _on_customize_button_pressed() -> void:
	if !NetworkTime._is_active():
		return
	
	var customization = {
		"ancestry" = ancestry_dropdown.text.to_lower(),
		"clothes_color" = color_picker.color,
		"head_scale" = head_slider.value,
		"hand_scale" = hands_slider.value
	}
	print(customization)
	base_player.rpc("remote_customize", customization)
