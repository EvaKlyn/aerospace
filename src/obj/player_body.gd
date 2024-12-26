extends CharacterBody3D
class_name PlayerBody

@onready var base: BasePlayer = get_parent()
@onready var game_unit: GameUnit = get_parent().game_unit
# @onready var animator: AnimationPlayer = $AnimationPlayer
@onready var state_chart: StateChart = $StateChart

@export var looking_vector: Vector3 = Vector3.ZERO

@export var network_velocity = Vector3.ZERO
@export var is_actionable: bool = true
@export var animation: String = "idle"
@export var anim_speed: float = 1.0
@export var move_dir: Vector3 = Vector3.ZERO

@export var dodge_cooldown: float = 0.6
@export var dodge_time_total: float = 0.4
@export var dodge_time_iframe: float = 0.3
@export var dodge_time_impulse: float = 0.4

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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().process_frame
	if !is_multiplayer_authority():
		return
	unit_status = game_unit.unit_info
	velocity = Vector3.ZERO
	spawn_pos.x += randf_range(-3,3)
	spawn_pos.z += randf_range(-3,3)
	SimpleGrass.set_interactive(true)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority():
		return
		
	SimpleGrass.set_player_position(global_position)
	network_velocity = velocity
	move_and_slide()

@rpc("reliable", "any_peer", "call_local")
func impulse(vector: Vector3, strength: float):
	if multiplayer.get_remote_sender_id() != 1:
		MmoUtils.eventlog("Someone attempted an RPC on you without being the server lol")
		return
	velocity = vector.normalized() * strength

func _on_actionable_state_physics_processing(delta: float) -> void:
	if !is_multiplayer_authority():
		return
	if !unit_status:
		return
	
	if game_unit.status_effects.has("stun"):
		state_chart.send_event("hit")
	
	if unit_status.cast_time_left > 0:
		state_chart.send_event("cast")
	
	var speed = game_unit.unit_info.move_speed
	var move_basis: Transform3D = base.cam_h.transform
	var last_y = velocity.y
	move_dir = (move_basis * network_peer.movement)
	move_dir.y = 0
	move_dir = move_dir.normalized()
	
	var target_vel = Vector3.ZERO
	
	if network_peer.movement:
		# player movement
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
	
	if network_peer.target:
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
		if network_peer.jump:
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
	
	if network_peer.dodge:
		if target_vel != Vector3.ZERO and !dodge_cooldown_left > 0:
			if is_on_floor() or has_airdodge:
				state_chart.send_event("dodge")
				dodge_cooldown_left = dodge_cooldown

func _on_casting_state_physics_processing(delta: float) -> void:
	if !is_multiplayer_authority():
		return
	if !unit_status:
		return
	
	if game_unit.status_effects.has("stun"):
		state_chart.send_event("hit")
		
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
		state_chart.send_event("castover")

func _on_dodge_state_entered() -> void:
	if !is_multiplayer_authority():
		return
	if !unit_status:
		return
	
	var result = base.rpc("do_skill_absolute", "PlayerDodge")
	
	var move_basis = base.cam_h.transform
	move_dir = move_basis * network_peer.movement
	move_dir.y = 0
	move_dir = move_dir.normalized()
	
	if !is_on_floor():
		velocity = move_dir * unit_status.move_speed * 6
		velocity.y = 8.0
		has_airdodge = false
		dodge_impulse_left = dodge_time_impulse
		dodge_time_left = dodge_time_total * 1.2
	else:
		velocity = move_dir * unit_status.move_speed * 6
		dodge_impulse_left = dodge_time_impulse
		dodge_time_left = dodge_time_total
	
	dodge_iframes_left = dodge_time_iframe
	

func _on_dodge_state_physics_processing(delta: float) -> void:
	if !is_multiplayer_authority():
		return
	if !unit_status:
		return
	
	if dodge_time_left > 0:
		dodge_time_left -= delta
	else:
		state_chart.send_event("dodgeover")
	
	if dodge_impulse_left > 0:
		dodge_impulse_left -= delta
	if dodge_iframes_left > 0:
		dodge_iframes_left -= delta
	
	var fac = (dodge_time_impulse - dodge_impulse_left)/dodge_time_impulse
	
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
	

func _on_knockback_state_physics_processing(delta: float) -> void:
	if !is_multiplayer_authority():
		return
	if !unit_status:
		return
	
	var real = knockback_time_left + game_unit.status_effects.get("stun", 0)
	
	if real > 0:
		knockback_time_left -= delta
	else:
		state_chart.send_event("knockbackover")
	
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

func _on_actionable_state_entered() -> void:
	if !is_multiplayer_authority():
		return
	
	is_actionable = true

func _on_actionable_state_exited() -> void:
	if !is_multiplayer_authority():
		return
	
	is_actionable = false

func _on_frozen_state_physics_processing(delta: float) -> void:
	if !is_multiplayer_authority():
		return
	velocity = Vector3.ZERO
	if just_spawned:
		position = spawn_pos
		if Input.is_action_just_pressed("input_jump"):
			state_chart.send_event("unfreeze")
