extends Control
## Drawn city map with listing pins and an animated pickup car.
const K = preload("res://scripts/ui_kit.gd")
signal pin_clicked(listing_id: int)

var listings: Array = []
var selected_id: int = -1
var trip: Dictionary = {}
var progress: float = 0.0   # 0..1 visual progress of current trip (display only)
var home_pos: Variant = null
var _min := Vector2(INF, INF)
var _max := Vector2(-INF, -INF)
var _pins: Array = []       # [{id, p(px)}]
var _hover: int = -1
var _t: float = 0.0
var _blocks: Array = []

func _init() -> void:
	custom_minimum_size = Vector2(520, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 8841
	for gx in 12:
		for gy in 8:
			if rng.randf() < 0.82:
				_blocks.append([Vector2i(gx, gy), rng.randf_range(0.0, 1.0), rng.randi_range(0, 3)])

func set_data(p_listings: Array, p_trip: Dictionary, p_selected: int) -> void:
	listings = p_listings
	trip = p_trip
	selected_id = p_selected
	for l in listings:
		var p: Vector2 = l.get("pos", Vector2.ZERO)
		_min = _min.min(p)
		_max = _max.max(p)
	if not trip.is_empty():
		for k in ["origin", "destination"]:
			var q: Vector2 = trip.get(k, Vector2.ZERO)
			_min = _min.min(q)
			_max = _max.max(q)
		home_pos = trip.get("origin", Vector2.ZERO)
	queue_redraw()

func _process(delta: float) -> void:
	if visible and is_visible_in_tree():
		_t += delta
		queue_redraw()

func _to_px(p: Vector2) -> Vector2:
	var pad := 52.0
	var span := _max - _min
	if span.x <= 0.0001: span.x = 1.0
	if span.y <= 0.0001: span.y = 1.0
	var n := (p - _min) / span
	return Vector2(pad + n.x * (size.x - pad * 2.0), pad + n.y * (size.y - pad * 2.0))

func _home_px() -> Vector2:
	if home_pos != null:
		return _to_px(home_pos)
	if _min.x == INF:
		return size * 0.5
	return _to_px((_min + _max) * 0.5)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _pin_at((event as InputEventMouseMotion).position)
		if h != _hover:
			_hover = h
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h >= 0 else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var id := _pin_at((event as InputEventMouseButton).position)
		if id >= 0:
			pin_clicked.emit(id)
			accept_event()

func _pin_at(pos: Vector2) -> int:
	var best := -1
	var bd := 18.0
	for pin in _pins:
		var d: float = pos.distance_to(pin["p"])
		if d < bd:
			bd = d
			best = pin["id"]
	return best

func _draw() -> void:
	var f: Font = K.mono()
	draw_rect(Rect2(Vector2.ZERO, size), Color("08122b"))
	# city blocks
	var cell := Vector2(size.x / 12.0, size.y / 8.0)
	for b in _blocks:
		var g: Vector2i = b[0]
		var r := Rect2(Vector2(g.x, g.y) * cell + Vector2(6, 6), cell - Vector2(12, 12))
		var kind: int = b[2]
		var col := Color("0f1d42")
		if kind == 0:
			col = Color("0f2a2c")  # park
		elif kind == 1:
			col = Color("13224c")
		draw_rect(r, col)
		if kind >= 2:
			var h: float = 0.3 + float(b[1]) * 0.6
			draw_rect(Rect2(r.position + r.size * 0.2, r.size * 0.6 * Vector2(1, h)), Color("1a2f63"))
	# roads
	for i in range(1, 12):
		draw_line(Vector2(i * cell.x, 0), Vector2(i * cell.x, size.y), Color("1b2e5e"), 3.0)
	for j in range(1, 8):
		draw_line(Vector2(0, j * cell.y), Vector2(size.x, j * cell.y), Color("1b2e5e"), 3.0)
	# river
	var river := PackedVector2Array()
	for i in 25:
		var x: float = size.x * i / 24.0
		river.append(Vector2(x, size.y * 0.58 + sin(i * 0.55) * 24.0))
	draw_polyline(river, Color("16457a"), 14.0, true)
	draw_polyline(river, Color("245f9c", 0.6), 2.0, true)
	draw_string(f, Vector2(14, size.y - 12), "SLOPYARD BASIN // PICKUP MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, K.FAINT)
	# pins
	_pins.clear()
	for l in listings:
		var st := String(l.get("status", "available"))
		var lid: int = int(l.get("id", -1))
		var p := _to_px(l.get("pos", Vector2.ZERO))
		var col: Color = K.cat_color(String(l.get("category", "cpu")))
		if st != "available":
			col = K.FAINT
		else:
			_pins.append({"id": lid, "p": p})
		var sel: bool = lid == selected_id
		var rad: float = 7.0 + (3.0 if sel or lid == _hover else 0.0)
		if sel:
			draw_arc(p, rad + 6 + sin(_t * 4.0) * 2.0, 0, TAU, 28, Color(K.LIME, 0.8), 1.5, true)
		draw_circle(p, rad, K.NAVY0)
		draw_circle(p, rad - 2.0, col)
		if sel or lid == _hover:
			var label := "%s  %s" % [String(l.get("category", "")).to_upper(), K.money(l.get("price", 0))]
			var w: float = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var lp := p + Vector2(-w * 0.5, -rad - 12)
			draw_rect(Rect2(lp - Vector2(6, 13), Vector2(w + 12, 20)), Color(K.NAVY0, 0.92))
			draw_rect(Rect2(lp - Vector2(6, 13), Vector2(w + 12, 20)), col, false, 1.0)
			draw_string(f, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, K.CREAM)
	# garage
	var home := _home_px()
	draw_rect(Rect2(home - Vector2(12, 9), Vector2(24, 18)), K.LIME)
	draw_colored_polygon(PackedVector2Array([home + Vector2(-14, -9), home + Vector2(0, -19), home + Vector2(14, -9)]), K.LIME)
	draw_rect(Rect2(home - Vector2(5, 0), Vector2(10, 9)), K.NAVY0)
	draw_string(f, home + Vector2(-18, 30), "GARAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, K.LIME)
	# route + car
	if not trip.is_empty():
		var a := _to_px(trip.get("origin", Vector2.ZERO))
		var b := _to_px(trip.get("destination", Vector2.ZERO))
		var steps := int(a.distance_to(b) / 14.0)
		for i in steps:
			if i % 2 == 0:
				draw_line(a.lerp(b, float(i) / steps), a.lerp(b, float(i + 1) / steps), K.ORANGE, 3.0)
		draw_arc(b, 12 + fmod(_t * 14.0, 14.0), 0, TAU, 28, Color(K.ORANGE, 0.8 - fmod(_t * 14.0, 14.0) / 18.0), 2.0, true)
		var cp: Vector2 = a.lerp(b, clampf(progress, 0.0, 1.0))
		_draw_car(cp, (b - a).angle())
	else:
		_draw_car(home + Vector2(26, 6), 0.0, 0.6)

func _draw_car(p: Vector2, ang: float, alpha: float = 1.0) -> void:
	draw_set_transform(p, ang, Vector2.ONE)
	var bob: float = sin(_t * 18.0) * 0.6
	draw_rect(Rect2(-15, -7 + bob, 30, 14), Color(K.LIME, alpha))
	draw_rect(Rect2(-6, -6 + bob, 12, 12), Color(K.NAVY0, 0.85 * alpha))
	draw_rect(Rect2(10, -5 + bob, 4, 3), Color(K.CREAM, alpha))
	draw_rect(Rect2(10, 2 + bob, 4, 3), Color(K.CREAM, alpha))
	draw_circle(Vector2(-9, -8), 3.2, K.NAVY0)
	draw_circle(Vector2(-9, 8), 3.2, K.NAVY0)
	draw_circle(Vector2(9, -8), 3.2, K.NAVY0)
	draw_circle(Vector2(9, 8), 3.2, K.NAVY0)
	draw_set_transform_matrix(Transform2D.IDENTITY)
