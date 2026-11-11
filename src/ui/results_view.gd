extends VBoxContainer
## Solo benchmark results: component bars fill in sequence, then the final score.
const K = preload("res://src/ui/ui_kit.gd")

signal replay
signal menu

const CATS4: Array = ["cpu", "gpu", "ram", "storage"]
const LABELS := {"cpu": "CPU", "gpu": "GPU", "ram": "RAM", "storage": "STORAGE"}
const REFS = preload("res://src/workshop/rig_rules.gd").REF

var _sig: String = ""
var _t: float = 0.0
var _rows: Array = []     # [{bars:{cat:[bar,lbl,val]}, total:Label, total_val:int}]
var _stage_lbl: Label
var _body: VBoxContainer
var _winner: Label
var _actions: HBoxContainer
var _skip: Button
var _spacer: Control
var _replay_btn: Button
var _back_btn: Button

const RowScene = preload("res://src/ui/results_row.tscn")
const FooterScene = preload("res://src/ui/results_footer.tscn")

func _ready() -> void:
	_stage_lbl = $Head/Stage
	_winner = $Winner
	_body = $Scroll/Body
	_actions = $Actions
	_skip = $Actions/Skip
	_spacer = $Actions/Spacer
	_replay_btn = $Actions/Replay
	_back_btn = $Actions/Back
	add_theme_constant_override("separation", 10)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skip.pressed.connect(func(): _t = 99.0)
	_replay_btn.pressed.connect(func(): replay.emit())
	_back_btn.pressed.connect(func(): menu.emit())


func _process(delta: float) -> void:
	tick(delta)


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
		var row = RowScene.instantiate()
		_body.add_child(row)
		row.configure(rank, String(p.name), mine, K.money(int(p.cash)), sc, maxes, bool(sc.get("valid", false)), sc.get("issues", []))
		row.rank_label.visible = false
		_rows.append({"bars": row.bars, "total": row.total_label, "total_val": int(sc.get("total", 0))})
	# footer details
	var me: Dictionary = Game.me()
	var footer = FooterScene.instantiate()
	_body.add_child(footer)
	footer.configure(st, me)
	for ch in _actions.get_children():
		if ch != _skip and ch != _spacer and ch != _replay_btn and ch != _back_btn:
			_actions.remove_child(ch)
			ch.queue_free()
	_replay_btn.visible = false
	_replay_btn.text = "REPLAY ASSEMBLY TEST" if st.get("assembly_test", false) else "REPLAY - NEW MARKET"
	_back_btn.visible = true
	if st.mode == "solo":
		_replay_btn.visible = true
	var top_id: int = ids[0] if not ids.is_empty() else -1
	if top_id >= 0:
		var wp: Dictionary = st.players[top_id]
		_winner.text = ("YOUR SCORE: %d" % int(wp.score.get("total", 0))) if int(wp.score.get("total", 0)) > 0 else "No valid rig finished. Score: 0."
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
		stage = "FINAL SCORE"
		_skip.visible = false
	else:
		stage = "TESTING %s..." % LABELS[CATS4[idx]]
		_skip.visible = true
	_stage_lbl.text = stage
