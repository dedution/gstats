class_name GStatsNotifications
extends Control

enum NotificationTypes {INFO = 0, WARN = 1, ERROR = 2, GRADIENT = 3}

const INFO_BG_COLOR: Color = Color(0.031999998, 0.052, 0.08, 0.82)
const INFO_BORDER_COLOR: Color = Color(0.266667, 0.482353, 0.631373, 0.62)
const INFO_TEXT_COLOR: Color = Color(0.94, 0.97, 1.0, 1.0)

const WARN_BG_COLOR: Color = Color(0.231373, 0.176471, 0.0352941, 0.86)
const WARN_BORDER_COLOR: Color = Color(0.945098, 0.72549, 0.239216, 0.75)
const WARN_TEXT_COLOR: Color = Color(1.0, 0.952941, 0.815686, 1.0)

const ERROR_BG_COLOR: Color = Color(0.27451, 0.0627451, 0.0784314, 0.9)
const ERROR_BORDER_COLOR: Color = Color(0.913725, 0.317647, 0.360784, 0.82)
const ERROR_TEXT_COLOR: Color = Color(1.0, 0.890196, 0.901961, 1.0)

const GRADIENT_TEXTURE_SIZE: Vector2 = Vector2(512.0, 80.0)
const GRADIENT_OVERLAY_INSET: float = 1.0
const GRADIENT_CORNER_RADIUS: float = 11.0
const GRADIENT_CORNER_SEGMENTS: int = 5

@export_range(1, 12, 1) var max_visible_notifications: int = 4
@export_range(0.25, 20.0, 0.05) var default_lifetime: float = 5.0
@export_range(0.05, 2.0, 0.05) var enter_duration: float = 0.18
@export_range(0.05, 2.0, 0.05) var fade_duration: float = 0.35
@export var preview_on_ready: bool = false

@export_group("Gradient Theme")
@export var gradient_panel_color: Color = Color(0.052, 0.047, 0.109, 0.92)
@export var gradient_border_color: Color = Color(0.92549, 0.764706, 1.0, 0.94)
@export var gradient_text_color: Color = Color(1.0, 0.956863, 0.992157, 1.0)
@export var gradient_start_color: Color = Color(0.972549, 0.298039, 0.686275, 0.62)
@export var gradient_mid_color: Color = Color(0.556863, 0.372549, 1.0, 0.54)
@export var gradient_end_color: Color = Color(0.223529, 0.831373, 0.972549, 0.62)

@onready var _notification_container: VBoxContainer = $NotificationMarginContainer/NotificationVerticalContainer
@onready var _notification_template: PanelContainer = $NotificationMarginContainer/NotificationVerticalContainer/NotificationTemplate

var _pending_notifications: Array[Dictionary] = []
var _active_notifications: Array[Dictionary] = []


func _ready() -> void:
	_notification_template.visible = false
	_notification_template.modulate = Color(1.0, 1.0, 1.0, 0.0)

	if preview_on_ready:
		push_notification("GSTATS running at full speed!", NotificationTypes.INFO)
		push_notification("Average frame rate is low. Consider analisys.", NotificationTypes.WARN)
		push_notification("Memory limit reached!", NotificationTypes.ERROR)
		push_notification("Gradient theme engaged!", NotificationTypes.GRADIENT)


func _process(_delta: float) -> void:
	if _active_notifications.is_empty():
		_flush_queue()
		return

	var oldest_notification: Dictionary = _active_notifications[0]
	if oldest_notification.get("fading", false):
		return

	oldest_notification["remaining"] = float(oldest_notification.get("remaining", default_lifetime)) - _delta
	_active_notifications[0] = oldest_notification

	if oldest_notification["remaining"] <= 0.0:
		_begin_fade_out(oldest_notification.get("node"))


func push_notification(message: String, message_type: NotificationTypes, lifetime: float = -1.0) -> void:
	var resolved_lifetime := default_lifetime if lifetime <= 0.0 else lifetime
	_pending_notifications.append(
		{
			"message": message,
			"type": message_type,
			"lifetime": resolved_lifetime,
		}
	)
	_flush_queue()


func clear_notifications() -> void:
	_pending_notifications.clear()
	for notification_data in _active_notifications:
		var notification_node = notification_data.get("node")
		if is_instance_valid(notification_node):
			notification_node.queue_free()
	_active_notifications.clear()


func _flush_queue() -> void:
	while _pending_notifications.size() > 0 and _active_notifications.size() < max_visible_notifications:
		var queued_notification: Dictionary = _pending_notifications.pop_front()
		_spawn_notification(
			str(queued_notification.get("message", "")),\
			queued_notification.get("type", NotificationTypes.INFO),
			float(queued_notification.get("lifetime", default_lifetime))
		)


func _spawn_notification(message: String, type: NotificationTypes, lifetime: float) -> void:
	var notification_instance := _notification_template.duplicate(true) as PanelContainer
	if notification_instance == null:
		return

	notification_instance.visible = true
	notification_instance.modulate = Color(1.0, 1.0, 1.0, 0.0)
	notification_instance.scale = Vector2(0.96, 0.96)
	notification_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var message_label := notification_instance.get_node("Message") as Label
	if message_label != null:
		message_label.text = message
		message_label.modulate = _get_notification_text_color(type)

	_notification_container.add_child(notification_instance)

	var panel_override := _apply_notification_panel_colors(notification_instance, type)
	if _is_gradient_notification(type):
		_apply_gradient_theme(notification_instance, message_label, panel_override)

	var notification_data: Dictionary = {
		"node": notification_instance,
		"remaining": lifetime,
		"fading": false,
	}

	_active_notifications.append(notification_data)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification_instance, "modulate:a", 1.0, enter_duration)
	tween.tween_property(notification_instance, "scale", Vector2.ONE, enter_duration)


func _apply_notification_panel_colors(notification_instance: PanelContainer, type: NotificationTypes) -> StyleBoxFlat:
	var panel_style := notification_instance.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style == null:
		return null

	var panel_override := panel_style.duplicate() as StyleBoxFlat
	if panel_override == null:
		return null

	panel_override.bg_color = _get_notification_background_color(type)
	panel_override.border_color = _get_notification_border_color(type)
	notification_instance.add_theme_stylebox_override("panel", panel_override)
	return panel_override


func _get_notification_background_color(type: NotificationTypes) -> Color:
	match type:
		NotificationTypes.WARN:
			return WARN_BG_COLOR
		NotificationTypes.ERROR:
			return ERROR_BG_COLOR
		NotificationTypes.GRADIENT:
			return gradient_panel_color
		_:
			return INFO_BG_COLOR


func _get_notification_border_color(type: NotificationTypes) -> Color:
	match type:
		NotificationTypes.WARN:
			return WARN_BORDER_COLOR
		NotificationTypes.ERROR:
			return ERROR_BORDER_COLOR
		NotificationTypes.GRADIENT:
			return gradient_border_color
		_:
			return INFO_BORDER_COLOR


func _get_notification_text_color(type: NotificationTypes) -> Color:
	match type:
		NotificationTypes.WARN:
			return WARN_TEXT_COLOR
		NotificationTypes.ERROR:
			return ERROR_TEXT_COLOR
		NotificationTypes.GRADIENT:
			return gradient_text_color
		_:
			return INFO_TEXT_COLOR


func _apply_gradient_theme(
	notification_instance: PanelContainer,
	message_label: Label,
	panel_override: StyleBoxFlat
) -> void:
	if message_label != null:
		message_label.modulate = gradient_text_color

	if panel_override != null:
		panel_override.bg_color = gradient_panel_color
		panel_override.border_color = gradient_border_color

	var gradient_overlay := _ensure_gradient_overlay(notification_instance)
	if gradient_overlay != null:
		gradient_overlay.texture = _build_gradient_texture()
		var resize_callable := Callable(self, "_update_gradient_theme_layout").bind(notification_instance)
		if not notification_instance.resized.is_connected(resize_callable):
			notification_instance.resized.connect(resize_callable)
		_update_gradient_theme_layout(notification_instance)
		call_deferred("_update_gradient_theme_layout", notification_instance)


func _ensure_gradient_overlay(notification_instance: PanelContainer) -> Polygon2D:
	var existing_overlay := notification_instance.get_node_or_null("GradientTheme") as Polygon2D
	if existing_overlay != null:
		return existing_overlay

	var gradient_overlay := Polygon2D.new()
	gradient_overlay.name = "GradientTheme"
	notification_instance.add_child(gradient_overlay)
	notification_instance.move_child(gradient_overlay, 0)
	return gradient_overlay


func _build_gradient_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([gradient_start_color, gradient_mid_color, gradient_end_color])
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])

	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill = GradientTexture2D.FILL_LINEAR
	gradient_texture.fill_from = Vector2(0.0, 0.15)
	gradient_texture.fill_to = Vector2(1.0, 0.85)
	gradient_texture.width = int(GRADIENT_TEXTURE_SIZE.x)
	gradient_texture.height = int(GRADIENT_TEXTURE_SIZE.y)
	return gradient_texture


func _is_gradient_notification(type: int) -> bool:
	return type == NotificationTypes.GRADIENT


func _update_gradient_theme_layout(notification_instance: PanelContainer) -> void:
	if not is_instance_valid(notification_instance):
		return

	var gradient_overlay := notification_instance.get_node_or_null("GradientTheme") as Polygon2D
	if gradient_overlay == null:
		return

	var overlay_position := Vector2.ONE * GRADIENT_OVERLAY_INSET
	var overlay_size := notification_instance.size - (Vector2.ONE * GRADIENT_OVERLAY_INSET * 2.0)
	if overlay_size.x <= 0.0 or overlay_size.y <= 0.0:
		return

	var overlay_radius := GRADIENT_CORNER_RADIUS
	var overlay_polygon := _build_rounded_rect_polygon(
		overlay_position,
		overlay_size,
		overlay_radius,
		GRADIENT_CORNER_SEGMENTS
	)
	gradient_overlay.polygon = overlay_polygon
	gradient_overlay.uv = _build_polygon_uvs(overlay_polygon, overlay_position, overlay_size)


func _build_rounded_rect_polygon(
	rect_position: Vector2,
	rect_size: Vector2,
	corner_radius: float,
	corner_segments: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	if corner_radius <= 0.0:
		points.append(rect_position)
		points.append(rect_position + Vector2(rect_size.x, 0.0))
		points.append(rect_position + rect_size)
		points.append(rect_position + Vector2(0.0, rect_size.y))
		return points

	var top_left := rect_position + Vector2(corner_radius, corner_radius)
	var top_right := rect_position + Vector2(rect_size.x - corner_radius, corner_radius)
	var bottom_right := rect_position + rect_size - Vector2(corner_radius, corner_radius)
	var bottom_left := rect_position + Vector2(corner_radius, rect_size.y - corner_radius)

	_append_arc_points(points, top_left, corner_radius, PI, PI * 1.5, corner_segments, false)
	_append_arc_points(points, top_right, corner_radius, PI * 1.5, TAU, corner_segments, true)
	_append_arc_points(points, bottom_right, corner_radius, 0.0, PI * 0.5, corner_segments, true)
	_append_arc_points(points, bottom_left, corner_radius, PI * 0.5, PI, corner_segments, true)
	return points


func _append_arc_points(
	points: PackedVector2Array,
	center: Vector2,
	radius: float,
	start_angle: float,
	end_angle: float,
	segments: int,
	skip_first_point: bool
) -> void:
	for index in range(segments + 1):
		if skip_first_point and index == 0:
			continue

		var weight := float(index) / float(segments)
		var angle := lerpf(start_angle, end_angle, weight)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)


func _build_polygon_uvs(
	points: PackedVector2Array,
	rect_position: Vector2,
	rect_size: Vector2
) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	for point in points:
		var relative_position := point - rect_position
		uvs.append(
			Vector2(
				(relative_position.x / rect_size.x) * GRADIENT_TEXTURE_SIZE.x,
				(relative_position.y / rect_size.y) * GRADIENT_TEXTURE_SIZE.y
			)
		)
	return uvs


func _begin_fade_out(notification_node: Variant) -> void:
	if not is_instance_valid(notification_node):
		_remove_notification_entry(notification_node)
		_flush_queue()
		return

	for index in range(_active_notifications.size()):
		var notification_data: Dictionary = _active_notifications[index]
		if notification_data.get("node") == notification_node:
			if notification_data.get("fading", false):
				return
			notification_data["fading"] = true
			_active_notifications[index] = notification_data
			break

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification_node, "modulate:a", 0.0, fade_duration)
	tween.tween_property(notification_node, "scale", Vector2(0.96, 0.96), fade_duration)
	tween.finished.connect(_finalize_notification.bind(notification_node), CONNECT_ONE_SHOT)


func _finalize_notification(notification_node: Variant) -> void:
	_remove_notification_entry(notification_node)

	if is_instance_valid(notification_node):
		notification_node.queue_free()

	_flush_queue()


func _remove_notification_entry(notification_node: Variant) -> void:
	for index in range(_active_notifications.size()):
		if _active_notifications[index].get("node") == notification_node:
			_active_notifications.remove_at(index)
			return
