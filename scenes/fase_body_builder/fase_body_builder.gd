@tool
extends Node2D

## Fase 1: Lichaamsvorm bepalen met 4 schuifknoppen
## Dak (plat/rond/spits), Buik (ingedeukt/recht/bol), Rok (taps/recht/uitlopend), Kleur

signal phase_completed

@onready var _background: TextureRect = $Background
@onready var _body_shape: Node2D = $BodyShape
@onready var _slider_container: VBoxContainer = $UILayer/SliderContainer
@onready var _dak_slider: Control = $UILayer/SliderContainer/DakSlider
@onready var _buik_slider: Control = $UILayer/SliderContainer/BuikSlider
@onready var _rok_slider: Control = $UILayer/SliderContainer/RokSlider
@onready var _kleur_slider: Control = $UILayer/SliderContainer/KleurSlider
@onready var _done_button: IconButton = $UILayer/DoneButton

var _shape_data: Dictionary = {}


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

	# Start met default waarden uit de sliders
	_body_shape.dak = _dak_slider.value
	_body_shape.buik = _buik_slider.value
	_body_shape.rok = _rok_slider.value
	_body_shape.kleur = _kleur_slider.value


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
	_shape_data = {
		"polygon": _body_shape.get_polygon(),
		"color": Color.from_hsv(
			_body_shape.kleur, _body_shape.color_saturation, _body_shape.color_value
		),
	}
	_animate_zoom_in()


func get_phase_data() -> Dictionary:
	return _shape_data


func _animate_zoom_in() -> void:
	var viewport_size := get_viewport_rect().size
	var viewport_center := viewport_size / 2.0

	# Bereken bounding box van de polygon
	var polygon: PackedVector2Array = _body_shape.get_polygon()
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for p in polygon:
		min_p = Vector2(minf(min_p.x, p.x), minf(min_p.y, p.y))
		max_p = Vector2(maxf(max_p.x, p.x), maxf(max_p.y, p.y))
	var shape_size := max_p - min_p
	var shape_center_local := (min_p + max_p) / 2.0

	# Target scale zodat contour 88% van viewport vult
	var target_scale_f := minf(
		viewport_size.x / shape_size.x, viewport_size.y / shape_size.y
	) * 0.88
	var target_scale := Vector2(target_scale_f, target_scale_f)

	# Target positie zodat het midden van de contour op viewport center staat
	var target_pos := viewport_center - shape_center_local * target_scale_f

	# Animatie opbouwen
	var tween := create_tween()
	tween.set_parallel()

	# Fade out UI
	tween.tween_property(_slider_container, "modulate:a", 0.0, 0.3)
	tween.tween_property(_done_button, "modulate:a", 0.0, 0.3)

	# Fade out decoraties en outline (laat alleen ShapeFill over)
	var decoration := _body_shape.get_node_or_null("BodyDecoration")
	var outline := _body_shape.get_node_or_null("ShapeOutline")
	if decoration:
		tween.tween_property(decoration, "modulate:a", 0.0, 0.4).set_delay(0.15)
	if outline:
		tween.tween_property(outline, "modulate:a", 0.0, 0.4).set_delay(0.15)

	# Zoom body shape naar het midden van het scherm
	tween.tween_property(_body_shape, "scale", target_scale, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_body_shape, "position", target_pos, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# Fade achtergrond
	tween.tween_property(_background, "modulate:a", 0.0, 0.5).set_delay(0.3)

	# Na animatie: volgende fase
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
