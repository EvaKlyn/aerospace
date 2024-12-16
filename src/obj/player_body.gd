extends CharacterBody3D
class_name PlayerBody

@onready var base: BasePlayer = get_parent()
@onready var game_unit: GameUnit = get_parent().game_unit
# @onready var animator: AnimationPlayer = $AnimationPlayer
@onready var state_chart: StateChart = $StateChart

@export var is_actionable: bool = true

var unit_status: UnitInfo
var network_peer: NetworkPeer

var aircontrol = 0
var accel = 40.0
var gravity = 34.0
var drag = 3.0

var knockback_time_left: float = 0.0

var just_spawned = true
var spawn_pos = Vector3.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().process_frame
	unit_status = game_unit.unit_info
	velocity = Vector3.ZERO
	spawn_pos.x += randf_range(-3,3)
	spawn_pos.z += randf_range(-3,3)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority():
		return
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
	var move_basis = base.cam_h.transform
	var last_y = velocity.y
	var move_dir = (move_basis * network_peer.movement).normalized()
	var target_vel = Vector3.ZERO
	
	if move_dir:
		# player movement
		target_vel.x = move_dir.x * speed
		target_vel.z = move_dir.z * speed
		
		# change player model rotation
		if not game_unit.has_target:
			global_rotation.y = move_basis.basis.get_euler().y
	else:
		target_vel.x = 0
		target_vel.z = 0
	
	if is_on_floor():
		velocity.x = velocity.move_toward(target_vel, delta * accel).x
		velocity.z = velocity.move_toward(target_vel, delta * accel).z
		if network_peer.jump:
			if move_dir != Vector3.ZERO:
				velocity.y = unit_status.jump_str * 1.0
				knockback_time_left = 1.0
			else:
				velocity.y = unit_status.jump_str * 1.2
	else:
		velocity.x = velocity.move_toward(target_vel, delta * aircontrol).x
		velocity.z = velocity.move_toward(target_vel, delta * aircontrol).z
		velocity.y -= gravity * delta * unit_status.gravity_mult

func _on_casting_state_physics_processing(delta: float) -> void:
	if !is_multiplayer_authority():
		return
	if !unit_status:
		return
	
	if game_unit.status_effects.has("stun"):
		state_chart.send_event("hit")
		
	var target_vel = Vector3.ZERO
	velocity.x = velocity.move_toward(target_vel, delta * accel).x
	velocity.z = velocity.move_toward(target_vel, delta * accel).z
	
	if !is_on_floor():
		pass
		velocity.y -= gravity * delta * unit_status.gravity_mult
	
	if unit_status.cast_time_left <= 0:
		state_chart.send_event("castover")

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
	
	velocity.x = velocity.move_toward(target_vel, delta * drag).x
	velocity.z = velocity.move_toward(target_vel, delta * drag).z


func _on_actionable_state_entered() -> void:
	if !is_multiplayer_authority():
		return
	
	is_actionable = true

func _on_actionable_state_exited() -> void:
	if !is_multiplayer_authority():
		return
	
	is_actionable = false

func _on_frozen_state_physics_processing(delta: float) -> void:
	velocity = Vector3.ZERO
	if just_spawned:
		position = spawn_pos
		if Input.is_action_just_pressed("input_jump"):
			state_chart.send_event("unfreeze")
