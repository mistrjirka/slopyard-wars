extends Control
## Slopyard Wars shell: menu, lobby, walkable world, phone and home workbench, results. All state changes go through Game.act().
const K = preload("res://scripts/ui_kit.gd")
const PartArt = preload("res://scripts/part_art.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Phone = preload("res://scripts/phone.gd")
const TownView = preload("res://scripts/town_view.gd")
const World = preload("res://scripts/world_rules.gd")
const Trade = preload("res://scripts/trade_rules.gd")
const TownMap = preload("res://scripts/town_map.gd")
const BenchView = preload("res://scripts/bench_view.gd")
const TuneView = preload("res://scripts/tune_view.gd")
const ResultsView = preload("res://scripts/results_view.gd")
const Assembly = preload("res://scripts/assembly.gd")

const BUDGETS: Array = [600, 800, 1000, 1500, 2500, 5000]
const OBJECTIVES := {
	"Balanced": "Equal weight on CPU, GPU, RAM and storage.",
	"CPU": "CPU counts 45%. Pick a strong processor and tune it.",
	"GPU": "Graphics counts 45%. A discrete GPU pays off.",
	"Storage": "Storage counts 50%. Fast drives win this one.",
}
const STEPS: Array = [
	["1  EXPLORE", "WASD / arrows to walk. You start at home. E uses doors, your car and meeting contacts."],
	["2  PHONE", "P opens Browse, Messages and Sell. Agree price, place AND time in chat. People have different schedules."],
	["3  MEET", "Walk outside, E to enter the car, then drive yourself. Park and walk to the contact at the agreed time."],
	["4  BUILD / SELL", "B at your home workbench opens assembly. Sell spare parts on the phone; NPC buyers will haggle."],
	["5  TUNE", "Overclock CPU, GPU and RAM. More volts = more speed, but over 1.40 V a part burns out forever."],
	["6  BENCH", "Finish before the deadline. 3 days pass in 36 real minutes. CPU, GPU, RAM and storage are scored."],
]

var _phase: String = ""
var _match_id: int = -1
var _screens: Dictionary = {}
var _screen_layer: Control
var _toast_box: VBoxContainer
var _modal: Control
var _notice_log: Array = []

# menu / lobby widgets
var _name_edit: LineEdit
var _budget_opt: OptionButton
var _obj_opt: OptionButton
var _obj_desc: Label
var _addr_edit: LineEdit
var _menu_status: Label
var _lobby_players: VBoxContainer
var _lobby_sig: String = ""
var _lobby_budget: OptionButton
var _lobby_obj: OptionButton
var _lobby_start: Button
var _lobby_wait: Label
var _lobby_addr: Label
var _results: Control

# game widgets
var _game: Control
var _clock_lbl: Label
var _cash_lbl: Label

func _ready() -> void:
	theme = K.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	_screen_layer = Control.new()
	_screen_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_screen_layer)
	_build_menu()
	_build_lobby()
	_build_results()
	_toast_box = VBoxContainer.new()
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_toast_box.offset_left = -430
	_toast_box.offset_right = -16
	_toast_box.offset_bottom = -16
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_box.alignment = BoxContainer.ALIGNMENT_END
	add_child(_toast_box)
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.visible = false
	add_child(_modal)
	Game.changed.connect(_on_changed)
	Game.notice.connect(_toast)
	_on_changed()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), K.NAVY0)
	var step := 48.0
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(K.LINE, 0.16), 1.0)
		x += step
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(K.LINE, 0.16), 1.0)
		y += step
	draw_rect(Rect2(0, 0, size.x, 4), K.LIME)

# ------------------------------------------------------------------ toasts and modal

func _toast(msg: String) -> void:
	_notice_log.append(msg)
	if _notice_log.size() > 40:
		_notice_log.pop_front()
	var risky := msg.contains("BANG") or msg.contains("Too late") or msg.contains("error") or msg.contains("Cannot") or msg.contains("walked away") or msg.contains("Need ") or msg.contains("refuse") or msg.contains("busy") or msg.contains("Wait ")
	var t := K.panel("ToastRisk" if risky else "Toast")
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := K.lbl(msg, "", K.CREAM, true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(l)
	_toast_box.add_child(t)
	while _toast_box.get_child_count() > 5:
		var o := _toast_box.get_child(0)
		_toast_box.remove_child(o)
		o.queue_free()
	var tw := t.create_tween()
	tw.tween_interval(5.5 if risky else 4.5)
	tw.tween_property(t, "modulate:a", 0.0, 0.6)
	tw.tween_callback(t.queue_free)

func _modal_open() -> void:
	K.clear(_modal)
	var dim := ColorRect.new()
	dim.color = Color(K.NAVY0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_child(dim)
	_modal.visible = true

func _modal_close() -> void:
	_modal.visible = false
	K.clear(_modal)

func ask(title: String, text: String, ok_label: String, cb: Callable) -> void:
	_modal_open()
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(cc)
	var card := K.panel("CardRisk")
	var v := K.vbox(12)
	v.add_child(K.lbl(title.to_upper(), "H2", K.ORANGE))
	var t := K.lbl(text, "", K.CREAM, true)
	t.custom_minimum_size.x = 440
	v.add_child(t)
	var row := K.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	var cancel := K.btn("CANCEL", "GhostButton", _modal_close)
	row.add_child(cancel)
	row.add_child(K.btn(ok_label.to_upper(), "RiskButton", func():
		_modal_close()
		cb.call()))
	v.add_child(row)
	card.add_child(v)
	cc.add_child(card)
	cancel.grab_focus()

func _open_assembly(item: Dictionary) -> void:
	var me := Game.me()
	if float(me.get("busy", 0.0)) > 0.0 or not me.get("trip", {}).is_empty():
		_toast("The workbench is busy right now.")
		return
	_modal_open()
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(cc)
	var card := K.panel("Card")
	var v := K.vbox(8)
	var head := K.hbox(10)
	head.add_child(K.lbl("INSTALLING  %s" % String(item.name), "H2", K.cat_color(item.category)))
	head.add_child(K.spacer())
	var asm: Control = Assembly.new()
	head.add_child(K.btn("ROTATE (R)", "GhostButton", func(): asm.rotate_current()))
	head.add_child(K.btn("CANCEL (ESC)", "GhostButton", _modal_close))
	v.add_child(head)
	var frame := K.panel("Inset")
	frame.add_child(asm)
	v.add_child(frame)
	card.add_child(v)
	cc.add_child(card)
	asm.begin(item.duplicate(true))
	var iid: int = int(item.id)
	asm.cancelled.connect(_modal_close)
	asm.completed.connect(func(slips: int):
		_modal_close()
		Game.act("install", {"item_id": iid})
		if slips == 0:
			_toast("Flawless assembly."))

func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo: return
	if k.keycode == KEY_ESCAPE:
		if _modal.visible: _modal_close()
		elif is_instance_valid(_phone_layer) and _phone_layer.visible: _phone_layer.visible = false
		elif is_instance_valid(_workspace) and _workspace.visible: _workspace.visible = false
		elif is_instance_valid(_map_layer) and _map_layer.visible: _map_layer.visible = false
		else: return
		get_viewport().set_input_as_handled()
		return
	if _phase != "playing" or _modal.visible: return
	match k.keycode:
		KEY_P, KEY_TAB: _toggle_phone()
		KEY_M: _toggle_map()
		KEY_B: _open_workspace("bench")
		KEY_T: _open_workspace("tune")
		KEY_E:
			if not _overlay_open():
				if Game.me().area == "home" and Game.me().pos.distance_to(World.BENCH) < 50: _open_workspace("bench")
				else: Game.act("interact")
		KEY_SPACE:
			if not _overlay_open(): Game.act("wait")
		_: return
	get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ phase handling

func _show_screen(n: String) -> void:
	for k in _screens:
		_screens[k].visible = k == n

func _on_changed() -> void:
	var st: Dictionary = Game.state
	var ph: String = String(st.get("phase", "menu"))
	if ph != _phase or (ph == "playing" and int(st.get("match_id", 0)) != _match_id):
		_enter_phase(ph)
	match ph:
		"menu":
			_menu_status.text = _seller_line()
		"lobby":
			_lobby_refresh()
		"playing":
			_game_refresh()
		"results":
			_results.refresh()

func _enter_phase(ph: String) -> void:
	_phase = ph
	_modal_close()
	if ph != "playing":
		K.clear(_toast_box)
	if ph == "playing":
		_match_id = int(Game.state.get("match_id", 0))
		_build_game()
		_show_screen("game")
		_toast("Welcome home. WASD / arrows to walk. P: phone · E: interact · B: workbench · M: town map.")
	elif ph == "results":
		_show_screen("results")
		_results.refresh()
	else:
		_show_screen(ph)
		if ph == "lobby":
			_lobby_sig = ""

func _seller_line() -> String:
	var s: String = Game.seller_status()
	return "Seller AI: " + (s if s != "" else "offline scripted sellers unless OPENROUTER_API_KEY is set")

# ------------------------------------------------------------------ menu

func _build_menu() -> void:
	var sc := K.scroll()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_layer.add_child(sc)
	_screens["menu"] = sc
	var mc := MarginContainer.new()
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right"]:
		mc.add_theme_constant_override("margin_" + s, 48)
	mc.add_theme_constant_override("margin_top", 36)
	mc.add_theme_constant_override("margin_bottom", 28)
	sc.add_child(mc)
	var h := K.hbox(36)
	mc.add_child(h)
	# hero side
	var hero := K.vbox(14)
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.size_flags_stretch_ratio = 1.25
	hero.add_child(K.lbl("3 DAYS. ONE BUDGET. A PILE OF USED PARTS.", "Eyebrow"))
	hero.add_child(K.lbl("SLOPYARD WARS", "Display"))
	hero.add_child(K.lbl("Hunt classifieds, haggle with eccentric sellers, drive across town for the parts, assemble the rig by hand, overclock it to the edge and out-benchmark your rivals.", "Muted", null, true))
	var art := Control.new()
	art.custom_minimum_size = Vector2(0, 150)
	art.draw.connect(func():
		var cats := ["cpu", "gpu", "ram", "motherboard", "storage"]
		var w: float = art.size.x
		for i in cats.size():
			var c: String = cats[i]
			var xf := Transform2D(deg_to_rad(-6 + i * 3.0), Vector2(1.5, 1.5), 0.0, Vector2(w * (0.1 + 0.2 * i), 80 + (i % 2) * 14))
			PartArt.draw_part(art, xf, c, {"category": c, "name": "ssd"}, K.cat_color(c), 1.0))
	art.resized.connect(art.queue_redraw)
	hero.add_child(art)
	hero.add_child(K.lbl("HOW IT WORKS", "Eyebrow"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for s in STEPS:
		var p := K.panel("CardTight")
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := K.vbox(2)
		v.add_child(K.lbl(String(s[0]), "Mono", K.LIME))
		v.add_child(K.lbl(String(s[1]), "Muted", null, true))
		p.add_child(v)
		grid.add_child(p)
	hero.add_child(grid)
	h.add_child(hero)
	# setup side
	var card := K.panel("Hero")
	card.size_flags_horizontal = Control.SIZE_FILL
	card.custom_minimum_size.x = 430
	var v := K.vbox(10)
	v.add_child(K.lbl("PLAYER", "Eyebrow"))
	_name_edit = LineEdit.new()
	_name_edit.text = "Scrapper"
	_name_edit.max_length = 16
	v.add_child(_name_edit)
	v.add_child(K.hrule())
	v.add_child(K.lbl("SOLO RUN", "Eyebrow"))
	var r1 := K.hbox(8)
	r1.add_child(K.lbl("Budget", "Muted"))
	_budget_opt = OptionButton.new()
	for b in BUDGETS:
		_budget_opt.add_item(K.money(b))
	_budget_opt.select(2)
	_budget_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(_budget_opt)
	v.add_child(r1)
	var r2 := K.hbox(8)
	r2.add_child(K.lbl("Goal", "Muted"))
	_obj_opt = OptionButton.new()
	for o in OBJECTIVES:
		_obj_opt.add_item(o)
	_obj_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(_obj_opt)
	v.add_child(r2)
	_obj_desc = K.lbl(String(OBJECTIVES["Balanced"]), "Tiny", K.SKY, true)
	v.add_child(_obj_desc)
	_obj_opt.item_selected.connect(func(i: int): _obj_desc.text = String(OBJECTIVES[_obj_opt.get_item_text(i)]))
	var solo := K.btn("PLAY SOLO", "PrimaryButton", func(): _start_solo())
	solo.custom_minimum_size.y = 46
	v.add_child(solo)
	v.add_child(K.hrule())
	v.add_child(K.lbl("LAN MULTIPLAYER (2-4 PLAYERS)", "Eyebrow"))
	v.add_child(K.btn("HOST A GAME", "", func(): Game.host(_pname())))
	var r3 := K.hbox(8)
	_addr_edit = LineEdit.new()
	_addr_edit.placeholder_text = "Host address, e.g. 192.168.1.20"
	_addr_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_addr_edit.text_submitted.connect(func(_t: String): Game.join_game(_addr_edit.text, _pname()))
	r3.add_child(_addr_edit)
	r3.add_child(K.btn("JOIN", "", func(): Game.join_game(_addr_edit.text, _pname())))
	v.add_child(r3)
	v.add_child(K.lbl("Same network, UDP port 24680. Players compete for the same shared listings: whoever arrives first gets the part.", "Tiny", K.MUTED, true))
	_menu_status = K.lbl("", "Tiny", K.ORANGE, true)
	v.add_child(_menu_status)
	card.add_child(v)
	h.add_child(card)

func _pname() -> String:
	var n := _name_edit.text.strip_edges()
	return n if n != "" else "Scrapper"

func _start_solo() -> void:
	Game.solo(_pname(), int(BUDGETS[_budget_opt.selected]), _obj_opt.get_item_text(_obj_opt.selected))

# ------------------------------------------------------------------ lobby

func _build_lobby() -> void:
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, 40)
	_screen_layer.add_child(mc)
	_screens["lobby"] = mc
	var cc := CenterContainer.new()
	mc.add_child(cc)
	var card := K.panel("Hero")
	card.custom_minimum_size.x = 620
	var v := K.vbox(12)
	v.add_child(K.lbl("LAN LOBBY", "Title"))
	_lobby_addr = K.lbl("", "Mono", K.SKY, true)
	v.add_child(_lobby_addr)
	v.add_child(K.lbl("PLAYERS", "Eyebrow"))
	_lobby_players = K.vbox(6)
	v.add_child(_lobby_players)
	v.add_child(K.hrule())
	var r := K.hbox(8)
	r.add_child(K.lbl("Budget", "Muted"))
	_lobby_budget = OptionButton.new()
	for b in BUDGETS:
		_lobby_budget.add_item(K.money(b))
	_lobby_budget.select(2)
	_lobby_budget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(_lobby_budget)
	r.add_child(K.lbl("Goal", "Muted"))
	_lobby_obj = OptionButton.new()
	for o in OBJECTIVES:
		_lobby_obj.add_item(o)
	_lobby_obj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(_lobby_obj)
	v.add_child(r)
	_lobby_start = K.btn("START MATCH", "PrimaryButton", func(): Game.start_match(int(BUDGETS[_lobby_budget.selected]), _lobby_obj.get_item_text(_lobby_obj.selected)))
	_lobby_start.custom_minimum_size.y = 46
	v.add_child(_lobby_start)
	_lobby_wait = K.lbl("", "Muted", null, true)
	v.add_child(_lobby_wait)
	v.add_child(K.btn("LEAVE LOBBY", "GhostButton", func(): Game.leave()))
	card.add_child(v)
	cc.add_child(card)

func _lobby_ips() -> String:
	var out: Array = []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return ", ".join(out)

func _lobby_refresh() -> void:
	var st: Dictionary = Game.state
	var host: bool = Game.is_host()
	var sig := str(st.players.size()) + str(host)
	for id in st.players:
		sig += String(st.players[id].name)
	if sig != _lobby_sig:
		_lobby_sig = sig
		K.clear(_lobby_players)
		if st.players.is_empty():
			_lobby_players.add_child(K.lbl("Connecting to host...", "Muted"))
		for id in st.players:
			var p := K.panel("CardTight")
			var r := K.hbox(8)
			r.add_child(K.lbl(String(st.players[id].name), "Mono"))
			r.add_child(K.spacer())
			if id == 1:
				r.add_child(K.pill("HOST", K.ORANGE))
			if id == Game.local_id():
				r.add_child(K.pill("YOU", K.LIME))
			p.add_child(r)
			_lobby_players.add_child(p)
	_lobby_addr.text = ("Tell friends to join: %s  (UDP port 24680)" % _lobby_ips()) if host else "Connected to the host. Waiting for the match to start."
	_lobby_budget.disabled = not host
	_lobby_obj.disabled = not host
	_lobby_start.visible = host
	_lobby_wait.text = "You are the host. Start whenever everyone is in. Late joins are refused once play starts." if host else "The host chooses the budget and goal and starts the match."

# ------------------------------------------------------------------ results

func _build_results() -> void:
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, 32)
	_screen_layer.add_child(mc)
	_screens["results"] = mc
	_results = ResultsView.new()
	mc.add_child(_results)
	_results.menu.connect(func(): Game.leave())
	_results.replay.connect(_replay)

func _replay() -> void:
	var n: String = String(Game.me().get("name", "Scrapper"))
	var b: int = int(Game.state.budget)
	var o: String = String(Game.state.objective)
	Game.solo(n, b, o)

# ------------------------------------------------------------------ game screen

# World presentation never owns inventory, clock or movement authority.
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

func _build_game() -> void:
	if _screens.has("game"):
		_screens.game.queue_free()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_layer.add_child(root)
	_screens["game"] = root
	_game = root
	_world = TownView.new()
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
	row.add_child(K.btn("MENU", "GhostButton", func(): ask("Leave match?", "This unfinished run is not saved.", "Leave", func(): Game.leave())))
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
	hints.add_child(K.lbl("WASD / arrows: move  ·  E: door / car / handoff  ·  P: phone  ·  M: map  ·  B/T: home workbench  ·  Space: wait (solo)", "Tiny", K.MUTED, true))
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
		_toast("Meeting tracked. M shows the whole town; follow the yellow marker. Park and E at the contact."))
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
	_bench.ask = ask
	_bench.install_requested.connect(_open_assembly)
	_bench.go_market.connect(_toggle_phone)
	_bench.go_tuning.connect(func(): _open_workspace("tune"))
	work.add_child(_bench)
	_tune = TuneView.new()
	_tune.ask = ask
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
	_update_world_hud()

func _overlay_open() -> bool:
	return _modal.visible or _phone_layer.visible or _workspace.visible or _map_layer.visible

func _toggle_phone() -> void:
	if _phase != "playing": return
	_workspace.visible = false
	_map_layer.visible = false
	_phone_layer.visible = not _phone_layer.visible
	if _phone_layer.visible: _phone.refresh()
	Game.act("move", {"direction": Vector2.ZERO})

func _toggle_map() -> void:
	if _phase != "playing": return
	_phone_layer.visible = false
	_workspace.visible = false
	_map_layer.visible = not _map_layer.visible
	if not _map_layer.visible: return
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
		_toast("Walk up to the PC workbench inside your house first.")
		return
	_phone_layer.visible = false
	_map_layer.visible = false
	_workspace.visible = true
	_bench.visible = which == "bench"
	_tune.visible = which == "tune"
	if which == "bench": _bench.refresh()
	else: _tune.refresh()

func _game_refresh() -> void:
	if not is_instance_valid(_world): return
	if _phone_layer.visible: _phone.refresh()
	if _workspace.visible:
		if _bench.visible: _bench.refresh()
		if _tune.visible: _tune.refresh()
	_update_world_hud()

func _process(delta: float) -> void:
	if _phase != "playing" or not is_instance_valid(_world) or Game.me().is_empty(): return
	_move_t += delta
	if _move_t >= 0.10:
		_move_t = 0
		var input := Vector2.ZERO
		if not _overlay_open() and not Game.me().ready:
			input = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).limit_length()
		Game.act("move", {"direction": input})
	_update_world_hud()
	if _workspace.visible:
		if _bench.visible: _bench.tick()
		if _tune.visible: _tune.tick(delta)

func _update_world_hud() -> void:
	if not is_instance_valid(_clock_lbl) or Game.me().is_empty(): return
	var p: Dictionary = Game.me()
	_clock_lbl.text = Trade.stamp(Game.clock())
	_cash_lbl.text = "$%d" % int(p.cash)
	var hint := "Home · E at the door to go outside. Walk to the PC desk for B: assembly / T: tuning."
	if p.area == "town":
		hint = "Driving · WASD / arrows. E parks and gets out. Fuel costs $3 each time you start the car." if p.driving else "Town · E by your car to drive, by home to go inside, or by a scheduled contact to trade."
	if p.ready: hint = "Rig locked. Waiting for the other builders or the deadline."
	_context_label.text = hint
	var meetings: Array = Game.active_meetings(p)
	var line := "Three-day deadline: " + Trade.stamp(Trade.START + 4320) + " · " + str(Game.state.objective) + " objective · P opens your phone."
	if not meetings.is_empty():
		var m: Dictionary = meetings[0]
		for candidate: Dictionary in meetings:
			if int(candidate.listing_id) == _tracked: m = candidate
		line = str(m.contact) + " · " + str(m.label) + " · " + str(m.status).to_upper() + " · Space waits in solo; missed? message to reschedule."
	_appointment_label.text = line
