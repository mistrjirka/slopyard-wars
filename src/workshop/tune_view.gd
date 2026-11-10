extends HBoxContainer
## Overclocking bench for CPU / GPU / RAM: clock + voltage dials, stability and burn-out warnings, stress test.
const Overclock = preload("res://src/workshop/overclock_rules.gd")
const Stats = preload("res://src/data/hardware_stats.gd")
const K = preload("res://src/ui/ui_kit.gd")
const RigRules = preload("res://src/workshop/rig_rules.gd")

var ask: Callable = Callable()
var cat: String = "cpu"
var _draft: Dictionary = {}     # cat -> {clock, voltage}
var _applied: Dictionary = {}   # last known applied state, to detect external changes
var _sel_btns: Dictionary = {}
var _sig: String = ""
var _t: float = 0.0


@onready var _dial_c: Control = $MidPanel/MidScroll/Holder/BodyBox/DialsBox/DialClock
@onready var _dial_v: Control = $MidPanel/MidScroll/Holder/BodyBox/DialsBox/DialVoltage
@onready var _info: Label = $MidPanel/MidScroll/Holder/BodyBox/InfoLabel
@onready var _warn_panel: PanelContainer = $MidPanel/MidScroll/Holder/BodyBox/WarnPanel
@onready var _warn_lbl: Label = $MidPanel/MidScroll/Holder/BodyBox/WarnPanel/WarnLabel
@onready var _run: Button = $MidPanel/MidScroll/Holder/BodyBox/ActionsRow/RunButton
@onready var _safe: Button = $MidPanel/MidScroll/Holder/BodyBox/ActionsRow/SafeButton
@onready var _stock: Button = $MidPanel/MidScroll/Holder/BodyBox/ActionsRow/StockButton
@onready var _prev: Label = $RightColumn/ProjPanel/ProjBox/PrevLabel
@onready var _power: Label = $RightColumn/ProjPanel/ProjBox/PowerLabel
@onready var _title: Label = $MidPanel/MidScroll/Holder/TitleLabel
@onready var _empty: Label = $MidPanel/MidScroll/Holder/EmptyLabel
@onready var _outcome: Label = $MidPanel/MidScroll/Holder/OutcomeLabel
@onready var _body: VBoxContainer = $MidPanel/MidScroll/Holder/BodyBox


func _ready() -> void:
	_sel_btns["cpu"] = $LeftColumn/SelCpu
	_sel_btns["gpu"] = $LeftColumn/SelGpu
	_sel_btns["ram"] = $LeftColumn/SelRam
	for c in RigRules.TUNABLE:
		var b: Button = _sel_btns[c]
		b.toggle_mode = true
		b.pressed.connect(_select.bind(c))
	_sel_btns["cpu"].button_pressed = true
	_dial_c.title = "CLOCK"
	_dial_c.unit = "x"
	_dial_c.warn_from = 1.26
	_dial_c.danger_from = 1.61
	_dial_c.value_changed.connect(func(v: float): _edit(true, v))
	_dial_v.title = "VOLTAGE"
	_dial_v.unit = "x"
	_dial_v.tint = K.SKY
	_dial_v.warn_from = 1.31
	_dial_v.danger_from = 1.4001
	_dial_v.value_changed.connect(func(v: float): _edit(false, v))
	_outcome.add_theme_color_override("font_color", K.DANGER)
	_run.pressed.connect(_apply)
	_safe.pressed.connect(_safe_preset)
	_stock.pressed.connect(func(): _set_draft(1.0, 1.0))


func _me() -> Dictionary:
	return Game.me()


func _get_draft(c: String) -> Dictionary:
	if not _draft.has(c):
		var t: Dictionary = RigRules.tune_of(_me().get("tuning", {}), c)
		_draft[c] = {"clock": t.clock, "voltage": t.voltage}
	return _draft[c]


func _select(c: String) -> void:
	cat = c
	_load_dials()
	_readouts()


func _load_dials() -> void:
	var d := _get_draft(cat)
	_dial_c.set_value(d.clock)
	_dial_v.set_value(d.voltage)
	_dial_c.queue_redraw()
	_dial_v.queue_redraw()


func _set_draft(clock: float, volt: float) -> void:
	var d := _get_draft(cat)
	d.clock = clampf(snappedf(clock, 0.01), 1.0, 1.6)
	d.voltage = clampf(snappedf(volt, 0.01), 1.0, 1.6)
	_load_dials()
	_readouts()


func _edit(is_clock: bool, v: float) -> void:
	var d := _get_draft(cat)
	d["clock" if is_clock else "voltage"] = v
	_readouts()


func tick(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	var me := _me()
	var blocked: bool = float(me.get("busy", 0.0)) > 0.0 or bool(me.get("driving", false)) or bool(me.get("ready", false))
	var inst: Dictionary = me.get("installed", {})
	_run.disabled = blocked or not inst.has(cat)
	if _warn_panel.visible and float(_get_draft(cat).voltage) > Overclock.HARD_VOLTAGE_LIMIT + 0.0001:
		_warn_panel.modulate.a = 0.65 + 0.35 * sin(_t * 8.0)
	else:
		_warn_panel.modulate.a = 1.0


func refresh() -> void:
	if not is_visible_in_tree():
		return
	var me := _me()
	var tun: Dictionary = me.get("tuning", {})
	var inst: Dictionary = me.get("installed", {})
	var sig := str(tun) + str(inst) + str(me.get("workshop_modifiers", {})) + str(me.get("last_stress_test", {})) + str(me.get("busy", 0.0) > 0.0)
	for c in inst:
		sig += str(int(inst[c].id))
	if sig == _sig:
		return
	_sig = sig
	# adopt applied values when they changed (stress test, part swapped, burn-out)
	for c in RigRules.TUNABLE:
		var t: Dictionary = RigRules.tune_of(tun, c)
		var key := "%s:%d" % [c, int(inst[c].id) if inst.has(c) else -1]
		var now := "%s|%.2f|%.2f" % [key, t.clock, t.voltage]
		if _applied.get(c, "") != now:
			_applied[c] = now
			_draft[c] = {"clock": t.clock, "voltage": t.voltage}
		var b: Button = _sel_btns[c]
		if inst.has(c):
			b.text = "%s\n%s  x%.2f @ %.2fx" % [K.CAT_LABEL[c], String(inst[c].name).left(24), t.clock, t.voltage]
		else:
			b.text = "%s\nnot installed" % K.CAT_LABEL[c]
	_load_dials()
	_readouts()


func _readouts() -> void:
	var me := _me()
	var inst: Dictionary = me.get("installed", {})
	var has_part: bool = inst.has(cat)
	_title.text = "%s TUNING" % String(K.CAT_LABEL[cat])
	_body.visible = has_part
	_empty.visible = not has_part
	var last: Dictionary = me.get("last_stress_test", {})
	_outcome.visible = last.get("failure_mode", "") == "fire"
	_outcome.text = "CONNECTOR FIRE: %s was destroyed. Dragon Breath mode is not covered by warranty. The rest of your rig survived." % last.get("part", "GPU") if _outcome.visible else ""
	if not has_part:
		_empty.text = "Install a %s first (WORKBENCH tab). There is nothing here to overclock." % String(K.CAT_LABEL[cat]).to_lower()
		_prev.text = "Install the part, then come back to see projected scores."
		_power.text = ""
		return
	var d := _get_draft(cat)
	var clock: float = d.clock
	var volt: float = d.voltage
	var item: Dictionary = inst[cat]
	var result := Overclock.evaluate(item, clock, volt, inst, me.get("workshop_modifiers", {}))
	var chance: float = result.damage_chance
	_dial_c.warn_from = result.stable_clock
	_dial_v.warn_from = float(item.get("voltage_limit", 1.3)) - 0.04
	_dial_c.queue_redraw()
	_dial_v.queue_redraw()
	_info.text = "%s\nCondition %d/100 · stock score %d · model headroom +%d%%\nStable clock here: %.2fx · performance %.2fx\nEstimated temperature %.0f°C · destruction chance %.1f%% per test" % [item.name, item.get("condition", 100), roundi(Stats.stock_score(item)), roundi(float(item.get("oc_potential", 0)) * 100), result.stable_clock, result.multiplier, result.temperature, chance * 100]
	if cat == "cpu":
		var paste_loss := roundi((1.0 - float(result.paste_multiplier)) * 100)
		var mount_loss := roundi((1.0 - float(result.mount_headroom_multiplier)) * 100)
		if paste_loss > 0:
			_info.text += "\nINSTALLATION: insufficient paste costs %d%% CPU performance." % paste_loss
		if mount_loss > 0:
			_info.text += "\nINSTALLATION: uneven mounting costs %d%% OC headroom and adds %.0f°C." % [mount_loss, result.mount_temperature_penalty]
		if paste_loss > 0 or mount_loss > 0:
			_info.text += "\nUse REINSTALL on the workbench CPU card to correct it."
	var modifiers: Dictionary = me.get("workshop_modifiers", {})
	if int(modifiers.get("cooling_bonus", 0)) > 0:
		_info.text += "\n%s applied: +%d cooling (100-point cap)" % [modifiers.get("cooling_name", "Cooling preparation"), modifiers.cooling_bonus]
	var col := K.LIME if chance == 0 else K.ORANGE
	var message := "Zero destruction risk at these settings."
	var stock_fault: float = result.stock_failure_chance
	var inherent_risk := Stats.has_inherent_risk(item)
	_safe.text = "LOWEST RISK: STOCK" if inherent_risk else "SAFE PRESET"
	_safe.tooltip_text = "This model has no zero-risk setting. Stock avoids extra tuning stress." if inherent_risk else "Choose a zero-risk preset for this exact part, condition and cooling setup"
	if chance >= 1.0:
		col = K.DANGER
		message = "GUARANTEED DESTRUCTION: voltage exceeds the hard 1.40x limit. No charm or cooling upgrade can prevent this."
	elif chance > 0:
		message = "%.1f%% chance of permanent destruction. Surviving this test still costs %d condition points." % [chance * 100, result.wear]
	if stock_fault > 0:
		message += " MODEL RELIABILITY FLAW: %.1f%% unblessed failure risk even at stock. The final benchmark also tests this part; cleaning cannot remove the flaw." % (stock_fault * 100)
	if result.fire_chance > 0:
		message += " CONNECTOR FIRE: %.1f%% chance at these settings, INCLUDED in the destruction chance above. More power and weak PSU regulation make it worse. Paste helps heat, but cannot cure the connector. The final benchmark tests this too." % (result.fire_chance * 100)
	if clock > float(result.stable_clock) + 0.0005:
		message += " UNSTABLE: the extra clock is reducing performance."
	if result.uses_luck:
		message += " Lucky's 25% risk reduction is included; this test consumes the charm."
	elif int(me.get("workshop_modifiers", {}).get("lucky_tests", 0)) > 0:
		message += " Lucky charm held for a future risky test."
	_warn_panel.add_theme_stylebox_override("panel", K.box(Color(col, 0.12), col, 6, 1, 12, 10))
	_warn_lbl.add_theme_color_override("font_color", col)
	_warn_lbl.text = message
	_run.theme_type_variation = "RiskButton" if chance > 0 else "PrimaryButton"
	_run.text = "TEST: %.1f%% DESTRUCTION RISK" % (chance * 100) if chance > 0 else "RUN SAFE TEST (20 min)"
	# projection
	var tun2: Dictionary = me.get("tuning", {}).duplicate(true)
	tun2[cat] = {"clock": clock, "voltage": volt}
	var cur: Dictionary = Game.preview_score(me)
	var now_inst := inst.duplicate(true)
	var projection_title := "After a successful test (including wear)"
	if chance >= 1.0:
		now_inst.erase(cat)
		tun2.erase(cat)
		projection_title = "After guaranteed destruction"
	else:
		now_inst[cat]["condition"] = maxi(1, int(item.get("condition", 100)) - int(result.wear))
	var obj: String = String(Game.state.objective)
	var sc: Dictionary = RigRules.score(now_inst, tun2, obj, me.get("workshop_modifiers", {}))
	var cap: int = int(inst.psu.capacity) if inst.has("psu") else 0
	var draw: int = RigRules.power_draw(inst, tun2)
	_prev.text = "Applied score now\n  CPU %5d  GPU %5d\n  RAM %5d  STO %5d\n  TOTAL %5d\n\n%s\n  CPU %5d  GPU %5d\n  RAM %5d  STO %5d\n  TOTAL %5d" % [cur.cpu, cur.gpu, cur.ram, cur.storage, cur.total, projection_title, sc.cpu, sc.gpu, sc.ram, sc.storage, sc.total]
	var pcol := K.CREAM
	_power.text = "Estimated draw %dW / %s PSU.%s" % [draw, ("%dW" % cap) if cap > 0 else "no", "  OVERLOADED - rig turns invalid!" if (cap > 0 and draw > cap) else ""]
	_power.add_theme_color_override("font_color", K.DANGER if (cap > 0 and draw > cap) else pcol)


func _safe_preset() -> void:
	var player := _me()
	if not player.installed.has(cat):
		return
	var preset := Overclock.safe_preset(player.installed[cat], player.installed, player.get("workshop_modifiers", {}))
	_set_draft(preset.clock, preset.voltage)


func _apply() -> void:
	var player := _me()
	if not player.installed.has(cat):
		return
	var draft := _get_draft(cat)
	var item: Dictionary = player.installed[cat]
	var result := Overclock.evaluate(item, draft.clock, draft.voltage, player.installed, player.get("workshop_modifiers", {}))
	var data := {"category": cat, "clock": draft.clock, "voltage": draft.voltage,
		"item_id": int(item.id), "risk_quote": result.damage_chance}
	var go := func(): Game.act("tune", data)
	if result.damage_chance > 0 and ask.is_valid():
		var message := "%s has a %.1f%% chance of being permanently destroyed in this test. If it survives, it loses %d condition points. Cost: 20 game minutes." % [item.name, result.damage_chance * 100, result.wear]
		if result.fire_chance > 0:
			message += "\n\nCONNECTOR FIRE: %.1f%% chance, included in that total. A fire destroys this part; the rest of the rig survives." % (result.fire_chance * 100)
		ask.call("Release the magic smoke?", message, "Run risky test", go)
	else:
		go.call()
