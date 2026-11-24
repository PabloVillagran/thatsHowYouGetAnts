extends Button


func _ready() -> void:
	toggle_mode = true
	text = "Heat Map: Off"
	toggled.connect(_on_toggled)


func _on_toggled(enabled: bool) -> void:
	text = "Heat Map: On" if enabled else "Heat Map: Off"
	var scene := get_tree().current_scene
	if scene == null:
		return
	var ant_source := scene.get_node_or_null("AntSource")
	if ant_source != null:
		ant_source.set("debug_step_heatmap", enabled)
