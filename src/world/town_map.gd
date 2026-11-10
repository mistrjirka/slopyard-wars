extends Control
## Asset-backed overview and compact HUD map; both share the walkable world's backdrop.
const Activities = preload("res://src/world/activities.gd")
const World = preload("res://src/world/world_rules.gd")
const Catalog = preload("res://src/data/catalog.gd")
const Art = preload("res://src/ui/art_library.gd")
const K = preload("res://src/ui/ui_kit.gd")

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
	if not compact:
		_draw_place_labels(origin, scale_factor)
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
		draw_string(font, (home + Vector2(-width - 10, 22)).round(), "HOME", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, K.NAVY0)
	for meeting: Dictionary in Game.active_meetings(p):
		var at := origin + Vector2(meeting.pos) * scale_factor
		var selected := int(meeting.listing_id) == tracked
		draw_arc(at, (6.0 if selected else 4.0) if compact else 12.0, 0, TAU, 20, K.ORANGE, 2)
	var you := origin + pos * scale_factor
	draw_circle(you, 4.5 if compact else 8.0, K.NAVY0)
	draw_circle(you, 3.0 if compact else 6.0, K.LIME)
	if not compact:
		draw_string(K.map_font(true), (you + Vector2(9, -6)).round(), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, K.NAVY0)


func _label_rect(font: Font, baseline: Vector2, width: float) -> Rect2:
	return Rect2(baseline - Vector2(0, font.get_ascent(16)), Vector2(width, font.get_height(16))).grow(2)


func _draw_place_labels(origin: Vector2, scale_factor: float) -> void:
	var font := K.map_font()
	var occupied: Array[Rect2] = []
	for y in World.ROAD_ROWS:
		occupied.append(Rect2(origin + Vector2(16, y) * scale_factor, Vector2(992, 32) * scale_factor))
	for x in World.ROAD_COLUMNS:
		occupied.append(Rect2(origin + Vector2(x, 16) * scale_factor, Vector2(32, 608) * scale_factor))
	for place: String in Catalog.LOCATIONS:
		var at := origin + Vector2(Catalog.LOCATIONS[place]) * scale_factor
		draw_circle(at, 5, K.CREAM)
		draw_circle(at, 3, K.NAVY0)
		var width := font.get_string_size(place, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var label := at + Vector2(-width * 0.5, 20)
		label.x = clampf(label.x, origin.x + 4, origin.x + World.TOWN_SIZE.x * scale_factor - width - 4)
		label = label.round()
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
		var label := candidates[0]
		var best_overlap := INF
		# Service names share busy blocks with meeting signs. Prefer positions clear of text and roads.
		for candidate: Vector2 in candidates:
			candidate.x = clampf(candidate.x, origin.x + 4, origin.x + World.TOWN_SIZE.x * scale_factor - width - 4)
			candidate = candidate.round()
			var rect := _label_rect(font, candidate, width)
			var overlap := 0.0
			for other: Rect2 in occupied:
				overlap += rect.intersection(other).get_area()
			if overlap < best_overlap:
				best_overlap = overlap
				label = candidate
		draw_string(font, label, activity.map_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, K.NAVY0)
		occupied.append(_label_rect(font, label, width))
