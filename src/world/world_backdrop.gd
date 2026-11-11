extends Node2D
## Static world art. Redraws on area changes, independently of moving actors.
const Activities = preload("res://src/world/activities.gd")
const Art = preload("res://src/ui/art_library.gd")
const World = preload("res://src/world/world_rules.gd")
const Props = preload("res://src/world/world_props.gd")
const K = preload("res://src/ui/ui_kit.gd")
@export var show_labels := true
var show_props := true:
	set(value):
		if show_props != value:
			show_props = value
			queue_redraw()
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
	_draw_activity_markers()
	if area == "home" and show_props:
		for prop: Dictionary in World.room_props(has_rig):
			Props.draw_prop(self, prop, show_labels)


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
	# Furniture is shared with the live depth-sorted prop pass.
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
	# Asphalt sits below the street; only the driveway touches its southern edge.
	var asphalt := Color("252a30")
	var paint := Color("e7eaec")
	draw_rect(World.PARKING_RECT, asphalt)
	draw_rect(Rect2(452, 528, 32, 20), asphalt)
	draw_line(Vector2(400, 540), Vector2(452, 540), Color("6f7479"))
	draw_line(Vector2(484, 540), Vector2(535, 540), Color("6f7479"))
	for x in [408, 448, 488, 528]:
		draw_line(Vector2(x, 585), Vector2(x, 609), paint)
	draw_line(Vector2(408, 609), Vector2(528, 609), paint)
	draw_line(Vector2(468, 568), Vector2(468, 548), paint, 2)
	draw_line(Vector2(468, 548), Vector2(462, 555), paint, 2)
	draw_line(Vector2(468, 548), Vector2(474, 555), paint, 2)
	_centered_label(Vector2(468, 580), "PARKING", paint)
	_tiles("floor_tile_beige", Rect2(472, 306, 48, 30))
	if show_props:
		for prop: Dictionary in World.town_props():
			Props.draw_prop(self, prop, show_labels)
	for x in range(8, 1024, 16):
		draw_rect(Rect2(x, 12, 3, 12), Color("7c7468"))
		draw_rect(Rect2(x, 620, 3, 12), Color("7c7468"))
	draw_line(Vector2(8, 16), Vector2(1016, 16), Color("b5a385"), 2)
	draw_line(Vector2(8, 624), Vector2(1016, 624), Color("b5a385"), 2)


func _draw_activity_markers() -> void:
	for activity: Resource in Activities.ALL:
		if activity.area != area:
			continue
		var at: Vector2 = activity.position
		draw_arc(at, 15, 0, TAU, 16, Color("f4d68f"), 1)
