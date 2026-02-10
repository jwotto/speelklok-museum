@tool
extends Node2D

## Flow controller - schakelt tussen fasen van de installatie
## Toets 1-9 om tussen fases te wisselen

signal phase_completed(phase_index: int)

@export_group("Phases")
## Array van phase scenes in volgorde
@export var phase_scenes: Array[PackedScene] = []
## Welke fase start bij opstarten (0-indexed)
@export var start_phase_index: int = 1

@onready var _phase_container: Node2D = $PhaseContainer

var _current_phase_index: int = -1
var _current_phase: Node = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Globale touch-naar-muis emulatie (Godot editor verwijdert deze setting steeds)
	Input.emulate_mouse_from_touch = true

	start_phase(start_phase_index)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	# ESC = afsluiten
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		# Toets 1-9 = wissel naar fase
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var index = event.keycode - KEY_1
			if index < phase_scenes.size():
				start_phase(index)


func start_phase(index: int) -> void:
	## Laad en activeer een fase
	if index < 0 or index >= phase_scenes.size():
		return
	if index == _current_phase_index:
		return
	# Verwijder huidige fase
	if _current_phase != null:
		_current_phase.queue_free()
		_current_phase = null
	# Instantiate nieuwe fase
	_current_phase_index = index
	_current_phase = phase_scenes[index].instantiate()
	_phase_container.add_child(_current_phase)
	# Verbind phase_completed signal als de fase dat heeft
	if _current_phase.has_signal("phase_completed"):
		_current_phase.phase_completed.connect(_on_phase_completed)


func _on_phase_completed() -> void:
	phase_completed.emit(_current_phase_index)
	start_phase(_current_phase_index + 1)
