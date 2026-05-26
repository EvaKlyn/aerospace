extends Node
class_name GameMainNode

var is_host = false
var spawn_host_pc = true
var my_character_data = {}

@export var character_scene: PackedScene
@export var peer_scene: PackedScene
@export var spawn_root: Node3D
@export var peers_parent: Node
@export var fps_label: Label
@export var ping_label: Label
@export var chatlog: RichTextLabel
@export var syslog: RichTextLabel
@export var chatbox: LineEdit

@onready var ui_coordinator = $UiCoodinator
@onready var bootstrapper = $Bootstrapper
@export var world_3d: Node3D
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner

var peers: Dictionary = {}

func _ready() -> void:
	player_spawner.spawn_function = MmoUtils.spawn_player_character
	multiplayer.peer_connected.connect(_handle_new_peer)
	multiplayer.peer_disconnected.connect(_handle_leave)
	multiplayer.connected_to_server.connect(func(): _handle_connected(multiplayer.get_unique_id()))
	multiplayer.server_disconnected.connect(_handle_stop)
	multiplayer.connection_failed.connect(_handle_stop)

func _client_handle_connect(connection_string: String):
	var client = IrohClient.connect(connection_string)
	multiplayer.multiplayer_peer = client

func _handle_connected(id: int):
	# Spawn an avatar for us
	_spawn(id)
	# Spawn avatars for all already connected peers
	for peer_id in multiplayer.get_peers():
		_spawn(peer_id)

func _handle_host():
	# Spawn own avatar on host machine
	var start_level = load("res://scenes/testworld.tscn").instantiate()
	world_3d.add_child(start_level)
	
	if spawn_host_pc:
		_spawn(1)

func _handle_new_peer(id: int):
	# Spawn an avatar for new player
	if id == 1 and !spawn_host_pc:
		return
	_spawn(id)

func _handle_leave(id: int):
	if not peers.has(id):
		return
	
	for n in get_tree().get_nodes_in_group('players'):
		if n is BasePlayer:
			if n.peer_id == id:
				n.queue_free()
	
	var peer = peers[id] as Node
	peer.queue_free()
	peers.erase(id)
	
	if multiplayer.is_server():
		MmoUtils.rpc("eventlog", peer.nickname + " disconnected. " + str(peers.size()) + " players online.")


func _handle_stop():
	# Remove all avatars on game end
	for peer in peers.values():
		peer.queue_free()
	peers.clear()

func _spawn(id: int):
	var peer: NetworkPeer = peer_scene.instantiate()
	peers[id] = peer
	peer.name += " #%d" % id
	peer.peer_id = id
	peers_parent.add_child(peer)
	print("created id " + str(id))

func _process(delta: float) -> void:
	fps_label.text = "FPS: " + str(Performance.get_monitor(Performance.TIME_FPS))
	if multiplayer.multiplayer_peer != null:
		ping_label.text = "Ping: N/A"


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if !spawn_host_pc and get_viewport().get_camera_3d():
		get_viewport().get_camera_3d().current = false
	MmoUtils.peers = peers

func _on_multiplayer_spawner_spawned(node: Node) -> void:
	pass
