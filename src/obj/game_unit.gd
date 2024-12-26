extends Node
class_name GameUnit

enum Teams {
	NEUTRAL,
	FRIENDLY,
	HOSTILE,
	UNTARGETABLE
}

signal attacked(attacker: GameUnit)
signal damaged(attacker: GameUnit, damage_report: Dictionary)
signal stats_update
signal cast_over(succeeded: bool)
signal status_added(status: String, duration: float)
signal status_removed(status: String)

var skill_map: Array[GameSkill] = []

@export_category("Basics")
@export var unit_name: String = ""
@export var team: Teams = Teams.NEUTRAL
@export var max_hp: int = 10
@export var current_hp: int = 10
@export var max_target_range: float = 20.0

@export_category("Combat Statistics")
@export var stat_attack_damage: int = 0
@export var stat_armor: int = 0
@export var stat_poise: int = 0
@export_range(0.0, 1.0) var stat_evasion: float = 0.0
@export var stat_magic_power: int = 0
@export var stat_magic_resist: int = 0
@export var stat_armor_pen: int = 0
@export var stat_magic_pen: int = 0
@export var stat_attack_drain: int = 0
@export var stat_magic_drain: int = 0
@export var stat_attack_speed: float = 1.0
@export var stat_cooldown_mult: float = 1.0
@export var stat_move_speed: float = 10.0
@export var stat_jump_str: float = 14.0
@export var stat_melee_range: float = 4.0
@export var stat_missile_range: float = 12.0
@export var stat_crit_rate: float = 0.05

@export_category("ATB")
@export var atb_passive_gain: float = 3.0
@export var atb_gain_mult: float = 1.0

@export_category("funny stuff")
@export var gravity_mult: float = 1.0
@export var cast_time_mult: float = 1.0

@export_category("RPG Statistics")
@export var rpg_strength: int = 10
@export var rpg_dexterity: int = 10
@export var rpg_constitution: int = 10
@export var rpg_intelligence: int = 10
@export var rpg_wisdom: int = 10
@export var rpg_charisma: int = 10

@export_category("State")
@export var actionable: bool = true
@export var unit_positon: Vector3 = Vector3.ZERO
@export var equipment_list: Array[String] = []
@export var skills: Array[GameSkill] = []
@export var auto_attack_skill: GameSkill
@export var has_target: bool = false
@export var target_position: Vector3 = Vector3.ZERO
@export var status_effects: Dictionary = {}

@onready var unit_info: UnitInfo = $UnitInfo
@onready var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer

var animator: AnimationPlayer

var hardened_armor: int = 0
var last_autoattack_lockout = 0.0

## STATUS EFFECTS 
## are put in here with the name as the key and the
## value as a float noting how much time is left


var current_target: GameUnit = null:
	get():
		return current_target
	set(target):
		if current_target != null:
			current_target.targeting_me.erase(self)
		current_target = target
		if target == null:
			return
		if target.team == Teams.UNTARGETABLE:
			current_target = null
		target.targeting_me.append(self)
		

var targeting_me: Array[GameUnit] = []
var last_prune = 0.0

var last_cast_time = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	recalc_stats()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	
	unit_info.atb = unit_info.atb + (atb_passive_gain * delta)
	unit_info.atb = clamp(unit_info.atb, 0, 100)
	
	if current_target: 
		has_target = true
		target_position = current_target.unit_positon
		if target_position.distance_to(unit_positon) > unit_info.max_target_range:
			current_target = null
			
	else:
		has_target = false
	
	last_cast_time = unit_info.cast_time_left
	
	if unit_info.cast_time_left > 0:
		status_effects["casting"] = -1
		unit_info.cast_time_left -= delta
		if last_cast_time > 0 and unit_info.cast_time_left <= 0:
			cast_over.emit(true)
	else:
		unit_info.cast_time_left = 0
		status_effects.erase("casting")
	
	if NetworkTime.time - 1.5 > last_prune:
		prune_targeting_me()
		last_prune = NetworkTime.time
	
	#if !actionable:
		#last_autoattack_lockout = NetworkTime.time
		
	
	if NetworkTime.time - unit_info.attack_speed > last_autoattack_lockout:
		await auto_attack()
	
	var stale_states = []
	for state in status_effects:
		if status_effects[state] > 0.0:
			status_effects[state] -= delta
		elif status_effects[state] == -1:
			continue
		else:
			stale_states.append(state)
	if stale_states.size() > 0:
		for state in stale_states:
			remove_status(state)
		recalc_stats()

func prune_targeting_me():
	if not is_multiplayer_authority():
		return
	var dead_positions: Array[int] = []
	for i in targeting_me.size():
		var unit = targeting_me[i]
		if unit == null: dead_positions.append(i)
		if unit.current_target != self:
			dead_positions.append(i)
	for i in dead_positions:
		targeting_me.remove_at(i)

func untarget_me():
	if not is_multiplayer_authority():
		return
	var dead_positions: Array[int] = []
	for i in targeting_me.size():
		var unit = targeting_me[i]
		if unit.current_target == self:
			unit.current_target = null
		dead_positions.append(i)
	if dead_positions.size() == 0 or targeting_me.size() == 0:
		return
	for i in dead_positions:
		targeting_me.remove_at(i)

func auto_attack():
	if current_target == null:
		return
	if auto_attack_skill.range_type == "melee":
		if current_target.unit_positon.distance_to(unit_positon) > unit_info.melee_range:
			return
	elif auto_attack_skill.range_type == "ranged":
		if current_target.unit_positon.distance_to(unit_positon) > unit_info.missile_range:
			return
	
	last_autoattack_lockout = NetworkTime.time
	await auto_attack_skill.cast(self, current_target)
	if status_effects.has("empowered"):
		remove_status("empowered")

func recalc_stats():
	unit_info.max_hp = max_hp
	unit_info.current_hp = current_hp
	unit_info.attack_damage = stat_attack_damage
	unit_info.armor = stat_armor
	unit_info.magic_power = stat_magic_power
	unit_info.magic_resist = stat_magic_resist
	unit_info.armor_pen = stat_armor_pen
	unit_info.magic_pen = stat_magic_pen
	unit_info.attack_drain = stat_attack_drain
	unit_info.magic_drain = stat_magic_drain
	unit_info.attack_speed = stat_attack_speed
	unit_info.cooldown_mult = stat_cooldown_mult
	unit_info.move_speed = stat_move_speed
	unit_info.missile_range = stat_missile_range
	unit_info.evasion = stat_evasion
	unit_info.poise = stat_poise
	unit_info.jump_str = stat_jump_str
	unit_info.gravity_mult = gravity_mult
	unit_info.melee_range = stat_melee_range
	unit_info.cast_time_mult = cast_time_mult
	unit_info.crit_rate = stat_crit_rate
	
	if status_effects.has("low_g"):
		unit_info.gravity_mult *= 0.5
	
	if status_effects. has("sprint"):
		unit_info.move_speed *= 1.6
	
	if status_effects.has("haste"):
		var haste_mult = 1.5
		unit_info.cooldown_mult *= 0.8
		unit_info.cast_time_mult *= 0.8
		unit_info.move_speed *= haste_mult
		unit_info.jump_str *= haste_mult
		unit_info.attack_speed *= haste_mult
	
	if status_effects.has("weak"):
		unit_info.attack_damage *= 0.5
		unit_info.magic_power *= 0.5
	
	if status_effects.has("slow"):
		var slow_mult = 0.6
		unit_info.cooldown_mult *= 1.1
		unit_info.cast_time_mult *= 1.3
		unit_info.move_speed *= slow_mult
		unit_info.jump_str *= slow_mult
		unit_info.evasion *= slow_mult
	
	if status_effects.has("empowered"):
		unit_info.attack_damage *= 1.5
		unit_info.crit_rate = 1.0
		unit_info.armor_pen += unit_info.attack_damage / 2
		unit_info.melee_range *= 1.3
	
	if status_effects.has("stun"):
		unit_info.move_speed *= 0
		unit_info.jump_str *= 0
		unit_info.poise *= 0
		unit_info.evasion *= 0
	
	max_target_range = unit_info.missile_range
	
	if status_effects.has("dodge"):
		unit_info.evasion = 1.0
	
	skills.clear()
	unit_info.skills_dict.clear()
	for child in get_children():
		if child is GameSkill:
			if child.is_internal: continue
			if child.is_auto_attack: continue
			skills.append(child)
			unit_info.skills_dict[child.skill_name] = skills.size() - 1
	
	stats_update.emit()

## OK SO this function returns a dict that has 3 keys.
## inflicted: int = amount of damage that was done in reality
## mitigated: int = difference between raw damage and actual damage
## status_code: String = a string specifying special cases. usually "normal"
##                       but might be someting like "evaded" etc.

func take_damage(from: GameUnit, damage: DamageInstance) -> Dictionary:
	var cooked: float = 0.0
	recalc_stats()
	attacked.emit(from)
	
	if randf_range(0.0, 1.0) < unit_info.evasion:
		if damage.can_dodge:
			MmoUtils.rpc("text_popup", unit_positon, "Evade!", 1.0, 1.0, Color.AQUA, Color.BLACK)
			return {"inflicted": 0, "mitigated": damage.raw, "status_code": "evaded"}
		else: 
			MmoUtils.rpc("eventlog", unit_name + " would have evaded " + from.unit_name + "'s attack but could not!", "combat")
	
	var textcolor = [Color.DARK_RED, Color.MEDIUM_VIOLET_RED]
	var textscale = 1.0
	var suffix = ""
	
	
	if damage.damage_type == "attack":
		var effective_armor: float = unit_info.armor - damage.bonus_armor_pen - from.unit_info.armor_pen
		effective_armor = max(hardened_armor, effective_armor)
		cooked = damage.raw / (1.0 + (effective_armor/10))
		textcolor = [Color.DARK_RED, Color.WHITE]
	elif damage.damage_type == "magic":
		var effective_resist = unit_info.magic_resist - damage.bonus_magic_pen - from.unit_info.magic_pen
		effective_resist = max(0.0, effective_resist)
		cooked = damage.raw / (1 + (effective_resist/100))
		textcolor = [Color.REBECCA_PURPLE, Color.WHITE]
	elif damage.damage_type == "true":
		cooked = damage.raw
		textcolor = [Color.WHITE, Color.BLACK]
	
	if randf_range(0.0, 1.0) < from.unit_info.crit_rate:
		cooked *= 2.0
		textcolor = [Color.GOLD, Color.BLACK]
		MmoUtils.rpc("eventlog", from.unit_name + "'s attack was critical!", "combat")
		suffix = "!!!"
	
	var final_dmg = ceili(cooked)
	var dmg_report = {"inflicted": final_dmg, "mitigated": damage.raw - final_dmg, "status_code": "normal"}
	if final_dmg > 0:
		damaged.emit(from, dmg_report)
	
	MmoUtils.rpc("text_popup", unit_positon, str(final_dmg) + suffix, textscale, 1.0, textcolor[0], textcolor[1])
	current_hp -= final_dmg
	recalc_stats()
	return dmg_report

func add_status(state: String, duration: float):
	status_effects[state] = duration
	status_added.emit(state, duration)
	
	recalc_stats()
	#if team == Teams.FRIENDLY:
		#MmoUtils.rpc("eventlog", unit_name + " is " + state + " for " + str(duration), "status")

func remove_status(state: String):
	status_effects.erase(state)
	recalc_stats()
	status_removed.emit(state)
	#if team == Teams.FRIENDLY:
		#MmoUtils.rpc("eventlog", unit_name + " is no longer " + str(state), "status")
