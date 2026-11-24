extends Button

const WORKER_COST: int = 100

var ant_source


func _ready() -> void:
	ant_source = get_tree().current_scene.get_node("AntSource")
	pressed.connect(_on_pressed)
	GameState.food_changed.connect(_refresh_state)
	_refresh_state()


func _on_pressed() -> void:
	ant_source.purchase_worker()
	ant_source.save_colony()
	_refresh_state()


func _refresh_state(_unused: int = 0) -> void:
	disabled = GameState.food_amount < WORKER_COST
