extends Control
## In-match presentation and local input. All mutations go through Game.act().
signal notice_requested(message: String)
signal leave_requested
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
@onready var _workspace: Control = $Workspace
@onready var _map_layer: Control = $MapLayer

var _move_t := 0.0
var _tracked := -1

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
	_phone.close_requested.connect(func(): _phone_layer.visible = false)
	_phone.track_requested.connect(func(id: int):
		_tracked = id
		_world.tracked = id
		_phone_layer.visible = false
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
	_workspace.visible = false
	_map_layer.visible = false
	# Pocketing hides the existing device; its fold state and current app stay intact.
	_phone_layer.visible = not _phone_layer.visible
	Game.act("move", {"direction": Vector2.ZERO})


func _toggle_map() -> void:
	if Game.state.phase != "playing":
		return
	_phone_layer.visible = false
	_workspace.visible = false
	_map_layer.visible = not _map_layer.visible
	if not _map_layer.visible:
		return
	K.clear(_meetings)
	for meeting: Dictionary in Game.active_meetings(Game.me()):
		var button: Button = MeetingButton.instantiate()
		_meetings.add_child(button)
		button.text = str(meeting.name) + " · " + str(meeting.label) + " · " + str(meeting.status)
		button.pressed.connect(_track_meeting.bind(int(meeting.listing_id)))


func _track_meeting(listing_id: int) -> void:
	_tracked = listing_id
	_world.tracked = listing_id
	_map_layer.hide()


func _open_workspace(which: String) -> void:
	var p: Dictionary = Game.me()
	if p.is_empty() or p.area != "home" or p.pos.distance_to(World.BENCH) > 58:
		notice_requested.emit("Walk up to the PC workbench inside your house first.")
		return
	_phone_layer.visible = false
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


func _process(delta: float) -> void:
	if Game.state.phase != "playing" or not is_instance_valid(_world) or Game.me().is_empty():
		return
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
	_context_label.text = hint
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


func _unhandled_key_input(event: InputEvent) -> void:
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
			_phone_layer.hide()
			_workspace.hide()
			_map_layer.hide()
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
