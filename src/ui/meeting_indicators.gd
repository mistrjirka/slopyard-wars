extends Control
## Passive meeting guidance. Full map and Agreed inbox retain individual pickup details.
const TownView = preload("res://src/world/town_view.gd")
const Relationships = preload("res://src/trading/contact_relationships.gd")
const K = preload("res://src/ui/ui_kit.gd")
const UPCOMING := Color("aab3c0")
const ACTIVE := Color("8af19b")
const URGENT := Color("ff5264")
const INSET := 22.0
const FONT_SIZE := 15
const ROW_HEIGHT := 21.0
const GAP := 5.0
const MARKER_WIDTH := 54.0

class MeetingGroup:
	var times: Dictionary[int, int] = {}
	var urgency: int = 0

var _world: TownView
var _checklist: Control
var _footer: Control


func setup(world: TownView, checklist: Control, footer: Control) -> void:
	_world = world
	_checklist = checklist
	_footer = footer


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _safe_rect() -> Rect2:
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var top_left := inverse * _world.get_global_rect().position + Vector2(INSET, INSET)
	var bottom_right := inverse * _world.get_global_rect().end - Vector2(INSET, INSET)
	# Leave the checklist, top bar and dynamically sized footer completely clear.
	top_left.y = maxf(top_left.y, (inverse * _checklist.get_global_rect().end).y + INSET)
	bottom_right.y = minf(bottom_right.y, (inverse * _footer.get_global_rect().position).y - INSET)
	return Rect2(top_left, (bottom_right - top_left).max(Vector2.ZERO))


func _draw() -> void:
	if not is_instance_valid(_world) or Game.me().is_empty():
		return
	var player: Dictionary = Game.me()
	if player.area != "town":
		return
	var safe := _safe_rect()
	if safe.size.x < 100.0 or safe.size.y < 40.0:
		return
	var now: float = Game.clock()
	var groups: Dictionary[Vector2, MeetingGroup] = {}
	for meeting: Dictionary in Game.active_meetings(player):
		var id := int(meeting.listing_id)
		var listing: Dictionary = Game.market.listing(id)
		if listing.is_empty() or listing.get("status", "gone") != "available":
			continue
		if int(player.get("offers", {}).get(id, 0)) <= 0 or Relationships.blocked(player, listing):
			continue
		if str(meeting.status) == "missed" or now > float(meeting.end):
			continue
		var urgency := 0
		if now >= float(meeting.start):
			urgency = 2 if float(meeting.end) - now <= 10.0 else 1
		var destination: Vector2 = meeting.pos
		if not groups.has(destination):
			groups[destination] = MeetingGroup.new()
		var group: MeetingGroup = groups[destination]
		var start := int(meeting.start)
		group.times[start] = maxi(group.times.get(start, 0), urgency)
		group.urgency = maxi(group.urgency, urgency)
	var destinations: Array[Vector2] = groups.keys()
	destinations.sort_custom(func(a: Vector2, b: Vector2) -> bool: return groups[a].urgency > groups[b].urgency)
	var occupied: Array[Rect2] = []
	var inverse := get_global_transform_with_canvas().affine_inverse()
	# Reserve all visible destinations before placing any labels, including low-priority dots.
	for destination: Vector2 in destinations:
		var target := inverse * _world.world_to_screen(destination)
		if safe.grow(-17.0).has_point(target):
			occupied.append(Rect2(target - Vector2(17, 17), Vector2(34, 34)))
	for destination: Vector2 in destinations:
		var target := inverse * _world.world_to_screen(destination)
		var group: MeetingGroup = groups[destination]
		var starts: Array[int] = group.times.keys()
		starts.sort()
		var label_size := _label_size(starts, now)
		if safe.grow(-17.0).has_point(target):
			_draw_marker(target, Vector2.ZERO, group.urgency)
			var box := _place_box(target + Vector2(21, -label_size.y * 0.5), label_size, safe, occupied)
			if box.has_area():
				occupied.append(box)
				var nearest := target.clamp(box.position, box.end)
				if nearest.distance_to(target) > 27.0:
					draw_line(target, nearest, Color("aab3c080"), 1.0, true)
				_draw_times(box, starts, group, now)
		else:
			var direction := target - safe.get_center()
			var half := safe.size * 0.5
			var ratio := maxf(absf(direction.x) / half.x, absf(direction.y) / half.y)
			var edge := safe.get_center() + direction / ratio
			var marker_right := target.x > safe.get_center().x
			var size := Vector2(label_size.x + MARKER_WIDTH, maxf(50.0, label_size.y))
			var preferred := edge - Vector2(size.x if marker_right else 0.0, size.y * 0.5)
			var box := _place_box(preferred, size, safe, occupied)
			if not box.has_area():
				continue
			occupied.append(box)
			var at := Vector2(box.end.x - 25.0 if marker_right else box.position.x + 25.0, box.get_center().y)
			var label_at := Vector2(box.position.x if marker_right else box.position.x + MARKER_WIDTH, box.get_center().y - label_size.y * 0.5)
			_draw_marker(at, (target - at).normalized(), group.urgency)
			_draw_times(Rect2(label_at, label_size), starts, group, now)


func _time_text(start: int, now: float) -> String:
	var clock := "%02d:%02d" % [(start % 1440) / 60, start % 60]
	return clock if start / 1440 == int(now) / 1440 else "D%d %s" % [1 + start / 1440, clock]


func _label_size(starts: Array[int], now: float) -> Vector2:
	var width := 0.0
	for start: int in starts:
		width = maxf(width, K.mono_bold().get_string_size(_time_text(start, now), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	return Vector2(ceilf(width) + 12.0, starts.size() * ROW_HEIGHT + 4.0)


func _place_box(preferred: Vector2, size: Vector2, safe: Rect2, occupied: Array[Rect2]) -> Rect2:
	if size.x > safe.size.x or size.y > safe.size.y:
		return Rect2()
	var origin := preferred.clamp(safe.position, safe.end - size)
	# Candidate boundaries pack whole boxes (not just marker centers), including corners.
	var xs: Array[float] = [origin.x, safe.position.x, safe.end.x - size.x]
	var ys: Array[float] = [origin.y, safe.position.y, safe.end.y - size.y]
	for other: Rect2 in occupied:
		xs.append(clampf(other.position.x - size.x - GAP, safe.position.x, safe.end.x - size.x))
		xs.append(clampf(other.end.x + GAP, safe.position.x, safe.end.x - size.x))
		ys.append(clampf(other.position.y - size.y - GAP, safe.position.y, safe.end.y - size.y))
		ys.append(clampf(other.end.y + GAP, safe.position.y, safe.end.y - size.y))
	var best := Rect2()
	var distance := INF
	for x: float in xs:
		for y: float in ys:
			var candidate := Rect2(Vector2(x, y), size)
			var score := candidate.position.distance_squared_to(origin)
			if score >= distance:
				continue
			var clear := true
			for other: Rect2 in occupied:
				if candidate.grow(GAP).intersects(other):
					clear = false
					break
			if clear:
				best = candidate
				distance = score
	return best


func _color(urgency: int) -> Color:
	return UPCOMING if urgency == 0 else (ACTIVE if urgency == 1 else URGENT)


func _draw_times(box: Rect2, starts: Array[int], group: MeetingGroup, now: float) -> void:
	draw_style_box(_label_backdrop(), box)
	var font := K.mono_bold()
	var baseline := box.position + Vector2(6, 2 + (ROW_HEIGHT - font.get_height(FONT_SIZE)) * 0.5 + font.get_ascent(FONT_SIZE))
	for start: int in starts:
		var text := _time_text(start, now)
		draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, Color("050a1a"))
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, _color(group.times[start]))
		baseline.y += ROW_HEIGHT


func _label_backdrop() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101c2cf0")
	style.set_corner_radius_all(4)
	return style


func _draw_marker(at: Vector2, direction: Vector2, urgency: int) -> void:
	var color := _color(urgency)
	if urgency > 0:
		draw_circle(at, 15, Color(color, 0.07))
		draw_circle(at, 11, Color(color, 0.16))
	draw_circle(at, 8 if urgency == 2 else 6, Color("101c2ce6"))
	if direction != Vector2.ZERO:
		var side := direction.orthogonal()
		var tip := at + direction * 9
		draw_colored_polygon(PackedVector2Array([tip, at - direction * 5 + side * 6, at - direction * 5 - side * 6]), color)
		if urgency == 2:
			_draw_exclamation(at - direction * 15, color)
	elif urgency == 2:
		_draw_exclamation(at, color)
	else:
		draw_circle(at, 4, color)


func _draw_exclamation(at: Vector2, color: Color) -> void:
	draw_circle(at, 9, Color("101c2ce6"))
	draw_line(at + Vector2(0, -5), at + Vector2(0, 1), color, 3, true)
	draw_circle(at + Vector2(0, 5), 1.8, color)
