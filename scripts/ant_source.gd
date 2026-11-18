extends Node2D

signal worker_count_changed(count: int)
const ANT_SCENE: PackedScene = preload("res://scenes/ant.tscn")
const FOOD_SOURCE_SCENE: PackedScene = preload("res://scenes/food_source.tscn")
const QUEEN_COUNT: int = 1
const WORKER_COUNT: int = 10
const WARRIOR_COUNT: int = 3
const FOLLOW_DISTANCE: float = 4.0
const ARRIVAL_TOLERANCE: float = 2.0
const IDLE_SCATTER_RANGE: float = 10.0
const MAX_GROUP_SIZE: int = 100

@export var ant_speed: float = 28.0
@export var spawn_workers: bool = true
@export var spawn_warriors: bool = true
@export var leader_destination_distance: float = 72.0
@export_range(1.0, 10.0, 0.5) var idle_pause_duration: float = 3.0
@export_range(0.0, 10000.0, 1.0) var food_search_range: float = 120.0
@export_range(0.0, 10000.0, 1.0) var warrior_scout_range: float = 32.0
@export_range(0, 20, 1) var active_food_source_count: int = 3
@export_range(1, 100, 1) var food_per_ant_per_trip: int = 1
@export_range(1.0, 20.0, 0.5) var food_gather_pause_duration: float = 5.0

@onready var queen_cluster: Node2D = $QueenCluster
@onready var worker_cluster: Node2D = $WorkerCluster
@onready var warrior_cluster: Node2D = $WarriorCluster
@onready var food_sources_container: Node2D = $FoodSources

var queen_ants: Array[AntParticle] = []
var worker_ants: Array[AntParticle] = []
var worker_groups: Array = []
var warrior_ants: Array[AntParticle] = []
var random := RandomNumberGenerator.new()
var worker_destination: Vector2
var warrior_destination: Vector2
var current_food_source: Node2D
var worker_colony_is_walking: bool = false
var startup_idle_remaining: float = 0.0
var worker_idle_remaining: float = 0.0
var warrior_idle_remaining: float = 0.0
var worker_foraging_enabled: bool = false
var worker_behavior_initialized: bool = false
var worker_destination_handled: bool = false


func _ready() -> void:
	random.randomize()
	if get_tree().current_scene == get_parent():
		position = get_viewport_rect().size * 0.5
	_spawn_colonies()
	_spawn_initial_food_sources()
	if not worker_ants.is_empty():
		worker_groups.append(worker_ants.duplicate())
	if not warrior_ants.is_empty():
		_start_warrior_scouting()


func _process(delta: float) -> void:
	_update_idle_group(queen_ants, delta)
	_update_warrior_scouting(delta)
	_update_worker_returns(delta)
	if worker_colony_is_walking:
		_update_worker_walking(delta)
	else:
		_update_idle_workers(delta)
		if startup_idle_remaining > 0.0:
			startup_idle_remaining = maxf(0.0, startup_idle_remaining - delta)
			if startup_idle_remaining == 0.0:
				_start_worker_walk()


func _spawn_colonies() -> void:
	var worker_count := GameState.saved_worker_amount if GameState.has_saved_game else (WORKER_COUNT if spawn_workers else 0)
	var queen_count := GameState.saved_queen_amount if GameState.has_saved_game else QUEEN_COUNT
	var warrior_count := GameState.saved_warrior_amount if GameState.has_saved_game else (WARRIOR_COUNT if spawn_warriors else 0)
	# Workers are created first, so the first emitted ant remains their leader.
	var worker_direction := Vector2.RIGHT.rotated(random.randf_range(0.0, TAU))
	for index in range(worker_count):
		var ant := _create_ant(AntParticle.AntType.WORKER, worker_cluster)
		ant.position = -worker_direction * FOLLOW_DISTANCE * index
		ant.heading = worker_direction
		ant.rotation = worker_direction.angle() - PI * 0.5
		worker_ants.append(ant)
		if worker_ants.size() == 1:
			_initialize_worker_behavior()

	for index in range(queen_count):
		var queen := _create_ant(AntParticle.AntType.QUEEN, queen_cluster)
		queen.position = Vector2.ZERO
		queen_ants.append(queen)

	var warrior_direction := Vector2.RIGHT.rotated(random.randf_range(0.0, TAU))
	for index in range(warrior_count):
		var ant := _create_ant(AntParticle.AntType.WARRIOR, warrior_cluster)
		ant.position = -warrior_direction * FOLLOW_DISTANCE * index
		ant.heading = warrior_direction
		ant.rotation = warrior_direction.angle() - PI * 0.5
		warrior_ants.append(ant)

	_set_group_idle(queen_ants)
	_set_group_idle(worker_ants)
	_set_group_idle(warrior_ants)


func _create_ant(ant_type, cluster: Node2D) -> AntParticle:
	var ant := ANT_SCENE.instantiate() as AntParticle
	ant.ant_type = ant_type
	ant.move_speed = ant_speed
	cluster.add_child(ant)
	return ant


func _start_worker_walk() -> void:
	if worker_ants.is_empty():
		return

	var direction := Vector2.RIGHT.rotated(random.randf_range(0.0, TAU))
	current_food_source = null
	worker_destination = _center_of_mass(worker_ants) + direction * leader_destination_distance
	_set_workers_walking()


func _start_worker_foraging_walk() -> void:
	if worker_ants.is_empty():
		return

	current_food_source = _nearest_food_source()
	if current_food_source != null:
		worker_destination = worker_cluster.to_local(current_food_source.global_position)
	else:
		var angle := random.randf_range(0.0, TAU)
		var radius := sqrt(random.randf()) * food_search_range
		worker_destination = worker_ants[0].position + Vector2.RIGHT.rotated(angle) * radius
	_set_workers_walking()


func _set_workers_walking() -> void:
	worker_destination_handled = false
	worker_idle_remaining = 0.0
	for ant in worker_ants:
		ant.has_reached_destination = false
	worker_ants[0].set_target(worker_destination)
	worker_ants[0].set_state(AntParticle.State.walking)
	for index in range(1, worker_ants.size()):
		worker_ants[index].set_state(AntParticle.State.walking)
	worker_colony_is_walking = true


func _update_worker_walking(delta: float) -> void:
	if current_food_source != null:
		if is_instance_valid(current_food_source):
			worker_destination = worker_cluster.to_local(current_food_source.global_position)
		else:
			current_food_source = null

	var leader := worker_ants[0]
	if not leader.is_returning_food and leader.carried_food <= 0:
		if not leader.has_reached_destination:
			leader.set_target(worker_destination)
			leader.move_step(delta)
			if leader.position.distance_to(worker_destination) <= ARRIVAL_TOLERANCE:
				_arrive_ant_at_destination(leader, worker_destination)
				if current_food_source != null:
					_collect_worker_food(leader)
				else:
					worker_idle_remaining = idle_pause_duration
		else:
			_update_idle_ant(leader, delta)
			worker_idle_remaining = maxf(0.0, worker_idle_remaining - delta)
			if worker_idle_remaining == 0.0 and current_food_source == null:
				_start_worker_foraging_walk()
				return

	for index in range(1, worker_ants.size()):
		var ant := worker_ants[index]
		if ant.is_returning_food or ant.carried_food > 0:
			continue
		if ant.has_reached_destination:
			_update_idle_ant(ant, delta)
			continue
		var predecessor := worker_ants[index - 1]
		var trail_target := worker_destination if predecessor.has_reached_destination else predecessor.position - predecessor.heading * FOLLOW_DISTANCE
		ant.set_target(trail_target)
		ant.set_state(AntParticle.State.walking)
		ant.move_step(delta)
		if ant.position.distance_to(worker_destination) <= ARRIVAL_TOLERANCE:
			_arrive_ant_at_destination(ant, worker_destination)
			if current_food_source != null:
				_collect_worker_food(ant)

	for ant in worker_ants:
		if not ant.has_reached_destination:
			return
	if worker_destination_handled:
		return
	worker_destination_handled = true
	worker_foraging_enabled = true
	current_food_source = null
	worker_colony_is_walking = false


func _collect_worker_food(ant: AntParticle) -> void:
	if not is_instance_valid(current_food_source):
		return
	ant.carried_food = int(current_food_source.call("harvest", food_per_ant_per_trip))
	if ant.carried_food <= 0:
		return
	ant.food_gather_remaining = food_gather_pause_duration
	ant.idle_anchor = worker_destination
	ant.set_state(AntParticle.State.gathering)
	_assign_idle_target(ant)
	worker_idle_remaining = food_gather_pause_duration


func _update_worker_returns(delta: float) -> void:
	var queen_position := worker_cluster.to_local(queen_cluster.global_position)
	for ant in worker_ants:
		if ant.carried_food > 0 and not ant.is_returning_food:
			_update_idle_ant(ant, delta)
			ant.food_gather_remaining = maxf(0.0, ant.food_gather_remaining - delta)
			if ant.food_gather_remaining == 0.0:
				ant.is_returning_food = true
				ant.set_state(AntParticle.State.walking)
				ant.set_target(queen_position)
			continue
		if not ant.is_returning_food:
			continue
		ant.set_target(queen_position)
		ant.move_step(delta)
		if ant.position.distance_to(queen_position) <= ARRIVAL_TOLERANCE:
			ant.position = queen_position
			GameState.add_food(ant.carried_food)
			ant.carried_food = 0
			ant.is_returning_food = false
			ant.set_state(AntParticle.State.idle)
			ant.idle_anchor = queen_position
			_assign_idle_target(ant)


func _update_idle_workers(delta: float) -> void:
	_update_idle_group(worker_ants, delta)
	if not worker_foraging_enabled:
		return
	for ant in worker_ants:
		if ant.is_returning_food or ant.carried_food > 0:
			return
	if worker_idle_remaining > 0.0:
		worker_idle_remaining = maxf(0.0, worker_idle_remaining - delta)
		if worker_idle_remaining > 0.0:
			return
	_start_worker_foraging_walk()


func _start_warrior_scouting() -> void:
	warrior_idle_remaining = idle_pause_duration


func _choose_warrior_destination() -> void:
	var angle := random.randf_range(0.0, TAU)
	var radius := sqrt(random.randf()) * warrior_scout_range
	warrior_destination = Vector2.RIGHT.rotated(angle) * radius
	for ant in warrior_ants:
		ant.has_reached_destination = false
	warrior_ants[0].set_target(warrior_destination)
	for ant in warrior_ants:
		ant.set_state(AntParticle.State.walking)


func _update_warrior_scouting(delta: float) -> void:
	if warrior_ants.is_empty():
		return
	if warrior_idle_remaining > 0.0 and not warrior_ants[0].has_reached_destination:
		_update_idle_group(warrior_ants, delta)
		warrior_idle_remaining = maxf(0.0, warrior_idle_remaining - delta)
		if warrior_idle_remaining == 0.0:
			_choose_warrior_destination()
		return

	var leader := warrior_ants[0]
	if not leader.has_reached_destination:
		leader.set_target(warrior_destination)
		leader.move_step(delta)
		if leader.position.distance_to(warrior_destination) <= ARRIVAL_TOLERANCE:
			_arrive_ant_at_destination(leader, warrior_destination)
			warrior_idle_remaining = idle_pause_duration
	else:
		_update_idle_ant(leader, delta)
		warrior_idle_remaining = maxf(0.0, warrior_idle_remaining - delta)
		if warrior_idle_remaining == 0.0:
			_choose_warrior_destination()
			return

	for index in range(1, warrior_ants.size()):
		var ant := warrior_ants[index]
		if ant.has_reached_destination:
			_update_idle_ant(ant, delta)
			continue
		var predecessor := warrior_ants[index - 1]
		var trail_target := warrior_destination if predecessor.has_reached_destination else predecessor.position - predecessor.heading * FOLLOW_DISTANCE
		ant.set_target(trail_target)
		ant.set_state(AntParticle.State.walking)
		ant.move_step(delta)
		if ant.position.distance_to(warrior_destination) <= ARRIVAL_TOLERANCE:
			_arrive_ant_at_destination(ant, warrior_destination)


func _arrive_ant_at_destination(ant: AntParticle, destination: Vector2) -> void:
	ant.position = destination
	ant.has_reached_destination = true
	ant.set_state(AntParticle.State.idle)
	ant.idle_anchor = destination
	_assign_idle_target(ant)


func _update_idle_ant(ant: AntParticle, delta: float) -> void:
	if ant.is_at_target(ARRIVAL_TOLERANCE):
		_assign_idle_target(ant)
	ant.move_step(delta)


func _set_group_idle(group: Array[AntParticle]) -> void:
	for ant in group:
		ant.set_state(AntParticle.State.idle)
		ant.idle_anchor = ant.position
		_assign_idle_target(ant)


func _update_idle_group(group: Array[AntParticle], delta: float) -> void:
	for ant in group:
		if ant.state != AntParticle.State.idle:
			continue
		if ant.is_at_target(ARRIVAL_TOLERANCE):
			_assign_idle_target(ant)
		ant.move_step(delta)


func _assign_idle_target(ant: AntParticle) -> void:
	var angle := random.randf_range(0.0, TAU)
	var radius := sqrt(random.randf()) * IDLE_SCATTER_RANGE
	ant.set_target(ant.idle_anchor + Vector2.RIGHT.rotated(angle) * radius)


func _nearest_food_source() -> Node2D:
	var leader := worker_ants[0]
	var nearest: Node2D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("food_sources"):
		var source := candidate as Node2D
		if source == null:
			continue
		if int(source.get("food_remaining")) <= 0:
			continue
		var distance := leader.global_position.distance_to(source.global_position)
		if nearest == null or distance < nearest_distance:
			nearest = source
			nearest_distance = distance
	return nearest


func _center_of_mass(group: Array[AntParticle]) -> Vector2:
	var center := Vector2.ZERO
	for ant in group:
		center += ant.position
	return center / float(group.size())


func _spawn_initial_food_sources() -> void:
	for _index in range(active_food_source_count):
		_spawn_food_source()


func _spawn_food_source() -> void:
	var source := FOOD_SOURCE_SCENE.instantiate() as Node2D
	source.connect("depleted", _on_food_source_depleted)
	food_sources_container.add_child(source)
	source.call("initialize", random)
	var angle := random.randf_range(0.0, TAU)
	var radius := random.randf_range(food_search_range * 0.45, food_search_range)
	source.position = Vector2.RIGHT.rotated(angle) * radius


func _on_food_source_depleted(_source: Node2D) -> void:
	_spawn_food_source()


func _initialize_worker_behavior() -> void:
	if worker_behavior_initialized or worker_ants.is_empty():
		return
	worker_behavior_initialized = true
	current_food_source = null
	worker_colony_is_walking = false
	worker_foraging_enabled = false
	worker_idle_remaining = 0.0
	startup_idle_remaining = idle_pause_duration
	_set_group_idle(worker_ants)


func purchase_worker() -> bool:
	if not GameState.spend_food(100):
		return false

	var first_worker := worker_ants.is_empty()
	var worker := _create_ant(AntParticle.AntType.WORKER, worker_cluster)
	if worker_groups.is_empty():
		worker_groups.append(worker_ants.duplicate())
	if worker_groups.back().size() >= MAX_GROUP_SIZE:
		worker_groups.append([])
	var current_group: Array = worker_groups.back()

	if first_worker:
		worker.position = Vector2.ZERO
	else:
		var predecessor := worker_ants[worker_ants.size() - 1]
		worker.position = predecessor.position - predecessor.heading * FOLLOW_DISTANCE

	worker_ants.append(worker)
	current_group.append(worker)
	worker_count_changed.emit(worker_ants.size())

	if first_worker:
		_initialize_worker_behavior()
	elif worker_colony_is_walking:
		worker.set_state(AntParticle.State.walking)
	else:
		worker.set_state(AntParticle.State.idle)
		worker.idle_anchor = worker.position
		_assign_idle_target(worker)
	return true
