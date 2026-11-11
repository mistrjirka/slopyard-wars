extends VBoxContainer
## Authored inbox page and canonical conversation categories, shared with the phone.
enum Category { ACTIVE, AGREED, FINISHED }

signal unfold_requested
signal category_selected(category: Category)

@onready var title_label: Label = $Title
@onready var appointment_label: Label = $Appointment
@onready var scroll: ScrollContainer = $Scroll
@onready var box: VBoxContainer = $Scroll/Box
@onready var empty_label: Label = $Scroll/Box/Empty
@onready var unfold_btn: Button = $UnfoldBtn
@onready var _category_buttons: Array[Button] = [$Categories/Active, $Categories/Agreed, $Categories/Finished]


static func category_name(category: Category) -> String:
	match category:
		Category.ACTIVE:
			return "Active"
		Category.AGREED:
			return "Agreed"
		Category.FINISHED:
			return "Finished"
	return ""


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	unfold_btn.pressed.connect(func() -> void: unfold_requested.emit())
	for category: Category in Category.values():
		_category_buttons[category].pressed.connect(func() -> void: category_selected.emit(category))


func set_category(selected: Category, counts: Array[int], unread: Array[int]) -> void:
	var descriptions: Array[String] = ["Negotiating or awaiting reschedule", "Price, place and time confirmed · pickup pending", "Sold, unavailable or blocked"]
	for category: Category in Category.values():
		var button: Button = _category_buttons[category]
		button.set_pressed_no_signal(category == selected)
		button.text = category_name(category) + (" •" if unread[category] > 0 else "")
		button.tooltip_text = "%s · %d conversations · %d unread messages" % [descriptions[category], counts[category], unread[category]]
	title_label.text = category_name(selected) + " conversations"
	empty_label.text = "No " + category_name(selected).to_lower() + " conversations"


func set_cover_mode(unfolded: bool) -> void:
	unfold_btn.visible = not unfolded


func set_appointment(text: String) -> void:
	appointment_label.visible = text != ""
	appointment_label.text = text


func set_empty_visible(value: bool) -> void:
	empty_label.visible = value
	title_label.visible = not value
