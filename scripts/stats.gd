extends Node

const SCENE_PATH := "%s/scenes/stats.tscn"

## Singleton that spawns the graphs and notification system

# TODO: System to measure and notify memory and average frame limits
var _stats_control: StatsController = null
var _parent_folder: String


func _enter_tree() -> void:
	var script_file = get_script().resource_path
	var current_folder = script_file.get_base_dir()
	_parent_folder = current_folder.get_base_dir()
	_spawn_menu()


func _ready() -> void:
	pass


func get_version() -> String:
	return "1.0.0"


func push_notification(message: String, type: StatsNotification.NotificationTypes) -> void:
	_stats_control.push_notification(message, type)


#region Private


func _spawn_menu() -> void:
	var packed_scene = load(SCENE_PATH % _parent_folder)
	var instance = packed_scene.instantiate()
	add_child(instance)
	_stats_control = instance

#endregion
