extends HBoxContainer
## Overclocking bench for CPU / GPU / RAM: clock + voltage dials, stability and burn-out warnings, stress test.
const K = preload("res://scripts/ui_kit.gd")
const PartArt = preload("res://scripts/part_art.gd")
const Catalog = preload("res://scripts/catalog.gd")
const OcDial = preload("res://scripts/oc_dial.gd")

var ask: Callable = Callable()
var cat: String = "cpu"
var _draft: Dictionary = {}     # cat -> {clock, voltage}
var _applied: Dictionary = {}   # last known applied state, to detect external changes
var _sel_btns: Dictionary = {}
var _sel_names: Dictionary = {}
var _dial_c: Control
var _dial_v: Control
var _info: Label
var _warn_panel: PanelContainer
var _warn_lbl: Label
var _run: Button
var _stock: Button
var _safe: Button
var _prev: Label
var _power: Label
var _title: Label
var _empty: Label
var _body: VBoxContainer
var _sig: String = ""
var _t: float = 0.0

func _init() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var a := K.vbox(8)
	a.custom_minimum_size.x = 250
	a.add_child(K.lbl("OVERCLOCK BENCH", "H2"))
	var grp := ButtonGroup.new()
	for c in Catalog.TUNABLE:
		var b := K.btn("", "")
		b.toggle_mode = true
		b.button_group = grp
		b.custom_minimum_size = Vector2(240, 64)
		b.pressed.connect(_select.bind(c))
		_sel_btns[c] = b
		a.add_child(b)
	_sel_btns["cpu"].button_pressed = true
	a.add_child(K.lbl("Storage and the rest of the parts are not tunable.", "Tiny", K.MUTED, true))
	var rules := K.panel("Inset")
	var rv := K.vbox(4)
	rv.add_child(K.lbl("RULES OF THUMB", "Eyebrow"))
	for t in ["Clock and voltage run 1.00 to 1.60 (normalized multipliers).", "Voltage ABOVE 1.40 V permanently destroys the part.", "Stable clock = 1 + 1.3 x (V - 1). Above it the score drops.", "More clock and volts draw more power - watch the PSU.", "Each stress test costs 20 game minutes at the bench."]:
		rv.add_child(K.lbl("- " + t, "Tiny", K.MUTED, true))
	rules.add_child(rv)
	a.add_child(rules)
	add_child(a)
	var mid := K.panel("Card")
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var msc := K.scroll()
	mid.add_child(msc)
	var holder := K.vbox(10)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msc.add_child(holder)
	_title = K.lbl("", "H2")
	holder.add_child(_title)
	_empty = K.lbl("", "Muted", null, true)
	holder.add_child(_empty)
	_body = K.vbox(10)
	holder.add_child(_body)
	var dials := K.hbox(24)
	dials.alignment = BoxContainer.ALIGNMENT_CENTER
	_dial_c = OcDial.new()
	_dial_c.title = "CLOCK"
	_dial_c.unit = "x"
	_dial_c.custom_minimum_size = Vector2(200, 200)
	_dial_c.warn_from = 1.26
	_dial_c.danger_from = 1.61
	_dial_c.value_changed.connect(func(v: float): _edit(true, v))
	dials.add_child(_dial_c)
	_dial_v = OcDial.new()
	_dial_v.title = "VOLTAGE"
	_dial_v.unit = " V"
	_dial_v.tint = K.SKY
	_dial_v.custom_minimum_size = Vector2(200, 200)
	_dial_v.warn_from = 1.31
	_dial_v.danger_from = 1.4001
	_dial_v.value_changed.connect(func(v: float): _edit(false, v))
	dials.add_child(_dial_v)
	_body.add_child(dials)
	_body.add_child(K.lbl("Drag a dial, use the mouse wheel, or focus it and press arrow keys (Shift = bigger steps).", "Tiny", K.MUTED, true))
	_info = K.lbl("", "Mono", null, true)
	_body.add_child(_info)
	_warn_panel = K.panel("CardTight")
	_warn_lbl = K.lbl("", "", K.CREAM, true)
	_warn_panel.add_child(_warn_lbl)
	_body.add_child(_warn_panel)
	var row := K.hbox(8)
	_run = K.btn("RUN STRESS TEST (20 min)", "PrimaryButton", _apply)
	row.add_child(_run)
	_safe = K.btn("SAFE PRESET", "GhostButton", func(): _set_draft(Catalog.stable_clock(1.30), 1.30))
	_safe.tooltip_text = "1.30 V with the clock at the stable limit for that voltage"
	row.add_child(_safe)
	_stock = K.btn("STOCK", "GhostButton", func(): _set_draft(1.0, 1.0))
	row.add_child(_stock)
	_body.add_child(row)
	add_child(mid)
	var right := K.vbox(8)
	right.custom_minimum_size.x = 300
	right.add_child(K.lbl("PROJECTION", "H2"))
	var pp := K.panel("Card")
	var pv := K.vbox(6)
	_prev = K.lbl("", "Mono", null, true)
	pv.add_child(_prev)
	_power = K.lbl("", "Muted", null, true)
	pv.add_child(_power)
	pp.add_child(pv)
	right.add_child(pp)
	add_child(right)

func _me() -> Dictionary:
	return Game.me()

func _get_draft(c: String) -> Dictionary:
	if not _draft.has(c):
		var t: Dictionary = Catalog.tune_of(_me().get("tuning", {}), c)
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
	var blocked: bool = float(me.get("busy", 0.0)) > 0.0 or not me.get("trip", {}).is_empty() or bool(me.get("ready", false))
	var inst: Dictionary = me.get("installed", {})
	_run.disabled = blocked or not inst.has(cat)
	if _warn_panel.visible and float(_get_draft(cat).voltage) > Catalog.MAX_SAFE_VOLTAGE + 0.0001:
		_warn_panel.modulate.a = 0.65 + 0.35 * sin(_t * 8.0)
	else:
		_warn_panel.modulate.a = 1.0

func refresh() -> void:
	if not is_visible_in_tree():
		return
	var me := _me()
	var tun: Dictionary = me.get("tuning", {})
	var inst: Dictionary = me.get("installed", {})
	var sig := str(tun) + str(inst.keys()) + str(me.get("busy", 0.0) > 0.0)
	for c in inst:
		sig += str(int(inst[c].id))
	if sig == _sig:
		return
	_sig = sig
	# adopt applied values when they changed (stress test, part swapped, burn-out)
	for c in Catalog.TUNABLE:
		var t: Dictionary = Catalog.tune_of(tun, c)
		var key := "%s:%d" % [c, int(inst[c].id) if inst.has(c) else -1]
		var now := "%s|%.2f|%.2f" % [key, t.clock, t.voltage]
		if _applied.get(c, "") != now:
			_applied[c] = now
			_draft[c] = {"clock": t.clock, "voltage": t.voltage}
		var b: Button = _sel_btns[c]
		if inst.has(c):
			b.text = "%s\n%s  x%.2f @ %.2fV" % [K.CAT_LABEL[c], String(inst[c].name).left(24), t.clock, t.voltage]
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
	if not has_part:
		_empty.text = "Install a %s first (WORKBENCH tab). There is nothing here to overclock." % String(K.CAT_LABEL[cat]).to_lower()
		_prev.text = "Install the part, then come back to see projected scores."
		_power.text = ""
		return
	var d := _get_draft(cat)
	var clock: float = d.clock
	var volt: float = d.voltage
	var stable: float = Catalog.stable_clock(volt)
	var mult: float = Catalog.multiplier(clock, volt)
	_dial_c.warn_from = stable
	_dial_c.queue_redraw()
	var item: Dictionary = inst[cat]
	var lines := PackedStringArray()
	lines.append("Part: %s" % item.name)
	lines.append("Stable clock at %.2f V: up to x%.2f" % [volt, stable])
	lines.append("Score multiplier: x%.2f" % mult)
	_info.text = "\n".join(lines)
	var burn: bool = volt > Catalog.MAX_SAFE_VOLTAGE + 0.0001
	var unstable: bool = clock > stable + 0.0005
	var col := K.LIME
	var msg := "SAFE. Voltage within limit and clock stable. Free score."
	if burn:
		col = K.DANGER
		msg = "BURN WARNING: %.2f V is above %.2f V. Running the stress test will PERMANENTLY DESTROY this %s. You would have to buy another one." % [volt, Catalog.MAX_SAFE_VOLTAGE, String(K.CAT_LABEL[cat]).to_lower()]
	elif unstable:
		col = K.ORANGE
		msg = "UNSTABLE: clock x%.2f exceeds the stable x%.2f for %.2f V - crashes cost score (multiplier cut). Raise voltage (max 1.40 V) or lower the clock." % [clock, stable, volt]
	elif volt > 1.30:
		col = K.SKY
		msg = "Hot but safe: %.2f V is close to the %.2f V limit. Good performance, no margin for mistakes." % [volt, Catalog.MAX_SAFE_VOLTAGE]
	_warn_panel.add_theme_stylebox_override("panel", K.box(Color(col, 0.12), col, 6, 2 if burn else 1, 12, 10))
	_warn_lbl.add_theme_color_override("font_color", col)
	_warn_lbl.text = msg
	_run.theme_type_variation = "RiskButton" if (burn or unstable) else "PrimaryButton"
	_run.text = "RUN STRESS TEST - DESTROYS PART" if burn else "RUN STRESS TEST (20 min)"
	# projection
	var tun2: Dictionary = me.get("tuning", {}).duplicate(true)
	tun2[cat] = {"clock": clock, "voltage": volt}
	var cur: Dictionary = Game.preview_score(me)
	var now_inst := inst
	var obj: String = String(Game.state.objective)
	var sc: Dictionary = Catalog.score(now_inst, tun2, obj)
	var cap: int = int(inst.psu.capacity) if inst.has("psu") else 0
	var draw: int = Catalog.power_draw(inst, tun2)
	_prev.text = "Applied score now\n  CPU %5d  GPU %5d\n  RAM %5d  STO %5d\n  TOTAL %5d\n\nWith these dials\n  CPU %5d  GPU %5d\n  RAM %5d  STO %5d\n  TOTAL %5d" % [cur.cpu, cur.gpu, cur.ram, cur.storage, cur.total, sc.cpu, sc.gpu, sc.ram, sc.storage, sc.total]
	var pcol := K.CREAM
	_power.text = "Estimated draw %dW / %s PSU.%s" % [draw, ("%dW" % cap) if cap > 0 else "no", "  OVERLOADED - rig turns invalid!" if (cap > 0 and draw > cap) else ""]
	_power.add_theme_color_override("font_color", K.DANGER if (cap > 0 and draw > cap) else pcol)

func _apply() -> void:
	var d := _get_draft(cat)
	var c := cat
	var clock: float = d.clock
	var volt: float = d.voltage
	var go := func(): Game.act("tune", {"category": c, "clock": clock, "voltage": volt})
	if volt > Catalog.MAX_SAFE_VOLTAGE + 0.0001 and ask.is_valid():
		ask.call("This will destroy your part", "%.2f V is above the %.2f V limit. The stress test will permanently burn out your %s. Do it anyway?" % [volt, Catalog.MAX_SAFE_VOLTAGE, String(K.CAT_LABEL[c]).to_lower()], "Burn it", go)
	else:
		go.call()
