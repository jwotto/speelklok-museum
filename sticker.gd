extends Sprite2D
class_name Sticker

## Een sticker die je kunt verplaatsen, draaien en schalen met touch

@export var min_scale: float = 0.3
@export var max_scale: float = 3.0

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

# Multitouch voor schalen en roteren
var touches: Dictionary = {}
var first_touch_index: int = -1
var start_distance: float = 0.0
var start_scale: Vector2 = Vector2.ONE
var start_angle: float = 0.0
var start_rotation: float = 0.0


func _ready() -> void:
	pass


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
		# Eerste vinger moet op sticker, tweede mag overal
		if touches.size() == 0 and _hit_test(event.position):
			touches[event.index] = event.position
			first_touch_index = event.index
			dragging = true
			drag_offset = global_position - event.position
		elif touches.size() == 1 and dragging:
			# Tweede vinger mag overal zijn
			touches[event.index] = event.position
			_begin_transform()
	else:
		touches.erase(event.index)
		if touches.size() == 0:
			dragging = false
			first_touch_index = -1
		elif touches.size() == 1:
			# Terug naar alleen draggen, eerste vinger is nu de overgebleven
			first_touch_index = touches.keys()[0]
			var remaining_pos = touches.values()[0]
			drag_offset = global_position - remaining_pos


func _on_drag(event: InputEventScreenDrag) -> void:
	if not touches.has(event.index):
		return

	touches[event.index] = event.position

	if touches.size() == 1 and dragging:
		# Alleen verplaatsen
		global_position = event.position + drag_offset
	elif touches.size() == 2:
		# Verplaatsen + schalen + roteren
		_update_transform()


func _begin_transform() -> void:
	var positions = touches.values()
	start_distance = positions[0].distance_to(positions[1])
	start_scale = scale
	start_angle = (positions[1] - positions[0]).angle()
	start_rotation = rotation


func _update_transform() -> void:
	var positions = touches.values()
	var current_distance = positions[0].distance_to(positions[1])
	var current_angle = (positions[1] - positions[0]).angle()

	# Schalen
	if start_distance > 0:
		var factor = current_distance / start_distance
		var new_scale = start_scale * factor
		new_scale = new_scale.clamp(Vector2(min_scale, min_scale), Vector2(max_scale, max_scale))
		scale = new_scale

	# Roteren
	rotation = start_rotation + (current_angle - start_angle)

	# Positie = eerste vinger blijft bepalen
	if first_touch_index >= 0 and touches.has(first_touch_index):
		global_position = touches[first_touch_index] + drag_offset


func _hit_test(pos: Vector2) -> bool:
	if texture == null:
		return global_position.distance_to(pos) < 50

	var local = to_local(pos)
	var size = texture.get_size()
	return abs(local.x) < size.x / 2 and abs(local.y) < size.y / 2
