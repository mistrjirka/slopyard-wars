extends HBoxContainer
## Sender names and aligned bubbles keep each side of the conversation clear.
@onready var bubble: PanelContainer = $Bubble
@onready var label: Label = $Bubble/Content/Label
@onready var header_label: Label = $Bubble/Content/Header
@onready var place_label: Label = $Bubble/Content/Place


func text_line_bounds() -> Array[Rect2]:
	var lines: Array[Rect2] = []
	for text_label: Label in [header_label, place_label, label]:
		if not text_label.visible:
			continue
		for index in text_label.text.length():
			var bounds := text_label.get_character_bounds(index)
			if not bounds.has_area():
				continue
			bounds.position += text_label.global_position
			if not lines.is_empty() and bounds.position.y < lines[-1].end.y and bounds.end.y > lines[-1].position.y:
				lines[-1] = lines[-1].merge(bounds)
			else:
				lines.append(bounds)
	return lines


func setup(msg: Dictionary, me_name: String, full_width: bool = false) -> void:
	var speaker := str(msg.get("speaker", ""))
	var mine := speaker == me_name
	var system := speaker == "system"
	var pending := bool(msg.get("pending", false))
	bubble.theme_type_variation = "BubblePending" if pending or system else ("BubbleMe" if mine else "BubbleThem")
	header_label.text = str(msg.get("header", speaker))
	header_label.visible = not header_label.text.is_empty()
	# Pale blue stays readable on the player's blue bubbles.
	header_label.add_theme_color_override("font_color", Color("d9edff") if mine and not pending else Color("6fb4ff"))
	var place := str(msg.get("place", ""))
	place_label.text = "From " + place
	place_label.visible = header_label.visible and not place.is_empty()
	label.text = str(msg.get("text", "")) + ("\nSending…" if pending and mine else "")
	label.add_theme_color_override("font_color", Color.WHITE if mine and not pending else Color("e6edf5"))
	alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
	if system and not pending:
		alignment = BoxContainer.ALIGNMENT_CENTER
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL if full_width else Control.SIZE_FILL
	if full_width:
		return
	var fit := func() -> void:
		if is_instance_valid(bubble) and is_inside_tree():
			var natural_width := 0.0
			for text_label: Label in [header_label, place_label, label]:
				if text_label.visible:
					var font := text_label.get_theme_font("font")
					natural_width = maxf(natural_width, font.get_multiline_string_size(text_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_label.get_theme_font_size("font_size")).x)
			var padding := bubble.get_theme_stylebox("panel").get_minimum_size().x
			var limit := maxf(60.0, size.x * (0.88 if system and not pending else 0.72))
			bubble.custom_minimum_size.x = clampf(natural_width + padding, 60.0, limit)
	resized.connect(fit)
	fit.call_deferred()
