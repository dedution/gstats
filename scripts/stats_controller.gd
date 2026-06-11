class_name StatsController
extends Control

# Screen scaling
const REFERENCE_VIEWPORT: Vector2 = Vector2(1920.0, 1080.0)
const BASE_CONTENT_POSITION: Vector2 = Vector2.ZERO
const BASE_CONTENT_SIZE: Vector2 = Vector2(1920.0, 500.0)
const MIN_SCALE: float = 0.01
const MAX_SCALE: float = 4.0

## Convert them into export vars for better control
@onready var _content_margin: Control = $ContentMargin
@onready var _panel: StatsPanel = $ContentMargin/ContentRow/StatsPanel
@onready var _notifications: StatsNotifications = $ContentMargin/ContentRow/Notifications
@onready var _service_warning: Control = $ServiceWarning

var _last_available_size: Vector2 = Vector2.ZERO
var _cmd_memory_chunks := []

func _ready() -> void:
	_adjust_content_size()
	_register_commands()
	_panel.set_panel_state(false)


func _register_commands() -> void:
	ConsoleCommands.commands.register(
		"/stats_message",
		{"message": TYPE_STRING, "type": TYPE_INT},
		_cmd_pop_message,
		"Pops a stats message at the top right corner"
	)
	
	ConsoleCommands.commands.register(
		"/simulate_crash",
		{},
		_cmd_simulate_crash,
		"Simulates a system crash"
	)
	
	ConsoleCommands.commands.register(
		"/simulate_leak",
		{},
		_cmd_simulate_memory_leak,
		"Simulates a memory leak that increases ram 100MB per frame"
	)


func _cmd_pop_message(handler: ConsoleHandler, args: Dictionary) -> void:
	var message: String = args.get("message", "")
	var type: StatsNotification.NotificationTypes = args.get("type", 0)
	push_notification(message, type)
	handler.log_info("STATS", "Notifying via stats")


func _cmd_simulate_crash(handler: ConsoleHandler) -> void:
	for i in range(3, 0, -1):
		var suffix := "second" if i == 1 else "seconds"
		handler.log_info("STATS", "Crashing in %d %s..." % [i, suffix])

		if i > 1:
			await get_tree().create_timer(1.0).timeout

	# Simulate crash
	OS.crash("Simulated crash")
	
	
func _cmd_simulate_memory_leak(handler: ConsoleHandler) -> void:
	for i in range(3, 0, -1):
		var suffix := "second" if i == 1 else "seconds"
		handler.log_info("STATS", "Starting leak in %d %s..." % [i, suffix])

		if i > 1:
			await get_tree().create_timer(1.0).timeout
			
	var allocated_mb := 0

	while true:
		var chunk := PackedByteArray()
		chunk.resize(1024 * 1024)
		chunk.fill(255)

		_cmd_memory_chunks.append(chunk)
		allocated_mb += 1

		if allocated_mb % 100 == 0:
			handler.log_info(
				"STATS",
				"Allocated %d MB" % allocated_mb
			)

			await get_tree().process_frame


func set_service_mode(state: bool) -> void:
	_service_warning.visible = state


## Push notification
func push_notification(message: String, type: StatsNotification.NotificationTypes) -> void:
	if not message.is_empty():
		_notifications.push_notification(message, type)


func _process(_delta: float) -> void:
	var available_size := _get_available_size()
	if available_size != _last_available_size:
		_adjust_content_size()

func _input(event) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		_panel.set_panel_state(!_panel.get_panel_state())

#region Scaling
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_adjust_content_size()


func _adjust_content_size() -> void:
	var available_size := _get_available_size()
	_last_available_size = available_size

	var reference_scale := minf(
		available_size.x / REFERENCE_VIEWPORT.x, available_size.y / REFERENCE_VIEWPORT.y
	)
	var safe_scale := minf(
		available_size.x / BASE_CONTENT_SIZE.x, available_size.y / BASE_CONTENT_SIZE.y
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
