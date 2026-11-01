extends Control
## Slopyard Wars UI shell: menu, lobby, game (tabbed command center), results. All state changes go through Game.act().
const K = preload("res://scripts/ui_kit.gd")
const PartArt = preload("res://scripts/part_art.gd")
const Catalog = preload("res://scripts/catalog.gd")
const MarketView = preload("res://scripts/market_view.gd")
const DriveView = preload("res://scripts/drive_view.gd")
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
	["1  FIND", "Browse CLASSIFIEDS. Use FITS MY RIG so you only see parts that work with what you own."],
	["2  HAGGLE", "Chat with the seller and agree a price. A deal is NOT a reservation."],
	["3  DRIVE", "Pick a pin on the DRIVE map. Trips cost game time and fuel; a rival can beat you there."],
	["4  BUILD", "Install on the WORKBENCH: case, then board, then CPU / RAM / GPU / storage / PSU. Each part has its own mini-game."],
	["5  TUNE", "Overclock CPU, GPU and RAM. More volts = more speed, but over 1.40 V a part burns out forever."],
	["6  BENCH", "Finish before the deadline. 3 days pass in 12 real minutes. CPU, GPU, RAM and storage are scored."],
]

var _phase: String = ""
var _match_id: int = -1
var _screens: Dictionary = {}
var _screen_layer: Control
var _toast_box: VBoxContainer
var _modal: Control
var _notice_log: Array = []
var _last_day: int = 0
var _guide_t: float = 0.0
var _guide_tab: String = ""

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
var _views: Dictionary = {}
var _tab_btns: Dictionary = {}
var _tab: String = "market"
var _clock_lbl: Label
var _left_lbl: Label
var _time_bar: ProgressBar
var _cash_lbl: Label
var _budget_lbl: Label
var _obj_lbl: Label
var _obj_sub: Label
var _trip_pill: PanelContainer
var _ai_pill: PanelContainer
var _ticker: Label
var _guide_panel: PanelContainer
var _guide_lbl: Label
var _guide_btn: Button
var _wait: Control
var _wait_lbl: Label
var _help_log: VBoxContainer
var _help_sig: int = -1

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
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_ESCAPE and _modal.visible:
		_modal_close()
		get_viewport().set_input_as_handled()
		return
	if _phase == "playing" and not _modal.visible and not k.ctrl_pressed and not k.alt_pressed:
		var order := ["market", "drive", "bench", "tune", "help"]
		var i := k.keycode - KEY_1
		if i >= 0 and i < order.size():
			_set_tab(order[i])
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
		_last_day = 0
		_show_screen("game")
		_set_tab("market")
		_toast("Match on! Read the banner under the tabs for your next step. Keys 1-5 switch tabs.")
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

func _build_game() -> void:
	if _screens.has("game"):
		_screens["game"].queue_free()
		_screens.erase("game")
	_views.clear()
	_tab_btns.clear()
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	_screen_layer.add_child(root)
	_screens["game"] = root
	_game = root
	# top bar
	var top := K.panel("Topbar")
	var th := K.hbox(22)
	th.add_child(K.lbl("SLOPYARD\nWARS", "H2", K.LIME))
	var dl := K.vbox(2)
	dl.custom_minimum_size.x = 250
	var dr := K.hbox(10)
	_clock_lbl = K.lbl("", "Big")
	dr.add_child(_clock_lbl)
	_left_lbl = K.lbl("", "Mono", K.ORANGE)
	dr.add_child(_left_lbl)
	dl.add_child(dr)
	_time_bar = ProgressBar.new()
	_time_bar.max_value = 4320.0
	_time_bar.custom_minimum_size.y = 8
	_time_bar.show_percentage = false
	dl.add_child(_time_bar)
	dl.add_child(K.lbl("BENCHMARK DEADLINE - rig must be finished", "Tiny", K.FAINT))
	th.add_child(dl)
	var cv := K.vbox(2)
	cv.custom_minimum_size.x = 150
	_cash_lbl = K.lbl("", "Big", K.LIME)
	cv.add_child(_cash_lbl)
	_budget_lbl = K.lbl("", "Tiny")
	cv.add_child(_budget_lbl)
	th.add_child(cv)
	var ov := K.vbox(2)
	_obj_lbl = K.lbl("", "Mono", K.SKY)
	ov.add_child(_obj_lbl)
	_obj_sub = K.lbl("", "Tiny")
	ov.add_child(_obj_sub)
	th.add_child(ov)
	th.add_child(K.spacer())
	_trip_pill = K.pill("", K.ORANGE)
	_trip_pill.visible = false
	th.add_child(_trip_pill)
	_ai_pill = K.pill("", K.LIME)
	th.add_child(_ai_pill)
	th.add_child(K.btn("MENU", "GhostButton", func(): ask("Leave the match?", "Your progress is lost and you return to the main menu.", "Leave", func(): Game.leave())))
	top.add_child(th)
	root.add_child(top)
	# tabs
	var tabs := K.panel("Topbar")
	tabs.add_theme_stylebox_override("panel", K.box(Color("060d20"), K.LINE, 0, 0, 12, 4))
	var tr := K.hbox(4)
	var grp := ButtonGroup.new()
	var defs := [["market", "1 CLASSIFIEDS"], ["drive", "2 DRIVE"], ["bench", "3 WORKBENCH"], ["tune", "4 OVERCLOCK"], ["help", "5 GUIDE"]]
	for d in defs:
		var b := K.btn(String(d[1]), "TabButton", _set_tab.bind(d[0]))
		b.button_group = grp
		tr.add_child(b)
		_tab_btns[d[0]] = b
	tr.add_child(K.spacer())
	_ticker = K.lbl("", "Tiny", K.MUTED)
	_ticker.clip_text = true
	_ticker.custom_minimum_size.x = 380
	_ticker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(_ticker)
	tabs.add_child(tr)
	root.add_child(tabs)
	# guide banner
	_guide_panel = K.panel("CardTight")
	_guide_panel.add_theme_stylebox_override("panel", K.box(Color(K.LIME, 0.08), K.LIME_DIM, 0, 1, 18, 6))
	var gr := K.hbox(10)
	gr.add_child(K.lbl("NEXT", "Eyebrow"))
	_guide_lbl = K.lbl("", "", K.CREAM, true)
	_guide_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gr.add_child(_guide_lbl)
	_guide_btn = K.btn("GO", "GhostButton", func(): if _guide_tab != "": _set_tab(_guide_tab))
	gr.add_child(_guide_btn)
	_guide_panel.add_child(gr)
	root.add_child(_guide_panel)
	# content
	var stack := MarginContainer.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for s in ["left", "right"]:
		stack.add_theme_constant_override("margin_" + s, 16)
	stack.add_theme_constant_override("margin_top", 12)
	stack.add_theme_constant_override("margin_bottom", 12)
	root.add_child(stack)
	var market := MarketView.new()
	market.ask = ask
	market.went_driving.connect(func(): _set_tab("drive"))
	stack.add_child(market)
	_views["market"] = market
	var drive := DriveView.new()
	drive.open_listing.connect(func(id: int): _set_tab("market"); market.select(id))
	drive.went_driving.connect(func(): pass)
	stack.add_child(drive)
	_views["drive"] = drive
	var bench := BenchView.new()
	bench.ask = ask
	bench.install_requested.connect(_open_assembly)
	bench.go_market.connect(func(): _set_tab("market"))
	stack.add_child(bench)
	_views["bench"] = bench
	var tune := TuneView.new()
	tune.ask = ask
	stack.add_child(tune)
	_views["tune"] = tune
	stack.add_child(_build_help())
	for k in _views:
		_views[k].visible = false
	# locked overlay
	_wait = Control.new()
	_wait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wait.visible = false
	var dim := ColorRect.new()
	dim.color = Color(K.NAVY0, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wait.add_child(dim)
	var wc := CenterContainer.new()
	wc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var wcard := K.panel("Hero")
	var wv := K.vbox(10)
	wv.add_child(K.lbl("RIG LOCKED", "Title", K.LIME))
	_wait_lbl = K.lbl("", "Muted", null, true)
	_wait_lbl.custom_minimum_size.x = 420
	wv.add_child(_wait_lbl)
	wcard.add_child(wv)
	wc.add_child(wcard)
	_wait.add_child(wc)
	stack.add_child(_wait)

func _build_help() -> Control:
	var sc := K.scroll()
	_views["help"] = sc
	var v := K.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	v.add_child(K.lbl("FIELD GUIDE", "Title"))
	var rules := [
		["YOUR GOAL", "Build the highest-scoring working PC inside your budget before the 3-day deadline (12 real minutes). Required: case, PSU, CPU, motherboard, RAM, storage, plus graphics (a GPU, or a CPU with integrated graphics on a board that has video outputs)."],
		["BUYING", "Listings are shared and change over time. Chat to agree a price before pickup. The host validates agreements and sales. An accepted deal does not reserve the part: you must drive there and arrive first."],
		["COMPATIBILITY", "CPU socket must equal the board socket (OX3 / OX4 / NX5). RAM type must equal the board's memory (DDR3 / DDR4 / DDR5). ATX boards need ATX cases. Wrong purchase? There is no refund: buy the matching part and swap it in; the old one stays in inventory."],
		["POWER", "The PSU must cover the whole rig, including overclocks. Overloaded builds are invalid and score zero."],
		["OVERCLOCKING", "CPU, GPU and RAM accept clock and voltage 1.00 - 1.60. Above 1.40 V the part is destroyed permanently. Stable clock = 1 + 1.3 x (V - 1); over that, performance drops. Safe sweet spot: 1.30 - 1.40 V near the stable clock."],
		["TIME", "Driving and bench work consume game time; the market keeps moving. Finish early to lock a score, or run until the deadline."],
	]
	for r in rules:
		var p := K.panel("Card")
		var pv := K.vbox(4)
		pv.add_child(K.lbl(String(r[0]), "Eyebrow"))
		pv.add_child(K.lbl(String(r[1]), "", K.CREAM, true))
		p.add_child(pv)
		v.add_child(p)
	v.add_child(K.lbl("MESSAGE LOG", "Eyebrow"))
	_help_log = K.vbox(4)
	v.add_child(_help_log)
	return sc

func _set_tab(t: String) -> void:
	if not _views.has(t):
		return
	_tab = t
	for k in _views:
		_views[k].visible = k == t
	if _tab_btns.has(t):
		_tab_btns[t].button_pressed = true
	_help_sig = -1
	_game_refresh()

func _game_refresh() -> void:
	if _game == null or not _screens.has("game"):
		return
	var st: Dictionary = Game.state
	var me: Dictionary = Game.me()
	var v: Control = _views.get(_tab)
	if v != null and v.has_method("refresh"):
		v.refresh()
	if _tab == "help" and _help_sig != _notice_log.size():
		_help_sig = _notice_log.size()
		K.clear(_help_log)
		for i in range(_notice_log.size() - 1, maxi(-1, _notice_log.size() - 25), -1):
			_help_log.add_child(K.lbl(String(_notice_log[i]), "Muted", null, true))
	var ev: Array = st.get("events", [])
	_ticker.text = String(ev[ev.size() - 1]) if not ev.is_empty() else ""
	var s: String = Game.seller_status()
	var live: bool = s.to_lower().contains("live") or s.to_lower().contains("online")
	K.set_pill(_ai_pill, ("AI SELLERS: LIVE" if live else "AI SELLERS: OFFLINE"), K.LIME if live else K.ORANGE)
	_ai_pill.tooltip_text = s
	# locked overlay
	var locked: bool = bool(me.get("ready", false))
	_wait.visible = locked
	if locked:
		var lines: Array = []
		for id in st.players:
			lines.append("%s %s" % ["done:" if st.players[id].ready else "working:", st.players[id].name])
		_wait_lbl.text = "Your rig is submitted. Waiting for the others or the deadline.\n\n" + "\n".join(lines)
	_update_guide(true)

func _process(delta: float) -> void:
	if _phase == "results":
		_results.tick(delta)
		return
	if _phase != "playing" or _game == null:
		return
	_update_top()
	var v: Control = _views.get(_tab)
	if v != null:
		if v.has_method("tick"):
			if _tab == "tune":
				v.tick(delta)
			else:
				v.tick()
	_guide_t += delta
	if _guide_t > 0.4:
		_guide_t = 0.0
		_update_guide(false)

func _set_text(l: Label, t: String) -> void:
	if l.text != t:
		l.text = t

func _update_top() -> void:
	var st: Dictionary = Game.state
	var rem: float = float(st.get("remaining", 0.0))
	var me: Dictionary = Game.me()
	_set_text(_clock_lbl, K.clock_text(rem))
	_set_text(_left_lbl, K.real_left(rem) + " left")
	_time_bar.value = 4320.0 - rem
	var low: bool = rem < 864.0
	_time_bar.theme_type_variation = "RiskBar" if low else ""
	_left_lbl.add_theme_color_override("font_color", K.DANGER if low else K.ORANGE)
	var day := mini(int((4320.0 - rem) / 1440.0) + 1, 3)
	if day != _last_day:
		if _last_day != 0:
			_toast("DAY %d begins. %s left on the clock." % [day, K.real_left(rem)])
		_last_day = day
	var cash: int = int(me.get("cash", 0))
	_set_text(_cash_lbl, K.money(cash))
	var budget: int = int(st.get("budget", 0))
	_set_text(_budget_lbl, "budget %s - spent %s" % [K.money(budget), K.money(maxi(0, budget - cash))])
	var obj: String = String(st.get("objective", "Balanced"))
	var w: Dictionary = Catalog.WEIGHTS.get(obj, Catalog.WEIGHTS.Balanced)
	_set_text(_obj_lbl, "OBJECTIVE: %s" % obj.to_upper())
	_set_text(_obj_sub, "CPU %d%%  GPU %d%%  RAM %d%%  STO %d%%" % [w.cpu * 100, w.gpu * 100, w.ram * 100, w.storage * 100])
	var trip: Dictionary = me.get("trip", {})
	_trip_pill.visible = not trip.is_empty()
	if not trip.is_empty():
		K.set_pill(_trip_pill, "DRIVING - ETA %d s" % ceili(maxf(0.0, float(trip.remaining)) / 6.0), K.ORANGE)

func _update_guide(force: bool) -> void:
	if _guide_lbl == null or Game.me().is_empty():
		return
	var g := _guide(Game.me())
	_set_text(_guide_lbl, g[0])
	_guide_lbl.add_theme_color_override("font_color", g[1])
	_guide_tab = String(g[2])
	_guide_btn.visible = _guide_tab != "" and _guide_tab != _tab

func _guide(me: Dictionary) -> Array:
	var inst: Dictionary = me.get("installed", {})
	var inv: Array = me.get("inventory", [])
	if bool(me.get("ready", false)):
		return ["Rig locked. Waiting for the other players or the deadline.", K.SKY, ""]
	var trip: Dictionary = me.get("trip", {})
	if not trip.is_empty():
		return ["Driving to the pickup. The workbench is locked until you arrive; if a rival gets there first you lose the fuel, not the cash.", K.ORANGE, "drive"]
	var order := ["case", "motherboard", "cpu", "gpu", "ram", "psu", "storage"]
	for c in order:
		for it in inv:
			if it.category == c:
				var why: String = Game.compatibility(it, me)
				if why == "" :
					return ["Install %s on the WORKBENCH (order: case, board, then the rest)." % it.name, K.LIME, "bench"]
	for it in inv:
		var why2: String = Game.compatibility(it, me)
		if why2 != "" and not why2.begins_with("Install a"):
			return ["%s will not install: %s. Buy a compatible part (try FITS MY RIG), then swap." % [it.name, why2], K.DANGER, "market"]
	var owned := {}
	for c in inst:
		owned[c] = inst[c]
	for it in inv:
		if not owned.has(it.category):
			owned[it.category] = it
	var missing: Array = []
	for c in order:
		if c == "gpu":
			continue
		if not owned.has(c):
			missing.append(String(K.CAT_LABEL[c]).to_lower())
	if not owned.has("gpu"):
		var igpu: bool = owned.has("cpu") and owned.has("motherboard") and owned.cpu.integrated and owned.motherboard.integrated
		if not igpu:
			missing.append("graphics (GPU, or iGPU CPU + board with video out)")
	if not missing.is_empty():
		return ["Still to buy: %s. Cash left %s." % [", ".join(missing), K.money(me.get("cash", 0))], K.CREAM, "market"]
	var issues: Array = Game.build_issues(me)
	if not issues.is_empty():
		return ["Build problem: %s" % issues[0], K.ORANGE, "bench"]
	var sc: Dictionary = Game.preview_score(me)
	return ["Rig is valid (score %d). Overclock for more points, or FINISH on the WORKBENCH. Unspent cash is worth nothing." % sc.total, K.LIME, "tune"]
