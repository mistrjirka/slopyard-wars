@tool
extends Button
## A full-width tab with its icon and label centered as one compact group.

@export var title: String = "":
	set(value):
		title = value
		_sync_content()
@export var tab_icon: Texture2D:
	set(value):
		tab_icon = value
		_sync_content()


func _ready() -> void:
	_sync_content()


func _sync_content() -> void:
	if not is_node_ready():
		return
	$Content/Items/Label.text = title
	$Content/Items/Icon.texture = tab_icon
	accessibility_name = title
	custom_minimum_size = $Content.get_combined_minimum_size()


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAW or not is_node_ready():
		return
	var color_name := "font_color"
	match get_draw_mode():
		DRAW_DISABLED: color_name = "font_disabled_color"
		DRAW_PRESSED: color_name = "font_pressed_color"
		DRAW_HOVER: color_name = "font_hover_color"
		DRAW_HOVER_PRESSED: color_name = "font_hover_pressed_color"
		DRAW_NORMAL:
			if has_focus():
				color_name = "font_focus_color"
	$Content/Items.modulate = get_theme_color(color_name)
