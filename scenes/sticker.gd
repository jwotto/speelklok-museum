extends Sprite2D
class_name Sticker

## Een sticker die je kunt verplaatsen, draaien en schalen met touch
## Features:
## - Drag met 1 vinger
## - Pinch/zoom/rotate met 2 vingers (vingers blijven "geplakt")
## - Inertia: sticker glijdt door na loslaten
## - Smooth scaling: vloeiende schaal overgangen
## - Schaduw: verschijnt bij oppakken

# === EXPORT VARIABELEN ===

@export_group("Scale Limits")
## Minimale schaal als multiplier van de start-grootte (0.3 = 30% van origineel)
@export var min_scale: float = 0.3
## Maximale schaal als multiplier van de start-grootte (5.0 = 5x zo groot)
@export var max_scale: float = 5.0

@export_group("Inertia")
## Hoeveel slide/momentum na loslaten (0 = geen, 1 = normaal, 2 = veel)
@export var inertia_amount: float = 1.0
## Hoe snel de sticker vertraagt na loslaten (0-1, lager = sneller stoppen)
@export var inertia_friction: float = 0.95
## Minimale snelheid voordat inertia stopt
@export var inertia_min_velocity: float = 5.0

@export_group("Smoothing")
## Hoe snel de schaal interpoleert naar target (0-1, hoger = sneller)
@export var scale_smoothing: float = 0.3

@export_group("Hit Detection")
## Extra marge rondom de zichtbare pixels voor klikken (in pixels)
@export var hit_margin: float = 20.0

@export_group("Shadow")
## Schaduw tonen bij draggen
@export var shadow_enabled: bool = true
## Transparantie van de schaduw (0 = onzichtbaar, 1 = volledig zichtbaar)
@export_range(0.0, 1.0) var shadow_opacity: float = 0.21
## Afstand van de schaduw tot de sticker (in pixels)
@export var shadow_distance: float = 30.0
## Richting van de schaduw in graden (0 = rechts, 90 = onder, 180 = links, 270 = boven)
@export_range(0.0, 360.0) var shadow_direction: float = 45.0
## Hoe snel de schaduw in/uit fade (hoger = sneller, 50+ = bijna instant)
@export var shadow_fade_speed: float = 50.0


# === STATISCHE VARIABELEN (gedeeld tussen alle stickers) ===

static var _active_sticker: Sticker = null  # Welke sticker wordt nu gedragged
static var _top_z_index: int = 0  # Hoogste z_index voor bovenop brengen

# === INTERNE VARIABELEN ===

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

# Multitouch voor schalen en roteren
var touches: Dictionary = {}
var first_touch_index: int = -1

# Voor pinch: lokale posities waar vingers de sticker raken
var touch_local_points: Dictionary = {}

# Inertia systeem
var _velocity: Vector2 = Vector2.ZERO
var _velocity_samples: Array[Vector2] = []
var _inertia_active: bool = false
const VELOCITY_SAMPLE_COUNT: int = 5  # Aantal frames om te meten

# Smooth scaling
var _target_scale: Vector2 = Vector2.ONE
var _scale_smoothing_active: bool = false
var _base_scale: float = 1.0  # Start-grootte wordt basis voor min/max

# Schaduw systeem
var _shadow_opacity: float = 0.0
var _shadow_node: Node2D = null


# === LIFECYCLE ===

func _ready() -> void:
	_base_scale = scale.x  # Sla start-grootte op als basis
	_target_scale = scale
	_create_shadow_node()


func _process(delta: float) -> void:
	_process_inertia(delta)
	_process_smooth_scale(delta)
	_process_shadow(delta)


# === INPUT HANDLING ===

func _input(event: InputEvent) -> void:
	# ESC = afsluiten
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()

	# Alleen touch events
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_handle_touch_pressed(event)
	else:
		_handle_touch_released(event)


func _handle_touch_pressed(event: InputEventScreenTouch) -> void:
	"""Verwerkt een nieuwe touch (vinger naar beneden)"""
	# Eerste vinger moet op sticker, tweede mag overal
	if touches.size() == 0 and _hit_test(event.position):
		# Check of er al een andere sticker wordt gedragged
		if _active_sticker != null and _active_sticker != self:
			return  # Andere sticker is actief, negeer deze touch

		touches[event.index] = event.position
		first_touch_index = event.index
		dragging = true
		drag_offset = global_position - event.position
		_active_sticker = self
		_bring_to_front()
		_start_drag()
	elif touches.size() == 1 and dragging:
		# Tweede vinger mag overal zijn
		touches[event.index] = event.position
		_begin_transform()


func _handle_touch_released(event: InputEventScreenTouch) -> void:
	"""Verwerkt een touch release (vinger omhoog)"""
	if not touches.has(event.index):
		return  # Deze touch was niet van ons

	touches.erase(event.index)
	touch_local_points.erase(event.index)

	if touches.size() == 0:
		_end_drag()
	elif touches.size() == 1:
		# Terug naar alleen draggen, eerste vinger is nu de overgebleven
		first_touch_index = touches.keys()[0]
		var remaining_pos = touches.values()[0]
		drag_offset = global_position - remaining_pos


func _on_drag(event: InputEventScreenDrag) -> void:
	"""Verwerkt touch drag beweging"""
	if not touches.has(event.index):
		return

	touches[event.index] = event.position

	if touches.size() == 1 and dragging:
		_update_single_finger_drag(event.position)
	elif touches.size() == 2:
		_update_transform()


# === DRAG SYSTEEM ===

func _start_drag() -> void:
	"""Start een drag operatie - stopt inertia en reset velocity tracking"""
	_inertia_active = false
	_velocity = Vector2.ZERO
	_velocity_samples.clear()


func _end_drag() -> void:
	"""Beeindig drag - start inertia en reset visuele feedback"""
	dragging = false
	first_touch_index = -1
	_active_sticker = null
	_start_inertia()


func _bring_to_front() -> void:
	"""Breng deze sticker naar de voorgrond"""
	_top_z_index += 1
	z_index = _top_z_index


func _update_single_finger_drag(finger_position: Vector2) -> void:
	"""Update positie bij single finger drag en track velocity voor inertia"""
	var new_position = finger_position + drag_offset
	var frame_velocity = new_position - global_position

	# Voeg velocity sample toe
	_velocity_samples.append(frame_velocity)
	if _velocity_samples.size() > VELOCITY_SAMPLE_COUNT:
		_velocity_samples.remove_at(0)

	global_position = new_position


# === TRANSFORM SYSTEEM (PINCH/ZOOM/ROTATE) ===

func _begin_transform() -> void:
	"""Start een twee-vinger transform - sla lokale touch punten op"""
	touch_local_points.clear()
	for idx in touches:
		touch_local_points[idx] = to_local(touches[idx])


func _update_transform() -> void:
	"""Update schaal, rotatie en positie gebaseerd op twee-vinger gesture"""
	var indices = touches.keys()
	var idx0 = indices[0]
	var idx1 = indices[1]

	# Huidige en originele touch posities
	var p0 = touches[idx0]
	var p1 = touches[idx1]
	var local0 = touch_local_points[idx0]
	var local1 = touch_local_points[idx1]

	# Bereken nieuwe schaal
	_calculate_scale_from_pinch(p0, p1, local0, local1)

	# Bereken rotatie
	_calculate_rotation_from_pinch(p0, p1, local0, local1)

	# Positie: zorg dat vinger 0 op zijn lokale punt blijft
	var rotated_local = local0.rotated(rotation) * scale
	global_position = p0 - rotated_local


func _calculate_scale_from_pinch(p0: Vector2, p1: Vector2, local0: Vector2, local1: Vector2) -> void:
	"""Bereken en pas schaal aan gebaseerd op pinch afstand"""
	var current_dist = p0.distance_to(p1)
	var local_dist = local0.distance_to(local1)

	if local_dist > 10:
		var new_scale_factor = current_dist / local_dist
		# Clamp relatief aan de basis-grootte
		var actual_min = _base_scale * min_scale
		var actual_max = _base_scale * max_scale
		var new_scale_val = clamp(new_scale_factor, actual_min, actual_max)
		_set_target_scale(Vector2(new_scale_val, new_scale_val))


func _calculate_rotation_from_pinch(p0: Vector2, p1: Vector2, local0: Vector2, local1: Vector2) -> void:
	"""Bereken en pas rotatie aan gebaseerd op twee-vinger hoek"""
	var original_angle = (local1 - local0).angle()
	var current_angle = (p1 - p0).angle()
	rotation = current_angle - original_angle


# === INERTIA SYSTEEM ===

func _start_inertia() -> void:
	"""Start inertia beweging gebaseerd op gemiddelde swipe snelheid"""
	# Bereken gemiddelde velocity van de laatste frames
	if _velocity_samples.size() > 0:
		var total = Vector2.ZERO
		for sample in _velocity_samples:
			total += sample
		_velocity = total / _velocity_samples.size()
	else:
		_velocity = Vector2.ZERO

	# Pas inertia_amount toe
	_velocity *= inertia_amount

	if _velocity.length() > inertia_min_velocity:
		_inertia_active = true


func _process_inertia(_delta: float) -> void:
	"""Verwerk inertia - laat sticker doorglijden na loslaten"""
	if not _inertia_active or dragging:
		return

	# Pas velocity toe op positie
	global_position += _velocity

	# Vertraag velocity met friction
	_velocity *= inertia_friction

	# Stop als velocity te laag is
	if _velocity.length() < inertia_min_velocity:
		_inertia_active = false
		_velocity = Vector2.ZERO


# === SMOOTH SCALING SYSTEEM ===

func _set_target_scale(new_scale: Vector2) -> void:
	"""Zet een target scale voor smooth interpolatie"""
	_target_scale = new_scale
	_scale_smoothing_active = true
	# Direct toepassen tijdens drag voor responsive gevoel
	if dragging:
		scale = new_scale


func _process_smooth_scale(_delta: float) -> void:
	"""Interpoleer schaal naar target voor vloeiende overgangen"""
	if not _scale_smoothing_active or dragging:
		return

	scale = scale.lerp(_target_scale, scale_smoothing)

	# Stop smoothing als we dichtbij genoeg zijn
	if scale.distance_to(_target_scale) < 0.01:
		scale = _target_scale
		_scale_smoothing_active = false


# === SCHADUW SYSTEEM ===

func _create_shadow_node() -> void:
	"""Maak een child node voor de schaduw die onder de sticker getekend wordt"""
	_shadow_node = Node2D.new()
	_shadow_node.z_index = -1  # Onder de sticker
	_shadow_node.z_as_relative = true
	_shadow_node.name = "Shadow"
	add_child(_shadow_node)
	_shadow_node.draw.connect(_draw_shadow)


func _process_shadow(delta: float) -> void:
	"""Update schaduw opacity - fade in bij draggen, fade out bij loslaten"""
	var target_opacity = 1.0 if dragging else 0.0
	_shadow_opacity = lerpf(_shadow_opacity, target_opacity, shadow_fade_speed * delta)
	if _shadow_node:
		_shadow_node.queue_redraw()


func _draw_shadow() -> void:
	"""Teken de schaduw (aangeroepen door shadow node)"""
	if not shadow_enabled or _shadow_opacity <= 0.01 or texture == null:
		return

	# Schaduw kleur met gecombineerde opacity
	var shadow_col = Color(0, 0, 0, shadow_opacity * _shadow_opacity)

	# Bereken offset vanuit richting (in graden) en afstand
	var direction_rad = deg_to_rad(shadow_direction)
	var world_offset = Vector2(cos(direction_rad), sin(direction_rad)) * shadow_distance

	# Counter-rotate zodat schaduw altijd vanuit dezelfde wereldrichting komt
	var local_offset = world_offset.rotated(-rotation)

	# Compenseer voor scale zodat visuele afstand constant blijft
	var compensated_offset = local_offset / scale.x
	_shadow_node.draw_texture(texture, compensated_offset - texture.get_size() / 2, shadow_col)


# === HIT DETECTION ===

var _hit_image: Image = null

func _hit_test(pos: Vector2) -> bool:
	"""Test of een punt op of nabij een niet-transparante pixel valt"""
	if texture == null:
		return global_position.distance_to(pos) < 50

	var local = to_local(pos)
	var size = texture.get_size()

	# Bounding box check met marge (in lokale schaal)
	var margin_local = hit_margin / scale.x
	if abs(local.x) >= size.x / 2 + margin_local or abs(local.y) >= size.y / 2 + margin_local:
		return false

	# Laad image lazy (alleen eerste keer)
	if _hit_image == null:
		_hit_image = texture.get_image()

	# Converteer naar texture coördinaten (0,0 = linksboven)
	var tex_x = int(local.x + size.x / 2)
	var tex_y = int(local.y + size.y / 2)

	# Check direct punt eerst
	if _check_pixel_alpha(tex_x, tex_y, size):
		return true

	# Check pixels binnen de marge
	var margin_pixels = int(margin_local)
	for dx in range(-margin_pixels, margin_pixels + 1, 4):  # Stap van 4 voor performance
		for dy in range(-margin_pixels, margin_pixels + 1, 4):
			if _check_pixel_alpha(tex_x + dx, tex_y + dy, size):
				return true

	return false


func _check_pixel_alpha(x: int, y: int, size: Vector2) -> bool:
	"""Helper: check of pixel op (x,y) alpha > threshold heeft"""
	if x >= 0 and x < size.x and y >= 0 and y < size.y:
		var pixel = _hit_image.get_pixel(x, y)
		return pixel.a > 0.1
	return false
