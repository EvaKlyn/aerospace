extends Window

@export var cursor_opt: OptionButton
@export var ui_scale_slider: Slider
@export var game_scale_slider: Slider
@export var scale_mode_opt: OptionButton
@export var debug_draw_opt: OptionButton
@export var relay_host_edit: LineEdit

func _on_close_requested() -> void:
	visible = false

func _on_button_pressed() -> void:
	set_settings()

func set_settings():
	match cursor_opt.selected:
		1:
			SaveSystem.set_var("opt_mouse_release_mode", MetaManager.MouseReleaseMode.HOLD_RELEASE)
		2:
			SaveSystem.set_var("opt_mouse_release_mode", MetaManager.MouseReleaseMode.HOLD_CAPTURE)
		_:
			SaveSystem.set_var("opt_mouse_release_mode", MetaManager.MouseReleaseMode.TOGGLE)
	match scale_mode_opt.selected:
		1:
			SaveSystem.set_var("opt_game_scale_mode", Viewport.Scaling3DMode.SCALING_3D_MODE_FSR)
		2:
			SaveSystem.set_var("opt_game_scale_mode", Viewport.Scaling3DMode.SCALING_3D_MODE_FSR2)
		_:
			SaveSystem.set_var("opt_game_scale_mode", Viewport.Scaling3DMode.SCALING_3D_MODE_BILINEAR)
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
	SaveSystem.set_var("opt_game_res_scale", game_scale_slider.value) 
	SaveSystem.set_var("opt_relay_host", relay_host_edit.text) 
	
	MetaManager.reload_settings()


func _on_reset_button_pressed() -> void:
	ui_scale_slider.value = 1
	game_scale_slider.value = 1
	scale_mode_opt.selected = 0
	cursor_opt.selected = 0
	debug_draw_opt.selected = 0
	set_settings()
