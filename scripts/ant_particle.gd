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

const TYPE_COLORS: Dictionary = {
	AntType.QUEEN: Color.WHITE,
	AntType.WORKER: Color(0.18, 0.45, 0.95, 1.0),
	AntType.WARRIOR: Color(0.45, 0.04, 0.08, 1.0),
}

@export var ant_type: AntType = AntType.WORKER
@export var move_speed: float = 28.0

var state: State = State.idle
var heading: Vector2 = Vector2.RIGHT
var target_position: Vector2
var idle_anchor: Vector2
var has_reached_destination: bool = false
var carried_food: int = 0
var is_returning_food: bool = false
var food_gather_remaining: float = 0.0


func _ready() -> void:
	apply_type_appearance()
	target_position = position
	idle_anchor = position


func apply_type_appearance() -> void:
	color = TYPE_COLORS.get(ant_type, Color.WHITE)


func set_state(next_state: State) -> void:
	state = next_state


func set_target(next_target: Vector2) -> void:
	target_position = next_target


func move_step(delta: float) -> void:
	var offset := target_position - position
	if offset.length_squared() <= 0.0001:
		return

	heading = offset.normalized()
	position = position.move_toward(target_position, move_speed * delta)
	rotation = heading.angle() - PI * 0.5


func is_at_target(tolerance: float = 1.0) -> bool:
	return position.distance_to(target_position) <= tolerance
