extends Control
## Cover-led solo high-score setup with pages for help and dialogue settings.
signal solo_requested(player_name: String, budget: int, objective: String, match_days: int)
signal assembly_test_requested(player_name: String)
signal host_requested(player_name: String, match_days: int)
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
@onready var _days_opt: OptionButton = %MatchDays
@onready var _host_days_opt: OptionButton = %HostMatchDays
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
	for days in Setup.MATCH_DAYS:
		var label := "%d game day%s" % [days, "" if days == 1 else "s"]
		_days_opt.add_item(label)
		_host_days_opt.add_item(label)
	_days_opt.select(Setup.MATCH_DAYS.find(Config.DEFAULT_MATCH_DAYS))
	_host_days_opt.select(Setup.MATCH_DAYS.find(Config.DEFAULT_MATCH_DAYS))
	_days_opt.item_selected.connect(_on_days_selected)
	_on_days_selected(_days_opt.selected)
	# Assign only at startup, not refresh: state updates must not overwrite edits.
	_key_edit.text = Game.openrouter_key()
	_show_solo()
	%PlaySolo.grab_focus()
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var stacked := size.x < 960.0
	%Columns.vertical = stacked
	%SetupCard.custom_minimum_size.x = 0.0 if stacked else 440.0
	%SetupCard.size_flags_horizontal = Control.SIZE_EXPAND_FILL if stacked else Control.SIZE_FILL
	%Cover.custom_minimum_size.y = clampf((size.x - 64.0) / 1.26, 220.0, 380.0) if stacked else 400.0


func _pname() -> String:
	var player_name := _name_edit.text.strip_edges()
	return player_name if player_name != "" else "Scrapper"


func _start_solo() -> void:
	solo_requested.emit(_pname(), int(BUDGETS[_budget_opt.selected]), _obj_opt.get_item_text(_obj_opt.selected), int(Setup.MATCH_DAYS[_days_opt.selected]))


func _start_assembly_test() -> void:
	assembly_test_requested.emit(_pname())


func _on_days_selected(index: int) -> void:
	var days := int(Setup.MATCH_DAYS[index])
	%RunDescription.text = "Day 1, 08:00 to Day %d, 22:00 · about %d minutes\nTurn secondhand parts into a new local high score before the deadline." % [days, roundi(Config.duration_for_days(days) / Config.RATE / 60.0)]


func _on_objective_selected(index: int) -> void:
	_obj_desc.text = String(OBJECTIVES[_obj_opt.get_item_text(index)])


func _on_key_changed(value: String) -> void:
	Game.set_openrouter_key(value)
	refresh()


func _toggle_lan() -> void:
	# Retained for old scene connections; multiplayer is no longer a menu page.
	_show_solo()


func _toggle_help() -> void:
	_show_page(%HelpControls)


func _toggle_sellers() -> void:
	_show_page(%SellerControls)


func _show_solo() -> void:
	_show_page(%SoloControls)


func _show_page(page: Control) -> void:
	var sections := [%SoloControls, %HelpControls, %SellerControls, _lan]
	var buttons := [%PlayToggle, %HelpToggle, %SellerToggle, %LanToggle]
	for i in sections.size():
		sections[i].visible = sections[i] == page
		buttons[i].set_pressed_no_signal(sections[i].visible)


func _host() -> void:
	host_requested.emit(_pname(), int(Setup.MATCH_DAYS[_host_days_opt.selected]))


func _join() -> void:
	join_requested.emit(_addr_edit.text, _pname())


func _on_address_submitted(_text: String) -> void:
	_join()


func refresh() -> void:
	_menu_status.text = "Seller dialogue: " + Game.seller_status()
