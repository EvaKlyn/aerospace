extends Node
class_name NetworkPeer

@export var color: Color = Color.ANTIQUE_WHITE

var peer_id: int
var movement: Vector3 = Vector3.ZERO
var twist_input = 0.0
var pitch_input = 0.0
var jump: bool = false
var target: bool = false
var dodge: bool = false

var player_object: BasePlayer
var dummy = 1

var mouse_cam_sensitivity = 0.003

var character_data = {}

@export var nickname: String = "NOTHIN'"

func _ready():
	# Wait a frame so peer_id is set
	await get_tree().process_frame
	set_multiplayer_authority(peer_id, true)
	
	if !is_multiplayer_authority():
		return
	
	nickname = "bubs"
	nickname = nickname.left(16)
	character_data = get_node("/root/Main").my_character_data
	MmoUtils.rpc("create_player_character", character_data)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	
	movement = Vector3(
	Input.get_axis("input_left", "input_right"), 0,
	Input.get_axis("input_up", "input_down"))
	
	jump = Input.is_action_pressed("input_jump")
	target = Input.is_action_just_pressed("menu_target")
	dodge = Input.is_action_pressed("input_dodge")
	
	if get_viewport().gui_get_focus_owner():
		movement = Vector3.ZERO
		jump = false
		target = false
		dodge = false

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	
	if Input.is_action_just_pressed("ui_cancel"):
		MetaManager.ui_coordinator.settings_window.visible = true
	
	if Input.is_action_just_pressed("menu_capture"):
		match MetaManager.mouse_release_mode:
			MetaManager.MouseReleaseMode.TOGGLE:
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					release_mouse()
				else:
					capture_mouse()
			MetaManager.MouseReleaseMode.HOLD_CAPTURE:
				capture_mouse()
			MetaManager.MouseReleaseMode.HOLD_RELEASE:
				release_mouse()
	if Input.is_action_just_released("menu_capture"):
		match MetaManager.mouse_release_mode:
			MetaManager.MouseReleaseMode.HOLD_CAPTURE:
				release_mouse()
			MetaManager.MouseReleaseMode.HOLD_RELEASE:
				capture_mouse()
	
	if event is InputEventMouseMotion and player_object:
		player_object.camera_input(event)

func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_viewport().gui_release_focus()
	
func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
