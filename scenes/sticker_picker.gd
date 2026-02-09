@tool
extends Control
class_name StickerPicker

## Sticker picker - toont beschikbare stickers om te plaatsen
## Sleep sticker scenes naar de array in de inspector

signal sticker_selected(scene: PackedScene)

@export var sticker_scenes: Array[PackedScene] = []:
	set(value):
		sticker_scenes = value
		if Engine.is_editor_hint() and is_inside_tree():
			_populate_grid()

@export_group("Panel")
@export var panel_color: Color = Color(0.15, 0.15, 0.15, 0.9):
	set(value):
		panel_color = value
		_update_panel_style()
@export var panel_corner_radius: int = 20:
	set(value):
		panel_corner_radius = value
		_update_panel_style()
@export var overlay_color: Color = Color(0, 0, 0, 0.5):
	set(value):
		overlay_color = value
		_update_panel_style()

@export_group("Layout")
@export var min_columns: int = 2
@export var max_columns: int = 5
@export var min_icon_size: float = 100.0
@export var max_icon_size: float = 500.0
@export var grid_padding: float = 30.0

# Scene node references
@onready var _background: ColorRect = $Background
@onready var _panel: Panel = $Panel
@onready var _center: CenterContainer = $Panel/CenterContainer
@onready var _grid: GridContainer = $Panel/CenterContainer/GridContainer

var _is_open: bool = false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if sticker_scenes.is_empty():
		warnings.append("Geen sticker scenes ingesteld. Sleep scenes naar de array in de inspector.")
	return warnings


func _update_panel_style() -> void:
	if not is_inside_tree():
		return
	if _panel:
		var style = StyleBoxFlat.new()
		style.bg_color = panel_color
		style.corner_radius_top_left = panel_corner_radius
		style.corner_radius_top_right = panel_corner_radius
		style.corner_radius_bottom_left = panel_corner_radius
		style.corner_radius_bottom_right = panel_corner_radius
		_panel.add_theme_stylebox_override("panel", style)
	if _background:
		_background.color = overlay_color


func _ready() -> void:
	_update_panel_style()
	if Engine.is_editor_hint():
		# In editor: toon preview
		_populate_grid()
		return

	# Runtime
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	get_tree().root.size_changed.connect(_update_layout)


func _populate_grid() -> void:
	if _grid == null:
		return

	# Verwijder oude knoppen
	for child in _grid.get_children():
		child.queue_free()

	if not Engine.is_editor_hint():
		# Wacht tot layout klaar is (alleen runtime)
		await get_tree().process_frame

	# Bereken optimale icon grootte
	var icon_size = _calculate_icon_size()

	# Update grid padding
	_grid.add_theme_constant_override("h_separation", int(grid_padding))
	_grid.add_theme_constant_override("v_separation", int(grid_padding))

	# Maak knop voor elke sticker scene
	for scene in sticker_scenes:
		var tex = _get_texture_from_scene(scene)
		if tex == null:
			continue

		var btn = TextureButton.new()
		btn.texture_normal = tex
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = icon_size

		if not Engine.is_editor_hint():
			# Click mask voor pixel-perfect klikken (alleen runtime)
			var click_mask = _create_click_mask(tex)
			if click_mask:
				btn.texture_click_mask = click_mask
			btn.pressed.connect(_on_sticker_pressed.bind(scene))

		_grid.add_child(btn)


func _get_texture_from_scene(scene: PackedScene) -> Texture2D:
	## Haal texture op uit een sticker scene voor de preview
	if scene == null:
		return null
	var state = scene.get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == "texture":
			return state.get_node_property_value(0, i)
	return null


func _calculate_icon_size() -> Vector2:
	var panel_size = _panel.size if _panel else Vector2(800, 600)
	var available_size = panel_size - Vector2(grid_padding * 2, grid_padding * 2)
	var item_count = sticker_scenes.size()

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


func _on_sticker_pressed(scene: PackedScene) -> void:
	sticker_selected.emit(scene)
	close()


func open() -> void:
	_is_open = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Connect click handlers (alleen als nog niet connected)
	if not _background.gui_input.is_connected(_on_overlay_click):
		_background.gui_input.connect(_on_overlay_click)
	if not _panel.gui_input.is_connected(_on_overlay_click):
		_panel.gui_input.connect(_on_overlay_click)
	_populate_grid()
	show()


func _on_overlay_click(event: InputEvent) -> void:
	# Sluit picker bij klik op achtergrond of paneel (niet op sticker button)
	if event is InputEventMouseButton and event.pressed:
		close()


func close() -> void:
	_is_open = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _is_open and event is InputEventScreenTouch and event.pressed:
		var local = _panel.get_global_transform().affine_inverse() * event.position
		if not Rect2(Vector2.ZERO, _panel.size).has_point(local):
			close()
