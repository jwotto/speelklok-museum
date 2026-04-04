@tool
extends Control

## Draaibaar wiel dat angular velocity berekent op basis van touch drag.
## Geeft een speed_factor (0.0 - 2.0) die aan audio playback gekoppeld kan worden.

signal speed_changed(speed_factor: float)

@export var wheel_texture: Texture2D = preload("res://assets/muziekdragers/draaiwiel.png")
@export var wheel_size: float = 750.0  ## Diameter van het wiel in pixels
## Hoe snel het wiel vertraagt zonder input (0 = nooit, 1 = instant)
@export_range(0.0, 1.0) var friction: float = 0.03
## Maximale snelheidsfactor (1.0 = normaal tempo)
@export var max_speed: float = 1.0  ## Max 1.0 = normaal tempo, nooit sneller
## Hoe gevoelig de draaibeweging is
@export var sensitivity: float = 4.0

var _wheel_sprite: TextureRect
var _current_rotation: float = 0.0  ## Huidige hoek van het wiel (radialen)
var _angular_velocity: float = 0.0  ## Hoeksnelheid (radialen per seconde)
var _touch_active: bool = false
var _touch_index: int = -1
var _prev_angle: float = 0.0
var _speed_factor: float = 0.0  ## 0.0 - max_speed


func _ready() -> void:
	# Maak het wiel als TextureRect
	_wheel_sprite = TextureRect.new()
	_wheel_sprite.texture = wheel_texture
	_wheel_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wheel_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_wheel_sprite.custom_minimum_size = Vector2(wheel_size, wheel_size)
	_wheel_sprite.size = Vector2(wheel_size, wheel_size)
	_wheel_sprite.pivot_offset = Vector2(wheel_size / 2.0, wheel_size / 2.0)
	_wheel_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wheel_sprite)

	custom_minimum_size = Vector2(wheel_size, wheel_size)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Frictie: vertraag als niet aangeraakt
	if not _touch_active:
		_angular_velocity *= (1.0 - friction)
		if absf(_angular_velocity) < 0.05:
			_angular_velocity = 0.0

	# Clamp angular velocity zodat het wiel niet sneller draait dan max tempo
	var max_angular = PI * 2.0 * max_speed / sensitivity
	_angular_velocity = clampf(_angular_velocity, -max_angular, max_angular)

	# Update rotatie op basis van velocity
	_current_rotation += _angular_velocity * delta
	_wheel_sprite.rotation = _current_rotation

	# Bereken speed factor van angular velocity
	var new_speed = clampf(absf(_angular_velocity) / (PI * 2.0) * sensitivity, 0.0, max_speed)

	# Smooth de speed factor
	_speed_factor = lerpf(_speed_factor, new_speed, 0.15)
	speed_changed.emit(_speed_factor)


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_active = true
			_touch_index = event.index
			_prev_angle = _get_touch_angle(event.position)
			accept_event()
		elif event.index == _touch_index:
			_touch_active = false
			_touch_index = -1
			accept_event()

	elif event is InputEventScreenDrag and event.index == _touch_index:
		var current_angle = _get_touch_angle(event.position)
		var delta_angle = current_angle - _prev_angle

		# Fix voor angle wrapping (-PI ↔ PI)
		if delta_angle > PI:
			delta_angle -= TAU
		elif delta_angle < -PI:
			delta_angle += TAU

		_angular_velocity = delta_angle / get_process_delta_time() if get_process_delta_time() > 0 else 0.0
		_current_rotation += delta_angle
		_wheel_sprite.rotation = _current_rotation
		_prev_angle = current_angle
		accept_event()


func _get_touch_angle(touch_pos: Vector2) -> float:
	## Bereken de hoek van de touch positie t.o.v. het midden van het wiel
	var center = size / 2.0
	var local_pos = touch_pos - center
	return atan2(local_pos.y, local_pos.x)


func get_speed_factor() -> float:
	return _speed_factor


func reset() -> void:
	_angular_velocity = 0.0
	_speed_factor = 0.0
	_current_rotation = 0.0
	_touch_active = false
	_touch_index = -1
	if _wheel_sprite:
		_wheel_sprite.rotation = 0.0
