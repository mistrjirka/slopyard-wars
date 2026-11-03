extends Control
## Read-only overview of the same geometry used by the walkable world; no travel shortcut.
const World = preload("res://scripts/world_rules.gd")
const Catalog = preload("res://scripts/catalog.gd")
const K = preload("res://scripts/ui_kit.gd")
func _init() -> void:
	custom_minimum_size = Vector2(480, 400)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
	if is_visible_in_tree(): queue_redraw()
func _draw() -> void:
	if Game.me().is_empty(): return
	var scale_factor: float = minf((size.x - 100) / World.TOWN_SIZE.x, (size.y - 40) / World.TOWN_SIZE.y)
	var origin := (size - World.TOWN_SIZE * scale_factor) * 0.5
	draw_rect(Rect2(origin, World.TOWN_SIZE * scale_factor), Color("92ae77"))
	for y in [128, 336, 496]: draw_rect(Rect2(origin + Vector2(20, y) * scale_factor, Vector2(984, 32) * scale_factor), Color("7d8990"))
	for x in [144, 328, 592, 840]: draw_rect(Rect2(origin + Vector2(x, 24) * scale_factor, Vector2(32, 600) * scale_factor), Color("7d8990"))
	for r: Rect2 in World.BUILDINGS: draw_rect(Rect2(origin + r.position * scale_factor, r.size * scale_factor), Color("896b68"))
	draw_rect(Rect2(origin + World.HOME_BUILDING.position * scale_factor, World.HOME_BUILDING.size * scale_factor), Color("607e90"))
	draw_rect(Rect2(origin + Vector2(400, 510) * scale_factor, Vector2(135, 115) * scale_factor), Color("6999a7"))
	for name: String in Catalog.LOCATIONS:
		var at: Vector2 = origin + Catalog.LOCATIONS[name] * scale_factor
		draw_circle(at, 5, K.CREAM)
		draw_circle(at, 3, K.NAVY0)
		var label_pos := at + Vector2(-22, 20)
		if name == "Lakeside Storage": label_pos.x -= 40
		draw_string(K.mono(), label_pos, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, K.NAVY0)
	var p: Dictionary = Game.me()
	var pos: Vector2 = p.pos if p.area == "town" else World.DOOR_OUTSIDE
	var you := origin + pos * scale_factor
	draw_circle(you, 7, K.LIME)
	draw_string(K.mono_bold(), you + Vector2(9, -6), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, K.NAVY0)
	var car: Vector2 = origin + Vector2(p.car_pos) * scale_factor
	draw_rect(Rect2(car - Vector2(5, 3), Vector2(10, 6)), K.SKY)
	for m: Dictionary in Game.active_meetings(p):
		var at: Vector2 = origin + Vector2(m.pos) * scale_factor
		draw_arc(at, 12, 0, TAU, 20, K.ORANGE, 2)
	draw_string(K.mono_bold(), origin + World.DOOR_OUTSIDE * scale_factor + Vector2(-24, 22), "HOME", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, K.NAVY0)
