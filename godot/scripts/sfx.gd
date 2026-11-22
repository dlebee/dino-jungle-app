extends Node
## Music, a synthesized "found it" chime, and the device's text-to-speech voice. All offline.

var music := AudioStreamPlayer.new()
var chime_player := AudioStreamPlayer.new()
var ambience := AudioStreamPlayer.new()
var music_on := true:
	set(v):
		music_on = v
		music.stream_paused = not v
		if v and not music.playing:
			music.play()

var _voice := ""


func _ready() -> void:
	for f in ["music.ogg", "music.mp3"]:
		if ResourceLoader.exists("res://assets/audio/" + f):
			var s = load("res://assets/audio/" + f)
			s.loop = true
			music.stream = s
			break
	music.volume_db = linear_to_db(0.22)
	add_child(music)
	if ResourceLoader.exists("res://assets/audio/ambience.mp3"):
		var a: AudioStreamMP3 = load("res://assets/audio/ambience.mp3")
		a.loop = true
		ambience.stream = a
		ambience.volume_db = linear_to_db(0.5)
		add_child(ambience)
	chime_player.stream = _make_chime()
	chime_player.volume_db = linear_to_db(0.9)
	add_child(chime_player)
	_pick_voice()


func start_music() -> void:
	if music_on and not music.playing and music.stream:
		music.play()
	if ambience.stream and not ambience.playing:
		ambience.play()


func chime() -> void:
	chime_player.play()


func say(text: String) -> void:
	if _voice == "":
		_pick_voice()
	if _voice == "":
		return
	DisplayServer.tts_speak(text, _voice, 90, 1.15, 0.9, 0, true)


func _pick_voice() -> void:
	var best := ""
	for v in DisplayServer.tts_get_voices():
		var lang := str(v.get("language", "")).to_lower().replace("-", "_")
		if lang.begins_with("en_us") and best == "":
			best = v["id"]
		elif lang.begins_with("en") and best == "" :
			best = v["id"]
	if best == "":
		var any := DisplayServer.tts_get_voices_for_language("en")
		if any.size() > 0:
			best = any[0]
	_voice = best


## C-E-G-C arpeggio with soft decay.
func _make_chime() -> AudioStreamWAV:
	var sr := 44100
	var frames := int(sr * 1.4)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var notes := [1046.5, 1318.5, 1568.0, 2093.0]
	for i in frames:
		var t := float(i) / sr
		var s := 0.0
		for k in notes.size():
			var start := k * 0.11
			if t >= start:
				var lt := t - start
				s += sin(TAU * notes[k] * lt) * exp(-lt * 4.0) * 0.22
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = sr
	w.stereo = false
	w.data = data
	return w


var _roar_player := AudioStreamPlayer.new()
var _roar_wav: AudioStreamWAV


## Big dinosaur roar. Uses assets/audio/roar*.ogg|wav|mp3 if present, else a synthesized growl.
func roar(pitch := 1.0) -> void:
	if not _roar_player.is_inside_tree():
		add_child(_roar_player)
		_roar_player.volume_db = linear_to_db(0.9)
	var files: Array[String] = []
	for ext in ["ogg", "wav", "mp3"]:
		for i in range(0, 6):
			var p := "res://assets/audio/roar%s.%s" % ["" if i == 0 else str(i), ext]
			if ResourceLoader.exists(p):
				files.append(p)
	if files.size() > 0:
		_roar_player.stream = load(files[randi() % files.size()])
	else:
		if _roar_wav == null:
			_roar_wav = _make_roar()
		_roar_player.stream = _roar_wav
	_roar_player.pitch_scale = clampf(pitch * randf_range(0.9, 1.1), 0.5, 2.5)
	_roar_player.play()


func _make_roar() -> AudioStreamWAV:
	var sr := 22050
	var frames := int(sr * 1.6)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var ph := 0.0
	var lp := 0.0
	for i in frames:
		var t := float(i) / sr
		var env := minf(t * 8.0, 1.0) * exp(-maxf(t - 0.5, 0.0) * 2.5)
		var f := 95.0 + 40.0 * sin(t * 3.0) - t * 25.0
		ph += TAU * f / sr
		var buzz := sin(ph) + 0.6 * sin(ph * 2.01) + 0.4 * sin(ph * 3.03)
		lp += (randf() * 2.0 - 1.0 - lp) * 0.08
		var s := (buzz * 0.35 + lp * 2.2) * env * (0.7 + 0.3 * sin(t * 37.0))
		data.encode_s16(i * 2, int(clampf(s * 0.8, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = sr
	w.data = data
	return w
