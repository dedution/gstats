class_name StatsAPI

## Processes and parses formated and ready to consume data about performance

const NOT_AVAILABLE_TEXT: String = "N/A"


static func _read_rendering_info(metric: int) -> int:
	return int(RenderingServer.get_rendering_info(metric))


static func _read_singleton_string(singleton: Object, method_name: String) -> String:
	if singleton != null and singleton.has_method(method_name):
		return str(singleton.call(method_name)).strip_edges()
	return ""


static func format_memory_bytes(bytes: int) -> String:
	if bytes < 0:
		return NOT_AVAILABLE_TEXT

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


static func calculate_percentage(bytes: int, bytes_total: int) -> String:
	if bytes < 0 or bytes_total <= 0:
		return NOT_AVAILABLE_TEXT

	var percentage := int(float(bytes) * 100.0 / float(bytes_total))
	return str(percentage) + "%"


static func calculate_percentage_ms(ms: float, ms_total: float) -> String:
	if ms < 0.0 or ms_total <= 0.0:
		return NOT_AVAILABLE_TEXT

	var percentage := int(ms * 100.0 / ms_total)
	return str(percentage) + "%"


static func get_vram_used() -> int:
	return _read_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)


static func get_tex_used() -> int:
	return _read_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)


static func get_buffer_used() -> int:
	return _read_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)


static func get_ram_used() -> int:
	var ram_used := OS.get_static_memory_usage()
	if ram_used > 0:
		return ram_used

	var performance_ram := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	return performance_ram if performance_ram > 0 else -1


static func get_system_total_ram() -> int:
	var memory_info := OS.get_memory_info()
	return int(memory_info.get("physical", -1))


static func get_system_total_vram() -> int:
	return -1


static func get_processor_name() -> String:
	return _read_singleton_string(OS, "get_processor_name")


static func get_processor_count() -> int:
	if OS.has_method("get_processor_count"):
		var processor_count := int(OS.call("get_processor_count"))
		return processor_count if processor_count > 0 else -1
	return -1


static func get_gpu_name() -> String:
	var gpu_name := _read_singleton_string(RenderingServer, "get_video_adapter_name")
	if not gpu_name.is_empty():
		return gpu_name
	return "None"


static func get_render_driver_name() -> String:
	return _read_singleton_string(RenderingServer, "get_current_rendering_driver_name").replace(
		"_", " "
	)


static func get_total_draw_calls() -> int:
	return _read_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


static func get_object_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_COUNT))


static func get_resource_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))


static func get_node_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


static func get_orphan_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


static func get_cpu_render_time_ms(viewport_rid: RID) -> float:
	var cpu_render_ms := RenderingServer.get_frame_setup_time_cpu()
	if (
		viewport_rid.is_valid()
		and RenderingServer.has_method("viewport_get_measured_render_time_cpu")
	):
		cpu_render_ms += RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
	return cpu_render_ms if cpu_render_ms > 0.0 else -1.0


static func get_gpu_render_time_ms(viewport_rid: RID) -> float:
	if (
		not viewport_rid.is_valid()
		or not RenderingServer.has_method("viewport_get_measured_render_time_gpu")
	):
		return -1.0

	var gpu_render_ms := RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
	return gpu_render_ms if gpu_render_ms > 0.0 else -1.0
