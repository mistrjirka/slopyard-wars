extends Control
signal start_requested(budget: int, objective: String)
signal leave_requested
const K = preload("res://src/ui/ui_kit.gd")
const Setup = preload("res://src/ui/match_setup.gd")
const BUDGETS = Setup.BUDGETS
const OBJECTIVES = Setup.OBJECTIVES
const STEPS = Setup.STEPS
var _lobby_players: VBoxContainer
var _lobby_sig: String = ""
var _lobby_budget: OptionButton
var _lobby_obj: OptionButton
var _lobby_start: Button
var _lobby_wait: Label
var _lobby_addr: Label


func _ready() -> void:
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, 40)
	add_child(mc)
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
	_lobby_start = K.btn("START MATCH", "PrimaryButton", func(): start_requested.emit(int(BUDGETS[_lobby_budget.selected]), _lobby_obj.get_item_text(_lobby_obj.selected)))
	_lobby_start.custom_minimum_size.y = 46
	v.add_child(_lobby_start)
	_lobby_wait = K.lbl("", "Muted", null, true)
	v.add_child(_lobby_wait)
	v.add_child(K.btn("LEAVE LOBBY", "GhostButton", func(): leave_requested.emit()))
	card.add_child(v)
	cc.add_child(card)


func _lobby_ips() -> String:
	var out: Array = []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return ", ".join(out)


func refresh() -> void:
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
