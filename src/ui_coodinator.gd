extends Node

@export var chat_log: RichTextLabel
@export var chat_line_edit: LineEdit
@export var chat_button: Button

@export var hotbar: Control
@export var hp_text: Label
@export var hp_bar: ProgressBar
@export var atb_text: Label
@export var atb_bar: ProgressBar
@export var skills_area: Control

@export var spell_window: PanelContainer
@export var spell_bar: ProgressBar
@export var spell_text: Label

@export var status_window: PanelContainer
@export var status_container: Container

@export var viewport: SubViewport

@export var settings_window: Window

@export_category("customization_menu")
@export var ancestry_dropdown: OptionButton
@export var color_picker: ColorPickerButton
@export var head_slider: HSlider
@export var hands_slider: HSlider

var base_player: BasePlayer
var unitinfo: UnitInfo
var unit: GameUnit:
	set(newu):
		unit = newu
		last_status_effects = unit.status_effects.duplicate()
var dict_hash
var last_status_effects: Dictionary = {}
var just_connected = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hotbar.visible = false
	MetaManager.ui_coordinator = self
	MetaManager.settings_updated.connect(_on_settings_updated)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if not unitinfo or not base_player:
		return
	if not unit:
		unit = unitinfo.get_parent()
	if just_connected:
		var customization = {
		"ancestry" = ancestry_dropdown.text.to_lower(),
		"clothes_color" = color_picker.color,
		"head_scale" = head_slider.value,
		"hand_scale" = hands_slider.value
		}
		base_player.rpc("remote_customize", customization)
		just_connected = false
	
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
		spell_window.modulate = Color.WHITE
	else:
		spell_window.modulate = Color.TRANSPARENT
	
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
			if ResourceLoader.exists(unitinfo.skills_dict[key][1]):
				new_button.icon = load(unitinfo.skills_dict[key][1])
			skills_area.add_child(new_button)
			i += 1
	
	if unit:
		for key in unit.status_effects:
			if status_container.get_node_or_null(key):
				if unit.status_effects[key] <= last_status_effects[key]:
					continue
				else:
					print(unit.status_effects[key] - last_status_effects[key])
					_remove_status_icon(key)
			_add_status_icon(key, unit.status_effects[key])
		for child in status_container.get_children():
			if !unit.status_effects.has(child.name):
				_remove_status_icon(child.name)
		
		if status_container.get_child_count() == 0:
			status_window.modulate = Color.TRANSPARENT
		else:
			status_window.modulate = Color.WHITE
		last_status_effects = unit.status_effects.duplicate()

func _add_status_icon(state: String, duration: float):
	var path = "res://assets/texture2d/icons/status/" + state + ".png"
	if !ResourceLoader.exists(path):
		return
	var img = load(path)
	
	var new_status_icon: UiStatusIcon = preload("res://src/obj/ui/status_icon.tscn").instantiate()
	new_status_icon.name = state
	status_container.add_child(new_status_icon)
	new_status_icon.img = img
	new_status_icon.number = duration

func _remove_status_icon(state: String):
	var node = status_container.get_node_or_null(state)
	if node: node.queue_free()

func _on_chat_button_pressed() -> void:
	if NetworkTime._is_active():
		MmoUtils.rpc("sendchat", chat_line_edit.text)
		chat_line_edit.clear()

func _on_skill_button_pressed(skillbutton: Button):
	print(unitinfo.skills_dict[skillbutton.text.substr(4)])
	base_player.rpc("do_skill", unitinfo.skills_dict[skillbutton.text.substr(4)][0])


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

func _on_settings_updated():
	viewport.scaling_3d_scale = MetaManager.game_scale
	viewport.scaling_3d_mode = MetaManager.game_scale_mode
	viewport.debug_draw = MetaManager.debug_draw_mode
