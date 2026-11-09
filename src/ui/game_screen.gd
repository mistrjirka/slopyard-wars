extends Control
## In-match presentation and local input. All mutations go through Game.act().
signal notice_requested(message: String)
signal leave_requested
const K = preload("res://src/ui/ui_kit.gd")
const Phone = preload("res://src/trading/phone.gd")
const Activities = preload("res://src/world/activities.gd")
const World = preload("res://src/world/world_rules.gd")
const Trade = preload("res://src/trading/trade_rules.gd")
const TownMap = preload("res://src/world/town_map.gd")
const BenchView = preload("res://src/workshop/bench_view.gd")
const TuneView = preload("res://src/workshop/tune_view.gd")
const DialogLayer = preload("res://src/ui/dialog_layer.gd")
var _world: Control
var _phone: Control
var _phone_layer: Control
var _workspace: Control
var _map_layer: Control
var _bench: Control
var _tune: Control
var _context_label: Label
var _appointment_label: Label
var _move_t := 0.0
var _tracked := -1

var _clock_lbl: Label
var _cash_lbl: Label
var _dialogs: Control


func _ready() -> void:
	var root: Control = self
	_dialogs = DialogLayer.new()
	_dialogs.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialogs.visible = false
	_dialogs.notice_requested.connect(func(message: String): notice_requested.emit(message))
	_world = preload("res://src/world/town_view.tscn").instantiate()
	_world.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_world)
	var top := K.panel("Topbar")
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var row := K.hbox(18)
	row.add_child(K.lbl("SLOPYARD / TOWN", "H2", K.LIME))
	_clock_lbl = K.lbl("", "Big")
	row.add_child(_clock_lbl)
	_cash_lbl = K.lbl("", "Big", K.LIME)
	row.add_child(_cash_lbl)
	row.add_child(K.spacer())
	row.add_child(K.btn("PHONE [P]", "PrimaryButton", _toggle_phone))
	row.add_child(K.btn("MAP [M]", "", _toggle_map))
	row.add_child(K.btn("MENU", "GhostButton", func(): _dialogs.ask("Leave match?", "This unfinished run is not saved.", "Leave", func(): leave_requested.emit())))
	top.add_child(row)
	root.add_child(top)
	var bottom := K.panel("Topbar")
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_top = -90
	var hints := K.vbox(4)
	_context_label = K.lbl("", "Mono", K.CREAM, true)
	hints.add_child(_context_label)
	_appointment_label = K.lbl("", "Tiny", K.SKY, true)
	hints.add_child(_appointment_label)
	hints.add_child(K.lbl("WASD / arrows: move  ·  E: door / car / handoff  ·  E at town attractions  ·  P: phone  ·  M: map  ·  B/T: home workbench  ·  Space: wait (solo)", "Tiny", K.MUTED, true))
	bottom.add_child(hints)
	root.add_child(bottom)
	_phone_layer = Control.new()
	_phone_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_phone_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.09, 0.50)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_phone_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_phone_layer.add_child(center)
	_phone = Phone.new()
	center.add_child(_phone)
	_phone.close_requested.connect(func(): _phone_layer.visible = false)
	_phone.track_requested.connect(func(id: int):
		_tracked = id
		_world.tracked = id
		_phone_layer.visible = false
		notice_requested.emit("Meeting tracked. M shows the whole town; follow the yellow marker. Park and E at the contact."))
	_phone_layer.visible = false
	_workspace = K.panel("Card")
	_workspace.set_anchors_preset(Control.PRESET_FULL_RECT)
	_workspace.offset_left = 24
	_workspace.offset_right = -24
	_workspace.offset_top = 80
	_workspace.offset_bottom = -100
	root.add_child(_workspace)
	var work := K.vbox(8)
	_workspace.add_child(work)
	work.add_child(K.btn("BACK TO ROOM [Esc]", "GhostButton", func(): _workspace.visible = false))
	_bench = BenchView.new()
	_bench.ask = _dialogs.ask
	_bench.install_requested.connect(_dialogs.open_assembly)
	_bench.go_market.connect(_toggle_phone)
	_bench.go_tuning.connect(func(): _open_workspace("tune"))
	work.add_child(_bench)
	_tune = TuneView.new()
	_tune.ask = _dialogs.ask
	work.add_child(_tune)
	_workspace.visible = false
	_map_layer = K.panel("Card")
	_map_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_layer.offset_left = 80
	_map_layer.offset_right = -80
	_map_layer.offset_top = 90
	_map_layer.offset_bottom = -110
	root.add_child(_map_layer)
	_map_layer.visible = false
	add_child(_dialogs)
	_update_world_hud()


func _overlay_open() -> bool:
	return _dialogs.visible or _phone_layer.visible or _workspace.visible or _map_layer.visible


func _toggle_phone() -> void:
	if Game.state.phase != "playing":
		return
	_workspace.visible = false
	_map_layer.visible = false
	_phone_layer.visible = not _phone_layer.visible
	if _phone_layer.visible:
		_phone.refresh()
	Game.act("move", {"direction": Vector2.ZERO})


func _toggle_map() -> void:
	if Game.state.phase != "playing":
		return
	_phone_layer.visible = false
	_workspace.visible = false
	_map_layer.visible = not _map_layer.visible
	if not _map_layer.visible:
		return
	K.clear(_map_layer)
	var scroll := K.scroll()
	_map_layer.add_child(scroll)
	var box := K.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var header := K.hbox(8)
	header.add_child(K.lbl("SLOPYARD TOWN · MEETING PLACES", "H2"))
	header.add_child(K.spacer())
	header.add_child(K.btn("Close [M/Esc]", "GhostButton", func(): _map_layer.visible = false))
	box.add_child(header)
	var map: Control = TownMap.new()
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.custom_minimum_size.y = 400
	box.add_child(map)
	box.add_child(K.lbl("Home: center of town. Meeting signs: harbor southwest, scrapyard northwest, Grease Alley north-center, mill northeast, suburbs east, dorms south, storage far east. The yellow world marker tracks your selected appointment.", "Muted", null, true))
	for m: Dictionary in Game.active_meetings(Game.me()):
		box.add_child(K.btn(str(m.name) + " · " + str(m.label) + " · " + str(m.status), "", func(): _tracked = int(m.listing_id); _world.tracked = _tracked; _map_layer.visible = false))


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
	_clock_lbl.text = Trade.stamp(Game.clock())
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
	var line := "Three-day deadline: " + Trade.stamp(Trade.START + 4320) + " · " + str(Game.state.objective) + " objective · P opens your phone."
	if not meetings.is_empty():
		var m: Dictionary = meetings[0]
		for candidate: Dictionary in meetings:
			if int(candidate.listing_id) == _tracked:
				m = candidate
		line = str(m.contact) + " · " + str(m.label) + " · " + str(m.status).to_upper() + " · Space waits in solo; missed? message to reschedule."
	_appointment_label.text = line


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if _dialogs.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_phone_layer.hide()
		_workspace.hide()
		_map_layer.hide()
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
