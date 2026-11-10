extends Control
## Reusable confirmation and assembly dialogs.
signal notice_requested(message: String)
const K = preload("res://src/ui/ui_kit.gd")
const World = preload("res://src/world/world_rules.gd")
const ActivityDialogScene = preload("res://src/ui/activity_dialog.tscn")
const ConfirmationDialogScene = preload("res://src/ui/confirmation_dialog.tscn")
const AssemblyDialogScene = preload("res://src/ui/assembly_dialog.tscn")
const AssemblyScene = preload("res://src/workshop/assembly.tscn")


var _assembly: Control
var _assembly_id := -1

@onready var _backdrop: ColorRect = $Backdrop
@onready var _center: CenterContainer = $Center


func _ready() -> void:
	visible = false
	if is_instance_valid(_backdrop):
		_backdrop.visible = false
	Game.changed.connect(_synchronize_assembly)


func open() -> void:
	if is_instance_valid(_backdrop):
		_backdrop.visible = true
	visible = true
	_clear_center()


func close() -> void:
	visible = false
	if is_instance_valid(_backdrop):
		_backdrop.visible = false
	_clear_center()


func _clear_center() -> void:
	_assembly = null
	_assembly_id = -1
	if not is_instance_valid(_center):
		return
	for c in _center.get_children():
		_center.remove_child(c)
		c.queue_free()


func ask(title: String, text: String, ok_label: String, cb: Callable) -> void:
	open()
	var dlg: PanelContainer = ConfirmationDialogScene.instantiate()
	_center.add_child(dlg)
	var title_lbl: Label = dlg.get_node("Box/Title")
	title_lbl.text = title.to_upper()
	title_lbl.add_theme_color_override("font_color", K.ORANGE)
	var text_lbl: Label = dlg.get_node("Box/Text")
	text_lbl.text = text
	text_lbl.custom_minimum_size.x = 440
	var cancel: Button = dlg.get_node("Box/Buttons/Cancel")
	cancel.pressed.connect(close)
	var ok: Button = dlg.get_node("Box/Buttons/Ok")
	ok.text = ok_label.to_upper()
	ok.pressed.connect(func():
		close()
		cb.call())
	cancel.grab_focus()


func open_assembly(item: Dictionary) -> void:
	var me := Game.me()
	if Game.state.get("phase") != "playing" or me.is_empty():
		return
	if bool(me.get("ready", false)):
		notice_requested.emit("Your rig is locked for the benchmark.")
		return
	if me.area != "home" or bool(me.get("driving", false)) or Vector2(me.pos).distance_to(World.BENCH) > 58:
		notice_requested.emit("Return home and walk to the workbench first.")
		return
	if float(me.get("busy", 0.0)) > 0.0:
		notice_requested.emit("The workbench is busy right now.")
		return
	# A disabled inventory button is only an affordance: validate current state at launch too.
	var owned := _owned_part(int(item.get("id", -1)))
	if owned.is_empty():
		notice_requested.emit("You do not own that part.")
		return
	for listing: Dictionary in Game.state.get("listings", []):
		if int(listing.get("owner", 0)) == Game.local_id() and int(listing.get("item_id", -1)) == int(owned.id) and listing.get("status") == "available":
			notice_requested.emit("Cancel the sale listing before installing this part.")
			return
	var why := Game.compatibility(owned, me)
	if why != "":
		notice_requested.emit("Cannot install: " + why)
		return
	open()
	var dlg: PanelContainer = AssemblyDialogScene.instantiate()
	_center.add_child(dlg)
	var mounted: Dictionary = me.get("installed", {}).get(owned.category, {})
	var reinstall := int(mounted.get("id", -1)) == int(owned.id)
	var title: Label = dlg.get_node("Box/Head/Title")
	title.text = "%s  %s" % ["REINSTALLING" if reinstall else "INSTALLING", String(owned.name)]
	title.add_theme_color_override("font_color", K.cat_color(owned.category))
	var rotate_btn: Button = dlg.get_node("Box/Head/Rotate")
	var cancel_btn: Button = dlg.get_node("Box/Head/Cancel")
	cancel_btn.pressed.connect(close)
	var frame: PanelContainer = dlg.get_node("Box/Frame")
	_assembly = AssemblyScene.instantiate()
	frame.add_child(_assembly)
	var iid: int = int(owned.id)
	_assembly_id = iid
	rotate_btn.pressed.connect(_assembly.rotate_current)
	_assembly.stage_changed.connect(func(): rotate_btn.visible = is_instance_valid(_assembly) and _assembly.rotation_available())
	_assembly.cancelled.connect(close)
	_assembly.damage_requested.connect(func(damaged_id: int, strike: int, reason: String):
		Game.act("assembly_damage", {"item_id": damaged_id, "assembly_item_id": iid, "strike": strike, "reason": reason}))
	_assembly.completed.connect(func(result: Dictionary):
		close()
		Game.act("install", {"item_id": iid, "mount_quality": result.mount_quality, "paste_amount": result.paste_amount,
			"screws_seated": result.screws_seated, "supports": result.supports}))
	_assembly.begin(owned, {"installed": me.installed, "modifiers": me.get("workshop_modifiers", {}),
		"reinstall": reinstall})


func _owned_part(id: int) -> Dictionary:
	var me := Game.me()
	for part: Dictionary in me.get("inventory", []):
		if int(part.get("id", -1)) == id:
			return part
	for part: Dictionary in me.get("installed", {}).values():
		if int(part.get("id", -1)) == id:
			return part
	return {}


func _synchronize_assembly() -> void:
	if not is_instance_valid(_assembly):
		return
	if Game.state.get("phase") != "playing":
		close()
		return
	var part := _owned_part(_assembly_id)
	if not part.is_empty():
		_assembly.synchronize(part, Game.me().get("installed", {}), Game.me().get("workshop_modifiers", {}))
	elif _assembly.has_pending_fatal_damage():
		_assembly.mark_destroyed("", Game.me().get("workshop_modifiers", {}))
	else:
		close()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open_activity(activity: Resource) -> void:
	open()
	var dialog: Control = ActivityDialogScene.instantiate()
	_center.add_child(dialog)
	dialog.setup(activity)
	dialog.close_requested.connect(close)
