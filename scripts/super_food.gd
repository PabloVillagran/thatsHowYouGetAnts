extends Area2D

signal collected

const STAR_OUTER_RADIUS: float = 20.0
const STAR_INNER_RADIUS: float = 9.0
const LIFETIME_SECONDS: float = 50.0
const BASE_SCREEN_SIZE: float = 20.0
const MIN_SCREEN_SIZE: float = 22.0
const SIZE_FACTOR_PER_ZOOM: float = 0.2

var lifetime_remaining: float = LIFETIME_SECONDS


func _ready() -> void:
	visible = false
	input_pickable = true
	rotation = 0.0
	var points := _star_points(STAR_OUTER_RADIUS, STAR_INNER_RADIUS)
	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = points
	visual.color = Color(1.0, 0.88, 0.16, 1.0)
	visual.z_index = 1
	add_child(visual)
	var collision := CollisionPolygon2D.new()
	collision.name = "PickupArea"
	collision.polygon = points
	add_child(collision)
	_add_glitter()
	input_event.connect(_on_input_event)
	if _update_screen_scale():
		visible = true
	else:
		input_pickable = false


func _process(delta: float) -> void:
	lifetime_remaining -= delta
	if lifetime_remaining <= 0.0:
		queue_free()
		return
	if _update_screen_scale() and not visible:
		input_pickable = true
		visible = true


func _update_screen_scale() -> bool:
	var active_camera := get_viewport().get_camera_2d()
	if active_camera == null:
		return false
	var camera_zoom := maxf(active_camera.zoom.x, 0.001)
	var screen_size := maxf(MIN_SCREEN_SIZE, BASE_SCREEN_SIZE * pow(SIZE_FACTOR_PER_ZOOM, camera_zoom - 1.0))
	var world_diameter := STAR_OUTER_RADIUS * 2.0
	var scale_factor := screen_size / (world_diameter * camera_zoom)
	scale = Vector2.ONE * scale_factor
	return true


func _star_points(outer_radius: float, inner_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(10):
		var angle := -PI * 0.5 + TAU * float(index) / 10.0
		var radius := outer_radius if index % 2 == 0 else inner_radius
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	return points


func _add_glitter() -> void:
	var glitter := CPUParticles2D.new()
	glitter.name = "Glitter"
	glitter.amount = 10
	glitter.lifetime = 0.8
	glitter.preprocess = 0.8
	glitter.local_coords = true
	glitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	glitter.emission_sphere_radius = STAR_OUTER_RADIUS
	glitter.direction = Vector2.UP
	glitter.spread = 180.0
	glitter.gravity = Vector2.ZERO
	glitter.initial_velocity_min = 0.5
	glitter.initial_velocity_max = 5.0
	glitter.scale_amount_min = 0.35
	glitter.scale_amount_max = 0.8
	glitter.color = Color(1.0, 0.94, 0.55, 0.9)
	glitter.z_index = 3
	add_child(glitter)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pick_up()
	elif event is InputEventScreenTouch and event.pressed:
		_pick_up()


func _pick_up() -> void:
	collected.emit()
	queue_free()
