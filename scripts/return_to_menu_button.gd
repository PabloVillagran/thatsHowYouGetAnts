extends Button


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	if error != OK:
		push_error("Could not return to main menu: %s" % error_string(error))
