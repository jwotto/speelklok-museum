@tool
extends Node2D

## Fase 1: Lichaamsvorm bepalen met 4 schuifknoppen
## Dak (plat/rond/spits), Buik (ingedeukt/recht/bol), Rok (taps/recht/uitlopend), Kleur

signal phase_completed

@onready var _background: TextureRect = $Background
@onready var _body_shape: Node2D = $BodyShape
@onready var _slider_container: HBoxContainer = $UILayer/SliderContainer
@onready var _dak_slider: Control = $UILayer/SliderContainer/LeftSliders/DakSlider
@onready var _buik_slider: Control = $UILayer/SliderContainer/LeftSliders/BuikSlider
@onready var _rok_slider: Control = $UILayer/SliderContainer/RightSliders/RokSlider
@onready var _kleur_slider: Control = $UILayer/SliderContainer/RightSliders/KleurSlider
@onready var _done_button: IconButton = $UILayer/SliderContainer/DoneButton

var _shape_data: Dictionary = {}
var _demo_mode: bool = true
var _demo_time: float = 0.0
var _start_button: Control = null
var _start_delay: float = 0.0  ## Vertraging voordat START knop verschijnt
var _floating_container: Node2D = null
var _spawn_timer: float = 0.0

const INSTRUMENT_TEXTURES = [
	preload("res://afbeeldingen instrumenten/accordeon.png"),
	preload("res://afbeeldingen instrumenten/banjo.png"),
	preload("res://afbeeldingen instrumenten/bellen.png"),
	preload("res://afbeeldingen instrumenten/bongo.png"),
	preload("res://afbeeldingen instrumenten/contrabas.png"),
	preload("res://afbeeldingen instrumenten/gitaar.png"),
	preload("res://afbeeldingen instrumenten/hihat.png"),
	preload("res://afbeeldingen instrumenten/piano.png"),
	preload("res://afbeeldingen instrumenten/snaredrum.png"),
	preload("res://afbeeldingen instrumenten/trompet.png"),
	preload("res://afbeeldingen instrumenten/viool.png"),
	preload("res://afbeeldingen instrumenten/xylofoon.png"),
]


func _ready() -> void:
	_resize_background()
	if Engine.is_editor_hint():
		return

	get_tree().root.size_changed.connect(_resize_background)

	# Slider signals koppelen aan shape updates
	_dak_slider.value_changed.connect(_on_dak_changed)
	_buik_slider.value_changed.connect(_on_buik_changed)
	_rok_slider.value_changed.connect(_on_rok_changed)
	_kleur_slider.value_changed.connect(_on_kleur_changed)
	_done_button.pressed.connect(_on_done_pressed)

	# Start in demo mode
	_slider_container.visible = false
	_start_demo()


func set_phase_data(data: Dictionary) -> void:
	# Ontvang start_delay van main.gd
	if data.has("start_delay"):
		_start_delay = data["start_delay"]


func _start_demo() -> void:
	_demo_mode = true
	_demo_time = 0.0

	# Container voor zwevende stickers (achter de kast)
	_floating_container = Node2D.new()
	add_child(_floating_container)
	move_child(_floating_container, 1)

	# Spawn een flinke groep stickers direct
	for i in 10:
		_spawn_floating_sticker()

	# Maak start knop (met delay als die ingesteld is)
	if _start_delay > 0:
		get_tree().create_timer(_start_delay).timeout.connect(_create_start_button)
	else:
		_create_start_button()


func _create_start_button() -> void:
	## Grote pulserende play knop onderaan het scherm
	# START knop: wit vlak met uitgesneden tekst (knockout effect)
	var btn_w = 450
	var btn_h = 180
	var corner_r = 45

	# Render de knop als image: wit met afgeronde hoeken, tekst als gaten
	var img = Image.create(btn_w, btn_h, true, Image.FORMAT_RGBA8)

	# Vul met wit (afgeronde hoeken)
	for x in btn_w:
		for y in btn_h:
			var in_rect = true
			# Check hoeken
			if x < corner_r and y < corner_r:
				in_rect = Vector2(x - corner_r, y - corner_r).length() <= corner_r
			elif x >= btn_w - corner_r and y < corner_r:
				in_rect = Vector2(x - (btn_w - corner_r), y - corner_r).length() <= corner_r
			elif x < corner_r and y >= btn_h - corner_r:
				in_rect = Vector2(x - corner_r, y - (btn_h - corner_r)).length() <= corner_r
			elif x >= btn_w - corner_r and y >= btn_h - corner_r:
				in_rect = Vector2(x - (btn_w - corner_r), y - (btn_h - corner_r)).length() <= corner_r
			if in_rect:
				img.set_pixel(x, y, Color.WHITE)

	# Render "START" tekst op een apart image
	var font = ThemeDB.fallback_font
	var font_size = 72
	var text_size = font.get_string_size("START", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_x = int((btn_w - text_size.x) / 2.0)
	var text_y = int((btn_h + text_size.y) / 2.0) - int(font.get_descent(font_size))

	# Render tekst naar een SubViewport
	var sv = SubViewport.new()
	sv.size = Vector2i(btn_w, btn_h)
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	var label = Label.new()
	label.text = "START"
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(btn_w, btn_h)
	sv.add_child(label)
	add_child(sv)

	# Wacht een frame zodat de SubViewport rendert
	await get_tree().process_frame
	await get_tree().process_frame

	# Knip de tekst uit de witte achtergrond
	var text_img = sv.get_texture().get_image()
	for x in btn_w:
		for y in btn_h:
			var text_pixel = text_img.get_pixel(x, y)
			if text_pixel.a > 0.3:
				img.set_pixel(x, y, Color(0, 0, 0, 0))  # Gat

	sv.queue_free()

	# Maak TextureButton
	var tex = ImageTexture.create_from_image(img)
	var btn = TextureButton.new()
	btn.texture_normal = tex
	btn.custom_minimum_size = Vector2(btn_w, btn_h)
	btn.pressed.connect(_on_start_pressed)

	_start_button = btn
	_start_button.position = Vector2(540 - btn_w / 2, 1920 - 230 + 10)
	_start_button.pivot_offset = Vector2(btn_w / 2, btn_h / 2)

	$UILayer.add_child(_start_button)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _demo_mode:
		return

	_demo_time += delta

	# Langzaam veranderende kast
	_body_shape.dak = (sin(_demo_time * 0.25) + 1.0) * 0.49 + 0.01
	_body_shape.buik = (sin(_demo_time * 0.253 + 1.5) + 1.0) * 0.49 + 0.01
	_body_shape.rok = (sin(_demo_time * 0.257 + 3.0) + 1.0) * 0.49 + 0.01
	_body_shape.kleur = fmod(_demo_time * 0.04, 0.98) + 0.01

	# Start knop: ademend pulse
	if _start_button:
		var pulse = 1.0 + sin(_demo_time * 2.5) * 0.08
		_start_button.scale = Vector2(pulse, pulse)

	# Spawn nieuwe zwevende stickers
	_spawn_timer += delta
	if _spawn_timer > 2.0:
		_spawn_timer = 0.0
		_spawn_floating_sticker(false)


func _spawn_floating_sticker(_instant: bool = false) -> void:
	## Maak een zwevend instrument dat over het scherm drijft
	if not _floating_container:
		return

	var viewport_size = get_viewport_rect().size
	var tex = INSTRUMENT_TEXTURES[randi() % INSTRUMENT_TEXTURES.size()]

	var sprite = Sprite2D.new()
	sprite.texture = tex
	var s = randf_range(0.15, 0.7)
	sprite.scale = Vector2(s, s)
	sprite.modulate = Color(1, 1, 1, 1.0)
	sprite.rotation = randf_range(-0.3, 0.3)

	# Random kant: 0=links, 1=rechts, 2=boven, 3=onder
	var side = randi() % 4
	var start_pos: Vector2
	var end_pos: Vector2
	var margin = 200.0

	match side:
		0:  # Links naar rechts
			start_pos = Vector2(-margin, randf_range(0, viewport_size.y))
			end_pos = Vector2(viewport_size.x + margin, randf_range(0, viewport_size.y))
		1:  # Rechts naar links
			start_pos = Vector2(viewport_size.x + margin, randf_range(0, viewport_size.y))
			end_pos = Vector2(-margin, randf_range(0, viewport_size.y))
		2:  # Boven naar onder
			start_pos = Vector2(randf_range(0, viewport_size.x), -margin)
			end_pos = Vector2(randf_range(0, viewport_size.x), viewport_size.y + margin)
		3:  # Onder naar boven
			start_pos = Vector2(randf_range(0, viewport_size.x), viewport_size.y + margin)
			end_pos = Vector2(randf_range(0, viewport_size.x), -margin)

	sprite.position = start_pos

	# Alles achter de kast (container zit voor Background, achter BodyShape)

	_floating_container.add_child(sprite)

	# Animeer over het scherm
	var duration = randf_range(12.0, 25.0)
	var tween = create_tween()
	tween.tween_property(sprite, "position", end_pos, duration)
	tween.parallel().tween_property(sprite, "rotation", sprite.rotation + randf_range(-3.0, 3.0), duration)
	tween.tween_callback(sprite.queue_free)


func _on_start_pressed() -> void:
	_demo_mode = false

	# Verwijder start knop met animatie
	if _start_button:
		var tween = create_tween().set_parallel()
		tween.tween_property(_start_button, "scale", Vector2(1.5, 1.5), 0.3) \
			.set_ease(Tween.EASE_OUT)
		tween.tween_property(_start_button, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(func():
			_start_button.queue_free()
			_start_button = null
		)

	# Verwijder zwevende stickers
	if _floating_container:
		var tween_float = create_tween()
		tween_float.tween_property(_floating_container, "modulate:a", 0.0, 0.5)
		tween_float.tween_callback(func():
			_floating_container.queue_free()
			_floating_container = null
		)

	# Toon sliders met fade-in
	_slider_container.visible = true
	_slider_container.modulate.a = 0.0
	var tween2 = create_tween()
	tween2.tween_property(_slider_container, "modulate:a", 1.0, 0.3)

	# Zet slider waarden op de huidige kast vorm
	_dak_slider.value = _body_shape.dak
	_buik_slider.value = _body_shape.buik
	_rok_slider.value = _body_shape.rok
	_kleur_slider.value = _body_shape.kleur


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	# Alleen ESC in demo mode
	pass


func _on_dak_changed(val: float) -> void:
	_body_shape.dak = val


func _on_buik_changed(val: float) -> void:
	_body_shape.buik = val


func _on_rok_changed(val: float) -> void:
	_body_shape.rok = val


func _on_kleur_changed(val: float) -> void:
	_body_shape.kleur = val


func _on_done_pressed() -> void:
	if Engine.is_editor_hint():
		return

	var polygon: PackedVector2Array = _body_shape.get_polygon()

	# Bereken zoom rondom het visuele centrum van de shape (geen verplaatsing)
	var viewport_size := get_viewport_rect().size
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for p in polygon:
		min_p = Vector2(minf(min_p.x, p.x), minf(min_p.y, p.y))
		max_p = Vector2(maxf(max_p.x, p.x), maxf(max_p.y, p.y))
	var shape_size := max_p - min_p

	var target_scale_f := minf(
		viewport_size.x / shape_size.x, viewport_size.y / shape_size.y
	) * 0.88

	# Maak een ECHTE duplicate van de body shape node (ALLE properties automatisch mee)
	var body_duplicate = _body_shape.duplicate()

	_shape_data = {
		"body_node": body_duplicate,
		"zoom_scale": target_scale_f,
		"polygon": polygon,
	}
	_animate_transition()



func get_phase_data() -> Dictionary:
	return _shape_data


func _animate_transition() -> void:
	var target_scale_f: float = _shape_data["zoom_scale"]

	# Stap 1: UI direct weg, foto maken (1 frame)
	_slider_container.visible = false
	_background.visible = false
	get_viewport().transparent_bg = true
	await RenderingServer.frame_post_draw
	_shape_data["front_render"] = get_viewport().get_texture().get_image()
	get_viewport().transparent_bg = false
	_background.visible = true

	# Stap 2: snelle overgang (0.3s)
	var tween := create_tween().set_parallel()
	# Kast schaalt naar target + decoraties faden
	tween.tween_property(_body_shape, "scale", Vector2(target_scale_f, target_scale_f), 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var decoration := _body_shape.get_node_or_null("BodyDecoration")
	if decoration:
		tween.tween_property(decoration, "modulate:a", 0.0, 0.2)
	var outline := _body_shape.get_node_or_null("ShapeOutline")
	if outline:
		tween.tween_property(outline, "modulate:a", 0.0, 0.2)
	# Achtergrond NIET faden — gradient blijft mooi zichtbaar

	tween.chain().tween_callback(phase_completed.emit)


func _resize_background() -> void:
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
