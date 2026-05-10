class_name StatsNotifications
extends Control

@export_range(1, 12, 1) var max_visible_notifications: int = 5
@export_range(0.25, 20.0, 0.05) var default_duration: float = 5.0
@export_range(0.05, 2.0, 0.05) var enter_duration: float = 0.18
@export_range(0.05, 2.0, 0.05) var fade_duration: float = 0.35

@export var _notification_template: StatsNotification
@onready
var _notification_container: VBoxContainer = $NotificationMarginContainer/NotificationVerticalContainer
var _active_notifications: Array[StatsNotification] = []


func _ready() -> void:
	_notification_template.visible = false
	_notification_template.modulate = Color(1.0, 1.0, 1.0, 0.0)


#region Public


func push_notification(
	message: String, message_type: StatsNotification.NotificationTypes, duration: float = -1.0
) -> void:
	_spawn_notification(message, message_type, default_duration if duration <= 0.0 else duration)
	_flush_queue()


func clear_all_notifications() -> void:
	while _active_notifications.size() > 0:
		var notification := _active_notifications.front()
		_destroy_notification(notification)


#endregion

#region Private


## Get rid of the older active notifications outside the limit
func _flush_queue() -> void:
	while _active_notifications.size() > max_visible_notifications:
		var notification := _active_notifications.front()
		_destroy_notification(notification)


func _spawn_notification(
	message: String, type: StatsNotification.NotificationTypes, duration: float
) -> void:
	if _notification_template == null:
		return

	var notification := _notification_template.duplicate() as StatsNotification
	if notification == null:
		push_warning("Failed to duplicate stats notification template with its script attached.")
		return

	_notification_container.add_child(notification)
	_active_notifications.append(notification)

	notification.set_message(message, type, duration, _fade_out_notification.bind(notification))
	notification.fadein(enter_duration)


func _fade_out_notification(notification: StatsNotification) -> void:
	if !notification:
		_active_notifications.erase(notification)
		return

	notification.fadeout(fade_duration, _destroy_notification.bind(notification))


func _destroy_notification(notification: StatsNotification) -> void:
	if notification:
		notification.queue_free()

	_active_notifications.erase(notification)

#endregion
