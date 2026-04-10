@tool
extends Node2D

## Flow controller - schakelt tussen fasen van de installatie
## Toets 1-9 om tussen fases te wisselen

signal phase_completed(phase_index: int)

@export_group("Phases")
## Array van phase scenes in volgorde
@export var phase_scenes: Array[PackedScene] = []
## Welke fase start bij opstarten (0-indexed)
@export var start_phase_index: int = 0

@export_group("Inactiviteit")
## Seconden zonder input voordat de app terug naar start gaat
@export var inactivity_timeout: float = 60.0
## Seconden wachten na reset voordat de START knop verschijnt
@export var start_delay: float = 4.0

@onready var _phase_container: Node2D = $PhaseContainer

var _current_phase_index: int = -1
var _current_phase: Node = null
var _phase_data: Dictionary = {}
var _inactivity_timer: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Globale touch-naar-muis emulatie (Godot editor verwijdert deze setting steeds)
	Input.emulate_mouse_from_touch = true
	# Overschrijf titel (verwijdert "(DEBUG)" label)
	DisplayServer.window_set_title("Speelklok Museum")
	# Borderless + exclusive fullscreen — geen titelbalk, blokkeert OS edge gestures
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	start_phase(start_phase_index)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Inactiviteit: terug naar start na timeout
	# Niet tijdens demo mode (fase 0 met _demo_mode aan)
	var in_demo = _current_phase_index == 0 and _current_phase and _current_phase.get("_demo_mode")
	if not in_demo:
		_inactivity_timer += delta
		if _inactivity_timer >= inactivity_timeout:
			_inactivity_timer = 0.0
			_phase_data = {"start_delay": start_delay}
			_current_phase_index = -1
			start_phase(0)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	# Reset inactiviteit timer bij elke input
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton:
		_inactivity_timer = 0.0
	# ESC = afsluiten
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		# F11 = toggle fullscreen
		elif event.keycode == KEY_F11:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		# Toets 1-9 = wissel naar fase
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var index = event.keycode - KEY_1
			if index < phase_scenes.size():
				_phase_data = {}
				start_phase(index)


func start_phase(index: int) -> void:
	## Laad en activeer een fase
	if index < 0 or index >= phase_scenes.size():
		return
	if index == _current_phase_index and _current_phase != null:
		return
	# Verwijder huidige fase
	if _current_phase != null:
		_current_phase.queue_free()
		_current_phase = null
	# Instantiate nieuwe fase
	_current_phase_index = index
	_current_phase = phase_scenes[index].instantiate()
	_phase_container.add_child(_current_phase)
	# Geef data door — bij terugkeer naar start, stuur start_delay mee
	if index == 0 and _phase_data.is_empty():
		_phase_data = {"start_delay": start_delay}
	if _current_phase.has_method("set_phase_data") and _phase_data.size() > 0:
		_current_phase.set_phase_data(_phase_data)
	# Verbind phase_completed signal als de fase dat heeft
	if _current_phase.has_signal("phase_completed"):
		_current_phase.phase_completed.connect(_on_phase_completed)


func _on_phase_completed() -> void:
	# Haal data op van huidige fase voordat die vernietigd wordt
	if _current_phase.has_method("get_phase_data"):
		_phase_data = _current_phase.get_phase_data()
	phase_completed.emit(_current_phase_index)
	start_phase(_current_phase_index + 1)
