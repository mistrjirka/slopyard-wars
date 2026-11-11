extends SceneTree
## Offline editing of chonkdonk's CC0 field recording; no synthetic hinge tones.
## Run: godot --headless --path . --script res://scripts/prepare_hinges.gd
const SOURCE := "res://assets/audio/sources/chonkdonk_619819_hinge.mp3"
const RATE := 44100
const DURATION := 1.15


func _initialize() -> void:
	var stream := AudioStreamMP3.new()
	stream.data = FileAccess.get_file_as_bytes(SOURCE)
	if stream.data.is_empty():
		push_error("Missing CC0 hinge source: " + SOURCE)
		quit(1)
		return
	var playback := stream.instantiate_playback()
	playback.start()
	var source_rate := int(AudioServer.get_mix_rate())
	var frames := PackedVector2Array()
	for block in ceili(stream.get_length() * source_rate / 4096.0) + 1:
		frames.append_array(playback.mix_audio(1.0, 4096))
	playback.stop()
	# Opening waits for the lateral shift; closing creaks during the initial rotation.
	write_hinge("hinge_open", frames, source_rate, 23.00, 1.00, 0.18, 0.87)
	write_hinge("hinge_close", frames, source_rate, 15.90, 0.80, 0.035, 0.85)
	print("Prepared two recorded hinge sounds, each ", DURATION, " seconds.")
	quit()


func write_hinge(name: String, frames: PackedVector2Array, source_rate: int,
		source_start: float, source_span: float, lead: float, movement: float) -> void:
	var samples := PackedFloat32Array()
	samples.resize(roundi(RATE * DURATION))
	var offset := roundi(lead * RATE)
	var count := roundi(movement * RATE)
	var highpass := exp(-TAU * 150.0 / RATE)
	var lowpass := 1.0 - exp(-TAU * 2800.0 / RATE)
	var previous := 0.0
	var high := 0.0
	var low := 0.0
	var peak := 0.0
	var energy := 0.0
	for index in count:
		var position := (source_start + float(index) / count * source_span) * source_rate
		var a := clampi(floori(position), 0, frames.size() - 2)
		var frame := frames[a].lerp(frames[a + 1], position - a)
		var mono := (frame.x + frame.y) * 0.5
		high = highpass * (high + mono - previous)
		previous = mono
		low += lowpass * (high - low)
		var time := float(index) / RATE
		var envelope := smoothstep(0.0, 0.025, time) * smoothstep(0.0, 0.08, movement - time)
		var value := low * envelope
		samples[offset + index] = value
		energy += value * value
	# Tame isolated door clicks so the quieter friction remains audible on a small phone.
	var limit := maxf(0.000001, sqrt(energy / samples.size()) * 3.5)
	for index in samples.size():
		samples[index] = tanh(samples[index] / limit) * limit
		peak = maxf(peak, absf(samples[index]))
	assert(peak > 0.00001, "Hinge excerpt is silent")
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)
	for index in samples.size():
		pcm.encode_s16(index * 2, roundi(samples[index] / peak * 0.56 * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = pcm
	var error := wav.save_to_wav("res://assets/audio/" + name + ".wav")
	assert(error == OK, "Could not write hinge excerpt")
