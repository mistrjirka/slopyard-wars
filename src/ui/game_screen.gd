extends Control
## In-match presentation and local input. All mutations go through Game.act().
signal notice_requested(message: String)
signal leave_requested
signal phone_pocketed
const PHONE_ENTER_SECONDS := 0.48
const PHONE_EXIT_SECONDS := 0.38
const K = preload("res://src/ui/ui_kit.gd")
const Config = preload("res://src/core/game_config.gd")
const Activities = preload("res://src/world/activities.gd")
const World = preload("res://src/world/world_rules.gd")
const Trade = preload("res://src/trading/trade_rules.gd")
const MeetingButton = preload("res://src/ui/map_meeting_button.tscn")
@onready var _phone: Control = $PhoneLayer/Center/Phone
@onready var _bench: Control = $Workspace/Work/Bench
@onready var _tune: Control = $Workspace/Work/Tune
@onready var _world: Control = $World
@onready var _clock_lbl: Label = $Topbar/Row/Clock
@onready var _cash_lbl: Label = $Topbar/Row/Cash
@onready var _context_label: Label = $Bottombar/Hints/Context
@onready var _appointment_label: Label = $Bottombar/Hints/Appointment
@onready var _phone_layer: Control = $PhoneLayer
@onready var _phone_center: Control = $PhoneLayer/Center
@onready var _phone_shade: ColorRect = $PhoneLayer/Shade
@onready var _workspace: Control = $Workspace
@onready var _map_layer: Control = $MapLayer
@onready var _world_hud: Control = $WorldHud
@onready var _minimap: Control = $WorldHud/Minimap
@onready var _mini_map_view: Control = $WorldHud/Minimap/Box/Map

var _move_t := 0.0
var _tracked := -1
var _phone_motion := "hidden"
var _phone_wanted := false
var _phone_reopen_unfolded := false
var _phone_slide := 1.0
var _phone_tween: Tween
var _phone_reveal_generation := 0
var _after_phone_pocket := Callable()
var _feedback_message := ""
var _feedback_remaining := 0.0

@onready var _dialogs: Control = $Dialogs
@onready var _meetings: VBoxContainer = $MapLayer/Scroll/Content/Meetings


func _ready() -> void:
	_dialogs.notice_requested.connect(func(message: String): notice_requested.emit(message))
	_phone_layer.visible = false
	_workspace.visible = false
	_map_layer.visible = false
	($Topbar/Row/PhoneBtn as Button).pressed.connect(_toggle_phone)
	($Topbar/Row/MapBtn as Button).pressed.connect(_toggle_map)
	($Topbar/Row/MenuBtn as Button).pressed.connect(func(): _dialogs.ask("Leave match?", "This unfinished run is not saved.", "Leave", func(): leave_requested.emit()))
	$Workspace/Work/BackBtn.pressed.connect(func(): _workspace.visible = false)
	$MapLayer/Scroll/Content/Header/Close.pressed.connect(func(): _map_layer.hide())
	_phone.close_requested.connect(_close_phone)
	_phone.fold_finished.connect(_on_phone_fold_finished)
	resized.connect(func(): _set_phone_slide(_phone_slide))
	_phone.track_requested.connect(func(id: int):
		_tracked = id
		_world.tracked = id
		_mini_map_view.tracked = id
		_close_phone()
		notice_requested.emit("Meeting tracked. M shows the whole town; follow the yellow marker. Park and E at the contact."))
	_phone_layer.visible = false
	_bench.ask = _dialogs.ask
	_bench.install_requested.connect(_dialogs.open_assembly)
	_bench.go_market.connect(_toggle_phone)
	_bench.go_tuning.connect(func(): _open_workspace("tune"))
	_tune.ask = _dialogs.ask
	_workspace.visible = false
	_update_world_hud()

func _overlay_open() -> bool:
	return _dialogs.visible or _phone_layer.visible or _workspace.visible or _map_layer.visible


func _toggle_phone() -> void:
	if Game.state.phase != "playing":
		return
	if _phone_wanted:
		_close_phone()
		return
	_phone_wanted = true
	_after_phone_pocket = Callable()
	_workspace.visible = false
	_map_layer.visible = false
	# Finish pocketing before honoring a rapid request to take it out again.
	if _phone_motion == "hidden":
		_open_phone()
	Game.act("move", {"direction": Vector2.ZERO})


func _open_phone() -> void:
	_phone_reveal_generation += 1
	_phone_motion = "opening"
	_phone.set_unfolded(false)
	_phone.set_pocket_transition(true)
	_set_phone_slide(1.0)
	_phone_layer.show()
	_phone.refresh()
	_start_phone_entry(_phone_reveal_generation)


func _start_phone_entry(generation: int) -> void:
	# Render the cover while it is below the screen, before the slide reveals it.
	await _phone.prepare_for_reveal()
	if generation != _phone_reveal_generation or _phone_motion != "opening":
		return
	_phone_tween = create_tween()
	_phone_tween.tween_method(_set_phone_slide, 1.0, 0.0, PHONE_ENTER_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_phone_tween.finished.connect(func():
		_phone_motion = "open"
		_phone.set_pocket_transition(false)
		if _phone_reopen_unfolded:
			_phone.set_unfolded_animated(true))


func _close_phone(after: Callable = Callable()) -> void:
	_phone_reveal_generation += 1
	_phone_wanted = false
	_after_phone_pocket = after
	if _phone_motion == "hidden":
		if after.is_valid():
			after.call_deferred()
		return
	if _phone_motion in ["closing_fold", "closing_slide"]:
		return
	# Entry temporarily shows the cover; interrupting it must retain the saved mode.
	# Otherwise remember the player's mode before the fold-to-pocket animation.
	if _phone_motion != "opening":
		_phone_reopen_unfolded = _phone.unfolded
	if _phone_tween != null and _phone_tween.is_valid():
		_phone_tween.kill()
	_phone.set_pocket_transition(true)
	_phone_motion = "closing_fold"
	_advance_phone_close()


func _on_phone_fold_finished() -> void:
	# Defer so an interrupted fold can finish changing state before we inspect it.
	if _phone_motion == "closing_fold":
		_advance_phone_close.call_deferred()


func _advance_phone_close() -> void:
	if _phone_motion != "closing_fold" or _phone.is_folding():
		return
	if _phone.unfolded:
		_phone.set_unfolded_animated(false)
		if _phone.is_folding():
			return
	_phone_motion = "closing_slide"
	_phone_tween = create_tween()
	_phone_tween.tween_method(_set_phone_slide, _phone_slide, 1.0, PHONE_EXIT_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_phone_tween.finished.connect(_finish_phone_pocket)


func _finish_phone_pocket() -> void:
	_phone_layer.hide()
	_phone.set_pocket_transition(false)
	_phone_motion = "hidden"
	var after := _after_phone_pocket
	_after_phone_pocket = Callable()
	phone_pocketed.emit()
	if _phone_wanted:
		_open_phone()
	elif after.is_valid():
		after.call_deferred()


func _set_phone_slide(value: float) -> void:
	_phone_slide = value
	_phone_center.position.y = size.y * value
	_phone_shade.modulate.a = 1.0 - value


func _toggle_map() -> void:
	if Game.state.phase != "playing":
		return
	if _phone_layer.visible:
		_close_phone(_toggle_map)
		return
	_workspace.visible = false
	_map_layer.visible = not _map_layer.visible
	if not _map_layer.visible:
		return
	$MapLayer/Scroll/Content/Map.tracked = _tracked
	K.clear(_meetings)
	var meetings: Array = Game.active_meetings(Game.me())
	meetings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.start) < float(b.start) if float(a.start) != float(b.start) else int(a.listing_id) < int(b.listing_id))
	for meeting: Dictionary in meetings:
		var button: Button = MeetingButton.instantiate()
		_meetings.add_child(button)
		button.text = "Track: %s · %s · %s" % [meeting.contact, meeting.name, Trade.stamp(float(meeting.start))]
		if meeting.status == "missed":
			button.text += " (missed)"
		button.clip_text = true
		button.tooltip_text = str(meeting.label)
		button.pressed.connect(_track_meeting.bind(int(meeting.listing_id)))


func _track_meeting(listing_id: int) -> void:
	_tracked = listing_id
	_world.tracked = listing_id
	_mini_map_view.tracked = listing_id
	_map_layer.hide()


func _open_workspace(which: String) -> void:
	var p: Dictionary = Game.me()
	if p.is_empty() or p.area != "home" or p.pos.distance_to(World.BENCH) > 58:
		notice_requested.emit("Walk up to the PC workbench inside your house first.")
		return
	if _phone_layer.visible:
		_close_phone(_open_workspace.bind(which))
		return
	_map_layer.visible = false
	_workspace.visible = true
	_bench.visible = which == "bench"
	_tune.visible = which == "tune"
	if which == "bench":
		_bench.refresh()
	else:
		_tune.refresh()


func refresh() -> void:
	if not is_instance_valid(_world):
		return
	if _phone_layer.visible:
		_phone.refresh()
	if _workspace.visible:
		if _bench.visible:
			_bench.refresh()
		if _tune.visible:
			_tune.refresh()
	_update_world_hud()


func show_notice(message: String) -> void:
	_feedback_message = message
	_feedback_remaining = 5.5
	_update_world_hud()


func _process(delta: float) -> void:
	if Game.state.phase != "playing" or not is_instance_valid(_world) or Game.me().is_empty():
		return
	_feedback_remaining = maxf(0.0, _feedback_remaining - delta)
	_move_t += delta
	if _move_t >= 0.10:
		_move_t = 0
		var input := Vector2.ZERO
		if not _overlay_open() and not Game.me().ready:
			input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		Game.act("move", {"direction": input})
	_update_world_hud()
	if _workspace.visible:
		if _bench.visible:
			_bench.tick()
		if _tune.visible:
			_tune.tick(delta)


func _update_world_hud() -> void:
	if not is_instance_valid(_clock_lbl) or Game.me().is_empty():
		return
	var p: Dictionary = Game.me()
	var unread: int = _phone.unread_count()
	$Topbar/Row/PhoneBtn.text = "PHONE [P] · %d" % unread if unread > 0 else "PHONE [P]"
	$Topbar/Row/PhoneBtn.tooltip_text = "%d unread messages" % unread if unread > 0 else "Open your phone"
	_world_hud.visible = not _overlay_open()
	_minimap.visible = p.area == "town"
	_clock_lbl.text = Trade.stamp(Game.clock()) + " · ~" + K.real_left(Game.state.remaining) + " left"
	_cash_lbl.text = "$%d" % int(p.cash)
	var hint := "Home · E at the door to go outside. Walk to the PC desk for B: assembly / T: tuning."
	if p.area == "town":
		hint = "Driving · WASD / arrows. E parks and gets out. Fuel costs $3 each time you start the car." if p.driving else "Town · E by your car to drive, by home to go inside, or by a scheduled contact to trade."
	var nearby := Activities.nearby(p)
	if nearby != null:
		hint = "E: " + nearby.display_name + " · " + Activities.cost_text(nearby)
	if p.ready:
		hint = "Rig locked. Waiting for the other builders or the deadline."
	_context_label.text = _feedback_message if _feedback_remaining > 0.0 else hint
	_context_label.add_theme_color_override("font_color", K.ORANGE if _feedback_remaining > 0.0 else K.CREAM)
	var meetings: Array = Game.active_meetings(p)
	var line := "Tonight's deadline: " + Trade.stamp(Config.DEADLINE) + " · " + str(Game.state.objective) + " objective · P opens your phone."
	if not meetings.is_empty():
		var m: Dictionary = meetings[0]
		for candidate: Dictionary in meetings:
			if int(candidate.listing_id) == _tracked:
				m = candidate
		line = str(m.contact) + " · " + str(m.label) + " · " + str(m.status).to_upper() + " · Space waits in solo; missed? message to reschedule."
	if float(Game.state.remaining) <= Config.BUILD_REMINDER_MINUTES and not p.ready:
		line = "BUILD TIME · " + line + " · Leave time to return home, assemble and test."
	_appointment_label.text = line


func _input(event: InputEvent) -> void:
	if _dialogs.visible or not _phone_layer.visible or event is not InputEventKey or not event.pressed:
		return
	if event.is_action_pressed("ui_focus_next", true) or event.is_action_pressed("ui_focus_prev", true):
		# Keep focus traversal inside the phone's separate GUI viewport instead
		# of letting the host GUI select controls behind the overlay.
		_phone.move_keyboard_focus(event.is_action_pressed("ui_focus_prev", true))
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# SubViewportContainer forwards keys in unhandled_input. Running game shortcuts
	# in the earlier unhandled_key_input stage steals letters from phone text fields.
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if _dialogs.visible:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	var editing_here := focus_owner is LineEdit or focus_owner is TextEdit
	if event.is_action_pressed("ui_cancel"):
		if _phone_layer.visible and _phone.release_text_focus():
			pass # First Escape leaves text editing; another pockets the phone.
		elif editing_here:
			focus_owner.release_focus()
		else:
			_close_phone()
			_workspace.hide()
			_map_layer.hide()
	elif _phone_layer.visible and (event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev")):
		pass # Tab navigates the open phone; it must not also pocket it.
	elif editing_here or _phone.has_text_focus():
		# Child SubViewport GUI handling does not consume the host's shortcuts.
		return
	elif event.is_action_pressed("phone"):
		_toggle_phone()
	elif event.is_action_pressed("town_map"):
		_toggle_map()
	elif event.is_action_pressed("workbench"):
		_open_workspace("bench")
	elif event.is_action_pressed("tuning"):
		_open_workspace("tune")
	elif event.is_action_pressed("interact") and not _overlay_open():
		if Game.me().area == "home" and Game.me().pos.distance_to(World.BENCH) < 50:
			_open_workspace("bench")
		elif Activities.nearby(Game.me()) != null:
			_dialogs.open_activity(Activities.nearby(Game.me()))
		else:
			Game.act("interact")
	elif event.is_action_pressed("wait") and not _overlay_open():
		Game.act("wait")
	else:
		return
	get_viewport().set_input_as_handled()
