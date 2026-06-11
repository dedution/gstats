extends Node

const SCENE_PATH := "%s/scenes/stats.tscn"

var _stats_control: StatsController = null
var _stats_service: StatsService = null
var _parent_folder: String


func _enter_tree() -> void:
	var script_file = get_script().resource_path
	var current_folder = script_file.get_base_dir()
	_parent_folder = current_folder.get_base_dir()
	_spawn_menu()
	_spawn_service()


func _ready() -> void:
	pass


func get_version() -> String:
	return "1.0.0"


func start_service() -> void:
	if _stats_service:
		_stats_service.start_service()
	else:
		print("GStats service not available.")


func stop_service() -> void:
	if _stats_service:
		_stats_service.stop_service()
	else:
		print("GStats service not available.")


func push_notification(message: String, type: StatsNotification.NotificationTypes) -> void:
	_stats_control.push_notification(message, type)


#region Private


func _spawn_menu() -> void:
	var packed_scene = load(SCENE_PATH % _parent_folder)
	var instance = packed_scene.instantiate()
	add_child(instance)
	_stats_control = instance


func _spawn_service() -> void:
	var service_node = StatsService.new()
	service_node.name = "GStatsService"
	add_child(service_node)
	_stats_service = service_node
	_stats_service.on_process_event.connect(push_notification)
	
	# TODO: On service start and end, notify the signal system so that the game can properly lock up player input
	# Also use these signal to trigger simulation parameters like game speed, automation and so on.
	_stats_service.on_service_start.connect(_stats_control.set_service_mode.bind(true))
	_stats_service.on_service_end.connect(_stats_control.set_service_mode.bind(false))

#endregion
