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
var game_scale: float = 1
var game_scale_mode: Viewport.Scaling3DMode = Viewport.Scaling3DMode.SCALING_3D_MODE_BILINEAR
var debug_draw_mode: Viewport.DebugDraw = Viewport.DebugDraw.DEBUG_DRAW_DISABLED
var relay_host: String = "localhost"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SaveSystem.loaded.connect(_on_loaded)

func _on_loaded() -> void:
	reload_settings()

func reload_settings() -> void:
	mouse_release_mode = SaveSystem.get_var("opt_mouse_release_mode", mouse_release_mode)
	ui_scale = SaveSystem.get_var("opt_ui_scale", ui_scale)
	ProjectSettings.set_setting("display/window/stretch/scale", ui_scale)
	get_window().content_scale_factor = ui_scale
	game_scale = SaveSystem.get_var("opt_game_res_scale", game_scale)
	game_scale_mode = SaveSystem.get_var("opt_game_scale_mode", game_scale_mode)
	relay_host = SaveSystem.get_var("opt_net_relay_host", relay_host)
	settings_updated.emit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
