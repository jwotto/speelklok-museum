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

# Voor pinch: lokale posities waar vingers de sticker raken
var touch_local_points: Dictionary = {}


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
	# Sla op waar elke vinger de sticker raakt in lokale coördinaten
	touch_local_points.clear()
	for idx in touches:
		touch_local_points[idx] = to_local(touches[idx])


func _update_transform() -> void:
	var indices = touches.keys()
	var idx0 = indices[0]
	var idx1 = indices[1]

	# Huidige en originele touch posities
	var p0 = touches[idx0]
	var p1 = touches[idx1]
	var local0 = touch_local_points[idx0]
	var local1 = touch_local_points[idx1]

	# Bereken nieuwe schaal: afstand tussen vingers / originele lokale afstand
	var current_dist = p0.distance_to(p1)
	var original_local_dist = (local0 * scale).distance_to(local1 * scale)

	if original_local_dist > 10:
		var local_dist = local0.distance_to(local1)
		var new_scale_factor = current_dist / local_dist
		var new_scale_val = clamp(new_scale_factor, min_scale, max_scale)
		scale = Vector2(new_scale_val, new_scale_val)

	# Bereken rotatie
	var original_angle = (local1 - local0).angle()
	var current_angle = (p1 - p0).angle()
	rotation = current_angle - original_angle

	# Positie: zorg dat vinger 0 op zijn lokale punt blijft
	var rotated_local = local0.rotated(rotation) * scale
	global_position = p0 - rotated_local


func _hit_test(pos: Vector2) -> bool:
	if texture == null:
		return global_position.distance_to(pos) < 50

	var local = to_local(pos)
	var size = texture.get_size()
	return abs(local.x) < size.x / 2 and abs(local.y) < size.y / 2
