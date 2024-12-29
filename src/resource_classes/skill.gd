extends Node
class_name GameSkill

## CLASS FOR SKILLS!
## LITERALLY EVERYTHING SHOULD BE A SKILL.
## CUSTOM LOGIC SHOULD BE DONE BY OVERRIDING THE "custom_cast" FUNCTION

enum SkillResult {
	SUCCESS,
	INTERRUPT,
	FIZZLE,
	INVALID,
	ON_COOLDOWN,
}

@onready var cooldown_timer = Timer.new()

@export_category("Basic Info")
@export var skill_name: String = "Unknown Skill"
@export var icon: Texture2D = PlaceholderTexture2D.new()
@export var is_auto_attack: bool = false
@export var is_internal: bool = false
@export var base_cooldown: float = 2.0
@export var cast_time: float = 0.0
@export var auto_attack_reset: bool = false
@export_range(0, 100) var atb_gain: int = 0
@export_range(0, 100) var atb_cost: int = 10
@export_range(0.0, 1.0) var failure_chance: float = 0.0
@export_enum("melee", "ranged") var range_type: String = "melee"
@export_enum("enemy", "ally", "object", "self") var target_type: String = "enemy"
@export_enum("skill", "spell", "special", "misc") var category: String = "skill"
@export_enum("data-driven", "callable") var logic_type: String

@export_category("Text Popup")
@export_enum("none", "caster", "target") var popup: String = "none"
@export var popup_text: String = ""
@export var popup_fill: Color = Color.WHITE
@export var popup_border: Color = Color.WHITE
@export var popup_scale = 1.0
@export var popup_lifetime = 1.0

@export_category("Visuals")
@export var fx_scene: PackedScene
@export var cast_animation_name: StringName
@export var result_offset: float = 0.0

@export_category("Damage Details")
@export var inflicts_damage: bool = false
@export var base_damage: int = 0
@export var can_crit: bool = false
@export_enum("attack", "magic", "true") var damage_type: String = "attack"
@export_enum("none", "attack_damage", "magic_power", "special") var damage_scales_with: String = "none"
@export var damage_special_scaler: NodePath = ""
@export var base_armor_pen: int = 0
@export var base_magic_pen: int = 0
@export var base_attack_drain: int = 0
@export var base_magic_drain: int = 0
@export var damage_elements: Array[String] = []

@export_category("Healing Details")
@export var does_healing: bool = false
@export var base_healing: int = 0
@export_enum("none", "attack_damage", "magic_power", "special") var heal_scales_with: String = "none"
@export var heal_special_scaler: NodePath = ""
@export var heal_elements: Array[String] = []

@export_category("Status Details")
@export var gives_status: bool = false
@export var statuses: Dictionary = {}

func _ready() -> void:
	add_child(cooldown_timer)
	cooldown_timer.one_shot = true

func cast(caster: GameUnit, target: GameUnit = null) -> SkillResult:
	if not caster:
		return SkillResult.INVALID
	if not caster.actionable:
		return SkillResult.INVALID
	if cast_time > 0 and caster.unit_info.cast_time_left > 0:
		return SkillResult.INVALID
	if target_type != "self" and !target:
		return SkillResult.INVALID
	if not is_auto_attack and cooldown_timer.time_left > 0:
		MmoUtils.rpc("text_popup", caster.unit_positon, str(cooldown_timer.time_left).left(4)+ " sec", 0.5, 1.0, Color.ROSY_BROWN, Color.WEB_MAROON)
		return SkillResult.ON_COOLDOWN
	if caster.unit_info.atb < atb_cost:
		return SkillResult.INVALID
	
	if not is_auto_attack:
		caster.unit_info.atb -= atb_cost
		caster.unit_info.atb += atb_gain * caster.atb_gain_mult
	if is_auto_attack and !caster.status_effects.has("empowered"):
		caster.unit_info.atb -= atb_cost
		caster.unit_info.atb += atb_gain * caster.atb_gain_mult
	
	if base_cooldown > 0:
		cooldown_timer.one_shot = true
		cooldown_timer.start(base_cooldown * caster.unit_info.cooldown_mult)
	
	
	
	if cast_time > 0:
		caster.unit_info.cast_time_left = cast_time * caster.unit_info.cast_time_mult
		caster.unit_info.full_cast_time = cast_time * caster.unit_info.cast_time_mult
		var success = await caster.cast_over
		
		if !success:
			return SkillResult.INTERRUPT
	
	if cast_animation_name and caster.animator:
		caster.animator.play(cast_animation_name)
		caster.status_effects["animating"] = caster.animator.current_animation_length
	
	await get_tree().create_timer(result_offset).timeout
	
	var result = await _realcast(caster, target) 
	
	if auto_attack_reset:
		caster.last_autoattack_lockout = 0.0
	
	match result:
		SkillResult.SUCCESS:
			if fx_scene:
				var targetpos = null
				if target: targetpos = target.unit_positon
				MmoUtils.rpc("do_fx", fx_scene.resource_path, caster.unit_positon, targetpos)
	return result

func _realcast(caster: GameUnit, target: GameUnit) -> SkillResult:
	var result = SkillResult.FIZZLE
	
	if target_type != "self":
		if range_type == "melee" and caster.unit_positon.distance_to(target.unit_positon) > caster.unit_info.melee_range:
			MmoUtils.rpc("text_popup", target.unit_positon, "Out of range!", 1.0, 1.0, Color.WHITE, Color.BLACK)
			return SkillResult.FIZZLE
		if range_type == "ranged" and caster.unit_positon.distance_to(target.unit_positon) > caster.unit_info.missile_range:
			MmoUtils.rpc("text_popup", target.unit_positon, "Out of range!", 1.0, 1.0, Color.WHITE, Color.BLACK)
			return SkillResult.FIZZLE
	
	if randf_range(0.0, 1.0) < failure_chance:
		MmoUtils.rpc("text_popup", caster.unit_positon, "Fizzled!", 1.0, 1.0, Color.WHITE, Color.BLACK)
		return SkillResult.FIZZLE
	
	if logic_type == "callable":
		result = await custom_cast(caster, target)
		match result:
			SkillResult.FIZZLE:
				MmoUtils.rpc("eventlog", caster.unit_name + " failed to use " + skill_name + ".")
				MmoUtils.rpc("text_popup", caster.unit_positon, "Failed!", 1.0, 1.0, Color.WHITE, Color.BLACK)
			SkillResult.INTERRUPT:
				MmoUtils.rpc("text_popup", caster.unit_positon, "Interrupted!", 1.0, 1.0, Color.WHITE, Color.BLACK)
				MmoUtils.rpc("eventlog", caster.unit_name + " was interrupted using " + skill_name + ".")
		return result
	
	if target_type == "self":
		target = caster
	
	if inflicts_damage:
		var damage = DamageInstance.new()
		damage.raw = base_damage
		damage.bonus_armor_pen = base_armor_pen
		damage.bonus_magic_pen = base_magic_pen
		damage.damage_type = damage_type
		
		match damage_scales_with:
			"attack_damage":
				damage.raw = damage.raw + caster.unit_info.attack_damage
			"magic_power":
				damage.raw = damage.raw + caster.unit_info.magic_power
			_:
				pass
		
		var report = target.take_damage(caster, damage)
		var str_message: String = ""
		if report["status_code"] == "normal":
			str_message = target.unit_name + " took " + str(report["inflicted"]) + "(-" + str(report["mitigated"]) + ") " + damage.damage_type + " damage from " + caster.unit_name + "'s " + skill_name + "."
			result = SkillResult.SUCCESS
		elif report["status_code"] == "evaded":
			str_message = target.unit_name + " evaded " + caster.unit_name + "'s " + skill_name + "."
			result = SkillResult.SUCCESS
		else:
			str_message = "something went weird lol."
		MmoUtils.rpc("eventlog", str_message, "combat")
	
	if gives_status:
		for status in statuses:
			if statuses[status] is float:
				target.add_status(status, statuses[status])
		result = SkillResult.SUCCESS
	
	if popup == "caster":
		MmoUtils.rpc("text_popup", caster.unit_positon, popup_text, popup_scale, popup_lifetime, popup_fill, popup_border)
	if popup == "target":
		MmoUtils.rpc("text_popup", target.unit_positon, popup_text, popup_scale, popup_lifetime, popup_fill, popup_border)
	
	match result:
		SkillResult.FIZZLE:
			MmoUtils.rpc("eventlog", caster.unit_name + " failed to use " + skill_name + ".")
			MmoUtils.rpc("text_popup", caster.unit_positon, "Failed!", 1.0, 1.0, Color.WHITE, Color.BLACK)
		SkillResult.INTERRUPT:
			MmoUtils.rpc("eventlog", caster.unit_name + " was interrupted using " + skill_name + ".")
			MmoUtils.rpc("text_popup", caster.unit_positon, "Interrupted!", 1.0, 1.0, Color.WHITE, Color.BLACK)
	return result

func custom_cast(caster: GameUnit, target: GameUnit) -> SkillResult:
	return SkillResult.FIZZLE
