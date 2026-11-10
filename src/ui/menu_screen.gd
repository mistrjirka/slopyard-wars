extends Control
## Solo-first setup; networking is an optional expandable section.
signal solo_requested(player_name: String, budget: int, objective: String)
signal host_requested(player_name: String)
signal join_requested(address: String, player_name: String)

const K = preload("res://src/ui/ui_kit.gd")
const Setup = preload("res://src/ui/match_setup.gd")
const Config = preload("res://src/core/game_config.gd")
const BUDGETS = Setup.BUDGETS
const OBJECTIVES = Setup.OBJECTIVES

@onready var _name_edit: LineEdit = %PlayerName
@onready var _key_edit: LineEdit = %OpenRouterKey
@onready var _budget_opt: OptionButton = %Budget
@onready var _obj_opt: OptionButton = %Objective
@onready var _obj_desc: Label = %ObjectiveDescription
@onready var _addr_edit: LineEdit = %HostAddress
@onready var _menu_status: Label = %SellerStatus
@onready var _lan: VBoxContainer = %LanControls


func _ready() -> void:
	for budget in BUDGETS:
		_budget_opt.add_item(K.money(budget))
	_budget_opt.select(2)
	for objective in OBJECTIVES:
		_obj_opt.add_item(objective)
	_on_objective_selected(0)
	%RunDescription.text = "08:00–22:00 · about %d real minutes before time skips. Hunt parts, collect them, then leave the evening for your build." % roundi(Config.TOTAL_MINUTES / Config.RATE / 60.0)
	# Assign only at startup, not refresh: state updates must not overwrite edits.
	_key_edit.text = Game.openrouter_key()
	_name_edit.grab_focus()


func _pname() -> String:
	var player_name := _name_edit.text.strip_edges()
	return player_name if player_name != "" else "Scrapper"


func _start_solo() -> void:
	solo_requested.emit(_pname(), int(BUDGETS[_budget_opt.selected]), _obj_opt.get_item_text(_obj_opt.selected))


func _on_objective_selected(index: int) -> void:
	_obj_desc.text = String(OBJECTIVES[_obj_opt.get_item_text(index)])


func _on_key_changed(value: String) -> void:
	Game.set_openrouter_key(value)
	refresh()


func _toggle_lan() -> void:
	_lan.visible = not _lan.visible


func _host() -> void:
	host_requested.emit(_pname())


func _join() -> void:
	join_requested.emit(_addr_edit.text, _pname())


func _on_address_submitted(_text: String) -> void:
	_join()


func refresh() -> void:
	_menu_status.text = "Seller dialogue: " + Game.seller_status()
