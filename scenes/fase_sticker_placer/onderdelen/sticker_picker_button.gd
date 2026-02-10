extends TextureButton
class_name StickerPickerButton

## TextureButton met pixel-detectie en marge, zoals Sticker._hit_test()

var hit_margin: float = 30.0
var _hit_image: Image = null


func _has_point(point: Vector2) -> bool:
	if texture_normal == null:
		return Rect2(Vector2.ZERO, size).has_point(point)

	# Lazy load image
	if _hit_image == null:
		_hit_image = texture_normal.get_image()
	if _hit_image == null:
		return Rect2(Vector2.ZERO, size).has_point(point)

	# Bereken display rect (STRETCH_KEEP_ASPECT_CENTERED)
	var tex_size = Vector2(texture_normal.get_size())
	var scale_factor = minf(size.x / tex_size.x, size.y / tex_size.y)
	var display_size = tex_size * scale_factor
	var offset = (size - display_size) / 2.0

	# Converteer naar texture coördinaten
	var local = point - offset
	var tex_x = int(local.x / display_size.x * tex_size.x)
	var tex_y = int(local.y / display_size.y * tex_size.y)

	# Marge in texture pixels
	var margin_pixels = int(hit_margin / scale_factor)

	# Bounding box check met marge
	if tex_x < -margin_pixels or tex_x >= int(tex_size.x) + margin_pixels:
		return false
	if tex_y < -margin_pixels or tex_y >= int(tex_size.y) + margin_pixels:
		return false

	# Check direct pixel eerst
	if _check_alpha(tex_x, tex_y):
		return true

	# Check pixels binnen de marge (stap van 4 voor performance)
	for dx in range(-margin_pixels, margin_pixels + 1, 4):
		for dy in range(-margin_pixels, margin_pixels + 1, 4):
			if _check_alpha(tex_x + dx, tex_y + dy):
				return true

	return false


func _check_alpha(x: int, y: int) -> bool:
	var w = _hit_image.get_width()
	var h = _hit_image.get_height()
	if x >= 0 and x < w and y >= 0 and y < h:
		return _hit_image.get_pixel(x, y).a > 0.1
	return false
