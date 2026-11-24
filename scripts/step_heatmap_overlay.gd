class_name StepHeatmapOverlay
extends Node2D

class TrailChunk:
	extends Node2D

	var cell_shades: Dictionary = {}
	var paint_cell_size: float = 1.0
	var paint_shade_max: int = 255


	func set_cell(cell: Vector2i, shade: int) -> void:
		if int(cell_shades.get(cell, -1)) == shade:
			return
		cell_shades[cell] = shade
		queue_redraw()


	func _draw() -> void:
		for cell: Vector2i in cell_shades:
			var gray := clampf(float(cell_shades[cell]) / float(paint_shade_max), 0.0, 1.0)
			var rect := Rect2(Vector2(cell) * paint_cell_size, Vector2.ONE * paint_cell_size)
			draw_rect(rect, Color(gray, gray, gray, 1.0))


const QUEEN_SPAWN_POSITION: Vector2 = Vector2(0.0, -32.0)
const STEP_GRID_SPACING: float = 15.0
const STEP_GRID_ROW_HEIGHT: float = 12.990381
const STEP_GRID_MAX_COUNT: int = 100
const STEP_GRID_DOT_RADIUS: float = 7.5
const STEP_GRID_LABEL_FONT_SIZE: int = 8
const PAINT_RADIUS: float = 5.0
const PAINT_CELL_SIZE: float = 1.0
const PAINT_SAMPLE_SPACING: float = 2.5
const LEGACY_PAINT_CELL_SIZE: float = 5.0
const PREVIOUS_PAINT_CELL_SIZE: float = 0.5
const PAINT_FORMAT_VERSION: int = 3
const TRAIL_CHUNK_CELLS: int = 32
const PAINT_DARK_GRAY: float = 0.15
const PAINT_LIGHT_GRAY: float = 0.65
const PAINT_SHADE_MAX: int = 255

var step_counts: Dictionary = {}
var step_grid_points: Dictionary = {}
var paint_shades: Dictionary = {}
var trail_chunks: Dictionary = {}
var debug_step_heatmap: bool = false
var draw_paint_trail: bool = true
var draw_step_heatmap: bool = true


func paint_worker_trail(from_position: Vector2, to_position: Vector2, current_step_counts: Dictionary, current_step_grid_points: Dictionary) -> void:
	var segment := to_position - from_position
	var sample_count := maxi(1, int(ceil(segment.length() / PAINT_SAMPLE_SPACING)))
	for sample_index in range(sample_count + 1):
		var dab_position := from_position + segment * (float(sample_index) / float(sample_count))
		var min_x := int(floor((dab_position.x - PAINT_RADIUS) / PAINT_CELL_SIZE))
		var max_x := int(floor((dab_position.x + PAINT_RADIUS) / PAINT_CELL_SIZE))
		var min_y := int(floor((dab_position.y - PAINT_RADIUS) / PAINT_CELL_SIZE))
		var max_y := int(floor((dab_position.y + PAINT_RADIUS) / PAINT_CELL_SIZE))
		for cell_x in range(min_x, max_x + 1):
			for cell_y in range(min_y, max_y + 1):
				var cell_center := Vector2((cell_x + 0.5) * PAINT_CELL_SIZE, (cell_y + 0.5) * PAINT_CELL_SIZE)
				if cell_center.distance_squared_to(dab_position) > PAINT_RADIUS * PAINT_RADIUS:
					continue
				var key := "%d,%d" % [cell_x, cell_y]
				if paint_shades.has(key):
					continue
				var heat := float(_heat_at(cell_center, current_step_counts, current_step_grid_points)) / float(STEP_GRID_MAX_COUNT)
				var shade := roundi(lerpf(PAINT_DARK_GRAY, PAINT_LIGHT_GRAY, heat) * PAINT_SHADE_MAX)
				paint_shades[key] = shade
				_set_trail_cell(cell_x, cell_y, shade)


func _heat_at(position_to_check: Vector2, current_step_counts: Dictionary, current_step_grid_points: Dictionary) -> int:
	var relative_position := position_to_check - QUEEN_SPAWN_POSITION
	var approximate_r := relative_position.y / STEP_GRID_ROW_HEIGHT
	var approximate_q := (relative_position.x - approximate_r * STEP_GRID_SPACING * 0.5) / STEP_GRID_SPACING
	var center_q := roundi(approximate_q)
	var center_r := roundi(approximate_r)
	var closest_key := ""
	var closest_distance_squared := INF
	for q in range(center_q - 1, center_q + 2):
		for r in range(center_r - 1, center_r + 2):
			var key := "%d,%d" % [q, r]
			if not current_step_grid_points.has(key):
				continue
			var point := Vector2(q * STEP_GRID_SPACING + r * STEP_GRID_SPACING * 0.5, r * STEP_GRID_ROW_HEIGHT)
			var distance_squared := relative_position.distance_squared_to(point)
			if distance_squared < closest_distance_squared:
				closest_distance_squared = distance_squared
				closest_key = key
	return clampi(int(current_step_counts.get(closest_key, 0)), 0, STEP_GRID_MAX_COUNT)


func load_paint_state(saved_paint_shades: Dictionary, format_version: int) -> void:
	paint_shades.clear()
	for chunk in trail_chunks.values():
		(chunk as Node).queue_free()
	trail_chunks.clear()
	var migrated_shade_totals: Dictionary = {}
	var migrated_shade_counts: Dictionary = {}
	for key in saved_paint_shades:
		var parts := str(key).split(",")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			continue
		var saved_value: Variant = saved_paint_shades[key]
		var shade: int
		if format_version >= 1:
			shade = clampi(int(saved_value), 0, PAINT_SHADE_MAX)
		elif typeof(saved_value) == TYPE_FLOAT:
			# Older saves stored trail opacity in the 0.0-0.75 range. Convert
			# those values to a medium-gray range instead of making them white.
			shade = roundi(lerpf(PAINT_DARK_GRAY, PAINT_LIGHT_GRAY, clampf(float(saved_value) / 0.75, 0.0, 1.0)) * PAINT_SHADE_MAX)
		else:
			# Intermediate saves stored heat counts from 0 to 100.
			var heat := clampf(float(saved_value) / float(STEP_GRID_MAX_COUNT), 0.0, 1.0)
			shade = roundi(lerpf(PAINT_DARK_GRAY, PAINT_LIGHT_GRAY, heat) * PAINT_SHADE_MAX)
		var cell_x: int = int(parts[0])
		var cell_y: int = int(parts[1])
		if format_version >= PAINT_FORMAT_VERSION:
			paint_shades["%d,%d" % [cell_x, cell_y]] = shade
		elif format_version == 2:
			var world_x: float = (float(cell_x) + 0.5) * PREVIOUS_PAINT_CELL_SIZE
			var world_y: float = (float(cell_y) + 0.5) * PREVIOUS_PAINT_CELL_SIZE
			var target_x: int = floori(world_x / PAINT_CELL_SIZE)
			var target_y: int = floori(world_y / PAINT_CELL_SIZE)
			var target_key := "%d,%d" % [target_x, target_y]
			migrated_shade_totals[target_key] = int(migrated_shade_totals.get(target_key, 0)) + shade
			migrated_shade_counts[target_key] = int(migrated_shade_counts.get(target_key, 0)) + 1
		else:
			var expansion: int = int(round(LEGACY_PAINT_CELL_SIZE / PAINT_CELL_SIZE))
			for offset_x in range(expansion):
				for offset_y in range(expansion):
					var expanded_x: int = cell_x * expansion + offset_x
					var expanded_y: int = cell_y * expansion + offset_y
					paint_shades["%d,%d" % [expanded_x, expanded_y]] = shade
	for key in migrated_shade_totals:
		paint_shades[key] = roundi(float(migrated_shade_totals[key]) / float(migrated_shade_counts[key]))
	for key in paint_shades:
		var parts := str(key).split(",")
		var cell_x: int = int(parts[0])
		var cell_y: int = int(parts[1])
		_set_trail_cell(cell_x, cell_y, int(paint_shades[key]))


func _set_trail_cell(cell_x: int, cell_y: int, shade: int) -> void:
	var chunk_coordinates := Vector2i(floori(float(cell_x) / TRAIL_CHUNK_CELLS), floori(float(cell_y) / TRAIL_CHUNK_CELLS))
	var chunk: TrailChunk
	if trail_chunks.has(chunk_coordinates):
		chunk = trail_chunks[chunk_coordinates]
	else:
		chunk = TrailChunk.new()
		chunk.paint_cell_size = PAINT_CELL_SIZE
		chunk.paint_shade_max = PAINT_SHADE_MAX
		chunk.position = Vector2(chunk_coordinates * TRAIL_CHUNK_CELLS) * PAINT_CELL_SIZE
		trail_chunks[chunk_coordinates] = chunk
		add_child(chunk)
	var local_cell := Vector2i(cell_x - chunk_coordinates.x * TRAIL_CHUNK_CELLS, cell_y - chunk_coordinates.y * TRAIL_CHUNK_CELLS)
	chunk.set_cell(local_cell, shade)


func saved_paint_state() -> Dictionary:
	return paint_shades.duplicate(true)


func _draw() -> void:
	if not draw_step_heatmap or not debug_step_heatmap:
		return
	for key in step_counts:
		var grid_point: Vector2i = step_grid_points.get(key, Vector2i.ZERO)
		var point := QUEEN_SPAWN_POSITION + Vector2(grid_point.x * STEP_GRID_SPACING + grid_point.y * STEP_GRID_SPACING * 0.5, grid_point.y * STEP_GRID_ROW_HEIGHT)
		var amount := clampf(float(step_counts[key]) / STEP_GRID_MAX_COUNT, 0.0, 1.0)
		var hue := lerpf(2.0 / 3.0, 1.0, amount)
		draw_circle(point, STEP_GRID_DOT_RADIUS, Color.from_hsv(hue, 1.0, 1.0, 0.9))
		draw_string_outline(ThemeDB.fallback_font, point + Vector2(3.0, 3.0), str(step_counts[key]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, STEP_GRID_LABEL_FONT_SIZE, 2, Color(0.0, 0.0, 0.0, 0.95))
		draw_string(ThemeDB.fallback_font, point + Vector2(3.0, 3.0), str(step_counts[key]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, STEP_GRID_LABEL_FONT_SIZE, Color.WHITE)
