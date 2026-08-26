@tool
extends Node2D
class_name DragHint

## Sleep-hint: een handje dat bij een net geplaatste sticker verschijnt en een
## sleepbeweging maakt, zodat duidelijk is dat de sticker verplaatst kan worden.
## Verdwijnt vanzelf na `show_duration`, of eerder via `hide_hint()`.

@export_group("Uiterlijk")
## Grootte van het handje in pixels (het icoon heeft rondom ruimte voor de witte rand)
@export var icon_size: float = 180.0:
	set(value):
		icon_size = value
		_apply_appearance()
## Dikte van de witte rand in scherm-pixels
@export var outline_screen_width: float = 10.0:
	set(value):
		outline_screen_width = value
		_apply_appearance()
## Verschuiving t.o.v. het midden van de sticker
@export var hand_offset: Vector2 = Vector2(30.0, 55.0):
	set(value):
		hand_offset = value
		_apply_appearance()

@export_group("Animatie")
## Afstand die het handje opzij sleept
@export var drag_distance: float = 95.0
## Hoogte van het boogje halverwege de sleepbeweging (0 = kaarsrecht)
@export var arc_height: float = 28.0
## Duur van één sleepbeweging
@export var cycle_duration: float = 1.4
## Hoe lang de hint blijft staan voordat hij vanzelf verdwijnt
@export var show_duration: float = 4.0

@onready var _hand: Sprite2D = $Hand

var _target: Node2D = null
var _loop_tween: Tween = null
var _fade_tween: Tween = null
var _hide_timer: SceneTreeTimer = null
var _base_scale: float = 1.0


func _ready() -> void:
	_apply_appearance()
	if Engine.is_editor_hint():
		return
	visible = false
	set_process(false)


func _process(_delta: float) -> void:
	## Volg de sticker zolang de hint zichtbaar is
	if Engine.is_editor_hint():
		return
	if not is_instance_valid(_target):
		hide_hint()
		return
	position = _target.position


## Toon de hint op een vaste plek (bijv. boven een slider) en start de animatie
func show_at(pos: Vector2) -> void:
	if Engine.is_editor_hint() or _hand == null:
		return

	_target = null
	position = pos
	visible = true
	set_process(false)

	if _fade_tween:
		_fade_tween.kill()
		_fade_tween = null

	_start_animation()

	# Automatisch verdwijnen — bind de timer zodat een oudere timer niets doet
	_hide_timer = get_tree().create_timer(show_duration)
	_hide_timer.timeout.connect(_on_hide_timeout.bind(_hide_timer))


## Toon de hint bij een sticker en blijf die volgen zolang hij zichtbaar is
func show_for(target: Node2D) -> void:
	if Engine.is_editor_hint() or target == null or _hand == null:
		return

	show_at(target.position)
	_target = target
	set_process(true)


## Voeg één sleepbeweging toe aan een bestaande, sequentiële tween: het handje
## verschijnt op `from`, sleept in een rechte lijn naar `to` en laat weer los.
## Rijg meerdere aanroepen aaneen om verschillende elementen langs te gaan.
## `on_progress` krijgt tijdens het slepen de voortgang (0-1), zodat de aanroeper
## het gesleepte element mee kan laten bewegen.
## Met `bounce` gaat het handje naar `to` en weer terug naar `from` — handig om
## te laten zien wat een schuifknop doet zonder de stand echt te veranderen.
func append_drag(tween: Tween, from: Vector2, to: Vector2, duration: float,
		on_progress: Callable = Callable(), bounce: bool = false) -> void:
	if Engine.is_editor_hint() or _hand == null:
		return

	var idle := Vector2(_base_scale, _base_scale)
	var grabbed := idle * 0.85

	# Verschijnen op het startpunt en "vastpakken"
	tween.tween_callback(func():
		_stop()
		# Ook een lopende fade afbreken, anders zet die ons zo weer op onzichtbaar
		if _fade_tween:
			_fade_tween.kill()
			_fade_tween = null
		visible = true
		position = from
		_hand.position = hand_offset
		_hand.scale = idle
		_hand.modulate.a = 0.0
	)
	tween.tween_property(_hand, "modulate:a", 1.0, duration * 0.2)
	tween.parallel().tween_property(_hand, "scale", grabbed, duration * 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Slepen — rechte lijn, geen boog
	var step := func(t: float) -> void:
		# bounce: 0 -> 1 -> 0, dus heen en weer terug naar het startpunt
		var p := sin(t * PI) if bounce else t
		position = from.lerp(to, p)
		if on_progress.is_valid():
			on_progress.call(p)
	var drag := tween.tween_method(step, 0.0, 1.0, duration * 0.55)
	if bounce:
		drag.set_trans(Tween.TRANS_LINEAR)  # de sinus zorgt zelf voor de soepele beweging
	else:
		drag.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

	# Loslaten
	tween.tween_property(_hand, "modulate:a", 0.0, duration * 0.25)
	tween.parallel().tween_property(_hand, "scale", idle, duration * 0.25)


## Voeg een tik toe aan een bestaande, sequentiële tween: het handje verschijnt
## bij `pos`, drukt een keer in en verdwijnt weer. Voor "hier moet je klikken".
func append_tap(tween: Tween, pos: Vector2, duration: float) -> void:
	if Engine.is_editor_hint() or _hand == null:
		return

	var idle := Vector2(_base_scale, _base_scale)
	var pressed := idle * 0.8

	tween.tween_callback(func():
		_stop()
		if _fade_tween:
			_fade_tween.kill()
			_fade_tween = null
		visible = true
		position = pos
		_hand.position = hand_offset
		_hand.scale = idle
		_hand.modulate.a = 0.0
	)
	tween.tween_property(_hand, "modulate:a", 1.0, duration * 0.25)
	# De tik zelf: even indrukken en weer loslaten
	tween.tween_property(_hand, "scale", pressed, duration * 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_hand, "scale", idle, duration * 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_hand, "modulate:a", 0.0, duration * 0.25)


## Verberg de hint met een fade (bijv. zodra de bezoeker zelf gaat slepen)
func hide_hint() -> void:
	# Al verborgen? Dan is er niets op te ruimen (wordt bij elke touch aangeroepen)
	if Engine.is_editor_hint() or _hand == null or not visible:
		return

	_stop()
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_hand, "modulate:a", 0.0, 0.2)
	_fade_tween.tween_callback(func(): visible = false)


## Verberg direct zonder fade — nodig vlak voor een schermafdruk
func hide_now() -> void:
	if Engine.is_editor_hint() or _hand == null:
		return

	_stop()
	if _fade_tween:
		_fade_tween.kill()
		_fade_tween = null
	visible = false


func _stop() -> void:
	## Stop de animatie en laat de gevolgde node los
	_hide_timer = null
	_target = null
	set_process(false)
	if _loop_tween:
		_loop_tween.kill()
		_loop_tween = null


func _on_hide_timeout(timer: SceneTreeTimer) -> void:
	# Alleen reageren als dit nog de actuele timer is
	if timer == _hide_timer:
		hide_hint()


func _apply_appearance() -> void:
	if not is_inside_tree():
		return
	if _hand == null:
		_hand = get_node_or_null("Hand")
	if _hand == null or _hand.texture == null:
		return

	var tex_size: float = maxf(_hand.texture.get_width(), _hand.texture.get_height())
	_base_scale = icon_size / tex_size if tex_size > 0.0 else 1.0
	_hand.scale = Vector2(_base_scale, _base_scale)
	_hand.position = hand_offset

	# Shader werkt in texel-eenheden — delen door de schaal geeft een
	# constante randdikte op het scherm (zelfde truc als in sticker.gd)
	var mat := _hand.material as ShaderMaterial
	if mat and _base_scale > 0.0:
		mat.set_shader_parameter("outline_width", outline_screen_width / _base_scale)


func _start_animation() -> void:
	if _loop_tween:
		_loop_tween.kill()

	var grab_scale := Vector2(_base_scale, _base_scale) * 0.85
	var idle_scale := Vector2(_base_scale, _base_scale)

	_set_hand_arc(0.0)  # startpositie van het boogje
	_hand.scale = idle_scale
	_hand.modulate.a = 0.0

	_loop_tween = create_tween().set_loops()
	# 1. Verschijnen en "vastpakken" (handje knijpt samen)
	_loop_tween.tween_property(_hand, "modulate:a", 1.0, cycle_duration * 0.15)
	_loop_tween.parallel().tween_property(_hand, "scale", grab_scale, cycle_duration * 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# 2. Slepen in een boogje
	_loop_tween.tween_method(_set_hand_arc, 0.0, 1.0, cycle_duration * 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	# 3. Loslaten en wegfaden
	_loop_tween.tween_property(_hand, "modulate:a", 0.0, cycle_duration * 0.25)
	_loop_tween.parallel().tween_property(_hand, "scale", idle_scale, cycle_duration * 0.25)
	# 4. Terug naar startpositie (onzichtbaar) en even wachten
	_loop_tween.tween_callback(func(): _set_hand_arc(0.0))
	_loop_tween.tween_interval(cycle_duration * 0.1)


func _set_hand_arc(t: float) -> void:
	## Volgt een boogje: horizontaal opschuiven, verticaal een halve sinus omhoog
	_hand.position = hand_offset + Vector2(
		drag_distance * t,
		-arc_height * sin(t * PI)
	)


func _get_configuration_warnings() -> PackedStringArray:
	if get_node_or_null("Hand") == null:
		return PackedStringArray(["Mist een Sprite2D child met de naam 'Hand'."])
	return PackedStringArray()
