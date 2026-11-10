extends VBoxContainer
## Meeting choices use host-provided canonical options and current action permission.
signal toggle_requested
signal track_requested
signal slot_chosen(label: String)

const SlotButtonScene = preload("res://src/trading/slot_button.tscn")

@onready var toggle_btn: Button = $ToggleRow/ToggleBtn
@onready var track_btn: Button = $ToggleRow/TrackBtn
@onready var choices: VBoxContainer = $Choices
@onready var choices_scroll: ScrollContainer = $ChoicesScroll
@onready var choices_compact: VBoxContainer = $ChoicesScroll/ChoicesCompact
@onready var empty_label: Label = $Empty
var _can_schedule := false


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_btn.pressed.connect(func() -> void:
		if _can_schedule:
			toggle_requested.emit())
	track_btn.pressed.connect(func() -> void:
		if track_btn.visible:
			track_requested.emit())


func setup(options: Array, has_meeting: bool, expanded: bool, compact: bool, can_schedule: bool = true) -> void:
	_can_schedule = can_schedule
	track_btn.visible = has_meeting
	toggle_btn.disabled = not can_schedule
	toggle_btn.text = "Hide times" if expanded and can_schedule else "Meeting times"
	var show_choices := expanded and can_schedule
	var host := choices_compact if compact else choices
	choices.visible = show_choices and not compact and not options.is_empty()
	choices_scroll.visible = show_choices and compact and not options.is_empty()
	empty_label.visible = show_choices and options.is_empty()
	for container in [choices, choices_compact]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	if not show_choices:
		return
	for slot: Dictionary in options:
		var b: Button = SlotButtonScene.instantiate()
		b.text = str(slot.label)
		b.theme_type_variation = "GhostButton"
		b.add_theme_font_size_override("font_size", 13)
		b.custom_minimum_size.y = 44
		b.clip_text = true
		b.tooltip_text = str(slot.label)
		var label := str(slot.label)
		b.pressed.connect(func() -> void:
			if _can_schedule:
				slot_chosen.emit(label))
		host.add_child(b)
