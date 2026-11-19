extends Label


func _ready() -> void:
	GameState.food_changed.connect(_on_food_changed)
	_on_food_changed(GameState.food_amount)


func _on_food_changed(amount: int) -> void:
	text = "Food: %s" % _format_quantity(amount)


func _format_quantity(amount: int) -> String:
	if amount >= 999950000:
		return "%.1fB" % (float(amount) / 1000000000.0)
	if amount >= 999950:
		return "%.1fM" % (float(amount) / 1000000.0)
	if amount >= 1000:
		return "%.1fK" % (float(amount) / 1000.0)
	return str(amount)
