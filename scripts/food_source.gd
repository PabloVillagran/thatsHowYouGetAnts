extends Polygon2D

signal depleted(source: Node2D)

const SIDE_COUNTS: Array[int] = [5, 6, 7, 9]
const MIN_FOOD: int = 50
const MAX_FOOD: int = 300
const MIN_RADIUS: float = 8.0
const MAX_RADIUS: float = 24.0

var starting_food: int = 0
var food_remaining: int = 0
var _depletion_step: int = 0
var _is_depleted: bool = false


func initialize(random: RandomNumberGenerator, food_multiplier: float = 1.0) -> void:
	var sides := SIDE_COUNTS[random.randi_range(0, SIDE_COUNTS.size() - 1)]
	starting_food = int(ceil(random.randi_range(MIN_FOOD, MAX_FOOD) * food_multiplier))
	food_remaining = starting_food
	var points := PackedVector2Array()
	var base_angle := random.randf_range(0.0, TAU)
	for index in range(sides):
		var angle := base_angle + TAU * float(index) / float(sides) + random.randf_range(-0.13, 0.13)
		var vertex_radius := random.randf_range(0.72, 1.0)
		points.append(Vector2.RIGHT.rotated(angle) * vertex_radius)
	polygon = points
	var size_ratio := clampf(float(starting_food - MIN_FOOD) / float(MAX_FOOD - MIN_FOOD), 0.0, 1.0)
	var radius := lerpf(MIN_RADIUS, MAX_RADIUS, size_ratio)
	scale = Vector2.ONE * radius
	color = Color(0.88, 0.58, 0.16, 1.0)
	add_to_group("food_sources")


func harvest(requested_amount: int) -> int:
	if requested_amount <= 0 or _is_depleted:
		return 0
	var collected := mini(requested_amount, food_remaining)
	food_remaining -= collected
	var new_step := 4 if food_remaining == 0 else mini(3, int((starting_food - food_remaining) * 4.0 / starting_food))
	if new_step > _depletion_step:
		_depletion_step = new_step
		scale = Vector2.ONE * _base_radius() * (1.0 - 0.25 * float(_depletion_step))
	if food_remaining == 0:
		_is_depleted = true
		call_deferred("_finish_depletion")
	return collected


func _finish_depletion() -> void:
	depleted.emit(self)
	queue_free()


func _base_radius() -> float:
	var size_ratio := clampf(float(starting_food - MIN_FOOD) / float(MAX_FOOD - MIN_FOOD), 0.0, 1.0)
	return lerpf(MIN_RADIUS, MAX_RADIUS, size_ratio)
