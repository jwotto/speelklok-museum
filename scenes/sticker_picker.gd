@tool
extends Control
class_name StickerPicker

## Sticker picker - toont beschikbare stickers om te plaatsen
## Sleep sticker scenes naar de array in de inspector

signal sticker_selected(scene: PackedScene, from_position: Vector2)
signal opened
signal closed

@export var sticker_scenes: Array[PackedScene] = []:
	set(value):
		sticker_scenes = value
		if Engine.is_editor_hint() and is_inside_tree():
			_populate_grid()

@export_group("Panel")
@export var panel_gradient: GradientTexture2D:
	set(value):
		panel_gradient = value
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
@onready var _grid: GridContainer = $Panel/CenterContainer/GridContainer
@onready var _close_button: Button = $Panel/CloseButton

var _is_open: bool = false
var _outline_shader = preload("res://scenes/sticker_outline.gdshader")
var _picker_btn_script = preload("res://scenes/sticker_picker_button.gd")


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if sticker_scenes.is_empty():
		warnings.append("Geen sticker scenes ingesteld. Sleep scenes naar de array in de inspector.")
	return warnings


func _update_panel_style() -> void:
	if not is_inside_tree():
		return
	if _panel:
		# Altijd StyleBoxFlat voor afgeronde hoeken
		var style = StyleBoxFlat.new()
		style.corner_radius_top_left = panel_corner_radius
		style.corner_radius_top_right = panel_corner_radius
		style.corner_radius_bottom_left = panel_corner_radius
		style.corner_radius_bottom_right = panel_corner_radius

		if panel_gradient:
			# Gradient met afgeronde hoeken: StyleBoxFlat als clip mask,
			# TextureRect als gradient wordt geclipt op de afgeronde vorm.
			style.bg_color = Color.WHITE
			_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
			_panel.add_theme_stylebox_override("panel", style)
			_ensure_gradient_rect()
		else:
			# Simpele kleur met afgeronde hoeken
			style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
			_panel.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
			_panel.add_theme_stylebox_override("panel", style)
			_remove_gradient_rect()
	if _background:
		_background.color = overlay_color


func _ensure_gradient_rect() -> void:
	## Maak of update TextureRect voor gradient achtergrond
	var gradient_rect = _panel.get_node_or_null("GradientBG")
	if gradient_rect == null:
		gradient_rect = TextureRect.new()
		gradient_rect.name = "GradientBG"
		gradient_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gradient_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gradient_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_panel.add_child(gradient_rect)
		_panel.move_child(gradient_rect, 0)
	gradient_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	gradient_rect.offset_left = 0
	gradient_rect.offset_top = 0
	gradient_rect.offset_right = 0
	gradient_rect.offset_bottom = 0
	gradient_rect.texture = panel_gradient


func _remove_gradient_rect() -> void:
	var gradient_rect = _panel.get_node_or_null("GradientBG")
	if gradient_rect:
		gradient_rect.queue_free()


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
	_close_button.pressed.connect(close)


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

		var btn: TextureButton
		if Engine.is_editor_hint():
			btn = TextureButton.new()
			btn.texture_normal = tex
		else:
			btn = _picker_btn_script.new()
			btn.hit_margin = 30.0
			btn.texture_normal = tex
			btn.self_modulate = Color(1, 1, 1, 0)  # Verberg button tekening
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = icon_size

		if not Engine.is_editor_hint():
			# Visuele child (wordt gedraaid/geschaald, button zelf blijft stil)
			var visual = TextureRect.new()
			visual.texture = tex
			visual.set_anchors_preset(Control.PRESET_FULL_RECT)
			visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
			visual.pivot_offset = icon_size / 2

			# Outline shader op de visual
			var mat = ShaderMaterial.new()
			mat.shader = _outline_shader
			mat.set_shader_parameter("show_outline", false)
			mat.set_shader_parameter("outline_width", 30.0)
			mat.set_shader_parameter("outline_color", Color.WHITE)
			visual.material = mat
			btn.add_child(visual)
			btn.set_meta("visual", visual)

			# Vaste random hoek per knop
			btn.set_meta("hover_angle", deg_to_rad(randf_range(-6.0, 6.0)))

			# Hover en press effecten
			btn.mouse_entered.connect(_on_btn_activate.bind(btn))
			btn.mouse_exited.connect(_on_btn_deactivate.bind(btn))
			btn.button_down.connect(_on_btn_activate.bind(btn))
			btn.button_up.connect(func():
				if not btn.is_hovered():
					_on_btn_deactivate(btn)
			)
			btn.pressed.connect(_on_sticker_pressed.bind(scene, btn))
			btn.set_meta("scene", scene)

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



func _kill_btn_tween(btn: TextureButton) -> void:
	var old_tween = btn.get_meta("tween", null) as Tween
	if old_tween and old_tween.is_valid():
		old_tween.kill()


func _on_btn_activate(btn: TextureButton) -> void:
	_kill_btn_tween(btn)
	var visual = btn.get_meta("visual") as Control
	visual.material.set_shader_parameter("show_outline", true)
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.set_parallel()
	tween.tween_property(visual, "rotation", btn.get_meta("hover_angle", 0.0), 0.2)
	tween.tween_property(visual, "scale", Vector2(1.08, 1.08), 0.2)
	btn.set_meta("tween", tween)


func _on_btn_deactivate(btn: TextureButton) -> void:
	_kill_btn_tween(btn)
	var visual = btn.get_meta("visual") as Control
	visual.material.set_shader_parameter("show_outline", false)
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.set_parallel()
	tween.tween_property(visual, "rotation", 0.0, 0.4)
	tween.tween_property(visual, "scale", Vector2.ONE, 0.4)
	btn.set_meta("tween", tween)


func _input(event: InputEvent) -> void:
	## Release = actie (touch-friendly: release op knop telt als klik)
	if Engine.is_editor_hint() or not _is_open:
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check sticker knoppen
		var btn = _find_btn_at(event.position)
		if btn:
			var scene = btn.get_meta("scene", null) as PackedScene
			if scene:
				_on_sticker_pressed(scene, btn)
				get_viewport().set_input_as_handled()
				return
		# Close button
		if _close_button.get_global_rect().has_point(event.position):
			close()
			get_viewport().set_input_as_handled()
			return
		# Buiten panel = sluiten
		if not _panel.get_global_rect().has_point(event.position):
			close()
			get_viewport().set_input_as_handled()


func _find_btn_at(pos: Vector2) -> TextureButton:
	## Vind de sticker-knop op de gegeven screen positie
	for btn in _grid.get_children():
		if btn is TextureButton and btn.get_global_rect().has_point(pos):
			return btn
	return null


func _on_sticker_pressed(scene: PackedScene, btn: TextureButton) -> void:
	var btn_center = btn.global_position + btn.size / 2
	sticker_selected.emit(scene, btn_center)
	close()


func open() -> void:
	_is_open = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_populate_grid()
	show()
	opened.emit()


func close() -> void:
	_is_open = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	closed.emit()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


