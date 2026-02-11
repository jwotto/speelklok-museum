@tool
extends Node2D
class_name BodyShape

## Genereert een muziekkast-silhouet als Polygon2D
## De vorm wordt bepaald door 4 parameters: dak, buik, rok, kleur

@export_group("Shape Parameters")
## Dak: 0.0 = plat, 0.5 = rond (koepel), 1.0 = spits
@export_range(0.0, 1.0) var dak: float = 0.5:
	set(v):
		dak = v
		_update_shape()
## Buik: 0.0 = ingedeukt, 0.5 = recht, 1.0 = bollend
@export_range(0.0, 1.0) var buik: float = 0.5:
	set(v):
		buik = v
		_update_shape()
## Rok: 0.0 = taps toelopend, 0.5 = recht, 1.0 = uitlopend
@export_range(0.0, 1.0) var rok: float = 0.5:
	set(v):
		rok = v
		_update_shape()
## Kleur: hue waarde (0.0 - 1.0 over het kleurspectrum)
@export_range(0.0, 1.0) var kleur: float = 0.5:
	set(v):
		kleur = v
		_update_color()

@export_group("Dimensions")
## Breedte van de kast in pixels
@export var shape_width: float = 900.0:
	set(v):
		shape_width = v
		_update_shape()
## Hoogte van de kast in pixels
@export var shape_height: float = 850.0:
	set(v):
		shape_height = v
		_update_shape()
## Maximale buik-uitbuiging in pixels
@export var max_belly_offset: float = 100.0:
	set(v):
		max_belly_offset = v
		_update_shape()
## Maximale rok-verbreding in pixels
@export var max_flare_offset: float = 120.0:
	set(v):
		max_flare_offset = v
		_update_shape()

@export_group("Smoothing")
## Hoekafronding in pixels. 0 = scherp, 50+ = mooi rond
@export_range(0.0, 200.0) var corner_radius: float = 60.0:
	set(v):
		corner_radius = v
		_update_shape()

@export_group("Appearance")
## Verzadiging van de vulkleur
@export_range(0.0, 1.0) var color_saturation: float = 0.65
## Helderheid van de vulkleur
@export_range(0.0, 1.0) var color_value: float = 0.92
## Kleur van de contourlijn
@export var outline_color: Color = Color(0.15, 0.1, 0.05, 0.8):
	set(v):
		outline_color = v
		_update_outline_color()
## Dikte van de contourlijn
@export var outline_width: float = 6.0:
	set(v):
		outline_width = v
		if _shape_outline:
			_shape_outline.width = outline_width

@onready var _shape_fill: Polygon2D = $ShapeFill
@onready var _shape_outline: Line2D = $ShapeOutline
@onready var _decoration: Node2D = $BodyDecoration


func _ready() -> void:
	_update_shape()
	_update_color()


func _update_shape() -> void:
	if not _shape_fill or not _shape_outline:
		return
	var pts = _generate_points()
	pts = _deduplicate(pts)
	if corner_radius > 0.0:
		pts = _round_corners(pts, corner_radius)
	_shape_fill.polygon = pts
	# Outline: sluit de loop door eerste punt toe te voegen
	var outline_pts = pts.duplicate()
	outline_pts.append(pts[0])
	_shape_outline.points = outline_pts
	_shape_outline.width = outline_width
	_update_decoration()


func _update_color() -> void:
	if not _shape_fill:
		return
	_shape_fill.color = Color.from_hsv(kleur, color_saturation, color_value)
	_update_decoration()


func _update_decoration() -> void:
	if not _decoration or not _shape_fill:
		return
	_decoration.update_decoration(
		_shape_fill.polygon,
		Color.from_hsv(kleur, color_saturation, color_value),
		shape_height
	)


func _update_outline_color() -> void:
	if _shape_outline:
		_shape_outline.default_color = outline_color


func get_polygon() -> PackedVector2Array:
	## Geeft de huidige polygon punten terug (voor gebruik door andere fases)
	if _shape_fill:
		return _shape_fill.polygon
	return PackedVector2Array()


func _deduplicate(pts: PackedVector2Array) -> PackedVector2Array:
	## Verwijdert opeenvolgende dubbele punten (zone-overgangen delen eindpunten)
	var n = pts.size()
	var result = PackedVector2Array()
	for i in n:
		if pts[i].distance_to(pts[(i + 1) % n]) > 0.01:
			result.append(pts[i])
	return result


func _round_corners(pts: PackedVector2Array, radius: float) -> PackedVector2Array:
	## Vervangt scherpe hoeken door quadratische Bezier curves
	var n = pts.size()
	if n < 3 or radius <= 0.0:
		return pts
	var result = PackedVector2Array()
	var segments = 6
	for i in n:
		var prev = pts[(i - 1 + n) % n]
		var curr = pts[i]
		var next_pt = pts[(i + 1) % n]
		var to_prev = prev - curr
		var to_next = next_pt - curr
		var dist_prev = to_prev.length()
		var dist_next = to_next.length()
		if dist_prev < 0.001 or dist_next < 0.001:
			result.append(curr)
			continue
		# Hoek bijna recht? Gewoon punt toevoegen
		var dot = to_prev.normalized().dot(to_next.normalized())
		if dot < -0.999:
			result.append(curr)
			continue
		var r = minf(radius, minf(dist_prev, dist_next) * 0.5)
		var start = curr + to_prev.normalized() * r
		var end = curr + to_next.normalized() * r
		# Quadratische Bezier: start -> curr (control point) -> end
		for j in range(segments + 1):
			var t = float(j) / float(segments)
			var a = start.lerp(curr, t)
			var b = curr.lerp(end, t)
			result.append(a.lerp(b, t))
	return result


func _generate_points() -> PackedVector2Array:
	## Berekent alle polygon punten op basis van de 4 parameters
	var points: PackedVector2Array = []
	var half_w = shape_width / 2.0
	var shoulder_y = shape_height * 0.25
	var hip_y = shape_height * 0.75
	var base_y = shape_height
	var dak_height = shoulder_y

	# --- RECHTS: van top-center naar rechtsonder ---

	# Dak: 9 punten van center naar rechterrand
	for i in range(9):
		var x_norm = float(i) / 8.0
		var x = x_norm * half_w
		var y_offset = _dak_y(x_norm) * dak_height
		points.append(Vector2(x, shoulder_y - y_offset))

	# Buik: 7 punten van schouder naar heup (rechterzijde)
	for i in range(7):
		var t = float(i) / 6.0
		var y = lerpf(shoulder_y, hip_y, t)
		var x_offset = _buik_x_offset(t)
		points.append(Vector2(half_w + x_offset, y))

	# Rok: 5 punten van heup naar basis (rechterzijde)
	var hip_x_right = half_w + _buik_x_offset(1.0)
	var bottom_half_w = _rok_bottom_half_width()
	for i in range(5):
		var t = float(i) / 4.0
		var y = lerpf(hip_y, base_y, t)
		var x = lerpf(hip_x_right, bottom_half_w, t)
		points.append(Vector2(x, y))

	# Basislijn: rechts naar links
	points.append(Vector2(bottom_half_w, base_y))
	points.append(Vector2(-bottom_half_w, base_y))

	# --- LINKS: van linksonder terug naar top-center (spiegeling) ---

	# Rok (gespiegeld, van basis naar heup)
	var hip_x_left = -(half_w + _buik_x_offset(1.0))
	for i in range(4, -1, -1):
		var t = float(i) / 4.0
		var y = lerpf(hip_y, base_y, t)
		var x = lerpf(hip_x_left, -bottom_half_w, t)
		points.append(Vector2(x, y))

	# Buik (gespiegeld, van heup naar schouder)
	for i in range(6, -1, -1):
		var t = float(i) / 6.0
		var y = lerpf(shoulder_y, hip_y, t)
		var x_offset = _buik_x_offset(t)
		points.append(Vector2(-half_w - x_offset, y))

	# Dak (gespiegeld, van linkerrand terug naar center)
	for i in range(8, -1, -1):
		var x_norm = float(i) / 8.0
		var x = -x_norm * half_w
		var y_offset = _dak_y(x_norm) * dak_height
		points.append(Vector2(x, shoulder_y - y_offset))

	return points


func _dak_y(x_norm: float) -> float:
	## Berekent de relatieve hoogte van het dak op positie x_norm (0=center, 1=rand)
	## Retourneert 0..1 die vermenigvuldigd wordt met dak_height
	var abs_x = absf(x_norm)
	var flat_y = 1.0
	var spits_y = 1.0 - abs_x
	var round_y = sqrt(maxf(0.0, 1.0 - abs_x * abs_x))

	if dak <= 0.5:
		var t = dak * 2.0
		return lerpf(flat_y, spits_y, t)
	else:
		var t = (dak - 0.5) * 2.0
		return lerpf(spits_y, round_y, t)


func _buik_x_offset(t_norm: float) -> float:
	## Berekent horizontale offset voor buikpunten
	## t_norm: 0.0 (schouder) tot 1.0 (heup)
	## Positief = naar buiten
	var belly_amount = (buik - 0.5) * 2.0
	var curve = sin(t_norm * PI)
	return belly_amount * curve * max_belly_offset


func _rok_bottom_half_width() -> float:
	## Berekent de halve breedte van de onderkant
	var flare = (rok - 0.5) * 2.0
	var half_w = shape_width / 2.0
	return half_w + flare * max_flare_offset
