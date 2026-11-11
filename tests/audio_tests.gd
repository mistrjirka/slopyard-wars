extends RefCounted
## Resource validity, independent volume controls and recipient-only gameplay cues.


func run(game: Node, check: Callable) -> void:
	var sound: Node = game.get_tree().root.get_node("Sound")
	for cue: String in sound.CUES:
		var stream: AudioStreamWAV = sound.CUES[cue]
		check.call(not stream.data.is_empty() and stream.get_length() > 0.04, "Audio asset loads: " + cue)
	check.call(is_equal_approx(sound.CUES.hinge_open.get_length(), 1.15) and is_equal_approx(sound.CUES.hinge_close.get_length(), 1.15),
		"Hinge sounds match the normal folding animation duration")
	check.call(sound._music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and is_equal_approx(sound._music.stream.get_length(), 48.0),
		"Original background music is a looping 48-second stereo stream")
	check.call(sound._music.stream.stereo, "Background music preserves its stereo mix")
	var previous_path: String = sound.settings_path
	var previous_volumes: Dictionary = sound.volumes.duplicate()
	var previous_muted: bool = sound.muted
	sound.settings_path = "res://artifacts/test_audio.cfg"
	sound.set_volume("Music", 0.23)
	sound.set_volume("Effects", 0.61)
	sound.set_muted(true)
	sound.save_settings()
	sound.set_volume("Music", 0.9)
	sound.set_muted(false)
	sound.load_settings()
	check.call(is_equal_approx(sound.volumes.Music, 0.23) and is_equal_approx(sound.volumes.Effects, 0.61) and sound.muted,
		"Audio settings persist independently from game scores and simulation")
	check.call(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "Master mute silences both music and effects")
	sound.set_muted(false)
	sound.set_volume("Music", 0.0)
	check.call(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")),
		"Music can be silenced while effects remain enabled")
	sound.settings_path = previous_path
	for bus: String in previous_volumes:
		sound.set_volume(bus, previous_volumes[bus])
	sound.set_muted(previous_muted)
	game.solo("Sound Test", 1000, "Balanced")
	game.set_process(false)
	game.set_physics_process(false)
	game.changed.emit()
	var cues: Array[String] = []
	var listener := func(cue: String, _voice: int): cues.append(cue)
	sound.cue_played.connect(listener)
	var player: Dictionary = game.me()
	player.area = "town"
	game.changed.emit()
	check.call(cues.has("door"), "Entering town produces a door effect")
	cues.clear()
	player.driving = true
	game.changed.emit()
	check.call(cues.has("car_start"), "Entering the car starts its engine sound")
	cues.clear()
	game.text_player(game.local_id(), "An incoming Lucky text.")
	game.changed.emit()
	check.call(cues.has("message"), "Incoming Lucky texts produce a phone notification")
	cues.clear()
	# Another player's private updates must never play on this device.
	game.state.players[2] = preload("res://src/core/state_factory.gd").player("Remote")
	game.text_player(2, "Only the other player should hear this.")
	game.changed.emit()
	check.call(cues.is_empty(), "Other players' private messages do not produce local sounds")
	player.inventory.append({"id": 50000})
	player.cash -= 20
	game.changed.emit()
	check.call(cues.has("cash"), "A completed trade produces its cash effect")
	cues.clear()
	player.destroyed.append("A failed test part")
	game.changed.emit()
	check.call(cues.has("failure"), "A destroyed part produces a failure effect")
	check.call(sound.play("missing_sound") == -1, "Unknown cues cannot allocate voices")
	sound.cue_played.disconnect(listener)
