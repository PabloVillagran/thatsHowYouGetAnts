extends Camera2D

const MAX_ZOOM: float = 10.0
const ZOOM_STEP: float = 1.15

var touches: Dictionary = {}
var mouse_panning: bool = false


func _ready() -> void:
	_update_minimum_zoom()
	# Wait until AntSource has finished positioning itself and spawning the queen.
	call_deferred("recenter_on_colony")


func recenter_on_colony() -> void:
	var ant_source := get_parent().get_node_or_null("AntSource")
	if ant_source == null:
		return
	var queen_ants: Array = ant_source.get("queen_ants")
	if not queen_ants.is_empty() and is_instance_valid(queen_ants[0]):
		global_position = queen_ants[0].global_position
	else:
		global_position = ant_source.global_position


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and mouse_panning:
		position -= event.relative / zoom


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		touches[event.index] = event.position
	else:
		touches.erase(event.index)


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if not touches.has(event.index):
		return
	var previous_distance := _touch_distance()
	touches[event.index] = event.position
	if touches.size() >= 2:
		var current_distance := _touch_distance()
		if previous_distance > 0.0 and current_distance > 0.0:
			_set_zoom(zoom.x * current_distance / previous_distance)
	elif touches.size() == 1:
		position -= event.relative / zoom


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_set_zoom(zoom.x * ZOOM_STEP)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_set_zoom(zoom.x / ZOOM_STEP)
	elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
		mouse_panning = event.pressed


func _touch_distance() -> float:
	if touches.size() < 2:
		return 0.0
	var points: Array = touches.values()
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


func _update_minimum_zoom() -> void:
	var ant_count := get_tree().get_nodes_in_group("ants").size()
	var minimum_zoom := maxf(0.1, 0.5 / sqrt(float(maxi(ant_count, 1))))
	zoom = Vector2.ONE * clampf(zoom.x, minimum_zoom, MAX_ZOOM)


func _set_zoom(next_zoom: float) -> void:
	_update_minimum_zoom()
	var ant_count := get_tree().get_nodes_in_group("ants").size()
	var minimum_zoom := maxf(0.1, 0.5 / sqrt(float(maxi(ant_count, 1))))
	var bounded_zoom := clampf(next_zoom, minimum_zoom, MAX_ZOOM)
	zoom = Vector2.ONE * bounded_zoom
