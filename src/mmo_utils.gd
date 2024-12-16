extends Node

@onready var main: GameMainNode = get_node("/root/Main")
@onready var chat_log: RichTextLabel = main.chatlog
@onready var sys_log: RichTextLabel = main.syslog
@onready var chatbox: LineEdit = main.chatbox

var text_popup_scene: PackedScene = preload("res://src/obj/text_popup.tscn")

var ids_on_cooldown: Dictionary = {}
var rate_limit = 0.5

var peers: Dictionary = {}

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if not NetworkEvents.is_server():
		return
	
	if NetworkTime._is_active():
		var done_guys = []
		for k in ids_on_cooldown:
			if ids_on_cooldown[k] > 0.0:
				ids_on_cooldown[k] -= delta
			else:
				done_guys.append(k)
		
		for k in done_guys:
			ids_on_cooldown.erase(k)

@rpc("reliable", "call_local")
func eventlog(message: String, category: String = "system"):
	sys_log.append_text("\n" + "[" + category.to_upper() + "] " + message)

@rpc("reliable", "call_local")
func chatlog(message: String, nickname: String = "system"):
	if nickname == "system":
		chat_log.append_text("\n" + "[SYSTEM] " + message)
	else:
		chat_log.append_text("\n" + "<" + nickname + "> " + message)

@rpc("reliable", "call_local", "any_peer")
func sendchat(message: String, scope: String = "say"):
	if !is_multiplayer_authority():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	if ids_on_cooldown.has(sender_id):
		rpc_id(sender_id, "chatlog", "you were rate-limited.")
		return
	
	var peer: NetworkPeer = main.peers[sender_id]
	
	if peer.nickname == "system":
		rpc_id(sender_id, "chatlog", "your nickname can't be \"system\" bozo.")
		return
	
	message = message.left(140)
	
	ids_on_cooldown[sender_id] = rate_limit
	rpc("chatlog", message, peer.nickname)

@rpc("reliable", "call_local")
func text_popup(position: Vector3, text: String, size: float = 1.0, lifetime: float = 1.0, fill_color: Color = Color.WHITE, outline_color: Color = Color.BLACK):
	var new_popup: TextWorldPopup = text_popup_scene.instantiate()
	new_popup.text = text
	new_popup.size = size
	new_popup.lifetime = lifetime
	new_popup.fill_color = fill_color
	new_popup.outline_color = outline_color
	main.world_3d.add_child(new_popup)
	new_popup.global_position = position + Vector3(0, 2, 0)
