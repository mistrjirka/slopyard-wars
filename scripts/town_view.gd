extends Control
## Original low-resolution pixel-art world, nearest scaled under the high-resolution phone/HUD.
const World = preload("res://scripts/world_rules.gd")
const Trade = preload("res://scripts/trade_rules.gd")
const Catalog = preload("res://scripts/catalog.gd")
const ATLAS = preload("res://assets/town/atlas.png")
var tracked := -1
var _viewport: SubViewport
var _canvas: Node2D
var _camera := Vector2.ZERO
var _time := 0.0
var _last_pos := Vector2.ZERO
var _walking := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(480, 300)
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_canvas = Node2D.new()
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_paint)
	_viewport.add_child(_canvas)

func _process(delta: float) -> void:
	_time += delta
	if not is_visible_in_tree() or Game.me().is_empty(): return
	var target := Vector2i(maxi(320, int(size.x / 3)), maxi(200, int(size.y / 3)))
	if _viewport.size != target: _viewport.size = target
	var p: Dictionary = Game.me()
	_walking = Vector2(p.pos).distance_to(_last_pos) > 0.1
	_last_pos = p.pos
	_canvas.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if is_instance_valid(_viewport): draw_texture_rect(_viewport.get_texture(), Rect2(Vector2.ZERO, size), false)

func _rect(r: Rect2, color: String) -> void:
	_canvas.draw_rect(r, Color(color))
func _r(x: float, y: float, w: float, h: float, color: String) -> void:
	_rect(Rect2(x, y, w, h), color)
func _sprite(cell: Vector2i, at: Vector2, scale_factor: float = 1.0, color: Color = Color.WHITE) -> void:
	_canvas.draw_texture_rect_region(ATLAS, Rect2((at - Vector2(16, 24) * scale_factor).round(), Vector2(32, 32) * scale_factor), Rect2(Vector2(cell) * 32, Vector2(32, 32)), color)
func _text(at: Vector2, text: String, color: String = "f7edcb", font_size: int = 8) -> void:
	_canvas.draw_string(ThemeDB.fallback_font, at.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color))

func _paint() -> void:
	if Game.me().is_empty(): return
	var p: Dictionary = Game.me()
	var view := Vector2(_viewport.size)
	var bounds: Vector2 = World.ROOM_SIZE if p.area == "home" else World.TOWN_SIZE
	_camera = Vector2(p.pos) - view * 0.5
	_camera.x = clampf(_camera.x, minf(0, bounds.x - view.x) * 0.5, maxf(0, bounds.x - view.x))
	_camera.y = clampf(_camera.y, minf(0, bounds.y - view.y) * 0.5, maxf(0, bounds.y - view.y))
	_canvas.draw_set_transform(-_camera.round())
	if p.area == "home": _house()
	else: _town()
	var actors: Array = []
	for pid in Game.state.players:
		var other: Dictionary = Game.state.players[pid]
		if other.area != p.area: continue
		if p.area == "town":
			actors.append({"pos": other.car_pos, "kind": "car", "p": other, "id": int(pid)})
		if not other.driving: actors.append({"pos": other.pos, "kind": "person", "p": other, "id": int(pid)})
	if p.area == "town":
		var contacts := {}
		for player: Dictionary in Game.state.players.values():
			for m: Dictionary in Game.active_meetings(player):
				var key := str(m.contact) + str(m.pos)
				if m.status == "now" and not contacts.has(key):
					contacts[key] = true
					actors.append({"pos": m.pos, "kind": "contact", "meeting": m})
	actors.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for actor: Dictionary in actors:
		if actor.kind == "car": _car(actor.pos, actor.p, actor.id)
		elif actor.kind == "person": _person(actor.pos, actor.p.facing, actor.id, str(actor.p.name))
		else:
			_person(actor.pos, Vector2.DOWN, 9, str(actor.meeting.contact))
			_r(actor.pos.x - 3, actor.pos.y - 35, 6, 9, "fff1b9")
			_text(actor.pos + Vector2(-1, -28), "!", "8f5b56", 10)
	if p.area == "town": _track(p, view)
	# A restrained day/night tint. Appointment text/HUD stays outside the world viewport.
	var hour: float = fmod(Game.clock() / 60.0, 24.0)
	var night := 0.0
	if hour >= 19: night = minf(0.48, (hour - 19) * 0.12)
	elif hour < 7: night = minf(0.48, (7 - hour) * 0.12)
	_canvas.draw_set_transform(Vector2.ZERO)
	_canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0.08, 0.12, 0.30, night))

func _house() -> void:
	_r(0, 0, 384, 256, "3b4058")
	_r(18, 22, 348, 218, "d5bc8e")
	for y in range(24, 239, 16):
		for x in range(20, 364, 32):
			_r(x, y, 31, 1, "b9a17c")
			_r(x + ((y / 16) % 2) * 15, y + 1, 1, 15, "c6ac82")
	_r(18, 16, 348, 17, "7e777a")
	_r(18, 17, 348, 3, "b8b1a4")
	_r(18, 33, 6, 207, "a78976")
	_r(360, 33, 6, 207, "a78976")
	_r(18, 237, 348, 8, "705d61")
	_r(177, 237, 32, 9, "d2aa72")
	_r(178, 243, 30, 3, "aa784d")
	# Windows, curtains, posters and shelves establish a lived-in room.
	for x in [177, 221]:
		_r(x, 18, 28, 20, "483f53")
		_r(x + 2, 20, 24, 16, "a4d6c2")
		_r(x + 13, 20, 2, 16, "f3e0ae")
		_r(x, 18, 4, 23, "aa7376")
		_r(x + 24, 18, 4, 23, "aa7376")
	_sprite(Vector2i(0, 2), Vector2(60, 72), 1.3)
	_sprite(Vector2i(0, 2), Vector2(103, 72), 1.3)
	_text(Vector2(39, 32), "PC WORKBENCH", "fff0c2", 8)
	_sprite(Vector2i(2, 2), Vector2(304, 78), 2.2)
	_sprite(Vector2i(1, 2), Vector2(307, 157), 2.0)
	_sprite(Vector2i(3, 2), Vector2(206, 181), 2.2)
	_sprite(Vector2i(2, 2), Vector2(76, 169), 1.8)
	_r(135, 89, 42, 33, "664f57")
	_r(138, 88, 36, 28, "b18b66")
	_r(148, 94, 11, 12, "dfcfaa")
	_r(264, 42, 77, 18, "594a57")
	for i in 9: _r(268 + i * 7, 43, 4, 12, ["a97877", "799d97", "b6a27e"][i % 3])
	_r(283, 172, 16, 17, "8e666c")
	_text(Vector2(262, 203), "Space: wait", "6a5a61")
	_text(Vector2(169, 231), "OUTSIDE", "725a58")

func _road(r: Rect2, horizontal: bool) -> void:
	_rect(r.grow(4), "c9bb91")
	_rect(r, "7d8990")
	if horizontal:
		for x in range(int(r.position.x) + 10, int(r.end.x), 32): _r(x, r.get_center().y, 13, 1, "dbd2ad")
	else:
		for y in range(int(r.position.y) + 10, int(r.end.y), 32): _r(r.get_center().x, y, 1, 13, "dbd2ad")

func _building(r: Rect2, index: int) -> void:
	var roof: String = ["b86f65", "698e9e", "8b82a0", "b49562"][index % 4]
	_rect(r.grow(3), "46515c")
	_rect(r, "e1cd9c")
	_rect(Rect2(r.position + Vector2(0, -6), Vector2(r.size.x, r.size.y * 0.56)), roof)
	for y in range(int(r.position.y), int(r.position.y + r.size.y * 0.50), 6):
		_canvas.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color("574d61"), 1)
		for x in range(int(r.position.x) + (y % 12), int(r.end.x), 16): _r(x, y, 1, 6, "806b6d")
	_r(r.position.x - 3, r.position.y + r.size.y * 0.53, r.size.x + 6, 4, "565360")
	for x in [r.position.x + 12, r.end.x - 28]:
		_r(x, r.end.y - 29, 18, 18, "806a63")
		_r(x + 2, r.end.y - 27, 14, 13, "aed0ba")
		_r(x + 8, r.end.y - 27, 1, 13, "f1dfa6")
	_r(r.get_center().x - 9, r.end.y - 26, 18, 26, "725d60")
	_r(r.get_center().x - 6, r.end.y - 22, 12, 21, "a98067")
	_r(r.get_center().x + 3, r.end.y - 12, 2, 2, "e7c877")
	_r(r.position.x + 14, r.position.y - 10, 9, 17, "675a63")

func _town() -> void:
	_r(0, 0, 1024, 640, "96b875")
	for y in range(0, 640, 16):
		for x in range(0, 1024, 16):
			var n := (x * 13 + y * 7) % 113
			if n < 31:
				_r(x + 3, y + 5, 2, 3, "76a36b")
				_r(x + 6, y + 4, 1, 3, "bed18a")
			if n == 40:
				_r(x + 5, y + 5, 3, 2, "e4c78e")
	for y in [128, 336, 496]: _road(Rect2(20, y, 984, 32), true)
	for x in [144, 328, 592, 840]: _road(Rect2(x, 24, 32, 600), false)
	_r(400, 510, 135, 115, "607f91")
	_r(406, 516, 123, 103, "74a4b0")
	for y in range(524, 616, 12):
		for x in range(412, 527, 25): _r(x, y, 12, 1, "abd0c9")
	for i in World.BUILDINGS.size(): _building(World.BUILDINGS[i], i)
	_building(World.HOME_BUILDING, 1)
	_text(Vector2(454, 194), "YOUR HOME", "304a50", 9)
	for x in range(472, 521, 10): _r(x, 306, 8, 29, "d2c08f")
	for i in 33:
		var at := Vector2(25 + (i * 97) % 974, 36 + (i * 173) % 570)
		if not World.clear_at("town", at, 24): continue
		# Keep roads and all meeting clearances readable.
		var blocked := false
		for meet: Vector2 in Catalog.LOCATIONS.values():
			if at.distance_to(meet) < 50: blocked = true
		if blocked or absi(int(at.x) - 500) < 70: continue
		_sprite(Vector2i(4 + i % 4, 1), at, 1.5)
	for name: String in Catalog.LOCATIONS:
		var at: Vector2 = Catalog.LOCATIONS[name]
		_r(at.x - 3, at.y + 1, 6, 6, "d8ca9c")
		_r(at.x - 2, at.y - 9, 4, 13, "75676a")
		_r(at.x - 13, at.y - 14, 26, 8, "f0dfac")
		var label := name.replace(" Market", "").replace(" Storage", "").replace(" Cul-de-sac", "").replace(" Garage", "")
		_text(at + Vector2(-25, 17), label, "30474e", 8)
	# Fence border.
	for x in range(8, 1024, 16):
		_r(x, 12, 3, 12, "7c7468"); _r(x, 620, 3, 12, "7c7468")
	_r(8, 16, 1008, 2, "b5a385")
	_r(8, 624, 1008, 2, "b5a385")

func _person(at: Vector2, facing: Vector2, id: int, label: String) -> void:
	var dir := 0
	if absf(facing.x) > absf(facing.y): dir = 2 if facing.x < 0 else 3
	elif facing.y < 0: dir = 1
	var frame := int(_time * 7) % 2 if _walking and id == Game.local_id() else 0
	var tint := Color.WHITE if id == Game.local_id() else Color.from_hsv(fmod(id * 0.17, 1.0), 0.20, 1.0)
	_r(at.x - 6, at.y - 2, 12, 4, "70856d")
	_sprite(Vector2i(dir * 2 + frame, 0), at + Vector2(0, 1), 1, tint)
	if id != Game.local_id(): _text(at + Vector2(-18, -26), label, "273f4a", 8)

func _car(at: Vector2, p: Dictionary, id: int) -> void:
	var facing: Vector2 = p.facing if p.driving else Vector2.LEFT
	_canvas.draw_set_transform((at - _camera).round(), facing.angle() - PI, Vector2.ONE)
	_canvas.draw_texture_rect_region(ATLAS, Rect2(-16, -16, 32, 32), Rect2((id % 4) * 32, 32, 32, 32))
	_canvas.draw_set_transform(-_camera.round())

func _track(p: Dictionary, view: Vector2) -> void:
	for m: Dictionary in Game.active_meetings(p):
		if int(m.listing_id) != tracked: continue
		var target: Vector2 = m.pos
		_canvas.draw_arc(target, 23, 0, TAU, 16, Color("fff3ab"), 2)
		var pos: Vector2 = p.pos
		var delta := target - pos
		if delta.length() > 40:
			var marker: Vector2 = (pos + delta.normalized() * 44).round()
			_canvas.draw_line(marker - delta.normalized() * 6, marker + delta.normalized() * 6, Color("fff4b8"), 3)
			_text(marker + Vector2(4, -6), "%dm" % int(delta.length()), "fff4b8", 9)
		break
