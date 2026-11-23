extends Camera2D

const MAX_ZOOM: float = 10.0
const MIN_ZOOM: float = 0.001
const ZOOM_STEP: float = 1.15
const FIT_PADDING_PIXELS: float = 48.0

var touches: Dictionary = {}
var ui_touches: Dictionary = {}
var mouse_panning: bool = false


func _ready() -> void:
	# Wait until AntSource has positioned itself and spawned the colony.
	call_deferred("recenter_on_colony")


func recenter_on_colony() -> void:
	var ants := get_tree().get_nodes_in_group("ants")
	var colony_center := Vector2.ZERO
	var ant_count := 0
	for ant in ants:
		if not is_instance_valid(ant) or ant.is_queued_for_deletion():
			continue
		colony_center += (ant as Node2D).global_position
		ant_count += 1
	if ant_count == 0:
		var ant_source := get_parent().get_node_or_null("AntSource")
		if ant_source != null:
			global_position = ant_source.global_position
		zoom = Vector2.ONE * MAX_ZOOM
		return

	colony_center /= float(ant_count)
	global_position = colony_center
	var farthest_ant_distance := 0.0
	for ant in ants:
		if not is_instance_valid(ant) or ant.is_queued_for_deletion():
			continue
		farthest_ant_distance = maxf(
			farthest_ant_distance,
			colony_center.distance_to((ant as Node2D).global_position)
		)
	var viewport_size := get_viewport_rect().size
	var available_radius := maxf(1.0, minf(viewport_size.x, viewport_size.y) * 0.5 - FIT_PADDING_PIXELS)
	var fit_zoom := MAX_ZOOM
	if farthest_ant_distance > 0.0:
		fit_zoom = available_radius / farthest_ant_distance
	zoom = Vector2.ONE * clampf(fit_zoom, MIN_ZOOM, MAX_ZOOM)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and mouse_panning:
		if not _is_over_action_area(event.position):
			position -= event.relative / zoom


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		touches[event.index] = event.position
		ui_touches[event.index] = _is_over_action_area(event.position)
	else:
		touches.erase(event.index)
		ui_touches.erase(event.index)


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if not touches.has(event.index):
		return
	var previous_distance := _touch_distance()
	touches[event.index] = event.position
	if ui_touches.get(event.index, false):
		return
	if _is_over_action_area(event.position):
		ui_touches[event.index] = true
		return
	if _has_ui_touch():
		return
	if touches.size() >= 2:
		var current_distance := _touch_distance()
		if previous_distance > 0.0 and current_distance > 0.0:
			_set_zoom(zoom.x * current_distance / previous_distance)
	elif touches.size() == 1:
		position -= event.relative / zoom


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		if not _is_over_action_area(event.position):
			_set_zoom(zoom.x * ZOOM_STEP)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		if not _is_over_action_area(event.position):
			_set_zoom(zoom.x / ZOOM_STEP)
	elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
		mouse_panning = event.pressed and not _is_over_action_area(event.position)


func _has_ui_touch() -> bool:
	for is_ui_touch in ui_touches.values():
		if is_ui_touch:
			return true
	return false


func _is_over_action_area(screen_position: Vector2) -> bool:
	var action_area: Control = get_parent().get_node_or_null("UI/PurchaseScroll") as Control
	return action_area != null and action_area.visible and action_area.get_global_rect().has_point(screen_position)


func _touch_distance() -> float:
	if touches.size() < 2:
		return 0.0
	var points: Array = touches.values()
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


func _set_zoom(next_zoom: float) -> void:
	var bounded_zoom := clampf(next_zoom, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2.ONE * bounded_zoom
