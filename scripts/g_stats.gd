extends Node

## Singleton that spawns the graphs and notification system
## The notification system should be open to any part of the game

const TOGGLE_KEY: Key = KEY_F11

# TODO: Coloring and log types like GTERM
# TODO: System to measure and notify memory and average frame limits
var _stats_control: GStatsController = null

func _enter_tree() -> void:
	_spawn_menu()

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

#endregion
