extends VBoxContainer
## Compact quick responses. IDs, never button prose, are sent to the host.
signal slot_chosen(meeting_id: String)

const SlotButtonScene = preload("res://src/trading/slot_button.tscn")

@onready var choices: VBoxContainer = $ChoicesScroll/ChoicesCompact


func setup(options: Array, can_choose: bool = true) -> void:
	visible = not options.is_empty()
	$Hint.text = "Choose a time & place · Not reserved" if can_choose else "Proposed times · Agree a price in chat first"
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	for slot: Dictionary in options:
		var button: Button = SlotButtonScene.instantiate()
		choices.add_child(button)
		button.setup(slot)
		button.disabled = not can_choose
		var id := str(slot.id)
		button.pressed.connect(func() -> void: slot_chosen.emit(id))
