extends Control
## Pixel viewport, local camera and dynamic actors. Static art lives in WorldBackdrop.
const World = preload("res://src/world/world_rules.gd")
const K = preload("res://src/ui/ui_kit.gd")
const ATLAS = preload("res://assets/town/atlas.png")
var tracked := -1
@onready var _viewport: SubViewport = $Viewport
@onready var _canvas: Node2D = $Viewport/Actors
@onready var _backdrop: Node2D = $Viewport/Backdrop
@onready var _tint: ColorRect = $Viewport/NightTint
var _camera := Vector2.ZERO
var _time := 0.0
var _last_pos := Vector2.ZERO
var _walking := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_paint)


func _process(delta: float) -> void:
	_time += delta
	if not is_visible_in_tree() or Game.me().is_empty():
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var target := Vector2i(maxi(320, int(size.x / 3)), maxi(200, int(size.y / 3)))
	if _viewport.size != target:
		_viewport.size = target
	var p: Dictionary = Game.me()
	_walking = Vector2(p.pos).distance_to(_last_pos) > 0.1
	_last_pos = p.pos
	_canvas.queue_redraw()
	queue_redraw()


func _draw() -> void:
	if is_instance_valid(_viewport):
		draw_texture_rect(_viewport.get_texture(), Rect2(Vector2.ZERO, size), false)


func _rect(r: Rect2, color: String) -> void:
	_canvas.draw_rect(r, Color(color))


func _r(x: float, y: float, w: float, h: float, color: String) -> void:
	_rect(Rect2(x, y, w, h), color)


func _sprite(cell: Vector2i, at: Vector2, scale_factor: float = 1.0, color: Color = Color.WHITE) -> void:
	_canvas.draw_texture_rect_region(ATLAS, Rect2((at - Vector2(16, 24) * scale_factor).round(), Vector2(32, 32) * scale_factor), Rect2(Vector2(cell) * 32, Vector2(32, 32)), color)


func _text(at: Vector2, text: String, color: String = "f7edcb", bold: bool = false) -> void:
	_canvas.draw_string(K.world_font(bold), at.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(color))


func _paint() -> void:
	if Game.me().is_empty():
		return
	var p: Dictionary = Game.me()
	var view := Vector2(_viewport.size)
	var bounds: Vector2 = World.ROOM_SIZE if p.area == "home" else World.TOWN_SIZE
	_camera = Vector2(p.pos) - view * 0.5
	_camera.x = clampf(_camera.x, minf(0, bounds.x - view.x) * 0.5, maxf(0, bounds.x - view.x))
	_camera.y = clampf(_camera.y, minf(0, bounds.y - view.y) * 0.5, maxf(0, bounds.y - view.y))
	_canvas.draw_set_transform(-_camera.round())
	_backdrop.area = str(p.area)
	_backdrop.has_rig = p.installed.has("case")
	_backdrop.position = -_camera.round()
	var actors: Array = []
	for pid in Game.state.players:
		var other: Dictionary = Game.state.players[pid]
		if other.area != p.area:
			continue
		if p.area == "town":
			actors.append({"pos": other.car_pos, "kind": "car", "p": other, "id": int(pid)})
		if not other.driving:
			actors.append({"pos": other.pos, "kind": "person", "p": other, "id": int(pid)})
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
		if actor.kind == "car":
			_car(actor.pos, actor.p, actor.id)
		elif actor.kind == "person":
			_person(actor.pos, actor.p.facing, actor.id, str(actor.p.name))
		else:
			_person(actor.pos, Vector2.DOWN, 9, str(actor.meeting.contact))
			_r(actor.pos.x - 3, actor.pos.y - 35, 6, 9, "fff1b9")
			_text(actor.pos + Vector2(-1, -28), "!", "8f5b56", true)
	if p.area == "town":
		_track(p, view)
	# A restrained day/night tint. Appointment text/HUD stays outside the world viewport.
	var hour: float = fmod(Game.clock() / 60.0, 24.0)
	var night := 0.0
	if hour >= 19:
		night = minf(0.48, (hour - 19) * 0.12)
	elif hour < 7:
		night = minf(0.48, (7 - hour) * 0.12)
	_tint.size = view
	_tint.color = Color(0.08, 0.12, 0.30, night)


func _person(at: Vector2, facing: Vector2, id: int, label: String) -> void:
	var dir := 0
	if absf(facing.x) > absf(facing.y):
		dir = 2 if facing.x < 0 else 3
	elif facing.y < 0:
		dir = 1
	var frame := int(_time * 7) % 2 if _walking and id == Game.local_id() else 0
	var tint := Color.WHITE if id == Game.local_id() else Color.from_hsv(fmod(id * 0.17, 1.0), 0.20, 1.0)
	_r(at.x - 6, at.y - 2, 12, 4, "70856d")
	_sprite(Vector2i(dir * 2 + frame, 0), at + Vector2(0, 1), 1, tint)
	if id != Game.local_id():
		_text(at + Vector2(-18, -26), label, "273f4a")


func _car(at: Vector2, player: Dictionary, _id: int) -> void:
	var facing: Vector2 = player.facing if player.driving else Vector2.LEFT
	var key := "car_side"
	if absf(facing.y) > absf(facing.x):
		key = "car_front" if facing.y > 0 else "car_rear"
	var extent := Vector2(40, 32)
	var rect := Rect2((at - extent * 0.5).round(), extent)
	if key == "car_side" and facing.x > 0:
		# draw_texture_rect flips negative widths without moving the destination origin.
		rect.size.x = -extent.x
	_canvas.draw_texture_rect(preload("res://src/ui/art_library.gd").WORLD[key], rect, false)


func _track(p: Dictionary, _view: Vector2) -> void:
	for m: Dictionary in Game.active_meetings(p):
		if int(m.listing_id) != tracked:
			continue
		var target: Vector2 = m.pos
		_canvas.draw_arc(target, 23, 0, TAU, 16, Color("fff3ab"), 2)
		var pos: Vector2 = p.pos
		var delta := target - pos
		if delta.length() > 40:
			var marker: Vector2 = (pos + delta.normalized() * 44).round()
			_canvas.draw_line(marker - delta.normalized() * 6, marker + delta.normalized() * 6, Color("fff4b8"), 3)
			_text(marker + Vector2(4, -6), "%dm" % int(delta.length()), "fff4b8")
		break
