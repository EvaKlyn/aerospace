extends Area3D

@export var strength: float = 40

func _on_body_entered(body: Node3D) -> void:
	if !is_multiplayer_authority():
		return
	
	var parent = body.get_parent()
	if parent is BasePlayer:
		parent.physics_body.rpc("impulse", -global_basis.z, strength)
		parent.game_unit.add_status("low_g", 1.5)
		MmoUtils.rpc("text_popup", parent.physics_body.global_position + Vector3(0,1,0), "Bounce...", 1.0, 2.0, Color.WHITE, Color.DARK_GRAY)
		print(-global_basis.z * strength)
