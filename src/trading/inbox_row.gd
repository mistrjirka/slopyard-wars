extends Button
## Authored inbox thread row, shared by the inbox and unfolded conversation sidebar.
@onready var seller_label: Label = $Rows/Seller
@onready var title_label: Label = $Rows/Title
@onready var preview_label: Label = $Rows/Preview
@onready var _meeting_badge: PanelContainer = $MeetingBadge
@onready var _unread_dot: Panel = $UnreadDot
var _current := false
var _unread_count := 0
var _base_tooltip := ""


func setup(seller: String, is_buyer: bool, title: String, preview: String) -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	clip_text = true
	custom_minimum_size.y = 82
	seller_label.text = seller + (" · BUYER" if is_buyer else "")
	title_label.text = title
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	preview_label.text = preview
	preview_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_base_tooltip = seller_label.text + "\n" + title + "\n" + preview
	tooltip_text = _base_tooltip


func set_current(current: bool) -> void:
	_current = current
	theme_type_variation = "CurrentThread" if current else ""
	_update_description()


func set_meeting_confirmed(confirmed: bool) -> void:
	_meeting_badge.visible = confirmed
	_update_description()


func set_unread(count: int) -> void:
	_unread_count = count
	_unread_dot.visible = count > 0
	_update_description()


func _update_description() -> void:
	$Rows.offset_right = -44.0 if _meeting_badge.visible or _unread_dot.visible else -14.0
	_unread_dot.position.y = 54.0 if _meeting_badge.visible else 35.0
	var unread := "%d unread message%s." % [_unread_count, "" if _unread_count == 1 else "s"] if _unread_count > 0 else ""
	var meeting := "Meeting confirmed." if _meeting_badge.visible else ""
	tooltip_text = _base_tooltip + ("\n" + meeting if meeting != "" else "") + ("\n" + unread if unread != "" else "")
	accessibility_description = ("Current conversation. " if _current else "") + unread + " " + meeting
