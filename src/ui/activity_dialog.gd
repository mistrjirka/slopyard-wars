extends PanelContainer
## Content-driven activity chooser. Sends intents; cannot grant rewards.
signal close_requested
const K = preload("res://src/ui/ui_kit.gd")
const Activities = preload("res://src/world/activities.gd")
var _activity: Resource
var _choice: OptionButton
var _items: Array = []


func setup(activity: Resource) -> void:
	_activity = activity
	custom_minimum_size.x = 560
	theme_type_variation = "Card"
	var box := K.vbox(12)
	add_child(box)
	box.add_child(K.lbl(activity.display_name, "H2", K.LIME))
	box.add_child(K.lbl(activity.description, "", K.CREAM, true))
	box.add_child(K.lbl(Activities.cost_text(activity), "Mono", K.SKY))
	var reason: String = Game.activities.unavailable_reason(Game.me(), activity)
	if activity.kind == "clean":
		_items = Game.activities.eligible_parts(Game.me())
		_choice = OptionButton.new()
		for item: Dictionary in _items:
			_choice.add_item("%s · %d/100" % [item.name, item.condition])
		box.add_child(_choice)
		if _items.is_empty():
			reason = "No eligible parts. Already-serviced and currently listed parts are excluded."
	if reason != "":
		box.add_child(K.lbl(reason, "Muted", K.ORANGE, true))
	var row := K.hbox(8)
	box.add_child(row)
	var use_button := K.btn(activity.action_label, "PrimaryButton", _use)
	use_button.disabled = reason != ""
	row.add_child(use_button)
	row.add_child(K.btn("Maybe later", "GhostButton", func(): close_requested.emit()))


func _use() -> void:
	var data := {"activity_id": str(_activity.id)}
	if is_instance_valid(_choice) and _choice.selected >= 0:
		data["item_id"] = int(_items[_choice.selected].id)
	Game.act("world_activity", data)
	close_requested.emit()
