extends Polygon2D

signal depleted(drop: Node2D)

var food_remaining: int = 0


func initialize(amount: int) -> void:
	food_remaining = maxi(amount, 0)
	polygon = PackedVector2Array([
		Vector2(-0.5, -0.5),
		Vector2(0.5, -0.5),
		Vector2(0.5, 0.5),
		Vector2(-0.5, 0.5),
	])
	color = Color(1.0, 0.78, 0.18, 1.0)
	add_to_group("food_sources")


func harvest(requested_amount: int) -> int:
	if requested_amount <= 0 or food_remaining <= 0:
		return 0
	var collected := mini(requested_amount, food_remaining)
	food_remaining -= collected
	if food_remaining == 0:
		call_deferred("_finish_depletion")
	return collected


func _finish_depletion() -> void:
	depleted.emit(self)
	queue_free()
