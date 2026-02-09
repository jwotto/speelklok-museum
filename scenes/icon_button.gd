@tool
extends TextureButton
class_name IconButton

## Configureerbare button met kleur, afgeronde hoeken en icoon

enum IconType { NONE, ADD, TRASH }

@export var icon_type: IconType = IconType.NONE:
	set(value):
		icon_type = value
		_regenerate()

@export_group("Appearance")
@export var button_size: int = 120:
	set(value):
		button_size = value
		_regenerate()
@export var color: Color = Color(0.3, 0.3, 0.3, 0.8):
	set(value):
		color = value
		_regenerate()
@export var corner_radius: int = 20:
	set(value):
		corner_radius = value
		_regenerate()
@export var icon_color: Color = Color.WHITE:
	set(value):
		icon_color = value
		_regenerate()


var _pulse_tween: Tween = null
var _press_tween: Tween = null


func _ready() -> void:
	_regenerate()
	if Engine.is_editor_hint():
		return
	pivot_offset = Vector2(button_size, button_size) / 2
	button_down.connect(_on_press)
	button_up.connect(_on_release)
	_start_pulse()


func _regenerate() -> void:
	if not is_inside_tree():
		return
	var img = Image.create(button_size, button_size, false, Image.FORMAT_RGBA8)
	_fill_rounded_rect(img, color)
	match icon_type:
		IconType.ADD:
			_draw_add_icon(img)
		IconType.TRASH:
			_draw_trash_icon(img)
	texture_normal = ImageTexture.create_from_image(img)
	custom_minimum_size = Vector2(button_size, button_size)


func _fill_rounded_rect(img: Image, fill_color: Color) -> void:
	var w = img.get_width()
	var h = img.get_height()
	for x in w:
		for y in h:
			if _is_in_rounded_rect(x, y, w, h, corner_radius):
				img.set_pixel(x, y, fill_color)


func _is_in_rounded_rect(x: int, y: int, w: int, h: int, r: int) -> bool:
	if r <= 0:
		return true
	if x < r and y < r:
		return Vector2(x - r, y - r).length() <= r
	if x >= w - r and y < r:
		return Vector2(x - (w - r - 1), y - r).length() <= r
	if x < r and y >= h - r:
		return Vector2(x - r, y - (h - r - 1)).length() <= r
	if x >= w - r and y >= h - r:
		return Vector2(x - (w - r - 1), y - (h - r - 1)).length() <= r
	return true


func _draw_add_icon(img: Image) -> void:
	var s = button_size
	var center = int(s / 2.0)
	var half_thick = 6
	var length = 45
	for x in range(center - length, center + length + 1):
		for y in range(center - half_thick, center + half_thick + 1):
			img.set_pixel(x, y, icon_color)
	for y in range(center - length, center + length + 1):
		for x in range(center - half_thick, center + half_thick + 1):
			img.set_pixel(x, y, icon_color)


func _draw_trash_icon(img: Image) -> void:
	var s = button_size
	@warning_ignore("integer_division")
	var cx: int = s / 2
	# Deksel
	for x in range(10, s - 10):
		for y in range(15, 25):
			if _is_in_rounded_rect(x, y, s, s, corner_radius):
				img.set_pixel(x, y, icon_color)
	# Handvat
	for x in range(cx - 10, cx + 10):
		for y in range(5, 15):
			if _is_in_rounded_rect(x, y, s, s, corner_radius):
				img.set_pixel(x, y, icon_color)
	# Bak
	for x in range(15, s - 15):
		for y in range(25, s - 10):
			if x < 20 or x > s - 20 or y > s - 15:
				img.set_pixel(x, y, icon_color)


# === ANIMATIES ===

func _start_pulse() -> void:
	_pulse_tween = create_tween().set_loops()
	var angle = deg_to_rad(3.0)
	_pulse_tween.tween_property(self, "scale", Vector2(1.04, 1.04), 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.parallel().tween_property(self, "rotation", angle, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(self, "scale", Vector2(0.96, 0.96), 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.parallel().tween_property(self, "rotation", -angle, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null


func _on_press() -> void:
	_stop_pulse()
	if _press_tween and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_press_tween.tween_property(self, "scale", Vector2(1.15, 0.85), 0.12)


func _on_release() -> void:
	if _press_tween and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	_press_tween.set_parallel()
	_press_tween.tween_property(self, "scale", Vector2.ONE, 0.4)
	_press_tween.tween_property(self, "rotation", 0.0, 0.4)
	_press_tween.chain().tween_callback(_start_pulse)
