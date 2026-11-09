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
	for pid in state.players:
		var p: Dictionary = state.players[pid]
		motion_age[pid] = float(motion_age.get(pid, 0.0)) + delta
		var direction: Vector2 = motion.get(pid, Vector2.ZERO) if float(motion_age[pid]) < 0.4 else Vector2.ZERO
		if p.ready:
			direction = Vector2.ZERO
		if direction.length_squared() > 0.01:
			p.facing = direction.normalized()
			p.pos = World.move(p.area, p.pos, direction.limit_length() * (World.CAR_SPEED if p.driving else World.WALK_SPEED) * delta, p.driving)
			if p.driving:
				p.car_pos = p.pos
	spatial_tick += delta
	if spatial_tick >= 0.08:
		spatial_tick = 0.0
		session.mark_changed()


func interact(pid: int, p: Dictionary) -> void:
	if p.area == "home":
		if p.pos.distance_to(World.DOOR_INSIDE) < 27:
			p.area = "town"
			p.pos = World.DOOR_OUTSIDE
		elif p.pos.distance_to(World.BENCH) < 50:
			session.notify_player(pid, "Workbench ready. Open the workbench with B; T opens tuning.")
		else:
			session.notify_player(pid, "Walk to the door, workbench, or armchair. P opens your phone.")
		return
	if p.driving:
		# Park, then step out beside the vehicle only where a pedestrian can stand.
		for off in [Vector2(0, 22), Vector2(22, 0), Vector2(-22, 0), Vector2(0, -22)]:
			if World.clear_at("town", p.car_pos + off, 5):
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
		p.cash -= 3
		p.driving = true
		p.pos = p.car_pos
		session.notify_player(pid, "In the car. WASD / arrows to drive; E to park and get out. Fuel $3.")
	else:
		session.notify_player(pid, "E: car, home door, or a scheduled contact nearby. Use P for appointments.")


func wait(pid: int, p: Dictionary) -> void:
	if state.mode != "solo":
		session.notify_player(pid, "The clock is shared in LAN. Waiting cannot skip other players' time.")
		return
	if p.driving:
		session.notify_player(pid, "Park before waiting.")
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
