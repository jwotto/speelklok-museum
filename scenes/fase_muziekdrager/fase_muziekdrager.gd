@tool
extends Node2D

## Fase 2: Muziekdrager selectie
## Carousel met 4 muziekdragers — swipe of pijltjes om te kiezen, done knop om te bevestigen.

@warning_ignore("unused_signal")
signal phase_completed

const DRAGERS = [
	{"id": "groove", "texture": preload("res://assets/muziekdragers/speelplaat.png"), "preview": preload("res://audio/previews/groove.wav")},
	{"id": "klassiek", "texture": preload("res://assets/muziekdragers/cilinder.png"), "preview": preload("res://audio/previews/klassiek.wav")},
	{"id": "klezmer", "texture": preload("res://assets/muziekdragers/orgelboek.png"), "preview": preload("res://audio/previews/klezmer.wav")},
	{"id": "pop", "texture": preload("res://assets/muziekdragers/papierrol.png"), "preview": preload("res://audio/previews/pop.wav")},
]

@export_group("Carousel")
## Swipe threshold in pixels voor wisselen
@export var swipe_threshold: float = 100.0
## Animatie duur bij wisselen
@export var transition_duration: float = 0.2

# Scene node references
@onready var _background: TextureRect = $Background
@onready var _drager_sprite: TextureRect = $UILayer/DragerSprite
@onready var _left_arrow: Control = $UILayer/LeftArrow
@onready var _right_arrow: Control = $UILayer/RightArrow
@onready var _done_button: Control = $UILayer/DoneButton

var _current_index: int = 0
var _phase_data: Dictionary = {}
var _body_shape: Node2D = null

# Swipe tracking
var _preview_player: AudioStreamPlayer = null

# Swipe tracking
var _touch_start_x: float = 0.0
var _touch_active: bool = false
var _swiping: bool = false
var _transitioning: bool = false
var _idle_timer: float = 0.0  ## Timer voor idle animatie


func _ready() -> void:
	_resize_background()
	if Engine.is_editor_hint():
		return
	get_tree().root.size_changed.connect(_resize_background)

	# Audio player voor genre previews (80% volume)
	_preview_player = AudioStreamPlayer.new()
	_preview_player.volume_db = linear_to_db(0.8)
	add_child(_preview_player)

	_left_arrow.pressed.connect(_on_prev)
	_right_arrow.pressed.connect(_on_next)
	_done_button.pressed.connect(_on_done_pressed)

	# Linkse pijl spiegelen (play icoon omgedraaid)
	_left_arrow.flip_h = true

	# Pivot op midden voor animaties
	_drager_sprite.pivot_offset = _drager_sprite.size / 2.0

	_update_drager_display()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _transitioning:
		return
	# Idle animatie: subtiele pulse + wobble (zelfde stijl als sticker audio pulse)
	_idle_timer += delta
	var pulse = sin(_idle_timer * PI * 2.5) * 0.03 + 1.0  # 0.97 - 1.03
	var wobble = sin(_idle_timer * PI * 1.8) * 0.02  # Lichte rotatie
	_drager_sprite.scale = Vector2(pulse, pulse)
	_drager_sprite.rotation = wobble


func set_phase_data(data: Dictionary) -> void:
	if not data.has("body_node") or not data.has("polygon"):
		return

	_phase_data = data.duplicate()
	var body_shape: Node2D = data["body_node"]

	body_shape.name = "OrganContour"
	add_child(body_shape)
	move_child(body_shape, 1)  # Na Background
	_body_shape = body_shape

	# Sla originele decoratie waardes op VOORDAT we ze op 0 zetten
	var decoration := body_shape.get_node_or_null("BodyDecoration")
	if decoration:
		_phase_data["original_decoration"] = {
			"pipe_count": decoration.pipe_count,
			"panel_count": decoration.panel_count,
			"molding_width": decoration.molding_width,
			"molding_accent_width": decoration.molding_accent_width,
			"gold_trim_width": decoration.gold_trim_width,
			"arch_line_width": decoration.arch_line_width,
			"panel_frame_width": decoration.panel_frame_width,
			"panel_inner_width": decoration.panel_inner_width,
			"crown_arch_count": decoration.crown_arch_count,
			"pendant_radius": decoration.pendant_radius,
			"neck_frame_inset": decoration.neck_frame_inset,
			"neck_fill_color": decoration.neck_fill_color,
			"rok_frame_inset": decoration.rok_frame_inset,
			"rok_fill_color": decoration.rok_fill_color,
			"uniform_zones": decoration.uniform_zones,
		}

	# Gebruik BodyDecoration maar ZONDER versieringen - alleen basis hout texture
	if decoration:
		decoration.visible = true
		decoration.pipe_count = 0
		decoration.panel_count = 0
		decoration.molding_width = 0.0
		decoration.molding_accent_width = 0.0
		decoration.gold_trim_width = 0.0
		decoration.arch_line_width = 0.0
		decoration.panel_frame_width = 0.0
		decoration.panel_inner_width = 0.0
		decoration.crown_arch_count = 0
		decoration.pendant_radius = 0.0
		decoration.neck_frame_inset = 0.0
		decoration.neck_fill_color = Color(0, 0, 0, 0)
		decoration.rok_frame_inset = 0.0
		decoration.rok_fill_color = Color(0, 0, 0, 0)
		decoration.uniform_zones = true
		decoration.kop_texture_opacity = decoration.lichaam_texture_opacity
		decoration.rok_texture_opacity = decoration.lichaam_texture_opacity
		decoration.kop_color_blend = decoration.lichaam_color_blend
		decoration.rok_color_blend = decoration.lichaam_color_blend
	var shape_fill := body_shape.get_node_or_null("ShapeFill")
	if shape_fill:
		shape_fill.visible = false


func _place_drager_in_kast() -> void:
	pass  # Drager wordt als sticker geplaatst in fase 3


func get_phase_data() -> Dictionary:
	var body_dup = _body_shape.duplicate() if _body_shape else null
	var result = _phase_data.duplicate()
	result["body_node"] = body_dup
	result["genre"] = DRAGERS[_current_index]["id"]
	result["drager_texture"] = DRAGERS[_current_index]["texture"]
	# Voorkant render doorsturen van fase 1
	if _phase_data.has("front_render"):
		result["front_render"] = _phase_data["front_render"]
	return result


func _update_drager_display() -> void:
	if _drager_sprite and _current_index >= 0 and _current_index < DRAGERS.size():
		_drager_sprite.texture = DRAGERS[_current_index]["texture"]
		# Speel genre preview
		if _preview_player and DRAGERS[_current_index].has("preview"):
			_preview_player.stream = DRAGERS[_current_index]["preview"]
			_preview_player.play()


func _on_prev() -> void:
	if _transitioning:
		return
	_switch_drager(-1)


func _on_next() -> void:
	if _transitioning:
		return
	_switch_drager(1)


func _switch_drager(direction: int) -> void:
	_transitioning = true
	_current_index = (_current_index + direction + DRAGERS.size()) % DRAGERS.size()

	var slide_offset = 300.0 * direction
	var original_x = _drager_sprite.position.x

	var tween = create_tween()
	tween.tween_property(_drager_sprite, "position:x", original_x - slide_offset, transition_duration * 0.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_drager_sprite, "modulate:a", 0.0, transition_duration * 0.3)
	tween.tween_callback(func():
		_update_drager_display()
		_drager_sprite.position.x = original_x + slide_offset
		_drager_sprite.modulate.a = 0.0
	)
	tween.tween_property(_drager_sprite, "position:x", original_x, transition_duration * 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_drager_sprite, "modulate:a", 1.0, transition_duration * 0.3)
	tween.tween_callback(func():
		_transitioning = false
	)


func _on_done_pressed() -> void:
	if _transitioning:
		return
	if _preview_player:
		_preview_player.stop()
	_transitioning = true

	# Zet pivot op midden van de sprite zodat schaal vanuit het midden gaat
	_drager_sprite.pivot_offset = _drager_sprite.size / 2.0

	# Beweeg horizontaal naar het midden, verticaal blijft gelijk
	var sprite_center_x = _drager_sprite.position.x + _drager_sprite.size.x / 2.0
	var screen_center_x = 540.0
	var move_to = _drager_sprite.position
	move_to.x += screen_center_x - sprite_center_x

	# Snelle overgang (0.3s): alles faded uit, achtergrond blijft
	var tween = create_tween().set_parallel()
	tween.tween_property(_drager_sprite, "scale", Vector2(0.2, 0.2), 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_drager_sprite, "position", move_to, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_drager_sprite, "modulate:a", 0.0, 0.2)
	tween.tween_property(_left_arrow, "modulate:a", 0.0, 0.2)
	tween.tween_property(_right_arrow, "modulate:a", 0.0, 0.2)
	tween.tween_property(_done_button, "modulate:a", 0.0, 0.2)
	# Achtergrond en kast NIET faden — gradient blijft zichtbaar
	tween.chain().tween_callback(func():
		_place_drager_in_kast()
		phase_completed.emit()
	)


func _is_touch_on_drager(pos: Vector2) -> bool:
	## Check of de touch positie op de drager sprite zit
	var rect = Rect2(_drager_sprite.global_position, _drager_sprite.size)
	return rect.has_point(pos)


# === SWIPE INPUT ===

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _transitioning:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start_x = event.position.x
			_touch_active = true
			_swiping = false
		else:
			if _swiping:
				var delta_x = event.position.x - _touch_start_x
				if absf(delta_x) > swipe_threshold:
					_switch_drager(-1 if delta_x > 0 else 1)
			elif _is_touch_on_drager(event.position):
				# Tik op de drager = bevestigen
				_on_done_pressed()
			_touch_active = false
			_swiping = false

	elif event is InputEventScreenDrag and _touch_active:
		var delta_x = event.position.x - _touch_start_x
		if absf(delta_x) > 30:
			_swiping = true


# === BACKGROUND ===

func _resize_background() -> void:
	if not _background:
		return
	var size: Vector2
	if Engine.is_editor_hint():
		size = Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height")
		)
	else:
		size = get_viewport_rect().size
	_background.size = size
