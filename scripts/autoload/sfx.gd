extends Node
## Sons et musique synthétisés au lancement (aucun fichier audio), et vibrations.

const RATE := 22050

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_thread: Thread


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -14.0
	add_child(_music)
	_sounds.tap = _tone([[900.0, 0.05]], 0.25, "sine")
	_sounds.cross = _tone([[520.0, 0.07]], 0.3, "triangle")
	_sounds.check = _tone([[660.0, 0.06], [990.0, 0.1]], 0.3, "sine")
	_sounds.erase = _tone([[380.0, 0.05]], 0.2, "triangle")
	_sounds.pop = _tone([[620.0, 0.04]], 0.25, "sine")
	_sounds.coin = _tone([[1320.0, 0.05], [1760.0, 0.16]], 0.22, "bell")
	_sounds.star = _tone([[880.0, 0.08], [1175.0, 0.08], [1760.0, 0.22]], 0.25, "bell")
	_sounds.win = _tone([[523.0, 0.1], [659.0, 0.1], [784.0, 0.1], [1047.0, 0.35]], 0.3, "bell")
	_sounds.unlock = _tone([[392.0, 0.09], [523.0, 0.09], [659.0, 0.09], [784.0, 0.09], [1047.0, 0.4]], 0.3, "bell")
	_sounds.error = _tone([[220.0, 0.08], [196.0, 0.14]], 0.25, "square")
	_sounds.whoosh = _noise(0.18, 0.12)
	_music_thread = Thread.new()
	_music_thread.start(_build_music)


func play(id: String, pitch: float = 1.0) -> void:
	if not Game.setting("sound") or not _sounds.has(id):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[id]
	p.pitch_scale = pitch
	p.play()


func buzz(ms: int = 18) -> void:
	if Game.setting("vibration"):
		Input.vibrate_handheld(ms)


func update_music() -> void:
	if Game.setting("music"):
		if _music.stream and not _music.playing:
			_music.play()
	else:
		_music.stop()


func _exit_tree() -> void:
	if _music_thread and _music_thread.is_started():
		_music_thread.wait_to_finish()


# --- Synthèse -----------------------------------------------------------------

func _osc(kind: String, phase: float) -> float:
	match kind:
		"triangle":
			return 2.0 * abs(2.0 * (phase - floor(phase + 0.5))) - 1.0
		"square":
			return 0.6 if fmod(phase, 1.0) < 0.5 else -0.6
		"bell":
			return sin(TAU * phase) * 0.7 + sin(TAU * phase * 2.0) * 0.2 + sin(TAU * phase * 3.01) * 0.1
	return sin(TAU * phase)


func _tone(notes: Array, vol: float, kind: String) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	for note in notes:
		var f: float = note[0]
		var dur: float = note[1]
		var n := int(dur * RATE)
		for i in n:
			var t := float(i) / RATE
			var env: float = min(1.0, t * 400.0) * exp(-t * 6.0 / dur)
			samples.append(_osc(kind, f * t) * env * vol)
	return _to_wav(samples, false)


func _noise(dur: float, vol: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var n := int(dur * RATE)
	var last := 0.0
	for i in n:
		var t := float(i) / n
		last = last * 0.85 + randf_range(-1, 1) * 0.15
		samples.append(last * sin(PI * t) * vol * 4.0)
	return _to_wav(samples, false)


func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clamp(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## Petite boîte à musique pentatonique en boucle (16 mesures).
func _build_music() -> void:
	var bpm := 84.0
	var beat := 60.0 / bpm
	var scale := [0, 2, 4, 7, 9, 12, 14, 16]
	var chords := [[0, 4, 7], [-3, 0, 4], [-7, -3, 0], [-5, -1, 2]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bars := 16
	var total := int(bars * 4 * beat * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var base := 523.25
	for bar in bars:
		var chord: Array = chords[(bar / 2) % chords.size()]
		# Basse douce sur les temps 1 et 3.
		for b in [0, 2]:
			_add_note(buf, (bar * 4 + b) * beat, base / 4.0 * pow(2.0, chord[0] / 12.0), beat * 1.8, 0.10)
		# Mélodie : croches pentatoniques, parfois silencieuses.
		for e in 8:
			if rng.randf() < 0.3:
				continue
			var deg: int = scale[rng.randi_range(0, scale.size() - 1)]
			_add_note(buf, (bar * 4 + e * 0.5) * beat, base * pow(2.0, deg / 12.0), beat * 1.2, 0.07)
		for k in chord:
			_add_note(buf, (bar * 4) * beat, base / 2.0 * pow(2.0, k / 12.0), beat * 3.5, 0.035)
	var wav := _to_wav(buf, true)
	call_deferred("_music_ready", wav)


func _add_note(buf: PackedFloat32Array, start: float, f: float, dur: float, vol: float) -> void:
	var s0 := int(start * RATE)
	var n := int(dur * RATE)
	for i in n:
		var idx := (s0 + i) % buf.size()
		var t := float(i) / RATE
		var env: float = min(1.0, t * 200.0) * exp(-t * 3.5 / dur)
		buf[idx] += (sin(TAU * f * t) * 0.8 + sin(TAU * f * 2.0 * t) * 0.2) * env * vol


func _music_ready(wav: AudioStreamWAV) -> void:
	_music_thread.wait_to_finish()
	_music.stream = wav
	update_music()
