extends Node
## Tiny synthesised sound effects (no audio files needed).

const RATE := 22050
var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_sounds["swing"] = _make([[0.0, 0.07, 900.0, 300.0, 0.25, "noise"]])
	_sounds["hit"] = _make([[0.0, 0.06, 220.0, 90.0, 0.5, "square"], [0.0, 0.05, 0.0, 0.0, 0.3, "noise"]])
	_sounds["hurt"] = _make([[0.0, 0.18, 300.0, 120.0, 0.45, "square"]])
	_sounds["coin"] = _make([[0.0, 0.05, 1320.0, 1320.0, 0.25, "square"], [0.05, 0.1, 1760.0, 1760.0, 0.25, "square"]])
	_sounds["potion"] = _make([[0.0, 0.25, 400.0, 900.0, 0.3, "sine"]])
	_sounds["chest"] = _make([[0.0, 0.08, 523.0, 523.0, 0.3, "square"], [0.08, 0.08, 659.0, 659.0, 0.3, "square"], [0.16, 0.16, 784.0, 784.0, 0.3, "square"]])
	_sounds["level"] = _make([[0.0, 0.1, 523.0, 523.0, 0.3, "square"], [0.1, 0.1, 659.0, 659.0, 0.3, "square"], [0.2, 0.1, 784.0, 784.0, 0.3, "square"], [0.3, 0.25, 1046.0, 1046.0, 0.3, "square"]])
	_sounds["death"] = _make([[0.0, 0.25, 260.0, 60.0, 0.4, "square"], [0.0, 0.2, 0.0, 0.0, 0.2, "noise"]])
	_sounds["dash"] = _make([[0.0, 0.12, 300.0, 1200.0, 0.18, "noise"]])
	_sounds["slam"] = _make([[0.0, 0.3, 90.0, 40.0, 0.6, "sine"], [0.0, 0.25, 0.0, 0.0, 0.35, "noise"]])
	_sounds["break"] = _make([[0.0, 0.12, 0.0, 0.0, 0.4, "noise"], [0.0, 0.08, 180.0, 120.0, 0.3, "square"]])
	_sounds["boss"] = _make([[0.0, 0.4, 110.0, 110.0, 0.35, "square"], [0.4, 0.4, 98.0, 98.0, 0.35, "square"], [0.8, 0.6, 82.0, 82.0, 0.35, "square"]])
	_sounds["select"] = _make([[0.0, 0.05, 880.0, 880.0, 0.2, "square"]])


func play(name: String, pitch: float = 1.0) -> void:
	if Game.muted or not _sounds.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[name]
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()


# parts: [start, duration, freq_from, freq_to, volume, wave]
func _make(parts: Array) -> AudioStreamWAV:
	var total := 0.0
	for part in parts:
		total = max(total, part[0] + part[1])
	var n := int(total * RATE) + 1
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for part in parts:
		var start := int(part[0] * RATE)
		var length := int(part[1] * RATE)
		var phase := 0.0
		for i in length:
			var t := float(i) / maxf(1.0, float(length))
			var f: float = lerp(float(part[2]), float(part[3]), t)
			phase += f / RATE
			var s := 0.0
			match part[5]:
				"square":
					s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				"sine":
					s = sin(phase * TAU)
				"noise":
					s = rng.randf_range(-1.0, 1.0)
			var env: float = min(1.0, t * 20.0) * (1.0 - t)
			if start + i < n:
				buf[start + i] += s * env * float(part[4])
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clamp(buf[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
