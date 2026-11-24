extends Node

signal food_changed(amount: int)
signal economy_changed

const QUEEN_FOOD_INTERVAL: float = 5.0
const STARTING_FOOD: int = 250
const WORKER_START_COST: int = 5
const QUEEN_START_COST: int = 300
const UPGRADE_START_COST: int = 25
const MAX_PURCHASE_COST: int = 2000000000
const WARRIOR_DAMAGE_START_COST: int = 250
const WARRIOR_ENDURANCE_START_COST: int = 400
const WARRIOR_TRAINING_START_COST: int = 600
const SAVE_PATH: String = "user://game_state.json"
const AUTOSAVE_INTERVAL: float = 10.0
const MAX_OFFLINE_SECONDS: float = 86400.0

var food_amount: int = STARTING_FOOD:
	set(value):
		food_amount = maxi(value, 0)
		food_changed.emit(food_amount)

var queen_food_elapsed: float = 0.0
var queen_ant_mode_active: bool = false
var queen_count: int = 1
var worker_count: int = 0
var warrior_count: int = 0
var warrior_damage_level: int = 0
var warrior_endurance_level: int = 0
var warrior_training_level: int = 0
var warrior_damage_cost: int = WARRIOR_DAMAGE_START_COST
var warrior_endurance_cost: int = WARRIOR_ENDURANCE_START_COST
var warrior_training_cost: int = WARRIOR_TRAINING_START_COST
var worker_cost: int = WORKER_START_COST
var queen_cost: int = QUEEN_START_COST
var queen_production_level: int = 0
var carry_capacity_level: int = 0
var speed_level: int = 0
var food_efficiency_level: int = 0
var queen_production_cost: int = UPGRADE_START_COST
var carry_capacity_cost: int = UPGRADE_START_COST
var speed_cost: int = UPGRADE_START_COST
var food_efficiency_cost: int = UPGRADE_START_COST
var worker_lifetime_level: int = 0
var worker_lifetime_cost: int = UPGRADE_START_COST
const INC1_ANT_START_COST: int = 10
const INC1_CARRY_START_COST: int = 100
const INC1_SPEED_START_COST: int = 250
const INC1_SOURCE_SIZE_START_COST: int = 250
const INC1_QUEEN_START_COST: int = 500
const INC1_SOURCE_AMOUNT_START_COST: int = 350
const INC1_GATHERING_TIME_START_COST: int = 250
var inc1_ant_cost: int = INC1_ANT_START_COST
var inc1_queen_cost: int = INC1_QUEEN_START_COST
var inc1_carry_cost: int = INC1_CARRY_START_COST
var inc1_speed_cost: int = INC1_SPEED_START_COST
var inc1_source_size_cost: int = INC1_SOURCE_SIZE_START_COST
var inc1_source_amount_cost: int = INC1_SOURCE_AMOUNT_START_COST
var inc1_gathering_time_cost: int = INC1_GATHERING_TIME_START_COST
var inc1_carry_level: int = 0
var inc1_carry_gain: float = 1.0
var inc1_carry_total: int = 0
var inc1_speed_level: int = 0
var inc1_source_size_level: int = 0
var inc1_queen_level: int = 0
var inc1_source_amount_level: int = 0
var inc1_gathering_time_level: int = 0
var has_saved_game: bool = false
var saved_queen_amount: int = 1
var saved_worker_amount: int = 0
var saved_warrior_amount: int = 0
var saved_warrior_health: Array = []
var saved_step_counts: Dictionary = {}
var saved_step_grid_colliders: Dictionary = {}
var saved_worker_paint_trail: Dictionary = {}
var saved_worker_paint_trail_format: int = 0
var update_time: int = 0
var autosave_elapsed: float = 0.0


func _ready() -> void:
	_load_game()


func _process(delta: float) -> void:
	if not queen_ant_mode_active:
		queen_food_elapsed += delta
		while queen_food_elapsed >= QUEEN_FOOD_INTERVAL:
			queen_food_elapsed -= QUEEN_FOOD_INTERVAL
			add_food(queen_count * (1 + queen_production_level))
	autosave_elapsed += delta
	if autosave_elapsed >= AUTOSAVE_INTERVAL:
		autosave_elapsed = 0.0
		_save_active_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_active_game()


func _save_active_game() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var ant_source := scene.get_node_or_null("AntSource")
	if ant_source == null:
		return
	ant_source.call("save_colony")


func add_food(amount: int) -> void:
	if amount > 0:
		food_amount += amount


func spend_food(amount: int) -> bool:
	if amount < 0 or food_amount < amount:
		return false
	food_amount -= amount
	return true


func next_cost(cost: int, multiplier: float) -> int:
	return mini(MAX_PURCHASE_COST, int(ceil(float(cost) * multiplier)))


func _cost_after_purchases(start_cost: int, multiplier: float, purchases: int) -> int:
	var cost := start_cost
	for _index in range(maxi(0, purchases)):
		if cost >= MAX_PURCHASE_COST:
			break
		cost = next_cost(cost, multiplier)
	return cost


func save_game(queen_amount: int, worker_amount: int, warrior_amount: int, warrior_health: Array = [], step_counts: Dictionary = {}, step_grid_colliders: Dictionary = {}, worker_paint_trail: Dictionary = {}, worker_paint_trail_format: int = 1) -> void:
	queen_count = queen_amount
	worker_count = worker_amount
	warrior_count = warrior_amount
	var state := {
		"update_time": int(Time.get_unix_time_from_system()),
		"queen_ant_mode": queen_ant_mode_active,
		"food_amount": food_amount,
		"queen_amount": queen_amount,
		"worker_amount": worker_amount,
		"warrior_amount": warrior_amount,
		"warrior_health": warrior_health,
		"step_counts": step_counts,
		"step_grid_colliders": step_grid_colliders,
		"worker_paint_trail": worker_paint_trail,
		"worker_paint_trail_format": worker_paint_trail_format,
		"warrior_damage_level": warrior_damage_level,
		"warrior_endurance_level": warrior_endurance_level,
		"warrior_training_level": warrior_training_level,
		"worker_cost": worker_cost,
		"queen_cost": queen_cost,
		"queen_production_level": queen_production_level,
		"carry_capacity_level": carry_capacity_level,
		"speed_level": speed_level,
		"food_efficiency_level": food_efficiency_level,
		"queen_production_cost": queen_production_cost,
		"carry_capacity_cost": carry_capacity_cost,
		"speed_cost": speed_cost,
		"food_efficiency_cost": food_efficiency_cost,
		"worker_lifetime_level": worker_lifetime_level,
		"worker_lifetime_cost": worker_lifetime_cost,
		"inc1_ant_cost": inc1_ant_cost,
		"inc1_queen_cost": inc1_queen_cost,
		"inc1_carry_cost": inc1_carry_cost,
		"inc1_speed_cost": inc1_speed_cost,
		"inc1_source_size_cost": inc1_source_size_cost,
		"inc1_source_amount_cost": inc1_source_amount_cost,
		"inc1_gathering_time_cost": inc1_gathering_time_cost,
		"inc1_carry_level": inc1_carry_level,
		"inc1_carry_gain": inc1_carry_gain,
		"inc1_carry_total": inc1_carry_total,
		"inc1_speed_level": inc1_speed_level,
		"inc1_source_size_level": inc1_source_size_level,
		"inc1_queen_level": inc1_queen_level,
		"inc1_source_amount_level": inc1_source_amount_level,
		"inc1_gathering_time_level": inc1_gathering_time_level,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not save game state: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(state))
	update_time = state["update_time"]
	saved_queen_amount = queen_amount
	saved_worker_amount = worker_amount
	saved_warrior_amount = warrior_amount
	saved_warrior_health = warrior_health
	saved_step_counts = step_counts.duplicate(true)
	saved_step_grid_colliders = step_grid_colliders.duplicate(true)
	saved_worker_paint_trail = worker_paint_trail.duplicate(true)
	saved_worker_paint_trail_format = worker_paint_trail_format
	has_saved_game = true


func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not load game state: %s" % error_string(FileAccess.get_open_error()))
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Saved game state is invalid; starting a new game.")
		return
	var state: Dictionary = parsed
	food_amount = maxi(0, int(state.get("food_amount", 0)))
	var now := int(Time.get_unix_time_from_system())
	update_time = int(state.get("update_time", now))
	var saved_queen_ant_mode := bool(state.get("queen_ant_mode", false))
	queen_ant_mode_active = saved_queen_ant_mode
	# A playable colony always needs at least its starting queen.
	saved_queen_amount = maxi(1, int(state.get("queen_amount", 1)))
	saved_worker_amount = maxi(0, int(state.get("worker_amount", 0)))
	saved_warrior_amount = maxi(0, int(state.get("warrior_amount", 0)))
	warrior_damage_level = clampi(int(state.get("warrior_damage_level", 0)), 0, 4)
	warrior_endurance_level = clampi(int(state.get("warrior_endurance_level", 0)), 0, 5)
	warrior_training_level = clampi(int(state.get("warrior_training_level", 0)), 0, 5)
	var health: Variant = state.get("warrior_health", [])
	saved_warrior_health = health if health is Array else []
	var saved_steps: Variant = state.get("step_counts", {})
	saved_step_counts = saved_steps if saved_steps is Dictionary else {}
	var saved_colliders: Variant = state.get("step_grid_colliders", {})
	saved_step_grid_colliders = saved_colliders if saved_colliders is Dictionary else {}
	var saved_trail: Variant = state.get("worker_paint_trail", {})
	saved_worker_paint_trail = saved_trail if saved_trail is Dictionary else {}
	saved_worker_paint_trail_format = maxi(0, int(state.get("worker_paint_trail_format", 0)))
	queen_count = saved_queen_amount
	worker_count = saved_worker_amount
	warrior_count = saved_warrior_amount
	worker_cost = maxi(1, int(state.get("worker_cost", WORKER_START_COST)))
	queen_cost = maxi(1, int(state.get("queen_cost", QUEEN_START_COST)))
	queen_production_level = maxi(0, int(state.get("queen_production_level", 0)))
	carry_capacity_level = maxi(0, int(state.get("carry_capacity_level", 0)))
	speed_level = maxi(0, int(state.get("speed_level", 0)))
	food_efficiency_level = maxi(0, int(state.get("food_efficiency_level", 0)))
	queen_production_cost = maxi(1, int(state.get("queen_production_cost", UPGRADE_START_COST)))
	carry_capacity_cost = maxi(1, int(state.get("carry_capacity_cost", UPGRADE_START_COST)))
	speed_cost = maxi(1, int(state.get("speed_cost", UPGRADE_START_COST)))
	food_efficiency_cost = maxi(1, int(state.get("food_efficiency_cost", UPGRADE_START_COST)))
	worker_lifetime_level = maxi(0, int(state.get("worker_lifetime_level", 0)))
	worker_lifetime_cost = maxi(1, int(state.get("worker_lifetime_cost", UPGRADE_START_COST)))
	inc1_ant_cost = maxi(1, int(state.get("inc1_ant_cost", INC1_ANT_START_COST)))
	inc1_queen_cost = maxi(1, int(state.get("inc1_queen_cost", INC1_QUEEN_START_COST)))
	inc1_carry_cost = maxi(1, int(state.get("inc1_carry_cost", INC1_CARRY_START_COST)))
	inc1_speed_cost = maxi(1, int(state.get("inc1_speed_cost", INC1_SPEED_START_COST)))
	inc1_source_size_cost = maxi(1, int(state.get("inc1_source_size_cost", INC1_SOURCE_SIZE_START_COST)))
	inc1_source_amount_cost = maxi(1, int(state.get("inc1_source_amount_cost", INC1_SOURCE_AMOUNT_START_COST)))
	inc1_gathering_time_cost = maxi(1, int(state.get("inc1_gathering_time_cost", INC1_GATHERING_TIME_START_COST)))
	inc1_carry_level = maxi(0, int(state.get("inc1_carry_level", 0)))
	inc1_carry_gain = maxf(1.0, float(state.get("inc1_carry_gain", pow(1.005, inc1_carry_level))))
	inc1_carry_total = maxi(0, int(state.get("inc1_carry_total", inc1_carry_level)))
	inc1_speed_level = clampi(int(state.get("inc1_speed_level", 0)), 0, 8)
	inc1_source_size_level = maxi(0, int(state.get("inc1_source_size_level", 0)))
	inc1_queen_level = clampi(int(state.get("inc1_queen_level", 0)), 0, 9)
	inc1_source_amount_level = clampi(int(state.get("inc1_source_amount_level", 0)), 0, 19)
	inc1_gathering_time_level = clampi(int(state.get("inc1_gathering_time_level", 0)), 0, 6)
	# Recalculate next prices from saved progress so balance changes also reach
	# existing colonies without resetting food, ants, or upgrade levels.
	queen_cost = _cost_after_purchases(QUEEN_START_COST, 1.45, saved_queen_amount - 1)
	warrior_damage_cost = _cost_after_purchases(WARRIOR_DAMAGE_START_COST, 1.5, warrior_damage_level)
	warrior_endurance_cost = _cost_after_purchases(WARRIOR_ENDURANCE_START_COST, 1.6, warrior_endurance_level)
	warrior_training_cost = _cost_after_purchases(WARRIOR_TRAINING_START_COST, 1.7, warrior_training_level)
	queen_production_cost = _cost_after_purchases(UPGRADE_START_COST, 1.3, queen_production_level)
	food_efficiency_cost = _cost_after_purchases(UPGRADE_START_COST, 1.3, food_efficiency_level)
	carry_capacity_cost = _cost_after_purchases(UPGRADE_START_COST, 1.15, carry_capacity_level)
	speed_cost = _cost_after_purchases(UPGRADE_START_COST, 1.15, speed_level)
	worker_lifetime_cost = _cost_after_purchases(UPGRADE_START_COST, 1.15, worker_lifetime_level)
	inc1_queen_cost = _cost_after_purchases(INC1_QUEEN_START_COST, 1.5, inc1_queen_level)
	inc1_carry_cost = _cost_after_purchases(INC1_CARRY_START_COST, 1.35, inc1_carry_level)
	inc1_speed_cost = _cost_after_purchases(INC1_SPEED_START_COST, 1.35, inc1_speed_level)
	inc1_source_size_cost = _cost_after_purchases(INC1_SOURCE_SIZE_START_COST, 1.6, inc1_source_size_level)
	inc1_source_amount_cost = _cost_after_purchases(INC1_SOURCE_AMOUNT_START_COST, 1.5, inc1_source_amount_level)
	inc1_gathering_time_cost = _cost_after_purchases(INC1_GATHERING_TIME_START_COST, 1.4, inc1_gathering_time_level)
	has_saved_game = true
	var offline_seconds := clampf(float(now - update_time), 0.0, MAX_OFFLINE_SECONDS)
	if not saved_queen_ant_mode and offline_seconds >= QUEEN_FOOD_INTERVAL:
		var production_ticks := floori(offline_seconds / QUEEN_FOOD_INTERVAL)
		var offline_food := production_ticks * saved_queen_amount * (1 + queen_production_level)
		if offline_food > 0:
			add_food(offline_food)
			# Persist the credited amount and a fresh timestamp immediately so
			# reopening the app cannot credit the same offline interval again.
			save_game(saved_queen_amount, saved_worker_amount, saved_warrior_amount, saved_warrior_health, saved_step_counts, saved_step_grid_colliders, saved_worker_paint_trail, saved_worker_paint_trail_format)
	economy_changed.emit()


func reset_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if remove_error != OK:
			push_error("Could not remove saved game: %s" % error_string(remove_error))
			return

	food_amount = STARTING_FOOD
	queen_food_elapsed = 0.0
	# Reset can be triggered from either game variant. Clear the mode before
	# the scene reload so the autoload cannot keep applying the old variant's
	# background production rules during the transition.
	queen_ant_mode_active = false
	queen_count = 1
	worker_count = 0
	warrior_count = 0
	warrior_damage_level = 0
	warrior_endurance_level = 0
	warrior_training_level = 0
	warrior_damage_cost = WARRIOR_DAMAGE_START_COST
	warrior_endurance_cost = WARRIOR_ENDURANCE_START_COST
	warrior_training_cost = WARRIOR_TRAINING_START_COST
	worker_cost = WORKER_START_COST
	queen_cost = QUEEN_START_COST
	queen_production_level = 0
	carry_capacity_level = 0
	speed_level = 0
	food_efficiency_level = 0
	queen_production_cost = UPGRADE_START_COST
	carry_capacity_cost = UPGRADE_START_COST
	speed_cost = UPGRADE_START_COST
	food_efficiency_cost = UPGRADE_START_COST
	worker_lifetime_level = 0
	worker_lifetime_cost = UPGRADE_START_COST
	inc1_ant_cost = INC1_ANT_START_COST
	inc1_queen_cost = INC1_QUEEN_START_COST
	inc1_carry_cost = INC1_CARRY_START_COST
	inc1_speed_cost = INC1_SPEED_START_COST
	inc1_source_size_cost = INC1_SOURCE_SIZE_START_COST
	inc1_source_amount_cost = INC1_SOURCE_AMOUNT_START_COST
	inc1_gathering_time_cost = INC1_GATHERING_TIME_START_COST
	inc1_carry_level = 0
	inc1_carry_gain = 1.0
	inc1_carry_total = 0
	inc1_speed_level = 0
	inc1_source_size_level = 0
	inc1_queen_level = 0
	inc1_source_amount_level = 0
	inc1_gathering_time_level = 0
	has_saved_game = false
	saved_queen_amount = 1
	saved_worker_amount = 0
	saved_warrior_amount = 0
	saved_warrior_health = []
	saved_step_counts = {}
	saved_step_grid_colliders = {}
	saved_worker_paint_trail = {}
	saved_worker_paint_trail_format = 0
	update_time = 0
	autosave_elapsed = 0.0
	get_tree().reload_current_scene()
