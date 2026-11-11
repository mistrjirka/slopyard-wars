extends Control
## Asset-backed overview and compact HUD map; both share the walkable world's backdrop.
const Activities = preload("res://src/world/activities.gd")
const World = preload("res://src/world/world_rules.gd")
const Catalog = preload("res://src/data/catalog.gd")
const Art = preload("res://src/ui/art_library.gd")
const K = preload("res://src/ui/ui_kit.gd")
const Trade = preload("res://src/trading/trade_rules.gd")
const MEETING_FONT_SIZE := 14

@export var compact := false
var tracked := -1:
	set(value):
		if tracked != value:
			tracked = value
			queue_redraw()

@onready var _viewport: SubViewport = $MapViewport
@onready var _backdrop: Node2D = $MapViewport/Backdrop


func _ready() -> void:
	_backdrop.area = "town"
	Game.changed.connect(queue_redraw)
	resized.connect(queue_redraw)
	visibility_changed.connect(queue_redraw)
	# The scenery is static: render it once, rather than drawing the town every HUD tick.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		queue_redraw()


func _draw() -> void:
	if Game.me().is_empty() or not is_instance_valid(_viewport):
		return
	var margin := Vector2.ZERO if compact else Vector2(100, 40)
	var scale_factor := minf((size.x - margin.x) / World.TOWN_SIZE.x, (size.y - margin.y) / World.TOWN_SIZE.y)
	if scale_factor <= 0.0:
		return
	var extent := World.TOWN_SIZE * scale_factor
	var origin := ((size - extent) * 0.5).round()
	draw_texture_rect(_viewport.get_texture(), Rect2(origin, extent), false)
	var occupied: Array[Rect2] = []
	if not compact:
		occupied = _draw_place_labels(origin, scale_factor)
	var p: Dictionary = Game.me()
	var pos: Vector2 = p.pos if p.area == "town" else World.DOOR_OUTSIDE
	var car := origin + Vector2(p.car_pos) * scale_factor
	var car_size := Vector2(10, 8) if compact else Vector2(20, 14)
	draw_texture_rect(Art.WORLD.car_top, Rect2(car - car_size * 0.5, car_size), false)
	var home := origin + World.DOOR_OUTSIDE * scale_factor
	if compact:
		draw_rect(Rect2(home - Vector2(2, 2), Vector2(4, 4)), K.CREAM)
	else:
		var font := K.map_font(true)
		var width := font.get_string_size("HOME", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var label := (home + Vector2(-width - 10, 22)).round()
		draw_string(font, label, "HOME", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, K.NAVY0)
		occupied.append(_label_rect(font, label, width))
		occupied.append(Rect2(origin + pos * scale_factor - Vector2(8, 20), Vector2(48, 32)))
	_draw_meetings(origin, scale_factor, occupied)
	var you := origin + pos * scale_factor
	draw_circle(you, 4.5 if compact else 8.0, K.NAVY0)
	draw_circle(you, 3.0 if compact else 6.0, K.LIME)
	if not compact:
		draw_string(K.map_font(true), (you + Vector2(9, -6)).round(), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, K.NAVY0)


func _wrap_meeting_text(text: String, font: Font, width: float) -> Array[String]:
	var lines: Array[String] = []
	var line := ""
	for word: String in text.split(" "):
		var next := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, MEETING_FONT_SIZE).x > width:
			lines.append(line)
			line = word
		else:
			line = next
	lines.append(line)
	return lines


func _meeting_box(at: Vector2, extent: Vector2, occupied: Array[Rect2]) -> Rect2:
	var preferred := at + Vector2(-extent.x * 0.5, 32)
	var candidates: Array[Vector2] = [preferred, at + Vector2(18, 32),
		at + Vector2(-extent.x - 18, 32), at - Vector2(extent.x * 0.5, extent.y + 18),
		at + Vector2(18, -extent.y * 0.5), at - Vector2(extent.x + 18, extent.y * 0.5),
		Vector2(4, preferred.y), Vector2(size.x - extent.x - 4, preferred.y)]
	var best := Rect2(preferred, extent)
	var best_score := INF
	for candidate: Vector2 in candidates:
		candidate.x = clampf(candidate.x, 4, maxf(4, size.x - extent.x - 4))
		candidate.y = clampf(candidate.y, 4, maxf(4, size.y - extent.y - 4))
		var rect := Rect2(candidate.round(), extent)
		var score := candidate.distance_to(preferred) * 0.02
		# Keep meeting details below their marker whenever the panel bounds allow it.
		score += maxf(0, at.y - rect.position.y) * 200
		if rect.has_point(at):
			score += rect.get_area() * 1000
		for other: Rect2 in occupied:
			score += rect.intersection(other).get_area()
		if score < best_score:
			best_score = score
			best = rect
	return best


func _draw_meetings(origin: Vector2, scale_factor: float, occupied: Array[Rect2]) -> void:
	var groups: Dictionary = {}
	for meeting: Dictionary in Game.active_meetings(Game.me()):
		var place := str(meeting.place)
		if not groups.has(place):
			groups[place] = []
		groups[place].append(meeting)
	var places: Array = groups.keys()
	places.sort()
	for place: String in places:
		var meetings: Array = groups[place]
		meetings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.start) < float(b.start) if float(a.start) != float(b.start) else int(a.listing_id) < int(b.listing_id))
		var at := origin + Vector2(meetings[0].pos) * scale_factor
		var selected := meetings.any(func(m: Dictionary) -> bool: return int(m.listing_id) == tracked)
		if not compact:
			var font := get_theme_font("font", "Label")
			var lines: Array[Dictionary] = []
			var text_width := minf(320, size.x - 24)
			# Use the map's empty side gutters when they can hold readable callouts.
			if origin.x >= 200:
				text_width = minf(text_width, origin.x - 28)
			var width := 0.0
			for meeting: Dictionary in meetings:
				if not lines.is_empty():
					lines.append({"text": "", "color": K.MUTED})
				var time := Trade.stamp(float(meeting.start)) + "-%02d:%02d" % [(int(meeting.end) % 1440) / 60, int(meeting.end) % 60]
				time += " | " + str(meeting.contact)
				if meeting.status == "missed":
					time += " (missed)"
				var color: Color = K.MUTED if meeting.status == "missed" else (K.LIME if int(meeting.listing_id) == tracked else K.SKY)
				for text: String in _wrap_meeting_text(time, font, text_width):
					lines.append({"text": text, "color": color})
				for text: String in _wrap_meeting_text(str(meeting.name), font, text_width):
					lines.append({"text": text, "color": K.CREAM})
			for line: Dictionary in lines:
				width = maxf(width, font.get_string_size(str(line.text), HORIZONTAL_ALIGNMENT_LEFT, -1, MEETING_FONT_SIZE).x)
			var line_height := maxf(18, font.get_height(MEETING_FONT_SIZE))
			var box := _meeting_box(at, Vector2(width + 16, lines.size() * line_height + 16), occupied)
			var edge := Vector2(clampf(at.x, box.position.x, box.end.x), clampf(at.y, box.position.y, box.end.y))
			draw_line(at, edge, K.ORANGE, 1)
			draw_rect(box, K.NAVY1)
			draw_rect(box, K.LIME if selected else K.ORANGE, false, 1)
			var baseline := box.position + Vector2(8, 8 + font.get_ascent(MEETING_FONT_SIZE))
			for line: Dictionary in lines:
				draw_string(font, baseline.round(), str(line.text), HORIZONTAL_ALIGNMENT_LEFT, -1, MEETING_FONT_SIZE, line.color)
				baseline.y += line_height
			occupied.append(box.grow(4))
		draw_arc(at, (6.0 if selected else 4.0) if compact else 12.0, 0, TAU, 20, K.ORANGE, 2)


func _label_rect(font: Font, baseline: Vector2, width: float) -> Rect2:
	return Rect2(baseline - Vector2(0, font.get_ascent(16)), Vector2(width, font.get_height(16))).grow(2)


func _choose_map_label(candidates: Array[Vector2], anchor: Vector2, font: Font, width: float, occupied: Array[Rect2], origin: Vector2, scale_factor: float) -> Vector2:
	var best := candidates[0]
	var best_overlap := INF
	for candidate: Vector2 in candidates:
		candidate.x = clampf(candidate.x, origin.x + 4, origin.x + World.TOWN_SIZE.x * scale_factor - width - 4)
		candidate.y = clampf(candidate.y, origin.y + font.get_ascent(16) + 4, origin.y + World.TOWN_SIZE.y * scale_factor - 4)
		candidate = candidate.round()
		var rect := _label_rect(font, candidate, width)
		var overlap := 0.0
		if rect.grow(4).has_point(anchor):
			overlap += 1000000
		for other: Rect2 in occupied:
			overlap += rect.intersection(other).get_area()
		if overlap < best_overlap:
			best_overlap = overlap
			best = candidate
	return best


func _draw_place_labels(origin: Vector2, scale_factor: float) -> Array[Rect2]:
	var font := K.map_font()
	var occupied: Array[Rect2] = []
	for y in World.ROAD_ROWS:
		occupied.append(Rect2(origin + Vector2(16, y) * scale_factor, Vector2(992, 32) * scale_factor))
	for x in World.ROAD_COLUMNS:
		occupied.append(Rect2(origin + Vector2(x, 16) * scale_factor, Vector2(32, 608) * scale_factor))
	for building: Rect2 in World.BUILDINGS:
		occupied.append(Rect2(origin + building.position * scale_factor, building.size * scale_factor))
	occupied.append(Rect2(origin + World.HOME_BUILDING.position * scale_factor, World.HOME_BUILDING.size * scale_factor))
	for activity: Resource in Activities.ALL:
		if activity.area == "town":
			var extent: Vector2 = activity.art_size * scale_factor
			occupied.append(Rect2(origin + activity.position * scale_factor - Vector2(extent.x * 0.5, extent.y), extent).grow(2))
	for place: String in Catalog.LOCATIONS:
		var at := origin + Vector2(Catalog.LOCATIONS[place]) * scale_factor
		draw_circle(at, 5, K.CREAM)
		draw_circle(at, 3, K.NAVY0)
		occupied.append(Rect2(at - Vector2(8, 8), Vector2(16, 16)))
		var width := font.get_string_size(place, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var candidates: Array[Vector2] = [at + Vector2(-width * 0.5, 24),
			at + Vector2(-width * 0.5, -14), at + Vector2(12, 0), at - Vector2(width + 12, 0)]
		var label := _choose_map_label(candidates, at, font, width, occupied, origin, scale_factor)
		draw_string(font, label, place, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, K.NAVY0)
		occupied.append(_label_rect(font, label, width))
	for activity: Resource in Activities.ALL:
		if activity.area != "town":
			continue
		var at: Vector2 = origin + activity.position * scale_factor
		draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), K.ORANGE)
		var width := font.get_string_size(activity.map_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var art_size: Vector2 = activity.art_size * scale_factor
		var candidates: Array[Vector2] = [at + Vector2(-width * 0.5, -art_size.y - 4),
			at + Vector2(-width * 0.5, 20), at + Vector2(art_size.x * 0.5 + 8, 0),
			at - Vector2(art_size.x * 0.5 + width + 8, 0)]
		var label := _choose_map_label(candidates, at, font, width, occupied, origin, scale_factor)
		draw_string(font, label, activity.map_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, K.NAVY0)
		occupied.append(_label_rect(font, label, width))
	return occupied
