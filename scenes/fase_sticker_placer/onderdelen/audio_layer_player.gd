@tool
extends Node2D
class_name AudioLayerPlayer

## Speelt gelaagde audio tracks af — 1 per instrument, gesynchroniseerd.
## Ondersteunt genre-switching: tracks worden herladen uit een genre-submap.
## Elke track heeft een eigen AudioBus met SpectrumAnalyzer voor amplitude detectie.

signal genre_changed(genre: String)

@export_group("Audio")
@export var tracks_base_path: String = "res://audio/tracks/"

@export_group("Pulse")
## Onder deze drempel = geen bounce (filtert stille passages)
@export var noise_threshold: float = 0.0001
## Bovengrens voor normalisatie (ruwe magnitude die mapt naar 1.0)
@export var magnitude_ceiling: float = 0.002
## Hoe snel de pulse reageert (0-1, hoger = sneller op, langzamer af)
@export var pulse_attack: float = 0.5
## Hoe snel de pulse terugvalt
@export var pulse_release: float = 0.15

var _players: Dictionary = {}  ## instrument_id → AudioStreamPlayer
var _analyzers: Dictionary = {}  ## instrument_id → AudioEffectSpectrumAnalyzerInstance
var _magnitudes: Dictionary = {}  ## instrument_id → float (0.0-1.0, smoothed)
var _is_playing: bool = false
var _active_instruments: Dictionary = {}  ## instrument_id → volume (0.0-1.0)
var _current_genre: String = "groove"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_load_tracks()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _is_playing:
		return
	_update_magnitudes()


## Wissel van genre — herlaadt alle tracks uit de nieuwe submap
func set_genre(genre: String) -> void:
	if genre == _current_genre and not _players.is_empty():
		return
	var was_playing = _is_playing
	var active = _active_instruments.duplicate()
	stop_playback()
	_cleanup_tracks()
	_current_genre = genre
	_load_tracks()
	genre_changed.emit(genre)
	if was_playing and not active.is_empty():
		play_layers(active)


func get_genre() -> String:
	return _current_genre


func _load_tracks() -> void:
	var path = tracks_base_path + _current_genre + "/"
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("AudioLayerPlayer: kan tracks map niet openen: " + path)
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "wav":
			var instrument_id = file_name.get_basename()
			var stream = load(path + file_name) as AudioStream
			if stream:
				_create_instrument_bus(instrument_id, stream)
		file_name = dir.get_next()
	dir.list_dir_end()


func _create_instrument_bus(instrument_id: String, stream: AudioStream) -> void:
	var bus_name = "inst_" + instrument_id
	var bus_idx = AudioServer.bus_count
	AudioServer.add_bus(bus_idx)
	AudioServer.set_bus_name(bus_idx, bus_name)
	AudioServer.set_bus_send(bus_idx, "Master")

	var analyzer = AudioEffectSpectrumAnalyzer.new()
	analyzer.buffer_length = 0.05
	analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_512
	AudioServer.add_bus_effect(bus_idx, analyzer)

	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -80.0
	player.bus = bus_name
	add_child(player)

	_players[instrument_id] = player
	_magnitudes[instrument_id] = 0.0


func play_layers(active_instruments: Dictionary) -> void:
	_active_instruments = active_instruments
	_is_playing = true

	for instrument_id in _players:
		var player: AudioStreamPlayer = _players[instrument_id]
		if active_instruments.has(instrument_id):
			var vol = clampf(active_instruments[instrument_id], 0.0, 1.0)
			player.volume_db = linear_to_db(vol)
		else:
			player.volume_db = -80.0

	for instrument_id in _players:
		var player: AudioStreamPlayer = _players[instrument_id]
		player.play(0.0)

	var first_player: AudioStreamPlayer = _players.values()[0] if _players.size() > 0 else null
	if first_player and not first_player.finished.is_connected(_on_track_finished):
		first_player.finished.connect(_on_track_finished)


func stop_playback() -> void:
	_is_playing = false
	_active_instruments.clear()
	for instrument_id in _players:
		var player: AudioStreamPlayer = _players[instrument_id]
		player.stop()
	for instrument_id in _magnitudes:
		_magnitudes[instrument_id] = 0.0


func is_playing() -> bool:
	return _is_playing


func set_playback_speed(speed: float) -> void:
	## Pas afspeelsnelheid aan via pitch_scale.
	## Binnen 0.5-1.0 is het pitch verschil acceptabel.
	if not _is_playing or speed < 0.01:
		return
	var clamped = clampf(speed, 0.5, 1.0)
	for instrument_id in _players:
		var player: AudioStreamPlayer = _players[instrument_id]
		player.pitch_scale = clamped


func get_magnitude(instrument_id: String) -> float:
	return _magnitudes.get(instrument_id, 0.0)


func get_all_magnitudes() -> Dictionary:
	return _magnitudes


func _cleanup_tracks() -> void:
	## Verwijder alle players, analyzers en audio buses
	for instrument_id in _players:
		var player: AudioStreamPlayer = _players[instrument_id]
		if player.finished.is_connected(_on_track_finished):
			player.finished.disconnect(_on_track_finished)
		player.stop()
		remove_child(player)
		player.queue_free()
	_players.clear()
	_analyzers.clear()
	_magnitudes.clear()
	# Verwijder inst_ buses
	for i in range(AudioServer.bus_count - 1, 0, -1):
		var bus_name = AudioServer.get_bus_name(i)
		if bus_name.begins_with("inst_"):
			AudioServer.remove_bus(i)


func _ensure_analyzers() -> void:
	if not _analyzers.is_empty():
		return
	for instrument_id in _players:
		var bus_name = "inst_" + instrument_id
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx < 0:
			continue
		var effect_instance = AudioServer.get_bus_effect_instance(bus_idx, 0)
		if effect_instance:
			_analyzers[instrument_id] = effect_instance


func _update_magnitudes() -> void:
	_ensure_analyzers()
	for instrument_id in _players:
		if not _active_instruments.has(instrument_id):
			_magnitudes[instrument_id] = 0.0
			continue
		var analyzer = _analyzers.get(instrument_id)
		if not analyzer:
			continue
		var mag: Vector2 = analyzer.get_magnitude_for_frequency_range(20.0, 8000.0)
		var avg = (mag.x + mag.y) / 2.0

		var gated: float
		if avg < noise_threshold:
			gated = 0.0
		else:
			gated = clampf((avg - noise_threshold) / (magnitude_ceiling - noise_threshold), 0.0, 1.0)

		var prev = _magnitudes.get(instrument_id, 0.0)
		var smooth: float
		if gated > prev:
			smooth = lerpf(prev, gated, pulse_attack)
		else:
			smooth = lerpf(prev, gated, pulse_release)
		_magnitudes[instrument_id] = smooth


func _on_track_finished() -> void:
	if not _is_playing:
		return
	for instrument_id in _players:
		var player: AudioStreamPlayer = _players[instrument_id]
		player.play(0.0)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	_cleanup_tracks()
