class_name SFX
extends Node

## 程序化合成音效（无外部 wav/ogg），挂到场景树即可用。

var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for i in range(8):
		var asp := AudioStreamPlayer.new()
		asp.bus = &"Master"
		add_child(asp)
		_players.append(asp)


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
