class_name GStatsController
extends Control

# TODO (FB): 
# - Add screen positioning, by default the last

# Screen scaling
const REFERENCE_VIEWPORT: Vector2 = Vector2(1920.0, 1080.0)
const BASE_CONTENT_POSITION: Vector2 = Vector2.ZERO
const BASE_CONTENT_SIZE: Vector2 = Vector2(1920.0, 500.0)
const MIN_SCALE: float = 0.01
const MAX_SCALE: float = 4.0

@onready var _content_margin: Control = $ContentMargin
@onready var _notifications: GStatsNotifications = $ContentMargin/ContentRow/Notifications
@onready var _panel: GStatsPanel = $ContentMargin/ContentRow/Stats

var _last_available_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	_pin_to_reference_viewport()
	_register_commands()

func _register_commands() -> void:
	ConsoleCommands.commands.register("/pop_message", {"message": TYPE_STRING, "type": TYPE_INT}, _pop_message, "Pops a message at the top right corner")
	ConsoleCommands.commands.register("/g_stats", {"state": TYPE_BOOL}, _toggle_g_stats, "Opens or closes GSTATS")

func _toggle_g_stats(handler: ConsoleHandler, args: Dictionary) -> void:
	var state: bool = args.get("state", false)
	if state:
		_panel.open_menu()
	else:
		_panel.close_menu()
		
	handler.log_info("STATS", "%s GSTATS!" % ["Enabling" if state else "Disabling"])

func _pop_message(handler: ConsoleHandler, args: Dictionary) -> void:
	var message: String = args.get("message", "")
	var type: GStatsNotifications.NotificationTypes = args.get("type", 0)
	push_notification(message, type)
	handler.log_info("STATS", "Popping up message in GSTATS")

func push_notification(message: String, type: GStatsNotifications.NotificationTypes) -> void:
	if not message.is_empty():
		_notifications.push_notification(message, type)


func _process(_delta: float) -> void:
	var available_size := _get_available_size()
	if available_size != _last_available_size:
		_pin_to_reference_viewport()

#region Scaling
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_pin_to_reference_viewport()


func _pin_to_reference_viewport() -> void:
	var available_size := _get_available_size()
	_last_available_size = available_size

	var reference_scale := minf(
		available_size.x / REFERENCE_VIEWPORT.x,
		available_size.y / REFERENCE_VIEWPORT.y
	)
	var safe_scale := minf(
		available_size.x / BASE_CONTENT_SIZE.x,
		available_size.y / BASE_CONTENT_SIZE.y
	)
	var scale_factor := clampf(minf(reference_scale, safe_scale), MIN_SCALE, MAX_SCALE)

	_content_margin.position = BASE_CONTENT_POSITION * scale_factor
	_content_margin.size = BASE_CONTENT_SIZE
	_content_margin.scale = Vector2.ONE * scale_factor
	_content_margin.pivot_offset = Vector2.ZERO


func _get_available_size() -> Vector2:
	var window := get_window()
	if window != null:
		return window.get_visible_rect().size

	if get_tree() != null and get_tree().root != null:
		return get_tree().root.get_visible_rect().size

	return get_viewport_rect().size
#endregion
