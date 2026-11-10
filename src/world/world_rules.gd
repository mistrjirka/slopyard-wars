extends RefCounted
## Shared map geometry. The host applies directional input against these same solid shapes that are drawn.
const TOWN_SIZE := Vector2(1024, 640)
const ROOM_SIZE := Vector2(384, 256)
const SPAWN := Vector2(192, 180)
const DOOR_INSIDE := Vector2(192, 229)
const DOOR_OUTSIDE := Vector2(496, 316)
const CAR_START := Vector2(540, 348)
const BENCH := Vector2(87, 65)
const BENCH_RECT := Rect2(67, 38, 40, 29)
const BENCH_FOOTPRINT := Rect2(67, 50, 40, 17)
const CHAIR := Vector2(289, 175)
const HOME_BUILDING := Rect2(432, 198, 128, 108)
const BUILDINGS := [Rect2(40, 42, 88, 62), Rect2(208, 50, 104, 72), Rect2(708, 32, 112, 72), Rect2(884, 374, 112, 72), Rect2(640, 410, 96, 72), Rect2(28, 400, 104, 72), Rect2(882, 176, 112, 64)]
const ROOM_SOLIDS := [BENCH_FOOTPRINT, Rect2(264, 35, 80, 40), Rect2(277, 105, 60, 54), Rect2(48, 130, 58, 43), Rect2(133, 88, 44, 34)]
const ROAD_ROWS := [128, 336, 496]
const ROAD_COLUMNS := [144, 328, 592, 840]
const WALK_SPEED := 78.0
const CAR_SPEED := 190.0


static func solids(area: String) -> Array:
	if area == "home":
		return ROOM_SOLIDS
	var out: Array = BUILDINGS.duplicate()
	out.append(HOME_BUILDING)
	out.append(Rect2(400, 510, 135, 115))
	return out


static func clear_at(area: String, at: Vector2, radius: float) -> bool:
	var extent := ROOM_SIZE if area == "home" else TOWN_SIZE
	if at.x < 20 + radius or at.y < 24 + radius or at.x > extent.x - 20 - radius or at.y > extent.y - 12 - radius:
		return false
	for r: Rect2 in solids(area):
		if r.grow(radius).has_point(at):
			return false
	return true


static func move(area: String, from: Vector2, offset: Vector2, driving: bool) -> Vector2:
	var result := from
	var radius := 11.0 if driving else 5.0
	# Small substeps prevent driving through thin walls on a delayed frame.
	var steps := maxi(1, ceili(offset.length() / 3.0))
	var step := offset / steps
	for i in steps:
		var x := result + Vector2(step.x, 0)
		if clear_at(area, x, radius):
			result = x
		var y := result + Vector2(0, step.y)
		if clear_at(area, y, radius):
			result = y
	return result
