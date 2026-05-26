extends Node

enum Role { NONE, HOST, CLIENT }

@export_category("UI")
@export var connect_ui: Window
@export var oid_input: LineEdit
@export var connection_string_input: LineEdit
@export var force_relay_check: CheckBox
@export var game_view: Control

var role = Role.NONE

func _ready():
	if "--server" in OS.get_cmdline_args() or "--server" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		host_only()

func host_only():
	get_parent().spawn_host_pc = false
	host()

func host():
	if get_parent().spawn_host_pc and get_parent().my_character_data == {}:
		return
	
	var server := IrohServer.start()
	multiplayer.multiplayer_peer = server
	print("[Connectionstring] ", server.connection_string())
	
	# Wait for server to start
	while server.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		await get_tree().process_frame
	
	if server.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		OS.alert("Failed to start server!")
		return FAILED
	
	role = Role.HOST
	connect_ui.hide()
	game_view.show()
	
	# Inform main game node that server has started
	get_parent()._handle_host()
	

func join():
	if get_parent().my_character_data == {}:
		return
	role = Role.CLIENT
	_handle_connect(connection_string_input.text)

func _handle_connect(connection_string: String):
	var err = OK
	
	if role == Role.NONE:
		push_warning("Refusing connection, not running as client nor host")
		err = ERR_UNAVAILABLE
	
	if role == Role.CLIENT:
		# Connect
		var client = IrohClient.connect(connection_string)
		multiplayer.multiplayer_peer = client
		# Wait for connection to succeed
		await Async.condition(
			func(): return client.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTING
		)
		if client.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			print("Failed to connect with status %s" %[client.get_connection_status()])
			get_tree().get_multiplayer().multiplayer_peer = null
			return ERR_CANT_CONNECT
		
		connect_ui.hide()
		game_view.show()

	if role == Role.HOST:
		var peer = get_tree().get_multiplayer().multiplayer_peer as IrohServer
	return err
