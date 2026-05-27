class_name StatsService
extends Node

## Goal of this service is to measure all sorts of important metrics and notify the developer about the state of the game
# - Measure system and video memory through life cycle
# - Measure frame spikes frequency
# - Notify performance overheads
# - Analyse memory leaks and loose nodes over time

signal on_service_start
signal on_service_end
signal on_process_event(message: String, type: StatsNotification.NotificationTypes)

var _is_running: bool = false
var _service_time := 0.0
var _analysis_refresh_interval: float = 0.25
var _analysis_refresh_remaining: float = 0.0
var _service_analyzers: Array[BaseAnalyzer]


func _ready() -> void:
	_register_analyzer(MemoryAnalyser.new())
	_register_commands()


func _register_commands() -> void:
	ConsoleCommands.commands.register(
		"/analisys", {},
		_toggle_service_mode,
		"Enables or disables service mode"
	)


func _toggle_service_mode(handler: ConsoleHandler) -> void:
	var state: bool = !_is_running
	if state:
		start_service()
		handler.log_info("STATS", "Starting GStats analisys service...")
	else:
		stop_service()
		handler.log_info("STATS", "Stopping GStats analisys service.")


func _register_analyzer(analyzer: BaseAnalyzer) -> void:
	_service_analyzers.append(analyzer)
	add_child(analyzer)


func start_service() -> void:
	if _is_running:
		return
		
	_reset_data()
	_is_running = true
	on_service_start.emit()


func stop_service() -> void:
	if !_is_running:
		return
	_is_running = false
	on_service_end.emit()


func _reset_data() -> void:
	_service_time = 0.0
	_analysis_refresh_remaining = 0.0
	
	for analyzer: BaseAnalyzer in _service_analyzers:
		analyzer.reset_data()


func _process(delta) -> void:
	if not _is_running:
		return
		
	_service_time += delta
	_analysis_refresh_remaining -= delta
	
	if _analysis_refresh_remaining <= 0.0:
		_analysis_refresh_remaining = _analysis_refresh_interval
		
		var analysis_events: Array[AnalysisEvent] = []
		for analyzer: BaseAnalyzer in _service_analyzers:
			var report := analyzer.analyse(_service_time)
			analysis_events.append_array(report)
		
		_publish_events(analysis_events)


## TODO: Get rid of NotificationTypes dependency
func _publish_events(events: Array[AnalysisEvent]) -> void:
	for event: AnalysisEvent in events:
		on_process_event.emit(event.message, event.type)


class AnalysisEvent:
	var message: String
	var type: StatsNotification.NotificationTypes
