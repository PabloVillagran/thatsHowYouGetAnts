extends Node

signal food_changed(amount: int)

const QUEEN_FOOD_INTERVAL: float = 5.0
const STARTING_FOOD: int = 250
const SAVE_PATH: String = "user://game_state.json"

var food_amount: int = STARTING_FOOD:
	set(value):
		food_amount = maxi(value, 0)
		food_changed.emit(food_amount)

var queen_food_elapsed: float = 0.0
var has_saved_game: bool = false
var saved_queen_amount: int = 1
var saved_worker_amount: int = 0
var saved_warrior_amount: int = 0
var update_time: int = 0


func _ready() -> void:
	_load_game()


func _process(delta: float) -> void:
	queen_food_elapsed += delta
	while queen_food_elapsed >= QUEEN_FOOD_INTERVAL:
		queen_food_elapsed -= QUEEN_FOOD_INTERVAL
		add_food(1)


func add_food(amount: int) -> void:
	if amount > 0:
		food_amount += amount


func spend_food(amount: int) -> bool:
	if amount < 0 or food_amount < amount:
		return false
	food_amount -= amount
	return true


func save_game(queen_amount: int, worker_amount: int, warrior_amount: int) -> void:
	var state := {
		"update_time": int(Time.get_unix_time_from_system()),
		"food_amount": food_amount,
		"queen_amount": queen_amount,
		"worker_amount": worker_amount,
		"warrior_amount": warrior_amount,
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
	saved_queen_amount = maxi(0, int(state.get("queen_amount", 1)))
	saved_worker_amount = maxi(0, int(state.get("worker_amount", 0)))
	saved_warrior_amount = maxi(0, int(state.get("warrior_amount", 0)))
	has_saved_game = true


func reset_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if remove_error != OK:
			push_error("Could not remove saved game: %s" % error_string(remove_error))
			return

	food_amount = STARTING_FOOD
	queen_food_elapsed = 0.0
	has_saved_game = false
	saved_queen_amount = 1
	saved_worker_amount = 0
	saved_warrior_amount = 0
	update_time = 0
	get_tree().reload_current_scene()
