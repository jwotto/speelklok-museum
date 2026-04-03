@tool
extends Node2D

## Fase 2: Muziekinstrumenten plaatsen
## Self-contained scene met sticker plaatsing, prullenbak, picker en sliders

@warning_ignore("unused_signal")
signal phase_completed

@export_group("Trash")
## Hoe dicht (in pixels) de vinger bij de prullenbak moet zijn om een sticker te verwijderen bij loslaten
@export var trash_zone_radius: float = 210.0

# Scene node references
@onready var _background: TextureRect = $Background
@onready var _sticker_container: Node2D = $Stickers
@onready var _trash_button: IconButton = $UILayer/StickerSliders/TrashButton
@onready var _add_button: IconButton = $UILayer/StickerSliders/AddButton
@onready var _play_button: IconButton = $UILayer/StickerSliders/PlayButton
@onready var _picker: StickerPicker = $UILayer/StickerPicker
@onready var _slider_container: HBoxContainer = $UILayer/StickerSliders
@onready var _rotate_slider: Control = $UILayer/StickerSliders/RotateSlider
@onready var _scale_slider: Control = $UILayer/StickerSliders/ScaleSlider

var _was_dragging: Dictionary = {}  # instance_id -> was dragging last frame
var _last_touch_pos: Vector2 = Vector2.ZERO  # Laatste vinger/muis positie
var _trash_highlighted: bool = false
var _any_dragging: bool = false
var _picker_open: bool = false
var _is_playing: bool = false
var _tracked_sticker: Sticker = null
var _updating_sliders: bool = false
var _organ_polygon_world: PackedVector2Array = PackedVector2Array()
var _organ_center: Vector2 = Vector2.ZERO
var _audio_player: Node2D = null  ## AudioLayerPlayer
var _drager_overlay: CanvasLayer = null  ## Muziekdrager selectie overlay
var _drager_selecting: bool = false  ## Toon drager selectie


func _ready() -> void:
	_resize_background()
	if Engine.is_editor_hint():
		return

	get_tree().root.size_changed.connect(_resize_background)
	Sticker.reset_statics()

	# Runtime setup
	_trash_button.visible = false
	_play_button.visible = false
	_add_button.pressed.connect(_on_add_pressed)
	_play_button.pressed.connect(_on_play_pressed)
	_picker.sticker_selected.connect(_on_sticker_selected)
	_picker.opened.connect(_on_picker_opened)
	_picker.closed.connect(_on_picker_closed)
	_rotate_slider.value_changed.connect(_on_rotate_slider_changed)
	_scale_slider.value_changed.connect(_on_scale_slider_changed)

	# Audio systeem
	var AudioLayerPlayerScript = preload("res://scenes/fase_sticker_placer/onderdelen/audio_layer_player.gd")
	_audio_player = AudioLayerPlayerScript.new()
	add_child(_audio_player)

	# Muziekdrager selectie overlay
	_setup_drager_overlay()


func _on_add_pressed() -> void:
	_picker.toggle()


func _on_picker_opened() -> void:
	_picker_open = true
	_update_button_visibility()
	_set_stickers_input(false)
	_set_stickers_process(false)


func _on_picker_closed() -> void:
	_picker_open = false
	_update_button_visibility()
	_set_stickers_input(true)
	# Process wordt per sticker weer aangezet bij interactie


func _update_button_visibility() -> void:
	if _picker_open or _drager_selecting:
		_slider_container.visible = false
		return
	_slider_container.visible = true
	var has_stickers = _sticker_container.get_child_count() > 0

	if _is_playing:
		# Tijdens afspelen: alleen stop button tonen
		_trash_button.visible = false
		_add_button.visible = false
		_play_button.visible = true
		_rotate_slider.visible = false
		_scale_slider.visible = false
		return

	_trash_button.visible = _any_dragging
	_add_button.visible = not _any_dragging
	_play_button.visible = has_stickers and not _any_dragging
	var show_sliders := _tracked_sticker != null
	_rotate_slider.visible = show_sliders
	_scale_slider.visible = show_sliders


func _is_touch_over_ui(pos: Vector2) -> bool:
	## Check of de positie boven een UI element valt
	for btn: Control in [_add_button, _trash_button, _play_button]:
		if btn.visible and btn.get_global_rect().has_point(pos):
			return true
	if _slider_container.visible and _slider_container.get_global_rect().has_point(pos):
		return true
	return false


func _select_sticker_at(pos: Vector2) -> void:
	## Selecteer de bovenste sticker op de gegeven positie
	var best_sticker: Sticker = null
	var best_z: int = -1
	for sticker in _sticker_container.get_children():
		if sticker is Sticker and sticker._hit_test(pos) and sticker.z_index > best_z:
			best_sticker = sticker
			best_z = sticker.z_index
	if best_sticker != null:
		best_sticker._select()


func _set_stickers_input(enabled: bool) -> void:
	for sticker in _sticker_container.get_children():
		if sticker is Sticker:
			sticker.set_process_unhandled_input(enabled)
			sticker.input_locked = not enabled


func _set_stickers_process(enabled: bool) -> void:
	for sticker in _sticker_container.get_children():
		if sticker is Sticker:
			sticker.set_process(enabled)


func set_phase_data(data: Dictionary) -> void:
	## Ontvang de geduplicate body node van de body builder fase
	if not data.has("body_node") or not data.has("polygon"):
		return

	# Gebruik de GEDUPLICATE node uit fase 1 - EXACT dezelfde properties!
	var body_shape: Node2D = data["body_node"]
	var polygon: PackedVector2Array = data["polygon"]
	var target_scale_f: float = data["zoom_scale"]

	body_shape.name = "OrganContour"
	add_child(body_shape)
	move_child(body_shape, _sticker_container.get_index())

	# Gebruik BodyDecoration maar ZONDER versieringen - alleen basis hout texture
	var decoration := body_shape.get_node_or_null("BodyDecoration")
	if decoration:
		decoration.visible = true
		# Schakel ALLE decoraties uit - houd alleen de basis texture
		decoration.pipe_count = 0  # Geen pijpen
		decoration.panel_count = 0  # Geen panelen
		decoration.molding_width = 0.0  # Geen lijstwerk
		decoration.molding_accent_width = 0.0
		decoration.gold_trim_width = 0.0  # Geen gouden rand
		decoration.arch_line_width = 0.0
		decoration.panel_frame_width = 0.0  # Geen paneel randen
		decoration.panel_inner_width = 0.0
		decoration.crown_arch_count = 0  # Geen kroonboogjes
		decoration.pendant_radius = 0.0  # Geen bolletjes
		decoration.neck_frame_inset = 0.0  # Geen nek-kader
		decoration.neck_fill_color = Color(0, 0, 0, 0)  # Geen nek-vulling
		decoration.rok_frame_inset = 0.0  # Geen rok-kader
		decoration.rok_fill_color = Color(0, 0, 0, 0)  # Geen rok-vulling
		decoration.uniform_zones = true  # Uniforme kleur (geen donkere/lichte zones)
		# Maak texture opacity en blend uniform over alle zones
		decoration.kop_texture_opacity = decoration.lichaam_texture_opacity
		decoration.rok_texture_opacity = decoration.lichaam_texture_opacity
		decoration.kop_color_blend = decoration.lichaam_color_blend
		decoration.rok_color_blend = decoration.lichaam_color_blend
		# Nu blijft alleen de basis kleur + hout texture over!

	# ShapeFill blijft hidden (BodyDecoration tekent de vorm)
	var shape_fill := body_shape.get_node_or_null("ShapeFill")
	if shape_fill:
		shape_fill.visible = false

	# Scale is al gezet door de animatie in fase 1, dus laten we die
	# (position en scale zijn al exact zoals ze moeten zijn!)

	# Bereken world-space polygon voor constraining
	_organ_polygon_world = PackedVector2Array()
	for p in polygon:
		_organ_polygon_world.append(p * target_scale_f + body_shape.position)

	# Bereken organ center uit world-space bounding box
	var wmin := Vector2(INF, INF)
	var wmax := Vector2(-INF, -INF)
	for wp in _organ_polygon_world:
		wmin = Vector2(minf(wmin.x, wp.x), minf(wmin.y, wp.y))
		wmax = Vector2(maxf(wmax.x, wp.x), maxf(wmax.y, wp.y))
	_organ_center = (wmin + wmax) / 2.0

	# Achtergrond op volle sterkte houden (zelfde als body builder)
	_background.modulate = Color.WHITE

	# Zet constraint callable op Sticker class
	Sticker._constrain_position = _constrain_to_organ


func _on_sticker_selected(scene: PackedScene, from_position: Vector2) -> void:
	var target = _organ_center if _organ_polygon_world.size() > 0 else get_viewport_rect().size / 2
	var sticker = scene.instantiate()
	sticker.position = from_position
	_sticker_container.add_child(sticker)
	sticker.selection_changed.connect(_on_sticker_selection_changed.bind(sticker))
	# Selecteer de nieuwe sticker automatisch
	sticker._select()
	# Zet nieuwe sticker bovenop
	Sticker._top_z_index += 1
	sticker.z_index = Sticker._top_z_index
	# Fly-from-picker animatie
	var start_scale = sticker.scale * 0.3
	sticker.scale = start_scale
	sticker.modulate.a = 0.0
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.set_parallel()
	tween.tween_property(sticker, "position", target, 0.4)
	tween.tween_property(sticker, "scale", start_scale / 0.3, 0.4)
	tween.tween_property(sticker, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_LINEAR)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_check_trash_zone()
	_update_sliders()
	if _is_playing:
		_update_sticker_pulse(delta)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	# Track touch/mouse positie voor prullenbak detectie
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_last_touch_pos = event.position
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		_last_touch_pos = event.position
	# Voorkom dat touch events door UI heen naar stickers gaan
	if event is InputEventScreenTouch and event.pressed:
		if _is_touch_over_ui(event.position):
			get_viewport().set_input_as_handled()
	# Bij loslaten: selecteer sticker onder de vinger (als er niet gedragged werd)
	if not _any_dragging and not _picker_open:
		var released = false
		if event is InputEventScreenTouch and not event.pressed:
			released = true
		elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			released = true
		if released and not _is_touch_over_ui(event.position):
			_select_sticker_at(event.position)


func _check_trash_zone() -> void:
	if _picker_open:
		return

	var any_dragging_now = false
	for sticker in _sticker_container.get_children():
		if sticker is Sticker and sticker.dragging:
			any_dragging_now = true
			break

	# Toon/verberg knoppen bij drag state wijziging
	if _any_dragging != any_dragging_now:
		_any_dragging = any_dragging_now
		_update_button_visibility()

	# Alleen trash zone checken als er daadwerkelijk gesleept wordt of net losgelaten is
	if not any_dragging_now and _was_dragging.is_empty():
		return

	var trash_screen = _trash_button.get_screen_transform().origin
	var trash_center = trash_screen + _trash_button.size / 2.0
	var finger_dist = _last_touch_pos.distance_to(trash_center)
	var finger_in_zone = finger_dist < trash_zone_radius
	var any_dragging_in_zone = false

	for sticker in _sticker_container.get_children():
		if sticker is Sticker:
			var id = sticker.get_instance_id()
			var is_dragging = sticker.dragging
			var was_dragging = _was_dragging.get(id, false)

			if is_dragging:
				_was_dragging[id] = true
				if finger_in_zone:
					any_dragging_in_zone = true
			elif was_dragging:
				_was_dragging.erase(id)
				if finger_in_zone:
					_delete_sticker(sticker, trash_center)

	# Update modulate alleen bij wijziging
	if _trash_highlighted != any_dragging_in_zone:
		_trash_highlighted = any_dragging_in_zone
		_trash_button.modulate = Color(1.5, 0.5, 0.5) if any_dragging_in_zone else Color.WHITE


func _delete_sticker(sticker: Sticker, trash_center: Vector2) -> void:
	## Animeer sticker naar prullenbak en verwijder
	sticker._deselect()
	sticker.set_process_unhandled_input(false)
	sticker.set_process(false)  # Voorkomt ook snap-back via _check_snap_back
	sticker._outside_boundary = false
	sticker.modulate = Color.WHITE  # Reset rode tint voor delete-animatie
	var tween = create_tween().set_parallel()
	tween.tween_property(sticker, "position", trash_center, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sticker, "scale", Vector2.ZERO, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sticker, "rotation", sticker.rotation + TAU, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sticker, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(sticker.queue_free)


# === MUZIEKDRAGER SELECTIE ===

const DRAGERS = [
	{"id": "groove", "texture": "res://assets/muziekdragers/speelplaat.png"},
	{"id": "klassiek", "texture": "res://assets/muziekdragers/cilinder.png"},
	{"id": "klezmer", "texture": "res://assets/muziekdragers/orgelboek.png"},
	{"id": "pop", "texture": "res://assets/muziekdragers/papierrol.png"},
]



func _setup_drager_overlay() -> void:
	## Muziekdrager picker — zelfde visuele stijl als sticker picker
	_drager_overlay = CanvasLayer.new()
	_drager_overlay.layer = 20

	# Overlay achtergrond (klikbaar om te sluiten)
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(_on_drager_overlay_input)
	_drager_overlay.add_child(overlay)

	# Donker paneel — zelfde stijl als sticker picker
	var panel = Panel.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 70
	panel.offset_top = 40
	panel.offset_right = -70
	panel.offset_bottom = -240
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE  # Witte achtergrond als clip mask
	style.corner_radius_top_left = 30
	style.corner_radius_top_right = 30
	style.corner_radius_bottom_left = 30
	style.corner_radius_bottom_right = 30
	panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	panel.add_theme_stylebox_override("panel", style)
	_drager_overlay.add_child(panel)

	# Gebruik dezelfde gradient als de sticker picker
	var grad_rect = TextureRect.new()
	grad_rect.name = "GradientBG"
	grad_rect.texture = _picker.panel_gradient
	grad_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grad_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad_rect.stretch_mode = TextureRect.STRETCH_SCALE
	grad_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(grad_rect)
	panel.move_child(grad_rect, 0)  # Gradient achter alles

	# Grid met 2x2 dragers, gecentreerd, vullend in het paneel
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 25)
	grid.add_theme_constant_override("v_separation", 25)
	grid.anchor_left = 0.5
	grid.anchor_top = 0.5
	grid.anchor_right = 0.5
	grid.anchor_bottom = 0.5
	grid.grow_horizontal = Control.GROW_DIRECTION_BOTH
	grid.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_child(grid)

	# Bereken icon grootte: vul het paneel zo veel mogelijk
	var icon_size = 420

	for drager in DRAGERS:
		var btn = TextureButton.new()
		var tex = load(drager["texture"]) as Texture2D
		if tex:
			btn.texture_normal = tex
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(icon_size, icon_size)
		btn.pivot_offset = Vector2(icon_size / 2.0, icon_size / 2.0)
		btn.pressed.connect(_on_drager_selected.bind(drager["id"], btn))
		# Hover animatie
		btn.button_down.connect(_on_drager_hover.bind(btn, true))
		btn.button_up.connect(_on_drager_hover.bind(btn, false))
		grid.add_child(btn)

	# Sluit knop onderaan
	var close_btn_scene = preload("res://scenes/fase_sticker_placer/onderdelen/play_button.tscn")
	var close_btn: IconButton = close_btn_scene.instantiate()
	close_btn.icon_type = IconButton.IconType.CLOSE
	close_btn.button_size = 120
	close_btn.anchor_left = 0.5
	close_btn.anchor_right = 0.5
	close_btn.anchor_bottom = 1.0
	close_btn.offset_left = -60
	close_btn.offset_right = 60
	close_btn.offset_top = -190
	close_btn.pressed.connect(_hide_drager_selection)
	_drager_overlay.add_child(close_btn)

	add_child(_drager_overlay)
	_drager_overlay.visible = false


func _on_drager_hover(btn: TextureButton, pressed: bool) -> void:
	## Hover animatie: groter + lichte rotatie bij indrukken
	var tween = btn.get_meta("tween", null) as Tween
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween().set_parallel()
	btn.set_meta("tween", tween)
	if pressed:
		var angle = randf_range(-0.08, 0.08)
		tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.2) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(btn, "rotation", angle, 0.2) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	else:
		tween.tween_property(btn, "scale", Vector2.ONE, 0.4) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		tween.tween_property(btn, "rotation", 0.0, 0.4) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


func _on_drager_overlay_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_hide_drager_selection()


func _show_drager_selection() -> void:
	_drager_selecting = true
	_drager_overlay.visible = true
	_slider_container.visible = false
	_play_button.visible = false


func _hide_drager_selection() -> void:
	_drager_selecting = false
	_drager_overlay.visible = false
	_update_button_visibility()


func _on_drager_selected(genre: String, btn: TextureButton) -> void:
	## Korte selectie-animatie, dan muziek starten
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.2, 1.2), 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.1)
	tween.tween_callback(func():
		_hide_drager_selection()
		_audio_player.set_genre(genre)
		_start_playback()
	)


# === AUDIO PLAYBACK ===

func _on_play_pressed() -> void:
	if _is_playing:
		_stop_playback()
	else:
		_show_drager_selection()


func _start_playback() -> void:
	var active = _scan_active_instruments()
	if active.is_empty():
		return
	_is_playing = true
	_play_button.icon_type = IconButton.IconType.STOP
	_set_stickers_input(false)
	if Sticker._selected_sticker:
		Sticker._selected_sticker._deselect()
	_audio_player.play_layers(active)
	_update_button_visibility()


func _stop_playback() -> void:
	_is_playing = false
	_play_button.icon_type = IconButton.IconType.PLAY
	_audio_player.stop_playback()
	for sticker in _sticker_container.get_children():
		if sticker is Sticker:
			sticker.reset_audio_pulse()
	_set_stickers_input(true)
	_update_button_visibility()


func _scan_active_instruments() -> Dictionary:
	## Bouw dictionary: instrument_id → volume (altijd 1.0) op basis van geplaatste stickers
	var result: Dictionary = {}
	for sticker in _sticker_container.get_children():
		if not sticker is Sticker:
			continue
		var instrument_id = sticker.scene_file_path.get_file().get_basename()
		if instrument_id.is_empty():
			continue
		result[instrument_id] = 1.0
	return result


func _update_sticker_pulse(delta: float) -> void:
	## Pas sticker schaal aan op basis van hun instrument's audio amplitude
	var magnitudes = _audio_player.get_all_magnitudes()
	for sticker in _sticker_container.get_children():
		if not sticker is Sticker:
			continue
		var instrument_id = sticker.scene_file_path.get_file().get_basename()
		var mag = magnitudes.get(instrument_id, 0.0)
		sticker.set_audio_pulse(mag, delta)


# === SLIDERS ===

func _on_sticker_selection_changed(is_selected: bool, sticker: Sticker) -> void:
	if is_selected:
		_tracked_sticker = sticker
		_update_slider_values(sticker)
	elif _tracked_sticker == sticker:
		_tracked_sticker = null
	_update_button_visibility()


func _update_slider_values(sticker: Sticker) -> void:
	## Stel slider waardes in op basis van sticker state
	_updating_sliders = true
	var rot_deg = rad_to_deg(fmod(sticker.rotation, TAU))
	if rot_deg > 180.0:
		rot_deg -= 360.0
	elif rot_deg < -180.0:
		rot_deg += 360.0
	_rotate_slider.value = rot_deg
	_scale_slider.min_value = sticker._base_scale * sticker.min_scale
	_scale_slider.max_value = sticker._base_scale * sticker.max_scale
	_scale_slider.value = sticker.scale.x
	_updating_sliders = false


func _update_sliders() -> void:
	## Synchroniseer slider waardes met sticker (alleen bij pinch/rotate)
	if _tracked_sticker == null or not _slider_container.visible:
		return
	if not _tracked_sticker.dragging:
		return
	_updating_sliders = true
	_scale_slider.value = _tracked_sticker.scale.x
	# Kortste hoekafstand tot huidige slider positie, dan clampen (voorkomt springen)
	var prev = _rotate_slider.value
	var rot_deg = rad_to_deg(_tracked_sticker.rotation)
	var diff = fposmod(rot_deg - prev + 180.0, 360.0) - 180.0
	_rotate_slider.value = clampf(prev + diff, -180.0, 180.0)
	_updating_sliders = false


func _on_rotate_slider_changed(new_value: float) -> void:
	if _updating_sliders or _tracked_sticker == null:
		return
	_tracked_sticker.rotation = deg_to_rad(new_value)


func _on_scale_slider_changed(new_value: float) -> void:
	if _updating_sliders or _tracked_sticker == null:
		return
	_tracked_sticker.scale = Vector2(new_value, new_value)
	_tracked_sticker._target_scale = Vector2(new_value, new_value)


func _resize_background() -> void:
	## Pas achtergrond aan op viewport grootte
	if _background:
		var size: Vector2
		if Engine.is_editor_hint():
			size = Vector2(
				ProjectSettings.get_setting("display/window/size/viewport_width"),
				ProjectSettings.get_setting("display/window/size/viewport_height")
			)
		else:
			size = get_viewport_rect().size
		_background.size = size


# === ORGEL CONTOUR CONSTRAINING ===

func _constrain_to_organ(pos: Vector2) -> Vector2:
	## Beperk positie tot binnen de orgel-contour polygon
	if _organ_polygon_world.size() < 3:
		return pos
	if _point_in_polygon(pos, _organ_polygon_world):
		return pos
	return _nearest_point_on_edge(pos, _organ_polygon_world)


static func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	## Ray-casting point-in-polygon test
	var inside := false
	var n := polygon.size()
	var j := n - 1
	for i in range(n):
		var pi := polygon[i]
		var pj := polygon[j]
		if ((pi.y > point.y) != (pj.y > point.y)) and \
			(point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x):
			inside = not inside
		j = i
	return inside


static func _nearest_point_on_edge(point: Vector2, polygon: PackedVector2Array) -> Vector2:
	## Vind het dichtstbijzijnde punt op de rand van de polygon
	var best_point := polygon[0]
	var best_dist := INF
	var n := polygon.size()
	for i in range(n):
		var a := polygon[i]
		var b := polygon[(i + 1) % n]
		var closest := _closest_point_on_segment(point, a, b)
		var dist := point.distance_squared_to(closest)
		if dist < best_dist:
			best_dist = dist
			best_point = closest
	return best_point


static func _closest_point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	## Vind het dichtstbijzijnde punt op een lijnsegment
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.001:
		return a
	var t := clampf((point - a).dot(ab) / len_sq, 0.0, 1.0)
	return a + ab * t
