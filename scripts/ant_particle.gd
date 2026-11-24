class_name AntParticle
extends Polygon2D

enum AntType {
	QUEEN,
	WORKER,
	WARRIOR,
}

enum State {
	idle,
	walking,
	gathering,
}

const ANT_COLOR := Color.BLACK
const OUTLINE_COLOR := Color.WHITE
const OUTLINE_WIDTH := 0.5

@export var ant_type: AntType = AntType.WORKER
@export var move_speed: float = 28.0
@export var can_dig: bool = false

var state: State = State.idle
var heading: Vector2 = Vector2.RIGHT
var target_position: Vector2
var idle_anchor: Vector2
var has_reached_destination: bool = false
var scatter_started_this_trip: bool = false
var gathered_this_trip: bool = false
var carried_food: int = 0
var is_returning_food: bool = false
var food_gather_remaining: float = 0.0
var lifetime_remaining: float = -1.0
var is_dead: bool = false
var combat_health: int = 0
var attack_cooldown: float = 0.0
var food_source: Node2D
var route_waypoints: Array[Vector2] = []
var route_waypoint_index: int = 0
var route_target: Vector2
var route_initialized: bool = false
var route_leader_state: bool = false
var route_leader_state_initialized: bool = false


func _ready() -> void:
	add_to_group("ants")
	apply_type_appearance()
	target_position = position
	idle_anchor = position


func apply_type_appearance() -> void:
	color = ANT_COLOR
	if ant_type == AntType.WORKER:
		polygon = PackedVector2Array([
			Vector2(-1, -1.5),
			Vector2(1, -1.5),
			Vector2(1, 1.5),
			Vector2(-1, 1.5),
		])
	polygon = _rounded_rectangle(polygon, 0.7 if ant_type == AntType.WORKER else 1.25)
	var outline := get_node_or_null("Outline") as Line2D
	if outline == null:
		outline = Line2D.new()
		outline.name = "Outline"
		add_child(outline)
	outline.clear_points()
	for vertex in polygon:
		outline.add_point(vertex)
	if not polygon.is_empty():
		outline.add_point(polygon[0])
	outline.default_color = OUTLINE_COLOR
	outline.width = OUTLINE_WIDTH
	outline.antialiased = true


func _rounded_rectangle(source: PackedVector2Array, radius: float) -> PackedVector2Array:
	var min_x := source[0].x
	var max_x := source[0].x
	var min_y := source[0].y
	var max_y := source[0].y
	for vertex in source:
		min_x = minf(min_x, vertex.x)
		max_x = maxf(max_x, vertex.x)
		min_y = minf(min_y, vertex.y)
		max_y = maxf(max_y, vertex.y)
	var corner_data := [
		[Vector2(min_x + radius, min_y + radius), PI, PI * 1.5],
		[Vector2(max_x - radius, min_y + radius), PI * 1.5, TAU],
		[Vector2(max_x - radius, max_y - radius), 0.0, PI * 0.5],
		[Vector2(min_x + radius, max_y - radius), PI * 0.5, PI],
	]
	var rounded := PackedVector2Array()
	for corner in corner_data:
		for step in range(4):
			var angle: float = lerpf(corner[1], corner[2], float(step) / 3.0)
			rounded.append(corner[0] + Vector2(cos(angle), sin(angle)) * radius)
	return rounded


func set_state(next_state: State) -> void:
	state = next_state


func set_target(next_target: Vector2) -> void:
	var ant_source := get_parent()
	var is_route_leader := ant_source != null and ant_source.has_method("is_worker_group_leader") and bool(ant_source.call("is_worker_group_leader", self))
	var role_changed := not route_leader_state_initialized or route_leader_state != is_route_leader
	var should_refresh_route := role_changed or not route_initialized or (is_route_leader and route_target.distance_to(next_target) >= 20.0)
	target_position = next_target
	route_leader_state = is_route_leader
	route_leader_state_initialized = true
	if should_refresh_route:
		route_target = next_target
		route_initialized = true
		route_waypoints.clear()
		route_waypoint_index = 0
		if is_route_leader and ant_source.has_method("route_waypoints_for"):
			route_waypoints = ant_source.call("route_waypoints_for", self, position, target_position)


func move_step(delta: float) -> void:
	while route_waypoint_index < route_waypoints.size() and position.distance_squared_to(route_waypoints[route_waypoint_index]) <= 1.0:
		route_waypoint_index += 1
	var movement_target := target_position
	if route_waypoint_index < route_waypoints.size():
		movement_target = route_waypoints[route_waypoint_index]
	var offset := movement_target - position
	if offset.length_squared() <= 0.0001:
		return

	heading = offset.normalized()
	var speed_multiplier := 1.0
	var ant_source := get_parent()
	if ant_source != null and ant_source.has_method("step_speed_multiplier_at"):
		speed_multiplier = float(ant_source.call("step_speed_multiplier_at", position))
	position = position.move_toward(movement_target, move_speed * speed_multiplier * delta)
	rotation = heading.angle() - PI * 0.5


func is_at_target(tolerance: float = 1.0) -> bool:
	return position.distance_to(target_position) <= tolerance


func mark_dead() -> void:
	if is_dead:
		return
	is_dead = true
	queue_free()
