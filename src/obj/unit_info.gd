extends Node
class_name UnitInfo

@export var atb: int = 100
@export var max_hp: int = 10
@export var current_hp: int = 10
@export var max_target_range: float = 20.0
@export var attack_damage: int = 0
@export var armor: int = 0
@export var poise: int = 0
@export_range(0.0, 1.0) var evasion: float = 0.0
@export var magic_power: int = 0
@export var magic_resist: int = 0
@export var armor_pen: int = 0
@export var magic_pen: int = 0
@export var attack_drain: int = 0
@export var magic_drain: int = 0
@export var attack_speed: float = 1.0
@export var cooldown_reduce: float = 0.0
@export var move_speed: float = 7.0
@export var jump_str: float = 14.0
@export var melee_range: float = 4.0
@export var missile_range: float = 12.0
@export var cast_time_left: float = 0.0
@export var full_cast_time: float = 0.0
@export var gravity_mult: float = 1.0
@export var skills_dict: Dictionary = {}
