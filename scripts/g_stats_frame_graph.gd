@tool
class_name GStatsFrameGraph
extends Control

signal sample_added(frame_time_ms: float)

@export_range(32, 512, 1) var sample_capacity: int = 180:
	set(value):
		sample_capacity = maxi(value, 2)
		_resize_history()

@export_range(8.0, 100.0, 0.1, "or_greater") var graph_ceiling_ms: float = 40.0:
	set(value):
		graph_ceiling_ms = maxf(value, 1.0)
		queue_redraw()

@export_range(1.0, 100.0, 0.1, "or_greater") var target_frame_ms: float = 16.67:
	set(value):
		target_frame_ms = maxf(value, 0.1)
		queue_redraw()

@export_range(1.0, 100.0, 0.1, "or_greater") var warning_frame_ms: float = 33.33:
	set(value):
		warning_frame_ms = maxf(value, 0.1)
		queue_redraw()

@export var background_color: Color = Color(0.0235294, 0.0352941, 0.054902, 0.95)
@export var border_color: Color = Color(0.231373, 0.368627, 0.494118, 0.65)
@export var grid_color: Color = Color(0.192157, 0.286275, 0.368627, 0.5)
@export var target_color: Color = Color(0.360784, 0.780392, 0.611765, 0.95)
@export var warning_color: Color = Color(0.94902, 0.490196, 0.298039, 0.95)
@export var line_color: Color = Color(0.439216, 0.772549, 1.0, 1.0)
@export var fill_color: Color = Color(0.247059, 0.631373, 0.894118, 0.24)
@export var latest_point_color: Color = Color(0.780392, 0.913725, 1.0, 1.0)

var _samples: Array[float] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_ensure_seeded()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func clear_samples(seed_value: float = -1.0) -> void:
	_samples.clear()
	if seed_value < 0.0:
		seed_value = target_frame_ms
	_seed_history(seed_value)


func push_sample(frame_time_ms: float) -> void:
	_ensure_seeded()
	if _samples.size() >= sample_capacity:
		_samples.pop_front()
	_samples.append(maxf(frame_time_ms, 0.0))
	queue_redraw()
	sample_added.emit(frame_time_ms)


func set_samples(samples: Array[float]) -> void:
	_samples.clear()
	for sample in samples:
		_samples.append(maxf(sample, 0.0))

	if _samples.size() > sample_capacity:
		var trimmed: Array[float] = []
		var start_index := _samples.size() - sample_capacity
		for index in range(start_index, _samples.size()):
			trimmed.append(_samples[index])
		_samples = trimmed

	if _samples.is_empty():
		_seed_history(target_frame_ms)
	else:
		while _samples.size() < sample_capacity:
			_samples.push_front(_samples[0])

	queue_redraw()


func get_latest_sample() -> float:
	_ensure_seeded()
	return _samples.back()


func get_average_sample() -> float:
	_ensure_seeded()
	var total := 0.0
	for sample in _samples:
		total += sample
	return total / float(_samples.size())


func get_peak_sample() -> float:
	_ensure_seeded()
	var peak := 0.0
	for sample in _samples:
		peak = maxf(peak, sample)
	return peak


func get_samples() -> Array[float]:
	var duplicate_samples: Array[float] = []
	for sample in _samples:
		duplicate_samples.append(sample)
	return duplicate_samples


func _draw() -> void:
	var graph_rect := Rect2(Vector2.ZERO, size)
	if graph_rect.size.x <= 1.0 or graph_rect.size.y <= 1.0:
		return

	draw_rect(graph_rect, background_color)
	draw_rect(graph_rect, border_color, false, 1.0)
	_draw_vertical_grid(graph_rect, 6)
	_draw_horizontal_grid(graph_rect, [0.25, 0.5, 0.75])
	_draw_threshold(graph_rect, target_frame_ms, target_color)
	_draw_threshold(graph_rect, warning_frame_ms, warning_color)
	_draw_graph(graph_rect)


func _draw_vertical_grid(graph_rect: Rect2, divisions: int) -> void:
	for index in range(1, divisions):
		var x := graph_rect.size.x * float(index) / float(divisions)
		draw_line(Vector2(x, 0.0), Vector2(x, graph_rect.size.y), grid_color, 1.0, true)


func _draw_horizontal_grid(graph_rect: Rect2, ratios: Array) -> void:
	for ratio in ratios:
		var y := graph_rect.size.y * float(ratio)
		draw_line(Vector2(0.0, y), Vector2(graph_rect.size.x, y), grid_color, 1.0, true)


func _draw_threshold(graph_rect: Rect2, frame_time_ms: float, color: Color) -> void:
	if frame_time_ms <= 0.0:
		return

	var y := _sample_to_y(frame_time_ms, graph_rect)
	draw_line(Vector2(0.0, y), Vector2(graph_rect.size.x, y), color, 1.5, true)


func _draw_graph(graph_rect: Rect2) -> void:
	_ensure_seeded()
	if _samples.size() < 2:
		return

	var line_points := PackedVector2Array()
	var fill_points := PackedVector2Array()
	fill_points.append(Vector2(0.0, graph_rect.size.y))

	var step := graph_rect.size.x / float(_samples.size() - 1)
	for index in range(_samples.size()):
		var sample := clampf(_samples[index], 0.0, graph_ceiling_ms)
		var point := Vector2(step * float(index), _sample_to_y(sample, graph_rect))
		line_points.append(point)
		fill_points.append(point)

	fill_points.append(Vector2(graph_rect.size.x, graph_rect.size.y))

	draw_colored_polygon(fill_points, fill_color)
	draw_polyline(line_points, line_color, 2.0, true)

	var latest_point := line_points[line_points.size() - 1]
	var latest_sample := _samples.back()
	var latest_color := latest_point_color if latest_sample <= warning_frame_ms else warning_color
	draw_circle(latest_point, 3.0, latest_color)


func _sample_to_y(sample: float, graph_rect: Rect2) -> float:
	var clamped := clampf(sample, 0.0, graph_ceiling_ms)
	var ratio := clamped / graph_ceiling_ms
	return lerpf(graph_rect.size.y - 1.0, 1.0, ratio)


func _resize_history() -> void:
	if _samples.is_empty():
		_seed_history(target_frame_ms)
		return

	while _samples.size() > sample_capacity:
		_samples.pop_front()

	while _samples.size() < sample_capacity:
		_samples.push_front(_samples[0])

	queue_redraw()


func _ensure_seeded() -> void:
	if _samples.is_empty():
		_seed_history(target_frame_ms)


func _seed_history(seed_value: float) -> void:
	for _index in range(sample_capacity):
		_samples.append(maxf(seed_value, 0.0))
	queue_redraw()
