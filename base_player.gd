extends Node3D
class_name BasePlayer

@export var speed = 7.0
@export var jump_str = 10
@export var aircontrol = 20.0
@export var turn_speed = 180
@export var physics_body: PlayerBody
@export var game_unit: GameUnit

@export var parts_to_color: Array[MeshInstance3D]

@onready var vis: Node3D = $Vis
@onready var camera: Camera3D = $Camera3D
@onready var camera_origin = $CameraOrigin
@onready var camera_target = $CameraOrigin/h/v/SpringArm3D/CameraTarget
@onready var cam_h = $CameraOrigin/h
@onready var cam_v = $CameraOrigin/h/v
@onready var melee_area: Area3D = $MeleeArea
@onready var melee_shape: CollisionShape3D = $MeleeArea/CollisionShape3D
@onready var sight_cast: RayCast3D = $PhysicsBody/SightCast
@onready var angle_dummy: Node3D = $Vis/AngleDummy
@onready var target_ring: Sprite3D = $TargetRing
# @onready var animator: AnimationPlayer = $PhysicsBody/AnimationPlayer
@onready var listener: AudioListener3D = $PhysicsBody/AudioListener3D
@onready var melee_ring: Sprite3D = $Vis/MeleeRangeDecal

var dummy = 1
var color_cooldown = 0.0
@export var clothes_color: Color = Color.AQUAMARINE

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
	game_unit.unit_name = network_peer.nickname

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
	
	game_unit.unit_positon = physics_body.global_position
	game_unit.actionable = physics_body.is_actionable
	game_unit.unit_name = network_peer.nickname
	melee_area.position = physics_body.global_position
	
	if game_unit.current_target:
		target_ring.global_position = game_unit.current_target.unit_positon
		target_ring.scale = Vector3(1,1,1) * (10 - game_unit.current_target.targeting_me.find(game_unit))/10
		target_ring.visible = true
		angle_dummy.look_at(game_unit.current_target.unit_positon)
		
		if clothes_color != network_peer.color and color_cooldown <= 0:
			MmoUtils.rpc("eventlog", network_peer.nickname + " changed color to " + network_peer.color.to_html())
			clothes_color = network_peer.color
			color_cooldown = 3.0
		if color_cooldown > 0:
			color_cooldown -= delta
	else:
		target_ring.visible = false
		for body in melee_area.get_overlapping_bodies():
			var unit = body.get_node_or_null("../GameUnit")
			if unit is GameUnit:
				if unit.team == GameUnit.Teams.HOSTILE:
					MmoUtils.rpc_id(peer_id, "eventlog", "targeting " + unit.unit_name)
					game_unit.current_target = unit

func visual_update(delta) -> void:
	$Vis/Label3D.text = network_peer.nickname
	vis.position = vis.position.lerp(physics_body.position, delta * 50)
	
	for mesh in parts_to_color:
		mesh.get_active_material(0).albedo_color = clothes_color
	
	melee_ring.scale.x = game_unit.unit_info.melee_range * 2.0
	melee_ring.scale.y = game_unit.unit_info.melee_range * 2.0
	melee_ring.modulate = clothes_color
	if physics_body.is_on_floor():
		melee_ring.basis.z = physics_body.get_floor_normal()
	
	target_ring.modulate = clothes_color
	#vis.rotation.y = lerp_angle(vis.rotation.y, physics_body.rotation.y, delta * 20)

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
		melee_shape.shape.radius = game_unit.unit_info.melee_range

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
