class_name MemoryAnalyser
extends BaseAnalyzer

const RAM_HIGH_USAGE_RATIO: float = 0.85
const RAM_GROWTH_WARN_BYTES: int = 128 * 1024 * 1024
const RAM_GROWTH_ERROR_BYTES: int = 512 * 1024 * 1024
const MIN_GROWTH_WINDOW_SECONDS: float = 10.0
const OBJECT_GROWTH_HINT_COUNT: int = 64
const NODE_GROWTH_HINT_COUNT: int = 16
const RESOURCE_GROWTH_HINT_COUNT: int = 16
const ORPHAN_WARN_COUNT: int = 1
const EVENT_COOLDOWN_SECONDS: float = 15.0

var _memory_samples: Array[MemorySample] = []
var _max_sample_count: int = 240
var _last_event_time_by_key: Dictionary = {}


func analyse(time: float) -> Array[StatsService.AnalysisEvent]:
	_sample_memory(time)

	var events: Array[StatsService.AnalysisEvent] = []
	if _memory_samples.is_empty():
		return events

	var newest := _memory_samples[0]
	_analyse_high_ram_usage(newest, events)
	_analyse_orphans(newest, events)

	if _memory_samples.size() < 2:
		return events

	var oldest := _memory_samples[_memory_samples.size() - 1]
	if newest.time - oldest.time < MIN_GROWTH_WINDOW_SECONDS:
		return events

	_analyse_ram_growth(oldest, newest, events)
	_analyse_growth_with_object_counts(oldest, newest, events)

	return events


func reset_data() -> void:
	_memory_samples.clear()
	_last_event_time_by_key.clear()


func _sample_memory(time: float) -> void:
	var sample := MemorySample.new()
	sample.time = time
	sample.ram_used = StatsAPI.get_ram_used()
	sample.vram_used = StatsAPI.get_vram_used()
	sample.texture_used = StatsAPI.get_tex_used()
	sample.buffer_used = StatsAPI.get_buffer_used()
	sample.object_count = StatsAPI.get_object_count()
	sample.node_count = StatsAPI.get_node_count()
	sample.resource_count = StatsAPI.get_resource_count()
	sample.orphan_count = StatsAPI.get_orphan_count()
	_memory_samples.push_front(sample)

	if _memory_samples.size() > _max_sample_count:
		_memory_samples.pop_back()


func _analyse_high_ram_usage(
	sample: MemorySample, events: Array[StatsService.AnalysisEvent]
) -> void:
	var total_ram := StatsAPI.get_system_total_ram()
	if sample.ram_used < 0 or total_ram <= 0:
		return

	var usage_ratio := float(sample.ram_used) / float(total_ram)
	if usage_ratio < RAM_HIGH_USAGE_RATIO:
		return

	if not _can_emit_event("high_ram_usage", sample.time):
		return

	var message := (
		"RAM usage is high: %s / %s (%d%%)"
		% [
			StatsAPI.format_memory_bytes(sample.ram_used),
			StatsAPI.format_memory_bytes(total_ram),
			roundi(usage_ratio * 100.0),
		]
	)
	events.append(_make_event(message, StatsNotification.NotificationTypes.WARN))


func _analyse_ram_growth(
	oldest: MemorySample, newest: MemorySample, events: Array[StatsService.AnalysisEvent]
) -> void:
	if oldest.ram_used < 0 or newest.ram_used < 0:
		return

	var growth := newest.ram_used - oldest.ram_used
	if growth < RAM_GROWTH_WARN_BYTES:
		return

	var event_key := "ram_growth_error" if growth >= RAM_GROWTH_ERROR_BYTES else "ram_growth_warn"
	if not _can_emit_event(event_key, newest.time):
		return

	var severity := (
		StatsNotification.NotificationTypes.ERROR
		if growth >= RAM_GROWTH_ERROR_BYTES
		else StatsNotification.NotificationTypes.WARN
	)
	events.append(
		_make_event(
			(
				"RAM grew by %s over %.1fs"
				% [StatsAPI.format_memory_bytes(growth), newest.time - oldest.time]
			),
			severity
		)
	)


func _analyse_growth_with_object_counts(
	oldest: MemorySample, newest: MemorySample, events: Array[StatsService.AnalysisEvent]
) -> void:
	if oldest.ram_used < 0 or newest.ram_used < 0:
		return

	var ram_growth := newest.ram_used - oldest.ram_used
	if ram_growth < RAM_GROWTH_WARN_BYTES:
		return

	var object_growth := newest.object_count - oldest.object_count
	var node_growth := newest.node_count - oldest.node_count
	var resource_growth := newest.resource_count - oldest.resource_count
	var object_growth_is_interesting := object_growth >= OBJECT_GROWTH_HINT_COUNT
	var node_growth_is_interesting := node_growth >= NODE_GROWTH_HINT_COUNT
	var resource_growth_is_interesting := resource_growth >= RESOURCE_GROWTH_HINT_COUNT

	if (
		not object_growth_is_interesting
		and not node_growth_is_interesting
		and not resource_growth_is_interesting
	):
		return

	if not _can_emit_event("ram_growth_with_objects", newest.time):
		return

	var message := (
		"Memory grew with live counts: RAM +%s, Objects %+d, Nodes %+d, Resources %+d"
		% [
			StatsAPI.format_memory_bytes(ram_growth),
			object_growth,
			node_growth,
			resource_growth,
		]
	)
	events.append(_make_event(message, StatsNotification.NotificationTypes.WARN))


func _analyse_orphans(sample: MemorySample, events: Array[StatsService.AnalysisEvent]) -> void:
	if sample.orphan_count < ORPHAN_WARN_COUNT:
		return

	if not _can_emit_event("orphan_nodes", sample.time):
		return

	events.append(
		_make_event(
			"Detected %d orphan node(s)" % sample.orphan_count,
			StatsNotification.NotificationTypes.WARN
		)
	)


func _can_emit_event(key: String, time: float) -> bool:
	if _last_event_time_by_key.has(key):
		var last_time: float = _last_event_time_by_key[key]
		if time - last_time < EVENT_COOLDOWN_SECONDS:
			return false

	_last_event_time_by_key[key] = time
	return true


func _make_event(
	message: String, type: StatsNotification.NotificationTypes
) -> StatsService.AnalysisEvent:
	var event := StatsService.AnalysisEvent.new()
	event.message = message
	event.type = type
	return event


class MemorySample:
	var time: float
	var ram_used: int
	var vram_used: int
	var texture_used: int
	var buffer_used: int
	var object_count: int
	var node_count: int
	var resource_count: int
	var orphan_count: int
