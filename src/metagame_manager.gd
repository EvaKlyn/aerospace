extends Node

enum MouseReleaseMode {
	TOGGLE,
	HOLD_RELEASE,
	HOLD_CAPTURE
}

signal settings_updated

var ui_coordinator: Node
var mouse_release_mode: MouseReleaseMode = MouseReleaseMode.TOGGLE
var ui_scale: float = 1
var game_res: Vector2 = Vector2(640, 480)
var debug_draw_mode: Viewport.DebugDraw = Viewport.DebugDraw.DEBUG_DRAW_DISABLED
var relay_host: String = "localhost"
var resolutions: Array[Vector2] = [Vector2(320,240), Vector2(480,360), 
	Vector2(640,480), Vector2(800,600), Vector2(1440,1080), Vector2(3072,2304)]

func _ready() -> void:
	await get_tree().process_frame
	reload_settings()

func reload_settings() -> void:
	mouse_release_mode = SaveSystem.get_var("opt_mouse_release_mode", mouse_release_mode)
	ui_scale = SaveSystem.get_var("opt_ui_scale", ui_scale)
	ProjectSettings.set_setting("display/window/stretch/scale", ui_scale)
	get_window().content_scale_factor = ui_scale
	game_res = resolutions[SaveSystem.get_var("opt_game_res_scale", 1)]
	relay_host = SaveSystem.get_var("opt_net_relay_host", relay_host)
	settings_updated.emit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
