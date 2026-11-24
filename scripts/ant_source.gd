extends Node2D

signal worker_count_changed(count: int)

const ANT_SCENE: PackedScene = preload("res://scenes/ant.tscn")
const FOOD_SOURCE_SCENE: PackedScene = preload("res://scenes/food_source.tscn")
const FOOD_DROP_SCENE: PackedScene = preload("res://scenes/food_drop.tscn")
const SUPER_FOOD_SCENE: PackedScene = preload("res://scenes/super_food.tscn")
const STEP_HEATMAP_OVERLAY_SCRIPT = preload("res://scripts/step_heatmap_overlay.gd")
const WORKER_TRAIL_Z_INDEX: int = -4096
const QUEEN_Z_INDEX: int = 2
const WARRIOR_Z_INDEX: int = 3
const WORKER_Z_INDEX: int = 4
const SUPER_FOOD_DROP_CHANCE_OUT_OF: int = 10
const SUPER_FOOD_DROP_CHANCE_IN: int = 1
const SUPER_FOOD_SPEED_MULTIPLIER: float = 2.0
const SUPER_FOOD_SPEED_DURATION: float = 10.0
const QUEEN_COUNT: int = 1
const WORKER_COUNT: int = 10
const WARRIOR_COUNT: int = 3
const ARRIVAL_TOLERANCE: float = 2.0
const QUEEN_DROP_HALF_SIZE: float = 5.0
const STOCKPILE_SLOT_SPACING: float = 3.0
const QUEEN_SPAWN_POSITION: Vector2 = Vector2(0.0, -32.0)
const FOLLOW_DISTANCE: float = 10.0
const MAX_WORKERS_PER_CLUSTER: int = 10
const COLONY_RADIUS: float = 120.0
const WARRIOR_COST: int = 100
const WARRIOR_HEALTH: int = 10
const WARRIOR_DAMAGE: int = 4
const WARRIOR_HEALTH_PER_ENDURANCE_LEVEL: int = 2
const ATTACK_RANGE: float = 5.0
const ATTACK_INTERVAL: float = 1.0
const WARRIOR_POST_WANDER_RADIUS: float = 3.0
const WORM_HEALTH: int = 24
const WORM_SPEED: float = 12.0
const WORM_SPAWN_MARGIN: float = 10.0
const WORM_LANE_OFFSET_FRACTION: float = 0.65
const WORM_DROP_COUNT: int = 6
const WORM_DROP_FOOD: int = 60
const WORM_DROP_SPACING: float = 3.0
const STEP_GRID_SPACING: float = 15.0
const STEP_GRID_ROW_HEIGHT: float = 12.990381
const STEP_GRID_STEP_RADIUS: float = 7.0
const WARRIOR_DEFENSE_RADIUS: float = STEP_GRID_STEP_RADIUS + ATTACK_RANGE
const STEP_GRID_MAX_COUNT: int = 100
const SATURATED_POINT_FOOD_CLEARANCE: float = 2.0
const FOOD_SOURCE_POSITION_ATTEMPTS: int = 200
const STEP_GRID_NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 1)]

@export var ant_speed: float = 19.6
@export var spawn_workers: bool = false
@export var spawn_warriors: bool = false
@export var queen_ant_mode: bool = false
@export_range(0.0, 10000.0, 1.0) var food_search_range: float = 120.0
@export_range(0, 20, 1) var active_food_source_count: int = 3
@export_range(1, 100, 1) var food_per_ant_per_trip: int = 1
@export_range(1.0, 20.0, 0.5) var food_gather_pause_duration: float = 5.0
@export var debug_step_heatmap: bool = false

@onready var food_sources_container: Node2D = $FoodSources

var queen_ants: Array[AntParticle] = []
var worker_ants: Array[AntParticle] = []
var worker_groups: Array = []
var warrior_ants: Array[AntParticle] = []
var warrior_post_positions: Dictionary = {}
var random := RandomNumberGenerator.new()
var queen_spawn_elapsed: float = 0.0
var worm: Polygon2D
var worm_health: int = 0
var worm_spawn_remaining: float = 0.0
var worm_travel_direction: Vector2 = Vector2.ZERO
var worm_exit_position: Vector2 = Vector2.ZERO
var super_food_speed_remaining: float = 0.0
var step_counts: Dictionary = {}
var step_grid_colliders: Dictionary = {}
var step_grid_points: Dictionary = {}
var ant_previous_positions: Dictionary = {}
var ant_active_step_points: Dictionary = {}
var step_heatmap_overlay: StepHeatmapOverlay
var worker_trail_overlay: StepHeatmapOverlay


func _ready() -> void:
	GameState.queen_ant_mode_active = queen_ant_mode
	random.randomize()
	# The camera frames the viewport center in both game scenes. Keep the
	# shared spawn origin there regardless of how the scene was entered.
	position = get_viewport_rect().size * 0.5
	step_heatmap_overlay = STEP_HEATMAP_OVERLAY_SCRIPT.new() as StepHeatmapOverlay
	step_heatmap_overlay.name = "StepHeatmapOverlay"
	step_heatmap_overlay.z_as_relative = false
	step_heatmap_overlay.z_index = 4096
	step_heatmap_overlay.draw_paint_trail = false
	add_child(step_heatmap_overlay)
	worker_trail_overlay = STEP_HEATMAP_OVERLAY_SCRIPT.new() as StepHeatmapOverlay
	worker_trail_overlay.name = "WorkerTrailOverlay"
	worker_trail_overlay.z_as_relative = false
	worker_trail_overlay.z_index = WORKER_TRAIL_Z_INDEX
	worker_trail_overlay.draw_step_heatmap = false
	add_child(worker_trail_overlay)
	if GameState.has_saved_game:
		worker_trail_overlay.load_paint_state(GameState.saved_worker_paint_trail, GameState.saved_worker_paint_trail_format)
	_draw_colony_boundary()
	_schedule_worm()
	_spawn_colonies()
	_initialize_step_grid()
	for warrior in warrior_ants:
		_choose_warrior_destination(warrior)
	_spawn_initial_food_sources()
	for group_state in worker_groups:
		_start_worker_group_foraging(group_state)
	# Establish a fresh save timestamp for the selected variant. This prevents
	# time spent in the other variant from being credited at the wrong rate.
	save_colony()


func _process(delta: float) -> void:
	_update_super_food_speed(delta)
	if queen_ant_mode and not queen_ants.is_empty():
		var spawn_interval := GameState.QUEEN_FOOD_INTERVAL / float(1 + GameState.queen_production_level)
		queen_spawn_elapsed += delta * float(queen_ants.size())
		while queen_spawn_elapsed >= spawn_interval:
			queen_spawn_elapsed -= spawn_interval
			_spawn_queen_worker()
	_update_worker_lifetimes(delta)
	_update_worker_groups(delta)
	_update_idle_workers()
	_update_idle_queens(delta)
	_update_worm_spawn(delta)
	_update_warriors(delta)
	_update_step_heatmap()
	step_heatmap_overlay.step_counts = step_counts
	step_heatmap_overlay.step_grid_points = step_grid_points
	step_heatmap_overlay.debug_step_heatmap = debug_step_heatmap
	step_heatmap_overlay.visible = debug_step_heatmap
	step_heatmap_overlay.queue_redraw()


func _initialize_step_grid() -> void:
	step_counts = GameState.saved_step_counts.duplicate(true) if GameState.has_saved_game else {}
	step_grid_colliders = GameState.saved_step_grid_colliders.duplicate(true) if GameState.has_saved_game else {}
	step_grid_points.clear()
	ant_previous_positions.clear()
	ant_active_step_points.clear()
	# Seed the available triangular lattice through the colony radius. Only
	# visited points are drawn or stored in the save.
	var coordinate_limit := int(ceil(COLONY_RADIUS / STEP_GRID_ROW_HEIGHT)) + 2
	for q in range(-coordinate_limit, coordinate_limit + 1):
		for r in range(-coordinate_limit, coordinate_limit + 1):
			var point := Vector2(q * STEP_GRID_SPACING + r * STEP_GRID_SPACING * 0.5, r * STEP_GRID_ROW_HEIGHT)
			if point.length() <= COLONY_RADIUS:
				step_grid_points[_step_grid_key(Vector2i(q, r))] = Vector2i(q, r)
	for key in step_counts.keys():
		var coordinate: Variant = _step_grid_coordinate(str(key))
		if coordinate != null:
			step_grid_points[key] = coordinate
			step_counts[key] = clampi(int(step_counts[key]), 1, STEP_GRID_MAX_COUNT)
			if not step_grid_colliders.has(key):
				step_grid_colliders[key] = step_counts[key] < STEP_GRID_MAX_COUNT
			else:
				step_grid_colliders[key] = bool(step_grid_colliders[key]) and step_counts[key] < STEP_GRID_MAX_COUNT
			if _is_step_grid_edge(coordinate):
				_expand_step_grid_from(coordinate)
	for ant in _digging_ants():
		ant_previous_positions[ant.get_instance_id()] = ant.position


func _update_step_heatmap() -> void:
	for ant in _digging_ants():
		var id := ant.get_instance_id()
		var current_position := ant.position
		if ant_previous_positions.has(id):
			var previous_position: Vector2 = ant_previous_positions[id]
			var currently_near: Dictionary = {}
			for key in step_grid_points.keys():
				if not bool(step_grid_colliders.get(key, true)):
					continue
				var coordinate: Vector2i = step_grid_points[key]
				var point := QUEEN_SPAWN_POSITION + Vector2(coordinate.x * STEP_GRID_SPACING + coordinate.y * STEP_GRID_SPACING * 0.5, coordinate.y * STEP_GRID_ROW_HEIGHT)
				if _distance_to_segment(point, previous_position, current_position) <= STEP_GRID_STEP_RADIUS:
					var active_points: Dictionary = ant_active_step_points.get(id, {})
					if not active_points.has(key):
						step_counts[key] = mini(STEP_GRID_MAX_COUNT, int(step_counts.get(key, 0)) + 1)
						if step_counts[key] >= STEP_GRID_MAX_COUNT:
							step_grid_colliders[key] = false
						else:
							step_grid_colliders[key] = true
						if _is_step_grid_edge(coordinate):
							_expand_step_grid_from(coordinate)
					if current_position.distance_to(point) <= STEP_GRID_STEP_RADIUS:
						currently_near[key] = true
			ant_active_step_points[id] = currently_near
			if ant.ant_type == AntParticle.AntType.WORKER:
				worker_trail_overlay.paint_worker_trail(previous_position, current_position, step_counts, step_grid_points)
		ant_previous_positions[id] = current_position
	for id in ant_previous_positions.keys():
		if not is_instance_id_valid(int(id)):
			ant_previous_positions.erase(id)
			ant_active_step_points.erase(id)


func _expand_step_grid_from(coordinate: Vector2i) -> void:
	for offset in STEP_GRID_NEIGHBORS:
		var neighbor := coordinate + offset
		var key := _step_grid_key(neighbor)
		if not step_grid_points.has(key):
			step_grid_points[key] = neighbor


func _is_step_grid_edge(coordinate: Vector2i) -> bool:
	for offset in STEP_GRID_NEIGHBORS:
		if not step_grid_points.has(_step_grid_key(coordinate + offset)):
			return true
	return false


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)


func step_speed_multiplier_at(position_to_check: Vector2) -> float:
	var relative_position := position_to_check - QUEEN_SPAWN_POSITION
	var approximate_r := relative_position.y / STEP_GRID_ROW_HEIGHT
	var approximate_q := (relative_position.x - approximate_r * STEP_GRID_SPACING * 0.5) / STEP_GRID_SPACING
	var center_q := roundi(approximate_q)
	var center_r := roundi(approximate_r)
	var closest_key := ""
	var closest_distance_squared := INF
	for q in range(center_q - 1, center_q + 2):
		for r in range(center_r - 1, center_r + 2):
			var key := _step_grid_key(Vector2i(q, r))
			if not step_grid_points.has(key):
				continue
			var candidate := Vector2(q * STEP_GRID_SPACING + r * STEP_GRID_SPACING * 0.5, r * STEP_GRID_ROW_HEIGHT)
			var distance_squared := relative_position.distance_squared_to(candidate)
			if distance_squared < closest_distance_squared:
				closest_distance_squared = distance_squared
				closest_key = key
	if closest_key.is_empty():
		return 1.0
	var steps := clampf(float(step_counts.get(closest_key, 0)) / STEP_GRID_MAX_COUNT, 0.0, 1.0)
	return 1.0 - 0.75 * (1.0 - steps)


func route_waypoints_for(ant: AntParticle, start_position: Vector2, target: Vector2) -> Array[Vector2]:
	var route: Array[Vector2] = []
	if not is_worker_group_leader(ant):
		return route
	if step_counts.is_empty() or step_grid_points.is_empty():
		return route
	var start_coordinate := _nearest_step_coordinate(start_position)
	var goal_coordinate := _nearest_step_coordinate(target)
	if start_coordinate == goal_coordinate:
		return route
	var start_key := _step_grid_key(start_coordinate)
	var goal_key := _step_grid_key(goal_coordinate)
	var open_keys: Array[String] = [start_key]
	var came_from: Dictionary = {}
	var cost_so_far: Dictionary = {start_key: 0.0}
	var finished: Dictionary = {}
	while not open_keys.is_empty():
		var best_index := 0
		var best_score := INF
		for index in range(open_keys.size()):
			var candidate_key := open_keys[index]
			var candidate_coordinate: Vector2i = step_grid_points.get(candidate_key, Vector2i.ZERO)
			var candidate_position := _step_grid_position(candidate_coordinate)
			var score: float = float(cost_so_far[candidate_key]) + candidate_position.distance_to(_step_grid_position(goal_coordinate))
			if score < best_score:
				best_score = score
				best_index = index
		var current_key := open_keys.pop_at(best_index)
		if current_key == goal_key:
			break
		if finished.has(current_key):
			continue
		finished[current_key] = true
		var current_coordinate: Vector2i = step_grid_points[current_key]
		for neighbor_offset in STEP_GRID_NEIGHBORS:
			var neighbor_coordinate: Vector2i = current_coordinate + neighbor_offset
			var neighbor_key := _step_grid_key(neighbor_coordinate)
			if not step_grid_points.has(neighbor_key) or finished.has(neighbor_key):
				continue
			var current_heat := float(step_counts.get(current_key, 0)) / float(STEP_GRID_MAX_COUNT)
			var neighbor_heat := float(step_counts.get(neighbor_key, 0)) / float(STEP_GRID_MAX_COUNT)
			var current_resistance := 1.0 / (0.25 + 0.75 * current_heat)
			var neighbor_resistance := 1.0 / (0.25 + 0.75 * neighbor_heat)
			var edge_cost := STEP_GRID_SPACING * (current_resistance + neighbor_resistance) * 0.5
			var next_cost: float = float(cost_so_far[current_key]) + edge_cost
			if not cost_so_far.has(neighbor_key) or next_cost < float(cost_so_far[neighbor_key]):
				cost_so_far[neighbor_key] = next_cost
				came_from[neighbor_key] = current_key
				if not open_keys.has(neighbor_key):
					open_keys.append(neighbor_key)
	if not came_from.has(goal_key):
		return route
	var start_point := _step_grid_position(start_coordinate)
	if start_position.distance_to(start_point) > 1.0:
		route.append(start_point)
	var reverse_keys: Array[String] = []
	var cursor := goal_key
	while cursor != start_key:
		reverse_keys.append(cursor)
		cursor = str(came_from[cursor])
	reverse_keys.reverse()
	for key in reverse_keys:
		route.append(_step_grid_position(step_grid_points[key]))
	if route.is_empty() or route[route.size() - 1].distance_to(target) > 1.0:
		route.append(target)
	else:
		route[route.size() - 1] = target
	return route


func is_worker_group_leader(ant: AntParticle) -> bool:
	for group_state in worker_groups:
		var group_ants: Array = group_state["ants"]
		if not group_ants.is_empty() and group_ants[0] == ant:
			return true
	return false


func _nearest_step_coordinate(position_to_check: Vector2) -> Vector2i:
	var nearest := Vector2i.ZERO
	var nearest_distance_squared := INF
	for key in step_grid_points:
		var coordinate: Vector2i = step_grid_points[key]
		var distance_squared := position_to_check.distance_squared_to(_step_grid_position(coordinate))
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest = coordinate
	return nearest


func _step_grid_position(coordinate: Vector2i) -> Vector2:
	return QUEEN_SPAWN_POSITION + Vector2(coordinate.x * STEP_GRID_SPACING + coordinate.y * STEP_GRID_SPACING * 0.5, coordinate.y * STEP_GRID_ROW_HEIGHT)


func _step_grid_key(coordinate: Vector2i) -> String:
	return "%d,%d" % [coordinate.x, coordinate.y]


func _step_grid_coordinate(key: String) -> Variant:
	var parts := key.split(",")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return null
	return Vector2i(int(parts[0]), int(parts[1]))


func _digging_ants() -> Array[AntParticle]:
	var result: Array[AntParticle] = []
	for ant_node in get_tree().get_nodes_in_group("ants"):
		if ant_node is AntParticle:
			var ant := ant_node as AntParticle
			if ant.can_dig and ant.get_parent() == self:
				result.append(ant)
	return result


func _spawn_colonies() -> void:
	var workers_to_spawn := GameState.saved_worker_amount if GameState.has_saved_game else (WORKER_COUNT if spawn_workers else 0)
	var saved_queen_count := mini(GameState.saved_queen_amount, 10) if not queen_ant_mode else GameState.saved_queen_amount
	var queens_to_spawn := saved_queen_count if GameState.has_saved_game else QUEEN_COUNT
	var warriors_to_spawn := GameState.saved_warrior_amount if GameState.has_saved_game else (WARRIOR_COUNT if spawn_warriors else 0)
	for _index in range(queens_to_spawn):
		var queen := _create_ant(AntParticle.AntType.QUEEN)
		queen.position = QUEEN_SPAWN_POSITION
		queen_ants.append(queen)
	for _index in range(workers_to_spawn):
		_register_worker(_create_ant(AntParticle.AntType.WORKER))
	for index in range(warriors_to_spawn):
		var health := _warrior_max_health()
		if index < GameState.saved_warrior_health.size():
			health = clampi(int(GameState.saved_warrior_health[index]), 1, _warrior_max_health())
		_spawn_warrior(health)
	_set_idle_queens()
	GameState.queen_count = queen_ants.size()
	GameState.worker_count = worker_ants.size()
	GameState.warrior_count = warrior_ants.size()


func _create_ant(ant_type) -> AntParticle:
	var ant := ANT_SCENE.instantiate() as AntParticle
	ant.ant_type = ant_type
	match ant_type:
		AntParticle.AntType.QUEEN:
			ant.z_index = QUEEN_Z_INDEX
		AntParticle.AntType.WARRIOR:
			ant.z_index = WARRIOR_Z_INDEX
		AntParticle.AntType.WORKER:
			ant.z_index = WORKER_Z_INDEX
	ant.can_dig = ant_type == AntParticle.AntType.WORKER
	ant.move_speed = _move_speed_for_type(ant_type)
	if ant_type == AntParticle.AntType.WORKER and super_food_speed_remaining > 0.0:
		ant.move_speed *= SUPER_FOOD_SPEED_MULTIPLIER
	add_child(ant)
	return ant


func _move_speed_for_type(ant_type) -> float:
	var speed_multiplier := minf(2.0, pow(1.1, GameState.inc1_speed_level)) if not queen_ant_mode else pow(1.1, GameState.speed_level)
	if ant_type == AntParticle.AntType.WARRIOR:
		speed_multiplier *= pow(1.1, GameState.warrior_training_level)
	return ant_speed * speed_multiplier


func _update_super_food_speed(delta: float) -> void:
	if super_food_speed_remaining <= 0.0:
		return
	super_food_speed_remaining = maxf(0.0, super_food_speed_remaining - delta)
	if super_food_speed_remaining > 0.0:
		return
	for ant in worker_ants:
		if is_instance_valid(ant) and not ant.is_dead:
			ant.move_speed = _base_worker_move_speed()


func _base_worker_move_speed() -> float:
	var speed_multiplier := minf(2.0, pow(1.1, GameState.inc1_speed_level)) if not queen_ant_mode else pow(1.1, GameState.speed_level)
	return ant_speed * speed_multiplier


func _spawn_super_food(source: Node2D) -> void:
	var super_food := SUPER_FOOD_SCENE.instantiate() as Area2D
	add_child(super_food)
	super_food.position = to_local(source.global_position)
	super_food.collected.connect(_on_super_food_collected)


func _on_super_food_collected() -> void:
	if super_food_speed_remaining <= 0.0:
		for ant in worker_ants:
			if is_instance_valid(ant) and not ant.is_dead:
				ant.move_speed *= SUPER_FOOD_SPEED_MULTIPLIER
	super_food_speed_remaining = SUPER_FOOD_SPEED_DURATION


func _register_worker(ant: AntParticle) -> void:
	if not is_instance_valid(ant) or ant.is_dead:
		return
	if queen_ant_mode:
		ant.lifetime_remaining = 30.0 + 10.0 * GameState.worker_lifetime_level
	ant.position = to_local(_random_queen_drop_position())
	ant.heading = Vector2.RIGHT.rotated(random.randf_range(0.0, TAU))
	ant.idle_anchor = ant.position
	ant.rotation = ant.heading.angle() - PI * 0.5
	worker_ants.append(ant)
	_rebalance_worker_groups()
	var group_state := _group_for_new_worker(ant.global_position)
	if group_state.is_empty():
		ant.set_state(AntParticle.State.idle)
		ant.idle_anchor = ant.position
		_assign_idle_target(ant)
		return
	_attach_worker_to_group(ant, group_state)


func _group_for_new_worker(spawn_position: Vector2, create_if_missing: bool = true) -> Dictionary:
	var desired_group_count := mini(queen_ants.size(), worker_ants.size())
	if create_if_missing and desired_group_count > 0 and _active_worker_group_count() < desired_group_count:
		return _create_worker_group()
	var nearest_group: Dictionary = {}
	var nearest_distance := 0.0
	var smallest_group_size := 2147483647
	for candidate in worker_groups:
		var group_state: Dictionary = candidate
		_prune_dead_workers_from_group(group_state)
		var group_ants: Array = group_state["ants"]
		if group_state["phase"] in ["orphan_return", "waiting"] or group_ants.is_empty():
			continue
		var leader := group_ants[0] as AntParticle
		var distance := spawn_position.distance_to(leader.global_position)
		if group_ants.size() < smallest_group_size or (group_ants.size() == smallest_group_size and (nearest_group.is_empty() or distance < nearest_distance)):
			smallest_group_size = group_ants.size()
			nearest_distance = distance
			nearest_group = group_state
	if not nearest_group.is_empty():
		return nearest_group
	return {}


func _active_worker_group_count() -> int:
	var count := 0
	for group_state in worker_groups:
		if group_state["phase"] != "orphan_return" and not group_state["ants"].is_empty():
			count += 1
	return count


func _create_worker_group() -> Dictionary:
	var group_state: Dictionary = {
		"ants": [],
		"destination": QUEEN_SPAWN_POSITION,
		"return_positions": [],
		"food_source": null,
		"phase": "searching",
	}
	worker_groups.append(group_state)
	return group_state


func _split_largest_worker_group() -> void:
	_rebalance_worker_groups()


func _rebalance_worker_groups() -> void:
	var eligible_worker_count := 0
	for group_state in worker_groups:
		_prune_dead_workers_from_group(group_state)
		if group_state["phase"] != "orphan_return":
			eligible_worker_count += group_state["ants"].size()
	var target_group_count := mini(queen_ants.size(), eligible_worker_count)
	if target_group_count <= 0:
		return

	while _active_worker_group_count() < target_group_count:
		var largest_group: Dictionary = {}
		var largest_size := 1
		for candidate in worker_groups:
			var group_state: Dictionary = candidate
			if group_state["phase"] == "orphan_return":
				continue
			var group_ants: Array = group_state["ants"]
			if group_ants.size() > largest_size:
				largest_size = group_ants.size()
				largest_group = group_state
		if largest_group.is_empty():
			break
		var new_group := _create_worker_group()
		new_group["phase"] = largest_group["phase"]
		new_group["destination"] = largest_group["destination"]
		new_group["food_source"] = largest_group["food_source"]
		var original_ants: Array = largest_group["ants"]
		var split_count := int(floor(float(original_ants.size()) / 2.0))
		for _index in range(split_count):
			new_group["ants"].append(original_ants.pop_back())
		if new_group["phase"] == "returning":
			_assign_return_positions(new_group, new_group["destination"])
			for ant in new_group["ants"]:
				ant.has_reached_destination = false
				ant.set_state(AntParticle.State.walking)

	while _active_worker_group_count() > target_group_count:
		var smallest_group: Dictionary = {}
		var smallest_size := 2147483647
		for candidate in worker_groups:
			var group_state: Dictionary = candidate
			if group_state["phase"] == "orphan_return":
				continue
			var group_ants: Array = group_state["ants"]
			if not group_ants.is_empty() and group_ants.size() < smallest_size:
				smallest_size = group_ants.size()
				smallest_group = group_state
		if smallest_group.is_empty():
			break
		var destination_group := _least_populated_worker_group(smallest_group)
		if destination_group.is_empty():
			break
		var moving_ant: AntParticle = smallest_group["ants"].pop_back()
		_attach_worker_to_group(moving_ant, destination_group)
		if smallest_group["ants"].is_empty():
			worker_groups.erase(smallest_group)

	while true:
		var largest_group: Dictionary = {}
		var largest_size := 0
		var smallest_group: Dictionary = {}
		var smallest_size := 2147483647
		for candidate in worker_groups:
			var group_state: Dictionary = candidate
			if group_state["phase"] == "orphan_return" or group_state["ants"].is_empty():
				continue
			var group_size: int = group_state["ants"].size()
			if group_size > largest_size:
				largest_group = group_state
				largest_size = group_size
			if group_size < smallest_size:
				smallest_group = group_state
				smallest_size = group_size
		if largest_group.is_empty() or largest_size - smallest_size <= 1:
			break
		var moving_ant: AntParticle = largest_group["ants"].pop_back()
		_attach_worker_to_group(moving_ant, smallest_group)

	for group_state in worker_groups:
		if group_state["phase"] == "waiting":
			_start_worker_group_foraging(group_state)


func _least_populated_worker_group(exclude: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	var smallest_size := 2147483647
	for candidate in worker_groups:
		var group_state: Dictionary = candidate
		if group_state == exclude or group_state["phase"] == "orphan_return":
			continue
		var group_ants: Array = group_state["ants"]
		if group_ants.size() < smallest_size:
			smallest_size = group_ants.size()
			result = group_state
	return result


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
		elif was_leader and group_state["phase"] in ["outbound", "scouting", "gathering", "returning"]:
			var new_leader := group_ants[0] as AntParticle
			# Resume the trip with the promoted leader, even if the former leader
			# expired before reaching its destination.
			new_leader.has_reached_destination = false
			new_leader.set_target(group_state["destination"])
			new_leader.set_state(AntParticle.State.walking)
		break
	ant.mark_dead()
	_rebalance_worker_groups()
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
	_prune_dead_workers_from_group(group_state)
	var group_ants: Array = group_state["ants"]
	if group_ants.is_empty():
		return
	if group_state["phase"] == "waiting":
		group_state["phase"] = "searching"
	var leader := group_ants[0] as AntParticle
	var source := _nearest_food_source(leader.global_position, group_state)
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
		ant.scatter_started_this_trip = false
		ant.gathered_this_trip = false
		ant.set_state(AntParticle.State.walking)


func _prune_dead_workers_from_group(group_state: Dictionary) -> void:
	var group_ants: Array = group_state["ants"]
	var old_leader: AntParticle = group_ants[0] if not group_ants.is_empty() else null
	for member in group_ants.duplicate():
		var ant := member as AntParticle
		if not is_instance_valid(ant) or ant.is_dead or not worker_ants.has(ant):
			group_ants.erase(member)
			if is_instance_valid(ant):
				worker_ants.erase(ant)
	if group_ants.is_empty():
		group_state["phase"] = "searching"
		group_state["food_source"] = null
		return
	var leader := group_ants[0] as AntParticle
	if leader == old_leader:
		return
	if group_state["phase"] in ["outbound", "scouting", "gathering"]:
		leader.has_reached_destination = false
		leader.set_target(group_state["destination"])
		leader.set_state(AntParticle.State.walking)
	elif group_state["phase"] == "returning":
		_assign_return_positions(group_state, group_state["destination"])
		for ant in group_ants:
			ant.has_reached_destination = false
			ant.set_state(AntParticle.State.walking)


func _update_worker_groups(delta: float) -> void:
	for group_state in worker_groups.duplicate():
		_prune_dead_workers_from_group(group_state)
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


func _update_idle_workers() -> void:
	for ant in worker_ants:
		if ant.is_dead or ant.state != AntParticle.State.idle:
			continue
		# Reconcile idle workers with a nearby active leader. If none is close,
		# form a new group so the worker can resume foraging on its own.
		var current_group: Dictionary = {}
		for candidate in worker_groups:
			var candidate_ants: Array = candidate["ants"]
			if candidate_ants.has(ant):
				current_group = candidate
				break
		if not current_group.is_empty() and current_group["phase"] == "waiting":
			_start_worker_group_foraging(current_group)
			continue
		if not current_group.is_empty():
			var current_ants: Array = current_group["ants"]
			current_ants.erase(ant)
			if current_ants.is_empty():
				worker_groups.erase(current_group)
		var leader_group := _group_for_new_worker(ant.global_position)
		if leader_group.is_empty():
			ant.set_state(AntParticle.State.idle)
			continue
		var destination_group := leader_group
		ant.has_reached_destination = false
		ant.scatter_started_this_trip = false
		ant.gathered_this_trip = false
		_attach_worker_to_group(ant, destination_group)


func _update_group_travel(group_state: Dictionary, delta: float) -> void:
	var group_ants: Array = group_state["ants"]
	var source: Node2D
	if is_instance_valid(group_state["food_source"]):
		source = group_state["food_source"]
	if group_state["phase"] == "outbound" and source == null:
		_start_worker_group_foraging(group_state)
		return
	if source != null:
		group_state["destination"] = to_local(source.global_position)
	var destination: Vector2 = group_state["destination"]
	_move_group_in_formation(group_state, destination, delta)
	if group_state["phase"] == "scouting":
		if not _all_group_ants_arrived(group_ants):
			return
		_start_worker_group_foraging(group_state)
		return
	var leader := group_ants[0] as AntParticle
	if not leader.has_reached_destination:
		return
	group_state["phase"] = "gathering"
	for ant in group_ants:
		if ant.has_reached_destination and not ant.scatter_started_this_trip and is_instance_valid(source):
			_assign_gathering_target(ant, source)


func _assign_gathering_target(ant: AntParticle, source: Node2D) -> void:
	var source_radius := source.global_scale.x
	var angle := random.randf_range(0.0, TAU)
	var radius := sqrt(random.randf()) * (source_radius + 1.0)
	var scatter_point := source.global_position + Vector2.RIGHT.rotated(angle) * radius
	ant.gathered_this_trip = false
	ant.scatter_started_this_trip = true
	ant.food_gather_remaining = 0.0
	ant.set_target(to_local(scatter_point))
	ant.set_state(AntParticle.State.walking)


func _assign_return_positions(group_state: Dictionary, center: Vector2) -> void:
	var group_ants: Array = group_state["ants"]
	var slots: Array[Vector2] = []
	var spread_radius := maxf(QUEEN_DROP_HALF_SIZE, sqrt(float(group_ants.size())) * STOCKPILE_SLOT_SPACING)
	for index in range(group_ants.size()):
		var slot := center
		var found_spaced_slot := false
		for _attempt in range(24):
			var angle := random.randf_range(0.0, TAU)
			var radius := sqrt(random.randf()) * spread_radius
			var candidate := center + Vector2.RIGHT.rotated(angle) * radius
			var spaced_from_existing := true
			for existing_slot in slots:
				if candidate.distance_to(existing_slot) < STOCKPILE_SLOT_SPACING:
					spaced_from_existing = false
					break
			if spaced_from_existing:
				slot = candidate
				found_spaced_slot = true
				break
		if not found_spaced_slot:
			var angle := random.randf_range(0.0, TAU)
			var radius := sqrt(random.randf()) * spread_radius
			slot = center + Vector2.RIGHT.rotated(angle) * radius
		slots.append(slot)
	if not slots.is_empty():
		var leader_slot_index := 0
		for index in range(1, slots.size()):
			if slots[index].distance_squared_to(center) < slots[leader_slot_index].distance_squared_to(center):
				leader_slot_index = index
		var leader_slot := slots[leader_slot_index]
		slots[leader_slot_index] = slots[0]
		slots[0] = leader_slot
	group_state["return_positions"] = slots.slice(0, group_ants.size())
	group_state["destination"] = center
	for ant in group_ants:
		(ant as AntParticle).food_gather_remaining = 0.0


func _move_group_to_return_positions(group_state: Dictionary, delta: float) -> void:
	var group_ants: Array = group_state["ants"]
	var return_positions: Array = group_state["return_positions"]
	if return_positions.size() != group_ants.size():
		_assign_return_positions(group_state, group_state["destination"])
		return_positions = group_state["return_positions"]
	for index in range(group_ants.size()):
		var ant := group_ants[index] as AntParticle
		if ant.has_reached_destination:
			_update_stockpile_resting(ant, return_positions[index], delta)
			continue
		var target: Vector2 = return_positions[index]
		var following_leader := false
		if index > 0:
			var predecessor := group_ants[index - 1] as AntParticle
			if not predecessor.has_reached_destination:
				target = predecessor.position - predecessor.heading * FOLLOW_DISTANCE
				following_leader = true
		ant.set_target(target)
		ant.set_state(AntParticle.State.walking)
		ant.move_step(delta)
		if not following_leader and ant.position.distance_to(return_positions[index]) <= ARRIVAL_TOLERANCE:
			ant.position = return_positions[index]
			ant.has_reached_destination = true
			ant.idle_anchor = return_positions[index]
			ant.food_gather_remaining = 0.0
			GameState.add_food(ant.carried_food)
			ant.carried_food = 0
			ant.is_returning_food = false


func _update_stockpile_resting(ant: AntParticle, anchor: Vector2, delta: float) -> void:
	ant.set_state(AntParticle.State.walking)
	if ant.food_gather_remaining > 0.0:
		ant.food_gather_remaining = maxf(0.0, ant.food_gather_remaining - delta)
		return
	if ant.is_at_target(ARRIVAL_TOLERANCE):
		var angle := random.randf_range(0.0, TAU)
		var radius := sqrt(random.randf()) * 3.0
		ant.set_target(anchor + Vector2.RIGHT.rotated(angle) * radius)
		ant.food_gather_remaining = random.randf_range(0.2, 0.8)
		return
	ant.move_step(delta)


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
	if is_instance_valid(source):
		_move_group_in_formation(group_state, to_local(source.global_position), delta)
	for ant in group_ants:
		if ant.gathered_this_trip:
			continue
		if not is_instance_valid(source):
			ant.gathered_this_trip = true
			continue
		if ant.has_reached_destination and not ant.scatter_started_this_trip:
			_assign_gathering_target(ant, source)
			continue
		if not ant.scatter_started_this_trip:
			continue
		ant.move_step(delta)
		if ant.position.distance_to(ant.target_position) > ARRIVAL_TOLERANCE:
			continue
		ant.position = ant.target_position
		var carry_bonus := GameState.carry_capacity_level if queen_ant_mode else GameState.inc1_carry_total
		ant.carried_food += int(source.call("harvest", food_per_ant_per_trip + carry_bonus))
		ant.gathered_this_trip = true
		var gathering_multiplier := pow(0.9, GameState.inc1_gathering_time_level) if not queen_ant_mode else 1.0
		ant.food_gather_remaining = food_gather_pause_duration * gathering_multiplier
		ant.set_state(AntParticle.State.gathering)
	for ant in group_ants:
		if ant.gathered_this_trip and ant.food_gather_remaining > 0.0:
			ant.food_gather_remaining = maxf(0.0, ant.food_gather_remaining - delta)
	var group_ready_to_return := true
	for ant in group_ants:
		if not ant.gathered_this_trip or ant.food_gather_remaining > 0.0:
			group_ready_to_return = false
			break
	if group_ready_to_return:
		# Keep the cluster together: wait until every ant has finished gathering,
		# then return and resume foraging as one leader-led group.
		group_state["phase"] = "returning"
		_assign_return_positions(group_state, to_local(_random_queen_drop_position()))
		for ant in group_ants:
			ant.has_reached_destination = false
			ant.scatter_started_this_trip = false
			ant.set_state(AntParticle.State.walking)


func _update_group_return(group_state: Dictionary, delta: float) -> void:
	var group_ants: Array = group_state["ants"]
	_move_group_to_return_positions(group_state, delta)
	if not _all_group_ants_arrived(group_ants):
		return
	for ant in group_ants:
		ant.gathered_this_trip = false
		ant.has_reached_destination = false
	group_state["food_source"] = null
	_start_worker_group_foraging(group_state)


func _update_orphan_return(group_state: Dictionary, delta: float) -> void:
	var group_ants: Array = group_state["ants"]
	_move_group_to_return_positions(group_state, delta)
	if not _all_group_ants_arrived(group_ants):
		return
	var ant := group_ants[0] as AntParticle
	worker_groups.erase(group_state)
	group_ants.clear()
	_reassign_worker_after_source_depletion(ant)


func _nearest_food_source(origin: Vector2, requesting_group: Dictionary) -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("food_polygons"):
		var source := candidate as Node2D
		if source == null or int(source.get("food_remaining")) <= 0:
			continue
		var claimed_by_another_group := false
		for other_candidate in worker_groups:
			var other_group: Dictionary = other_candidate
			if other_group == requesting_group or other_group["phase"] not in ["outbound", "gathering"]:
				continue
			if other_group["food_source"] == source:
				claimed_by_another_group = true
				break
		if claimed_by_another_group:
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


func _draw_colony_boundary() -> void:
	var boundary := Polygon2D.new()
	var vertices := PackedVector2Array()
	var segments: Array[PackedInt32Array] = []
	const SEGMENT_COUNT: int = 64
	for index in range(SEGMENT_COUNT):
		var direction := Vector2.RIGHT.rotated(TAU * index / SEGMENT_COUNT)
		vertices.append(direction * COLONY_RADIUS)
		vertices.append(direction * (COLONY_RADIUS - 1.0))
		var next := (index + 1) % SEGMENT_COUNT
		segments.append(PackedInt32Array([index * 2, next * 2, next * 2 + 1, index * 2 + 1]))
	boundary.polygon = vertices
	boundary.polygons = segments
	boundary.position = QUEEN_SPAWN_POSITION
	boundary.color = Color(0.45, 0.7, 0.85, 0.45)
	boundary.z_index = -2
	add_child(boundary)


func _spawn_warrior(health: int) -> void:
	var warrior := _create_ant(AntParticle.AntType.WARRIOR)
	warrior.position = QUEEN_SPAWN_POSITION
	warrior.combat_health = health
	warrior.set_state(AntParticle.State.walking)
	warrior_ants.append(warrior)
	_choose_warrior_destination(warrior)


func _warrior_max_health() -> int:
	return WARRIOR_HEALTH + WARRIOR_HEALTH_PER_ENDURANCE_LEVEL * GameState.warrior_endurance_level


func _choose_warrior_destination(warrior: AntParticle) -> void:
	var saturated_points := _saturated_step_points()
	var warrior_id := warrior.get_instance_id()
	if saturated_points.is_empty():
		warrior_post_positions.erase(warrior_id)
		warrior.set_target(warrior.position)
		return
	var post_position: Vector2 = saturated_points[random.randi_range(0, saturated_points.size() - 1)]
	warrior_post_positions[warrior_id] = post_position
	var angle := random.randf_range(0.0, TAU)
	var radius := sqrt(random.randf()) * WARRIOR_POST_WANDER_RADIUS
	warrior.set_target(post_position + Vector2.RIGHT.rotated(angle) * radius)


func _saturated_step_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for key in step_counts:
		if int(step_counts[key]) < STEP_GRID_MAX_COUNT:
			continue
		var coordinate: Vector2i = step_grid_points.get(key, Vector2i.ZERO)
		points.append(QUEEN_SPAWN_POSITION + Vector2(coordinate.x * STEP_GRID_SPACING + coordinate.y * STEP_GRID_SPACING * 0.5, coordinate.y * STEP_GRID_ROW_HEIGHT))
	return points


func _update_warriors(delta: float) -> void:
	var saturated_points := _saturated_step_points()
	for warrior in warrior_ants.duplicate():
		warrior.attack_cooldown = maxf(0.0, warrior.attack_cooldown - delta)
		var warrior_id: int = warrior.get_instance_id()
		if saturated_points.is_empty():
			warrior_post_positions.erase(warrior_id)
			warrior.set_target(warrior.position)
			continue
		if not warrior_post_positions.has(warrior_id):
			_choose_warrior_destination(warrior)
		var post_position: Vector2 = warrior_post_positions.get(warrior_id, warrior.position)
		if worm != null and worm.position.distance_to(post_position) <= WARRIOR_DEFENSE_RADIUS:
			warrior.set_target(worm.position)
			if not warrior.is_at_target(ATTACK_RANGE):
				warrior.move_step(delta)
			if not warrior.is_at_target(ATTACK_RANGE) or warrior.attack_cooldown > 0.0:
				continue

			warrior.attack_cooldown = ATTACK_INTERVAL
			warrior.combat_health -= 1
			worm_health -= WARRIOR_DAMAGE + GameState.warrior_damage_level
			if worm_health <= 0:
				_drop_worm_food()
			if warrior.combat_health <= 0:
				warrior_ants.erase(warrior)
				warrior_post_positions.erase(warrior_id)
				warrior.queue_free()
				GameState.warrior_count = warrior_ants.size()
				GameState.economy_changed.emit()
			save_colony()
			continue

		warrior.set_target(post_position)
		warrior.move_step(delta)
		if warrior.is_at_target(ARRIVAL_TOLERANCE):
			_choose_warrior_destination(warrior)


func _schedule_worm() -> void:
	worm_spawn_remaining = random.randf_range(12.0, 20.0)


func _update_worm_spawn(delta: float) -> void:
	if worm != null:
		worm.position += worm_travel_direction * WORM_SPEED * delta
		if (worm.position - worm_exit_position).dot(worm_travel_direction) >= 0.0:
			worm.position = worm_exit_position
			worm.queue_free()
			worm = null
			_schedule_worm()
		return
	worm_spawn_remaining -= delta
	if worm_spawn_remaining > 0.0:
		return

	worm = Polygon2D.new()
	worm.polygon = PackedVector2Array([
		Vector2(-9, 0), Vector2(-7, -3), Vector2(-3, -4), Vector2(1, -2),
		Vector2(5, -3), Vector2(9, -1), Vector2(9, 2), Vector2(5, 4),
		Vector2(1, 2), Vector2(-3, 1), Vector2(-7, 3),
	])
	worm.color = Color(0.66, 0.42, 0.75)
	var travel_angle := random.randf_range(0.0, TAU)
	worm_travel_direction = Vector2.RIGHT.rotated(travel_angle)
	var perpendicular := worm_travel_direction.orthogonal()
	var lane_offset := random.randf_range(-COLONY_RADIUS * WORM_LANE_OFFSET_FRACTION, COLONY_RADIUS * WORM_LANE_OFFSET_FRACTION)
	var half_chord := sqrt(COLONY_RADIUS * COLONY_RADIUS - lane_offset * lane_offset)
	var center_position := QUEEN_SPAWN_POSITION + perpendicular * lane_offset
	worm.position = center_position - worm_travel_direction * (half_chord + WORM_SPAWN_MARGIN)
	worm_exit_position = center_position + worm_travel_direction * (half_chord + WORM_SPAWN_MARGIN)
	worm.rotation = travel_angle
	worm_health = WORM_HEALTH
	add_child(worm)


func _drop_worm_food() -> void:
	for index in range(WORM_DROP_COUNT):
		var offset := (float(index) - (WORM_DROP_COUNT - 1) * 0.5) * WORM_DROP_SPACING
		var drop_position := worm.to_global(Vector2(offset, 0.0))
		var drop := FOOD_DROP_SCENE.instantiate() as Polygon2D
		food_sources_container.add_child(drop)
		drop.position = food_sources_container.to_local(drop_position)
		drop.call("initialize", WORM_DROP_FOOD, Color(0.95, 0.16, 0.20), 2.0)
		drop.add_to_group("food_polygons")
		drop.connect("depleted", _redirect_workers_from_depleted_source)

	worm.queue_free()
	worm = null
	_schedule_worm()


func purchase_warrior() -> bool:
	if queen_ants.size() < 4:
		return false
	if not GameState.spend_food(WARRIOR_COST):
		return false
	_spawn_warrior(_warrior_max_health())
	GameState.warrior_count = warrior_ants.size()
	GameState.economy_changed.emit()
	return true


func save_colony() -> void:
	var warrior_health: Array[int] = []
	for warrior in warrior_ants:
		warrior_health.append(warrior.combat_health)
	GameState.save_game(queen_ants.size(), worker_ants.size(), warrior_ants.size(), warrior_health, step_counts, step_grid_colliders, worker_trail_overlay.saved_paint_state())


func _assign_idle_target(ant: AntParticle) -> void:
	var angle := random.randf_range(0.0, TAU)
	var radius := sqrt(random.randf()) * 10.0
	ant.set_target(ant.idle_anchor + Vector2.RIGHT.rotated(angle) * radius)


func _spawn_initial_food_sources() -> void:
	var source_count := active_food_source_count if queen_ant_mode else 1 + GameState.inc1_source_amount_level
	for _index in range(source_count):
		_spawn_food_source()


func _spawn_food_source() -> void:
	var source := FOOD_SOURCE_SCENE.instantiate() as Node2D
	if queen_ant_mode:
		source.call("initialize", random, 1.0 + 0.25 * GameState.food_efficiency_level, 0)
	else:
		source.call("initialize", random, 1.0, GameState.inc1_source_size_level * 25)
	var source_radius: float = source.scale.x
	for _attempt in range(FOOD_SOURCE_POSITION_ATTEMPTS):
		var angle := random.randf_range(0.0, TAU)
		var radius := random.randf_range(food_search_range * 0.45, food_search_range)
		var candidate := Vector2.RIGHT.rotated(angle) * radius
		if _is_food_source_position_allowed(candidate, source_radius):
			source.position = candidate
			source.connect("depleted", _on_food_source_depleted)
			food_sources_container.add_child(source)
			return
	push_warning("Could not find a food source position clear of fully stepped grid points.")
	source.free()


func _is_food_source_position_allowed(candidate: Vector2, source_radius: float) -> bool:
	var exclusion_radius := STEP_GRID_STEP_RADIUS + source_radius + SATURATED_POINT_FOOD_CLEARANCE
	for key in step_counts:
		if int(step_counts[key]) < STEP_GRID_MAX_COUNT:
			continue
		var coordinate: Vector2i = step_grid_points.get(key, Vector2i.ZERO)
		var point := QUEEN_SPAWN_POSITION + Vector2(coordinate.x * STEP_GRID_SPACING + coordinate.y * STEP_GRID_SPACING * 0.5, coordinate.y * STEP_GRID_ROW_HEIGHT)
		if candidate.distance_to(point) < exclusion_radius:
			return false
	return true


func _on_food_source_depleted(source: Node2D) -> void:
	if random.randi_range(1, SUPER_FOOD_DROP_CHANCE_OUT_OF) <= SUPER_FOOD_DROP_CHANCE_IN:
		_spawn_super_food(source)
	_spawn_food_source()
	_redirect_workers_from_depleted_source(source)


func _redirect_workers_from_depleted_source(source: Node2D) -> void:
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
	_rebalance_worker_groups()


func _reassign_worker_after_source_depletion(ant: AntParticle) -> void:
	ant.has_reached_destination = false
	ant.scatter_started_this_trip = false
	ant.gathered_this_trip = false
	var group_state := _group_for_new_worker(ant.global_position)
	if group_state.is_empty():
		ant.set_state(AntParticle.State.idle)
		_assign_idle_target(ant)
		return
	_attach_worker_to_group(ant, group_state)


func _attach_worker_to_group(ant: AntParticle, group_state: Dictionary) -> void:
	var group_ants: Array = group_state["ants"]
	group_ants.append(ant)
	if group_ants.size() == 1:
		_start_worker_group_foraging(group_state)
		return
	match group_state["phase"]:
		"outbound", "scouting":
			ant.has_reached_destination = false
			ant.set_target(group_state["destination"])
			ant.set_state(AntParticle.State.walking)
		"returning":
			_assign_return_positions(group_state, group_state["destination"])
			for member in group_ants:
				member.has_reached_destination = false
				member.set_state(AntParticle.State.walking)
		"gathering":
			if ant.gathered_this_trip:
				ant.set_state(AntParticle.State.gathering)
			else:
				var current_source := group_state["food_source"] as Node2D
				if is_instance_valid(current_source):
					_assign_gathering_target(ant, current_source)
				else:
					_start_worker_group_foraging(group_state)
		"waiting":
			_start_worker_group_foraging(group_state)
		_:
			_start_worker_group_foraging(group_state)


func _return_worker_after_gather_source_depletion(ant: AntParticle) -> void:
	ant.has_reached_destination = false
	ant.scatter_started_this_trip = false
	ant.gathered_this_trip = false
	var leader_group := _group_for_new_worker(ant.global_position, false)
	if not leader_group.is_empty():
		_attach_worker_to_group(ant, leader_group)
		return
	var return_group := _create_worker_group()
	return_group["ants"].append(ant)
	return_group["phase"] = "orphan_return"
	_assign_return_positions(return_group, to_local(_random_queen_drop_position()))
	ant.has_reached_destination = false
	ant.set_state(AntParticle.State.walking)


func _on_food_drop_depleted(_drop: Node2D) -> void:
	return


func purchase_worker() -> bool:
	if queen_ant_mode:
		if not GameState.spend_food(GameState.worker_cost):
			return false
		GameState.worker_cost = GameState.next_cost(GameState.worker_cost, 1.25)
	else:
		if not GameState.spend_food(GameState.inc1_ant_cost):
			return false
		GameState.inc1_ant_cost = GameState.next_cost(GameState.inc1_ant_cost, 1.02)
	_register_worker(_create_ant(AntParticle.AntType.WORKER))
	worker_count_changed.emit(worker_ants.size())
	GameState.economy_changed.emit()
	return true


func purchase_queen() -> bool:
	if not queen_ant_mode:
		return purchase_upgrade("queen")
	if not GameState.spend_food(GameState.queen_cost):
		return false
		GameState.queen_cost = GameState.next_cost(GameState.queen_cost, 1.45)
	var queen := _create_ant(AntParticle.AntType.QUEEN)
	queen.position = QUEEN_SPAWN_POSITION
	queen_ants.append(queen)
	queen.set_state(AntParticle.State.idle)
	queen.idle_anchor = queen.position
	_assign_idle_target(queen)
	_rebalance_worker_groups()
	GameState.queen_count = queen_ants.size()
	GameState.economy_changed.emit()
	return true


func purchase_upgrade(upgrade: String) -> bool:
	if upgrade in ["warrior_damage", "warrior_endurance", "warrior_training"]:
		return _purchase_warrior_upgrade(upgrade)
	if not queen_ant_mode:
		return _purchase_incremental_upgrade(upgrade)
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
			GameState.queen_production_cost = GameState.next_cost(cost, 1.3)
		"carry_capacity":
			GameState.carry_capacity_level += 1
			GameState.carry_capacity_cost = GameState.next_cost(cost, 1.15)
		"speed":
			GameState.speed_level += 1
			GameState.speed_cost = GameState.next_cost(cost, 1.15)
			for ant in queen_ants + worker_ants + warrior_ants:
				ant.move_speed = _move_speed_for_type(ant.ant_type)
				if ant.ant_type == AntParticle.AntType.WORKER and super_food_speed_remaining > 0.0:
					ant.move_speed *= SUPER_FOOD_SPEED_MULTIPLIER
		"food_efficiency":
			GameState.food_efficiency_level += 1
			GameState.food_efficiency_cost = GameState.next_cost(cost, 1.3)
		"worker_lifetime":
			GameState.worker_lifetime_level += 1
			GameState.worker_lifetime_cost = GameState.next_cost(cost, 1.15)
	GameState.economy_changed.emit()
	return true


func _purchase_incremental_upgrade(upgrade: String) -> bool:
	var cost: int
	match upgrade:
		"carry_capacity": cost = GameState.inc1_carry_cost
		"speed": cost = GameState.inc1_speed_cost
		"food_source_size": cost = GameState.inc1_source_size_cost
		"queen": cost = GameState.inc1_queen_cost
		"food_source_amount": cost = GameState.inc1_source_amount_cost
		"gathering_time": cost = GameState.inc1_gathering_time_cost
		_: return false
	if upgrade == "queen" and queen_ants.size() >= 10:
		return false
	if upgrade == "food_source_amount" and (queen_ants.size() < 2 or 1 + GameState.inc1_source_amount_level >= 20):
		return false
	if upgrade == "speed" and minf(2.0, pow(1.1, GameState.inc1_speed_level)) >= 2.0:
		return false
	if upgrade == "gathering_time" and GameState.inc1_gathering_time_level >= 6:
		return false
	if not GameState.spend_food(cost):
		return false
	match upgrade:
		"carry_capacity":
			GameState.inc1_carry_level += 1
			GameState.inc1_carry_total += 1
			GameState.inc1_carry_cost = GameState.next_cost(cost, 1.35)
		"speed":
			GameState.inc1_speed_level += 1
			GameState.inc1_speed_cost = GameState.next_cost(cost, 1.35)
			for ant in queen_ants + worker_ants + warrior_ants:
				ant.move_speed = _move_speed_for_type(ant.ant_type)
				if ant.ant_type == AntParticle.AntType.WORKER and super_food_speed_remaining > 0.0:
					ant.move_speed *= SUPER_FOOD_SPEED_MULTIPLIER
		"food_source_size":
			GameState.inc1_source_size_level += 1
			GameState.inc1_source_size_cost = GameState.next_cost(cost, 1.6)
			for source in food_sources_container.get_children():
				source.call("increase_food_capacity", 25)
		"queen":
			var queen := _create_ant(AntParticle.AntType.QUEEN)
			queen.position = QUEEN_SPAWN_POSITION
			queen_ants.append(queen)
			queen.set_state(AntParticle.State.idle)
			queen.idle_anchor = queen.position
			_assign_idle_target(queen)
			GameState.inc1_queen_level = queen_ants.size() - 1
			GameState.queen_count = queen_ants.size()
			GameState.inc1_queen_cost = GameState.next_cost(cost, 1.5)
			_split_largest_worker_group()
		"food_source_amount":
			GameState.inc1_source_amount_level += 1
			GameState.inc1_source_amount_cost = GameState.next_cost(cost, 1.5)
			_spawn_food_source()
		"gathering_time":
			GameState.inc1_gathering_time_level += 1
			GameState.inc1_gathering_time_cost = GameState.next_cost(cost, 1.4)
	GameState.economy_changed.emit()
	return true


func _purchase_warrior_upgrade(upgrade: String) -> bool:
	if queen_ants.size() < 4:
		return false
	var cost: int
	match upgrade:
		"warrior_damage":
			if GameState.warrior_damage_level >= 4:
				return false
			cost = GameState.warrior_damage_cost
		"warrior_endurance":
			if GameState.warrior_endurance_level >= 5:
				return false
			cost = GameState.warrior_endurance_cost
		"warrior_training":
			if GameState.warrior_training_level >= 5:
				return false
			cost = GameState.warrior_training_cost
		_:
			return false
	if not GameState.spend_food(cost):
		return false
	match upgrade:
		"warrior_damage":
			GameState.warrior_damage_level += 1
			GameState.warrior_damage_cost = GameState.next_cost(cost, 1.5)
		"warrior_endurance":
			GameState.warrior_endurance_level += 1
			GameState.warrior_endurance_cost = GameState.next_cost(cost, 1.6)
			for warrior in warrior_ants:
				warrior.combat_health += WARRIOR_HEALTH_PER_ENDURANCE_LEVEL
		"warrior_training":
			GameState.warrior_training_level += 1
			GameState.warrior_training_cost = GameState.next_cost(cost, 1.7)
			for warrior in warrior_ants:
				warrior.move_speed = _move_speed_for_type(warrior.ant_type)
	GameState.economy_changed.emit()
	return true
