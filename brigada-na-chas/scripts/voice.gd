extends Node
signal packet_ready(data: PackedByteArray)
var capture: AudioEffectCapture
var microphone: AudioStreamPlayer
var outputs: Dictionary = {}
var talking = false
var active = false
var remainder = 0.0
var pending = PackedByteArray()
const RATE = 16000.0
const CHUNK = 640

func start_input() -> void:
	if active or DisplayServer.get_name() == "headless":
		return
	active = true
	AudioServer.add_bus()
	var idx = AudioServer.bus_count-1
	AudioServer.set_bus_name(idx,"VoiceInput")
	capture = AudioEffectCapture.new()
	capture.buffer_length = 0.2
	AudioServer.add_bus_effect(idx,capture)
	AudioServer.set_bus_mute(idx,true)
	microphone = AudioStreamPlayer.new()
	microphone.bus = "VoiceInput"
	microphone.stream = AudioStreamMicrophone.new()
	add_child(microphone)

func _process(_dt: float) -> void:
	if not active:
		return
	if not talking:
		if microphone.playing:
			microphone.stop()
		capture.clear_buffer()
		pending.clear()
		return
	if not microphone.playing:
		microphone.play()
	var frames = capture.get_buffer(capture.get_frames_available())
	var ratio = RATE / AudioServer.get_mix_rate()
	for sample in frames:
		remainder += ratio
		if remainder >= 1.0:
			remainder -= 1.0
			var value = clampi(int((sample.x+sample.y)*0.5*32767),-32768,32767)
			pending.append(value & 255)
			pending.append((value >> 8) & 255)
		if pending.size() >= CHUNK:
			packet_ready.emit(pending)
			pending = PackedByteArray()

func receive(id: int, data: PackedByteArray) -> void:
	if data.size() != CHUNK or DisplayServer.get_name() == "headless":
		return
	if not outputs.has(id):
		var speaker = AudioStreamPlayer.new()
		var stream = AudioStreamGenerator.new()
		stream.mix_rate = RATE
		stream.buffer_length = 0.15
		speaker.stream = stream
		add_child(speaker)
		speaker.play()
		outputs[id] = speaker
	var playback: AudioStreamGeneratorPlayback = outputs[id].get_stream_playback()
	var count = data.size()/2
	if playback.get_frames_available() < count:
		playback.clear_buffer()
	for i in range(0,data.size(),2):
		var value = int(data[i]) | (int(data[i+1])<<8)
		if value >= 32768:
			value -= 65536
		var sample = float(value)/32768.0
		playback.push_frame(Vector2(sample,sample))

func remove_peer(id: int) -> void:
	if outputs.has(id):
		outputs[id].queue_free()
		outputs.erase(id)
