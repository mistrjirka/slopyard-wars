extends Button
## Authored inbox thread row, shared by the inbox and unfolded conversation sidebar.
@onready var seller_label: Label = $Rows/Seller
@onready var title_label: Label = $Rows/Title
@onready var preview_label: Label = $Rows/Preview


func setup(seller: String, is_buyer: bool, title: String, preview: String) -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	clip_text = true
	custom_minimum_size.y = 82
	seller_label.text = seller + (" · BUYER" if is_buyer else "")
	title_label.text = title
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	preview_label.text = preview
	preview_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	tooltip_text = seller_label.text + "\n" + title + "\n" + preview


func set_current(current: bool) -> void:
	theme_type_variation = "CurrentThread" if current else ""
	accessibility_description = "Current conversation" if current else ""
