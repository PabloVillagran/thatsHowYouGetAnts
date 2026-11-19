extends Node2D

signal worker_count_changed(count: int)

const ANT_SCENE: PackedScene = preload("res://scenes/ant.tscn")
const FOOD_SOURCE_SCENE: PackedScene = preload("res://scenes/food_source.tscn")
const FOOD_DROP_SCENE: PackedScene = preload("res://scenes/food_drop.tscn")
const QUEEN_COUNT: int = 1
const WORKER_COUNT: int = 10
const WARRIOR_COUNT: int = 3
const ARRIVAL_TOLERANCE: float = 2.0
const QUEEN_DROP_HALF_SIZE: float = 5.0
const QUEEN_SPAWN_POSITION: Vector2 = Vector2(0.0, -32.0)
const FOLLOW_DISTANCE: float = 9.0
const MAX_WORKERS_PER_CLUSTER: int = 10

@export var ant_speed: float = 19.6
@export var spawn_workers: bool = false
@export var spawn_warriors: bool = false
@export var queen_ant_mode: bool = false
@export_range(0.0, 10000.0, 1.0) var food_search_range: float = 120.0
@export_range(1.0, 500.0, 1.0) var leader_search_range: float = 40.0
@export_range(0, 20, 1) var active_food_source_count: int = 3
@export_range(1, 100, 1) var food_per_ant_per_trip: int = 1
@export_range(1.0, 20.0, 0.5) var food_gather_pause_duration: float = 5.0

@onready var food_sources_container: Node2D = $FoodSources

var queen_ants: Array[AntParticle] = []
var worker_ants: Array[AntParticle] = []
var worker_groups: Array = []
var warrior_ants: Array[AntParticle] = []
var random := RandomNumberGenerator.new()
var queen_spawn_elapsed: float = 0.0


func _ready() -> void:
	GameState.queen_ant_mode_active = queen_ant_mode
	random.randomize()
	# The camera frames the viewport center in both game scenes. Keep the
	# shared spawn origin there regardless of how the scene was entered.
	position = get_viewport_rect().size * 0.5
	_spawn_colonies()
	_spawn_initial_food_sources()
	for group_state in worker_groups:
		_start_worker_group_foraging(group_state)


func _process(delta: float) -> void:
	if queen_ant_mode and not queen_ants.is_empty():
		var spawn_interval := GameState.QUEEN_FOOD_INTERVAL / float(1 + GameState.queen_production_level)
		queen_spawn_elapsed += delta * float(queen_ants.size())
		while queen_spawn_elapsed >= spawn_interval:
			queen_spawn_elapsed -= spawn_interval
			_spawn_queen_worker()
	_update_worker_lifetimes(delta)
	_update_worker_groups(delta)
	_update_idle_queens(delta)
	_update_warriors(delta)


func _spawn_colonies() -> void:
	var workers_to_spawn := GameState.saved_worker_amount if GameState.has_saved_game else (WORKER_COUNT if spawn_workers else 0)
	var queens_to_spawn := GameState.saved_queen_amount if GameState.has_saved_game else QUEEN_COUNT
	var warriors_to_spawn := GameState.saved_warrior_amount if GameState.has_saved_game else (WARRIOR_COUNT if spawn_warriors else 0)
	for _index in range(queens_to_spawn):
		var queen := _create_ant(AntParticle.AntType.QUEEN)
		queen.position = QUEEN_SPAWN_POSITION
		queen_ants.append(queen)
	for _index in range(workers_to_spawn):
		_register_worker(_create_ant(AntParticle.AntType.WORKER))
	for _index in range(warriors_to_spawn):
		var warrior := _create_ant(AntParticle.AntType.WARRIOR)
		warrior.position = QUEEN_SPAWN_POSITION
		warrior_ants.append(warrior)
		_start_warrior_scouting(warrior)
	_set_idle_queens()
	GameState.queen_count = queen_ants.size()
	GameState.worker_count = worker_ants.size()
	GameState.warrior_count = warrior_ants.size()


func _create_ant(ant_type) -> AntParticle:
	var ant := ANT_SCENE.instantiate() as AntParticle
	ant.ant_type = ant_type
	ant.move_speed = ant_speed * pow(1.1, GameState.speed_level)
	add_child(ant)
	return ant


func _register_worker(ant: AntParticle) -> void:
	ant.position = to_local(_random_queen_drop_position())
	var group_state := _group_for_new_worker(ant.global_position)
	var group_ants: Array = group_state["ants"]
	ant.heading = Vector2.RIGHT.rotated(random.randf_range(0.0, TAU))
	ant.idle_anchor = ant.position
	ant.rotation = ant.heading.angle() - PI * 0.5
	worker_ants.append(ant)
	group_ants.append(ant)
	if queen_ant_mode:
		ant.lifetime_remaining = 30.0 + 10.0 * GameState.worker_lifetime_level
	if group_ants.size() == 1 and not food_sources_container.get_children().is_empty():
		_start_worker_group_foraging(group_state)
	elif group_state["phase"] == "outbound" or group_state["phase"] == "returning":
		ant.set_state(AntParticle.State.walking)
	elif group_state["phase"] == "gathering":
		var source := group_state["food_source"] as Node2D
		if is_instance_valid(source):
			_assign_gathering_target(ant, source)
	else:
		ant.set_state(AntParticle.State.idle)
		_assign_idle_target(ant)


func _group_for_new_worker(spawn_position: Vector2, create_if_missing: bool = true) -> Dictionary:
	var nearest_group: Dictionary = {}
	var nearest_distance := leader_search_range
	for candidate in worker_groups:
		var group_state: Dictionary = candidate
		var group_ants: Array = group_state["ants"]
		if group_state["phase"] == "orphan_return" or group_ants.is_empty() or group_ants.size() >= MAX_WORKERS_PER_CLUSTER:
			continue
		var leader := group_ants[0] as AntParticle
		var distance := spawn_position.distance_to(leader.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_group = group_state
	if not nearest_group.is_empty():
		return nearest_group
	return _create_worker_group() if create_if_missing else {}


func _create_worker_group() -> Dictionary:
	var group_state: Dictionary = {
		"ants": [],
		"destination": QUEEN_SPAWN_POSITION,
		"food_source": null,
		"phase": "searching",
	}
	worker_groups.append(group_state)
	return group_state


func _spawn_queen_worker() -> void:
	var worker := _create_ant(AntParticle.AntType.WORKER)
	_register_worker(worker)
	worker_count_changed.emit(worker_ants.size())
	GameState.worker_count = worker_ants.size()
	GameState.economy_changed.emit()


func _update_worker_lifetimes(delta: float) -> void:
	if not queen_ant_mode:
		return
	for ant in worker_ants.duplicate():
		ant.lifetime_remaining -= delta
		if ant.lifetime_remaining <= 0.0:
			_remove_worker(ant)


func _remove_worker(ant: AntParticle) -> void:
	# Only workers expire in Queen Ant 1; queens are permanent colony members.
	if ant.ant_type != AntParticle.AntType.WORKER or not worker_ants.has(ant):
		return
	if ant.carried_food > 0:
		_drop_carried_food(ant)
	worker_ants.erase(ant)
	for group_state in worker_groups:
		var group_ants: Array = group_state["ants"]
		if not group_ants.has(ant):
			continue
		var was_leader: bool = group_ants[0] == ant
		group_ants.erase(ant)
		if group_ants.is_empty():
			group_state["phase"] = "searching"
			group_state["food_source"] = null
		elif was_leader and (group_state["phase"] == "outbound" or group_state["phase"] == "returning"):
			var new_leader := group_ants[0] as AntParticle
			# Preserve the group's current destination even when the old leader
			# expires before any follower reaches it.
			new_leader.has_reached_destination = false
			new_leader.set_target(group_state["destination"])
			new_leader.set_state(AntParticle.State.walking)
		break
	ant.mark_dead()
	GameState.worker_count = worker_ants.size()
	worker_count_changed.emit(worker_ants.size())


func _drop_carried_food(ant: AntParticle) -> void:
	var drop := FOOD_DROP_SCENE.instantiate() as Polygon2D
	food_sources_container.add_child(drop)
	drop.position = food_sources_container.to_local(ant.global_position)
	drop.call("initialize", ant.carried_food)
	drop.connect("depleted", _on_food_drop_depleted)


func _random_queen_drop_position() -> Vector2:
	var queen_position := to_global(QUEEN_SPAWN_POSITION)
	var offset := Vector2(
		random.randf_range(-QUEEN_DROP_HALF_SIZE, QUEEN_DROP_HALF_SIZE),
		random.randf_range(-QUEEN_DROP_HALF_SIZE, QUEEN_DROP_HALF_SIZE)
	)
	return queen_position + offset


func _start_worker_group_foraging(group_state: Dictionary) -> void:
	var group_ants: Array = group_state["ants"]
	if group_ants.is_empty():
		return
	var leader := group_ants[0] as AntParticle
	var source := _nearest_food_source(leader.global_position)
	group_state["food_source"] = source
	if is_instance_valid(source):
		group_state["destination"] = to_local(source.global_position)
		group_state["phase"] = "outbound"
	else:
		var angle := random.randf_range(0.0, TAU)
		var radius := sqrt(random.randf()) * food_search_range
		group_state["destination"] = QUEEN_SPAWN_POSITION + Vector2.RIGHT.rotated(angle) * radius
		group_state["phase"] = "scouting"
	for ant in group_ants:
		ant.has_reached_destination = false
		ant.gathered_this_trip = false
		ant.set_state(AntParticle.State.walking)


func _update_worker_groups(delta: float) -> void:
	for group_state in worker_groups.duplicate():
		var group_ants: Array = group_state["ants"]
		if group_ants.is_empty():
			continue
		match group_state["phase"]:
			"outbound", "scouting":
				_update_group_travel(group_state, delta)
			"gathering":
				_update_group_gathering(group_state, delta)
			"returning":
				_update_group_return(group_state, delta)
			"orphan_return":
				_update_orphan_return(group_state, delta)
			_:
				_start_worker_group_foraging(group_state)


func _update_group_travel(group_state: Dictionary, delta: float) -> void:
	var group_ants: Array = group_state["ants"]
	var source := group_state["food_source"] as Node2D
	if group_state["phase"] == "outbound" and not is_instance_valid(source):
		_start_worker_group_foraging(group_state)
		return
	if is_instance_valid(source):
		group_state["destination"] = to_local(source.global_position)
	var destination: Vector2 = group_state["destination"]
	_move_group_in_formation(group_state, destination, delta)
	if not _all_group_ants_arrived(group_ants):
		return
	if group_state["phase"] == "scouting":
		_start_worker_group_foraging(group_state)
		return
	group_state["phase"] = "gathering"
	for ant in group_ants:
		ant.has_reached_destination = false
		ant.gathered_this_trip = false
		if is_instance_valid(source):
			_assign_gathering_target(ant, source)


func _assign_gathering_target(ant: AntParticle, source: Node2D) -> void:
	var source_radius := source.global_scale.x
	var angle := random.randf_range(0.0, TAU)
	var radius := sqrt(random.randf()) * (source_radius + 1.0)
	var scatter_point := source.global_position + Vector2.RIGHT.rotated(angle) * radius
	ant.gathered_this_trip = false
	ant.food_gather_remaining = 0.0
	ant.set_target(to_local(scatter_point))
	ant.set_state(AntParticle.State.walking)


func _move_group_in_formation(group_state: Dictionary, destination: Vector2, delta: float) -> void:
	var group_ants: Array = group_state["ants"]
	for index in range(group_ants.size()):
		var ant := group_ants[index] as AntParticle
		if ant.has_reached_destination:
			continue
		var target := destination
		if index > 0:
			var predecessor := group_ants[index - 1] as AntParticle
			if not predecessor.has_reached_destination:
				target = predecessor.position - predecessor.heading * FOLLOW_DISTANCE
		ant.set_target(target)
		ant.set_state(AntParticle.State.walking)
		ant.move_step(delta)
		if ant.position.distance_to(destination) <= ARRIVAL_TOLERANCE:
			ant.position = destination
			ant.has_reached_destination = true


func _all_group_ants_arrived(group_ants: Array) -> bool:
	for ant in group_ants:
		if not (ant as AntParticle).has_reached_destination:
			return false
	return true


func _update_group_gathering(group_state: Dictionary, delta: float) -> void:
	var group_ants: Array = group_state["ants"]
	var source := group_state["food_source"] as Node2D
	for ant in group_ants:
		if ant.gathered_this_trip:
			continue
		if not is_instance_valid(source):
			ant.gathered_this_trip = true
			continue
		ant.move_step(delta)
		if ant.position.distance_to(ant.target_position) > ARRIVAL_TOLERANCE:
			continue
		ant.position = ant.target_position
		ant.carried_food += int(source.call("harvest", food_per_ant_per_trip + GameState.carry_capacity_level))
		ant.gathered_this_trip = true
		ant.food_gather_remaining = food_gather_pause_duration
		ant.set_state(AntParticle.State.gathering)
	for ant in group_ants:
		if ant.gathered_this_trip and ant.food_gather_remaining > 0.0:
			ant.food_gather_remaining = maxf(0.0, ant.food_gather_remaining - delta)
	var leader := group_ants[0] as AntParticle
	var everyone_gathered := true
	for ant in group_ants:
		if not ant.gathered_this_trip:
			everyone_gathered = false
			break
	if everyone_gathered and leader.food_gather_remaining <= 0.0:
		group_state["phase"] = "returning"
		group_state["destination"] = to_local(_random_queen_drop_position())
		for ant in group_ants:
			ant.has_reached_destination = false


func _update_group_return(group_state: Dictionary, delta: float) -> void:
	var group_ants: Array = group_state["ants"]
	var destination: Vector2 = group_state["destination"]
	_move_group_in_formation(group_state, destination, delta)
	if not _all_group_ants_arrived(group_ants):
		return
	for ant in group_ants:
		GameState.add_food(ant.carried_food)
		ant.carried_food = 0
		ant.is_returning_food = false
		ant.gathered_this_trip = false
	group_state["food_source"] = null
	_start_worker_group_foraging(group_state)


func _update_orphan_return(group_state: Dictionary, delta: float) -> void:
	var group_ants: Array = group_state["ants"]
	_move_group_in_formation(group_state, group_state["destination"], delta)
	if not _all_group_ants_arrived(group_ants):
		return
	for ant in group_ants:
		GameState.add_food(ant.carried_food)
		ant.carried_food = 0
	var ant := group_ants[0] as AntParticle
	worker_groups.erase(group_state)
	group_ants.clear()
	_reassign_worker_after_source_depletion(ant)


func _nearest_food_source(origin: Vector2) -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("food_polygons"):
		var source := candidate as Node2D
		if source == null or int(source.get("food_remaining")) <= 0:
			continue
		var distance := origin.distance_to(source.global_position)
		if distance < nearest_distance:
			nearest = source
			nearest_distance = distance
	return nearest


func _set_idle_queens() -> void:
	for queen in queen_ants:
		queen.set_state(AntParticle.State.idle)
		queen.idle_anchor = queen.position
		_assign_idle_target(queen)


func _update_idle_queens(delta: float) -> void:
	for queen in queen_ants:
		if queen.state == AntParticle.State.idle:
			if queen.is_at_target(ARRIVAL_TOLERANCE):
				_assign_idle_target(queen)
			queen.move_step(delta)


func _start_warrior_scouting(warrior: AntParticle) -> void:
	warrior.idle_anchor = QUEEN_SPAWN_POSITION
	warrior.set_state(AntParticle.State.walking)
	_choose_warrior_destination(warrior)


func _choose_warrior_destination(warrior: AntParticle) -> void:
	var angle := random.randf_range(0.0, TAU)
	var radius := sqrt(random.randf()) * food_search_range
	warrior.set_target(warrior.idle_anchor + Vector2.RIGHT.rotated(angle) * radius)


func _update_warriors(delta: float) -> void:
	for warrior in warrior_ants:
		warrior.move_step(delta)
		if warrior.is_at_target(ARRIVAL_TOLERANCE):
			_choose_warrior_destination(warrior)


func _assign_idle_target(ant: AntParticle) -> void:
	var angle := random.randf_range(0.0, TAU)
	var radius := sqrt(random.randf()) * 10.0
	ant.set_target(ant.idle_anchor + Vector2.RIGHT.rotated(angle) * radius)


func _spawn_initial_food_sources() -> void:
	for _index in range(active_food_source_count):
		_spawn_food_source()


func _spawn_food_source() -> void:
	var source := FOOD_SOURCE_SCENE.instantiate() as Node2D
	source.connect("depleted", _on_food_source_depleted)
	food_sources_container.add_child(source)
	source.call("initialize", random, 1.0 + 0.1 * GameState.food_efficiency_level)
	var angle := random.randf_range(0.0, TAU)
	var radius := random.randf_range(food_search_range * 0.45, food_search_range)
	source.position = Vector2.RIGHT.rotated(angle) * radius


func _on_food_source_depleted(source: Node2D) -> void:
	_spawn_food_source()
	var interrupted_groups: Array = []
	for group_state in worker_groups:
		if (group_state["phase"] == "outbound" or group_state["phase"] == "gathering") and group_state["food_source"] == source:
			interrupted_groups.append(group_state)
	for group_state in interrupted_groups:
		worker_groups.erase(group_state)
		var interrupted_ants: Array = group_state["ants"].duplicate()
		group_state["ants"].clear()
		for ant in interrupted_ants:
			if group_state["phase"] == "gathering":
				_return_worker_after_gather_source_depletion(ant)
			else:
				_reassign_worker_after_source_depletion(ant)


func _reassign_worker_after_source_depletion(ant: AntParticle) -> void:
	ant.has_reached_destination = false
	ant.gathered_this_trip = false
	var group_state := _group_for_new_worker(ant.global_position)
	_attach_worker_to_group(ant, group_state)


func _attach_worker_to_group(ant: AntParticle, group_state: Dictionary) -> void:
	var group_ants: Array = group_state["ants"]
	group_ants.append(ant)
	if group_ants.size() == 1:
		_start_worker_group_foraging(group_state)
		return
	match group_state["phase"]:
		"outbound", "scouting", "returning":
			ant.set_state(AntParticle.State.walking)
		"gathering":
			var current_source := group_state["food_source"] as Node2D
			if is_instance_valid(current_source):
				_assign_gathering_target(ant, current_source)
		_:
			ant.set_state(AntParticle.State.idle)
			_assign_idle_target(ant)


func _return_worker_after_gather_source_depletion(ant: AntParticle) -> void:
	ant.has_reached_destination = false
	ant.gathered_this_trip = false
	var nearby_group := _group_for_new_worker(ant.global_position, false)
	if not nearby_group.is_empty():
		_attach_worker_to_group(ant, nearby_group)
		return
	var return_group := _create_worker_group()
	return_group["ants"].append(ant)
	return_group["phase"] = "orphan_return"
	return_group["destination"] = to_local(_random_queen_drop_position())
	ant.set_target(return_group["destination"])
	ant.set_state(AntParticle.State.walking)


func _on_food_drop_depleted(_drop: Node2D) -> void:
	return


func purchase_worker() -> bool:
	if not GameState.spend_food(GameState.worker_cost):
		return false
	GameState.worker_cost = GameState.next_cost(GameState.worker_cost, 1.25)
	_register_worker(_create_ant(AntParticle.AntType.WORKER))
	worker_count_changed.emit(worker_ants.size())
	GameState.economy_changed.emit()
	return true


func purchase_queen() -> bool:
	if not GameState.spend_food(GameState.queen_cost):
		return false
	GameState.queen_cost = GameState.next_cost(GameState.queen_cost, 1.5)
	var queen := _create_ant(AntParticle.AntType.QUEEN)
	queen.position = QUEEN_SPAWN_POSITION
	queen_ants.append(queen)
	queen.set_state(AntParticle.State.idle)
	queen.idle_anchor = queen.position
	_assign_idle_target(queen)
	GameState.queen_count = queen_ants.size()
	GameState.economy_changed.emit()
	return true


func purchase_upgrade(upgrade: String) -> bool:
	var cost: int
	match upgrade:
		"queen_production": cost = GameState.queen_production_cost
		"carry_capacity": cost = GameState.carry_capacity_cost
		"speed": cost = GameState.speed_cost
		"food_efficiency": cost = GameState.food_efficiency_cost
		"worker_lifetime": cost = GameState.worker_lifetime_cost
		_: return false
	if not GameState.spend_food(cost):
		return false
	match upgrade:
		"queen_production":
			GameState.queen_production_level += 1
			GameState.queen_production_cost = GameState.next_cost(cost, 1.15)
		"carry_capacity":
			GameState.carry_capacity_level += 1
			GameState.carry_capacity_cost = GameState.next_cost(cost, 1.15)
		"speed":
			GameState.speed_level += 1
			GameState.speed_cost = GameState.next_cost(cost, 1.15)
			for ant in queen_ants + worker_ants + warrior_ants:
				ant.move_speed = ant_speed * pow(1.1, GameState.speed_level)
		"food_efficiency":
			GameState.food_efficiency_level += 1
			GameState.food_efficiency_cost = GameState.next_cost(cost, 1.15)
		"worker_lifetime":
			GameState.worker_lifetime_level += 1
			GameState.worker_lifetime_cost = GameState.next_cost(cost, 1.15)
	GameState.economy_changed.emit()
	return true
