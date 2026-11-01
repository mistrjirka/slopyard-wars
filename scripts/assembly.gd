extends Control
## Component-specific assembly minigame. One canvas, a step list per part category.
## Emits completed(slips) when every step is done; the caller then sends the install action.
const K = preload("res://scripts/ui_kit.gd")
const PartArt = preload("res://scripts/part_art.gd")

signal completed(slips: int)
signal cancelled

const W := 780.0
const H := 440.0
const CASE_RECT := Rect2(30, 40, 480, 330)
const TARGET := Vector2(270, 205)

var item: Dictionary = {}
var cat: String = ""
var steps: Array = []
var si: int = 0
var slips: int = 0
var note: String = ""
var note_err: bool = false
var _flash: float = 0.0
var _t: float = 0.0
var _dragging: bool = false
var _grab := Vector2.ZERO
var _mouse := Vector2.ZERO
var _cable: int = -1
var _done: bool = false

func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	focus_mode = Control.FOCUS_ALL
	clip_contents = true

func begin(it: Dictionary) -> void:
	item = it
	cat = String(it.get("category", ""))
	steps = _build()
	si = 0
	slips = 0
	_done = false
	_dragging = false
	_cable = -1
	_enter()
	grab_focus()

# ------------------------------------------------------------------ step builders

func _clk(p: Vector2, n: int = 1, r: float = 15.0, decoy: bool = false) -> Dictionary:
	return {"p": p, "n": n, "c": 0, "r": r, "decoy": decoy}

func _clicks(title: String, hint: String, pts: Array, style: String = "screw") -> Dictionary:
	return {"kind": "clicks", "title": title, "hint": hint, "pts": pts, "style": style}

func _drag(title: String, hint: String, start: Vector2, target: Vector2, scale: float, inc: int, tol: float = 26.0, fail: String = "") -> Dictionary:
	var rot := 0
	if inc > 0:
		rot = inc if inc != 1 else [1, 2, 3][randi() % 3]
	return {"kind": "drag", "title": title, "hint": hint, "pos": start, "start": start, "target": target,
		"scale": scale, "inc": inc, "rot": rot, "tol": tol, "fail": fail}

func _cables(title: String, hint: String, list: Array) -> Dictionary:
	return {"kind": "cables", "title": title, "hint": hint, "list": list}

func _holes() -> Array:
	var xs := [-70.0, 0.0, 70.0]
	var ys: Array = [-70.0, 0.0, 70.0] if String(item.get("form", "ATX")) == "ATX" else [-45.0, 45.0]
	var out: Array = []
	for y in ys:
		for x in xs:
			out.append(TARGET + Vector2(x, y))
	return out

func _corner_pts(c: Vector2, hx: float, hy: float) -> Array:
	return [_clk(c + Vector2(-hx, -hy)), _clk(c + Vector2(hx, -hy)), _clk(c + Vector2(-hx, hy)), _clk(c + Vector2(hx, hy))]

func _build() -> Array:
	match cat:
		"case":
			var pts: Array = []
			for h in _holes():
				pts.append(_clk(h, 1, 13.0))
			pts.append(_clk(Vector2(80, 90), 1, 13.0, true))
			pts.append(_clk(Vector2(460, 330), 1, 13.0, true))
			return [
				_clicks("1/2  MOUNT STANDOFFS", "Click every glowing hole to screw in a brass standoff (%s case: %d). Dim spots are wrong - skip them." % [String(item.get("form", "ATX")), _holes().size()], pts, "standoff"),
				_clicks("2/2  CLOSE THE SIDE PANEL", "Tighten the four thumbscrews at the panel corners.", _corner_pts(CASE_RECT.get_center(), 218, 148)),
			]
		"motherboard":
			return [
				_drag("1/2  SET THE BOARD", "Drag the motherboard from the bench onto the brass standoffs in the case tray.", Vector2(650, 230), TARGET, 2.6, 0, 30.0),
				_clicks("2/2  SCREW IT DOWN", "Drive a screw into each board corner.", _corner_pts(TARGET, 78, 74)),
			]
		"cpu":
			return [
				_clicks("1/5  RELEASE THE SOCKET LEVER", "Click the lever end to lift it open.", [_clk(Vector2(440, 245), 1, 20.0)], "lever"),
				_drag("2/5  SEAT THE CPU", "Match the gold triangle on the CPU with the triangle on the socket corner (top-left). Rotate with R / E, right-click or mouse wheel, then drag it into the socket.", Vector2(650, 240), Vector2(270, 205), 2.2, 1, 24.0, "The gold triangle must sit on the socket's triangle (top-left). Rotate with R."),
				_clicks("3/5  LOCK THE LEVER", "Click the raised lever to clamp the CPU.", [_clk(Vector2(338, 150), 1, 20.0)], "lever"),
				_clicks("4/5  THERMAL PASTE", "Click the centre of the CPU to drop a pea of paste.", [_clk(Vector2(270, 205), 1, 22.0)], "paste"),
				_clicks("5/5  MOUNT THE COOLER", "Tighten the four cooler screws.", _corner_pts(Vector2(270, 205), 88, 88)),
			]
		"gpu":
			return [
				_clicks("1/4  OPEN THE SLOT LATCH", "Click the PCIe latch at the end of the x16 slot.", [_clk(Vector2(458, 310), 1, 18.0)], "lever"),
				_drag("2/4  SLIDE IN THE CARD", "Drag the graphics card down so the gold fingers drop into the x16 slot.", Vector2(630, 110), Vector2(250, 268), 2.6, 0, 26.0),
				_clicks("3/4  CLOSE THE LATCH", "Click the latch again to lock the card.", [_clk(Vector2(458, 310), 1, 18.0)], "lever"),
				_clicks("4/4  BRACKET SCREWS", "Secure the card bracket with the two screws on the left.", [_clk(Vector2(128, 235)), _clk(Vector2(128, 300))]),
			]
		"ram":
			return [
				_clicks("1/3  OPEN THE CLIPS", "Click both retention clips at the ends of the DIMM slot.", [_clk(Vector2(118, 313), 1, 18.0), _clk(Vector2(562, 313), 1, 18.0)], "lever"),
				_drag("2/3  ALIGN THE NOTCH", "The stick's notch must sit over the slot key (bottom centre). Flip it with R / E or right-click, then drag it onto the slot.", Vector2(390, 110), Vector2(340, 263), 3.6, 2, 26.0, "Notch is on the wrong side - flip the stick with R."),
				_clicks("3/3  PRESS DOWN", "Press both ends firmly: click each end 3 times until the clips snap shut.", [_clk(Vector2(200, 258), 3, 20.0), _clk(Vector2(480, 258), 3, 20.0)], "press"),
			]
		"psu":
			return [
				_drag("1/3  SLIDE THE PSU INTO ITS BAY", "Drag the power supply into the bottom bay.", Vector2(660, 330), Vector2(170, 320), 2.6, 0, 30.0),
				_clicks("2/3  FASTEN THE BRACKET", "Four rear screws hold it in.", [_clk(Vector2(62, 276)), _clk(Vector2(278, 276)), _clk(Vector2(62, 376)), _clk(Vector2(278, 376))]),
				_cables("3/3  PLUG IN THE CABLES", "Drag each coloured lead from the PSU to the matching colour socket.", [
					{"from": Vector2(292, 291), "to": Vector2(440, 90), "col": Color(1, 0.8, 0.3), "label": "CPU 8-PIN", "done": false},
					{"from": Vector2(292, 315), "to": Vector2(440, 170), "col": Color(1, 0.4, 0.2), "label": "24-PIN BOARD", "done": false},
					{"from": Vector2(292, 338), "to": Vector2(440, 250), "col": Color(0.4, 0.8, 1), "label": "PCIe / SATA", "done": false}]),
			]
		"storage":
			return [
				_drag("1/3  SLIDE THE DRIVE INTO THE BAY", "Drag the drive onto the bay rails.", Vector2(650, 230), Vector2(375, 205), 3.0, 0, 30.0),
				_clicks("2/3  SCREW IT TO THE RAILS", "Four screws hold the drive in the cage.", [_clk(Vector2(262, 112)), _clk(Vector2(488, 112)), _clk(Vector2(262, 298)), _clk(Vector2(488, 298))]),
				_cables("3/3  CONNECT DATA + POWER", "Drag the cyan SATA data lead and the orange power lead onto the matching drive ports.", [
					{"from": Vector2(70, 130), "to": Vector2(292, 170), "col": Color(0.4, 0.88, 0.95), "label": "SATA DATA", "done": false},
					{"from": Vector2(70, 210), "to": Vector2(292, 240), "col": Color(1, 0.55, 0.17), "label": "SATA POWER", "done": false}]),
			]
	return [_clicks("1/1  INSTALL", "Click the marker to install.", [_clk(Vector2(390, 220), 1, 22.0)], "press")]

# ------------------------------------------------------------------ flow

func _enter() -> void:
	if si < steps.size():
		note = String(steps[si].hint)
		note_err = false

func _slip(msg: String) -> void:
	slips += 1
	_flash = 0.45
	note = msg
	note_err = true

func _advance() -> void:
	si += 1
	if si >= steps.size():
		_done = true
		note = "Seated and secured."
		note_err = false
		await get_tree().create_timer(0.9).timeout
		completed.emit(slips)
	else:
		_enter()

func _gui_input(e: InputEvent) -> void:
	if _done:
		return
	var st: Dictionary = steps[si]
	if e is InputEventMouseMotion:
		_mouse = (e as InputEventMouseMotion).position
		if _dragging and st.kind == "drag":
			st.pos = (_mouse - _grab).clamp(Vector2(60, 60), Vector2(W - 20, H - 60))
	elif e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		_mouse = mb.position
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press(st)
			else:
				_release(st)
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_rotate(st)
		accept_event()
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		var kc: Key = (e as InputEventKey).keycode
		if kc == KEY_R or kc == KEY_E or kc == KEY_Q:
			_rotate(st)
			accept_event()
		elif kc == KEY_ESCAPE:
			cancelled.emit()
			accept_event()
	queue_redraw()

func rotate_current() -> void:
	if not _done and si < steps.size():
		_rotate(steps[si])
		queue_redraw()

func _rotate(st: Dictionary) -> void:
	if st.kind == "drag" and int(st.inc) > 0:
		st.rot = (int(st.rot) + int(st.inc)) % 4

func _press(st: Dictionary) -> void:
	match String(st.kind):
		"clicks":
			var pts: Array = st.pts
			for i in range(pts.size() - 1, -1, -1):
				var pt: Dictionary = pts[i]
				if int(pt.c) >= int(pt.n):
					continue
				if _mouse.distance_to(pt.p) <= float(pt.r) + 4.0:
					if pt.decoy:
						_slip("That is not a standoff position - use only the glowing holes.")
						return
					pt.c = int(pt.c) + 1
					note = String(st.hint)
					note_err = false
					for q in pts:
						if not q.decoy and int(q.c) < int(q.n):
							return
					_advance()
					return
		"drag":
			var half: float = 50.0 * float(st.scale) * 0.8
			if _mouse.distance_to(st.pos) <= half:
				_dragging = true
				_grab = _mouse - Vector2(st.pos)
		"cables":
			var list: Array = st.list
			for i in list.size():
				if not list[i].done and _mouse.distance_to(list[i].from) <= 20.0:
					_cable = i
					return

func _release(st: Dictionary) -> void:
	if st.kind == "drag" and _dragging:
		_dragging = false
		var d: float = Vector2(st.pos).distance_to(st.target)
		if d <= float(st.tol):
			if int(st.inc) > 0 and int(st.rot) % 4 != 0:
				_slip(String(st.fail))
				return
			st.pos = st.target
			_advance()
		elif d <= float(st.tol) * 3.0:
			_slip("Not quite lined up - nudge it onto the ghost outline.")
	elif st.kind == "cables" and _cable >= 0:
		var list: Array = st.list
		var c: Dictionary = list[_cable]
		_cable = -1
		if _mouse.distance_to(c.to) <= 24.0:
			c.done = true
			note = String(st.hint)
			note_err = false
			for o in list:
				if not o.done:
					return
			_advance()
			return
		for o in list:
			if o != c and not o.done and _mouse.distance_to(o.to) <= 24.0:
				_slip("Wrong socket - %s belongs on the %s socket (match the colour)." % [String(c.label), String(c.label)])
				break

func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	if is_visible_in_tree():
		queue_redraw()

# ------------------------------------------------------------------ drawing

func _txt(p: Vector2, s: String, size: int, col: Color, bold: bool = false) -> void:
	draw_string(K.mono_bold() if bold else K.mono(), p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), K.NAVY0)
	for x in range(0, int(W), 30):
		draw_line(Vector2(x, 0), Vector2(x, H), Color(K.LINE, 0.22), 1.0)
	for y in range(0, int(H), 30):
		draw_line(Vector2(0, y), Vector2(W, y), Color(K.LINE, 0.22), 1.0)
	_scene()
	for i in mini(si + 1, steps.size()):
		_draw_step(steps[i], i == si and not _done)
	if si < steps.size():
		_txt(Vector2(16, 24), String(steps[si].title), 15, K.cat_color(cat), true)
	for i in steps.size():
		var done: bool = i < si or _done
		draw_circle(Vector2(W - 20 - (steps.size() - 1 - i) * 18, 20), 6.0, K.LIME if done else (K.CREAM if i == si else K.LINE))
	draw_rect(Rect2(0, H - 50, W, 50), Color(K.NAVY1, 0.96))
	draw_line(Vector2(0, H - 50), Vector2(W, H - 50), K.DANGER if note_err else K.LINE, 1.5)
	draw_multiline_string(K.body(), Vector2(16, H - 30), note, HORIZONTAL_ALIGNMENT_LEFT, W - 32, 14, 2, K.DANGER if note_err else K.CREAM)
	if slips > 0:
		_txt(Vector2(W - 100, H - 56), "slips: %d" % slips, 11, K.ORANGE)
	if _flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(K.DANGER, _flash * 0.35))
	if _done:
		_txt(Vector2(W * 0.5 - 90, 100), "INSTALLED", 28, K.LIME, true)

func _scene() -> void:
	var tint: Color = K.cat_color(cat)
	draw_rect(CASE_RECT, Color("0b1738"))
	draw_rect(CASE_RECT, K.LINE, false, 2.0)
	_txt(Vector2(CASE_RECT.position.x + 8, CASE_RECT.end.y + 16), "CASE INTERIOR", 10, K.FAINT)
	draw_rect(Rect2(540, 40, 220, 330), Color(K.PANEL, 0.5))
	draw_rect(Rect2(540, 40, 220, 330), Color(K.LINE, 0.6), false, 1.0)
	_txt(Vector2(550, 58), "PARTS BENCH", 10, K.FAINT)
	match cat:
		"motherboard":
			for h in _holes():
				draw_circle(h, 7.0, Color("b08a3a"))
				draw_circle(h, 3.0, K.NAVY0)
		"cpu", "gpu", "ram":
			PartArt.draw_part(self, Transform2D(0.0, Vector2(2.6, 2.6), 0.0, TARGET), "motherboard", {"form": "ATX"}, K.cat_color("motherboard").darkened(0.35), 0.9)
			if cat == "cpu":
				draw_rect(Rect2(TARGET - Vector2(62, 62), Vector2(124, 124)), K.NAVY0)
				draw_rect(Rect2(TARGET - Vector2(62, 62), Vector2(124, 124)), tint, false, 2.0)
				for i in 8:
					for j in 8:
						draw_circle(TARGET - Vector2(48, 48) + Vector2(i, j) * 13.7, 1.6, Color(1, 0.8, 0.3, 0.6))
				draw_colored_polygon(PackedVector2Array([TARGET + Vector2(-62, -62), TARGET + Vector2(-42, -62), TARGET + Vector2(-62, -42)]), K.LIME)
				var up: bool = si >= 1 and si <= 2
				var base := Vector2(338, 245)
				draw_line(base, Vector2(338, 150) if up else Vector2(440, 245), K.CREAM, 5.0)
				draw_circle(base, 5.0, K.FAINT)
			elif cat == "gpu":
				draw_rect(Rect2(80, 300, 360, 18), K.NAVY0)
				draw_rect(Rect2(80, 300, 360, 18), tint, false, 1.5)
				_txt(Vector2(84, 296), "PCIe x16", 10, K.FAINT)
				draw_rect(Rect2(448, 290 if si == 1 else 302, 20, 14), K.ORANGE if si < 2 else K.LIME_DIM)
			else:
				draw_rect(Rect2(130, 300, 420, 26), K.NAVY0)
				draw_rect(Rect2(130, 300, 420, 26), tint, false, 1.5)
				draw_rect(Rect2(335, 324, 10, 8), K.LIME)
				_txt(Vector2(300, 348), "SLOT KEY", 10, K.LIME)
				for cx in [118, 562]:
					draw_rect(Rect2(cx - 10, 296, 20, 34), K.ORANGE if si == 0 else K.LIME_DIM)
		"psu":
			draw_rect(Rect2(50, 262, 240, 126), Color("070e24"))
			draw_rect(Rect2(50, 262, 240, 126), tint, false, 1.5)
			_txt(Vector2(60, 278), "PSU BAY", 10, K.FAINT)
		"storage":
			draw_rect(Rect2(250, 100, 250, 210), Color("070e24"))
			draw_rect(Rect2(250, 100, 250, 210), tint, false, 1.5)
			for y in [110, 296]:
				draw_line(Vector2(256, y), Vector2(494, y), K.FAINT, 3.0)
			_txt(Vector2(256, 326), "DRIVE CAGE", 10, K.FAINT)

func _screw(p: Vector2, hot: bool, done: bool) -> void:
	if done:
		draw_circle(p, 9.0, K.FAINT)
		draw_line(p + Vector2(-5, 0), p + Vector2(5, 0), K.NAVY0, 2.0)
		return
	if hot:
		draw_arc(p, 14.0 + sin(_t * 6.0) * 2.0, 0, TAU, 24, Color(K.LIME, 0.9), 2.0, true)
	draw_circle(p, 9.0, K.CREAM if hot else K.FAINT)
	draw_line(p + Vector2(-5, 0), p + Vector2(5, 0), K.NAVY0, 2.0)
	draw_line(p + Vector2(0, -5), p + Vector2(0, 5), K.NAVY0, 2.0)

func _draw_step(st: Dictionary, active: bool) -> void:
	match String(st.kind):
		"clicks":
			var style := String(st.style)
			for pt in st.pts:
				var p: Vector2 = pt.p
				var left: int = int(pt.n) - int(pt.c)
				if pt.decoy:
					if active:
						draw_arc(p, 11.0, 0, TAU, 16, Color(K.FAINT, 0.7), 1.5, true)
					continue
				if style == "standoff":
					if left <= 0:
						draw_circle(p, 8.0, Color("d9a441"))
						draw_circle(p, 3.5, K.NAVY0)
					elif active:
						draw_arc(p, 13.0 + sin(_t * 6.0) * 2.0, 0, TAU, 20, K.LIME, 2.0, true)
						draw_circle(p, 6.0, K.NAVY0)
				elif style == "lever" or style == "paste" or style == "press":
					if left > 0 and active:
						draw_arc(p, float(pt.r) + sin(_t * 6.0) * 3.0, 0, TAU, 28, K.LIME, 2.5, true)
						if int(pt.n) > 1:
							_txt(p + Vector2(-4, 5), str(left), 14, K.LIME, true)
					elif left <= 0 and style == "paste":
						draw_circle(p, 8.0, Color("c9d1e8"))
					elif left <= 0 and style == "press":
						draw_circle(p, 5.0, K.LIME)
				else:
					_screw(p, active and left > 0, left <= 0)
		"drag":
			var pos: Vector2 = st.pos
			var tgt: Vector2 = st.target
			var sc: float = st.scale
			var tint: Color = K.cat_color(cat)
			if active:
				var near: bool = pos.distance_to(tgt) <= float(st.tol)
				var gcol: Color = K.LIME if near else Color(K.CREAM, 0.5)
				var r := Rect2(tgt - Vector2(50, 35) * sc * 0.8, Vector2(100, 70) * sc * 0.8)
				draw_rect(r, Color(gcol, 0.08 + 0.05 * sin(_t * 5.0)))
				draw_rect(r, gcol, false, 1.5)
			var rot: float = float(int(st.rot)) * PI * 0.5
			PartArt.draw_part(self, Transform2D(rot, Vector2(sc, sc), 0.0, pos), cat, item, tint, 1.0)
			if active:
				if int(st.inc) > 0:
					_txt(pos + Vector2(-46, 50 * sc * 0.8 + 18), "R / right-click = rotate", 11, K.ORANGE if int(st.rot) % 4 != 0 else K.LIME)
				else:
					_txt(pos + Vector2(-34, 50 * sc * 0.8 + 18), "drag me", 11, K.MUTED)
		"cables":
			for i in st.list.size():
				var c: Dictionary = st.list[i]
				var col: Color = c.col
				var tp: Vector2 = c.to
				draw_rect(Rect2(tp - Vector2(14, 11), Vector2(28, 22)), K.NAVY0)
				draw_rect(Rect2(tp - Vector2(14, 11), Vector2(28, 22)), col, false, 2.0)
				_txt(tp + Vector2(20, 4), String(c.label), 10, col)
				var fp: Vector2 = c.from
				if c.done:
					_cable_line(fp, tp, col)
				else:
					draw_circle(fp, 8.0, col)
					if active:
						draw_arc(fp, 12.0 + sin(_t * 6.0) * 2.0, 0, TAU, 20, col, 2.0, true)
						if i == _cable:
							_cable_line(fp, _mouse, col)

func _cable_line(a: Vector2, b: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	var mid := (a + b) * 0.5 + Vector2(0, 26)
	for i in 21:
		var t := float(i) / 20.0
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	draw_polyline(pts, col, 4.0, true)
	draw_circle(b, 6.0, col)
