extends GameSkill

func custom_cast(caster: GameUnit, target: GameUnit) -> SkillResult:
	caster.recalc_stats()
	var parent = caster.get_parent()
	if !parent is BasePlayer:
		return SkillResult.INVALID
	var impulse_vec: Vector3 = parent.physics_body.move_dir
	impulse_vec.y = 0.5
	impulse_vec = impulse_vec.normalized()
	parent.physics_body.rpc("impulse", impulse_vec, 28)
	parent.game_unit.add_status("low_g", 1.5)
	MmoUtils.rpc("text_popup", parent.vis.global_position + Vector3(0,1,0), "Jump!", 1.0, 2.0, Color.WHITE, Color.DARK_GRAY)
	return SkillResult.SUCCESS
