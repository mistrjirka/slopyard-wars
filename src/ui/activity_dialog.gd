extends PanelContainer
## Content-driven activity chooser. Sends intents; cannot grant rewards.
signal close_requested
const K = preload("res://src/ui/ui_kit.gd")
const Activities = preload("res://src/world/activities.gd")
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


func setup(activity: Resource) -> void:
	_activity = activity
	_title.text = activity.display_name
	_title.add_theme_color_override("font_color", K.LIME)
	_description.text = activity.description
	_cost.text = Activities.cost_text(activity)
	_cost.add_theme_color_override("font_color", K.SKY)
	var reason: String = Game.activities.unavailable_reason(Game.me(), activity)
	_items = []
	if activity.kind == "clean":
		_items = Game.activities.eligible_parts(Game.me())
		_choice.visible = true
		_choice.clear()
		for item: Dictionary in _items:
			_choice.add_item("%s · %d/100" % [item.name, item.condition])
		if _items.is_empty():
			reason = "No eligible parts. Already-serviced and currently listed parts are excluded."
	else:
		_choice.visible = false
	if reason != "":
		_reason.visible = true
		_reason.text = reason
	else:
		_reason.visible = false
	_use_button.text = activity.action_label
	_use_button.disabled = reason != ""


func _use() -> void:
	var data := {"activity_id": str(_activity.id)}
	if is_instance_valid(_choice) and _choice.visible and _choice.selected >= 0 and _choice.selected < _items.size():
		data["item_id"] = int(_items[_choice.selected].id)
	Game.act("world_activity", data)
	close_requested.emit()
