extends Node
class_name GameMainNode

var is_host = false
var spawn_host_pc = true

@onready var name_input: LineEdit = $Control/CenterContainer/PanelContainer/VBoxContainer/GridContainer/NicknameEdit

@export var character_scene: PackedScene
@export var peer_scene: PackedScene
@export var spawn_root: Node3D
@export var peers_parent: Node
@export var color_picker: ColorPickerButton
@export var fps_label: Label
@export var ping_label: Label
@export var chatlog: RichTextLabel
@export var syslog: RichTextLabel
@export var chatbox: LineEdit

@onready var ui_coordinator = $UiCoodinator
@onready var bootstrapper = $Bootstrapper
@onready var world_3d = $World3D
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner

var peers: Dictionary = {}

func _ready() -> void:
	player_spawner.spawn_function = _spawn_player
	NetworkEvents.on_client_start.connect(_handle_connected)
	NetworkEvents.on_server_start.connect(_handle_host)
	NetworkEvents.on_peer_join.connect(_handle_new_peer)
	NetworkEvents.on_peer_leave.connect(_handle_leave)
	NetworkEvents.on_client_stop.connect(_handle_stop)
	NetworkEvents.on_server_stop.connect(_handle_stop)

func _client_handle_connect(address: String, port: int) -> Error:
	# Do a handshake
	var udp = PacketPeerUDP.new()
	udp.bind(Noray.local_port)
	udp.set_dest_address(address, port)
	var err = await PacketHandshake.over_packet_peer(udp)
	udp.close()
	if err != OK:
		return err
	
	# Connect to host
	var peer = ENetMultiplayerPeer.new()
	err = peer.create_client(address, port, 0, 0, 0, Noray.local_port)
	if err != OK:
		return err
	
	return OK

func _handle_connected(id: int):
	# Spawn an avatar for us
	_spawn(id)

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
	
	if NetworkEvents.is_server():
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
	
	if NetworkEvents.is_server():
		await get_tree().create_timer(0.2).timeout
		player_spawner.spawn({"id" = id})
		MmoUtils.rpc("eventlog", peer.nickname + " logged on. " + str(peers.size()) + " players online.")

## Data = {
##   id = (multiplayer id)
## }
##   perhaps more
func _spawn_player(data: Dictionary) -> BasePlayer:
	var new_pc: BasePlayer = character_scene.instantiate()
	new_pc.peer_id = data["id"]
	new_pc.network_peer = peers.get(data["id"])
	new_pc.name += " #%d" % data["id"]
	new_pc.physics_body.network_peer = new_pc.network_peer
	new_pc.set_multiplayer_authority(1)
	new_pc.physics_body.velocity = Vector3.ZERO
	new_pc.physics_body.set_multiplayer_authority(data["id"])
	print("Spawned Playercharacter %s for %s" % [new_pc.name, multiplayer.get_unique_id()])
	return new_pc

func _process(delta: float) -> void:
	fps_label.text = "FPS: " + str(Performance.get_monitor(Performance.TIME_FPS))
	if NetworkTime._is_active():
		ping_label.text = "Ping: " + str(NetworkTime.remote_rtt)


func _physics_process(delta: float) -> void:
	if not NetworkEvents.is_server():
		return
	MmoUtils.peers = peers