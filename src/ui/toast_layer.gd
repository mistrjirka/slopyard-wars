extends VBoxContainer
const K = preload("res://src/ui/ui_kit.gd")
var _notice_log: Array[String] = []


func show_notice(msg: String) -> void:
	_notice_log.append(msg)
	if _notice_log.size() > 40:
		_notice_log.pop_front()
	var risky := msg.contains("BANG") or msg.contains("Too late") or msg.contains("error") or msg.contains("Cannot") or msg.contains("walked away") or msg.contains("Need ") or msg.contains("refuse") or msg.contains("busy") or msg.contains("Wait ")
	var t := K.panel("ToastRisk" if risky else "Toast")
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := K.lbl(msg, "", K.CREAM, true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(l)
	self.add_child(t)
	while self.get_child_count() > 5:
		var o := self.get_child(0)
		self.remove_child(o)
		o.queue_free()
	var tw := t.create_tween()
	tw.tween_interval(5.5 if risky else 4.5)
	tw.tween_property(t, "modulate:a", 0.0, 0.6)
	tw.tween_callback(t.queue_free)
