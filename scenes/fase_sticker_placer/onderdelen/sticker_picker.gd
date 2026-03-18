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
@export var min_icon_size: float = 150.0
@export var max_icon_size: float = 750.0
@export var grid_padding: float = 45.0

# Scene node references
@onready var _background: ColorRect = $Background
@onready var _panel: Panel = $Panel
@onready var _scroll: ScrollContainer = $Panel/ScrollContainer
@onready var _margin: MarginContainer = $Panel/ScrollContainer/MarginContainer
@onready var _grid: GridContainer = $Panel/ScrollContainer/MarginContainer/GridContainer
@onready var _close_button: TextureButton = $CloseButton

## State machine voor touch input:
##   IDLE           - niks aan de hand
##   PRESSING       - vinger op sticker knop (visuele feedback)
##   SCROLLING      - aan het scrollen via grid
##   BAR_ANIMATING  - scrollbar thumb animeert naar klik-positie
##   BAR_DRAGGING   - scrollbar thumb wordt gesleept
enum TouchState { IDLE, PRESSING, SCROLLING, BAR_ANIMATING, BAR_DRAGGING }

var _is_open: bool = false
var _grid_populated: bool = false
var _picker_btn_script = preload("res://scenes/fase_sticker_placer/onderdelen/sticker_picker_button.gd")
var _outline_shader = preload("res://scenes/fase_sticker_placer/onderdelen/sticker_outline.gdshader")
var _scroll_track: Panel
var _scroll_thumb: Panel
var _state: TouchState = TouchState.IDLE
var _pressed_btn: TextureButton = null
var _bar_drag_offset: float = 0.0
var _bar_tween: Tween = null


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
	_style_scrollbar()


func _style_scrollbar() -> void:
	## Verberg ingebouwde scrollbar en maak overlay indicator
	var vbar = _scroll.get_v_scroll_bar()
	# Ingebouwde scrollbar onzichtbaar + 0 breedte (neemt geen ruimte in)
	var empty = StyleBoxEmpty.new()
	vbar.add_theme_stylebox_override("scroll", empty)
	vbar.add_theme_stylebox_override("grabber", empty)
	vbar.add_theme_stylebox_override("grabber_highlight", empty)
	vbar.add_theme_stylebox_override("grabber_pressed", empty)
	vbar.custom_minimum_size.x = 0

	# Scrollbar naast het panel (child van root, niet panel — anders wordt het geclipt)
	var bar_width := 48
	var bar_gap := 8
	var corner := bar_width / 2

	_scroll_track = Panel.new()
	_scroll_track.mouse_filter = Control.MOUSE_FILTER_STOP
	# Positioneer rechts naast het panel, meeschalend via anchors
	_scroll_track.anchor_left = 1.0
	_scroll_track.anchor_right = 1.0
	_scroll_track.anchor_top = 0.0
	_scroll_track.anchor_bottom = 1.0
	_scroll_track.offset_left = _panel.offset_right + bar_gap      # -70 + 8 = -62
	_scroll_track.offset_right = _panel.offset_right + bar_gap + bar_width  # -70 + 8 + 48 = -14
	_scroll_track.offset_top = _panel.offset_top        # 40
	_scroll_track.offset_bottom = _panel.offset_bottom   # -40
	var track_style = StyleBoxFlat.new()
	track_style.bg_color = Color(1, 1, 1, 0.15)
	track_style.corner_radius_top_left = corner
	track_style.corner_radius_top_right = corner
	track_style.corner_radius_bottom_left = corner
	track_style.corner_radius_bottom_right = corner
	_scroll_track.add_theme_stylebox_override("panel", track_style)
	add_child(_scroll_track)

	_scroll_thumb = Panel.new()
	_scroll_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var thumb_style = StyleBoxFlat.new()
	thumb_style.bg_color = Color(1, 1, 1, 0.5)
	thumb_style.corner_radius_top_left = corner
	thumb_style.corner_radius_top_right = corner
	thumb_style.corner_radius_bottom_left = corner
	thumb_style.corner_radius_bottom_right = corner
	_scroll_thumb.add_theme_stylebox_override("panel", thumb_style)
	_scroll_track.add_child(_scroll_thumb)

	vbar.value_changed.connect(_update_scroll_indicator)
	vbar.value_changed.connect(_on_scroll_value_changed)
	vbar.changed.connect(func(): _update_scroll_indicator(vbar.value))
	_scroll.resized.connect(func(): _update_scroll_indicator(vbar.value))

	# Scrollbar sleepbaar maken
	_scroll_track.gui_input.connect(_on_scrollbar_input)


func _on_scrollbar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_deactivate_pressed_btn()
			var thumb_rect = Rect2(_scroll_thumb.position, _scroll_thumb.size)
			if thumb_rect.has_point(event.position):
				# Klik op thumb → direct slepen
				_state = TouchState.BAR_DRAGGING
				_bar_drag_offset = event.position.y - _scroll_thumb.position.y
			else:
				# Klik op track → animeer thumb ernaartoe
				_state = TouchState.BAR_ANIMATING
				_bar_drag_offset = _scroll_thumb.size.y / 2
				_bar_animate_to(event.position.y - _bar_drag_offset)
		else:
			# Release → IDLE
			_kill_bar_tween()
			_state = TouchState.IDLE
		_scroll_track.accept_event()
	elif event is InputEventMouseMotion:
		match _state:
			TouchState.BAR_ANIMATING:
				# Animatie loopt, gebruiker sleept → stop animatie, sleep vanaf huidige positie
				_kill_bar_tween()
				_state = TouchState.BAR_DRAGGING
				_bar_drag_offset = event.position.y - _scroll_thumb.position.y
				_scroll_track.accept_event()
			TouchState.BAR_DRAGGING:
				_scroll_to_track_pos(event.position.y - _bar_drag_offset)
				_scroll_track.accept_event()


func _scroll_to_track_pos(thumb_top: float) -> void:
	var vbar = _scroll.get_v_scroll_bar()
	var max_scroll = vbar.max_value - vbar.page
	if max_scroll <= 0:
		return
	var track_height = _scroll_track.size.y
	var thumb_height = _scroll_thumb.size.y
	var max_thumb_y = track_height - thumb_height
	if max_thumb_y <= 0:
		return
	var ratio = clampf(thumb_top / max_thumb_y, 0.0, 1.0)
	_scroll.scroll_vertical = int(ratio * max_scroll)


func _bar_animate_to(thumb_top: float) -> void:
	## Animeer scroll naar positie (bij klik buiten thumb)
	var vbar = _scroll.get_v_scroll_bar()
	var max_scroll = vbar.max_value - vbar.page
	if max_scroll <= 0:
		return
	var track_height = _scroll_track.size.y
	var thumb_height = _scroll_thumb.size.y
	var max_thumb_y = track_height - thumb_height
	if max_thumb_y <= 0:
		return
	var ratio = clampf(thumb_top / max_thumb_y, 0.0, 1.0)
	var target = int(ratio * max_scroll)
	_kill_bar_tween()
	_bar_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_bar_tween.tween_method(func(v: int): _scroll.scroll_vertical = v, _scroll.scroll_vertical, target, 0.2)
	# Blijf in BAR_ANIMATING — offset wordt berekend bij eerste drag motion


func _kill_bar_tween() -> void:
	if _bar_tween and _bar_tween.is_valid():
		_bar_tween.kill()
	_bar_tween = null


func _update_scroll_indicator(value: float) -> void:
	if _scroll_track == null:
		return
	var vbar = _scroll.get_v_scroll_bar()
	var max_scroll = vbar.max_value - vbar.page
	if max_scroll <= 0:
		_scroll_track.hide()
		return
	_scroll_track.show()
	_scroll_track.modulate.a = 1.0
	var track_height = _scroll_track.size.y
	var thumb_ratio = vbar.page / maxf(vbar.max_value, 1.0)
	var thumb_height = maxf(track_height * thumb_ratio, 50.0)
	var scroll_ratio = value / max_scroll
	var thumb_y = scroll_ratio * (track_height - thumb_height)
	_scroll_thumb.position = Vector2(0, thumb_y)
	_scroll_thumb.size = Vector2(_scroll_track.size.x, thumb_height)


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
		var sprites = _get_sprites_from_scene(scene)
		if sprites.is_empty():
			continue

		var btn: TextureButton
		if Engine.is_editor_hint():
			btn = TextureButton.new()
			btn.texture_normal = sprites[0].texture
		else:
			btn = _picker_btn_script.new()
			btn.hit_margin = 2.0
			btn.texture_normal = sprites[0].texture
			btn.self_modulate = Color(1, 1, 1, 0)  # Verberg button tekening
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = icon_size

		if not Engine.is_editor_hint():
			var visual: Control
			if sprites.size() == 1:
				# Enkele sprite: TextureRect
				var tex_rect = TextureRect.new()
				tex_rect.texture = sprites[0].texture
				tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
				tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tex_rect.pivot_offset = icon_size / 2
				visual = tex_rect
			else:
				# Meerdere sprites: container met bounding box berekening
				visual = _create_multi_sprite_visual(sprites, icon_size)

			btn.add_child(visual)
			btn.set_meta("visual", visual)

			# Vaste random hoek per knop
			btn.set_meta("hover_angle", deg_to_rad(randf_range(-6.0, 6.0)))

			# Touch: button_down = visuele feedback, _input release = selectie
			btn.button_down.connect(_on_btn_down.bind(btn))
			btn.button_up.connect(_on_btn_up.bind(btn))
			btn.set_meta("scene", scene)

		_grid.add_child(btn)




func _create_multi_sprite_visual(sprites: Array[Dictionary], icon_size: Vector2) -> Control:
	## Maak een container met meerdere sprites, geschaald naar icon_size
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.pivot_offset = icon_size / 2

	# Bereken gecombineerde bounding box (Sprite2D centreert textures)
	var bbox := Rect2()
	for i in sprites.size():
		var tex_size = sprites[i].texture.get_size()
		var pos: Vector2 = sprites[i].position
		var sprite_rect = Rect2(pos - tex_size / 2, tex_size)
		if i == 0:
			bbox = sprite_rect
		else:
			bbox = bbox.merge(sprite_rect)

	# Schaal om in icon_size te passen
	var fit_scale = minf(icon_size.x / bbox.size.x, icon_size.y / bbox.size.y)
	var centering = (icon_size - bbox.size * fit_scale) / 2

	for s in sprites:
		var tex_rect = TextureRect.new()
		tex_rect.texture = s.texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex_size = s.texture.get_size()
		var top_left: Vector2 = s.position - tex_size / 2
		tex_rect.position = (top_left - bbox.position) * fit_scale + centering
		tex_rect.size = tex_size * fit_scale
		container.add_child(tex_rect)

	return container


func _get_sprites_from_scene(scene: PackedScene) -> Array[Dictionary]:
	## Haal alle sprite textures + posities op uit een sticker scene
	if scene == null:
		return []
	var state = scene.get_state()
	var sprites: Array[Dictionary] = []
	for node_idx in state.get_node_count():
		var tex: Texture2D = null
		var pos := Vector2.ZERO
		for prop_idx in state.get_node_property_count(node_idx):
			var prop_name = state.get_node_property_name(node_idx, prop_idx)
			if prop_name == "texture":
				tex = state.get_node_property_value(node_idx, prop_idx)
			elif prop_name == "position":
				pos = state.get_node_property_value(node_idx, prop_idx)
		if tex:
			sprites.append({"texture": tex, "position": pos})
	return sprites


func _calculate_icon_size() -> Vector2:
	## Bereken icon grootte op basis van breedte (hoogte scrollt)
	var panel_size = _panel.size if _panel else Vector2(800, 600)
	var available_width = panel_size.x - grid_padding * 2
	var item_count = sticker_scenes.size()

	if item_count == 0:
		return Vector2(max_icon_size, max_icon_size)

	var best_size = min_icon_size
	var best_cols = min_columns

	for cols in range(min_columns, max_columns + 1):
		var total_h_padding = (cols - 1) * grid_padding
		var icon_dim = (available_width - total_h_padding) / cols
		icon_dim = clampf(icon_dim, min_icon_size, max_icon_size)

		if icon_dim > best_size:
			best_size = icon_dim
			best_cols = cols

	_grid.columns = best_cols

	# Centreer grid horizontaal via marges
	var grid_width = best_cols * best_size + (best_cols - 1) * grid_padding
	var available = _panel.size.x if _panel else 800.0
	var margin = int(maxf((available - grid_width) / 2, 0))
	_margin.add_theme_constant_override("margin_left", margin)
	_margin.add_theme_constant_override("margin_right", margin)

	return Vector2(best_size, best_size)


func _update_layout() -> void:
	if not is_inside_tree() or not _is_open:
		return
	_grid_populated = false
	_populate_grid()
	_grid_populated = true



func _kill_btn_tween(btn: TextureButton) -> void:
	if not btn.has_meta("tween"):
		return
	var old_tween = btn.get_meta("tween") as Tween
	if old_tween and old_tween.is_valid():
		old_tween.kill()


func _on_scroll_value_changed(_value: float) -> void:
	## PRESSING → SCROLLING: scroll positie veranderd terwijl knop ingedrukt
	if _state == TouchState.PRESSING:
		_deactivate_pressed_btn()
		_state = TouchState.SCROLLING


func _on_btn_down(btn: TextureButton) -> void:
	## IDLE → PRESSING: vinger op een sticker knop
	if _state != TouchState.IDLE:
		return
	_state = TouchState.PRESSING
	_pressed_btn = btn
	_activate_btn_visual(btn)


func _on_btn_up(btn: TextureButton) -> void:
	## button_up wordt niet altijd betrouwbaar gevuurd — state machine handelt dit af in _input
	if _state == TouchState.PRESSING and _pressed_btn == btn:
		_deactivate_pressed_btn()


func _activate_btn_visual(btn: TextureButton) -> void:
	_kill_btn_tween(btn)
	var visual = btn.get_meta("visual") as Control
	_set_outline(visual, true)
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.set_parallel()
	tween.tween_property(visual, "rotation", btn.get_meta("hover_angle", 0.0), 0.2)
	tween.tween_property(visual, "scale", Vector2(1.08, 1.08), 0.2)
	btn.set_meta("tween", tween)


func _deactivate_pressed_btn() -> void:
	if _pressed_btn == null:
		return
	var btn = _pressed_btn
	_pressed_btn = null
	_kill_btn_tween(btn)
	var visual = btn.get_meta("visual") as Control
	_set_outline(visual, false)
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.set_parallel()
	tween.tween_property(visual, "rotation", 0.0, 0.4)
	tween.tween_property(visual, "scale", Vector2.ONE, 0.4)
	btn.set_meta("tween", tween)


func _set_outline(visual: Control, enabled: bool) -> void:
	## Zet witte outline shader op alle TextureRects in de visual
	if visual is TextureRect and visual.texture:
		if enabled:
			if visual.material == null:
				var mat = ShaderMaterial.new()
				mat.shader = _outline_shader
				mat.set_shader_parameter("outline_color", Color.WHITE)
				visual.material = mat
			# Compenseer outline dikte voor schaal (texture pixels vs display pixels)
			var tex_size = visual.texture.get_size()
			var display_size = visual.size
			var scale_ratio = tex_size.x / maxf(display_size.x, 1.0)
			(visual.material as ShaderMaterial).set_shader_parameter("outline_width", 6.0 * scale_ratio)
			(visual.material as ShaderMaterial).set_shader_parameter("show_outline", true)
		else:
			if visual.material is ShaderMaterial:
				(visual.material as ShaderMaterial).set_shader_parameter("show_outline", false)
	for child in visual.get_children():
		if child is TextureRect:
			_set_outline(child, enabled)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _is_open:
		return

	# PRESSING: vinger van knop af gesleept → deactiveer
	if event is InputEventMouseMotion and _state == TouchState.PRESSING and _pressed_btn:
		if not _pressed_btn.get_global_rect().has_point(event.position):
			_deactivate_pressed_btn()
			_state = TouchState.IDLE

	# Touch release
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match _state:
			TouchState.PRESSING:
				# Vinger los op knop → selecteer sticker
				_deactivate_pressed_btn()
				_state = TouchState.IDLE
				var btn = _find_btn_with_has_point(event.position)
				if btn:
					var scene = btn.get_meta("scene", null) as PackedScene
					if scene:
						_on_sticker_pressed(scene, btn)
						get_viewport().set_input_as_handled()
						return
			TouchState.SCROLLING, TouchState.BAR_ANIMATING, TouchState.BAR_DRAGGING:
				# Na scrollen: GEEN selectie
				_kill_bar_tween()
				_state = TouchState.IDLE
				return
			TouchState.IDLE:
				pass
		# Close button (alleen vanuit IDLE/PRESSING)
		if _close_button.get_global_rect().has_point(event.position):
			close()
			get_viewport().set_input_as_handled()
			return


func _find_btn_with_has_point(pos: Vector2) -> TextureButton:
	## Vind de sticker-knop via pixel-detectie (_has_point)
	for btn in _grid.get_children():
		if btn is TextureButton and btn.get_global_rect().has_point(pos):
			var local = pos - btn.global_position
			if btn._has_point(local):
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
	if not _grid_populated:
		await _populate_grid()
		_grid_populated = true
	_scroll.scroll_vertical = 0
	show()
	opened.emit()
	# Wacht 2 frames zodat layout + scroll range berekend is
	await get_tree().process_frame
	await get_tree().process_frame
	_update_scroll_indicator(0)


func close() -> void:
	_deactivate_pressed_btn()
	_kill_bar_tween()
	_state = TouchState.IDLE
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


