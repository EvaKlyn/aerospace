extends Window

@export var camera_pivot: Node3D

@export var name_edit: LineEdit
@export var build_opt: OptionButton
@export var save_button: Button

@export_category("Stat labels")
@export var mhp_label: Label
@export var might_label: Label
@export var finesse_label: Label
@export var agility_label: Label
@export var endurance_label: Label
@export var arcana_label: Label
@export var psycho_label: Label
@export var luck_label: Label
@export var tempo_label: Label
@export var wits_label: Label
@export var skills_container: HFlowContainer

@export_category("Character Creator")
@export var ancestry_dropdown: OptionButton
@export var accent_color_picker: ColorPickerButton
@export var head_scale_slider: HSlider
@export var hand_scale_slider: HSlider
@export var chara_preview_parent: Node3D

## Data = {
##   name = (character name)
##   level = (level)
##   stats = {
##     might = _
##     finesse = _
##     agility = _
##     endurance = _
##     arcana = _
##     psycho = _
##     charisma = _
##     luck = _
##     tempo = _
##     wits = _
##     }
##   skills = [array of IDs]
##   ready_skills = [array of IDs]
##   equipped = [array of IDs]
##   inventory = [array of IDs]
## }
var base_data = {
	"name" = "",
	level = 1,
	stats = {
		might = 0,
		finesse = 0,
		agility = 0,
		endurance = 0,
		arcana = 0,
		psycho = 0,
		charisma = 0,
		luck = 0,
		tempo = 0,
		wits = 0,
	},
	skills = [],
	ready_skills = [],
	equipped = [],
	inventory = []
}

var current_data = {
	
}

var _preview_body: Node3D = null

var build_raider_skills = ["sk_generic_melee_aa", "sk_generic_sprint", 
	"sk_raider_brutal_attack", "sk_raider_dash"]
var build_raider_stats = {
	might = 5,
	finesse = 1,
	tempo = 2,
	agility = 3,
	endurance = 4
}
var build_adept_skills = []
var build_adept_stats = {
	arcana = 5,
	psycho = 4,
	tempo = 3,
	wits = 2,
	agility = 1
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_data = base_data.duplicate(true)
	apply_build(0)
	
	# Connect customization controls to update preview
	ancestry_dropdown.item_selected.connect(func(_index): update_preview())
	accent_color_picker.color_changed.connect(func(_color): update_preview())
	head_scale_slider.value_changed.connect(func(_value): update_preview())
	hand_scale_slider.value_changed.connect(func(_value): update_preview())
	
	visibility_changed.connect(func():
		if visible:
			# Reset fields to default when opened
			build_opt.selected = 0
			ancestry_dropdown.selected = 0
			accent_color_picker.color = Color.WHITE
			head_scale_slider.value = 1.0
			hand_scale_slider.value = 1.0
			name_edit.text = ""
			apply_build(0)
			update_preview()
	)
	
	_update_all()
	update_preview()

func _physics_process(delta: float) -> void:
	if is_instance_valid(camera_pivot):
		camera_pivot.rotate_y(1*delta)
	
	if name_edit.text == "":
		save_button.disabled = true
	else:
		save_button.disabled = false

func apply_build(idx: int):
	current_data = base_data.duplicate(true)
	current_data["name"] = name_edit.text.left(16)
	match idx:
		0:
			for key in build_raider_stats:
				current_data["stats"][key] = build_raider_stats[key]
			current_data["skills"].append_array(build_raider_skills)
		1: 
			for key in build_adept_stats:
				current_data["stats"][key] = build_adept_stats[key]
			current_data["skills"].append_array(build_adept_skills)
	_update_all()

func _update_all() -> void:
	var mhp = 13 + (current_data["stats"]["endurance"] * 5)
	mhp_label.text = str(mhp)
	might_label.text = str(current_data["stats"]["might"])
	finesse_label.text = str(current_data["stats"]["finesse"])
	agility_label.text = str(current_data["stats"]["agility"])
	endurance_label.text = str(current_data["stats"]["endurance"])
	arcana_label.text = str(current_data["stats"]["arcana"])
	psycho_label.text = str(current_data["stats"]["psycho"])
	luck_label.text = str(current_data["stats"]["luck"])
	tempo_label.text = str(current_data["stats"]["tempo"])
	wits_label.text = str(current_data["stats"]["wits"])
	
	for child in skills_container.get_children():
		child.queue_free()
	
	for skill_id in current_data["skills"]:
		var skill = Stuff.get_skill_node(skill_id)
		var new_label = Label.new()
		new_label.text = "["+skill.skill_name+"]"
		skills_container.add_child(new_label)

func _on_name_edit_text_changed(new_text: String) -> void:
	current_data["name"] = name_edit.text.left(16)

func _on_option_button_item_selected(index: int) -> void:
	apply_build(index)

func _on_save_button_pressed() -> void:
	current_data["customization"] = {
		"ancestry": ancestry_dropdown.text.to_lower(),
		"clothes_color": accent_color_picker.color,
		"head_scale": head_scale_slider.value,
		"hand_scale": hand_scale_slider.value
	}
	
	var chars: Array = SaveSystem.get_var("characters", [])
	chars.append(current_data)
	SaveSystem.set_var("characters", chars)
	SaveSystem.save()
	visible = false
	current_data = base_data.duplicate(true)
	name_edit.text = ""

func _on_close_requested() -> void:
	visible = false
	current_data = base_data.duplicate(true)
	name_edit.text = ""

func update_preview():
	if not chara_preview_parent:
		return
		
	# Clear previous preview body only
	if is_instance_valid(_preview_body):
		_preview_body.queue_free()
		_preview_body = null
		
	var ancestry = ancestry_dropdown.text.to_lower()
	var new_body
	match ancestry:
		"human":
			var scene: PackedScene = load("res://scenes/chara/bodytypes/body_type_human.tscn")
			new_body = scene.instantiate()
		"bird":
			var scene: PackedScene = load("res://scenes/chara/bodytypes/body_type_bird.tscn")
			new_body = scene.instantiate()
		_:
			var scene: PackedScene = load("res://scenes/chara/bodytypes/body_type_human.tscn")
			new_body = scene.instantiate()
			
	_preview_body = new_body
	chara_preview_parent.add_child(_preview_body)
	
	# Apply customization parameters to preview mesh
	var clothes_color = accent_color_picker.color
	var head_scale = clamp(head_scale_slider.value, 0.7, 1.4)
	var hand_scale = clamp(hand_scale_slider.value, 0.7, 1.4)
	
	for mesh in new_body.clothes_parts:
		if mesh is MeshInstance3D:
			mesh.get_active_material(0).albedo_color = clothes_color
		if mesh is Sprite3D:
			mesh.modulate = clothes_color
			
	new_body.head.scale = Vector3(head_scale, head_scale, head_scale)
	new_body.left_hand.scale = Vector3(hand_scale, hand_scale, hand_scale)
	new_body.right_hand.scale = Vector3(hand_scale, hand_scale, hand_scale)
