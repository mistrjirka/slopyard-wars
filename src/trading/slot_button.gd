extends Button
## Player clashes are advisory, never disabling; text carries the count too.
const Trade = preload("res://src/trading/trade_rules.gd")


func setup(slot: Dictionary) -> void:
	var count := int(slot.get("overlap_count", 0))
	var end := int(slot.end) % 1440
	text = "%s%s–%02d:%02d\n%s · %d overlap%s" % ["Proposed: " if slot.get("proposed", false) else "",
		Trade.stamp(float(slot.start)), end / 60, end % 60, str(slot.place), count, "" if count == 1 else "s"]
	tooltip_text = str(slot.label) + "\n%d of your other confirmed meetings overlap this window. You can still choose it." % count
	theme_type_variation = "GhostButton"
	add_theme_font_size_override("font_size", 13)
	custom_minimum_size.y = 52
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	clip_text = true
	if count > 0:
		var tint := Color("ffab57") if count == 1 else Color("ff7373")
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			add_theme_color_override(state, tint)
