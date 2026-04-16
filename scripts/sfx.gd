class_name SFX
extends Node

## 程序化合成音效（无外部 wav/ogg），挂到场景树即可用。

var _players: Array[AudioStreamPlayer] = []
var _ambient_player: AudioStreamPlayer = null
var _current_ambient: String = ""


func _ready() -> void:
	for i in range(8):
		var asp := AudioStreamPlayer.new()
		asp.bus = &"Master"
		add_child(asp)
		_players.append(asp)
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = &"Master"
	_ambient_player.volume_db = -18.0
	add_child(_ambient_player)


func _get_free() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]


func play_place_bomb() -> void:
	_play_tone(220.0, 0.08, -8.0)


func play_explosion() -> void:
	_play_noise(0.22, -6.0)


func play_pickup() -> void:
	_play_tone(660.0, 0.06, -10.0)
	await get_tree().create_timer(0.06).timeout
	_play_tone(880.0, 0.06, -10.0)


func play_win() -> void:
	_play_tone(523.0, 0.10, -8.0)
	await get_tree().create_timer(0.10).timeout
	_play_tone(659.0, 0.10, -8.0)
	await get_tree().create_timer(0.10).timeout
	_play_tone(784.0, 0.15, -8.0)


func play_lose() -> void:
	_play_tone(330.0, 0.12, -8.0)
	await get_tree().create_timer(0.12).timeout
	_play_tone(262.0, 0.18, -8.0)


func play_kick() -> void:
	_play_tone(350.0, 0.05, -7.0)


func play_detonate() -> void:
	_play_tone(520.0, 0.04, -6.0)


func play_shield_break() -> void:
	_play_tone(880.0, 0.04, -8.0)
	await get_tree().create_timer(0.04).timeout
	_play_tone(660.0, 0.06, -8.0)


func play_curse() -> void:
	_play_tone(180.0, 0.15, -7.0)


func play_teleport() -> void:
	_play_tone(880.0, 0.04, -9.0)
	await get_tree().create_timer(0.04).timeout
	_play_tone(1100.0, 0.04, -9.0)


func play_shrink() -> void:
	_play_noise(0.12, -7.0)
	await get_tree().create_timer(0.06).timeout
	_play_tone(160.0, 0.10, -6.0)


func play_iron_hit() -> void:
	_play_tone(280.0, 0.06, -6.0)


func start_ambient(theme: String) -> void:
	if theme == _current_ambient and _ambient_player.playing:
		return
	_current_ambient = theme
	var melody: Array = []
	var bass: Array = []
	var bpm := 120.0
	match theme:
		"grassland":
			bpm = 110.0
			melody = [
				[392.0, 0.5], [440.0, 0.5], [494.0, 0.5], [523.0, 1.0],
				[494.0, 0.5], [440.0, 0.5], [392.0, 1.0],
				[330.0, 0.5], [392.0, 0.5], [440.0, 1.0], [392.0, 0.5],
				[330.0, 0.5], [294.0, 1.0], [0.0, 0.5],
				[294.0, 0.5], [330.0, 0.5], [392.0, 0.5], [440.0, 1.0],
				[494.0, 0.5], [523.0, 1.0], [494.0, 0.5],
				[440.0, 0.5], [392.0, 0.5], [330.0, 0.5], [294.0, 0.5],
				[330.0, 1.5], [0.0, 0.5],
			]
			bass = [
				[196.0, 2.0], [165.0, 2.0], [147.0, 2.0], [196.0, 2.0],
				[196.0, 2.0], [165.0, 2.0], [147.0, 2.0], [196.0, 2.0],
			]
		"tundra":
			bpm = 72.0
			melody = [
				[330.0, 1.5], [294.0, 0.5], [262.0, 1.0], [0.0, 1.0],
				[220.0, 1.0], [262.0, 1.0], [247.0, 2.0],
				[0.0, 1.0], [262.0, 1.0], [294.0, 1.0], [330.0, 1.0],
				[262.0, 1.5], [220.0, 0.5], [196.0, 2.0],
			]
			bass = [
				[131.0, 4.0], [110.0, 4.0], [131.0, 4.0], [98.0, 4.0],
			]
		"desert":
			bpm = 100.0
			melody = [
				[294.0, 0.5], [330.0, 0.5], [349.0, 0.5], [440.0, 1.0],
				[349.0, 0.5], [330.0, 0.5], [294.0, 0.5],
				[262.0, 1.0], [294.0, 0.5], [0.0, 0.5],
				[349.0, 0.5], [392.0, 0.5], [440.0, 1.0], [523.0, 0.5],
				[440.0, 0.5], [392.0, 0.5], [349.0, 0.5],
				[294.0, 1.5], [0.0, 0.5],
			]
			bass = [
				[147.0, 2.0], [131.0, 2.0], [147.0, 2.0], [175.0, 2.0],
				[147.0, 2.0], [131.0, 2.0],
			]
		"volcano":
			bpm = 138.0
			melody = [
				[330.0, 0.5], [311.0, 0.5], [294.0, 0.5], [330.0, 0.5],
				[247.0, 1.0], [0.0, 0.5], [294.0, 0.5],
				[330.0, 0.5], [370.0, 0.5], [392.0, 1.0],
				[330.0, 0.5], [294.0, 0.5],
				[247.0, 0.5], [220.0, 0.5], [247.0, 0.5], [294.0, 0.5],
				[330.0, 1.5], [0.0, 0.5],
			]
			bass = [
				[165.0, 2.0], [147.0, 2.0], [131.0, 2.0], [110.0, 2.0],
				[165.0, 2.0], [147.0, 2.0],
			]
		_:
			bpm = 125.0
			melody = [
				[523.0, 0.5], [494.0, 0.25], [523.0, 0.25], [587.0, 0.5],
				[523.0, 0.5], [440.0, 0.5], [392.0, 0.5],
				[0.0, 0.25], [392.0, 0.25], [440.0, 0.5], [523.0, 0.5],
				[494.0, 0.5], [440.0, 0.5], [392.0, 1.0],
			]
			bass = [
				[262.0, 2.0], [220.0, 2.0], [196.0, 2.0], [262.0, 2.0],
			]
	var stream := _render_music(melody, bass, bpm)
	_ambient_player.stream = stream
	_ambient_player.play()


func stop_ambient() -> void:
	_ambient_player.stop()
	_current_ambient = ""


func _render_music(melody: Array, bass_line: Array, bpm: float) -> AudioStreamWAV:
	var sr := 44100
	var beat_sec := 60.0 / bpm
	var total_beats := 0.0
	for n in melody:
		var note: Array = n
		total_beats += note[1]
	var dur := total_beats * beat_sec
	var frames := int(dur * sr)
	if frames < 100:
		frames = sr

	var buf := PackedFloat32Array()
	buf.resize(frames)
	buf.fill(0.0)

	_render_piano(buf, melody, beat_sec, sr, 0.30, 1.0)
	_render_piano(buf, melody, beat_sec, sr, 0.08, 2.0)
	_render_piano(buf, bass_line, beat_sec, sr, 0.18, 1.0)

	_apply_reverb(buf, sr)

	var gen := AudioStreamWAV.new()
	gen.mix_rate = sr
	gen.format = AudioStreamWAV.FORMAT_16_BITS
	gen.stereo = false
	gen.loop_mode = AudioStreamWAV.LOOP_FORWARD
	gen.loop_begin = 0
	gen.loop_end = frames
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var s := int(clampf(buf[i], -1.0, 1.0) * 32000.0)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	gen.data = data
	return gen


func _render_piano(buf: PackedFloat32Array, notes: Array, beat_sec: float,
		sr: int, vol: float, freq_mult: float) -> void:
	var pos := 0.0
	for n in notes:
		var note: Array = n
		var freq: float = note[0] * freq_mult
		var beats: float = note[1]
		var dur := beats * beat_sec
		var start_frame := int(pos * sr)
		var tail := minf(dur + 0.6, dur * 2.5)
		var end_frame := mini(int((pos + tail) * sr), buf.size())

		if freq > 20.0:
			var attack := 0.005
			var decay_rate := 3.5 + freq * 0.002
			for i in range(start_frame, end_frame):
				var t := float(i - start_frame) / sr
				var env: float
				if t < attack:
					env = t / attack
				else:
					env = exp(-(t - attack) * decay_rate)

				var h1 := sin(TAU * freq * t)
				var h2 := sin(TAU * freq * 2.0 * t) * exp(-t * 1.5) * 0.45
				var h3 := sin(TAU * freq * 3.0 * t) * exp(-t * 3.0) * 0.18
				var h4 := sin(TAU * freq * 4.0 * t) * exp(-t * 5.0) * 0.08
				var h5 := sin(TAU * freq * 5.01 * t) * exp(-t * 7.0) * 0.04

				var wave := (h1 + h2 + h3 + h4 + h5) * env * vol
				buf[i] += wave
		pos += dur


func _apply_reverb(buf: PackedFloat32Array, sr: int) -> void:
	var delay1 := int(0.08 * sr)
	var delay2 := int(0.16 * sr)
	var delay3 := int(0.25 * sr)
	for i in range(buf.size() - 1, -1, -1):
		var echo := 0.0
		if i + delay1 < buf.size():
			echo += buf[i] * 0.20
			buf[i + delay1] += echo
		if i + delay2 < buf.size():
			buf[i + delay2] += buf[i] * 0.10
		if i + delay3 < buf.size():
			buf[i + delay3] += buf[i] * 0.05


func _play_tone(freq: float, dur: float, vol_db: float) -> void:
	var sample_rate := 22050
	var frames := int(dur * sample_rate)
	var gen := AudioStreamWAV.new()
	gen.mix_rate = sample_rate
	gen.format = AudioStreamWAV.FORMAT_8_BITS
	gen.stereo = false
	var data := PackedByteArray()
	data.resize(frames)
	for i in range(frames):
		var t := float(i) / sample_rate
		var env := clampf(1.0 - t / dur, 0.0, 1.0)
		var sample := sin(TAU * freq * t) * env
		data[i] = int(clampf(sample * 127.0 + 128.0, 0, 255))
	gen.data = data
	var p := _get_free()
	p.stream = gen
	p.volume_db = vol_db
	p.play()


func _play_noise(dur: float, vol_db: float) -> void:
	var sample_rate := 22050
	var frames := int(dur * sample_rate)
	var gen := AudioStreamWAV.new()
	gen.mix_rate = sample_rate
	gen.format = AudioStreamWAV.FORMAT_8_BITS
	gen.stereo = false
	var data := PackedByteArray()
	data.resize(frames)
	for i in range(frames):
		var t := float(i) / sample_rate
		var env := clampf(1.0 - t / dur, 0.0, 1.0)
		var sample := (randf() * 2.0 - 1.0) * env
		data[i] = int(clampf(sample * 127.0 + 128.0, 0, 255))
	gen.data = data
	var p := _get_free()
	p.stream = gen
	p.volume_db = vol_db
	p.play()
