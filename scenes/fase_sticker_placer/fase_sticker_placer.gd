@tool
extends Node2D

## Fase 2: Muziekinstrumenten plaatsen
## Self-contained scene met sticker plaatsing, prullenbak, picker en sliders

@warning_ignore("unused_signal")
signal phase_completed

const NOTE_TEXTURE := preload("res://assets/icons/music-note.svg")

@export_group("Trash")
## Hoe dicht (in pixels) de vinger bij de prullenbak moet zijn om een sticker te verwijderen bij loslaten
@export var trash_zone_radius: float = 210.0

@export_group("Sticker Limiet")
## Maximaal aantal stickers dat geplaatst mag worden
@export var max_stickers: int = 30

@export_group("Plaatsing")
## Aantal random posities dat geprobeerd wordt — de plek het verst van andere stickers wint
@export var placement_candidates: int = 12
## Afstand tot de kastrand, als fractie van de sticker-grootte (0 = mag tegen de rand)
@export_range(0.0, 1.0) var placement_edge_margin: float = 0.5
## Duur per stap van de demo na het plaatsen (verschuiven, vergroten, draaien)
@export var slider_demo_duration: float = 1.2
## Hoe ver de sticker tijdens de demo opzij schuift, in pixels
@export var sticker_demo_shift: float = 110.0
## Hoe ver de sliders uitwijken tijdens de demo, als fractie van hun bereik
@export_range(0.0, 0.5) var slider_demo_shift: float = 0.10
## Duur van een tik-hint op een knop
@export var tap_hint_duration: float = 0.9
## Hoe vaak het handje op de + tikt als je de fase binnenkomt
@export var entry_tap_count: int = 1
## Wachttijd na binnenkomst voordat het handje naar de + wijst
@export var entry_hint_delay: float = 0.8
## Tot hoeveel instrumenten de plaats-demo nog getoond wordt (daarna wordt het irritant)
@export var demo_sticker_limit: int = 3
## Seconden stilte voordat het handje nog eens komt herinneren (0 = uit)
@export var reminder_delay: float = 10.0
## Kortere wachttijd voor het eerste +/play-duwtje, vlak na de plaats-demo
@export var first_reminder_delay: float = 3.0
## Hoe vaak het handje op de + tikt bij een herinnering
@export var reminder_tap_count: int = 1

@export_group("Muzieknootjes")
## Aantal nootjes dat uit de play-knop opstijgt
@export var note_count: int = 5
## Grootte van een nootje in pixels
@export var note_size: float = 70.0
## Dikte van de witte rand om een nootje
@export var note_outline: float = 6.0
## Hoe hoog de nootjes stijgen
@export var note_rise_height: float = 260.0
## Hoe lang een nootje onderweg is
@export var note_rise_duration: float = 1.4

@export_group("Afspelen")
## Hoelang de machine bij het starten vanzelf speelt om het draaien voor te doen
@export var auto_play_duration: float = 5.0

@export_group("Opslaan")
## Extra pad om foto's naartoe te kopiëren (bijv. /mnt/fotos of Z:\fotos)
@export var remote_fotos_path: String = ""
## Hoelang er in totaal aan het wiel gedraaid moet zijn voor de upload-knop verschijnt
@export var save_button_spin_time: float = 3.0
## Vanaf welke draaisnelheid het als "draaien" telt (0-1)
@export var save_button_spin_threshold: float = 0.1

# Scene node references
@onready var _background: TextureRect = $Background
@onready var _sticker_container: Node2D = $Stickers
@onready var _trash_button: IconButton = $UILayer/StickerSliders/TrashButton
@onready var _add_button: IconButton = $UILayer/StickerSliders/AddButton
@onready var _play_button: IconButton = $UILayer/StickerSliders/PlayButton
@onready var _picker: StickerPicker = $UILayer/StickerPicker
@onready var _slider_container: HBoxContainer = $UILayer/StickerSliders
@onready var _rotate_slider: Control = $UILayer/StickerSliders/RotateSlider
@onready var _scale_slider: Control = $UILayer/StickerSliders/ScaleSlider
@onready var _drag_hint: DragHint = $UILayer/DragHint

var _was_dragging: Dictionary = {}  # instance_id -> was dragging last frame
var _last_touch_pos: Vector2 = Vector2.ZERO  # Laatste vinger/muis positie
var _trash_highlighted: bool = false
var _any_dragging: bool = false
var _picker_open: bool = false
var _is_playing: bool = false
var _tracked_sticker: Sticker = null
var _updating_sliders: bool = false
var _organ_polygon_world: PackedVector2Array = PackedVector2Array()
var _organ_center: Vector2 = Vector2.ZERO
var _organ_bounds: Rect2 = Rect2()  ## Bounding box van de kast (voor random plaatsing)
var _audio_player: Node2D = null  ## AudioLayerPlayer
var _oneshot_player: AudioStreamPlayer = null  ## Instrument one-shot geluiden
var _current_genre: String = "groove"  ## Huidig genre voor preview geluid
var _drager_overlay: Node = null  ## Muziekdrager selectie overlay
var _pending_photo: Dictionary = {}  ## {data: PackedByteArray, path: String}
var _photo_mutex: Mutex = Mutex.new()
var _save_thread: Thread = null
var _spin_time: float = 0.0  ## Opgetelde tijd dat er aan het wiel gedraaid is
var _hint_tween: Tween = null  ## Schaal- en draai-demo, loopt naast de sleep-hint
var _idle_time: float = 0.0  ## Stilte sinds de laatste aanraking, voor de herinnering
var _reminder_wait: float = 10.0  ## Wachttijd tot de eerstvolgende herinnering
var _hint_sticker: Sticker = null  ## Sticker waarvan de demo de stand mag lenen
var _hint_position: Vector2 = Vector2.ZERO  ## Echte positie voor de demo, om exact terug te zetten
var _hint_rotation: float = 0.0  ## Echte rotatie voor de demo, om exact terug te zetten
var _hint_scale: float = 1.0  ## Echte schaal voor de demo, om exact terug te zetten
@onready var _playback_layer: CanvasLayer = $PlaybackLayer
@onready var _draaiwiel: Control = $PlaybackLayer/Draaiwiel
@onready var _back_button: IconButton = $PlaybackLayer/BackButton
@onready var _save_button: IconButton = $PlaybackLayer/SaveButton


func _ready() -> void:
	_resize_background()
	if Engine.is_editor_hint():
		return

	get_tree().root.size_changed.connect(_resize_background)
	Sticker.reset_statics()
	_reminder_wait = reminder_delay

	# Runtime setup
	_trash_button.visible = false
	_play_button.visible = false
	_add_button.pressed.connect(_on_add_pressed)
	_play_button.pressed.connect(_on_play_pressed)
	_picker.sticker_selected.connect(_on_sticker_selected)
	_picker.opened.connect(_on_picker_opened)
	_picker.closed.connect(_on_picker_closed)
	_rotate_slider.value_changed.connect(_on_rotate_slider_changed)
	_scale_slider.value_changed.connect(_on_scale_slider_changed)

	# Audio systeem
	var AudioLayerPlayerScript = preload("res://scenes/fase_sticker_placer/onderdelen/audio_layer_player.gd")
	_audio_player = AudioLayerPlayerScript.new()
	add_child(_audio_player)

	# One-shot player voor instrument geluiden
	_oneshot_player = AudioStreamPlayer.new()
	add_child(_oneshot_player)

	# Playback UI (draaiwiel + stop knop)
	_back_button.pressed.connect(_stop_playback)
	_save_button.pressed.connect(_on_save_pressed)
	_draaiwiel.speed_changed.connect(_on_wheel_speed_changed)

	# Muziekdrager selectie overlay (voor als drager verwijderd wordt)
	_setup_drager_overlay()


func _get_sticker_count() -> int:
	var count = 0
	for child in _sticker_container.get_children():
		if child is Sticker:
			count += 1
	return count


func _count_instruments() -> int:
	## Aantal geplaatste instrumenten — de muziekdrager telt niet mee, en een
	## sticker die net weggegooid is ook niet (die hangt nog even in de tree)
	var count = 0
	for child in _sticker_container.get_children():
		if child is Sticker and not child.has_meta("is_drager") \
				and not child.is_queued_for_deletion():
			count += 1
	return count


func _on_add_pressed() -> void:
	if _get_sticker_count() >= max_stickers:
		return
	_picker.toggle()


func _on_picker_opened() -> void:
	_picker_open = true
	_drag_hint.hide_hint()
	_stop_hint_demo()
	# Deselecteer huidige sticker
	if Sticker._selected_sticker:
		Sticker._selected_sticker._deselect()
	_update_button_visibility()
	_set_stickers_input(false)
	_set_stickers_process(false)


func _on_picker_closed() -> void:
	_picker_open = false
	_update_button_visibility()
	# Delay voordat sticker input weer aan gaat (voorkomt dat touch doorsijpelt)
	get_tree().create_timer(0.1).timeout.connect(func():
		_set_stickers_input(true)
	)


func _update_button_visibility() -> void:
	if _picker_open:
		_slider_container.visible = false
		return
	_slider_container.visible = true
	var has_stickers = _sticker_container.get_child_count() > 0

	if _is_playing:
		# Tijdens afspelen: slider bar verborgen, playback UI zichtbaar
		_slider_container.visible = false
		_playback_layer.visible = true
		return
	_playback_layer.visible = false

	var sticker_count = _get_sticker_count()
	var at_limit = sticker_count >= max_stickers
	# Play alleen als er echt iets te horen valt: minstens één instrument
	var has_instruments = _count_instruments() > 0

	_trash_button.visible = _any_dragging
	_add_button.visible = not _any_dragging and not at_limit
	_play_button.visible = has_instruments and not _any_dragging
	var show_sliders := _tracked_sticker != null
	_rotate_slider.visible = show_sliders
	_scale_slider.visible = show_sliders


func _is_touch_over_ui(pos: Vector2) -> bool:
	## Check of de positie boven een UI element valt
	for btn: Control in [_add_button, _trash_button, _play_button]:
		if btn.visible and btn.get_global_rect().has_point(pos):
			return true
	if _slider_container.visible and _slider_container.get_global_rect().has_point(pos):
		return true
	return false


func _select_sticker_at(pos: Vector2) -> void:
	## Selecteer de bovenste sticker op de gegeven positie
	var best_sticker: Sticker = null
	var best_z: int = -1
	for sticker in _sticker_container.get_children():
		if sticker is Sticker and sticker._hit_test(pos) and sticker.z_index > best_z:
			best_sticker = sticker
			best_z = sticker.z_index
	if best_sticker != null:
		best_sticker._select()


func _set_stickers_input(enabled: bool) -> void:
	for sticker in _sticker_container.get_children():
		if sticker is Sticker:
			sticker.set_process_unhandled_input(enabled)
			sticker.input_locked = not enabled


func _set_stickers_process(enabled: bool) -> void:
	for sticker in _sticker_container.get_children():
		if sticker is Sticker:
			sticker.set_process(enabled)


func set_phase_data(data: Dictionary) -> void:
	## Ontvang data van fase 2 (muziekdrager) — body node + genre
	if not data.has("body_node") or not data.has("polygon"):
		return

	var body_shape: Node2D = data["body_node"]
	var polygon: PackedVector2Array = data["polygon"]
	var target_scale_f: float = data["zoom_scale"]

	body_shape.name = "OrganContour"
	add_child(body_shape)
	move_child(body_shape, _sticker_container.get_index())

	# Ontvang originele decoratie waardes (opgeslagen in fase 2)
	if data.has("original_decoration"):
		_original_decoration = data["original_decoration"]

	# Gebruik BodyDecoration maar ZONDER versieringen - alleen basis hout texture
	var decoration := body_shape.get_node_or_null("BodyDecoration")
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

	# Genre instellen vanuit fase 2
	if data.has("genre"):
		_current_genre = data["genre"]
		_audio_player.set_genre(data["genre"])

	# Scale is al gezet door de animatie in fase 1, dus laten we die
	# (position en scale zijn al exact zoals ze moeten zijn!)

	# Bereken world-space polygon voor constraining
	_organ_polygon_world = PackedVector2Array()
	for p in polygon:
		_organ_polygon_world.append(p * target_scale_f + body_shape.position)

	# Bereken organ center uit world-space bounding box
	var wmin := Vector2(INF, INF)
	var wmax := Vector2(-INF, -INF)
	for wp in _organ_polygon_world:
		wmin = Vector2(minf(wmin.x, wp.x), minf(wmin.y, wp.y))
		wmax = Vector2(maxf(wmax.x, wp.x), maxf(wmax.y, wp.y))
	_organ_center = (wmin + wmax) / 2.0
	_organ_bounds = Rect2(wmin, wmax - wmin)

	# Achtergrond op volle sterkte houden (zelfde als body builder)
	_background.modulate = Color.WHITE

	# Zet constraint callable op Sticker class
	Sticker._constrain_position = _constrain_to_organ

	# Ontvang voorkant render van fase 1 (via fase 2)
	if data.has("front_render") and data["front_render"] != null:
		_front_render = data["front_render"]
		print("Voorkant render ontvangen: ", _front_render.get_width(), "x", _front_render.get_height())
	else:
		print("GEEN voorkant render ontvangen!")

	# Plaats de gekozen muziekdrager als sticker in de kast
	if data.has("drager_texture"):
		_place_drager_sticker(data["drager_texture"])

	# Kast is nog leeg — wijzen naar de + zodra de fase-overgang klaar is
	get_tree().create_timer(entry_hint_delay).timeout.connect(show_add_hint)


func _place_drager_sticker(tex: Texture2D) -> void:
	## Plaats de muziekdrager als een echte sticker in het midden van de kast
	var base_scene = preload("res://scenes/fase_sticker_placer/onderdelen/sticker.tscn")
	var sticker = base_scene.instantiate()
	sticker.texture = tex
	sticker.scale = Vector2(0.25, 0.25)
	sticker.position = _organ_center
	# Markeer als muziekdrager zodat die op master audio reageert
	sticker.set_meta("is_drager", true)
	_sticker_container.add_child(sticker)
	sticker.selection_changed.connect(_on_sticker_selection_changed.bind(sticker))
	Sticker._top_z_index += 1
	sticker.z_index = Sticker._top_z_index
	_update_button_visibility()


func _show_placement_hints(sticker: Sticker) -> void:
	## Eén handje doet achter elkaar drie dingen voor: de sticker een stukje
	## verschuiven, dan vergroten, dan draaien. Elke stap gaat heen en weer,
	## dus de sticker staat er daarna weer precies zo bij als hij geplaatst is.
	## Alleen bij de eerste paar stickers — daarna weet de bezoeker het wel.
	if _count_instruments() > demo_sticker_limit:
		return
	_stop_hint_demo()

	# De echte stand bewaren — de sliderwaarde kan door het heen-en-weer
	# animeren een fractie afwijken, de sticker zelf niet
	_hint_sticker = sticker
	_hint_position = sticker.position
	_hint_rotation = sticker.rotation
	_hint_scale = sticker.scale.x

	_hint_tween = create_tween()
	_append_sticker_demo(_hint_tween, sticker)
	_append_slider_demo(_hint_tween, _scale_slider, false)
	_append_slider_demo(_hint_tween, _rotate_slider, true)
	_hint_tween.tween_callback(_finish_hint_demo)
	# Kort na deze demo mag het +/play-duwtje komen, daarna in het normale ritme
	_reminder_wait = first_reminder_delay


func show_add_hint(tap_count: int = -1) -> void:
	## Handje tikt op de + knop, en daarna op play als daar al iets te horen is.
	## Bij de play-knop stijgen er nootjes op zodat duidelijk is wat die doet.
	if _picker_open or _is_playing:
		return
	if not _add_button.visible and not _play_button.visible:
		return
	if tap_count < 0:
		tap_count = entry_tap_count

	_stop_hint_demo()
	# Tikken los achter elkaar zetten, niet via set_loops — een callback in een
	# lussende tween vuurt bij elke ronde en laat de tween verweesd doorlopen
	_hint_tween = create_tween()
	_append_next_step_hint(_hint_tween, tap_count)
	_hint_tween.tween_callback(_finish_hint_demo)
	# Hierna weer het normale ritme
	_reminder_wait = reminder_delay


func _append_next_step_hint(tween: Tween, tap_count: int) -> void:
	## Wijst aan waar je hierna klikt: nog een instrument erbij, of afspelen.
	## Bij de play-knop stijgen er nootjes op zodat duidelijk is wat die doet.
	if _add_button.visible:
		var center := _add_button.get_global_rect().get_center()
		for i in tap_count:
			_drag_hint.append_tap(tween, center, tap_hint_duration)
			tween.tween_interval(0.35)
	if _play_button.visible:
		tween.tween_callback(_spawn_play_notes)
		_drag_hint.append_tap(tween, _play_button.get_global_rect().get_center(), tap_hint_duration)
		tween.tween_interval(note_rise_duration * 0.6)


func _spawn_play_notes() -> void:
	## Muzieknootjes stijgen op uit de play-knop
	var origin := _play_button.get_global_rect().get_center()
	for i in note_count:
		var note := OutlinedIcon.create(NOTE_TEXTURE, note_size, note_outline)
		note.z_index = 109  # net onder het handje, wel boven de knoppen
		note.position = origin + Vector2(randf_range(-45.0, 45.0), randf_range(-10.0, 10.0))
		note.rotation = randf_range(-0.25, 0.25)
		note.modulate.a = 0.0
		$UILayer.add_child(note)

		# Elk nootje z'n eigen hoogte en tempo, anders stijgen ze als één blok op
		var drift := randf_range(-90.0, 90.0)
		var hoogte := note_rise_height * randf_range(0.7, 1.3)
		var duur := note_rise_duration * randf_range(0.8, 1.2)

		var tween := create_tween().set_parallel()
		tween.tween_property(note, "position",
			note.position + Vector2(drift, -hoogte), duur) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(note, "rotation", note.rotation + drift * 0.006, duur)
		tween.tween_property(note, "modulate:a", 1.0, duur * 0.25)
		tween.chain().tween_property(note, "modulate:a", 0.0, duur * 0.45)
		tween.chain().tween_callback(note.queue_free)


func _append_sticker_demo(tween: Tween, sticker: Sticker) -> void:
	## Handje pakt de sticker op, schuift 'm een stukje opzij en weer terug
	var from_pos: Vector2 = sticker.position
	# Naar het midden van de kast toe, zodat hij niet over de rand piept
	var dir := 1.0 if from_pos.x <= _organ_center.x else -1.0
	var to_pos := from_pos + Vector2(sticker_demo_shift * dir, 0.0)

	_drag_hint.append_drag(
		tween, from_pos, to_pos, slider_demo_duration,
		_apply_sticker_demo.bind(sticker, from_pos, to_pos),
		true  # heen en weer
	)
	tween.tween_callback(_drag_hint.hide_now)


func _apply_sticker_demo(t: float, sticker: Sticker, from_pos: Vector2, to_pos: Vector2) -> void:
	## De sticker schuift mee met het handje
	if is_instance_valid(sticker):
		sticker.position = from_pos.lerp(to_pos, t)


func _append_slider_demo(tween: Tween, slider: Control, is_rotation: bool) -> void:
	## Handje schuift de thumb een klein stukje op en zet 'm weer precies terug
	var from_value: float = slider.value
	var span: float = slider.max_value - slider.min_value
	var shift: float = span * slider_demo_shift
	# Uitwijken naar de kant waar de meeste ruimte is
	if from_value + shift > slider.max_value:
		shift = -shift
	var to_value: float = clampf(from_value + shift, slider.min_value, slider.max_value)
	var origin: Vector2 = slider.global_position

	_drag_hint.append_drag(
		tween,
		origin + slider.get_thumb_position(from_value),
		origin + slider.get_thumb_position(to_value),
		slider_demo_duration,
		_apply_slider_demo.bind(slider, from_value, to_value, is_rotation),
		true  # heen en weer, dus de sticker komt weer terug waar hij stond
	)
	tween.tween_callback(_drag_hint.hide_now)


func _stop_hint_demo() -> void:
	## Breek de demo af en zet de sticker terug zoals hij stond — anders blijft
	## hij scheef of te groot staan als er middenin een beweging aangeraakt wordt
	if _hint_tween:
		_hint_tween.kill()
		_hint_tween = null
	_drag_hint.hide_hint()
	_restore_hint_sticker()


func _finish_hint_demo() -> void:
	## Demo netjes uitgelopen — toch exact terugzetten, want de sliderwaarde
	## kan een fractie afwijken van waar de sticker echt stond
	_hint_tween = null
	_drag_hint.hide_now()
	_restore_hint_sticker()


func _restore_hint_sticker() -> void:
	if is_instance_valid(_hint_sticker):
		_hint_sticker.position = _hint_position
		_hint_sticker.rotation = _hint_rotation
		_hint_sticker.scale = Vector2(_hint_scale, _hint_scale)
		_hint_sticker._target_scale = Vector2(_hint_scale, _hint_scale)
		if _tracked_sticker == _hint_sticker:
			_update_slider_values(_hint_sticker)
	_hint_sticker = null


func _apply_slider_demo(t: float, slider: Control, from_value: float,
		to_value: float, is_rotation: bool) -> void:
	## De slider-setter stuurt geen signaal, dus de sticker wordt hier zelf bijgewerkt
	var v := lerpf(from_value, to_value, t)
	_updating_sliders = true
	slider.value = v
	_updating_sliders = false
	if not is_instance_valid(_tracked_sticker):
		return
	if is_rotation:
		_tracked_sticker.rotation = deg_to_rad(v)
	else:
		_tracked_sticker.scale = Vector2(v, v)
		_tracked_sticker._target_scale = Vector2(v, v)


func _play_oneshot(instrument_id: String) -> void:
	## Speel het one-shot geluid van een instrument
	var path = "res://audio/oneshots/" + instrument_id + ".wav"
	var stream = load(path)
	if stream and _oneshot_player:
		_oneshot_player.stream = stream
		_oneshot_player.play()


func _on_sticker_selected(scene: PackedScene, from_position: Vector2) -> void:
	var sticker = scene.instantiate()
	# Random plek in de kast — spreidt de instrumenten i.p.v. alles op het midden
	var target = _random_position_in_organ(sticker)
	sticker.position = from_position
	_sticker_container.add_child(sticker)
	sticker.selection_changed.connect(_on_sticker_selection_changed.bind(sticker))
	# Selecteer de nieuwe sticker automatisch
	sticker._select()
	# Zet nieuwe sticker bovenop
	Sticker._top_z_index += 1
	sticker.z_index = Sticker._top_z_index
	# Fly-from-picker animatie
	var start_scale = sticker.scale * 0.3
	sticker.scale = start_scale
	sticker.modulate.a = 0.0
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.set_parallel()
	tween.tween_property(sticker, "position", target, 0.4)
	tween.tween_property(sticker, "scale", start_scale / 0.3, 0.4)
	tween.tween_property(sticker, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_LINEAR)
	# Hints tonen zodra de sticker geland is
	tween.chain().tween_callback(func(): _show_placement_hints(sticker))

	# Speel instrument geluid + cooldown zodat selectie niet ook speelt
	var instrument_id = sticker.scene_file_path.get_file().get_basename()
	_play_oneshot(instrument_id)

	# Sluit picker als limiet bereikt
	if _get_sticker_count() >= max_stickers:
		_picker.close()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_check_trash_zone()
	_update_sliders()
	_update_reminder(delta)
	if _is_playing:
		_update_sticker_pulse(delta)
		_update_save_button(delta)


func _update_reminder(delta: float) -> void:
	## Blijft het stil? Dan nog eens wijzen waar je instrumenten vandaan haalt
	## en waar je klikt om te horen wat je gemaakt hebt. Dit blijft komen,
	## ongeacht hoeveel instrumenten er al staan.
	if reminder_delay <= 0.0 or _is_playing or _picker_open or _hint_tween != null:
		_idle_time = 0.0
		return
	_idle_time += delta
	if _idle_time >= _reminder_wait:
		_idle_time = 0.0
		show_add_hint(reminder_tap_count)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	# Track touch/mouse positie voor prullenbak detectie
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_last_touch_pos = event.position
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		_last_touch_pos = event.position
	# Voorkom dat touch events door UI heen naar stickers gaan
	if event is InputEventScreenTouch and event.pressed:
		# Bezoeker raakt iets aan (sticker, knop of slider) — hints zijn niet meer nodig
		_idle_time = 0.0
		_drag_hint.hide_hint()
		_stop_hint_demo()
		if _is_touch_over_ui(event.position):
			get_viewport().set_input_as_handled()
	# Bij loslaten: selecteer sticker onder de vinger (als er niet gedragged werd)
	if not _any_dragging and not _picker_open:
		var released = false
		if event is InputEventScreenTouch and not event.pressed:
			released = true
		elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			released = true
		if released and not _is_touch_over_ui(event.position):
			_select_sticker_at(event.position)


func _check_trash_zone() -> void:
	if _picker_open:
		return

	var any_dragging_now = false
	for sticker in _sticker_container.get_children():
		if sticker is Sticker and sticker.dragging:
			any_dragging_now = true
			break

	# Toon/verberg knoppen bij drag state wijziging
	if _any_dragging != any_dragging_now:
		_any_dragging = any_dragging_now
		# Bezoeker sleept zelf — hint heeft zijn werk gedaan
		if any_dragging_now:
			_drag_hint.hide_hint()
		_update_button_visibility()

	# Alleen trash zone checken als er daadwerkelijk gesleept wordt of net losgelaten is
	if not any_dragging_now and _was_dragging.is_empty():
		return

	var trash_screen = _trash_button.get_screen_transform().origin
	var trash_center = trash_screen + _trash_button.size / 2.0
	var finger_dist = _last_touch_pos.distance_to(trash_center)
	var finger_in_zone = finger_dist < trash_zone_radius
	var any_dragging_in_zone = false

	for sticker in _sticker_container.get_children():
		if sticker is Sticker:
			var id = sticker.get_instance_id()
			var is_dragging = sticker.dragging
			var was_dragging = _was_dragging.get(id, false)

			if is_dragging:
				_was_dragging[id] = true
				if finger_in_zone:
					any_dragging_in_zone = true
			elif was_dragging:
				_was_dragging.erase(id)
				if finger_in_zone:
					_delete_sticker(sticker, trash_center)

	# Update modulate alleen bij wijziging
	if _trash_highlighted != any_dragging_in_zone:
		_trash_highlighted = any_dragging_in_zone
		_trash_button.modulate = Color(1.5, 0.5, 0.5) if any_dragging_in_zone else Color.WHITE


func _delete_sticker(sticker: Sticker, trash_center: Vector2) -> void:
	## Animeer sticker naar prullenbak en verwijder
	var is_drager = sticker.has_meta("is_drager")
	sticker._deselect()
	sticker.set_process_unhandled_input(false)
	sticker.set_process(false)
	sticker._outside_boundary = false
	sticker.modulate = Color.WHITE
	var tween = create_tween().set_parallel()
	tween.tween_property(sticker, "position", trash_center, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sticker, "scale", Vector2.ZERO, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sticker, "rotation", sticker.rotation + TAU, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sticker, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(func():
		sticker.queue_free()
		# Knoppen bijwerken: zonder instrumenten hoort de play-knop weg te zijn
		_update_button_visibility()
		if is_drager:
			_show_drager_selection()
	)


# === MUZIEKDRAGER SELECTIE (bij verwijderen drager sticker) ===

const DRAGERS = [
	{"id": "groove", "texture": preload("res://assets/muziekdragers/speelplaat.png")},
	{"id": "klassiek", "texture": preload("res://assets/muziekdragers/cilinder.png")},
	{"id": "klezmer", "texture": preload("res://assets/muziekdragers/orgelboek.png")},
	{"id": "pop", "texture": preload("res://assets/muziekdragers/papierrol.png")},
]


func _setup_drager_overlay() -> void:
	pass  # Overlay wordt on-demand aangemaakt vanuit fase_muziekdrager scene


func _show_drager_selection() -> void:
	## Instantieer fase_muziekdrager als overlay over fase 3
	var fase_scene = preload("res://scenes/fase_muziekdrager/fase_muziekdrager.tscn")
	_drager_overlay = fase_scene.instantiate()
	add_child(_drager_overlay)
	# Verberg sticker UI en blokkeer sticker input
	_slider_container.visible = false
	$UILayer.visible = false
	_set_stickers_input(false)
	# Verberg de achtergrond zodat de kast van fase 3 zichtbaar blijft
	var bg = _drager_overlay.get_node_or_null("Background")
	if bg:
		bg.visible = false

	# Verbind het phase_completed signal — als drager gekozen is
	_drager_overlay.phase_completed.connect(func():
		var data = _drager_overlay.get_phase_data()
		var genre: String = data.get("genre", "groove")
		var tex: Texture2D = data.get("drager_texture")

		_drager_overlay.queue_free()
		_drager_overlay = null

		# Zowel de tracks als het preview-geluid moeten mee — anders hoor je bij
		# het aantikken van de nieuwe drager nog het genre van de oude
		_current_genre = genre
		_audio_player.set_genre(genre)
		if tex:
			_place_drager_sticker(tex)
		# Herstel sticker UI en input
		$UILayer.visible = true
		_slider_container.visible = true
		_set_stickers_input(true)
		_update_button_visibility()
	)


# === EINDSCHERM ===

var _end_screen_image: Image = null  ## Opgeslagen render voor eindscherm
var _front_render: Image = null  ## Voorkant render (van fase 2)
var _original_decoration: Dictionary = {}  ## Originele decoratie waardes voor voorkant render

func _show_end_screen() -> void:
	## Toon eindscherm: binnenkant render als draaiende sprite die uitfadet
	_audio_player.stop_playback()
	_draaiwiel.reset()
	_playback_layer.visible = false
	$UILayer.visible = false

	# Fallback: als er geen render is, maak er nu een
	if not _end_screen_image:
		_background.visible = false
		get_viewport().transparent_bg = true
		await get_tree().process_frame
		await get_tree().process_frame
		_end_screen_image = get_viewport().get_texture().get_image()
		get_viewport().transparent_bg = false
		_background.visible = true

	# Verberg de echte kast + stickers
	var body = get_node_or_null("OrganContour")
	if body:
		body.visible = false
	_sticker_container.visible = false

	# Maak een sprite van de opgeslagen render
	var tex = ImageTexture.create_from_image(_end_screen_image)
	var sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.position = Vector2(540, 960)
	sprite.scale = Vector2(0.8, 0.8)
	add_child(sprite)

	# Animatie: draaien + krimpen + uitfaden (snappier)
	var tween = create_tween().set_parallel()
	tween.tween_property(sprite, "rotation", TAU * 0.4, 2.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 2.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite, "modulate:a", 0.0, 2.0).set_delay(0.3)

	# Na 3 seconden: reset naar fase 1
	await get_tree().create_timer(3.0).timeout
	var main = get_parent().get_parent()
	if main.has_method("start_phase"):
		main.start_phase(0)


# === OPSLAAN ===

var _confirm_mode: bool = false  ## Bevestigingsmodus actief

func _on_save_pressed() -> void:
	if _confirm_mode:
		return
	# Wissel naar bevestigingsmodus: camera → vinkje + kruisje
	_confirm_mode = true
	_save_button.icon_type = IconButton.IconType.CHECKMARK
	_save_button.color = Color(0.2, 0.65, 0.3, 0.9)
	_back_button.icon_type = IconButton.IconType.CLOSE
	_back_button.color = Color(0.8, 0.2, 0.2, 0.9)
	# Vinkje = opslaan, kruisje = annuleer
	_save_button.pressed.disconnect(_on_save_pressed)
	_back_button.pressed.disconnect(_stop_playback)
	_save_button.pressed.connect(_on_confirm_save)
	_back_button.pressed.connect(_on_cancel_save)


func _on_confirm_save() -> void:
	## Screenshot opslaan en eindscherm tonen
	_reset_save_buttons()
	_save_screenshot()
	_show_end_screen()


func _on_cancel_save() -> void:
	## Annuleer opslaan, terug naar normaal
	_reset_save_buttons()


func _reset_save_buttons() -> void:
	_confirm_mode = false
	# Herstel knoppen
	_save_button.icon_type = IconButton.IconType.UPLOAD
	_save_button.color = Color(0.2, 0.65, 0.3, 0.9)
	_back_button.icon_type = IconButton.IconType.BACK
	_back_button.color = Color(1, 1, 1, 1)
	# Herstel signal verbindingen
	if _save_button.pressed.is_connected(_on_confirm_save):
		_save_button.pressed.disconnect(_on_confirm_save)
	if _back_button.pressed.is_connected(_on_cancel_save):
		_back_button.pressed.disconnect(_on_cancel_save)
	if not _save_button.pressed.is_connected(_on_save_pressed):
		_save_button.pressed.connect(_on_save_pressed)
	if not _back_button.pressed.is_connected(_stop_playback):
		_back_button.pressed.connect(_stop_playback)



func _save_screenshot() -> void:
	## Combineer voorkant + binnenkant en sla op naar remote pad (async)
	if not _end_screen_image:
		print("Geen binnenkant render — skip opslaan")
		return
	if remote_fotos_path.is_empty():
		print("Geen remote pad ingesteld — skip opslaan")
		return

	var w = _end_screen_image.get_width()
	var h = _end_screen_image.get_height()
	var combined = Image.create(w * 2, h, true, Image.FORMAT_RGBA8)
	if _front_render:
		combined.blit_rect(_front_render, Rect2i(0, 0, _front_render.get_width(), _front_render.get_height()), Vector2i(0, 0))
	combined.blit_rect(_end_screen_image, Rect2i(0, 0, w, h), Vector2i(w, 0))

	var datetime = Time.get_datetime_dict_from_system()
	var pc_name = "unknown"
	var f = FileAccess.open("/etc/hostname", FileAccess.READ)
	if f:
		pc_name = f.get_as_text().strip_edges()
		f.close()
	if pc_name.is_empty():
		pc_name = str(randi() & 0xFFFF)
	var filename = "speelklok_%s_%04d%02d%02d_%02d%02d%02d.png" % [
		pc_name,
		datetime["year"], datetime["month"], datetime["day"],
		datetime["hour"], datetime["minute"], datetime["second"]
	]

	## Bewaar alleen de laatste foto — overschrijft eerdere onverzonden foto's
	var png_data = combined.save_png_to_buffer()
	_photo_mutex.lock()
	_pending_photo = {"data": png_data, "path": remote_fotos_path + "/" + filename}
	_photo_mutex.unlock()

	## Start save-thread als die nog niet draait
	if not _save_thread:
		_save_thread = Thread.new()
		_save_thread.start(_photo_save_loop)


func _photo_save_loop() -> void:
	## Achtergrond-thread: wacht op connectie, sla laatste foto op, stop als alles verzonden
	while true:
		_photo_mutex.lock()
		var photo = _pending_photo.duplicate()
		_photo_mutex.unlock()

		if photo.is_empty():
			break  # Niks meer te doen

		if DirAccess.dir_exists_absolute(remote_fotos_path):
			var file = FileAccess.open(photo["path"], FileAccess.WRITE)
			if file:
				file.store_buffer(photo["data"])
				file.close()
				print("Screenshot opgeslagen: ", photo["path"])
				_photo_mutex.lock()
				if _pending_photo.get("path") == photo["path"]:
					_pending_photo = {}  # Alleen wissen als niet inmiddels vervangen
				_photo_mutex.unlock()
				continue  # Check meteen of er een nieuwere foto is
			else:
				print("Foto schrijven mislukt: ", photo["path"])
		else:
			print("Wacht op remote pad: ", remote_fotos_path)

		OS.delay_msec(5000)

	call_deferred("_on_save_thread_done")


func _on_save_thread_done() -> void:
	if _save_thread:
		_save_thread.wait_to_finish()
		_save_thread = null


func _on_wheel_speed_changed(speed_factor: float) -> void:
	if not _is_playing:
		return

	if speed_factor < 0.05:
		# Wiel staat stil — demp muziek
		for instrument_id in _audio_player._players:
			_audio_player._players[instrument_id].volume_db = -80.0
		return

	# Tempo: map speed_factor naar 0.5 - 1.0 (nooit sneller dan normaal)
	var tempo = clampf(speed_factor, 0.5, 1.0)
	_audio_player.set_playback_speed(tempo)

	# Volume: snel vol bij enige draaiing
	var vol = clampf(speed_factor / 0.3, 0.0, 1.0)
	for instrument_id in _audio_player._players:
		if _audio_player._active_instruments.has(instrument_id):
			_audio_player._players[instrument_id].volume_db = linear_to_db(vol)
		else:
			_audio_player._players[instrument_id].volume_db = -80.0


# === AUDIO PLAYBACK ===

func _on_play_pressed() -> void:
	if _is_playing:
		_stop_playback()
	else:
		# Deselecteer alle stickers (geen witte rand in de foto)
		if Sticker._selected_sticker:
			Sticker._selected_sticker._deselect()
		# Foto van binnenkant maken (1 frame) voordat draaiwiel verschijnt
		$UILayer.visible = false
		_background.visible = false
		get_viewport().transparent_bg = true
		await RenderingServer.frame_post_draw
		_end_screen_image = get_viewport().get_texture().get_image()
		get_viewport().transparent_bg = false
		_background.visible = true
		$UILayer.visible = true
		_start_playback()


func _start_playback() -> void:
	var active = _scan_active_instruments()
	if active.is_empty():
		return
	_is_playing = true
	_set_stickers_input(false)
	_drag_hint.hide_hint()
	_stop_hint_demo()
	if Sticker._selected_sticker:
		Sticker._selected_sticker._deselect()

	# Animatie: slider bar faded uit, playback UI faded in
	_slider_container.visible = true
	_playback_layer.visible = true
	_playback_layer.get_node("Draaiwiel").modulate.a = 0.0
	_playback_layer.get_node("BackButton").modulate.a = 0.0
	_playback_layer.get_node("SaveButton").modulate.a = 0.0

	var tween = create_tween().set_parallel()
	tween.tween_property(_slider_container, "modulate:a", 0.0, 0.2)
	tween.tween_property(_playback_layer.get_node("Draaiwiel"), "modulate:a", 1.0, 0.3).set_delay(0.1)
	tween.tween_property(_playback_layer.get_node("BackButton"), "modulate:a", 1.0, 0.2).set_delay(0.1)
	tween.chain().tween_callback(func():
		_slider_container.visible = false
		_slider_container.modulate.a = 1.0
	)

	# Upload-knop verdienen: verschijnt pas na genoeg draaien aan het wiel
	_spin_time = 0.0
	_save_button.visible = false
	_save_button.modulate.a = 0.0

	# Start muziek gedempt — het wiel bepaalt het volume
	_audio_player.play_layers(active)
	for instrument_id in _audio_player._players:
		var player: AudioStreamPlayer = _audio_player._players[instrument_id]
		player.volume_db = -80.0
	_draaiwiel.reset()
	# Even vanzelf draaien zodat duidelijk is wat de bedoeling is; daarna
	# loopt het wiel uit en moet de bezoeker het overnemen
	_draaiwiel.start_auto_spin(auto_play_duration)
	_update_button_visibility()


func _update_save_button(delta: float) -> void:
	## De upload-knop verschijnt pas als er echt een tijdje gedraaid is.
	## Het voordoen telt niet mee — de teller loopt pas vanaf het moment dat
	## de bezoeker zelf aan het wiel draait.
	if _save_button.visible:
		return
	if _draaiwiel.is_auto_spinning() or not _draaiwiel.has_user_spun():
		return
	if _draaiwiel.get_speed_factor() < save_button_spin_threshold:
		return
	_spin_time += delta
	if _spin_time >= save_button_spin_time:
		_save_button.visible = true
		_save_button.modulate.a = 0.0
		create_tween().tween_property(_save_button, "modulate:a", 1.0, 0.3)


func _stop_playback() -> void:
	_is_playing = false
	_play_button.icon_type = IconButton.IconType.PLAY
	_audio_player.stop_playback()
	_draaiwiel.reset()
	for sticker in _sticker_container.get_children():
		if sticker is Sticker:
			sticker.reset_audio_pulse()
	_set_stickers_input(true)

	# Animatie: playback UI faded uit, sliders faden in
	_slider_container.visible = true
	_slider_container.modulate.a = 0.0
	var tween = create_tween().set_parallel()
	tween.tween_property(_playback_layer.get_node("Draaiwiel"), "modulate:a", 0.0, 0.2)
	tween.tween_property(_playback_layer.get_node("BackButton"), "modulate:a", 0.0, 0.15)
	tween.tween_property(_playback_layer.get_node("SaveButton"), "modulate:a", 0.0, 0.15)
	tween.tween_property(_slider_container, "modulate:a", 1.0, 0.2).set_delay(0.1)
	tween.chain().tween_callback(func():
		_playback_layer.visible = false
		_update_button_visibility()
	)


func _scan_active_instruments() -> Dictionary:
	## Bouw dictionary: instrument_id → volume (altijd 1.0) op basis van geplaatste stickers
	var result: Dictionary = {}
	for sticker in _sticker_container.get_children():
		if not sticker is Sticker:
			continue
		var instrument_id = sticker.scene_file_path.get_file().get_basename()
		if instrument_id.is_empty():
			continue
		result[instrument_id] = 1.0
	return result


func _update_sticker_pulse(delta: float) -> void:
	## Pas sticker schaal aan op basis van hun instrument's audio amplitude
	var magnitudes = _audio_player.get_all_magnitudes()

	# Bereken gemiddelde magnitude voor de muziekdrager sticker
	var total_mag: float = 0.0
	var active_count: int = 0
	for mag_val in magnitudes.values():
		if mag_val > 0.001:
			total_mag += mag_val
			active_count += 1
	var avg_mag: float = total_mag / float(maxi(active_count, 1))

	for sticker in _sticker_container.get_children():
		if not sticker is Sticker:
			continue
		if sticker.has_meta("is_drager"):
			# Muziekdrager reageert op gemiddelde van alle instrumenten
			sticker.set_audio_pulse(avg_mag, delta)
		else:
			var instrument_id = sticker.scene_file_path.get_file().get_basename()
			var mag = magnitudes.get(instrument_id, 0.0)
			sticker.set_audio_pulse(mag, delta)


# === SLIDERS ===

func _on_sticker_selection_changed(is_selected: bool, sticker: Sticker) -> void:
	if is_selected:
		_tracked_sticker = sticker
		_update_slider_values(sticker)
		# Speel instrument geluid (niet als picker open of net geplaatst)
		if not _picker_open:
			if sticker.has_meta("is_drager"):
				# Muziekdrager: speel genre preview
				var preview_path = "res://audio/previews/" + _current_genre + ".wav"
				var stream = load(preview_path)
				if stream and _oneshot_player:
					_oneshot_player.stream = stream
					_oneshot_player.play()
			else:
				var instrument_id = sticker.scene_file_path.get_file().get_basename()
				if not instrument_id.is_empty():
					_play_oneshot(instrument_id)
	elif _tracked_sticker == sticker:
		_tracked_sticker = null
		# Sticker niet meer geselecteerd — geen witte rand, dus ook geen hint
		_drag_hint.hide_hint()
		_stop_hint_demo()
	_update_button_visibility()


func _update_slider_values(sticker: Sticker) -> void:
	## Stel slider waardes in op basis van sticker state
	_updating_sliders = true
	var rot_deg = rad_to_deg(fmod(sticker.rotation, TAU))
	if rot_deg > 180.0:
		rot_deg -= 360.0
	elif rot_deg < -180.0:
		rot_deg += 360.0
	_rotate_slider.value = rot_deg
	_scale_slider.min_value = sticker._base_scale * sticker.min_scale
	_scale_slider.max_value = sticker._base_scale * sticker.max_scale
	_scale_slider.value = sticker.scale.x
	_updating_sliders = false


func _update_sliders() -> void:
	## Synchroniseer slider waardes met sticker (alleen bij pinch/rotate)
	if _tracked_sticker == null or not _slider_container.visible:
		return
	if not _tracked_sticker.dragging:
		return
	_updating_sliders = true
	_scale_slider.value = _tracked_sticker.scale.x
	# Kortste hoekafstand tot huidige slider positie, dan clampen (voorkomt springen)
	var prev = _rotate_slider.value
	var rot_deg = rad_to_deg(_tracked_sticker.rotation)
	var diff = fposmod(rot_deg - prev + 180.0, 360.0) - 180.0
	_rotate_slider.value = clampf(prev + diff, -180.0, 180.0)
	_updating_sliders = false


func _on_rotate_slider_changed(new_value: float) -> void:
	if _updating_sliders or _tracked_sticker == null:
		return
	_tracked_sticker.rotation = deg_to_rad(new_value)


func _on_scale_slider_changed(new_value: float) -> void:
	if _updating_sliders or _tracked_sticker == null:
		return
	_tracked_sticker.scale = Vector2(new_value, new_value)
	_tracked_sticker._target_scale = Vector2(new_value, new_value)


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


# === ORGEL CONTOUR CONSTRAINING ===

func _constrain_to_organ(pos: Vector2) -> Vector2:
	## Beperk positie tot binnen de orgel-contour polygon
	if _organ_polygon_world.size() < 3:
		return pos
	if _point_in_polygon(pos, _organ_polygon_world):
		return pos
	return _nearest_point_on_edge(pos, _organ_polygon_world)


func _random_position_in_organ(sticker: Sticker) -> Vector2:
	## Zoek een random plek binnen de kast, zo ver mogelijk van de al geplaatste stickers
	if _organ_polygon_world.size() < 3:
		return get_viewport_rect().size / 2.0

	# Marge tot de rand zodat de sticker er niet half overheen hangt
	var margin := 0.0
	if sticker.texture:
		var half := minf(sticker.texture.get_width(), sticker.texture.get_height()) \
			* absf(sticker.scale.x) * 0.5
		margin = half * placement_edge_margin

	var existing := PackedVector2Array()
	for child in _sticker_container.get_children():
		if child is Sticker:
			existing.append(child.position)

	var best := _organ_center
	var best_score := -1.0
	var fallback := _organ_center
	var has_fallback := false

	for i in placement_candidates:
		var p := Vector2(
			randf_range(_organ_bounds.position.x, _organ_bounds.end.x),
			randf_range(_organ_bounds.position.y, _organ_bounds.end.y)
		)
		if not _point_in_polygon(p, _organ_polygon_world):
			continue
		# Eerste punt binnen de kast bewaren voor als de marge nergens past
		if not has_fallback:
			fallback = p
			has_fallback = true
		if margin > 0.0 and _nearest_point_on_edge(p, _organ_polygon_world).distance_to(p) < margin:
			continue
		# Score = afstand tot de dichtstbijzijnde bestaande sticker (verder weg = beter)
		var score := INF
		for other in existing:
			score = minf(score, p.distance_squared_to(other))
		if score > best_score:
			best_score = score
			best = p

	# Smalle kast: geen enkel punt haalde de marge — pak dan een punt zonder marge
	if best_score < 0.0:
		return fallback
	return best


static func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	## Ray-casting point-in-polygon test
	var inside := false
	var n := polygon.size()
	var j := n - 1
	for i in range(n):
		var pi := polygon[i]
		var pj := polygon[j]
		if ((pi.y > point.y) != (pj.y > point.y)) and \
			(point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x):
			inside = not inside
		j = i
	return inside


static func _nearest_point_on_edge(point: Vector2, polygon: PackedVector2Array) -> Vector2:
	## Vind het dichtstbijzijnde punt op de rand van de polygon
	var best_point := polygon[0]
	var best_dist := INF
	var n := polygon.size()
	for i in range(n):
		var a := polygon[i]
		var b := polygon[(i + 1) % n]
		var closest := _closest_point_on_segment(point, a, b)
		var dist := point.distance_squared_to(closest)
		if dist < best_dist:
			best_dist = dist
			best_point = closest
	return best_point


static func _closest_point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	## Vind het dichtstbijzijnde punt op een lijnsegment
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.001:
		return a
	var t := clampf((point - a).dot(ab) / len_sq, 0.0, 1.0)
	return a + ab * t
