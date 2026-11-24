class_name StepHeatmapOverlay
extends Node2D

const QUEEN_SPAWN_POSITION: Vector2 = Vector2(0.0, -32.0)
const STEP_GRID_SPACING: float = 15.0
const STEP_GRID_ROW_HEIGHT: float = 12.990381
const STEP_GRID_MAX_COUNT: int = 100
const STEP_GRID_DOT_RADIUS: float = 7.5
const STEP_GRID_LABEL_FONT_SIZE: int = 8
const PAINT_RADIUS: float = 10.0
const PAINT_CELL_SIZE: float = 5.0
const PAINT_SAMPLE_SPACING: float = 2.5
const PAINT_DARK_GRAY: float = 0.15
const PAINT_LIGHT_GRAY: float = 0.65
const PAINT_SHADE_MAX: int = 255

var step_counts: Dictionary = {}
var step_grid_points: Dictionary = {}
var paint_shades: Dictionary = {}
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
				var heat := float(_heat_at(cell_center, current_step_counts, current_step_grid_points)) / float(STEP_GRID_MAX_COUNT)
				paint_shades[key] = roundi(lerpf(PAINT_DARK_GRAY, PAINT_LIGHT_GRAY, heat) * PAINT_SHADE_MAX)
	queue_redraw()


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
		paint_shades["%d,%d" % [int(parts[0]), int(parts[1])]] = shade
	queue_redraw()


func saved_paint_state() -> Dictionary:
	return paint_shades.duplicate(true)


func _draw() -> void:
	if draw_paint_trail:
		for key in paint_shades:
			var parts := str(key).split(",")
			if parts.size() != 2:
				continue
			var cell := Vector2i(int(parts[0]), int(parts[1]))
			var gray := clampf(float(paint_shades[key]) / float(PAINT_SHADE_MAX), 0.0, 1.0)
			var rect := Rect2(Vector2(cell.x * PAINT_CELL_SIZE, cell.y * PAINT_CELL_SIZE), Vector2(PAINT_CELL_SIZE, PAINT_CELL_SIZE))
			draw_rect(rect, Color(gray, gray, gray, 1.0))
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
