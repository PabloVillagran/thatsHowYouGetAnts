extends Button

@export_enum("worker", "queen", "warrior", "warrior_damage", "warrior_endurance", "warrior_training", "queen_production", "carry_capacity", "speed", "food_efficiency", "worker_lifetime", "worker_dig_speed", "food_source_size", "food_source_amount", "gathering_time") var purchase_kind: String = "worker"

var ant_source


func _ready() -> void:
	# Let the parent ScrollContainer receive touch drags that begin on a button.
	mouse_filter = Control.MOUSE_FILTER_PASS
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
	var incremental: bool = not ant_source.queen_ant_mode
	visible = _is_unlocked(incremental)
	if not visible:
		return
	var cost := _current_cost(incremental)
	text = _purchase_label(incremental, cost)
	disabled = GameState.food_amount < cost or _at_cap(incremental)


func _is_unlocked(incremental: bool) -> bool:
	if purchase_kind in ["warrior", "warrior_damage", "warrior_endurance", "warrior_training"]:
		return ant_source.queen_ants.size() >= 4
	if not incremental:
		if purchase_kind == "worker_dig_speed":
			return GameState.speed_level > 0
		return purchase_kind not in ["food_source_size", "food_source_amount", "gathering_time"]
	match purchase_kind:
		"worker": return true
		"carry_capacity": return ant_source.worker_ants.size() >= 10 or GameState.inc1_carry_level > 0
		"speed": return (ant_source.worker_ants.size() >= 20 and GameState.inc1_carry_level > 0) or GameState.inc1_speed_level > 0
		"worker_dig_speed": return GameState.inc1_speed_level > 0
		"food_source_size": return GameState.inc1_carry_level >= 5
		"queen": return ant_source.worker_ants.size() >= 25 or GameState.inc1_queen_level > 0
		"food_source_amount": return ant_source.queen_ants.size() >= 2 or GameState.inc1_source_amount_level > 0
		"gathering_time": return GameState.inc1_speed_level > 0 or GameState.inc1_gathering_time_level > 0
		_: return false


func _at_cap(incremental: bool) -> bool:
	match purchase_kind:
		"warrior_damage": return GameState.warrior_damage_level >= 4
		"warrior_endurance": return GameState.warrior_endurance_level >= 5
		"warrior_training": return GameState.warrior_training_level >= 5
	if not incremental:
		return false
	match purchase_kind:
		"speed": return minf(2.0, pow(1.1, GameState.inc1_speed_level)) >= 2.0
		"queen": return ant_source.queen_ants.size() >= 10
		"food_source_amount": return 1 + GameState.inc1_source_amount_level >= 20
		"gathering_time": return GameState.inc1_gathering_time_level >= 6
	return false


func _current_cost(incremental: bool) -> int:
	match purchase_kind:
		"warrior_damage": return GameState.warrior_damage_cost
		"warrior_endurance": return GameState.warrior_endurance_cost
		"warrior_training": return GameState.warrior_training_cost
	if incremental:
		match purchase_kind:
			"worker": return GameState.inc1_ant_cost
			"queen": return GameState.inc1_queen_cost
			"carry_capacity": return GameState.inc1_carry_cost
			"speed": return GameState.inc1_speed_cost
			"food_source_size": return GameState.inc1_source_size_cost
			"food_source_amount": return GameState.inc1_source_amount_cost
			"gathering_time": return GameState.inc1_gathering_time_cost
		return 0
	match purchase_kind:
		"worker": return GameState.worker_cost
		"queen": return GameState.queen_cost
		"warrior": return ant_source.WARRIOR_COST
		"queen_production": return GameState.queen_production_cost
		"carry_capacity": return GameState.carry_capacity_cost
		"speed": return GameState.speed_cost
		"food_efficiency": return GameState.food_efficiency_cost
		"worker_lifetime": return GameState.worker_lifetime_cost
		"worker_dig_speed": return GameState.worker_dig_speed_cost
	return 0


func _purchase_label(incremental: bool, cost: int) -> String:
	var label := ""
	if incremental:
		match purchase_kind:
			"warrior": label = "Defenders %s  |  Buy Defender" % _format_quantity(ant_source.warrior_ants.size())
			"warrior_damage": label = "Warrior Damage +1/attack"
			"warrior_endurance": label = "Warrior Max Health +2"
			"warrior_training": label = "Warrior Move Speed +10%"
			"worker": label = "Workers %s  |  Buy Ant" % _format_quantity(ant_source.worker_ants.size())
			"queen": label = "Queens %s / 10  |  +1 leader" % _format_quantity(ant_source.queen_ants.size())
			"carry_capacity": label = "Next Carry +1 food/trip"
			"speed":
				var current_speed_multiplier := minf(2.0, pow(1.1, GameState.inc1_speed_level))
				var next_speed_multiplier := minf(2.0, pow(1.1, GameState.inc1_speed_level + 1))
				var next_speed_increase := (next_speed_multiplier / current_speed_multiplier - 1.0) * 100.0
				label = "Next Speed +%.1f%%  |  Total %.0f%%" % [next_speed_increase, (current_speed_multiplier - 1.0) * 100.0]
			"food_source_size": label = "Source Size +25 food/source"
			"food_source_amount": label = "Food Sources %s / 20  |  +1" % _format_quantity(1 + GameState.inc1_source_amount_level)
			"gathering_time": label = "Gathering Time -10%"
	else:
		match purchase_kind:
			"queen": label = "Queens %s  |  Buy Queen" % _format_quantity(ant_source.queen_ants.size())
			"warrior": label = "Defenders %s  |  Buy Defender" % _format_quantity(ant_source.warrior_ants.size())
			"warrior_damage": label = "Warrior Damage +1/attack"
			"warrior_endurance": label = "Warrior Max Health +2"
			"warrior_training": label = "Warrior Move Speed +10%"
			"queen_production": label = "Queen Spawn Rate +1 level" if ant_source.queen_ant_mode else "Queen Food +1/5s/queen"
			"worker_lifetime": label = "Worker Lifetime +10s"
			"worker_dig_speed": label = "Worker Dig Speed +1 step/pass"
			"carry_capacity": label = "Carry +1 food/trip"
			"speed": label = "Ant Speed +10%"
			"food_efficiency": label = "New Source Stockpile +25%"
	var level := _current_level(incremental)
	var level_text := "" if purchase_kind in ["worker", "queen", "warrior"] else "  Lv.%s" % _format_quantity(level)
	return "%s%s  |  Cost: %s food" % [label, level_text, _format_quantity(cost)]


func _current_level(incremental: bool) -> int:
	match purchase_kind:
		"warrior_damage": return GameState.warrior_damage_level
		"warrior_endurance": return GameState.warrior_endurance_level
		"warrior_training": return GameState.warrior_training_level
		"worker_dig_speed": return GameState.worker_dig_speed_level
	if incremental:
		match purchase_kind:
			"carry_capacity": return GameState.inc1_carry_level
			"speed": return GameState.inc1_speed_level
			"food_source_size": return GameState.inc1_source_size_level
			"queen": return GameState.inc1_queen_level
			"food_source_amount": return GameState.inc1_source_amount_level
			"gathering_time": return GameState.inc1_gathering_time_level
		return 0
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
