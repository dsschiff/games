extends RefCounted
## Short original brass/pluck tones, cached once per frequency.
var cache: Dictionary = {}

func tone(frequency: float) -> AudioStreamWAV:
	var key := int(frequency)
	if cache.has(key):
		return cache[key]
	var data := PackedByteArray()
	data.resize(5292)
	for i in 2646:
		var t := float(i) / 22050.0
		var envelope := pow(1.0 - float(i) / 2646.0, 2) * minf(1.0, i / 80.0)
		var brass := sin(t * frequency * TAU) + sin(t * frequency * 2 * TAU) * 0.22 + sin(t * frequency * 3 * TAU) * 0.1
		data.encode_s16(i * 2, int(brass * envelope * 2800))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	cache[key] = stream
	return stream
