extends Node3D

@onready var game_unit: GameUnit = $GameUnit
@onready var static_body: StaticBody3D = $StaticBody3D

@export var alive: bool = true:
	set(new_state):
		if new_state:
			static_body.collision_layer = 1
			visible = true
			alive = new_state
			if not is_multiplayer_authority():
				return
			time_left = regrow_time
			game_unit.team = game_unit.Teams.HOSTILE
		else:
			static_body.collision_layer = 0
			visible = false
			alive = new_state
			if not is_multiplayer_authority():
				return
			game_unit.team = game_unit.Teams.UNTARGETABLE
			game_unit.untarget_me()


var regrow_time: float = 30.0
var time_left = 0.0

func _ready() -> void:
	game_unit.unit_positon = global_position + Vector3(0,0.3,0)

func _on_game_unit_damaged(attacker: GameUnit, damage_report: Dictionary) -> void:
	if not is_multiplayer_authority():
		return
	if game_unit.current_hp <= 0:
		alive = false

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if not alive:
		if time_left <= 0.0:
			alive = true
			return
		else:
			time_left -= delta
