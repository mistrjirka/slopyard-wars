extends HBoxContainer
## Workbench: rig slots, inventory with compatibility, build checklist, power budget, finish.
const K = preload("res://src/ui/ui_kit.gd")
const PartArt = preload("res://src/ui/part_art.gd")
const RigRules = preload("res://src/workshop/rig_rules.gd")
const Catalog = preload("res://src/data/catalog.gd")
const Overclock = preload("res://src/workshop/overclock_rules.gd")

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

var _slots_box: VBoxContainer
var _inv_box: VBoxContainer
var _check_box: VBoxContainer
var _power_bar: ProgressBar
var _power_lbl: Label
var _busy_lbl: Label
var _finish_btn: Button
var _score_lbl: Label
var _sig: String = ""
var _install_btns: Array = []


func _init() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var a := K.vbox(6)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.size_flags_stretch_ratio = 1.0
	a.custom_minimum_size.x = 340
	a.add_child(K.lbl("YOUR RIG", "H2"))
	a.add_child(K.lbl("Install order: case, then motherboard, then everything else (PSU needs only the case).", "Muted", null, true))
	var sa := K.scroll()
	a.add_child(sa)
	_slots_box = K.vbox(8)
	_slots_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sa.add_child(_slots_box)
	add_child(a)
	var b := K.vbox(6)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = 1.15
	b.custom_minimum_size.x = 380
	b.add_child(K.lbl("INVENTORY", "H2"))
	var sb := K.scroll()
	b.add_child(sb)
	_inv_box = K.vbox(8)
	_inv_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sb.add_child(_inv_box)
	add_child(b)
	var c := K.vbox(8)
	c.custom_minimum_size.x = 330
	c.size_flags_horizontal = Control.SIZE_FILL
	c.add_child(K.lbl("BUILD CHECK", "H2"))
	var sc := K.scroll()
	c.add_child(sc)
	var cv := K.vbox(10)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(cv)
	_check_box = K.vbox(6)
	var cp := K.panel("Card")
	cp.add_child(_check_box)
	cv.add_child(cp)
	var pp := K.panel("Card")
	var pv := K.vbox(4)
	pv.add_child(K.lbl("POWER BUDGET", "Eyebrow"))
	_power_bar = ProgressBar.new()
	_power_bar.custom_minimum_size.y = 16
	_power_bar.show_percentage = false
	pv.add_child(_power_bar)
	_power_lbl = K.lbl("", "Muted", null, true)
	pv.add_child(_power_lbl)
	pp.add_child(pv)
	cv.add_child(pp)
	var sp := K.panel("Card")
	var sv := K.vbox(4)
	sv.add_child(K.lbl("BENCHMARK PREVIEW", "Eyebrow"))
	_score_lbl = K.lbl("", "Mono", null, true)
	sv.add_child(_score_lbl)
	sp.add_child(sv)
	cv.add_child(sp)
	_busy_lbl = K.lbl("", "Tiny", K.ORANGE, true)
	cv.add_child(_busy_lbl)
	_finish_btn = K.btn("FINISH & RUN BENCHMARK", "RiskButton", _finish)
	cv.add_child(_finish_btn)
	cv.add_child(K.lbl("Finishing locks your rig. Tune CPU/GPU/RAM first (TUNING tab) if you want more score.", "Tiny", K.MUTED, true))
	add_child(c)


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
		if is_instance_valid(btn) and entry[1] == "":
			btn.disabled = busy > 0.0 or driving or locked
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
	K.clear(_slots_box)
	for c in ORDER:
		var p := K.panel("CardTight")
		var h := K.hbox(10)
		var art: Control = PartArt.new()
		art.custom_minimum_size = Vector2(72, 50)
		var col := K.cat_color(c)
		if inst.has(c):
			art.show_item(inst[c])
		else:
			art.show_item({"category": c, "name": ""}, true)
		h.add_child(art)
		var v := K.vbox(1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(K.lbl(String(K.CAT_LABEL[c]), "Eyebrow", col))
		if inst.has(c):
			var it: Dictionary = inst[c]
			var n := K.lbl(String(it.name), "Mono", null, true)
			v.add_child(n)
			v.add_child(K.lbl(Catalog.spec_text(it), "Tiny", null, true))
			if c in RigRules.TUNABLE and tun.has(c):
				v.add_child(K.lbl("OC x%.2f clock @ %.2f V" % [tun[c].clock, tun[c].voltage], "Tiny", K.ORANGE))
		else:
			v.add_child(K.lbl("EMPTY", "Mono", K.FAINT))
			v.add_child(K.lbl(String(NEED_HINT[c]), "Tiny", K.MUTED, true))
		h.add_child(v)
		if inst.has(c):
			h.add_child(K.pill("OK", K.LIME))
		p.add_child(h)
		_slots_box.add_child(p)
	var destroyed: Array = me.get("destroyed", [])
	if not destroyed.is_empty():
		var dp := K.panel("CardRisk")
		var dv := K.vbox(2)
		dv.add_child(K.lbl("BURNT OUT", "Eyebrow", K.DANGER))
		for d in destroyed:
			dv.add_child(K.lbl(String(d), "Tiny", K.CREAM, true))
		dv.add_child(K.lbl("Destroyed parts are gone for good. Buy a replacement.", "Tiny", K.MUTED, true))
		dp.add_child(dv)
		_slots_box.add_child(dp)
	# inventory
	K.clear(_inv_box)
	_install_btns.clear()
	var inv: Array = me.get("inventory", [])
	if inv.is_empty():
		var e := K.panel("Inset")
		var ev := K.vbox(6)
		ev.add_child(K.lbl("Nothing in your parts box yet.", "Mono"))
		ev.add_child(K.lbl("Use your phone to agree price, time and place; drive to the meeting and complete the handoff. Collected parts land here.", "Muted", null, true))
		ev.add_child(K.btn("OPEN PHONE", "GhostButton", func(): go_market.emit()))
		e.add_child(ev)
		_inv_box.add_child(e)
	for it in inv:
		_inv_box.add_child(_inv_card(it, me))
	# checklist
	K.clear(_check_box)
	_check_box.add_child(K.lbl("CHECKLIST", "Eyebrow"))
	var issues: Array = Game.build_issues(me)
	if issues.is_empty():
		_check_box.add_child(K.lbl("All requirements met. The rig can be benchmarked.", "Mono", K.LIME, true))
	else:
		for i in issues:
			var r := K.hbox(6)
			r.add_child(K.lbl("x", "Mono", K.DANGER))
			r.add_child(K.lbl(String(i), "Muted", K.CREAM, true))
			_check_box.add_child(r)
		_check_box.add_child(K.lbl("Wrong socket or memory type? Sell the spare using your phone, or buy a compatible board/CPU/RAM and swap it in.", "Tiny", K.ORANGE, true))
	# power
	var cap := 0
	if inst.has("psu"):
		cap = int(inst.psu.capacity)
	var draw: int = RigRules.power_draw(inst, tun)
	_power_bar.max_value = maxf(100.0, float(maxi(cap, draw)))
	_power_bar.value = draw
	_power_bar.theme_type_variation = "RiskBar" if draw > cap else ""
	_power_lbl.text = ("Draw about %dW of %dW PSU capacity." % [draw, cap]) if cap > 0 else "Draw about %dW. No PSU installed yet." % draw
	var sc: Dictionary = Game.preview_score(me)
	_score_lbl.text = "CPU      %5d\nGPU      %5d\nRAM      %5d\nSTORAGE  %5d\nTOTAL    %5d%s" % [sc.cpu, sc.gpu, sc.ram, sc.storage, sc.total, "" if sc.valid else "  (rig invalid = 0)"]
	_finish_btn.disabled = bool(me.get("ready", false))
	_finish_btn.text = "RIG LOCKED" if bool(me.get("ready", false)) else ("FINISH & RUN BENCHMARK" if issues.is_empty() else "FINISH ANYWAY (SCORE 0)")


func _inv_card(it: Dictionary, me: Dictionary) -> Control:
	var p := K.panel("CardTight")
	var h := K.hbox(10)
	var art: Control = PartArt.new()
	art.custom_minimum_size = Vector2(84, 58)
	art.show_item(it)
	h.add_child(art)
	var v := K.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(K.lbl(String(it.name), "Mono", null, true))
	v.add_child(K.lbl(Catalog.spec_text(it), "Tiny", null, true))
	var why: String = Game.compatibility(it, me)
	var inst: Dictionary = me.get("installed", {})
	if why == "":
		if inst.has(it.category):
			v.add_child(K.lbl("Replaces %s (old part returns here)." % inst[it.category].name, "Tiny", K.SKY, true))
		else:
			v.add_child(K.lbl("Compatible - ready to install.", "Tiny", K.LIME))
	else:
		v.add_child(K.lbl(why + (". Buy a matching part or swap the other one." if not why.begins_with("Install a") else "."), "Tiny", K.ORANGE if why.begins_with("Install a") else K.DANGER, true))
	h.add_child(v)
	var btn := K.btn("INSTALL", "PrimaryButton" if why == "" else "GhostButton", func(): install_requested.emit(it))
	h.add_child(btn)
	_install_btns.append([btn, why])
	if why != "":
		btn.disabled = true
	p.add_child(h)
	return p


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
