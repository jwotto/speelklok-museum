@tool
extends Node2D

## Fase 1: Lichaamsvorm bepalen (5 vragen -> contour)
## Placeholder - wordt later uitgewerkt

signal phase_completed

@onready var _background: TextureRect = $Background


func _ready() -> void:
	_resize_background()
	if Engine.is_editor_hint():
		return

	get_tree().root.size_changed.connect(_resize_background)
	# TODO: Implementeer 5 vragen voor lichaamsvorm


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
