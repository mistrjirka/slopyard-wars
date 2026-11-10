extends VBoxContainer
## Authored inbox page. Phone adds InboxRow instances into Box; this script binds static labels only.
signal unfold_requested

@onready var title_label: Label = $Title
@onready var appointment_label: Label = $Appointment
@onready var scroll: ScrollContainer = $Scroll
@onready var box: VBoxContainer = $Scroll/Box
@onready var empty_label: Label = $Scroll/Box/Empty
@onready var unfold_btn: Button = $UnfoldBtn


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	unfold_btn.pressed.connect(func() -> void: unfold_requested.emit())


func set_cover_mode(unfolded: bool) -> void:
	unfold_btn.visible = not unfolded


func set_appointment(text: String) -> void:
	appointment_label.visible = text != ""
	appointment_label.text = text


func set_empty_visible(value: bool) -> void:
	empty_label.visible = value
	title_label.visible = not value
