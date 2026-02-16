@tool
extends Node2D

## Fase 2: Muziekinstrumenten plaatsen
## Self-contained scene met sticker plaatsing, prullenbak, picker en sliders

signal phase_completed

@export_group("Trash")
## Hoe dicht (in pixels) de vinger bij de prullenbak moet zijn om een sticker te verwijderen bij loslaten
@export var trash_zone_radius: float = 210.0

# Scene node references
@onready var _background: TextureRect = $Background
@onready var _sticker_container: Node2D = $Stickers
@onready var _trash_button: IconButton = $UILayer/StickerSliders/TrashButton
@onready var _add_button: IconButton = $UILayer/StickerSliders/AddButton
@onready var _picker: StickerPicker = $UILayer/StickerPicker
@onready var _slider_container: HBoxContainer = $UILayer/StickerSliders
@onready var _rotate_slider: Control = $UILayer/StickerSliders/RotateSlider
@onready var _scale_slider: Control = $UILayer/StickerSliders/ScaleSlider

var _was_dragging: Dictionary = {}  # instance_id -> was dragging last frame
var _last_touch_pos: Vector2 = Vector2.ZERO  # Laatste vinger/muis positie
var _trash_highlighted: bool = false
var _any_dragging: bool = false
var _picker_open: bool = false
var _tracked_sticker: Sticker = null
var _updating_sliders: bool = false
var _organ_polygon_world: PackedVector2Array = PackedVector2Array()
var _organ_center: Vector2 = Vector2.ZERO


func _ready() -> void:
	_resize_background()
	if Engine.is_editor_hint():
		return

	get_tree().root.size_changed.connect(_resize_background)
	Sticker.reset_statics()

	# Runtime setup
	_trash_button.visible = false
	_add_button.pressed.connect(_on_add_pressed)
	_picker.sticker_selected.connect(_on_sticker_selected)
	_picker.opened.connect(_on_picker_opened)
	_picker.closed.connect(_on_picker_closed)
	_rotate_slider.value_changed.connect(_on_rotate_slider_changed)
	_scale_slider.value_changed.connect(_on_scale_slider_changed)


func _on_add_pressed() -> void:
	_picker.toggle()


func _on_picker_opened() -> void:
	_picker_open = true
	_update_button_visibility()
	_set_stickers_input(false)


func _on_picker_closed() -> void:
	_picker_open = false
	_update_button_visibility()
	_set_stickers_input(true)


func _update_button_visibility() -> void:
	if _picker_open:
		_slider_container.visible = false
		return
	# Container altijd zichtbaar (bevat nu ook knoppen)
	_slider_container.visible = true
	_trash_button.visible = _any_dragging
	_add_button.visible = not _any_dragging
	# Sliders: alleen tonen als sticker geselecteerd
	var show_sliders := _tracked_sticker != null
	_rotate_slider.visible = show_sliders
	_scale_slider.visible = show_sliders


func _is_touch_over_ui(pos: Vector2) -> bool:
	## Check of de positie boven een UI element valt
	for btn: Control in [_add_button, _trash_button]:
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


func set_phase_data(data: Dictionary) -> void:
	## Ontvang polygon + kleur + zoom positie van de body builder fase
	if not data.has("polygon") or not data.has("color"):
		return
	var polygon: PackedVector2Array = data["polygon"]
	var color: Color = data["color"]

	# Gebruik exact dezelfde zoom waarden als de body builder animatie
	var target_scale_f: float = data["zoom_scale"]
	var contour_pos: Vector2 = data["zoom_position"]

	# Maak OrganContour node
	var OrganContourScript = preload("res://scenes/fase_sticker_placer/onderdelen/organ_contour.gd")
	var contour := Node2D.new()
	contour.set_script(OrganContourScript)
	contour.name = "OrganContour"
	contour.position = contour_pos
	contour.scale = Vector2(target_scale_f, target_scale_f)

	# Voeg toe vóór Stickers container (z-order: achtergrond)
	add_child(contour)
	move_child(contour, _sticker_container.get_index())
	contour.setup(polygon, color)

	# Bereken world-space polygon voor constraining
	_organ_polygon_world = PackedVector2Array()
	for p in polygon:
		_organ_polygon_world.append(p * target_scale_f + contour_pos)

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


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_check_trash_zone()
	_update_sliders()


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
	# Check of vinger in prullenbak zone is (niet sticker positie!)
	var trash_screen = _trash_button.get_screen_transform().origin
	var trash_center = trash_screen + _trash_button.size / 2.0
	var finger_dist = _last_touch_pos.distance_to(trash_center)
	var finger_in_zone = finger_dist < trash_zone_radius
	var any_dragging_in_zone = false
	var any_dragging_now = false

	for sticker in _sticker_container.get_children():
		if sticker is Sticker:
			var id = sticker.get_instance_id()
			var is_dragging = sticker.dragging
			var was_dragging = _was_dragging.get(id, false)

			# Track voor volgende frame
			_was_dragging[id] = is_dragging

			if is_dragging:
				any_dragging_now = true

			# Highlight trash als vinger erboven is tijdens slepen
			if is_dragging and finger_in_zone:
				any_dragging_in_zone = true

			# Verwijder zodra vinger losgelaten wordt in zone
			if was_dragging and not is_dragging and finger_in_zone:
				_was_dragging.erase(id)
				_delete_sticker(sticker, trash_center)

	# Toon/verberg knoppen bij drag state wijziging
	if _any_dragging != any_dragging_now:
		_any_dragging = any_dragging_now
		_update_button_visibility()

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
	## Synchroniseer slider waardes met sticker (voor pinch/rotate updates)
	if _tracked_sticker == null or not _slider_container.visible:
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
