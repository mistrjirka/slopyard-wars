extends HBoxContainer
## Workbench: rig slots, inventory with compatibility, build checklist, power budget, finish.
const K = preload("res://src/ui/ui_kit.gd")
const SlotCardScene = preload("res://src/workshop/slot_card.tscn")
const InventoryCardScene = preload("res://src/workshop/inventory_card.tscn")
const BurntPanelScene = preload("res://src/workshop/burnt_panel.tscn")
const EmptyInventoryPanelScene = preload("res://src/workshop/empty_inventory_panel.tscn")
const ChecklistRowScene = preload("res://src/workshop/checklist_row.tscn")
const RigRules = preload("res://src/workshop/rig_rules.gd")
const Catalog = preload("res://src/data/catalog.gd")
const Overclock = preload("res://src/workshop/overclock_rules.gd")
const Stats = preload("res://src/data/hardware_stats.gd")

signal install_requested(item: Dictionary)
signal go_market
signal go_tuning
var ask: Callable = Callable()

const ORDER: Array = ["case", "motherboard", "cpu", "gpu", "ram", "psu", "storage"]
const NEED_HINT := {
	"case": "Buy a case first. An ATX board needs an ATX case.",
	"motherboard": "Board socket must match the CPU, memory type must match the RAM.",
	"cpu": "Pick the CPU socket your board has (OX3 / OX4 / NX5 / LX7).",
	"gpu": "Optional if CPU has integrated graphics AND the board has video outputs.",
	"ram": "Use the memory type your board takes (DDR3 / DDR4 / DDR5).",
	"psu": "Capacity must exceed the rig's draw (watch the power meter).",
	"storage": "Required: storage is a benchmark category.",
}

var _sig: String = ""
var _install_btns: Array = []

@onready var _slots_box: VBoxContainer = $RigColumn/RigScroll/SlotsBox
@onready var _inv_box: VBoxContainer = $InventoryColumn/InventoryScroll/InvBox
@onready var _check_box: VBoxContainer = $CheckColumn/CheckScroll/CheckHolder/CheckCard/CardBox/CheckBox
@onready var _checklist_success: Label = $CheckColumn/CheckScroll/CheckHolder/CheckCard/CardBox/ChecklistSuccess
@onready var _checklist_hint: Label = $CheckColumn/CheckScroll/CheckHolder/CheckCard/CardBox/ChecklistHint
@onready var _power_bar: ProgressBar = $CheckColumn/CheckScroll/CheckHolder/PowerPanel/PowerBox/PowerBar
@onready var _power_lbl: Label = $CheckColumn/CheckScroll/CheckHolder/PowerPanel/PowerBox/PowerLabel
@onready var _busy_lbl: Label = $CheckColumn/CheckScroll/CheckHolder/BusyLabel
@onready var _finish_btn: Button = $CheckColumn/CheckScroll/CheckHolder/FinishButton
@onready var _score_lbl: Label = $CheckColumn/CheckScroll/CheckHolder/ScorePanel/ScoreBox/ScoreLabel
@onready var _tuning_button: Button = $CheckColumn/CheckScroll/CheckHolder/TuningButton


func _ready() -> void:
	_finish_btn.pressed.connect(_finish)
	_tuning_button.pressed.connect(func(): go_tuning.emit())


func _me() -> Dictionary:
	return Game.me()


func tick() -> void:
	if not is_visible_in_tree():
		return
	var me := _me()
	var busy: float = float(me.get("busy", 0.0))
	var driving: bool = bool(me.get("driving", false))
	var locked: bool = bool(me.get("ready", false))
	for entry in _install_btns:
		var btn: Button = entry[0]
		if is_instance_valid(btn):
			btn.visible = entry[1] == "" and not driving and not locked
			btn.disabled = busy > 0.0 or entry[1] != ""
	if locked:
		_busy_lbl.text = "Rig locked. Waiting for the match to end."
	elif driving:
		_busy_lbl.text = "You are out driving - the workbench is unavailable until you return home."
	elif busy > 0.0:
		_busy_lbl.text = "Workbench busy: %d game min left (installing/stress testing)." % ceili(busy)
	else:
		_busy_lbl.text = ""


func refresh() -> void:
	if not is_visible_in_tree():
		return
	var me := _me()
	var inst: Dictionary = me.get("installed", {})
	var parts := PackedStringArray()
	for k in inst:
		parts.append("%s%d" % [k, int(inst[k].id)])
	for it in me.get("inventory", []):
		parts.append("i%d" % int(it.id))
	for listing: Dictionary in Game.state.get("listings", []):
		if int(listing.get("owner", 0)) == Game.local_id() and listing.get("status") == "available":
			parts.append("sale%d" % int(listing.get("item_id", -1)))
	var sig := "%s|%s|%s|%s|%s|%s" % [",".join(parts), str(me.get("tuning", {})) + str(me.get("workshop_modifiers", {})) + str(inst) + str(me.get("inventory", [])), str(me.get("ready", false)), str(me.get("destroyed", []).size()), str(Game.state.objective), str(not bool(me.get("driving", false)))]
	if sig == _sig:
		tick()
		return
	_sig = sig
	_rebuild(me)
	tick()


func _rebuild(me: Dictionary) -> void:
	var inst: Dictionary = me.get("installed", {})
	var tun: Dictionary = me.get("tuning", {})
	_install_btns.clear()
	K.clear(_slots_box)
	for c in ORDER:
		var card: PanelContainer = SlotCardScene.instantiate()
		# @onready members only exist once the card is in the tree.
		_slots_box.add_child(card)
		var col := K.cat_color(c)
		card.category_label.text = String(K.CAT_LABEL[c])
		card.category_label.add_theme_color_override("font_color", col)
		if inst.has(c):
			card.art.show_item(inst[c])
			var it: Dictionary = inst[c]
			card.name_label.text = String(it.name)
			card.spec_label.text = _part_summary(it)
			card.tooltip_text = Catalog.spec_text(it, false)
			if c in RigRules.TUNABLE and tun.has(c):
				card.oc_label.text = "OC x%.2f clock @ %.2f V" % [tun[c].clock, tun[c].voltage]
				card.oc_label.add_theme_color_override("font_color", K.ORANGE)
				card.oc_label.visible = true
			else:
				card.oc_label.visible = false
			var why := _installation_reason(it, me)
			card.ok_pill.visible = why == ""
			card.reinstall_button.visible = why == ""
			card.reinstall_button.disabled = why != ""
			card.reinstall_button.pressed.connect(func(): install_requested.emit(it))
			_install_btns.append([card.reinstall_button, why])
			card.penalty_label.text = _installation_penalties(it, me)
			if why != "":
				card.penalty_label.text += ("\n" if card.penalty_label.text != "" else "") + why
			card.penalty_label.visible = card.penalty_label.text != ""
		else:
			card.art.show_item({"category": c, "name": ""}, true)
			card.name_label.text = "EMPTY"
			card.name_label.add_theme_color_override("font_color", K.FAINT)
			card.spec_label.text = String(NEED_HINT[c])
			card.oc_label.visible = false
			card.ok_pill.visible = false
	var destroyed: Array = me.get("destroyed", [])
	if not destroyed.is_empty():
		var dp: PanelContainer = BurntPanelScene.instantiate()
		_slots_box.add_child(dp)
		dp.get_node("Box/TitleLabel").add_theme_color_override("font_color", K.DANGER)
		dp.items_label.text = "\n".join(PackedStringArray(destroyed.map(func(x): return String(x))))
		dp.items_label.add_theme_color_override("font_color", K.CREAM)
	# inventory
	K.clear(_inv_box)
	var inv: Array = me.get("inventory", [])
	if inv.is_empty():
		var e: PanelContainer = EmptyInventoryPanelScene.instantiate()
		_inv_box.add_child(e)
		e.phone_button.pressed.connect(func(): go_market.emit())
	for it in inv:
		_inv_card(it, me)
	# checklist
	K.clear(_check_box)
	var issues: Array = Game.build_issues(me)
	if issues.is_empty():
		_checklist_success.visible = true
		_checklist_hint.visible = false
		_checklist_success.add_theme_color_override("font_color", K.LIME)
	else:
		_checklist_success.visible = false
		_checklist_hint.visible = true
		for i in issues:
			var row: HBoxContainer = ChecklistRowScene.instantiate()
			_check_box.add_child(row)
			row.mark_label.add_theme_color_override("font_color", K.DANGER)
			row.text_label.text = String(i)
			row.text_label.add_theme_color_override("font_color", K.CREAM)
	# power
	var cap := 0
	if inst.has("psu"):
		cap = int(inst.psu.capacity)
	var draw: int = RigRules.power_draw(inst, tun)
	_power_bar.max_value = maxf(100.0, float(maxi(cap, draw)))
	_power_bar.value = draw
	_power_bar.theme_type_variation = "RiskBar" if draw > cap else ""
	_power_lbl.text = ("Draw about %dW of %dW PSU capacity." % [draw, cap]) if cap > 0 else "Draw about %dW. No PSU installed yet." % draw
	_tuning_button.visible = RigRules.TUNABLE.any(func(category: String): return inst.has(category))
	var sc: Dictionary = Game.preview_score(me)
	_score_lbl.text = "CPU      %5d\nGPU      %5d\nRAM      %5d\nSTORAGE  %5d\nTOTAL    %5d%s" % [sc.cpu, sc.gpu, sc.ram, sc.storage, sc.total, "" if sc.valid else "  (rig invalid = 0)"]
	_finish_btn.disabled = bool(me.get("ready", false))
	_finish_btn.text = "RIG LOCKED" if bool(me.get("ready", false)) else ("FINISH & RUN BENCHMARK" if issues.is_empty() else "FINISH ANYWAY (SCORE 0)")


func _inv_card(it: Dictionary, me: Dictionary) -> void:
	var card: PanelContainer = InventoryCardScene.instantiate()
	# @onready members only exist once the card is in the tree.
	_inv_box.add_child(card)
	card.art.show_item(it)
	card.name_label.text = String(it.name)
	card.spec_label.text = _part_summary(it)
	card.tooltip_text = Catalog.spec_text(it, false)
	var why := _installation_reason(it, me)
	var inst: Dictionary = me.get("installed", {})
	var status_text := ""
	var status_color := K.MUTED
	if why == "":
		if inst.has(it.category):
			status_text = "Replaces %s (old part returns here)." % inst[it.category].name
			status_color = K.SKY
		else:
			status_text = "Compatible - ready to install."
			status_color = K.LIME
	else:
		status_text = why + "."
		status_color = K.ORANGE if why.begins_with("Install a") or why.begins_with("Cancel") else K.DANGER
	var strikes := int(it.get("assembly_strikes", 0))
	if strikes > 0:
		status_text += " Assembly damage %d/5; retrying does not reset it." % strikes
	card.status_label.text = status_text
	card.status_label.add_theme_color_override("font_color", status_color)
	card.install_button.theme_type_variation = "PrimaryButton" if why == "" else "GhostButton"
	card.install_button.pressed.connect(func(): install_requested.emit(it))
	_install_btns.append([card.install_button, why])
	if why != "":
		card.install_button.disabled = true


func _installation_reason(part: Dictionary, player: Dictionary) -> String:
	var why := Game.compatibility(part, player)
	if why != "":
		return why
	for listing: Dictionary in Game.state.get("listings", []):
		if int(listing.get("owner", 0)) == Game.local_id() and int(listing.get("item_id", -1)) == int(part.id) and listing.get("status") == "available":
			return "Cancel the sale listing before installing this part"
	return ""


func _part_summary(part: Dictionary) -> String:
	var details: Array[String] = []
	match str(part.get("category", "")):
		"case": details.append("%s · airflow %d/100" % [part.get("form", ""), part.get("support_quality", 50)])
		"motherboard": details.append("%s · %s · %s" % [part.get("socket", ""), part.get("memory", ""), part.get("form", "")])
		"cpu": details.append("%s · %dW · %s" % [part.get("socket", ""), part.get("watts", 0), "integrated graphics" if part.get("integrated", false) else "needs GPU"])
		"gpu": details.append("%dW · stock score %d" % [part.get("watts", 0), part.get("gpu", 0)])
		"ram": details.append("%s · stock score %d" % [part.get("memory", ""), part.get("ram", 0)])
		"storage": details.append("Stock score %d" % part.get("storage", 0))
		"psu": details.append("%dW · regulation %d/100" % [part.get("capacity", 0), part.get("support_quality", 50)])
	details.append("Condition %d/100" % part.get("condition", 100))
	if Stats.has_inherent_risk(part):
		details.append("Intrinsic reliability risk — hover for details")
	return "\n".join(details)


func _installation_penalties(part: Dictionary, player: Dictionary) -> String:
	var lines: Array[String] = []
	var strikes := int(part.get("assembly_strikes", 0))
	if strikes > 0:
		lines.append("Damage %d/5 · condition %d/100" % [strikes, part.get("condition", 100)])
	if part.get("category") == "cpu":
		var assessment := Overclock.evaluate(part, 1.0, 1.0, player.installed, player.get("workshop_modifiers", {}))
		var paste_loss := roundi((1.0 - float(assessment.paste_multiplier)) * 100)
		var mount_loss := roundi((1.0 - float(assessment.mount_headroom_multiplier)) * 100)
		if paste_loss > 0:
			lines.append("Paste: −%d%% CPU performance" % paste_loss)
		if mount_loss > 0:
			lines.append("Uneven mount: −%d%% OC headroom, +%.0f°C" % [mount_loss, assessment.mount_temperature_penalty])
		if paste_loss > 0 or mount_loss > 0:
			lines.append("Reinstall to correct these penalties.")
	return "\n".join(lines)


func _finish() -> void:
	var me := _me()
	var issues: Array = Game.build_issues(me)
	var msg := "Locks your rig and submits it to the benchmark. "
	if issues.is_empty():
		msg += "Your build is valid."
		var tests := Overclock.final_tests(me.installed, me.tuning, me.workshop_modifiers)
		if not tests.is_empty():
			msg += "\n\nFINAL RELIABILITY TESTS (in order; stop if the rig cannot run):"
			for test: Dictionary in tests:
				var risk: Dictionary = test.result
				msg += "\n%s: %.1f%% destruction chance; %d condition wear if it survives." % [me.installed[test.category].name, risk.damage_chance * 100, risk.wear]
				if risk.fire_chance > 0:
					msg += " Includes %.1f%% CONNECTOR FIRE risk." % (risk.fire_chance * 100)
				if risk.uses_luck:
					msg += " Lucky's reduction is included; this test consumes the blessing."
			msg += "\nDestroyed parts are removed before scoring. A lost GPU can fall back to integrated graphics; a rig that cannot boot scores zero."
		msg += "\n\nUnused cash does not add score. Finish now?"
	else:
		msg += "Your build is INCOMPLETE and will score ZERO:\n- " + "\n- ".join(issues.slice(0, 4)) + "\n\nFinish anyway?"
	if ask.is_valid():
		ask.call("Finish and benchmark?", msg, "Finish", func(): Game.act("finish", {}))
	else:
		Game.act("finish", {})
