@tool
extends Control
class_name StickerSlider

## Verticale slider met icoon in de thumb
## Gebruik voor rotatie en schaal besturing van stickers

signal value_changed(new_value: float)

enum IconType { ROTATE, SCALE }

## Welk icoon wordt getoond in de thumb: draai-pijl of schaal-pijlen
@export var icon_type: IconType = IconType.ROTATE:
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
## Lengte van de sleeplijn in pixels (totale control hoogte = track_length + 2x thumb_radius)
@export var track_length: float = 200.0:
	set(v):
		track_length = v
		_update_minimum_size()
		queue_redraw()
## Kleur van de verticale lijn waarover de thumb beweegt
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
## Straal van de ronde thumb in pixels (bepaalt ook de marge boven/onder de track)
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
## Kleur van het icoon dat in de thumb wordt getekend
@export var icon_color: Color = Color(0.25, 0.25, 0.25):
	set(v):
		icon_color = v
		queue_redraw()
## Lijndikte van het icoon in pixels
@export var icon_line_width: float = 2.5:
	set(v):
		icon_line_width = v
		queue_redraw()
## Grootte van het icoon als fractie van de thumb straal (0.1 = klein, 1.0 = vult hele thumb)
@export_range(0.1, 1.0) var icon_scale: float = 0.45:
	set(v):
		icon_scale = v
		queue_redraw()
## Grootte van de pijlpunten in pixels
@export var icon_arrow_size: float = 8.0:
	set(v):
		icon_arrow_size = v
		queue_redraw()

var _dragging: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_minimum_size()


func _update_minimum_size() -> void:
	## Pas minimum grootte aan zodat track_length + thumb past
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
	var r = thumb_radius * icon_scale
	var points: PackedVector2Array = []
	for i in range(9):
		var angle = deg_to_rad(-90.0 + i * 30.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	# Exacte tangent (reisrichting) aan de boog op het eindpunt
	var last_angle = deg_to_rad(-90.0 + 8 * 30.0)
	var travel = Vector2(-sin(last_angle), cos(last_angle))
	var perp = Vector2(-travel.y, travel.x)
	var arrow_width = icon_arrow_size * 0.625
	var curve_end = points[points.size() - 1]
	# Pijlpunt steekt voorbij de boog uit in de reisrichting
	var arrow_tip = curve_end + travel * icon_arrow_size
	draw_polyline(points, icon_color, icon_line_width)
	# Driehoek: smalle punt in reisrichting, brede basis op het boog-eindpunt
	draw_polygon(
		PackedVector2Array([arrow_tip, curve_end + perp * arrow_width, curve_end - perp * arrow_width]),
		PackedColorArray([icon_color])
	)


func _draw_scale_icon(center: Vector2) -> void:
	## Diagonale dubbele pijl icoon (schalen)
	var r = thumb_radius * icon_scale
	var p1 = center + Vector2(-r, -r)
	var p2 = center + Vector2(r, r)
	var dir = (p2 - p1).normalized()
	var arrow = icon_arrow_size * 0.875
	# Basis-midden van de rechte driehoek zit op arrow / sqrt(2) afstand van de tip
	var base_inset = arrow / sqrt(2.0)
	# Kort de lijn in tot het midden van beide pijlpunt-bases
	draw_line(p1 + dir * base_inset, p2 - dir * base_inset, icon_color, icon_line_width)
	draw_polygon(
		PackedVector2Array([p1, p1 + Vector2(arrow, 0), p1 + Vector2(0, arrow)]),
		PackedColorArray([icon_color])
	)
	draw_polygon(
		PackedVector2Array([p2, p2 - Vector2(arrow, 0), p2 - Vector2(0, arrow)]),
		PackedColorArray([icon_color])
	)


func _gui_input(event: InputEvent) -> void:
	## Muis input (via Godot GUI systeem)
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
	var top_y = (size.y - track_length) / 2.0
	var bottom_y = top_y + track_length
	var t = 1.0 - clampf((local_y - top_y) / (bottom_y - top_y), 0.0, 1.0)
	var new_val = lerpf(min_value, max_value, t)
	var old_val = value
	value = new_val
	if absf(value - old_val) > 0.001:
		value_changed.emit(value)
