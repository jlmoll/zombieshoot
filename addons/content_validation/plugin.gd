@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_tool_menu_item("Validate Gameplay Content", _validate_open_scene)


func _exit_tree() -> void:
	remove_tool_menu_item("Validate Gameplay Content")


func _build() -> bool:
	return _validate_open_scene()


func _validate_open_scene() -> bool:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return true
	var errors := ContentValidator.validate_tree(root)
	if root is Game:
		if root.map_scene == null:
			errors.append("Game needs a map scene.")
		else:
			var map_instance: Node = root.map_scene.instantiate()
			var session := Game.RUN_SCENE.instantiate()
			if not map_instance is Arena:
				errors.append("Game map scene needs an Arena root.")
			else:
				errors.append_array(ContentValidator.validate_run(map_instance, session))
			map_instance.free()
			session.free()
	elif root is Arena:
		var session := Game.RUN_SCENE.instantiate()
		errors.append_array(ContentValidator.validate_run(root, session))
		session.free()
	for error in errors:
		push_error("Content validation: " + error)
	if errors.is_empty():
		print("Gameplay content validation passed: " + root.scene_file_path)
	return errors.is_empty()
