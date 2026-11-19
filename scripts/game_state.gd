extends Node

signal food_changed(amount: int)
signal economy_changed

const QUEEN_FOOD_INTERVAL: float = 5.0
const STARTING_FOOD: int = 250
const WORKER_START_COST: int = 5
const QUEEN_START_COST: int = 1000
const UPGRADE_START_COST: int = 25
const MAX_PURCHASE_COST: int = 2000000000
const SAVE_PATH: String = "user://game_state.json"
const AUTOSAVE_INTERVAL: float = 10.0

var food_amount: int = STARTING_FOOD:
	set(value):
		food_amount = maxi(value, 0)
		food_changed.emit(food_amount)

var queen_food_elapsed: float = 0.0
var queen_ant_mode_active: bool = false
var queen_count: int = 1
var worker_count: int = 0
var warrior_count: int = 0
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
var has_saved_game: bool = false
var saved_queen_amount: int = 1
var saved_worker_amount: int = 0
var saved_warrior_amount: int = 0
var saved_warrior_health: Array = []
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


func save_game(queen_amount: int, worker_amount: int, warrior_amount: int, warrior_health: Array = []) -> void:
	queen_count = queen_amount
	worker_count = worker_amount
	warrior_count = warrior_amount
	var state := {
		"update_time": int(Time.get_unix_time_from_system()),
		"food_amount": food_amount,
		"queen_amount": queen_amount,
		"worker_amount": worker_amount,
		"warrior_amount": warrior_amount,
		"warrior_health": warrior_health,
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
	update_time = int(state.get("update_time", 0))
	# A playable colony always needs at least its starting queen.
	saved_queen_amount = maxi(1, int(state.get("queen_amount", 1)))
	saved_worker_amount = maxi(0, int(state.get("worker_amount", 0)))
	saved_warrior_amount = maxi(0, int(state.get("warrior_amount", 0)))
	var health: Variant = state.get("warrior_health", [])
	saved_warrior_health = health if health is Array else []
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
	has_saved_game = true
	economy_changed.emit()


func reset_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if remove_error != OK:
			push_error("Could not remove saved game: %s" % error_string(remove_error))
			return

	food_amount = STARTING_FOOD
	queen_food_elapsed = 0.0
	queen_count = 1
	worker_count = 0
	warrior_count = 0
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
	has_saved_game = false
	saved_queen_amount = 1
	saved_worker_amount = 0
	saved_warrior_amount = 0
	saved_warrior_health = []
	update_time = 0
	autosave_elapsed = 0.0
	get_tree().reload_current_scene()
