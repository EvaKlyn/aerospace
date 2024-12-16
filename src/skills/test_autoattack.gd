extends GameSkill

func custom_cast(caster: GameUnit, target: GameUnit) -> SkillResult:
	caster.recalc_stats()
	var damage = DamageInstance.new()
	damage.raw = caster.unit_info.attack_damage
	damage.damage_type = "attack"
	var report = target.take_damage(caster, damage)
	var str_message = "hhuh?"
	if report["status_code"] == "normal":
		str_message = target.unit_name + " took " + str(report["inflicted"]) + "(-" + str(report["mitigated"]) + ") " + damage.damage_type + " damage from " + caster.unit_name + "'s " + skill_name + "."
	elif report["status_code"] == "evaded":
		str_message = target.unit_name + " evaded " + caster.unit_name + "'s " + skill_name + "."
	else:
		str_message = "something went weird lol."
	MmoUtils.rpc("eventlog", str_message, "combat")
	return SkillResult.SUCCESS
