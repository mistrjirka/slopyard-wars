extends RefCounted
## Shared map geometry. The host applies directional input against these same solid shapes that are drawn.
const TOWN_SIZE := Vector2(1024, 640)
const ROOM_SIZE := Vector2(384, 256)
const SPAWN := Vector2(192, 180)
const DOOR_INSIDE := Vector2(192, 229)
const DOOR_OUTSIDE := Vector2(496, 316)
const CAR_START := Vector2(540, 348)
const PARKING_RECT := Rect2(400, 540, 135, 74)
const BENCH := Vector2(87, 65)
const BENCH_RECT := Rect2(67, 38, 40, 29)
const BENCH_FOOTPRINT := Rect2(68, 56, 38, 9)
const CHAIR := Vector2(289, 175)
const BED_RECT := Rect2(278, 92, 58, 78)
const BED_FOOTPRINT := Rect2(287, 151, 40, 16)
const BED := Vector2(307, 167)
const BED_REACH := 40.0
const HOME_BUILDING := Rect2(432, 198, 128, 108)
const BUILDINGS := [Rect2(40, 42, 88, 62), Rect2(208, 50, 104, 72), Rect2(708, 32, 112, 72), Rect2(884, 374, 112, 72), Rect2(640, 410, 96, 72), Rect2(28, 400, 104, 72), Rect2(882, 176, 112, 64)]
const BUILDING_KEYS := ["house_garage", "house_red_dormer", "house_garage", "house_green", "house_purple_porch", "shop", "house_blue"]
const ROAD_ROWS := [128, 336, 496]
const ROAD_COLUMNS := [144, 328, 592, 840]
const WALK_SPEED := 78.0
const CAR_SPEED := 190.0
const Activities = preload("res://src/world/activities.gd")
const Catalog = preload("res://src/data/catalog.gd")
static var _town_props: Array[Dictionary] = []


static func solids(area: String) -> Array:
	var out: Array = []
	var props := room_props() if area == "home" else town_props()
	for prop: Dictionary in props:
		if prop.has("solid"):
			out.append(prop.solid)
	return out


## Layout rectangles stay unchanged; only the visible foundation is solid.
static func building_prop(layout: Rect2, key: String) -> Dictionary:
	var extent := Vector2(layout.size.x * 1.18, layout.size.y * 1.35)
	var rect := Rect2(Vector2(layout.get_center().x - extent.x / 2, layout.end.y - extent.y + 8), extent)
	# All house sources are 112x104; foundation pixels span x=10..102, y ends at 101.
	var base := rect.position + extent * Vector2(10.0 / 112, 101.0 / 104)
	var solid := Rect2(base - Vector2(0, 18), Vector2(extent.x * 92.0 / 112, 18))
	return {"kind": "building", "pos": Vector2(rect.get_center().x, base.y), "rect": rect, "key": key, "solid": solid}


static func activity_props(area: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for activity: Resource in Activities.ALL:
		if activity.area != area:
			continue
		var extent: Vector2 = activity.art_size
		var at: Vector2 = activity.position
		# Source-space base strips, excluding PNG margins and elevated art.
		var bases := {"lucky_shrine": Rect2(8, 108, 114, 20), "salvage_bin": Rect2(22, 108, 88, 18),
			"dust_clinic": Rect2(24, 108, 100, 18), "paste_club": Rect2(16, 104, 96, 18),
			"advice_board": Rect2(22, 110, 92, 14)}
		var source: Rect2 = bases.get(activity.art_key, Rect2(24, 108, 80, 18))
		var rect := Rect2(at - Vector2(extent.x / 2, extent.y - 4), extent)
		var solid := Rect2(rect.position + source.position * extent / 128.0, source.size * extent / 128.0)
		out.append({"kind": "activity", "pos": Vector2(at.x, solid.end.y), "rect": rect,
			"key": activity.art_key, "solid": solid, "activity": activity})
	return out


## Only existing room furniture is solid; rugs, windows and floor tiles remain decoration.
static func room_props(has_rig: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var furniture := [
		["bench_metal" if has_rig else "bench_wood", BENCH_RECT, BENCH_FOOTPRINT],
		["desk_metal" if has_rig else "desk_wood", Rect2(46, 124, 64, 48), Rect2(50, 156, 56, 12)],
		["bookshelf", Rect2(264, 20, 44, 55), Rect2(269, 64, 34, 9)],
		["bookshelf", Rect2(305, 20, 44, 55), Rect2(310, 64, 34, 9)],
		["bed", BED_RECT, BED_FOOTPRINT],
		["statue_lucky_gpu", Rect2(316, 172, 30, 42), Rect2(321, 207, 21, 7)]]
	for item: Array in furniture:
		var solid: Rect2 = item[2]
		out.append({"kind": "furniture", "key": item[0], "rect": item[1], "solid": solid,
			"pos": Vector2(solid.get_center().x, solid.end.y)})
	out.append_array(activity_props("home"))
	return out


static func near_bed(area: String, at: Vector2) -> bool:
	return area == "home" and at.distance_to(BED) <= BED_REACH


## Shared deterministic scenery: pos is the ground/depth anchor, never the canopy center.
## Placement only reads base geometry; it must not call clear_at()/solids().
static func town_props() -> Array[Dictionary]:
	if not _town_props.is_empty():
		return _town_props
	for i in BUILDINGS.size():
		_town_props.append(building_prop(BUILDINGS[i], BUILDING_KEYS[i]))
	_town_props.append(building_prop(HOME_BUILDING, "house_blue"))
	_town_props.append_array(activity_props("town"))
	for place: String in Catalog.LOCATIONS:
		var at: Vector2 = Catalog.LOCATIONS[place]
		var text := place.replace(" Market", "").replace(" Storage", "").replace(" Cul-de-sac", "").replace(" Garage", "")
		_town_props.append({"kind": "sign", "pos": at + Vector2(0, 4), "text": text,
			"solid": Rect2(at + Vector2(-2, 0), Vector2(4, 4))})
	for i in 96:
		# Staggered fixed grid avoids the old arithmetic sequence's overlapping tree rows.
		var row := i / 12
		var at := Vector2(52 + (i % 12) * 82 + (row % 2) * 12, 96 + row * 68)
		if not _scenery_clear(at) or absi(int(at.x) - 500) < 70:
			continue
		var tree := (i + row) % 3 != 1
		var extent := Vector2(64, 80) if tree else Vector2(32, 20)
		var rect := Rect2(at - Vector2(extent.x / 2, extent.y), extent)
		var blocked := false
		for building: Dictionary in _town_props:
			if building.kind == "building" and rect.intersects(building.rect.grow(4)):
				blocked = true
		for meeting: Vector2 in Catalog.LOCATIONS.values():
			# Keep the whole enlarged crown away from sign boards and visiting space.
			if at.distance_to(meeting) < 52 or rect.intersects(Rect2(meeting - Vector2(50, 58), Vector2(100, 76))):
				blocked = true
		for activity: Resource in Activities.ALL:
			if activity.area == "town" and (at.distance_to(activity.position) < 48 or rect.intersects(Rect2(activity.position - Vector2(32, 48), Vector2(64, 64)))):
				blocked = true
		if blocked:
			continue
		var prop := {"kind": "tree" if tree else "bush", "pos": at, "rect": rect,
			"key": ("tree_" if tree else "bush_") + ["a", "b", "c"][i % 3]}
		# Visible tree trunk ends six pixels above the PNG bottom; bushes end two above.
		prop["pos"] = at - Vector2(0, 6 if tree else 2)
		prop["solid"] = Rect2(at - Vector2(6, 13), Vector2(12, 7)) if tree else Rect2(at - Vector2(11, 6), Vector2(22, 4))
		_town_props.append(prop)
	_town_props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.y < b.pos.y)
	return _town_props


static func _scenery_clear(at: Vector2) -> bool:
	if at.x < 48 or at.y < 52 or at.x > TOWN_SIZE.x - 48 or at.y > TOWN_SIZE.y - 40:
		return false
	# Reserve visual building plots and parking for placement only, not collision.
	for rect: Rect2 in BUILDINGS + [HOME_BUILDING, PARKING_RECT]:
		if rect.grow(28).has_point(at):
			return false
	for y in ROAD_ROWS:
		if at.y > y - 18 and at.y < y + 50:
			return false
	for x in ROAD_COLUMNS:
		if at.x > x - 18 and at.x < x + 50:
			return false
	return true


## Opaque artwork bounds inside the centered 40x32 draw rect (80x64 source).
## Used for visual coverage, never as the car's ground collision shape.
static func car_visual_bounds(at: Vector2, facing: Vector2 = Vector2.LEFT) -> Rect2:
	if absf(facing.y) > absf(facing.x):
		return Rect2(at + Vector2(-11, -11), Vector2(22, 23))
	return Rect2(at + Vector2(-17.5 if facing.x > 0 else -17, -7), Vector2(34.5, 19.5))


## Only the lower wheel/base strip is solid, like the foundations of town props.
## Parked cars face LEFT; driving, turning and pedestrians share this footprint.
static func car_footprint(at: Vector2, facing: Vector2 = Vector2.LEFT) -> Rect2:
	var artwork := car_visual_bounds(at, facing)
	return Rect2(Vector2(artwork.position.x, artwork.end.y - 6.0), Vector2(artwork.size.x, 6.0))


static func clear_at(area: String, at: Vector2, radius: float, obstacles: Array = [], body: Rect2 = Rect2()) -> bool:
	var extent := ROOM_SIZE if area == "home" else TOWN_SIZE
	var bounds := Rect2(Vector2(20, 24), extent - Vector2(40, 36))
	var shape := body if body.has_area() else Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2)
	if not bounds.encloses(shape):
		return false
	for r: Rect2 in solids(area):
		if r.intersects(shape):
			return false
	for r: Rect2 in obstacles:
		if r.intersects(shape):
			return false
	return true


static func move(area: String, from: Vector2, offset: Vector2, driving: bool, obstacles: Array = [], facing: Vector2 = Vector2.LEFT) -> Vector2:
	var result := from
	# Small substeps prevent driving through thin walls on a delayed frame.
	var steps := maxi(1, ceili(offset.length() / 3.0))
	var step := offset / steps
	for i in steps:
		var x := result + Vector2(step.x, 0)
		if clear_at(area, x, 5, obstacles, car_footprint(x, facing) if driving else Rect2()):
			result = x
		var y := result + Vector2(0, step.y)
		if clear_at(area, y, 5, obstacles, car_footprint(y, facing) if driving else Rect2()):
			result = y
	return result
