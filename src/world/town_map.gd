extends Control
## Read-only overview of the same geometry used by the walkable world; no travel shortcut.
const Activities = preload("res://src/world/activities.gd")
const World = preload("res://src/world/world_rules.gd")
const Catalog = preload("res://src/data/catalog.gd")
const K = preload("res://src/ui/ui_kit.gd")


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if Game.me().is_empty():
		return
	var scale_factor: float = minf((size.x - 100) / World.TOWN_SIZE.x, (size.y - 40) / World.TOWN_SIZE.y)
	var origin := (size - World.TOWN_SIZE * scale_factor) * 0.5
	draw_rect(Rect2(origin, World.TOWN_SIZE * scale_factor), Color("92ae77"))
	for y in World.ROAD_ROWS:
		draw_rect(Rect2(origin + Vector2(20, y) * scale_factor, Vector2(984, 32) * scale_factor), Color("7d8990"))
	for x in World.ROAD_COLUMNS:
		draw_rect(Rect2(origin + Vector2(x, 24) * scale_factor, Vector2(32, 600) * scale_factor), Color("7d8990"))
	for r: Rect2 in World.BUILDINGS:
		draw_rect(Rect2(origin + r.position * scale_factor, r.size * scale_factor), Color("896b68"))
	draw_rect(Rect2(origin + World.HOME_BUILDING.position * scale_factor, World.HOME_BUILDING.size * scale_factor), Color("607e90"))
	draw_rect(Rect2(origin + Vector2(400, 510) * scale_factor, Vector2(135, 115) * scale_factor), Color("6999a7"))
	for name: String in Catalog.LOCATIONS:
		var at: Vector2 = origin + Catalog.LOCATIONS[name] * scale_factor
		draw_circle(at, 5, K.CREAM)
		draw_circle(at, 3, K.NAVY0)
		var font := K.map_font()
		var label_width := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var label_pos := at + Vector2(-label_width * 0.5, 20)
		label_pos.x = clampf(label_pos.x, origin.x + 4, origin.x + World.TOWN_SIZE.x * scale_factor - label_width - 4)
		draw_string(font, label_pos.round(), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, K.NAVY0)
	for activity: Resource in Activities.ALL:
		if activity.area != "town":
			continue
		var at: Vector2 = origin + activity.position * scale_factor
		draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), K.ORANGE)
		var font := K.map_font()
		var label_width := font.get_string_size(activity.map_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font, (at + Vector2(-label_width * 0.5, 16)).round(), activity.map_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, K.NAVY0)
	var p: Dictionary = Game.me()
	var pos: Vector2 = p.pos if p.area == "town" else World.DOOR_OUTSIDE
	var you := origin + pos * scale_factor
	draw_circle(you, 7, K.LIME)
	draw_string(K.map_font(true), (you + Vector2(9, -6)).round(), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, K.NAVY0)
	var car: Vector2 = origin + Vector2(p.car_pos) * scale_factor
	draw_texture_rect(preload("res://src/ui/art_library.gd").WORLD.car_top, Rect2(car - Vector2(10, 7), Vector2(20, 14)), false)
	for m: Dictionary in Game.active_meetings(p):
		var at: Vector2 = origin + Vector2(m.pos) * scale_factor
		draw_arc(at, 12, 0, TAU, 20, K.ORANGE, 2)
	var home_font := K.map_font(true)
	var home_width := home_font.get_string_size("HOME", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var home_label := origin + World.DOOR_OUTSIDE * scale_factor + Vector2(-home_width - 10, 22)
	draw_string(home_font, home_label.round(), "HOME", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, K.NAVY0)
