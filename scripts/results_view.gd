extends VBoxContainer
## Animated benchmark run-off: CPU, GPU, RAM, STORAGE bars fill in sequence, then totals and ranking.
const K = preload("res://scripts/ui_kit.gd")

signal replay
signal menu

const CATS4: Array = ["cpu", "gpu", "ram", "storage"]
const LABELS := {"cpu": "CPU", "gpu": "GPU", "ram": "RAM", "storage": "STORAGE"}
const REFS := {"cpu": 6000.0, "gpu": 6000.0, "ram": 4000.0, "storage": 4000.0}

var _sig: String = ""
var _t: float = 0.0
var _rows: Array = []     # [{bars:{cat:[bar,lbl,val]}, total:Label, total_val:int, card:Control}]
var _stage_lbl: Label
var _body: VBoxContainer
var _winner: Label
var _actions: HBoxContainer
var _skip: Button

func _init() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := K.hbox(12)
	head.add_child(K.lbl("BENCHMARK RESULTS", "Title"))
	_stage_lbl = K.lbl("", "Eyebrow")
	_stage_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_stage_lbl)
	add_child(head)
	_winner = K.lbl("", "H2", K.LIME, true)
	add_child(_winner)
	var sc := K.scroll()
	add_child(sc)
	_body = K.vbox(10)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)
	_actions = K.hbox(10)
	_skip = K.btn("SKIP ANIMATION", "GhostButton", func(): _t = 99.0)
	_actions.add_child(_skip)
	_actions.add_child(K.spacer())
	add_child(_actions)

func refresh() -> void:
	var st: Dictionary = Game.state
	var ids: Array = st.get("ranking", [])
	if ids.is_empty():
		ids = st.players.keys()
	var sig := str(st.get("match_id", 0)) + str(ids)
	for id in ids:
		sig += str(st.players[id].score.get("total", 0))
	if sig == _sig:
		return
	_sig = sig
	_t = 0.0
	_build(ids)

func _build(ids: Array) -> void:
	K.clear(_body)
	_rows.clear()
	var st: Dictionary = Game.state
	var maxes := {}
	for c in CATS4:
		var m: float = REFS[c]
		for id in ids:
			m = maxf(m, float(st.players[id].score.get(c, 0)))
		maxes[c] = m
	var rank := 0
	var me_id: int = Game.local_id()
	for id in ids:
		rank += 1
		var p: Dictionary = st.players[id]
		var sc: Dictionary = p.score
		var mine: bool = id == me_id
		var card := K.panel("CardHot" if mine else "Card")
		var h := K.hbox(18)
		var left := K.vbox(2)
		left.custom_minimum_size.x = 210
		left.add_child(K.lbl("#%d" % rank, "Display"))
		left.add_child(K.lbl(String(p.name) + ("  (YOU)" if mine else ""), "H2", null, true))
		var tl := K.lbl("...", "Title", K.LIME)
		left.add_child(tl)
		left.add_child(K.lbl("Cash left %s" % K.money(p.cash), "Tiny"))
		h.add_child(left)
		var bars := K.vbox(8)
		bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var barmap := {}
		for c in CATS4:
			var r := K.hbox(10)
			var nm := K.lbl(LABELS[c], "Mono", K.cat_color("gpu" if c == "gpu" else ("storage" if c == "storage" else c)))
			nm.custom_minimum_size.x = 82
			r.add_child(nm)
			var bar := ProgressBar.new()
			bar.max_value = maxes[c]
			bar.value = 0
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(120, 16)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.add_child(bar)
			var vl := K.lbl("0", "Mono")
			vl.custom_minimum_size.x = 70
			vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			r.add_child(vl)
			bars.add_child(r)
			barmap[c] = [bar, vl, int(sc.get(c, 0))]
		h.add_child(bars)
		card.add_child(h)
		var wrap := K.vbox(4)
		wrap.add_child(card)
		if not bool(sc.get("valid", false)):
			var iss: Array = sc.get("issues", [])
			wrap.add_child(K.lbl("Rig invalid - total score 0. " + (String(iss[0]) if not iss.is_empty() else ""), "Tiny", K.ORANGE, true))
		_body.add_child(wrap)
		_rows.append({"bars": barmap, "total": tl, "total_val": int(sc.get("total", 0))})
	# footer details
	var me: Dictionary = Game.me()
	var info := K.panel("Inset")
	var iv := K.vbox(4)
	if st.mode == "solo":
		var total: int = int(me.get("score", {}).get("total", 0))
		var best: int = int(me.get("best", 0))
		iv.add_child(K.lbl("Solo high score for objective %s: %d%s" % [st.objective, maxi(best, total), "  - NEW BEST!" if total >= best and total > 0 else ""], "Mono", K.LIME, true))
	iv.add_child(K.lbl("Scores use fictional benchmark units. The total is weighted by the objective (%s)." % st.objective, "Muted", null, true))
	var destroyed: Array = me.get("destroyed", [])
	if not destroyed.is_empty():
		iv.add_child(K.lbl("You burnt out: " + ", ".join(destroyed), "Tiny", K.DANGER, true))
	info.add_child(iv)
	_body.add_child(info)
	for ch in _actions.get_children():
		if ch != _skip:
			_actions.remove_child(ch)
			ch.queue_free()
	_actions.add_child(K.spacer())
	if st.mode == "solo":
		_actions.add_child(K.btn("REPLAY - NEW MARKET", "PrimaryButton", func(): replay.emit()))
	_actions.add_child(K.btn("BACK TO MENU", "GhostButton", func(): menu.emit()))
	var top_id: int = ids[0] if not ids.is_empty() else -1
	if top_id >= 0:
		var wp: Dictionary = st.players[top_id]
		_winner.text = ("WINNER: %s with %d" % [wp.name, int(wp.score.get("total", 0))]) if int(wp.score.get("total", 0)) > 0 else "No valid rig finished. Nobody scores."
		_winner.visible = true

func tick(delta: float) -> void:
	if not is_visible_in_tree() or _rows.is_empty():
		return
	_t += delta
	var stage := "RUNNING BENCHMARKS"
	for r in _rows:
		for i in CATS4.size():
			var c: String = CATS4[i]
			var f: float = clampf((_t - i * 1.2) / 1.0, 0.0, 1.0)
			var e: Array = r.bars[c]
			var target: int = e[2]
			var v := int(round(target * (1.0 - pow(1.0 - f, 3.0))))
			e[0].value = v
			var txt := str(v)
			if e[1].text != txt:
				e[1].text = txt
		var done: bool = _t >= CATS4.size() * 1.2 + 0.3
		var tt: String = str(int(r.total_val)) if done else "..."
		if r.total.text != tt:
			r.total.text = tt
	var idx: int = clampi(int(_t / 1.2), 0, 3)
	if _t >= CATS4.size() * 1.2 + 0.3:
		stage = "FINAL RANKING"
		_skip.visible = false
	else:
		stage = "TESTING %s..." % LABELS[CATS4[idx]]
		_skip.visible = true
	_stage_lbl.text = stage
