extends Control
signal start_requested(budget: int, objective: String)
signal leave_requested
const K = preload("res://src/ui/ui_kit.gd")
const Setup = preload("res://src/ui/match_setup.gd")
const BUDGETS = Setup.BUDGETS
const OBJECTIVES = Setup.OBJECTIVES
const PlayerRowScene = preload("res://src/ui/lobby_player_row.tscn")
var _lobby_players: VBoxContainer
var _lobby_connecting: Label
var _lobby_sig: String = ""
var _lobby_budget: OptionButton
var _lobby_obj: OptionButton
var _lobby_start: Button
var _lobby_wait: Label
var _lobby_addr: Label


func _ready() -> void:
	_lobby_players = $Margin/Center/HeroCard/Content/Players
	_lobby_connecting = $Margin/Center/HeroCard/Content/Connecting
	_lobby_addr = $Margin/Center/HeroCard/Content/Addr
	_lobby_budget = $Margin/Center/HeroCard/Content/OptionsRow/Budget
	_lobby_obj = $Margin/Center/HeroCard/Content/OptionsRow/Goal
	_lobby_start = $Margin/Center/HeroCard/Content/StartBtn
	_lobby_wait = $Margin/Center/HeroCard/Content/Wait
	for b in BUDGETS:
		_lobby_budget.add_item(K.money(b))
	_lobby_budget.select(2)
	for o in OBJECTIVES:
		_lobby_obj.add_item(o)
	_lobby_start.pressed.connect(func(): start_requested.emit(int(BUDGETS[_lobby_budget.selected]), _lobby_obj.get_item_text(_lobby_obj.selected)))
	$Margin/Center/HeroCard/Content/LeaveBtn.pressed.connect(func(): leave_requested.emit())


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
		_lobby_connecting.visible = st.players.is_empty()
		for id in st.players:
			var row = PlayerRowScene.instantiate()
			_lobby_players.add_child(row)
			row.configure(String(st.players[id].name), id == 1, id == Game.local_id())
	_lobby_addr.text = ("Tell friends to join: %s  (UDP port 24680)" % _lobby_ips()) if host else "Connected to the host. Waiting for the match to start."
	_lobby_budget.disabled = not host
	_lobby_obj.disabled = not host
	_lobby_start.visible = host
	_lobby_wait.text = "You are the host. Start whenever everyone is in. Late joins are refused once play starts." if host else "The host chooses the budget and goal and starts the match."
