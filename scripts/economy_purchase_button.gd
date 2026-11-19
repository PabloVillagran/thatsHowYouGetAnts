extends Button

@export_enum("worker", "queen", "warrior", "queen_production", "carry_capacity", "speed", "food_efficiency", "worker_lifetime") var purchase_kind: String = "worker"

var ant_source


func _ready() -> void:
	ant_source = get_tree().current_scene.get_node("AntSource")
	pressed.connect(_on_pressed)
	GameState.food_changed.connect(_refresh_state)
	GameState.economy_changed.connect(_refresh_state)
	_refresh_state()


func _on_pressed() -> void:
	var purchased := false
	match purchase_kind:
		"worker": purchased = ant_source.purchase_worker()
		"queen": purchased = ant_source.purchase_queen()
		"warrior": purchased = ant_source.purchase_warrior()
		_: purchased = ant_source.purchase_upgrade(purchase_kind)
	if purchased:
		ant_source.save_colony()
	_refresh_state()


func _refresh_state(_unused: int = 0) -> void:
	var cost := _current_cost()
	var level := _current_level()
	var label := ""
	match purchase_kind:
		"worker":
			label = "Workers %s  |  Buy Worker" % _format_quantity(ant_source.worker_ants.size())
		"queen":
			label = "Queens %s  |  Buy Queen" % _format_quantity(ant_source.queen_ants.size())
		"warrior":
			label = "Guards %s  |  Buy Guard" % _format_quantity(ant_source.warrior_ants.size())
		"queen_production":
			label = "Queen Spawn Rate +1 level" if ant_source.queen_ant_mode else "Queen Food +1/5s/queen"
		"worker_lifetime": label = "Worker Lifetime +10s"
		"carry_capacity": label = "Carry +1 food/trip"
		"speed": label = "Ant Speed +10%"
		"food_efficiency": label = "New Source Stockpile +10%"
	var level_text := "" if purchase_kind in ["worker", "queen", "warrior"] else "  Lv.%s" % _format_quantity(level)
	text = "%s%s  |  Cost: %s food" % [label, level_text, _format_quantity(cost)]
	disabled = GameState.food_amount < cost


func _current_cost() -> int:
	match purchase_kind:
		"worker": return GameState.worker_cost
		"queen": return GameState.queen_cost
		"warrior": return ant_source.WARRIOR_COST
		"queen_production": return GameState.queen_production_cost
		"carry_capacity": return GameState.carry_capacity_cost
		"speed": return GameState.speed_cost
		"food_efficiency": return GameState.food_efficiency_cost
		"worker_lifetime": return GameState.worker_lifetime_cost
	return 0


func _current_level() -> int:
	match purchase_kind:
		"queen_production": return GameState.queen_production_level
		"carry_capacity": return GameState.carry_capacity_level
		"speed": return GameState.speed_level
		"food_efficiency": return GameState.food_efficiency_level
		"worker_lifetime": return GameState.worker_lifetime_level
	return 0


func _format_quantity(amount: int) -> String:
	if amount >= 999950000:
		return "%.1fB" % (float(amount) / 1000000000.0)
	if amount >= 999950:
		return "%.1fM" % (float(amount) / 1000000.0)
	if amount >= 1000:
		return "%.1fK" % (float(amount) / 1000.0)
	return str(amount)
