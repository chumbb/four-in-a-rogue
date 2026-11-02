class_name Sfx
extends RefCounted
## Placeholder sounds synthesized in code until real chiptune assets land
## (assets/ is still empty). Swap these for .wav/.ogg loads later.

const MIX_RATE := 22050


## Short descending square-wave "bonk" for invalid placement (§4.6).
static func error_buzz() -> AudioStreamWAV:
	return _square_sweep(260.0, 120.0, 0.16, 0.35)


## Soft click for a successful drop.
static func drop_click() -> AudioStreamWAV:
	return _square_sweep(520.0, 380.0, 0.05, 0.2)


static func _square_sweep(f_start: float, f_end: float, seconds: float, volume: float) -> AudioStreamWAV:
	var count := int(MIX_RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		var freq := lerpf(f_start, f_end, t)
		phase = fmod(phase + freq / MIX_RATE, 1.0)
		var envelope := 1.0 - t
		var sample := (1.0 if phase < 0.5 else -1.0) * volume * envelope
		data.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
