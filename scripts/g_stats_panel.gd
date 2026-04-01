class_name GStatsPanel
extends Control

const GRAPH_CONTENT_PATH := "StatsPadding/StatsBoxContainer/FrameGraphCard/GraphMargin/GraphContent"
const FRAME_GRAPH_PATH := GRAPH_CONTENT_PATH + "/FrameGraph"

@export var use_process_frame_time: bool = true
@export_range(0.01, 1.0, 0.01) var label_smoothing: float = 0.22
@export_range(0.05, 2.0, 0.05) var memory_refresh_interval: float = 0.25
@export var overdraw_toggle_key: Key = KEY_F10
@export var overdraw_visualization_enabled: bool = false

@onready var _stats_padding: Control = $StatsPadding

var _frame_graph: GStatsFrameGraph = null
var _latest_frame_time: Label = null
var _target_budget: Label = null
var _peak_frame_time: Label = null
var _current_fps: Label = null
var _average_fps: Label = null
var _performance_fps: Label = null
var _performance_average_fps: Label = null
var _cpu_model: Label = null
var _cpu_stats: Label = null
var _gpu_model: Label = null
var _gpu_stats: Label = null
var _draw_calls: Label = null
var _render_stats: Label = null
var _resource_stats: Label = null
var _allocation_stats: Label = null
var _pipeline_stats: Label = null
var _view_mode: Label = null
var _memory: Label = null
var _ram: Label = null
var _vram: Label = null

var _smoothed_frame_ms: float = 16.67
var _memory_refresh_remaining: float = 0.0
var _system_total_ram: int = -1
var _processor_name: String = ""
var _processor_count: int = -1
var _gpu_name: String = ""
var _renderer_name: String = ""
var _render_driver_name: String = ""
var _viewport_rid: RID = RID()
var _last_object_count: int = -1
var _last_resource_count: int = -1
var _last_node_count: int = -1
var _last_orphan_count: int = -1


func _ready() -> void:
	_cache_ui_references()
	if _frame_graph == null:
		push_warning("GStatsPanel could not find FrameGraph under GraphContent.")
		close_menu()
		return

	var initial_frame_ms := _frame_graph.target_frame_ms
	_frame_graph.clear_samples(initial_frame_ms)
	_smoothed_frame_ms = initial_frame_ms
	_enable_render_time_measurements()
	_apply_view_debug_draw()
	_system_total_ram = _read_system_total_ram()
	_processor_name = _read_processor_name()
	_processor_count = _read_processor_count()
	_gpu_name = _read_gpu_name()
	_renderer_name = _read_renderer_name()
	_render_driver_name = _read_render_driver_name()

	_refresh_hardware_labels()
	_update_runtime_debug_labels(memory_refresh_interval)
	_update_memory_label()
	_refresh_labels(initial_frame_ms)
	close_menu()


func _process(delta: float) -> void:
	if use_process_frame_time:
		record_frame_time(delta * 1000.0)

	_memory_refresh_remaining -= delta
	if _memory_refresh_remaining <= 0.0:
		_memory_refresh_remaining = memory_refresh_interval
		_update_runtime_debug_labels(memory_refresh_interval)
		_update_memory_label()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == GStats.TOGGLE_KEY:
			if _stats_padding.visible:
				close_menu()
			else:
				open_menu()
			return

		if event.keycode == overdraw_toggle_key:
			toggle_overdraw_visualization()


func open_menu() -> void:
	_stats_padding.visible = true
	_stats_padding.set_process(true)


func close_menu() -> void:
	_stats_padding.visible = false
	_stats_padding.set_process(false)


func record_frame_time(frame_time_ms: float) -> void:
	if _frame_graph == null:
		return

	var sample := maxf(frame_time_ms, 0.01)
	_smoothed_frame_ms = lerpf(_smoothed_frame_ms, sample, label_smoothing)
	_frame_graph.push_sample(sample)
	_refresh_labels(sample)


func seed_frame_time(frame_time_ms: float) -> void:
	if _frame_graph == null:
		return

	var seed := maxf(frame_time_ms, 0.01)
	_frame_graph.clear_samples(seed)
	_smoothed_frame_ms = seed
	_refresh_labels(seed)


func _cache_ui_references() -> void:
	_frame_graph = get_node_or_null(FRAME_GRAPH_PATH) as GStatsFrameGraph
	_latest_frame_time = _find_label([GRAPH_CONTENT_PATH + "/GraphMetaRow/LatestFrameTime"])
	_target_budget = _find_label([GRAPH_CONTENT_PATH + "/GraphMetaRow/TargetBudget"])
	_peak_frame_time = _find_label([GRAPH_CONTENT_PATH + "/GraphMetaRow/PeakFrameTime"])
	_current_fps = _find_label([GRAPH_CONTENT_PATH + "/CurrentFPS"])
	_average_fps = _find_label([GRAPH_CONTENT_PATH + "/avgFPS", GRAPH_CONTENT_PATH + "/AverageFPS"])
	_performance_fps = _find_label([GRAPH_CONTENT_PATH + "/GraphMetaRowPerformance/FPS"])
	_performance_average_fps = _find_label([GRAPH_CONTENT_PATH + "/GraphMetaRowPerformance/AvgFPS"])
	_cpu_model = _find_label([GRAPH_CONTENT_PATH + "/GraphMetaRowCPU/CPUModel"])
	_cpu_stats = _find_label([GRAPH_CONTENT_PATH + "/GraphMetaRowCPU/CPUStats"])
	_gpu_model = _find_label([GRAPH_CONTENT_PATH + "/GraphMetaRowGPU/GPUModel"])
	_gpu_stats = _find_label([GRAPH_CONTENT_PATH + "/GraphMetaRowGPU/GPUStats"])
	_draw_calls = _find_label([GRAPH_CONTENT_PATH + "/GraphMetaRowRender/DrawCalls"])
	_render_stats = _find_label([GRAPH_CONTENT_PATH + "/GraphMetaRowRender/RenderStats"])
	_resource_stats = _find_label([GRAPH_CONTENT_PATH + "/GraphMetaRowResources/ResourceStats"])
	_allocation_stats = _find_label([GRAPH_CONTENT_PATH + "/GraphMetaRowResources/AllocationStats"])
	_pipeline_stats = _find_label([GRAPH_CONTENT_PATH + "/GraphMetaRowPipelines/PipelineStats"])
	_view_mode = _find_label([GRAPH_CONTENT_PATH + "/GraphMetaRowPipelines/ViewMode"])
	_memory = _find_label([GRAPH_CONTENT_PATH + "/Memory"])
	_ram = _find_label([GRAPH_CONTENT_PATH + "/GraphMetaRowMemory/Ram", GRAPH_CONTENT_PATH + "/GraphMetaRowMemory/RAM"])
	_vram = _find_label(
		[
			GRAPH_CONTENT_PATH + "/GraphMetaRowMemory/VRam",
			GRAPH_CONTENT_PATH + "/GraphMetaRowMemory/Vram",
			GRAPH_CONTENT_PATH + "/GraphMetaRowMemory/VRAM",
		]
	)


func _find_label(paths: Array[String]) -> Label:
	for path in paths:
		var label := get_node_or_null(path) as Label
		if label != null:
			return label
	return null


func _refresh_labels(frame_time_ms: float) -> void:
	if _frame_graph == null:
		return

	var average_ms := _frame_graph.get_average_sample()
	var peak_ms := _frame_graph.get_peak_sample()
	var current_fps := _frame_time_to_fps(_smoothed_frame_ms)
	var average_fps := _frame_time_to_fps(average_ms)

	_set_label_text(_latest_frame_time, "Latest %.1f ms" % frame_time_ms)
	_set_label_text(
		_target_budget,
		"Budget %.1f ms / %.0f FPS" % [_frame_graph.target_frame_ms, _frame_time_to_fps(_frame_graph.target_frame_ms)]
	)
	_set_label_text(_peak_frame_time, "Peak %.1f ms" % peak_ms)
	_set_label_text(_current_fps, "FPS: %.0f  |  Frame: %.1f ms" % [current_fps, _smoothed_frame_ms])
	_set_label_text(_average_fps, "Avg FPS: %.1f  |  Avg Frame: %.1f ms" % [average_fps, average_ms])
	_set_label_text(_performance_fps, "FPS: %.0f / %.1f ms" % [current_fps, _smoothed_frame_ms])
	_set_label_text(_performance_average_fps, "Average FPS: %.1f / %.1f ms" % [average_fps, average_ms])
	_refresh_render_debug_labels()

func _refresh_hardware_labels() -> void:
	var cpu_details := _fallback_text(_processor_name)
	if _processor_count > 0:
		cpu_details += " (%d threads)" % _processor_count
	_set_label_text(_cpu_model, "CPU: %s" % cpu_details)

	var gpu_details := _fallback_text(_gpu_name)
	if not _renderer_name.is_empty() and _renderer_name.to_lower() != gpu_details.to_lower():
		gpu_details += " / %s" % _renderer_name
	if not _render_driver_name.is_empty():
		gpu_details += " (%s)" % _render_driver_name
	_set_label_text(_gpu_model, "GPU: %s" % gpu_details)


func _refresh_render_debug_labels() -> void:
	var frame_budget_ms := _get_frame_budget_ms()
	var cpu_render_ms := _read_cpu_render_time_ms()
	var gpu_render_ms := _read_gpu_render_time_ms()
	var draw_calls := _read_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var object_count := _read_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var primitive_count := _read_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)

	_set_label_text(_cpu_stats, _format_load_text("CPU load", cpu_render_ms, frame_budget_ms))
	_set_label_text(_gpu_stats, _format_load_text("GPU load", gpu_render_ms, frame_budget_ms))
	_set_label_text(_draw_calls, "Draw Calls: %s" % _format_compact_count(draw_calls))
	_set_label_text(
		_render_stats,
		"Objects: %s | Primitives: %s" % [
			_format_compact_count(object_count),
			_format_compact_count(primitive_count),
		]
	)


func _update_runtime_debug_labels(sample_interval: float) -> void:
	var object_count := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resource_count := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var node_count := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphan_count := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	_set_label_text(
		_resource_stats,
		"Objects: %s | Nodes: %s | Res: %s | Orphans: %s" % [
			_format_compact_count(object_count),
			_format_compact_count(node_count),
			_format_compact_count(resource_count),
			_format_compact_count(orphan_count),
		]
	)
	_set_label_text(
		_allocation_stats,
		"Alloc/s Obj %s | Res %s" % [
			_format_rate_per_second(object_count - _last_object_count, sample_interval, _last_object_count >= 0),
			_format_rate_per_second(resource_count - _last_resource_count, sample_interval, _last_resource_count >= 0),
		]
	)

	var mesh_compilations := _read_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH)
	var surface_compilations := _read_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE)
	var draw_compilations := _read_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW)
	var specialization_compilations := _read_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)
	_set_label_text(
		_pipeline_stats,
		"Pipes M:%s S:%s D:%s X:%s" % [
			_format_compact_count(mesh_compilations),
			_format_compact_count(surface_compilations),
			_format_compact_count(draw_compilations),
			_format_compact_count(specialization_compilations),
		]
	)
	_refresh_view_mode_label()

	_last_object_count = object_count
	_last_resource_count = resource_count
	_last_node_count = node_count
	_last_orphan_count = orphan_count


func _frame_time_to_fps(frame_time_ms: float) -> float:
	if frame_time_ms <= 0.0:
		return 0.0
	return 1000.0 / frame_time_ms


func _update_memory_label() -> void:
	var ram_used := _read_ram_used()
	var vram_used := _read_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	var texture_used := _read_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	var buffer_used := _read_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)
	var ram_text := _format_memory_usage_text(ram_used, _system_total_ram)
	var vram_text := _format_memory_pair(vram_used)

	_set_label_text(_memory, "RAM %s | VRAM %s" % [ram_text, vram_text])
	_set_label_text(_ram, "RAM: %s" % ram_text)
	_set_label_text(
		_vram,
		"VRAM: %s | Tex %s | Buf %s" % [
			vram_text,
			_format_memory_pair(texture_used),
			_format_memory_pair(buffer_used),
		]
	)


func _enable_render_time_measurements() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return

	_viewport_rid = viewport.get_viewport_rid()
	if _viewport_rid.is_valid() and RenderingServer.has_method("viewport_set_measure_render_time"):
		RenderingServer.viewport_set_measure_render_time(_viewport_rid, true)


func toggle_overdraw_visualization() -> void:
	overdraw_visualization_enabled = not overdraw_visualization_enabled
	_apply_view_debug_draw()
	_refresh_view_mode_label()


func _apply_view_debug_draw() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return

	viewport.debug_draw = Viewport.DEBUG_DRAW_OVERDRAW if overdraw_visualization_enabled else Viewport.DEBUG_DRAW_DISABLED


func _refresh_view_mode_label() -> void:
	_set_label_text(
		_view_mode,
		"View: %s (%s)" % [
			"Overdraw" if overdraw_visualization_enabled else "Normal",
			OS.get_keycode_string(overdraw_toggle_key),
		]
	)


func _read_ram_used() -> int:
	var ram_used := OS.get_static_memory_usage()
	if ram_used > 0:
		return ram_used

	var performance_ram := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	return performance_ram if performance_ram > 0 else -1


func _read_system_total_ram() -> int:
	var memory_info := OS.get_memory_info()
	return int(memory_info.get("physical", -1))


func _read_processor_name() -> String:
	return _read_singleton_string(OS, "get_processor_name")


func _read_processor_count() -> int:
	if OS.has_method("get_processor_count"):
		var processor_count := int(OS.call("get_processor_count"))
		return processor_count if processor_count > 0 else -1
	return -1


func _read_gpu_name() -> String:
	var gpu_name := _read_singleton_string(RenderingServer, "get_video_adapter_name")
	if not gpu_name.is_empty():
		return gpu_name
	return _read_renderer_name()


func _read_render_driver_name() -> String:
	return _read_singleton_string(RenderingServer, "get_current_rendering_driver_name").replace("_", " ")


func _read_renderer_name() -> String:
	var renderer_name := _read_singleton_string(RenderingServer, "get_current_rendering_method")
	if renderer_name.is_empty():
		var features: PackedStringArray = ProjectSettings.get_setting("application/config/features", PackedStringArray())
		for feature in features:
			var feature_name := str(feature).strip_edges()
			if feature_name.is_empty() or _is_version_token(feature_name):
				continue
			renderer_name = feature_name
			break

	return renderer_name.replace("_", " ")


func _is_version_token(value: String) -> bool:
	var normalized := value.strip_edges().replace(".", "")
	return not normalized.is_empty() and normalized.is_valid_int()


func _read_singleton_string(singleton: Object, method_name: String) -> String:
	if singleton != null and singleton.has_method(method_name):
		return str(singleton.call(method_name)).strip_edges()
	return ""


func _read_rendering_info(metric: int) -> int:
	return int(RenderingServer.get_rendering_info(metric))


func _read_cpu_render_time_ms() -> float:
	var cpu_render_ms := RenderingServer.get_frame_setup_time_cpu()
	if _viewport_rid.is_valid() and RenderingServer.has_method("viewport_get_measured_render_time_cpu"):
		cpu_render_ms += RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid)
	return cpu_render_ms if cpu_render_ms > 0.0 else -1.0


func _read_gpu_render_time_ms() -> float:
	if not _viewport_rid.is_valid() or not RenderingServer.has_method("viewport_get_measured_render_time_gpu"):
		return -1.0

	var gpu_render_ms := RenderingServer.viewport_get_measured_render_time_gpu(_viewport_rid)
	return gpu_render_ms if gpu_render_ms > 0.0 else -1.0


func _get_frame_budget_ms() -> float:
	if _frame_graph == null:
		return 16.67
	return maxf(_frame_graph.target_frame_ms, 0.1)


func _format_load_text(prefix: String, frame_time_ms: float, frame_budget_ms: float) -> String:
	if frame_time_ms <= 0.0:
		return "%s: n/a | n/a" % prefix
	return "%s: %.0f%% | %.2f ms" % [
		prefix,
		(frame_time_ms / frame_budget_ms) * 100.0,
		frame_time_ms,
	]


func _set_label_text(label: Label, text: String) -> void:
	if label != null:
		label.text = text


func _fallback_text(value: String) -> String:
	return value if not value.is_empty() else "n/a"


func _format_memory_pair(used_bytes: int, total_bytes: int = -1) -> String:
	if used_bytes <= 0:
		return "n/a"
	if total_bytes > 0:
		return "%s / %s" % [_format_memory_bytes(used_bytes), _format_memory_bytes(total_bytes)]
	return _format_memory_bytes(used_bytes)


func _format_memory_usage_text(used_bytes: int, total_bytes: int) -> String:
	if used_bytes <= 0:
		return "n/a"
	if total_bytes > 0:
		return "%s / %s (%.0f%%)" % [
			_format_memory_bytes(used_bytes),
			_format_memory_bytes(total_bytes),
			(float(used_bytes) / float(total_bytes)) * 100.0,
		]
	return _format_memory_bytes(used_bytes)


func _format_compact_count(value: int) -> String:
	if value < 0:
		return "n/a"
	if value < 1000:
		return str(value)

	var suffixes := ["K", "M", "B", "T"]
	var scaled_value := float(value)
	var suffix_index := -1
	while scaled_value >= 1000.0 and suffix_index < suffixes.size() - 1:
		scaled_value /= 1000.0
		suffix_index += 1

	if scaled_value >= 100.0:
		return "%.0f%s" % [scaled_value, suffixes[suffix_index]]
	if scaled_value >= 10.0:
		return "%.1f%s" % [scaled_value, suffixes[suffix_index]]
	return "%.2f%s" % [scaled_value, suffixes[suffix_index]]


func _format_rate_per_second(delta_value: int, sample_interval: float, has_history: bool) -> String:
	if not has_history or sample_interval <= 0.0:
		return "n/a"

	var rate := float(delta_value) / sample_interval
	if absf(rate) >= 100.0:
		return "%+.0f" % rate
	if absf(rate) >= 10.0:
		return "%+.1f" % rate
	return "%+.2f" % rate


func _format_memory_bytes(bytes: int) -> String:
	if bytes < 1024:
		return "%d B" % bytes

	var units := ["KiB", "MiB", "GiB", "TiB"]
	var value := float(bytes)
	var unit_index := -1
	while value >= 1024.0 and unit_index < units.size() - 1:
		value /= 1024.0
		unit_index += 1

	if value >= 100.0:
		return "%.0f %s" % [value, units[unit_index]]
	if value >= 10.0:
		return "%.1f %s" % [value, units[unit_index]]
	return "%.2f %s" % [value, units[unit_index]]
