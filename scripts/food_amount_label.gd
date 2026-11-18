extends Label


func _ready() -> void:
	GameState.food_changed.connect(_on_food_changed)
	_on_food_changed(GameState.food_amount)


func _on_food_changed(amount: int) -> void:
	text = "Food: %d" % amount
