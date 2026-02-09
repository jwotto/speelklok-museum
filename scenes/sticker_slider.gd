@tool
extends Control
class_name StickerSlider

## Verticale slider met icoon in de thumb
## Gebruik voor rotatie en schaal besturing van stickers

signal value_changed(new_value: float)

enum IconType { ROTATE, SCALE }

@export var icon_type: IconType = IconType.ROTATE:
	set(v):
		icon_type = v
		queue_redraw()

@export var min_value: float = 0.0
@export var max_value: float = 1.0
@export var value: float = 0.5:
	set(v):
		value = clampf(v, min_value, max_value)
		queue_redraw()

@export_group("Appearance")
@export var thumb_radius: float = 30.0:
	set(v):
		thumb_radius = v
		queue_redraw()
@export var track_color: Color = Color(1, 1, 1, 0.3):
	set(v):
		track_color = v
		queue_redraw()
@export var thumb_color: Color = Color.WHITE:
	set(v):
		thumb_color = v
		queue_redraw()
@export var icon_color: Color = Color(0.25, 0.25, 0.25):
	set(v):
		icon_color = v
		queue_redraw()
@export var track_width: float = 4.0:
	set(v):
		track_width = v
		queue_redraw()

var _dragging: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	var cx = size.x / 2.0
	var top_y = thumb_radius
	var bottom_y = size.y - thumb_radius

	# Track
	draw_line(Vector2(cx, top_y), Vector2(cx, bottom_y), track_color, track_width, true)

	# Thumb positie gebaseerd op value
	var t = inverse_lerp(min_value, max_value, value) if max_value > min_value else 0.5
	var thumb_y = lerpf(bottom_y, top_y, t)
	var thumb_pos = Vector2(cx, thumb_y)

	# Witte cirkel
	draw_circle(thumb_pos, thumb_radius, thumb_color)

	# Icoon in de thumb
	match icon_type:
		IconType.ROTATE:
			_draw_rotate_icon(thumb_pos)
		IconType.SCALE:
			_draw_scale_icon(thumb_pos)


func _draw_rotate_icon(center: Vector2) -> void:
	## Gebogen pijl icoon (draaien)
	var r = thumb_radius * 0.45
	var points: PackedVector2Array = []
	for i in range(9):
		var angle = deg_to_rad(-90.0 + i * 30.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_polyline(points, icon_color, 2.5)
	# Pijlpunt
	var tip = points[points.size() - 1]
	var prev = points[points.size() - 2]
	var dir = (tip - prev).normalized()
	var perp = Vector2(-dir.y, dir.x)
	draw_polygon(
		PackedVector2Array([tip, tip - dir * 8 + perp * 5, tip - dir * 8 - perp * 5]),
		PackedColorArray([icon_color])
	)


func _draw_scale_icon(center: Vector2) -> void:
	## Diagonale dubbele pijl icoon (schalen)
	var r = thumb_radius * 0.4
	var p1 = center + Vector2(-r, -r)
	var p2 = center + Vector2(r, r)
	draw_line(p1, p2, icon_color, 2.5)
	var arrow = 7.0
	draw_polygon(
		PackedVector2Array([p1, p1 + Vector2(arrow, 0), p1 + Vector2(0, arrow)]),
		PackedColorArray([icon_color])
	)
	draw_polygon(
		PackedVector2Array([p2, p2 - Vector2(arrow, 0), p2 - Vector2(0, arrow)]),
		PackedColorArray([icon_color])
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = true
			_update_from_position(event.position.y)
			accept_event()
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_update_from_position(event.position.y)
		accept_event()


func _update_from_position(local_y: float) -> void:
	## Bereken nieuwe value uit thumb positie
	var top_y = thumb_radius
	var bottom_y = size.y - thumb_radius
	var t = 1.0 - clampf((local_y - top_y) / (bottom_y - top_y), 0.0, 1.0)
	var new_val = lerpf(min_value, max_value, t)
	var old_val = value
	value = new_val
	if absf(value - old_val) > 0.001:
		value_changed.emit(value)
