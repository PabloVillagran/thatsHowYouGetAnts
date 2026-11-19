extends Control


func _ready() -> void:
	$CenterContainer/Menu/Incremental1Button.pressed.connect(_on_incremental_1_pressed)
	$CenterContainer/Menu/QueenAnt1Button.pressed.connect(_on_queen_ant_1_pressed)


func _on_incremental_1_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://MainScene.tscn")
	if error != OK:
		push_error("Could not open Incremental 1: %s" % error_string(error))


func _on_queen_ant_1_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/queen_ant_1.tscn")
	if error != OK:
		push_error("Could not open Queen Ant 1: %s" % error_string(error))
