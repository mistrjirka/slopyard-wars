extends RefCounted
## Host simulation of directional input, collisions, interactions and solo waiting.

const World = preload("res://src/world/world_rules.gd")
const Trade = preload("res://src/trading/trade_rules.gd")

var session: Node
var state: Dictionary:
	get:
		return session.state

var motion: Dictionary = {}
var motion_age: Dictionary = {}
var spatial_tick := 0.0


func _init(game_session: Node) -> void:
	session = game_session


func tick(delta: float) -> void:
	if not session.is_host() or state.get("phase") != "playing":
		return
	var ids: Array = state.players.keys()
	ids.sort()
	for pid in ids:
		var p: Dictionary = state.players[pid]
		motion_age[pid] = float(motion_age.get(pid, 0.0)) + delta
		var direction: Vector2 = motion.get(pid, Vector2.ZERO) if float(motion_age[pid]) < 0.4 else Vector2.ZERO
		if p.ready:
			direction = Vector2.ZERO
		if direction.length_squared() > 0.01:
			var obstacles := _obstacles(int(pid), p.driving) if p.area == "town" else []
			var facing := direction.normalized()
			# Turning changes the artwork footprint; never rotate into a solid.
			if p.driving and not World.clear_at("town", p.pos, 0, obstacles, World.car_footprint(p.pos, facing)):
				continue
			p.facing = facing
			p.pos = World.move(p.area, p.pos, direction.limit_length() * (World.CAR_SPEED if p.driving else World.WALK_SPEED) * delta, p.driving, obstacles, facing)
			if p.driving:
				p.car_pos = p.pos
	spatial_tick += delta
	if spatial_tick >= 0.08:
		spatial_tick = 0.0
		session.mark_changed()


## Cars live in town even while their owner is indoors. Only a driver's own
## vehicle is excluded; walkers also collide with their own parked vehicle.
func _obstacles(pid: int, driving: bool = false) -> Array:
	var out: Array = []
	for other_id in state.players:
		var other: Dictionary = state.players[other_id]
		if not driving or int(other_id) != pid:
			out.append(World.car_footprint(other.car_pos, other.facing if other.driving else Vector2.LEFT))
		# Do not let a moving car embed a pedestrian in its footprint.
		if driving and int(other_id) != pid and other.area == "town" and not other.driving:
			out.append(Rect2(other.pos - Vector2(5, 5), Vector2(10, 10)))
	return out


func interact(pid: int, p: Dictionary) -> void:
	if p.area == "home":
		if p.pos.distance_to(World.DOOR_INSIDE) < 27:
			var obstacles := _obstacles(pid)
			for offset: Vector2 in [Vector2.ZERO, Vector2(0, 26), Vector2(26, 0), Vector2(-26, 0)]:
				var exit := World.DOOR_OUTSIDE + offset
				if World.clear_at("town", exit, 5, obstacles):
					p.area = "town"
					p.pos = exit
					return
			session.notify_player(pid, "The doorway is blocked by cars. Wait for a clear exit.")
		elif p.pos.distance_to(World.BENCH) < 50:
			session.notify_player(pid, "Workbench ready. Open the workbench with B; T opens tuning.")
		else:
			session.notify_player(pid, "Walk to the door, workbench, or armchair. P opens your phone.")
		return
	if p.driving:
		# Parking uses side artwork, so check that shape before changing state.
		var parked: Rect2 = World.car_footprint(p.car_pos)
		if not World.clear_at("town", p.car_pos, 0, _obstacles(pid, true), parked):
			session.notify_player(pid, "No room to park. Move the car to an open spot.")
			return
		var obstacles := _obstacles(pid, true)
		obstacles.append(parked)
		for off in [Vector2(0, 26), Vector2(26, 0), Vector2(-26, 0), Vector2(0, -26)]:
			if World.clear_at("town", p.car_pos + off, 5, obstacles):
				p.driving = false
				p.pos = p.car_pos + off
				return
		session.notify_player(pid, "No room to get out. Move the car to an open spot.")
		return
	for m: Dictionary in session.market.active_meetings(p):
		if p.pos.distance_to(m.pos) <= 28:
			session.market.handoff(pid, p, int(m.listing_id))
			return
	if p.pos.distance_to(World.DOOR_OUTSIDE) < 28:
		p.area = "home"
		p.pos = World.DOOR_INSIDE - Vector2(0, 16)
		return
	if p.pos.distance_to(p.car_pos) < 34:
		if p.cash < 3:
			session.notify_player(pid, "Need $3 for fuel. You can still walk to a meeting.")
			return
		# Entry preserves the parked shape rather than inheriting a walker's facing.
		if not World.clear_at("town", p.car_pos, 0, _obstacles(pid, true), World.car_footprint(p.car_pos)):
			session.notify_player(pid, "The car is blocked. Wait for the way to clear.")
			return
		p.cash -= 3
		p.facing = Vector2.LEFT
		p.driving = true
		p.pos = p.car_pos
		session.notify_player(pid, "In the car. WASD / arrows to drive; E to park and get out. Fuel $3.")
	else:
		session.notify_player(pid, "E: car, home door, or a scheduled contact nearby. Use P for appointments.")


## Absolute next 07:00 for both confirmation and execution, before any deadline cap.
func sleep_target_minute() -> float:
	var now: float = session.clock()
	var morning := floorf(now / 1440.0) * 1440.0 + 420.0
	return morning + 1440.0 if morning <= now else morning


## Sleep uses the same authoritative clock as waiting; it never buys more match time.
func sleep(pid: int, p: Dictionary) -> void:
	if state.get("phase") != "playing" or bool(p.get("ready", false)):
		session.notify_player(pid, "You cannot sleep after finishing your build or match.")
		return
	if state.mode != "solo":
		session.notify_player(pid, "The clock is shared in LAN. Sleeping cannot skip other players' time.")
		return
	if p.driving:
		session.notify_player(pid, "Park and go home before sleeping.")
		return
	if not World.near_bed(p.area, p.pos):
		session.notify_player(pid, "Go home and stand near your bed to sleep.")
		return
	if bool(state.get("assembly_test", false)):
		session.notify_player(pid, "The practice clock is paused. Sleeping cannot advance it to 07:00.")
		return
	var skip := minf(sleep_target_minute() - session.clock(), maxf(0.0, float(state.remaining)))
	session.advance_time(skip)
	if state.remaining <= 0:
		session.notify_player(pid, "Sleep reached the match deadline before morning. %s" % Trade.stamp(session.clock()))
		if state.phase == "playing":
			session.end_match()
	else:
		session.notify_player(pid, "Slept until %s." % Trade.stamp(session.clock()))


func wait(pid: int, p: Dictionary) -> void:
	if state.mode != "solo":
		session.notify_player(pid, "The clock is shared in LAN. Waiting cannot skip other players' time.")
		return
	if p.driving:
		session.notify_player(pid, "Park before waiting.")
		return
	if bool(state.get("assembly_test", false)):
		var busy := float(p.busy)
		if busy > 0:
			session.advance_time(busy)
		session.notify_player(pid, "Practice job completed; the clock stays paused." if busy > 0 else "The practice clock is paused. There is no need to wait.")
		return
	var skip := 30.0
	for m: Dictionary in session.market.active_meetings(p):
		if m.status == "early" and p.area == "town" and p.pos.distance_to(m.pos) < 48:
			skip = minf(120, maxf(1, float(m.start) - session.clock()))
			break
	session.advance_time(skip)
	session.notify_player(pid, "Waited %d game minutes. %s" % [int(skip), Trade.stamp(session.clock())])
	if state.remaining <= 0:
		session.end_match()
