extends Node3D
class_name BasePlayer

@export var speed = 7.0
@export var jump_str = 10
@export var aircontrol = 20.0
@export var turn_speed = 180
@export var physics_body: PlayerBody
@export var game_unit: GameUnit

@export var vis_body: GameCharacterBodyType

@onready var vis: Node3D = $Vis
@onready var camera: Camera3D = $Camera3D
@onready var camera_origin = $CameraOrigin
@onready var camera_target = $CameraOrigin/h/v/SpringArm3D/CameraTarget
@onready var cam_h = $CameraOrigin/h
@onready var cam_v = $CameraOrigin/h/v
@onready var melee_area: Area3D = $TargetArea
@onready var melee_shape: CollisionShape3D = $TargetArea/CollisionShape3D
@onready var sight_cast: RayCast3D = $PhysicsBody/SightCast
@onready var angle_dummy: Node3D = $Vis/AngleDummy
@onready var target_ring: Sprite3D = $TargetRing
# @onready var animator: AnimationPlayer = $PhysicsBody/AnimationPlayer
@onready var listener: AudioListener3D = $PhysicsBody/AudioListener3D
@onready var melee_ring: Sprite3D = $Vis/MeleeRangeDecal


var dummy = 1
var customize_cooldown = 0.0

signal customization_changed

var queued_customization: Dictionary = {}

@export var customization: Dictionary = {
	ancestry = "human",
	clothes_color = Color.WHITE,
	head_scale = 1.0,
	hand_scale = 1.0
}


var peer_id = 0
var network_peer: NetworkPeer
var move_vec: Vector3 = Vector3.ZERO

var last_autoattack_time: float = 0.0

func _ready():
	# Wait a frame so peer_id is set
	await get_tree().process_frame
	add_to_group("players")
	
	# Set owner
	if network_peer.is_multiplayer_authority():
		physics_body.network_peer = network_peer
		camera.current = true
		MmoUtils.main.ui_coordinator.unitinfo = game_unit.unit_info
		MmoUtils.main.ui_coordinator.base_player = self
		listener.make_current()
	
	if not is_multiplayer_authority():
		return
	await get_tree().create_timer(0.2).timeout
	customization_changed.connect(update_customization)
	game_unit.unit_name = network_peer.nickname
	game_unit.sync.set_visibility_for(peer_id, true)
	game_unit.cast_over.connect(_cast_over)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and camera.current:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			cam_h.rotate_y(-event.relative.x * network_peer.mouse_cam_sensitivity)
			cam_v.rotate_x(-event.relative.y * network_peer.mouse_cam_sensitivity)
			cam_v.rotation.x = clamp(
				cam_v.rotation.x,
				deg_to_rad(-90),
				deg_to_rad(45)
				)

func _physics_process(delta: float) -> void:
	visual_update(delta)
	
	if camera.current:
		var fac = delta * 11
		camera_origin.position = physics_body.position
		camera.global_transform = camera_target.global_transform
	
	if not is_multiplayer_authority():
		return
	
	game_unit.unit_positon = physics_body.global_position + Vector3(0,1,0)
	game_unit.actionable = physics_body.is_actionable
	game_unit.unit_name = network_peer.nickname
	melee_area.position = physics_body.global_position
	
	if customize_cooldown > 0:
			customize_cooldown -= delta
	
	if game_unit.current_target:
		target_ring.global_position = game_unit.current_target.unit_positon
		target_ring.scale = Vector3(1,1,1) * (10 - game_unit.current_target.targeting_me.find(game_unit))/10
		target_ring.visible = true
		angle_dummy.look_at(game_unit.current_target.unit_positon)
	else:
		target_ring.visible = false
	
	if game_unit.status_effects.has("animating"):
		pass
	elif game_unit.status_effects.has("casting"):
		vis_body.animator.play("player_anim_lib/casting")
	else:
		vis_body.animator.play("player_anim_lib/" + physics_body.animation)

func _cast_over(success: bool):
	pass

@rpc("any_peer", "call_local")
func target_auto():
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	
	if game_unit.current_target:
		game_unit.current_target = null
	else:
		var candidate_targets: Array[GameUnit] = []
		for body in melee_area.get_overlapping_bodies():
			var unit = body.get_node_or_null("../GameUnit")
			if unit is GameUnit:
				if unit.team == GameUnit.Teams.HOSTILE:
					candidate_targets.append(unit)
		
		if candidate_targets.size() == 0:
			return
		
		var nearest_dist = 9999999999999
		var nearest_unit: GameUnit
		for candidate in candidate_targets:
			var dist = game_unit.unit_positon.distance_to(candidate.unit_positon)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_unit = candidate
		
		game_unit.current_target = nearest_unit
		MmoUtils.rpc_id(peer_id, "eventlog", "targeting " + nearest_unit.unit_name)

@rpc("any_peer", "reliable", "call_local")
func remote_customize(dict: Dictionary):
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	if !is_multiplayer_authority():
		return
	
	if customize_cooldown > 0:
		MmoUtils.rpc_id(multiplayer.get_remote_sender_id(), "eventlog", "Wait a sec to re-customize bro", "system")
		return
	else:
		queued_customization.clear()
		
	rpc("update_customization", dict)

@rpc("reliable", "call_local")
func update_customization(dict) -> void:
	customization = dict
	customize_cooldown = 10.0
	target_ring.modulate = customization.get("clothes_color", Color.WHITE)
	melee_ring.modulate = customization.get("clothes_color", Color.WHITE)
	
	var new_body
	match customization.get("ancestry", "human"):
		"human":
			var scene: PackedScene = load("res://scenes/chara/bodytypes/body_type_human.tscn")
			new_body = scene.instantiate()
		"bird":
			var scene: PackedScene = load("res://scenes/chara/bodytypes/body_type_bird.tscn")
			new_body = scene.instantiate()
		_:
			var scene: PackedScene = load("res://scenes/chara/bodytypes/body_type_human.tscn")
			new_body = scene.instantiate()
	
	vis.add_child(new_body)
	vis_body.queue_free()
	vis_body = new_body
	
	game_unit.animator = vis_body.animator
	
	for mesh in vis_body.clothes_parts:
		if mesh is MeshInstance3D:
			mesh.get_active_material(0).albedo_color = customization.get("clothes_color", Color.WHITE)
		if mesh is Sprite3D:
			mesh.modulate = customization.get("clothes_color", Color.WHITE)
	var head_scale = clamp(customization.get("head_scale", 1.0), 0.7, 1.4)
	var hand_scale = clamp(customization.get("hand_scale", 1.0), 0.7, 1.4)
	vis_body.head.scale = Vector3(head_scale,head_scale,head_scale)
	vis_body.left_hand.scale = Vector3(hand_scale, hand_scale, hand_scale)
	vis_body.right_hand.scale = Vector3(hand_scale, hand_scale, hand_scale)

func visual_update(delta) -> void:
	$Vis/Label3D.text = network_peer.nickname
	vis.position = vis.position.lerp(physics_body.position, delta * 50)
	
	melee_ring.scale.x = game_unit.unit_info.melee_range * 2.0
	melee_ring.scale.y = game_unit.unit_info.melee_range * 2.0
	
	if physics_body.is_on_floor():
		melee_ring.basis.z = physics_body.get_floor_normal()
	
	vis.global_rotation.y = lerp_angle(vis.global_rotation.y, physics_body.global_rotation.y, delta * 20)
	if physics_body.looking_vector != Vector3.ZERO:
		vis_body.head.global_rotation = vis_body.head.global_rotation.lerp(physics_body.looking_vector, delta * 6)
	
	var target = vis_body.head.to_local(vis_body.head.global_position + physics_body.network_velocity.normalized()) * 0.1
	vis_body.head.position = vis_body.head.position.lerp(target, delta * 2)
	vis_body.hand_container.position = vis_body.hand_container.position.lerp(target, delta * 2)
	vis_body.animator.speed_scale = physics_body.anim_speed

## DAMAGE_REPORT SPEC
## inflicted: int = amount of damage that was done in reality
## mitigated: int = difference between raw damage and actual damage
## status_code: String = a string specifying special cases. usually "normal"
##                       but might be someting like "evaded" etc.
func _on_game_unit_damaged(attacker: GameUnit, damage_report: Dictionary) -> void:
	var knockback_vector: Vector3 = attacker.unit_positon.direction_to(physics_body.global_position)
	var cooked = damage_report["inflicted"] + damage_report["mitigated"] / (1.0 + (game_unit.stat_poise/10))

func _on_game_unit_stats_update():
	if melee_shape:
		melee_shape.shape.radius = game_unit.unit_info.max_target_range

@rpc("any_peer", "call_local", "reliable")
func do_skill(skill_idx):
	if multiplayer.get_remote_sender_id() != peer_id:
		MmoUtils.rpc_id(peer_id, "Someone attempted to use one of your skills remotely lol", "debug")
		return
	
	if not is_multiplayer_authority():
		return
	
	if skill_idx > game_unit.skills.size():
		MmoUtils.rpc_id(peer_id, "You tried to call a skill index that doesn't exist", "debug")
		return
	
	var result: GameSkill.SkillResult = await game_unit.skills[skill_idx].cast(game_unit, game_unit.current_target)
	return result
