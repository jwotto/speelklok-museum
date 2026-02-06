extends Control
class_name StickerPicker

## Sticker picker - toont beschikbare stickers om te plaatsen

signal sticker_selected(texture: Texture2D)

@export var sticker_textures: Array[Texture2D] = []
@export var min_columns: int = 2
@export var max_columns: int = 5
@export var min_icon_size: float = 100.0
@export var max_icon_size: float = 500.0
@export var grid_padding: float = 30.0
@export var screen_margin: float = 50.0

var _background: ColorRect
var _panel: Panel
var _center: CenterContainer
var _grid: GridContainer
var _is_open: bool = false


func _ready() -> void:
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_ui()
	hide()
	get_tree().root.size_changed.connect(_update_layout)


func _create_ui() -> void:
	# Achtergrond (semi-transparant)
	_background = ColorRect.new()
	_background.color = Color(0, 0, 0, 0.7)
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_background)

	# Panel
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = screen_margin
	_panel.offset_top = screen_margin
	_panel.offset_right = -screen_margin
	_panel.offset_bottom = -screen_margin
	add_child(_panel)

	# CenterContainer voor centreren
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(_center)

	# Grid
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", int(grid_padding))
	_grid.add_theme_constant_override("v_separation", int(grid_padding))
	_center.add_child(_grid)


func _populate_grid() -> void:
	# Verwijder oude knoppen
	for child in _grid.get_children():
		child.queue_free()

	# Wacht tot layout klaar is
	await get_tree().process_frame

	# Bereken optimale icon grootte
	var icon_size = _calculate_icon_size()

	# Maak knop voor elke sticker
	for tex in sticker_textures:
		var btn = TextureButton.new()
		btn.texture_normal = tex
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = icon_size

		# Click mask voor pixel-perfect klikken
		var click_mask = _create_click_mask(tex)
		if click_mask:
			btn.texture_click_mask = click_mask

		btn.pressed.connect(_on_sticker_pressed.bind(tex))
		_grid.add_child(btn)


func _calculate_icon_size() -> Vector2:
	var available_size = _panel.size - Vector2(grid_padding * 2, grid_padding * 2)
	var item_count = sticker_textures.size()

	if item_count == 0:
		return Vector2(max_icon_size, max_icon_size)

	var best_size = min_icon_size
	var best_cols = min_columns

	for cols in range(min_columns, max_columns + 1):
		var rows = ceili(float(item_count) / cols)
		var total_h_padding = (cols - 1) * grid_padding
		var total_v_padding = (rows - 1) * grid_padding
		var available_width = available_size.x - total_h_padding
		var available_height = available_size.y - total_v_padding
		var max_width = available_width / cols
		var max_height = available_height / rows
		var icon_dim = minf(max_width, max_height)
		icon_dim = clampf(icon_dim, min_icon_size, max_icon_size)

		if icon_dim > best_size:
			best_size = icon_dim
			best_cols = cols

	_grid.columns = best_cols
	return Vector2(best_size, best_size)


func _update_layout() -> void:
	if not is_inside_tree() or not _is_open:
		return
	_populate_grid()


func _create_click_mask(tex: Texture2D) -> BitMap:
	if tex == null:
		return null
	var img = tex.get_image()
	if img == null:
		return null
	var bitmap = BitMap.new()
	bitmap.create_from_image_alpha(img, 0.1)
	return bitmap


func _on_sticker_pressed(tex: Texture2D) -> void:
	sticker_selected.emit(tex)
	close()


func open() -> void:
	_is_open = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_populate_grid()
	show()


func close() -> void:
	_is_open = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func _input(event: InputEvent) -> void:
	if _is_open and event is InputEventScreenTouch and event.pressed:
		var local = _panel.get_global_transform().affine_inverse() * event.position
		if not Rect2(Vector2.ZERO, _panel.size).has_point(local):
			close()
