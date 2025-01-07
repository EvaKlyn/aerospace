extends Window

@export var cursor_opt: OptionButton
@export var ui_scale_slider: Slider
@export var game_scale_opt: OptionButton
@export var debug_draw_opt: OptionButton
@export var relay_host_edit: LineEdit

func _on_close_requested() -> void:
	visible = false

func _on_button_pressed() -> void:
	set_settings()

func _ready() -> void:
	visibility_changed.connect(_load_settings)

func _load_settings():
	cursor_opt.selected = SaveSystem.get_var("opt_mouse_release_mode", 0)
	game_scale_opt.selected = SaveSystem.get_var("opt_game_res_scale", 0)
	ui_scale_slider.value = SaveSystem.get_var("opt_ui_scale", 1)
	relay_host_edit.text = SaveSystem.get_var("opt_relay_host", "localhost")
	set_settings()

func set_settings():
	SaveSystem.set_var("opt_mouse_release_mode", cursor_opt.selected)
	
	match debug_draw_opt.selected:
		1:
			MetaManager.debug_draw_mode = Viewport.DebugDraw.DEBUG_DRAW_UNSHADED
		2:
			MetaManager.debug_draw_mode = Viewport.DebugDraw.DEBUG_DRAW_WIREFRAME
		3: 
			MetaManager.debug_draw_mode = Viewport.DebugDraw.DEBUG_DRAW_OVERDRAW
		_:
			MetaManager.debug_draw_mode = Viewport.DebugDraw.DEBUG_DRAW_DISABLED
	
	SaveSystem.set_var("opt_ui_scale", ui_scale_slider.value)
	SaveSystem.set_var("opt_game_res_scale", game_scale_opt.selected)  
	SaveSystem.set_var("opt_relay_host", relay_host_edit.text) 
	SaveSystem.save()
	
	MetaManager.reload_settings()


func _on_reset_button_pressed() -> void:
	ui_scale_slider.value = 1
	game_scale_opt.selected = 1
	cursor_opt.selected = 0
	debug_draw_opt.selected = 0
	set_settings()
