extends Node2D

## Tekent de orgel-contour als achtergrond in de sticker fase
## Gevuld met basekleur + houttextuur overlay + outline

var _polygon: PackedVector2Array = PackedVector2Array()
var _color: Color = Color.WHITE
var _wood_texture: Texture2D
var _texture_scale: float = 3.0
var _texture_opacity: float = 0.3
var _outline_color: Color = Color(0.15, 0.1, 0.05, 0.6)
var _outline_width: float = 5.0


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func setup(polygon: PackedVector2Array, color: Color) -> void:
	_polygon = polygon
	_color = color
	_wood_texture = preload("res://textures/wood texture.png")
	queue_redraw()


func _draw() -> void:
	if _polygon.size() < 3:
		return

	# Gevulde contour
	draw_colored_polygon(_polygon, _color)

	# Houttextuur overlay (getiled)
	if _wood_texture and _texture_opacity > 0.01:
		var tex_size := Vector2(_wood_texture.get_width(), _wood_texture.get_height()) * _texture_scale
		var uvs := PackedVector2Array()
		var tint := Color(1, 1, 1, _texture_opacity)
		var colors := PackedColorArray()
		for p in _polygon:
			uvs.append(p / tex_size)
			colors.append(tint)
		draw_polygon(_polygon, colors, uvs, _wood_texture)

	# Contourlijn
	var outline := _polygon.duplicate()
	outline.append(_polygon[0])
	draw_polyline(outline, _outline_color, _outline_width, true)
