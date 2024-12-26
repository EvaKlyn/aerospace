extends GameSkill

func custom_cast(caster: GameUnit, _target: GameUnit) -> SkillResult:
	caster.recalc_stats()
	var parent = caster.get_parent()
	if !parent is BasePlayer:
		return SkillResult.INVALID
	parent.game_unit.add_status("dodge", 0.3)
	MmoUtils.rpc("text_popup", parent.vis.global_position + Vector3(0,1,0), "Dodge!", 1.0, 2.0, Color.WHITE, Color.DARK_GRAY)
	await get_tree().create_timer(0.6).timeout
	caster.last_autoattack_lockout = 0.0
	return SkillResult.SUCCESS
