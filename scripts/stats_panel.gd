class_name StatsPanel
extends Control

@export var use_process_frame_time: bool = true
@export_range(0.01, 1.0, 0.01) var label_smoothing: float = 0.22
@export_range(0.05, 2.0, 0.05) var memory_refresh_interval: float = 0.25

# References
@export var frame_graph: StatsFrameGraph = null
@export var label_fps: Label
@export var label_average_fps: Label
@export var label_cpu_model: Label
@export var label_cpu_stats: Label
@export var label_gpu_model: Label
@export var label_gpu_stats: Label
@export var label_draw_calls: Label
@export var label_resources: Label
@export var label_ram_usage: Label
@export var label_vram_usage: Label

var _cpu_model: String = "None"
var _gpu_model: String = "None"
var _smoothed_frame_ms: float = 16.67
var _memory_refresh_remaining: float = 0.0
var _viewport_rid: RID = RID()

@onready var stats_padding: Control = $StatsPadding

func _ready() -> void:
	_enable_render_time_measurements()

	_cpu_model = StatsAPI.get_processor_name()
	_gpu_model = StatsAPI.get_gpu_name()
	_refresh_static_labels()

	var initial_frame_ms := _get_frame_budget_ms()
	if frame_graph != null:
		frame_graph.clear_samples(initial_frame_ms)
	_smoothed_frame_ms = initial_frame_ms
	_refresh_frame_labels()
	_update_runtime_debug_labels()
	_update_memory_label()


func _exit_tree() -> void:
	_disable_render_time_measurements()


func set_panel_state(state: bool) -> void:
	stats_padding.visible = state
	
func get_panel_state() -> bool:
	return stats_padding.visible

func record_frame_time(frame_time_ms: float) -> void:
	var sample := maxf(frame_time_ms, 0.01)
	_smoothed_frame_ms = lerpf(_smoothed_frame_ms, sample, label_smoothing)

	if frame_graph != null:
		frame_graph.push_sample(sample)

	_refresh_frame_labels()


func _process(delta: float) -> void:
	if use_process_frame_time:
		record_frame_time(delta * 1000.0)

	_memory_refresh_remaining -= delta
	if _memory_refresh_remaining <= 0.0:
		_memory_refresh_remaining = memory_refresh_interval
		_update_runtime_debug_labels()
		_update_memory_label()


func _enable_render_time_measurements() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return

	_viewport_rid = viewport.get_viewport_rid()
	if _viewport_rid.is_valid() and RenderingServer.has_method("viewport_set_measure_render_time"):
		RenderingServer.viewport_set_measure_render_time(_viewport_rid, true)


func _disable_render_time_measurements() -> void:
	if _viewport_rid.is_valid() and RenderingServer.has_method("viewport_set_measure_render_time"):
		RenderingServer.viewport_set_measure_render_time(_viewport_rid, false)


func _refresh_static_labels() -> void:
	_set_label_text(label_cpu_model, "CPU: %s" % _cpu_model)
	_set_label_text(label_gpu_model, "GPU: %s" % _gpu_model)


func _refresh_frame_labels() -> void:
	var current_fps := _frame_time_to_fps(_smoothed_frame_ms)
	_set_label_text(label_fps, "FPS: %.0f / %.1f ms" % [current_fps, _smoothed_frame_ms])

	var average_frame_ms := _smoothed_frame_ms
	var peak_frame_ms := _smoothed_frame_ms
	if frame_graph != null:
		average_frame_ms = frame_graph.get_average_sample()
		peak_frame_ms = frame_graph.get_peak_sample()

	var average_fps := _frame_time_to_fps(average_frame_ms)
	_set_label_text(
		label_average_fps,
		"Avg: %.0f / %.1f ms | Peak: %.1f ms" % [average_fps, average_frame_ms, peak_frame_ms]
	)

	var cpu_render_time := StatsAPI.get_cpu_render_time_ms(_viewport_rid)
	var gpu_render_time := StatsAPI.get_gpu_render_time_ms(_viewport_rid)

	_set_label_text(label_cpu_stats, "Load: %s" % _format_render_load(cpu_render_time))
	_set_label_text(label_gpu_stats, "Load: %s" % _format_render_load(gpu_render_time))


func _get_frame_budget_ms() -> float:
	if frame_graph == null:
		return 16.67
	return maxf(frame_graph.target_frame_ms, 0.1)


func _update_runtime_debug_labels() -> void:
	_set_label_text(label_draw_calls, "Draw Calls: %d" % StatsAPI.get_total_draw_calls())
	_set_label_text(
		label_resources,
		(
			"Objects: %s | Nodes: %s | Resources: %s | Orphans: %s"
			% [
				StatsAPI.get_object_count(),
				StatsAPI.get_node_count(),
				StatsAPI.get_resource_count(),
				StatsAPI.get_orphan_count(),
			]
		)
	)


func _update_memory_label() -> void:
	var total_ram := StatsAPI.get_system_total_ram()
	var ram_used := StatsAPI.get_ram_used()
	var ram_text := StatsAPI.format_memory_bytes(ram_used)
	var total_ram_text := StatsAPI.format_memory_bytes(total_ram)
	var ram_usage_percentage := StatsAPI.calculate_percentage(ram_used, total_ram)

	var vram_text := StatsAPI.format_memory_bytes(StatsAPI.get_vram_used())
	var texture_text := StatsAPI.format_memory_bytes(StatsAPI.get_tex_used())
	var buffer_text := StatsAPI.format_memory_bytes(StatsAPI.get_buffer_used())

	_set_label_text(
		label_ram_usage, "RAM: %s / %s (%s)" % [ram_text, total_ram_text, ram_usage_percentage]
	)
	_set_label_text(
		label_vram_usage, "VRAM: %s | Tex: %s | Buf: %s" % [vram_text, texture_text, buffer_text]
	)


func _format_render_load(render_time_ms: float) -> String:
	var load := StatsAPI.calculate_percentage_ms(render_time_ms, _get_frame_budget_ms())
	if load == StatsAPI.NOT_AVAILABLE_TEXT:
		return load

	return "%s / %.2f ms" % [load, render_time_ms]


func _set_label_text(label: Label, text: String) -> void:
	if label != null:
		label.text = text


func _frame_time_to_fps(frame_time_ms: float) -> float:
	if frame_time_ms <= 0.0:
		return 0.0
	return 1000.0 / frame_time_ms
