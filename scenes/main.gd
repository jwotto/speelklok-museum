@tool
extends Node2D

## Main scene controller - beheert stickers en picker

@export_group("Trash")
## Hoe dicht (in pixels) de vinger bij de prullenbak moet zijn om een sticker te verwijderen bij loslaten
@export var trash_zone_radius: float = 140.0

# Scene node references
@onready var _background: TextureRect = $Background
@onready var _sticker_container: Node2D = $Stickers
@onready var _trash_button: IconButton = $UILayer/TrashButton
@onready var _add_button: IconButton = $UILayer/AddButton
@onready var _picker: StickerPicker = $UILayer/StickerPicker

var _was_dragging: Dictionary = {}  # instance_id -> was dragging last frame
var _last_touch_pos: Vector2 = Vector2.ZERO  # Laatste vinger/muis positie
var _trash_highlighted: bool = false
var _any_dragging: bool = false
var _picker_open: bool = false


func _ready() -> void:
	_resize_background()
	if Engine.is_editor_hint():
		return

	# Runtime setup
	_trash_button.visible = false
	get_tree().root.size_changed.connect(_resize_background)
	_add_button.pressed.connect(_on_add_pressed)
	_picker.sticker_selected.connect(_on_sticker_selected)
	_picker.opened.connect(_on_picker_opened)
	_picker.closed.connect(_on_picker_closed)


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
		_trash_button.visible = false
		_add_button.visible = false
	elif _any_dragging:
		_trash_button.visible = true
		_add_button.visible = false
	else:
		_trash_button.visible = false
		_add_button.visible = true


func _is_touch_over_ui(pos: Vector2) -> bool:
	for btn: Control in [_add_button, _trash_button]:
		if btn.visible and btn.get_global_rect().has_point(pos):
			return true
	return false


func _set_stickers_input(enabled: bool) -> void:
	for sticker in _sticker_container.get_children():
		if sticker is Sticker:
			sticker.set_process_unhandled_input(enabled)


func _on_sticker_selected(scene: PackedScene, from_position: Vector2) -> void:
	var target = get_viewport_rect().size / 2
	var sticker = scene.instantiate()
	sticker.position = from_position
	_sticker_container.add_child(sticker)
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


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	# ESC = afsluiten
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
	# Track touch/mouse positie voor prullenbak detectie
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_last_touch_pos = event.position
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		_last_touch_pos = event.position
	# Consumeer touch events die op een zichtbare UI knop vallen
	# zodat stickers (via _unhandled_input) ze niet oppakken
	if event is InputEventScreenTouch and event.pressed:
		if _is_touch_over_ui(event.position):
			get_viewport().set_input_as_handled()


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
	sticker.set_process_unhandled_input(false)
	sticker.set_process(false)
	var tween = create_tween().set_parallel()
	tween.tween_property(sticker, "position", trash_center, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sticker, "scale", Vector2.ZERO, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sticker, "rotation", sticker.rotation + TAU, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sticker, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(sticker.queue_free)
