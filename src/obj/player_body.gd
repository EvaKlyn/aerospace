extends CharacterBody3D
class_name PlayerBody

@onready var base: BasePlayer = get_parent()
@onready var game_unit: GameUnit = get_parent().game_unit

@export var looking_vector: Vector3 = Vector3.ZERO
@export var network_velocity = Vector3.ZERO
@export var is_actionable: bool = true
@export var animation: String = "idle"
@export var anim_speed: float = 1.0
@export var move_dir: Vector3 = Vector3.ZERO

var unit_status: UnitInfo
var network_peer: NetworkPeer

var aircontrol = 60.0
var accel = 40.0
var gravity = 34.0
var drag = 3.0

var has_airdodge: bool = true

var dodge_cooldown_left: float = 1.0
var knockback_time_left: float = 0.0
var dodge_impulse_left: float = 0.0
var dodge_time_left: float = 0.0
var dodge_iframes_left: float = 0.0

var just_spawned = true
var spawn_pos = Vector3(0, 40, 0)

# CSP/SR buffers
var current_tick: int = 0
var input_history: Dictionary = {}  # tick -> InputPacket (Dictionary)
var state_history: Dictionary = {}  # tick -> StatePacket (Dictionary)

enum States { FROZEN, ACTIONABLE, CASTING, DODGE, KNOCKBACK }
@export var current_state: States = States.FROZEN

var is_client_owner: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().process_frame
	unit_status = game_unit.unit_info
	velocity = Vector3.ZERO
	spawn_pos.x += randf_range(-3,3)
	spawn_pos.z += randf_range(-3,3)
	SimpleGrass.set_interactive(true)
	
	is_client_owner = (multiplayer.get_unique_id() == base.peer_id)

func _physics_process(delta: float) -> void:
	if is_client_owner:
		client_process_tick(delta)

func client_process_tick(delta: float) -> void:
	if !unit_status:
		return
		
	current_tick += 1
	
	# Gather current inputs
	var input = {
		"movement": network_peer.movement if network_peer else Vector3.ZERO,
		"jump": network_peer.jump if network_peer else false,
		"dodge": network_peer.dodge if network_peer else false,
		"target": network_peer.target if network_peer else false,
		"looking_vector": base.vis_body.head.global_rotation if (base.vis_body and base.vis_body.head) else Vector3.ZERO,
		"camera_yaw": base.cam_h.rotation.y if (base and base.cam_h) else 0.0
	}
	input_history[current_tick] = input
	
	# Predict locally
	simulate_tick(input, delta)
	move_and_slide()
	
	# Save state history
	state_history[current_tick] = get_state_packet()
	
	# Send inputs to server
	server_receive_input.rpc_id(1, current_tick, input)
	
	SimpleGrass.set_player_position(global_position)
	network_velocity = velocity

func get_state_packet() -> Dictionary:
	return {
		"position": global_position,
		"velocity": velocity,
		"rotation": rotation,
		"state": current_state,
		"dodge_cooldown_left": dodge_cooldown_left,
		"knockback_time_left": knockback_time_left,
		"dodge_impulse_left": dodge_impulse_left,
		"dodge_time_left": dodge_time_left,
		"dodge_iframes_left": dodge_iframes_left,
		"has_airdodge": has_airdodge,
		"just_spawned": just_spawned,
		"looking_vector": looking_vector,
		"animation": animation,
		"anim_speed": anim_speed
	}

func set_state_packet(packet: Dictionary) -> void:
	global_position = packet["position"]
	velocity = packet["velocity"]
	rotation = packet["rotation"]
	current_state = packet["state"]
	dodge_cooldown_left = packet["dodge_cooldown_left"]
	knockback_time_left = packet["knockback_time_left"]
	dodge_impulse_left = packet["dodge_impulse_left"]
	dodge_time_left = packet["dodge_time_left"]
	dodge_iframes_left = packet["dodge_iframes_left"]
	has_airdodge = packet["has_airdodge"]
	just_spawned = packet["just_spawned"]
	looking_vector = packet["looking_vector"]
	animation = packet["animation"]
	anim_speed = packet["anim_speed"]

@rpc("any_peer", "unreliable")
func server_receive_input(client_tick: int, input: Dictionary) -> void:
	if not multiplayer.is_server():
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != base.peer_id:
		return
		
	var delta = 1.0 / Engine.physics_ticks_per_second
	
	# Simulate client tick authoritatively
	simulate_tick(input, delta)
	move_and_slide()
	
	SimpleGrass.set_player_position(global_position)
	network_velocity = velocity
	
	# Send verified state back to client
	var auth_state = get_state_packet()
	auth_state["tick"] = client_tick
	client_receive_correction.rpc_id(sender_id, auth_state)

@rpc("unreliable")
func client_receive_correction(auth_state: Dictionary) -> void:
	if !is_client_owner:
		return
		
	var auth_tick = auth_state["tick"]
	var auth_pos = auth_state["position"]
	
	if not state_history.has(auth_tick):
		return
		
	var predicted_state = state_history[auth_tick]
	var position_error = predicted_state["position"].distance_to(auth_pos)
	
	if position_error > 0.05: # Desync detected
		var tick_difference = current_tick - auth_tick
		
		# If correction is too old (> 10 ticks), perform a hard snap
		if tick_difference > 10:
			set_state_packet(auth_state)
			current_tick = auth_tick
			input_history.clear()
			state_history.clear()
			return
			
		# Soft reconciliation
		var saved_current_tick = current_tick
		set_state_packet(auth_state)
		state_history[auth_tick] = get_state_packet()
		
		var delta = 1.0 / Engine.physics_ticks_per_second
		var replay_tick = auth_tick + 1
		
		while replay_tick <= saved_current_tick:
			if input_history.has(replay_tick):
				simulate_tick(input_history[replay_tick], delta)
				move_and_slide()
				state_history[replay_tick] = get_state_packet()
			replay_tick += 1
			
	# Cleanup history older than the confirmed tick
	for tick in input_history.keys():
		if tick < auth_tick:
			input_history.erase(tick)
			state_history.erase(tick)

@rpc("reliable", "any_peer", "call_local")
func impulse(vector: Vector3, strength: float):
	if multiplayer.get_remote_sender_id() != 1:
		MmoUtils.eventlog("Someone attempted an RPC on you without being the server lol")
		return
	velocity = vector.normalized() * strength

func simulate_tick(input: Dictionary, delta: float) -> void:
	# Sync looking direction
	looking_vector = input.get("looking_vector", Vector3.ZERO)
	
	match current_state:
		States.FROZEN:
			velocity = Vector3.ZERO
			is_actionable = false
			if just_spawned:
				position = spawn_pos
				if input.get("jump", false):
					just_spawned = false
					current_state = States.ACTIONABLE
					is_actionable = true
		
		States.ACTIONABLE:
			is_actionable = true
			if game_unit.status_effects.has("stun"):
				current_state = States.KNOCKBACK
				knockback_time_left = game_unit.status_effects.get("stun", 0.5)
				is_actionable = false
				return
				
			if unit_status and game_unit.status_effects.has("casting"):
				current_state = States.CASTING
				is_actionable = false
				return
				
			var speed = game_unit.unit_info.move_speed
			var yaw = input.get("camera_yaw", 0.0)
			var move_basis = Basis(Vector3.UP, yaw)
			var input_move = input.get("movement", Vector3.ZERO)
			move_dir = move_basis * input_move
			move_dir.y = 0
			move_dir = move_dir.normalized()
			
			var target_vel = Vector3.ZERO
			
			if input_move != Vector3.ZERO:
				target_vel.x = move_dir.x 
				target_vel.z = move_dir.z
				target_vel = target_vel.normalized() * speed
				
				if not game_unit.has_target:
					var dir = Vector2.ZERO.direction_to(Vector2(move_dir.x, move_dir.z))
					var dir3d = Vector3(dir.x, 0, dir.y)
					look_at(global_position + dir3d)
			else:
				target_vel.x = 0
				target_vel.z = 0
			
			if input.get("target", false):
				if is_client_owner:
					base.rpc("target_auto")
			
			if is_on_floor():
				has_airdodge = true
				velocity.x = velocity.move_toward(target_vel, delta * accel).x
				velocity.z = velocity.move_toward(target_vel, delta * accel).z
				if velocity.length() > 0 and !game_unit.status_effects.has("animating"):
					animation = "walk"
					anim_speed = velocity.length() / 7
				else:
					animation = "idle"
					anim_speed = 1.0
				if input.get("jump", false):
					if move_dir != Vector3.ZERO:
						velocity.y = unit_status.jump_str * 1.0
						knockback_time_left = 1.0
					else:
						velocity.y = unit_status.jump_str * 1.2
			else:
				var target = move_dir + Vector3(velocity.x, 0, velocity.z)
				if target.length() < unit_status.move_speed or target.length() < Vector3(velocity.x, 0, velocity.z).length():
					velocity.x = (velocity + move_dir).x
					velocity.z = (velocity + move_dir).z
				velocity.y -= gravity * delta * unit_status.gravity_mult
				animation = "air"
				anim_speed = 1.0
			
			if game_unit.has_target:
				var dir = Vector2(global_position.x, global_position.z).direction_to(Vector2(game_unit.target_position.x, game_unit.target_position.z))
				var dir3d = Vector3(dir.x, 0, dir.y)
				look_at(global_position + dir3d)
			
			if dodge_cooldown_left > 0:
				dodge_cooldown_left -= delta
			
			if input.get("dodge", false):
				if target_vel != Vector3.ZERO and not dodge_cooldown_left > 0:
					if is_on_floor() or has_airdodge:
						# Transition to dodge state
						current_state = States.DODGE
						is_actionable = false
						dodge_cooldown_left = base.dodge_array[4]
						
						if !is_on_floor():
							velocity = move_dir * unit_status.move_speed * base.dodge_array[0]
							velocity.y = 8.0
							has_airdodge = false
							dodge_impulse_left = base.dodge_array[2]
							dodge_time_left = base.dodge_array[3]
						else:
							velocity = move_dir * unit_status.move_speed * base.dodge_array[0]
							dodge_impulse_left = base.dodge_array[2]
							dodge_time_left = base.dodge_array[3]
						
						dodge_iframes_left = base.dodge_array[1]
						
						if is_client_owner:
							base.rpc("do_skill", "dodge")
		
		States.CASTING:
			is_actionable = false
			if game_unit.status_effects.has("stun"):
				current_state = States.KNOCKBACK
				knockback_time_left = game_unit.status_effects.get("stun", 0.5)
				return
				
			var target_vel = Vector3.ZERO
			
			if game_unit.has_target:
				var dir = Vector2(global_position.x, global_position.z).direction_to(Vector2(game_unit.target_position.x, game_unit.target_position.z))
				var dir3d = Vector3(dir.x, 0, dir.y)
				look_at(global_position + dir3d)
			
			if !is_on_floor():
				animation = "air"
				anim_speed = 1.0
				drag = 0
				velocity.y -= gravity * delta * unit_status.gravity_mult
				velocity.x = velocity.move_toward(target_vel, delta * drag).x
				velocity.z = velocity.move_toward(target_vel, delta * drag).z
			else:
				animation = "casting"
				anim_speed = 1.0
				velocity.x = velocity.move_toward(target_vel, delta * accel).x
				velocity.z = velocity.move_toward(target_vel, delta * accel).z
				drag = 10.0
			
			if unit_status.cast_time_left <= 0:
				current_state = States.ACTIONABLE
				is_actionable = true
				
		States.DODGE:
			is_actionable = false
			if dodge_time_left > 0:
				dodge_time_left -= delta
			else:
				current_state = States.ACTIONABLE
				is_actionable = true
				return
			
			if dodge_impulse_left > 0:
				dodge_impulse_left -= delta
			if dodge_iframes_left > 0:
				dodge_iframes_left -= delta
			
			var fac = (base.dodge_array[2] - dodge_impulse_left)/base.dodge_array[2]
			if fac == 0: fac = .99
			
			if !is_on_floor():
				drag = 90.0 * bezier_interpolate(0, 0.8, 0.9, 1, fac)
				drag = clamp(drag, 0, 90)
				velocity.y -= gravity * delta * unit_status.gravity_mult
			else:
				drag = 130.0 * bezier_interpolate(0, 0.8, 0.9, 1, fac)
				drag = clamp(drag, 0, 180)
			
			if game_unit.has_target:
				var dir = Vector2(global_position.x, global_position.z).direction_to(Vector2(game_unit.target_position.x, game_unit.target_position.z))
				var dir3d = Vector3(dir.x, 0, dir.y)
				look_at(global_position + dir3d)
			
			var target_vel = velocity.move_toward(Vector3.ZERO, delta * drag)
			if target_vel.length() > 1.0:
				velocity.x = target_vel.x
				velocity.z = target_vel.z
				velocity = velocity.limit_length(unit_status.move_speed * 3.0)
				
		States.KNOCKBACK:
			is_actionable = false
			var real = knockback_time_left + game_unit.status_effects.get("stun", 0)
			
			if real > 0:
				knockback_time_left -= delta
			else:
				current_state = States.ACTIONABLE
				is_actionable = true
				return
			
			var target_vel = Vector3.ZERO
			
			if !is_on_floor():
				drag = 10.0
				velocity.y -= gravity * delta * unit_status.gravity_mult
			else:
				drag = 3.0
			
			velocity.x = velocity.move_toward(target_vel, delta * drag).x
			velocity.z = velocity.move_toward(target_vel, delta * drag).z
			
			animation = "air"
			anim_speed = 1.0
