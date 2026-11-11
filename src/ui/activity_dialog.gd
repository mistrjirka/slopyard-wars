extends PanelContainer
## Content-driven activity chooser. Sends intents; cannot grant rewards.
signal close_requested
const K = preload("res://src/ui/ui_kit.gd")
const Activities = preload("res://src/world/activities.gd")
const Stats = preload("res://src/data/hardware_stats.gd")
var _activity: Resource
var _items: Array = []


@onready var _title: Label = $Box/Title
@onready var _description: Label = $Box/Description
@onready var _cost: Label = $Box/Cost
@onready var _reason: Label = $Box/Reason
@onready var _choice: OptionButton = $Box/Choice
@onready var _use_button: Button = $Box/Buttons/Use
@onready var _later_button: Button = $Box/Buttons/Later


func _ready() -> void:
	custom_minimum_size.x = 560
	theme_type_variation = "Card"
	_later_button.pressed.connect(func(): close_requested.emit())
	_use_button.pressed.connect(_use)
	_choice.item_selected.connect(func(_index: int): _update_quote())


func setup(activity: Resource) -> void:
	_activity = activity
	_title.text = activity.display_name
	_title.add_theme_color_override("font_color", K.LIME)
	_description.text = activity.description
	_cost.add_theme_color_override("font_color", K.SKY)
	_items = []
	if activity.kind == "clean":
		_items = Game.activities.eligible_parts(Game.me())
		_choice.visible = true
		_choice.clear()
		for item: Dictionary in _items:
			_choice.add_item("%s · %d/100" % [item.name, item.condition])
	else:
		_choice.visible = false
	_update_quote()


func _update_quote() -> void:
	var item: Dictionary = _items[_choice.selected] if _choice.visible and _choice.selected >= 0 and _choice.selected < _items.size() else {}
	var cost: int = Game.activities.cash_cost(_activity, item)
	_cost.text = "$%d · %s" % [cost, "Practice clock paused" if bool(Game.state.get("assembly_test", false)) else "%d game minutes" % _activity.minutes_cost]
	if _activity.kind == "clean" and not item.is_empty():
		var restored: Dictionary = item.duplicate()
		restored.condition = mini(100, int(item.condition) + _activity.strength)
		_cost.text += "\nCondition %d → %d · used-price guide $%d → $%d" % [item.condition, restored.condition, Stats.reference_price(item), Stats.reference_price(restored)]
	elif _activity.kind != "clean" and not bool(Game.state.get("assembly_test", false)):
		_cost.text = Activities.cost_text(_activity)
	var reason: String = Game.activities.unavailable_reason(Game.me(), _activity, item)
	if _activity.kind == "clean" and _items.is_empty():
		reason = "No eligible parts. Already-serviced and currently listed parts are excluded."
	if reason != "":
		_reason.visible = true
		_reason.text = reason
	else:
		_reason.visible = false
	_use_button.text = _activity.action_label
	_use_button.disabled = reason != ""


func _use() -> void:
	var data := {"activity_id": str(_activity.id)}
	if is_instance_valid(_choice) and _choice.visible and _choice.selected >= 0 and _choice.selected < _items.size():
		data["item_id"] = int(_items[_choice.selected].id)
	Game.act("world_activity", data)
	close_requested.emit()
