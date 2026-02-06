extends Node2D

## Main scene controller - beheert stickers en picker

@export var sticker_scene: PackedScene
@export var sticker_textures: Array[Texture2D] = []

var _picker: StickerPicker
var _add_button: TextureButton
var _trash_button: TextureButton
var _sticker_container: Node2D
var _ui_layer: CanvasLayer
var _was_dragging: Dictionary = {}  # Sticker -> was dragging last frame

const TRASH_SIZE = 80
const TRASH_ZONE_RADIUS = 100.0


func _ready() -> void:
	_create_ui_layer()
	_create_sticker_container()
	_create_trash_button()
	_create_add_button()
	_create_picker()


func _create_ui_layer() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UILayer"
	_ui_layer.layer = 10  # Boven alles
	add_child(_ui_layer)


func _create_sticker_container() -> void:
	_sticker_container = Node2D.new()
	_sticker_container.name = "Stickers"
	add_child(_sticker_container)


func _create_trash_button() -> void:
	_trash_button = TextureButton.new()
	_trash_button.name = "TrashButton"
	_trash_button.z_index = 50

	# Maak prullenbak texture
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

	var tex = ImageTexture.create_from_image(img)
	_trash_button.texture_normal = tex
	_trash_button.position = Vector2(20, 20)
	_ui_layer.add_child(_trash_button)


func _create_add_button() -> void:
	_add_button = TextureButton.new()
	_add_button.name = "AddButton"
	_add_button.z_index = 50

	# Maak een simpele + texture
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

	var tex = ImageTexture.create_from_image(img)
	_add_button.texture_normal = tex

	# Positie rechtsboven
	_add_button.position = Vector2(get_viewport_rect().size.x - 100, 20)
	_add_button.pressed.connect(_on_add_pressed)
	_ui_layer.add_child(_add_button)


func _create_picker() -> void:
	_picker = StickerPicker.new()
	_picker.name = "Picker"
	_picker.sticker_textures = sticker_textures
	_picker.sticker_selected.connect(_on_sticker_selected)
	_picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_picker)


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
	_check_trash_zone()


func _input(event: InputEvent) -> void:
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
