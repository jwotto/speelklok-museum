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

const TRASH_SIZE = 80
const TRASH_ZONE_RADIUS = 100.0


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
	var cx = TRASH_SIZE / 2
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
	var img = Image.create(80, 80, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.3, 0.3, 0.8))

	# Teken + teken
	var center = 40
	var thickness = 8
	var length = 30
	for x in range(center - length, center + length + 1):
		for y in range(center - thickness/2, center + thickness/2 + 1):
			img.set_pixel(x, y, Color.WHITE)
	for y in range(center - length, center + length + 1):
		for x in range(center - thickness/2, center + thickness/2 + 1):
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


func _check_trash_zone() -> void:
	# Check of een sticker in de prullenbak zone wordt losgelaten
	var trash_center = _trash_button.position + Vector2(TRASH_SIZE / 2.0, TRASH_SIZE / 2.0)
	var any_dragging_in_zone = false

	for sticker in _sticker_container.get_children():
		if sticker is Sticker:
			var dist = sticker.global_position.distance_to(trash_center)
			var in_zone = dist < TRASH_ZONE_RADIUS
			var is_active = sticker.dragging or sticker._inertia_active
			var was_active = _was_dragging.get(sticker, false)

			# Track voor volgende frame
			_was_dragging[sticker] = is_active

			# Highlight trash als sticker erboven is
			if is_active and in_zone:
				any_dragging_in_zone = true

			# Verwijder alleen als NET gestopt en in zone
			if was_active and not is_active and in_zone:
				_was_dragging.erase(sticker)
				sticker.queue_free()

	_trash_button.modulate = Color(1.5, 0.5, 0.5) if any_dragging_in_zone else Color.WHITE
