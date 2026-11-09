extends Control
## Reusable confirmation and assembly dialogs.
signal notice_requested(message: String)
const K = preload("res://src/ui/ui_kit.gd")
const ActivityDialog = preload("res://src/ui/activity_dialog.gd")
const Assembly = preload("res://src/workshop/assembly.gd")


func open() -> void:
	K.clear(self)
	var dim := ColorRect.new()
	dim.color = Color(K.NAVY0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	visible = true


func close() -> void:
	visible = false
	K.clear(self)


func ask(title: String, text: String, ok_label: String, cb: Callable) -> void:
	open()
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var card := K.panel("CardRisk")
	var v := K.vbox(12)
	v.add_child(K.lbl(title.to_upper(), "H2", K.ORANGE))
	var t := K.lbl(text, "", K.CREAM, true)
	t.custom_minimum_size.x = 440
	v.add_child(t)
	var row := K.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	var cancel := K.btn("CANCEL", "GhostButton", close)
	row.add_child(cancel)
	row.add_child(K.btn(ok_label.to_upper(), "RiskButton", func():
		close()
		cb.call()))
	v.add_child(row)
	card.add_child(v)
	cc.add_child(card)
	cancel.grab_focus()


func open_assembly(item: Dictionary) -> void:
	var me := Game.me()
	if float(me.get("busy", 0.0)) > 0.0:
		notice_requested.emit("The workbench is busy right now.")
		return
	open()
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var card := K.panel("Card")
	var v := K.vbox(8)
	var head := K.hbox(10)
	head.add_child(K.lbl("INSTALLING  %s" % String(item.name), "H2", K.cat_color(item.category)))
	head.add_child(K.spacer())
	var asm: Control = Assembly.new()
	head.add_child(K.btn("ROTATE (R)", "GhostButton", func(): asm.rotate_current()))
	head.add_child(K.btn("CANCEL (ESC)", "GhostButton", close))
	v.add_child(head)
	var frame := K.panel("Inset")
	frame.add_child(asm)
	v.add_child(frame)
	card.add_child(v)
	cc.add_child(card)
	asm.begin(item.duplicate(true))
	var iid: int = int(item.id)
	asm.cancelled.connect(close)
	asm.completed.connect(func(slips: int):
		close()
		Game.act("install", {"item_id": iid})
		if slips == 0:
			notice_requested.emit("Flawless assembly."))


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open_activity(activity: Resource) -> void:
	open()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var dialog := ActivityDialog.new()
	center.add_child(dialog)
	dialog.setup(activity)
	dialog.close_requested.connect(close)
