@tool
extends Control
class_name BodySlider

## Verticale slider met icoon in de thumb
## Gebruik voor dak, buik, rok en kleur besturing van de body shape

signal value_changed(new_value: float)

enum IconType { DAK, BUIK, ROK, KLEUR }

## Welk icoon wordt getoond in de thumb
@export var icon_type: IconType = IconType.DAK:
	set(v):
		icon_type = v
		queue_redraw()

@export_group("Value")
## Ondergrens van de slider
@export var min_value: float = 0.0
## Bovengrens van de slider
@export var max_value: float = 1.0
## Huidige waarde (wordt geclampt tussen min en max)
@export var value: float = 0.5:
	set(v):
		value = clampf(v, min_value, max_value)
		queue_redraw()

@export_group("Track")
## Lengte van de sleeplijn in pixels
@export var track_length: float = 200.0:
	set(v):
		track_length = v
		_update_minimum_size()
		queue_redraw()
## Kleur van de verticale lijn
@export var track_color: Color = Color(1, 1, 1, 0.3):
	set(v):
		track_color = v
		queue_redraw()
## Dikte van de track lijn in pixels
@export var track_width: float = 4.0:
	set(v):
		track_width = v
		queue_redraw()

@export_group("Thumb")
## Straal van de ronde thumb in pixels
@export var thumb_radius: float = 30.0:
	set(v):
		thumb_radius = v
		_update_minimum_size()
		queue_redraw()
## Vulkleur van de thumb cirkel
@export var thumb_color: Color = Color.WHITE:
	set(v):
		thumb_color = v
		queue_redraw()

@export_group("Icon")
## Kleur van het icoon in de thumb
@export var icon_color: Color = Color(0.25, 0.25, 0.25):
	set(v):
		icon_color = v
		queue_redraw()
## Lijndikte van het icoon in pixels
@export var icon_line_width: float = 2.5:
	set(v):
		icon_line_width = v
		queue_redraw()
## Grootte van het icoon als fractie van de thumb straal
@export_range(0.1, 1.0) var icon_scale: float = 0.45:
	set(v):
		icon_scale = v
		queue_redraw()

var _dragging: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_minimum_size()


func _update_minimum_size() -> void:
	custom_minimum_size = Vector2(thumb_radius * 2.0, track_length + thumb_radius * 2.0)


func _draw() -> void:
	var cx = size.x / 2.0
	var top_y = (size.y - track_length) / 2.0
	var bottom_y = top_y + track_length

	# Track
	draw_line(Vector2(cx, top_y), Vector2(cx, bottom_y), track_color, track_width, true)

	# Thumb positie gebaseerd op value
	var t = inverse_lerp(min_value, max_value, value) if max_value > min_value else 0.5
	var thumb_y = lerpf(bottom_y, top_y, t)
	var thumb_pos = Vector2(cx, thumb_y)

	# Thumb cirkel — kleur-slider thumb past mee met de hue
	var draw_color = Color.from_hsv(value, 0.7, 0.95) if icon_type == IconType.KLEUR else thumb_color
	draw_circle(thumb_pos, thumb_radius, draw_color)

	# Icoon in de thumb
	match icon_type:
		IconType.DAK:
			_draw_dak_icon(thumb_pos)
		IconType.BUIK:
			_draw_buik_icon(thumb_pos)
		IconType.ROK:
			_draw_rok_icon(thumb_pos)
		IconType.KLEUR:
			_draw_kleur_icon(thumb_pos)


func _draw_dak_icon(center: Vector2) -> void:
	## Dakje-silhouet: horizontale lijn + puntdak (^)
	var r = thumb_radius * icon_scale
	# Platte basis
	draw_line(center + Vector2(-r, r * 0.4), center + Vector2(r, r * 0.4), icon_color, icon_line_width)
	# Schuin dak
	draw_line(center + Vector2(-r, r * 0.4), center + Vector2(0, -r * 0.7), icon_color, icon_line_width)
	draw_line(center + Vector2(r, r * 0.4), center + Vector2(0, -r * 0.7), icon_color, icon_line_width)


func _draw_buik_icon(center: Vector2) -> void:
	## Twee gebogen lijnen )( die buiging tonen
	var r = thumb_radius * icon_scale
	var points_left: PackedVector2Array = []
	var points_right: PackedVector2Array = []
	for i in range(9):
		var t = float(i) / 8.0
		var y = center.y + lerpf(-r, r, t)
		var bulge = sin(t * PI) * r * 0.4
		points_left.append(Vector2(center.x - r * 0.3 - bulge, y))
		points_right.append(Vector2(center.x + r * 0.3 + bulge, y))
	draw_polyline(points_left, icon_color, icon_line_width)
	draw_polyline(points_right, icon_color, icon_line_width)


func _draw_rok_icon(center: Vector2) -> void:
	## Trapezium: smal boven, breed onder (rok/skirt)
	var r = thumb_radius * icon_scale
	# Bovenlijn (smal)
	draw_line(center + Vector2(-r * 0.3, -r), center + Vector2(r * 0.3, -r), icon_color, icon_line_width)
	# Linker schuine lijn
	draw_line(center + Vector2(-r * 0.3, -r), center + Vector2(-r, r), icon_color, icon_line_width)
	# Rechter schuine lijn
	draw_line(center + Vector2(r * 0.3, -r), center + Vector2(r, r), icon_color, icon_line_width)
	# Onderlijn (breed)
	draw_line(center + Vector2(-r, r), center + Vector2(r, r), icon_color, icon_line_width)


func _draw_kleur_icon(center: Vector2) -> void:
	## Kleurenwiel: 12 taartpunten in regenboogkleuren
	var r = thumb_radius * icon_scale * 0.8
	var segments = 12
	for i in range(segments):
		var angle_start = TAU * float(i) / segments
		var angle_end = TAU * float(i + 1) / segments
		var color = Color.from_hsv(float(i) / segments, 0.8, 0.9)
		var tri: PackedVector2Array = [
			center,
			center + Vector2(cos(angle_start), sin(angle_start)) * r,
			center + Vector2(cos(angle_end), sin(angle_end)) * r,
		]
		draw_polygon(tri, PackedColorArray([color, color, color]))


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
	var top_y = (size.y - track_length) / 2.0
	var bottom_y = top_y + track_length
	var t = 1.0 - clampf((local_y - top_y) / (bottom_y - top_y), 0.0, 1.0)
	var new_val = lerpf(min_value, max_value, t)
	var old_val = value
	value = new_val
	if absf(value - old_val) > 0.001:
		value_changed.emit(value)
