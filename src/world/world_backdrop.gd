extends Node2D
## Static world art. Redraws on area changes, independently of moving actors.
const Activities = preload("res://src/world/activities.gd")
const Art = preload("res://src/ui/art_library.gd")
const World = preload("res://src/world/world_rules.gd")
const Catalog = preload("res://src/data/catalog.gd")
const K = preload("res://src/ui/ui_kit.gd")
@export var show_labels := true
var has_rig := false:
	set(value):
		if has_rig != value:
			has_rig = value
			queue_redraw()
var area := "home":
	set(value):
		if area != value:
			area = value
			queue_redraw()


func _draw() -> void:
	if area == "home":
		_house()
	else:
		_town()
	_draw_activities()


func _art(key: String, rect: Rect2) -> void:
	draw_texture_rect(Art.WORLD[key], rect, false)


func _tiles(key: String, rect: Rect2) -> void:
	# All floor patches share the same tile origin. Clip edge tiles rather than restarting their UVs.
	for y in range(floori(rect.position.y / 32) * 32, ceili(rect.end.y), 32):
		for x in range(floori(rect.position.x / 32) * 32, ceili(rect.end.x), 32):
			var tile := Rect2(Vector2(x, y), Vector2(32, 32))
			var visible := tile.intersection(rect)
			if visible.has_area():
				draw_texture_rect_region(Art.WORLD[key], visible, Rect2(visible.position - tile.position, visible.size))


func _label(at: Vector2, text: String, color: Color = Color("30474e")) -> void:
	if not show_labels:
		return
	draw_string(K.world_font(), at.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)


func _centered_label(at: Vector2, text: String, color: Color = Color("30474e")) -> void:
	var width := K.world_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	_label(at - Vector2(width * 0.5, 0), text, color)


func _house() -> void:
	draw_rect(Rect2(Vector2.ZERO, World.ROOM_SIZE), Color("374650"))
	_tiles("floor_wood_light", Rect2(18, 22, 348, 218))
	_tiles("floor_tile_gray", Rect2(24, 33, 128, 63))
	_tiles("floor_wood_dark", Rect2(256, 33, 104, 143))
	draw_rect(Rect2(18, 16, 348, 17), Color("73838b"))
	draw_rect(Rect2(18, 33, 6, 207), Color("9b8b75"))
	draw_rect(Rect2(360, 33, 6, 207), Color("9b8b75"))
	draw_rect(Rect2(18, 237, 348, 8), Color("705d61"))
	draw_rect(Rect2(177, 237, 32, 9), Color("d2aa72"))
	_art("rug_a", Rect2(164, 146, 80, 64))
	_art("rug_b", Rect2(46, 187, 60, 48))
	_art("window", Rect2(174, 10, 38, 38))
	_art("window", Rect2(219, 10, 38, 38))
	_art("bench_metal" if has_rig else "bench_wood", World.BENCH_RECT)
	_art("desk_metal" if has_rig else "desk_wood", Rect2(46, 124, 64, 48))
	_art("bookshelf", Rect2(264, 20, 44, 55))
	_art("bookshelf", Rect2(305, 20, 44, 55))
	_art("bed", Rect2(278, 92, 58, 78))
	_art("box", Rect2(135, 86, 42, 36))
	_art("statue_lucky_gpu", Rect2(316, 172, 30, 42))
	_label(Vector2(49, 30), "PC WORKBENCH", Color("fff0c2"))
	_label(Vector2(160, 230), "E : OUTSIDE")
	_label(Vector2(263, 222), "LUCKY'S CORNER")


func _road(at: Vector2, horizontal: bool) -> void:
	if horizontal:
		draw_set_transform(at + Vector2(16, 16), PI / 2)
		draw_texture(Art.WORLD.road_straight, Vector2(-16, -16))
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture(Art.WORLD.road_straight, at)


func _town() -> void:
	for y in range(0, 640, 32):
		for x in range(0, 1024, 32):
			var variant := posmod(x * 17 + y * 11, 7)
			_art("grass_%02d" % mini(variant, 5), Rect2(x, y, 32, 32))
	for y in World.ROAD_ROWS:
		for x in range(16, 1008, 32):
			_road(Vector2(x, y), true)
	for x in World.ROAD_COLUMNS:
		for y in range(16, 624, 32):
			_road(Vector2(x, y), false)
	for x in World.ROAD_COLUMNS:
		for y in World.ROAD_ROWS:
			_art("road_cross", Rect2(x, y, 32, 32))
	draw_rect(Rect2(400, 510, 135, 115), Color("607f91"))
	draw_rect(Rect2(406, 516, 123, 103), Color("74a4b0"))
	for y in range(524, 616, 12):
		for x in range(412, 527, 25):
			draw_line(Vector2(x, y), Vector2(x + 12, y), Color("abd0c9"))
	var buildings := ["house_garage", "house_red_dormer", "house_garage", "house_green", "house_purple_porch", "shop", "house_blue"]
	for i in World.BUILDINGS.size():
		_building(World.BUILDINGS[i], buildings[i])
	_building(World.HOME_BUILDING, "house_blue")
	_centered_label(Vector2(World.HOME_BUILDING.get_center().x, 254), "YOUR HOME")
	_tiles("floor_tile_beige", Rect2(472, 306, 48, 30))
	for i in 60:
		var at := Vector2(25 + (i * 97) % 974, 36 + (i * 173) % 570)
		if not World.clear_at("town", at, 28) or _on_road(at):
			continue
		var blocked := false
		for meeting: Vector2 in Catalog.LOCATIONS.values():
			if at.distance_to(meeting) < 52:
				blocked = true
		for activity: Resource in Activities.ALL:
			if at.distance_to(activity.position) < 48:
				blocked = true
		if blocked or absi(int(at.x) - 500) < 70:
			continue
		var key: String = ("tree_" if i % 2 == 0 else "bush_") + ["a", "b", "c"][i % 3]
		var extent := Vector2(32, 40) if i % 2 == 0 else Vector2(32, 20)
		_art(key, Rect2(at - Vector2(extent.x / 2, extent.y), extent))
	for place: String in Catalog.LOCATIONS:
		var at: Vector2 = Catalog.LOCATIONS[place]
		var text := place.replace(" Market", "").replace(" Storage", "").replace(" Cul-de-sac", "").replace(" Garage", "")
		var width := K.world_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 8
		# The board sits above visitors' heads; its full footprint stays off the pavement.
		draw_rect(Rect2(at + Vector2(-2, -38), Vector2(4, 42)), Color("75676a"))
		draw_rect(Rect2(at + Vector2(-width * 0.5, -50), Vector2(width, 12)), Color("f0dfac"))
		_centered_label(at + Vector2(0, -41), text)
	for x in range(8, 1024, 16):
		draw_rect(Rect2(x, 12, 3, 12), Color("7c7468"))
		draw_rect(Rect2(x, 620, 3, 12), Color("7c7468"))
	draw_line(Vector2(8, 16), Vector2(1016, 16), Color("b5a385"), 2)
	draw_line(Vector2(8, 624), Vector2(1016, 624), Color("b5a385"), 2)


func _building(footprint: Rect2, key: String) -> void:
	# Assets include a transparent margin. Align their visible base with the collision footprint.
	var extent := Vector2(footprint.size.x * 1.18, footprint.size.y * 1.35)
	_art(key, Rect2(Vector2(footprint.get_center().x - extent.x / 2, footprint.end.y - extent.y + 8), extent))


func _on_road(at: Vector2) -> bool:
	for y in World.ROAD_ROWS:
		if at.y > y - 18 and at.y < y + 50:
			return true
	for x in World.ROAD_COLUMNS:
		if at.x > x - 18 and at.x < x + 50:
			return true
	return false


func _draw_activities() -> void:
	for activity: Resource in Activities.ALL:
		if activity.area != area:
			continue
		var at: Vector2 = activity.position
		var extent: Vector2 = activity.art_size
		draw_arc(at, 15, 0, TAU, 16, Color("f4d68f"), 1)
		_art(activity.art_key, Rect2(at - Vector2(extent.x / 2, extent.y - 4), extent))
		if activity.overlay_art_key != "":
			var overlay: Vector2 = activity.overlay_art_size
			_art(activity.overlay_art_key, Rect2(at - Vector2(overlay.x / 2, overlay.y - 4), overlay))
		_centered_label(at + Vector2(0, 16), activity.map_label)
