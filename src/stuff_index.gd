extends Node

var _skill_list = {}

func _enter_tree() -> void:
	load_skills_from_filesystem()
	print(_skill_list)

func load_skills_from_filesystem():
	var skill_files_paths = get_all_files("res://src/skills/", "tscn")
	
	for path: String in skill_files_paths:
		print(path)
		var idx = path.get_slice_count("/")
		var id = path.get_slice("/", idx-1)
		id = id.get_slice(".", 0)
		_skill_list[id] = load(path)

static func get_all_files(path: String, file_ext := "", files : Array[String] = []) -> Array[String]:
	var dir : = DirAccess.open(path)
	if file_ext.begins_with("."): # get rid of starting dot if we used, for example ".tscn" instead of "tscn"
		file_ext = file_ext.substr(1,file_ext.length()-1)
	if DirAccess.get_open_error() == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				# recursion
				files = get_all_files(dir.get_current_dir() +"/"+ file_name, file_ext, files)
			else:
				if file_ext and file_name.get_extension() != file_ext:
					file_name = dir.get_next()
					continue
				
				files.append(dir.get_current_dir() +"/"+ file_name)
			file_name = dir.get_next()
	else:
		print("[File loader] An error occurred when trying to access %s." % path)
	return files

func get_skill_node(skill_id: String) -> GameSkill:
	var skill = _skill_list.get(skill_id, null)
	
	if not skill:
		var epic_fail: GameSkill = _skill_list["sk_debug_epic_fail"].instantiate()
		return epic_fail
	
	var instance = skill.instantiate()
	
	if not instance or !is_instance_of(instance, GameSkill):
		var epic_fail: GameSkill = _skill_list["sk_debug_epic_fail"].instantiate()
		return epic_fail
	
	return instance
