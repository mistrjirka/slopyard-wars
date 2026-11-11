extends Node
## Local presentation only. Observes the recipient's state, including LAN snapshots.
signal cue_played(cue: String, voice: int)
signal settings_changed
const SettingsScene = preload("res://src/audio/audio_settings.tscn")
const MUSIC = preload("res://assets/audio/slopyard_afterhours.wav")
const ENGINE = preload("res://assets/audio/engine_loop.wav")
const CUES := {
	"ui_click": preload("res://assets/audio/ui_click.wav"),
	"feedback": preload("res://assets/audio/feedback.wav"),
	"screen_crack": preload("res://assets/audio/screen_crack.wav"),
	"hinge_open": preload("res://assets/audio/hinge_open.wav"),
	"hinge_close": preload("res://assets/audio/hinge_close.wav"),
	"phone_out": preload("res://assets/audio/phone_out.wav"),
	"phone_away": preload("res://assets/audio/phone_away.wav"),
	"step_a": preload("res://assets/audio/step_a.wav"),
	"step_b": preload("res://assets/audio/step_b.wav"),
	"door": preload("res://assets/audio/door.wav"),
	"snap": preload("res://assets/audio/snap.wav"),
	"screw": preload("res://assets/audio/screw.wav"),
	"paste": preload("res://assets/audio/paste.wav"),
	"damage": preload("res://assets/audio/damage.wav"),
	"failure": preload("res://assets/audio/failure.wav"),
	"car_start": preload("res://assets/audio/car_start.wav"),
	"message": preload("res://assets/audio/message.wav"),
	"send": preload("res://assets/audio/send.wav"),
	"cash": preload("res://assets/audio/cash.wav"),
	"activity": preload("res://assets/audio/activity.wav"),
	"success": preload("res://assets/audio/success.wav"),
	"match_end": preload("res://assets/audio/match_end.wav"),
}
const GAINS := {"ui_click": -15.0, "feedback": -14.0, "screen_crack": -3.0,
	"hinge_open": -11.0, "hinge_close": -11.0, "phone_out": -14.0, "phone_away": -14.0,
	"step_a": -21.0, "step_b": -21.0, "door": -13.0, "snap": -15.0, "screw": -21.0,
	"paste": -20.0, "damage": -10.0, "failure": -7.0, "car_start": -15.0,
	"message": -15.0, "send": -17.0, "cash": -12.0, "activity": -16.0,
	"success": -16.0, "match_end": -13.0}
var settings_path := "user://audio.cfg"
var volumes := {"Master": 0.8, "Music": 0.65, "Effects": 0.8}
var muted := false
var playback_enabled := true
var _voices: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _engine: AudioStreamPlayer
var _music_fade: Tween
var _panel: Control
var _canvas: CanvasLayer
var _serial := 0
var _last_played := {}
var _previous := {}
var _match := -1
var _phase := ""
var _position := Vector2.ZERO
var _stride := 0.0
var _left_step := false
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	playback_enabled = DisplayServer.get_name() != "headless"
	_random.randomize() # Never consume the simulation's random generator.
	for bus in ["Music", "Effects"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	load_settings()
	for index in 16:
		var player := AudioStreamPlayer.new()
		player.bus = "Effects"
		add_child(player)
		_voices.append(player)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.stream = _loop(MUSIC)
	add_child(_music)
	_engine = AudioStreamPlayer.new()
	_engine.bus = "Effects"
	_engine.stream = _loop(ENGINE)
	_engine.volume_db = -60.0
	add_child(_engine)
	_canvas = CanvasLayer.new()
	_canvas.layer = 100
	add_child(_canvas)
	get_tree().node_added.connect(_on_node_added)
	Game.changed.connect(_observe_state)
	Game.notice.connect(func(_message: String): play("feedback"))
	_observe_state()


func _loop(source: AudioStreamWAV) -> AudioStreamWAV:
	var stream := source.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	return stream


func play(cue: String, gain_db: float = 0.0, pitch: float = 1.0) -> int:
	if not CUES.has(cue):
		return -1
	var now := Time.get_ticks_msec()
	var gap := 140 if cue == "message" or cue == "feedback" else (110 if cue == "screw" else 35)
	if now - int(_last_played.get(cue, -10000)) < gap:
		return -1
	_last_played[cue] = now
	_serial += 1
	var voice := _serial
	cue_played.emit(cue, voice)
	if not playback_enabled:
		return voice
	var selected: AudioStreamPlayer = _voices[0]
	for player: AudioStreamPlayer in _voices:
		if not player.playing:
			selected = player
			break
		if int(player.get_meta("voice", 0)) < int(selected.get_meta("voice", 0)):
			selected = player
	selected.stop()
	selected.stream = CUES[cue]
	selected.volume_db = float(GAINS.get(cue, -12.0)) + gain_db
	selected.pitch_scale = clampf(pitch, 0.5, 2.0)
	selected.set_meta("voice", voice)
	selected.play()
	return voice


func stop_voice(voice: int) -> void:
	for player: AudioStreamPlayer in _voices:
		if int(player.get_meta("voice", -1)) == voice:
			player.stop()
			player.remove_meta("voice")


func start_music() -> void:
	if not playback_enabled or _music.playing:
		return
	_music.volume_db = -60.0
	_music.play()
	_music_fade = create_tween()
	_music_fade.tween_property(_music, "volume_db", -8.0, 1.5)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_bind_button.call_deferred(weakref(node))


func _bind_button(reference: WeakRef) -> void:
	var button := reference.get_ref() as BaseButton
	if is_instance_valid(button) and button.is_inside_tree():
		button.pressed.connect(func(): play("ui_click"))


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		for bus: String in volumes:
			var value: Variant = config.get_value("volume", bus, volumes[bus])
			if (value is float or value is int) and is_finite(float(value)):
				volumes[bus] = clampf(float(value), 0.0, 1.0)
		muted = bool(config.get_value("volume", "muted", false))
	_apply_volumes()


func save_settings() -> void:
	var config := ConfigFile.new()
	for bus: String in volumes:
		config.set_value("volume", bus, volumes[bus])
	config.set_value("volume", "muted", muted)
	config.save(settings_path)


func set_volume(bus: String, value: float) -> void:
	if not volumes.has(bus) or not is_finite(value):
		return
	volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volumes()
	settings_changed.emit()


func set_muted(value: bool) -> void:
	muted = value
	_apply_volumes()
	settings_changed.emit()


func _apply_volumes() -> void:
	for bus: String in volumes:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, float(volumes[bus]))))
		AudioServer.set_bus_mute(index, float(volumes[bus]) <= 0.0 or (bus == "Master" and muted))


func open_settings() -> void:
	if not is_instance_valid(_panel):
		_panel = SettingsScene.instantiate()
		_canvas.add_child(_panel)
	_panel.sync()
	_panel.show()
	_panel.focus_volume()


func is_settings_open() -> bool:
	return is_instance_valid(_panel) and _panel.visible


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and is_settings_open():
		_panel.hide()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		set_muted(not muted)
		save_settings()
		get_viewport().set_input_as_handled()


func _snapshot(player: Dictionary) -> Dictionary:
	var incoming := 0
	var outgoing := 0
	for messages: Array in player.get("chats", {}).values():
		for message: Dictionary in messages:
			if message.get("pending", false) or message.get("speaker", "") == "system":
				continue
			if message.speaker == player.name:
				outgoing = maxi(outgoing, int(message.get("id", 0)))
			else:
				incoming = maxi(incoming, int(message.get("id", 0)))
	var installed := {}
	for category: String in player.installed:
		installed[category] = player.installed[category].id
	return {"area": player.area, "driving": player.driving, "cash": player.cash,
		"busy": float(player.busy),
		"inventory": player.inventory.size(), "installed": installed, "destroyed": player.destroyed.size(),
		"stress": player.get("last_stress_test", {}).duplicate(true),
		"visits": str(player.get("world_visits", {})), "lucky": player.get("lucky_messages", []).size(),
		"incoming": incoming, "outgoing": outgoing}


func _observe_state() -> void:
	var phase := str(Game.state.get("phase", "menu"))
	var match_id := int(Game.state.get("match_id", 0))
	var player: Dictionary = Game.me()
	if phase != _phase or match_id != _match:
		if phase == "playing":
			play("success")
		elif phase == "results":
			play("match_end")
		_phase = phase
		_match = match_id
		_previous = _snapshot(player) if not player.is_empty() else {}
		_position = player.get("pos", Vector2.ZERO)
		_stride = 0.0
		return
	if phase != "playing" or player.is_empty():
		return
	var next := _snapshot(player)
	if _previous.is_empty():
		_previous = next
		return
	if next.area != _previous.area:
		play("door")
		_position = player.pos
		_stride = 0.0
	if next.driving != _previous.driving:
		play("car_start" if next.driving else "door")
		_position = player.pos
		_stride = 0.0
	var cue := ""
	if int(next.destroyed) > int(_previous.destroyed):
		cue = "failure"
	elif not next.stress.is_empty() and (next.stress != _previous.stress or
			(next.busy > _previous.busy + 1.0 and next.visits == _previous.visits)):
		cue = "failure" if next.stress.get("destroyed", false) else "success"
	elif next.installed != _previous.installed:
		cue = "success" if next.installed.size() > _previous.installed.size() else "snap"
	elif next.visits != _previous.visits:
		cue = "activity"
	elif next.inventory != _previous.inventory and next.cash != _previous.cash:
		cue = "cash"
	elif next.incoming > _previous.incoming or next.lucky > _previous.lucky:
		cue = "message"
	elif next.outgoing > _previous.outgoing:
		cue = "send"
	if not cue.is_empty():
		play(cue)
	_previous = next


func _process(delta: float) -> void:
	if not playback_enabled:
		return
	var player: Dictionary = Game.me()
	var active: bool = Game.state.get("phase") == "playing" and not player.is_empty()
	var driving: bool = active and bool(player.driving)
	if driving and not _engine.playing:
		_engine.play()
	_engine.volume_db = lerpf(_engine.volume_db, -26.0 if driving else -65.0, minf(1.0, delta * 5.0))
	if not driving and _engine.volume_db < -60.0:
		_engine.stop()
	if not active:
		return
	var distance := _position.distance_to(player.pos)
	_position = player.pos
	if driving:
		_engine.pitch_scale = lerpf(_engine.pitch_scale, 1.25 if distance > 0.1 else 0.85, minf(1.0, delta * 3.0))
	elif distance < 30.0:
		_stride += distance
		if _stride >= 28.0:
			_stride = fmod(_stride, 28.0)
			_left_step = not _left_step
			play("step_a" if _left_step else "step_b", 0.0, _random.randf_range(0.94, 1.06))
