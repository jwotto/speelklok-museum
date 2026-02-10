@tool
extends Node2D

## Fase 1: Lichaamsvorm bepalen met 4 schuifknoppen
## Dak (plat/rond/spits), Buik (ingedeukt/recht/bol), Rok (taps/recht/uitlopend), Kleur

signal phase_completed

@onready var _background: TextureRect = $Background
@onready var _body_shape: Node2D = $BodyShape
@onready var _dak_slider: Control = $UILayer/SliderContainer/DakSlider
@onready var _buik_slider: Control = $UILayer/SliderContainer/BuikSlider
@onready var _rok_slider: Control = $UILayer/SliderContainer/RokSlider
@onready var _kleur_slider: Control = $UILayer/SliderContainer/KleurSlider
@onready var _done_button: Button = $UILayer/DoneButton


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
	phase_completed.emit()


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
