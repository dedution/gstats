extends Node

## Singleton that spawns the graphs and notification system

const TOGGLE_KEY: Key = KEY_F11

# TODO: System to measure and notify memory and average frame limits
var _stats_control: GStatsController = null
var _service: GStatsService = null

func _enter_tree() -> void:
	_spawn_menu()
	_start_service()

func _ready() -> void:
	pass

func get_version() -> String:
	return "1.0.0"

func push_notification(message: String, type: GStatsNotifications.NotificationTypes) -> void:
	_stats_control.push_notification(message, type)

#region Private

func _spawn_menu() -> void:
	var script_file = get_script().resource_path
	var current_folder = script_file.get_base_dir()
	var parent_folder = current_folder.get_base_dir()
	var packed_scene = load(parent_folder + "/%s/%s" % ["scenes", "g_stats.tscn"])
	var instance = packed_scene.instantiate()
	add_child(instance)
	_stats_control = instance
	
func _start_service() -> void:
	if _service == null:
		_service = GStatsService.new()
		add_child(_service)
	_service.start_service()

#endregion
