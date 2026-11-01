extends Control
## Rotary dial for normalized clock multiplier / voltage (1.00 .. 1.60).
const K = preload("res://scripts/ui_kit.gd")
signal value_changed(v: float)

const A0 := deg_to_rad(135.0)
const SPAN := deg_to_rad(270.0)

var title: String = "CLOCK"
var unit: String = "x"
var value: float = 1.0
var min_v: float = 1.0
var max_v: float = 1.6
var warn_from: float = 1.3
var danger_from: float = 1.4
var tint: Color = K.LIME
var _drag: bool = false

func _init() -> void:
	custom_minimum_size = Vector2(170, 170)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_DRAG

func set_value(v: float, emit: bool = false) -> void:
	var nv: float = snappedf(clampf(v, min_v, max_v), 0.01)
	if is_equal_approx(nv, value):
		return
	value = nv
	queue_redraw()
	if emit:
		value_changed.emit(value)

func _frac(v: float) -> float:
	return (v - min_v) / (max_v - min_v)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
			if _drag:
				grab_focus()
				_set_from_pos(mb.position)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_value(value + 0.01, true)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_value(value - 0.01, true)
			accept_event()
	elif event is InputEventMouseMotion and _drag:
		_set_from_pos((event as InputEventMouseMotion).position)
		accept_event()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		var k := event as InputEventKey
		var step: float = 0.05 if k.shift_pressed else 0.01
		if k.keycode == KEY_RIGHT or k.keycode == KEY_UP:
			set_value(value + step, true)
			accept_event()
		elif k.keycode == KEY_LEFT or k.keycode == KEY_DOWN:
			set_value(value - step, true)
			accept_event()

func _set_from_pos(p: Vector2) -> void:
	var c := size * 0.5
	var a: float = (p - c).angle()  # -PI..PI, 0 = right
	var rel: float = fposmod(a - A0, TAU)
	var f: float
	if rel <= SPAN:
		f = rel / SPAN
	else:
		f = 1.0 if rel - SPAN < (TAU - SPAN) * 0.5 else 0.0
	set_value(min_v + f * (max_v - min_v), true)

func _zone_color() -> Color:
	if value >= danger_from:
		return K.DANGER
	if value >= warn_from:
		return K.ORANGE
	return tint

func _draw() -> void:
	var c := size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 14.0
	# track
	draw_arc(c, r, A0, A0 + SPAN, 64, Color("17274f"), 10.0, true)
	# zones
	var fw: float = _frac(warn_from)
	var fd: float = _frac(danger_from)
	draw_arc(c, r, A0, A0 + SPAN * fw, 40, Color(tint, 0.35), 4.0, true)
	draw_arc(c, r, A0 + SPAN * fw, A0 + SPAN * fd, 20, Color(K.ORANGE, 0.45), 4.0, true)
	draw_arc(c, r, A0 + SPAN * fd, A0 + SPAN, 20, Color(K.DANGER, 0.55), 4.0, true)
	# value arc
	var fv: float = _frac(value)
	if fv > 0.001:
		draw_arc(c, r, A0, A0 + SPAN * fv, 48, _zone_color(), 10.0, true)
	# ticks
	for i in 13:
		var a: float = A0 + SPAN * i / 12.0
		var d := Vector2.RIGHT.rotated(a)
		draw_line(c + d * (r - 12), c + d * (r - (18 if i % 3 == 0 else 15)), K.FAINT, 1.2)
	# knob
	draw_circle(c, r - 24, K.NAVY0)
	draw_arc(c, r - 24, 0, TAU, 40, K.LINE, 1.5, true)
	var ang: float = A0 + SPAN * fv
	var dir := Vector2.RIGHT.rotated(ang)
	draw_line(c + dir * (r - 44), c + dir * (r - 26), _zone_color(), 4.0, true)
	draw_circle(c + dir * (r - 18), 4.0, _zone_color())
	var f: Font = K.mono_bold()
	var txt: String = ("%.2f" % value) + unit
	var ts: Vector2 = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	draw_string(f, c + Vector2(-ts.x * 0.5, 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, _zone_color())
	var fm: Font = K.mono()
	var ts2: Vector2 = fm.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	draw_string(fm, c + Vector2(-ts2.x * 0.5, -18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, K.MUTED)
	if has_focus():
		draw_arc(c, r + 8, 0, TAU, 48, Color(K.LIME, 0.6), 1.5, true)
