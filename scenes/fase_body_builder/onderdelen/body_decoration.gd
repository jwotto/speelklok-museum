@tool
extends Node2D

## Tekent getekende houttexturen per zone binnen de muziekkast-contour.
## De zone-texturen (kop, nek, buik, rok) bevatten al decoraties (panelen, sierlijsten).
## Kleur wordt aangepast via een hue-shift shader (draait de kleur, geen overlay).

var _polygon: PackedVector2Array = PackedVector2Array()
var _base_color: Color = Color.WHITE
var _shape_height: float = 1050.0
var _neck_y: float = 212.5
var _shoulder_y: float = 312.5
var _hip_y: float = 937.5

## Zone polygon cache
var _zones_dirty: bool = true
var _cached_kop_poly: PackedVector2Array
var _cached_nek_poly: PackedVector2Array
var _cached_lichaam_poly: PackedVector2Array
var _cached_rok_poly: PackedVector2Array

var _shader_material: ShaderMaterial

## ═══════════════════════════════════════════════════════════════════════
## ZONE TEXTUREN
## ═══════════════════════════════════════════════════════════════════════

@export_group("Zone Texturen")
@export var kop_texture: Texture2D = preload("res://assets/kast/zones/kop.png"):
	set(v):
		kop_texture = v
		queue_redraw()
@export var nek_texture: Texture2D = preload("res://assets/kast/zones/nek.png"):
	set(v):
		nek_texture = v
		queue_redraw()
@export var buik_texture: Texture2D = preload("res://assets/kast/zones/buik.png"):
	set(v):
		buik_texture = v
		queue_redraw()
@export var rok_texture: Texture2D = preload("res://assets/kast/zones/rok.png"):
	set(v):
		rok_texture = v
		queue_redraw()

## Eén textuur over de hele kast (overschrijft zone-texturen als gezet)
@export var full_texture: Texture2D = null:
	set(v):
		full_texture = v
		queue_redraw()


func _ready() -> void:
	_setup_shader()
	_apply_hue_shift()


func _setup_shader() -> void:
	var shader = preload("res://shaders/hue_shift.gdshader")
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	material = _shader_material


func update_decoration(polygon: PackedVector2Array, base_color: Color, shape_height: float, neck_y: float, shoulder_y: float, hip_y: float) -> void:
	_polygon = polygon
	_base_color = base_color
	_shape_height = shape_height
	_neck_y = neck_y
	_shoulder_y = shoulder_y
	_hip_y = hip_y
	_zones_dirty = true
	_apply_hue_shift()
	queue_redraw()


func update_color(base_color: Color) -> void:
	_base_color = base_color
	_apply_hue_shift()


func _apply_hue_shift() -> void:
	if not _shader_material:
		return
	## Slider 0.5 = origineel hout (geen shift), links/rechts = kleurshift
	var shift: float = (_base_color.h - 0.5) * 360.0
	_shader_material.set_shader_parameter("hue_shift", shift)


func _draw() -> void:
	if _polygon.size() < 3:
		return
	_ensure_zone_cache()
	_draw_zone_textures()


# ── Zone texturen (gestrekt) ────────────────────────────────────────

func _draw_zone_textures() -> void:
	if full_texture:
		## Eén textuur over de hele kast
		_draw_stretched_texture(_polygon, full_texture)
	else:
		## Per-zone texturen
		_draw_stretched_texture(_cached_kop_poly, kop_texture)
		_draw_stretched_texture(_cached_nek_poly, nek_texture)
		_draw_stretched_texture(_cached_lichaam_poly, buik_texture)
		_draw_stretched_texture(_cached_rok_poly, rok_texture)


func _draw_stretched_texture(zone_poly: PackedVector2Array, tex: Texture2D) -> void:
	if zone_poly.size() < 3 or not tex:
		return

	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for p in zone_poly:
		min_p = Vector2(minf(min_p.x, p.x), minf(min_p.y, p.y))
		max_p = Vector2(maxf(max_p.x, p.x), maxf(max_p.y, p.y))
	var sz := max_p - min_p
	if sz.x < 1.0 or sz.y < 1.0:
		return

	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for p in zone_poly:
		uvs.append((p - min_p) / sz)
		colors.append(Color.WHITE)

	draw_polygon(zone_poly, colors, uvs, tex)


# ── Zone polygon cache ──────────────────────────────────────────────

func _ensure_zone_cache() -> void:
	if not _zones_dirty:
		return
	_cached_kop_poly = _clip_polygon_to_band(0.0, _neck_y)
	_cached_nek_poly = _clip_polygon_to_band(_neck_y, _shoulder_y)
	_cached_lichaam_poly = _clip_polygon_to_band(_shoulder_y, _hip_y)
	_cached_rok_poly = _clip_polygon_to_band(_hip_y, _shape_height)
	_zones_dirty = false


# ── Helpers ──────────────────────────────────────────────────────────

func _clip_polygon_to_band(y_min: float, y_max: float) -> PackedVector2Array:
	var clipped: PackedVector2Array = _clip_below(_polygon, y_max)
	return _clip_above(clipped, y_min)


func _clip_below(poly: PackedVector2Array, y_max: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var n: int = poly.size()
	if n < 3:
		return result
	for i in n:
		var c: Vector2 = poly[i]
		var nx: Vector2 = poly[(i + 1) % n]
		var c_in: bool = c.y <= y_max
		var n_in: bool = nx.y <= y_max
		if c_in:
			result.append(c)
		if c_in != n_in and absf(nx.y - c.y) > 0.001:
			var t: float = (y_max - c.y) / (nx.y - c.y)
			result.append(c.lerp(nx, t))
	return result


func _clip_above(poly: PackedVector2Array, y_min: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var n: int = poly.size()
	if n < 3:
		return result
	for i in n:
		var c: Vector2 = poly[i]
		var nx: Vector2 = poly[(i + 1) % n]
		var c_in: bool = c.y >= y_min
		var n_in: bool = nx.y >= y_min
		if c_in:
			result.append(c)
		if c_in != n_in and absf(nx.y - c.y) > 0.001:
			var t: float = (y_min - c.y) / (nx.y - c.y)
			result.append(c.lerp(nx, t))
	return result
