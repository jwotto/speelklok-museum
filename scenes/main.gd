@tool
extends Node2D

## Main scene controller - beheert stickers en picker

@export var sticker_scene: PackedScene

# Scene node references
@onready var _sticker_container: Node2D = $Stickers
@onready var _trash_button: TextureButton = $UILayer/TrashButton
@onready var _add_button: TextureButton = $UILayer/AddButton
@onready var _picker: StickerPicker = $UILayer/StickerPicker

var _was_dragging: Dictionary = {}  # Sticker -> was dragging last frame
var _last_touch_pos: Vector2 = Vector2.ZERO  # Laatste vinger/muis positie

const TRASH_SIZE = 120
const TRASH_ZONE_RADIUS = 140.0


func _ready() -> void:
	if Engine.is_editor_hint():
		_setup_editor_preview()
		return

	# Runtime setup
	_setup_button_textures()
	_add_button.pressed.connect(_on_add_pressed)
	_picker.sticker_selected.connect(_on_sticker_selected)


func _setup_editor_preview() -> void:
	# Maak button textures zichtbaar in editor
	_setup_button_textures()


func _setup_button_textures() -> void:
	# Trash button texture
	if _trash_button:
		_trash_button.texture_normal = _create_trash_texture()

	# Add button texture
	if _add_button:
		_add_button.texture_normal = _create_add_texture()


func _create_trash_texture() -> ImageTexture:
	var img = Image.create(TRASH_SIZE, TRASH_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.4, 0.2, 0.2, 0.8))

	# Teken simpele prullenbak vorm
	@warning_ignore("integer_division")
	var cx: int = TRASH_SIZE / 2
	# Deksel
	for x in range(10, TRASH_SIZE - 10):
		for y in range(15, 25):
			img.set_pixel(x, y, Color.WHITE)
	# Handvat
	for x in range(cx - 10, cx + 10):
		for y in range(5, 15):
			img.set_pixel(x, y, Color.WHITE)
	# Bak
	for x in range(15, TRASH_SIZE - 15):
		for y in range(25, TRASH_SIZE - 10):
			if x < 20 or x > TRASH_SIZE - 20 or y > TRASH_SIZE - 15:
				img.set_pixel(x, y, Color.WHITE)

	return ImageTexture.create_from_image(img)


func _create_add_texture() -> ImageTexture:
	var img = Image.create(TRASH_SIZE, TRASH_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.3, 0.3, 0.8))

	# Teken + teken
	var center = int(TRASH_SIZE / 2.0)
	var half_thick = 6  # thickness / 2
	var length = 45
	for x in range(center - length, center + length + 1):
		for y in range(center - half_thick, center + half_thick + 1):
			img.set_pixel(x, y, Color.WHITE)
	for y in range(center - length, center + length + 1):
		for x in range(center - half_thick, center + half_thick + 1):
			img.set_pixel(x, y, Color.WHITE)

	return ImageTexture.create_from_image(img)


func _on_add_pressed() -> void:
	_picker.toggle()


func _on_sticker_selected(tex: Texture2D) -> void:
	if sticker_scene == null:
		push_error("Sticker scene niet ingesteld!")
		return

	var sticker = sticker_scene.instantiate()
	sticker.texture = tex
	sticker.position = get_viewport_rect().size / 2  # Spawn in midden
	sticker.scale = Vector2(0.25, 0.25)
	_sticker_container.add_child(sticker)
	# Zet nieuwe sticker bovenop
	Sticker._top_z_index += 1
	sticker.z_index = Sticker._top_z_index


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


func _check_trash_zone() -> void:
	# Check of vinger in prullenbak zone is (niet sticker positie!)
	var trash_center = _trash_button.position + Vector2(TRASH_SIZE / 2.0, TRASH_SIZE / 2.0)
	var finger_dist = _last_touch_pos.distance_to(trash_center)
	var finger_in_zone = finger_dist < TRASH_ZONE_RADIUS
	var any_dragging_in_zone = false

	for sticker in _sticker_container.get_children():
		if sticker is Sticker:
			var is_dragging = sticker.dragging
			var was_dragging = _was_dragging.get(sticker, false)

			# Track voor volgende frame
			_was_dragging[sticker] = is_dragging

			# Highlight trash als vinger erboven is tijdens slepen
			if is_dragging and finger_in_zone:
				any_dragging_in_zone = true

			# Verwijder zodra vinger losgelaten wordt in zone
			if was_dragging and not is_dragging and finger_in_zone:
				_was_dragging.erase(sticker)
				sticker.queue_free()

	_trash_button.modulate = Color(1.5, 0.5, 0.5) if any_dragging_in_zone else Color.WHITE
