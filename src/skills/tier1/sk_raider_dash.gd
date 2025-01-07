extends GameSkill

@export var fx: PackedScene

func custom_cast(caster: GameUnit, _target: GameUnit) -> SkillResult:
	caster.recalc_stats()
	var parent = caster.get_parent()
	if !parent is BasePlayer:
		return SkillResult.INVALID
	parent.game_unit.add_status("dodge", d_intangibility_time)
	# MmoUtils.rpc("text_popup", parent.vis.global_position + Vector3(0,1,0), "Dash!", 1.0, 2.0, Color.WHITE, Color.DARK_GRAY)
	
	var result = SkillResult.SUCCESS
	var target = caster.current_target
	
	if target:
		var damage = DamageInstance.new()
		damage.raw = caster.unit_info.attack_damage * 0.5
		damage.bonus_armor_pen = base_armor_pen
		damage.bonus_magic_pen = base_magic_pen
		damage.damage_type = damage_type
		
		var report = target.take_damage(caster, damage)
		var str_message: String = ""
		if report["status_code"] == "normal":
			str_message = target.unit_name + " took " + str(report["inflicted"]) + "(-" + str(report["mitigated"]) + ") " + damage.damage_type + " damage from " + caster.unit_name + "'s " + skill_name + "."
			result = SkillResult.SUCCESS
			caster.unit_info
			MmoUtils.rpc("do_fx", fx.resource_path, caster.unit_positon, target.unit_positon)
			caster.take_healing(report["inflicted"] * 0.5)
		elif report["status_code"] == "evaded":
			str_message = target.unit_name + " evaded " + caster.unit_name + "'s dagger throw."
			result = SkillResult.SUCCESS
		else:
			str_message = "something went weird lol."
		MmoUtils.rpc("eventlog", str_message, "combat")
	
	caster.last_autoattack_lockout = 0.0
	return result
