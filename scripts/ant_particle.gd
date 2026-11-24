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

const QUEEN_TEXTURE: Texture2D = preload("res://assets/Ants/Queen.png")
const WORKER_TEXTURE: Texture2D = preload("res://assets/Ants/Worker.png")
const WARRIOR_TEXTURE: Texture2D = preload("res://assets/Ants/Warrior.png")

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
	polygon = PackedVector2Array()
	var ant_sprite := get_node_or_null("AntSprite") as Sprite2D
	if ant_sprite == null:
		ant_sprite = Sprite2D.new()
		ant_sprite.name = "AntSprite"
		add_child(ant_sprite)
	var ant_texture: Texture2D = WORKER_TEXTURE
	var display_size := Vector2(4.0, 8.0)
	match ant_type:
		AntType.QUEEN:
			ant_texture = QUEEN_TEXTURE
			display_size = Vector2(6.0, 9.0)
		AntType.WORKER:
			ant_texture = WORKER_TEXTURE
			display_size = Vector2(2.0, 3.0)
		AntType.WARRIOR:
			ant_texture = WARRIOR_TEXTURE
			display_size = Vector2(4.0, 8.0)
	ant_sprite.texture = ant_texture
	ant_sprite.centered = true
	ant_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ant_sprite.scale = Vector2(display_size.x / ant_texture.get_width(), display_size.y / ant_texture.get_height())


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
	rotation = heading.angle() + PI * 0.5


func is_at_target(tolerance: float = 1.0) -> bool:
	return position.distance_to(target_position) <= tolerance


func mark_dead() -> void:
	if is_dead:
		return
	is_dead = true
	queue_free()
