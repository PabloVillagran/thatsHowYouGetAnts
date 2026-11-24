extends Control


func _ready() -> void:
	$CenterContainer/MenuArt/PlayButton.pressed.connect(_on_play_pressed)
	$CenterContainer/MenuArt/ResetButton.pressed.connect(_on_reset_pressed)
	$CenterContainer/MenuArt/ExitButton.pressed.connect(_on_exit_pressed)


func _on_play_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://MainScene.tscn")
	if error != OK:
		push_error("Could not start the game: %s" % error_string(error))


func _on_reset_pressed() -> void:
	GameState.reset_game()


func _on_exit_pressed() -> void:
	get_tree().quit()
