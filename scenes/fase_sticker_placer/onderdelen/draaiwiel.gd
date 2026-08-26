@tool
extends Control

## Draaibaar wiel dat angular velocity berekent op basis van touch drag.
## Geeft een speed_factor (0.0 - 2.0) die aan audio playback gekoppeld kan worden.

signal speed_changed(speed_factor: float)
## Het wiel is klaar met vanzelf draaien — vanaf nu moet de bezoeker het doen
@warning_ignore("unused_signal")
signal auto_spin_finished

@export var wheel_texture: Texture2D = preload("res://assets/muziekdragers/draaiwiel.png")
@export var wheel_size: float = 750.0  ## Diameter van het wiel in pixels
## Extra pixels rondom het wiel die ook touch detecteren
@export var touch_margin: float = 100.0
## Hoe snel het wiel vertraagt zonder input (0 = nooit, 1 = instant).
## Laag houden: het wiel loopt dan langzaam uit, als een plaat die uitdraait.
@export_range(0.0, 1.0) var friction: float = 0.015
## Maximale snelheidsfactor (1.0 = normaal tempo)
@export var max_speed: float = 1.0  ## Max 1.0 = normaal tempo, nooit sneller
## Hoe gevoelig de draaibeweging is
@export var sensitivity: float = 4.0

@export_group("Hint")
## Grootte van het meedraaiende handje in pixels
@export var hint_hand_size: float = 150.0
## Dikte van de witte rand om het handje in scherm-pixels
@export var hint_hand_outline: float = 8.0
## Afstand van het handje tot het midden, als fractie van de wieldiameter.
## 0.369 = precies op het handvat van dit wiel (opgemeten uit de afbeelding).
@export_range(0.0, 0.5) var hint_hand_radius: float = 0.369
## Hoek waaronder het handvat op de wiel-afbeelding staat, in graden
@export var hint_hand_angle: float = 115.2

@export_group("Automatisch draaien")
## Snelheid waarmee het wiel vanzelf draait bij het voordoen (radialen/seconde)
@export var auto_spin_speed: float = 2.5
## Hoelang het wiel erover doet om op snelheid te komen — een opstart-zwengel
@export var auto_spin_rampup: float = 1.2

const HAND_TEXTURE := preload("res://assets/icons/hand-pointing.svg")

var _wheel_sprite: TextureRect
var _current_rotation: float = 0.0
var _angular_velocity: float = 0.0
var _touch_active: bool = false
var _touch_index: int = -1
var _prev_angle: float = 0.0
var _speed_factor: float = 0.0
var _hint_arrows: Node2D = null  ## Draaiende pijlen hint
var _hint_hand: Sprite2D = null  ## Handje op het handvat, blijft rechtop
var _hint_hand_pivot: Node2D = null  ## Draait mee met het wiel, niet met de pijlen
var _hint_time: float = 0.0
var _auto_spin_left: float = 0.0  ## Resterende tijd dat het wiel vanzelf draait
var _auto_spin_time: float = 0.0  ## Tijd sinds het voordoen begon, voor de opstart
var _user_has_spun: bool = false  ## Heeft de bezoeker zelf al gedraaid?


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

	# Hint pijlen rondom het wiel
	_create_hint_arrows()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if _auto_spin_left > 0.0:
		# Het wiel draait even vanzelf om voor te doen wat de bedoeling is,
		# en komt daarbij rustig op gang alsof er aangezwengeld wordt
		_auto_spin_left -= delta
		_auto_spin_time += delta
		var ramp := 1.0
		if auto_spin_rampup > 0.0:
			ramp = smoothstep(0.0, auto_spin_rampup, _auto_spin_time)
		_angular_velocity = auto_spin_speed * ramp
		_current_rotation += _angular_velocity * delta
		_wheel_sprite.rotation = _current_rotation
		if _auto_spin_left <= 0.0:
			_auto_spin_left = 0.0
			# Snelheid laten staan: de frictie hieronder laat het wiel
			# nu vanzelf uitlopen, alsof je de slinger loslaat
			auto_spin_finished.emit()
	elif not _touch_active:
		# Frictie: vertraag als niet aangeraakt
		_angular_velocity *= (1.0 - friction)
		if absf(_angular_velocity) < 0.05:
			_angular_velocity = 0.0
		# Alleen bij frictie het wiel laten draaien (bij touch doet _gui_input dit)
		_current_rotation += _angular_velocity * delta
		_wheel_sprite.rotation = _current_rotation

	# Hint pijlen updaten
	_update_hint_arrows(delta)

	# Bereken speed factor — clamp alleen de output, niet het wiel
	var new_speed = clampf(absf(_angular_velocity) / (PI * 2.0) * sensitivity, 0.0, max_speed)

	# Smooth de speed factor
	_speed_factor = lerpf(_speed_factor, new_speed, 0.15)
	speed_changed.emit(_speed_factor)


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			# Bezoeker pakt het wiel: klaar met voordoen
			_auto_spin_left = 0.0
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
		# Pas als er echt gedraaid wordt telt het als "zelf draaien"
		if absf(delta_angle) > 0.01:
			_user_has_spun = true
		accept_event()


func _create_hint_arrows() -> void:
	## Maak 4 gebogen pijlen rondom het wiel die de draairichting aangeven
	_hint_arrows = Node2D.new()
	_hint_arrows.position = Vector2(wheel_size / 2.0, wheel_size / 2.0)
	add_child(_hint_arrows)

	var arrow_radius = wheel_size * 0.46
	var arrow_size = 30.0

	for i in 2:
		var angle = i * TAU / 2.0
		var arrow = _create_arrow_sprite(arrow_size)
		arrow.position = Vector2(cos(angle), sin(angle)) * arrow_radius
		arrow.rotation = angle + PI  # Wijst in draairichting (met de klok mee)
		_hint_arrows.add_child(arrow)

	# Handje op het handvat van het wiel. Eigen draaipunt, want het moet met het
	# WIEL meedraaien (en dus op het handvat blijven), niet met de pijlen
	_hint_hand_pivot = Node2D.new()
	_hint_hand_pivot.position = Vector2(wheel_size / 2.0, wheel_size / 2.0)
	_hint_hand_pivot.modulate.a = 0.0
	_hint_hand_pivot.visible = false
	add_child(_hint_hand_pivot)

	var hand_angle = deg_to_rad(hint_hand_angle)
	_hint_hand = _create_hand_sprite()
	_hint_hand.position = Vector2(cos(hand_angle), sin(hand_angle)) * (wheel_size * hint_hand_radius)
	_hint_hand_pivot.add_child(_hint_hand)


func _create_hand_sprite() -> Sprite2D:
	## Handje met witte rand — zelfde icoon en stijl als de sleep-hint
	return OutlinedIcon.create(HAND_TEXTURE, hint_hand_size, hint_hand_outline)


func _create_arrow_sprite(arrow_size: float) -> Node2D:
	var arrow = Node2D.new()

	# Staart lijn achter de pijl
	var line = Line2D.new()
	line.points = PackedVector2Array([
		Vector2(0, arrow_size * 0.3),
		Vector2(0, arrow_size * 1.2),
	])
	line.width = 4.0
	line.default_color = Color.WHITE
	arrow.add_child(line)

	# Pijlpunt (driehoek, wijst omhoog/in draairichting)
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(0, -arrow_size * 0.5),
		Vector2(-arrow_size * 0.4, arrow_size * 0.3),
		Vector2(arrow_size * 0.4, arrow_size * 0.3),
	])
	poly.color = Color.WHITE
	arrow.add_child(poly)

	return arrow


func _update_hint_arrows(delta: float) -> void:
	if not _hint_arrows:
		return

	_hint_time += delta

	# Pijlen: verbergen zodra het wiel draait of aangeraakt wordt
	var target_alpha = 0.0 if _touch_active or absf(_angular_velocity) > 0.5 else 1.0
	_hint_arrows.modulate.a = lerpf(_hint_arrows.modulate.a, target_alpha, 0.1)
	if _hint_arrows.modulate.a > 0.01:
		_hint_arrows.rotation = _hint_time * 0.5  # Langzaam met de klok mee

	# Handje: alleen tijdens het voordoen. Het zit op het handvat en draait dus
	# met het wiel mee, terwijl het zelf rechtop blijft wijzen.
	if _hint_hand_pivot:
		var hand_target := 1.0 if is_auto_spinning() else 0.0
		_hint_hand_pivot.modulate.a = lerpf(_hint_hand_pivot.modulate.a, hand_target, 0.12)
		_hint_hand_pivot.visible = _hint_hand_pivot.modulate.a > 0.01
		_hint_hand_pivot.rotation = _current_rotation
		if _hint_hand:
			_hint_hand.rotation = -_current_rotation


func _get_touch_angle(touch_pos: Vector2) -> float:
	## Bereken de hoek van de touch positie t.o.v. het midden van het wiel
	var center = size / 2.0
	var local_pos = touch_pos - center
	return atan2(local_pos.y, local_pos.x)


func get_speed_factor() -> float:
	return _speed_factor


## Laat het wiel `duration` seconden vanzelf draaien om voor te doen wat de
## bedoeling is. Het handje blijft daarbij zichtbaar en draait mee.
func start_auto_spin(duration: float) -> void:
	_auto_spin_left = maxf(0.0, duration)
	_auto_spin_time = 0.0
	_user_has_spun = false


func is_auto_spinning() -> bool:
	return _auto_spin_left > 0.0


## Heeft de bezoeker zelf al aan het wiel gedraaid? Pas daarna telt de tijd
## mee die de upload-knop tevoorschijn brengt
func has_user_spun() -> bool:
	return _user_has_spun


func reset() -> void:
	_angular_velocity = 0.0
	_speed_factor = 0.0
	_current_rotation = 0.0
	_touch_active = false
	_touch_index = -1
	_hint_time = 0.0
	_auto_spin_left = 0.0
	_auto_spin_time = 0.0
	_user_has_spun = false
	if _wheel_sprite:
		_wheel_sprite.rotation = 0.0
	if _hint_arrows:
		_hint_arrows.modulate.a = 1.0
		_hint_arrows.rotation = 0.0
	if _hint_hand_pivot:
		# Handje onzichtbaar starten: het komt pas in beeld bij het voordoen
		_hint_hand_pivot.rotation = 0.0
		_hint_hand_pivot.modulate.a = 0.0
		_hint_hand_pivot.visible = false
	if _hint_hand:
		_hint_hand.rotation = 0.0
