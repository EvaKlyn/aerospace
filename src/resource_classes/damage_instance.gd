extends Resource
class_name DamageInstance

@export_category("Info")
@export var raw: float = 0.0
@export_enum("attack", "magic", "true") var damage_type: String = "attack"
@export var can_dodge: bool = true
@export var elements: Array[String]
@export var bonus_armor_pen: int = 0
@export var bonus_magic_pen: int = 0
