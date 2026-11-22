extends Button


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	var camera := get_tree().current_scene.get_node_or_null("Camera2D")
	if camera != null and camera.has_method("recenter_on_colony"):
		camera.recenter_on_colony()
