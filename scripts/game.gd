extends Node
## Authoritative game backend (autoload "Game"). Host/solo own all state; LAN clients send actions by RPC
## and receive per-peer snapshots. See docs/backend.md.

signal changed
signal notice(message: String)

const Catalog := preload("res://scripts/catalog.gd")
const World := preload("res://scripts/world_rules.gd")
const Trade := preload("res://scripts/trade_rules.gd")
const SellerScript := preload("res://scripts/seller_service.gd")
const PORT := 24680
const MAX_PLAYERS := 4
const RATE := 2.0                 # game minutes per real second
const TOTAL_MINUTES := 4320.0
const REFRESH_EVERY := 90.0       # game minutes
const SAVE_PATH := "user://highscore.json"
const MAX_CHAT := 24
const MAX_EVENTS := 14
const MAX_TEXT := 240
const INSTALL_MIN := 10.0
const TUNE_MIN := 20.0

var state := {}
var _seller: Node
var _rng := RandomNumberGenerator.new()
var _next_id := 1
var _floors := {}        # listing id -> hidden minimum price (host only)
var _motion := {}        # host-owned input; never accept client coordinates
var _motion_age := {}
var _spatial_tick := 0.0
var _anchors := {}       # listing ids that never expire until sold
var _pending := {}       # chat req id -> {pid, lid, match, text}
var _pending_by := {}    # pid -> req id
var _serial := 0
var _dirty := false
var _hb_t := 0.0
var _refresh := 0.0
var _join_name := ""


func _ready() -> void:
	_rng.randomize()
	state = _blank()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_seller = SellerScript.new()
	_seller.name = "SellerService"
	add_child(_seller)
	_seller.reply.connect(_on_seller_reply)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_conn_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


func _blank() -> Dictionary:
	return {"phase": "menu", "mode": "solo", "remaining": TOTAL_MINUTES, "budget": 1000, "objective": "Balanced",
		"players": {}, "listings": [], "events": [], "ranking": [], "seller_status": "", "match_id": 0}


# ------------------------------------------------------------------ public API

func local_id() -> int:
	return multiplayer.get_unique_id()


func is_host() -> bool:
	return multiplayer.is_server()


func me() -> Dictionary:
	return state.players.get(local_id(), {})


func seller_status() -> String:
	return _seller.status() if is_host() else str(state.get("seller_status", ""))


func solo(player_name: String, budget: int = 1000, objective: String = "Balanced") -> void:
	leave()
	state.mode = "solo"
	state.players[1] = _new_player(player_name)
	_begin(budget, objective)


func host(player_name: String) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		notice.emit("Could not host on port %d (error %d). Is another game already hosting?" % [PORT, err])
		return err
	multiplayer.multiplayer_peer = peer
	state.mode = "lan"
	state.phase = "lobby"
	state.players[1] = _new_player(player_name)
	_event("%s opened a lobby" % state.players[1].name)
	_mark()
	return OK


func join_game(address: String, player_name: String) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var addr := address.strip_edges()
	var err := peer.create_client(addr if addr != "" else "127.0.0.1", PORT)
	if err != OK:
		notice.emit("Could not connect to '%s' (error %d)" % [addr, err])
		return err
	_join_name = player_name
	multiplayer.multiplayer_peer = peer
	state.mode = "lan"
	state.phase = "lobby"
	_mark()
	return OK


func leave() -> void:
	_seller.cancel_all()
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_pending.clear()
	_pending_by.clear()
	state = _blank()
	_motion.clear()
	_motion_age.clear()
	_mark()


func start_match(budget: int = 1000, objective: String = "Balanced") -> void:
	if not is_host() or state.phase != "lobby":
		notice.emit("Only the host can start a match from the lobby.")
		return
	_begin(budget, objective)


func act(action: String, data: Dictionary = {}) -> void:
	if is_host():
		_handle(local_id(), action, data)
	elif state.phase == "playing":
		_srv_act.rpc_id(1, action, data)


func compatibility(item: Dictionary, player: Dictionary) -> String:
	if item.is_empty() or not player.has("installed"):
		return "Unknown part"
	var rest: Dictionary = player.installed.duplicate()
	rest.erase(item.get("category", ""))
	return Catalog.compat(item, rest)


func build_issues(player: Dictionary) -> Array[String]:
	return Catalog.issues(player.get("installed", {}), player.get("tuning", {}))


func preview_score(player: Dictionary) -> Dictionary:
	return Catalog.score(player.get("installed", {}), player.get("tuning", {}), str(state.objective))


# ------------------------------------------------------------------ match lifecycle

func _new_player(pname: String) -> Dictionary:
	var n := pname.strip_edges().left(16)
	return {"name": n if n != "" else "Player", "cash": 0, "inventory": [], "installed": {}, "tuning": {}, "chats": {},
		"offers": {}, "counters": {}, "meetings": {}, "meeting_proposals": {}, "trip": {}, "area": "home", "driving": false, "car_pos": World.CAR_START, "facing": Vector2.DOWN, "ready": false, "score": {}, "best": 0, "busy": 0.0, "pos": World.SPAWN, "destroyed": []}


func _begin(budget: int, objective: String) -> void:
	state.budget = clampi(budget, 600, 5000)
	state.objective = objective if objective in Catalog.WEIGHTS else "Balanced"
	state.match_id += 1
	state.remaining = TOTAL_MINUTES
	state.events = []
	state.ranking = []
	state.listings = []
	_floors.clear()
	_motion.clear()
	_motion_age.clear()
	_anchors.clear()
	_pending.clear()
	_pending_by.clear()
	_next_id = 1
	_refresh = REFRESH_EVERY
	_seller.begin_match()
	var best := _load_best()
	for pid in state.players:
		var p: Dictionary = state.players[pid]
		var nm: String = p.name
		p.merge(_new_player(nm), true)
		p.cash = state.budget
		# A visible old spare makes the selling path usable before the first purchase.
		var spare: Dictionary = Catalog.build_listing(_rng, Catalog.T[0], -int(pid))
		spare.name = "Your spare Tin Can mATX"
		spare.status = "owned"
		p.inventory.append(spare)
		p.best = int(best.get(state.objective, 0)) if state.mode == "solo" else 0
	for pick in Catalog.initial_picks(_rng, state.players.size()):
		_add_listing(pick.tpl, pick.anchor)
	state.phase = "playing"
	_event("Day 1 begins. Objective: %s. Budget $%d." % [state.objective, state.budget])
	_mark()


func _add_listing(tpl: Array, anchor: bool) -> Dictionary:
	var l: Dictionary = Catalog.build_listing(_rng, tpl, _next_id)
	_next_id += 1
	l.pos = Catalog.LOCATIONS[l.location]
	l["owner"] = 0
	var pers: Dictionary = Catalog.PERSONALITIES[l.personality]
	_floors[l.id] = int(round(l.price * clampf(pers.floor + _rng.randf_range(-0.03, 0.03), 0.5, 1.0)))
	if anchor:
		_anchors[l.id] = true
	state.listings.append(l)
	return l


func _end_match() -> void:
	if state.phase != "playing":
		return
	_seller.cancel_all()
	_pending.clear()
	_pending_by.clear()
	for pid in state.players:
		var p: Dictionary = state.players[pid]
		p.trip = {}
		p.ready = true
		p.score = preview_score(p)
	var ids: Array = state.players.keys()
	ids.sort_custom(func(a, b): return state.players[a].score.total > state.players[b].score.total \
			or (state.players[a].score.total == state.players[b].score.total and state.players[a].cash > state.players[b].cash))
	state.ranking = ids
	state.phase = "results"
	state.remaining = maxf(0.0, state.remaining)
	if state.mode == "solo":
		var p: Dictionary = state.players[1]
		var best := _load_best()
		if p.score.total > int(best.get(state.objective, 0)):
			best[state.objective] = p.score.total
			_save_best(best)
			p.best = p.score.total
			notice.emit("New solo high score: %d" % p.score.total)
	_event("Match over.")
	_mark()


func _load_best() -> Dictionary:
	if FileAccess.file_exists(SAVE_PATH):
		var js = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if js is Dictionary:
			return js
	return {}


func _save_best(d: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


# ------------------------------------------------------------------ simulation

func _process(delta: float) -> void:
	if state.phase == "playing":
		var dt := delta * RATE
		state.remaining = maxf(0.0, state.remaining - dt)
		for pid in state.players:
			var p: Dictionary = state.players[pid]
			p.busy = maxf(0.0, p.busy - dt)
			if not p.trip.is_empty():
				p.trip.remaining = p.trip.remaining - dt
		if is_host():
			_host_tick(dt)
	if is_host():
		_hb_t += delta
		if _hb_t >= 1.0:
			_hb_t = 0.0
			_dirty = true
		if _dirty:
			state.seller_status = _seller.status()
	if _dirty:
		_dirty = false
		changed.emit()
		if is_host() and state.mode == "lan":
			_send_snapshots()


func clock() -> float:
	return Trade.START + TOTAL_MINUTES - float(state.remaining)


func contact_options(listing: Dictionary) -> Array:
	var out: Array = []
	for option: Dictionary in Trade.options(str(listing.seller), str(listing.location), clock()):
		if not _meeting_conflict(str(listing.seller), int(listing.id), option): out.append(option)
	return out


func _meeting_conflict(contact: String, listing_id: int, candidate: Dictionary) -> bool:
	for player: Dictionary in state.players.values():
		for id in player.get("meetings", {}):
			if int(id) == listing_id: continue
			var other := _listing(int(id))
			if other.is_empty() or other.status != "available" or str(other.seller) != contact: continue
			var existing: Dictionary = player.meetings[id]
			if float(existing.end) <= clock(): continue
			if float(candidate.start) < float(existing.end) and float(candidate.end) > float(existing.start) and candidate.place != existing.place: return true
	return false


func active_meetings(player: Dictionary) -> Array:
	var out: Array = []
	for lid in player.get("meetings", {}):
		var m: Dictionary = player.meetings[lid]
		var l := _listing(int(lid))
		if not l.is_empty() and l.status == "available":
			var copy: Dictionary = m.duplicate(true)
			copy["listing_id"] = int(lid)
			copy["name"] = l.name
			copy["contact"] = l.seller
			copy["side"] = "sell" if int(l.get("owner", 0)) > 0 else "buy"
			copy["status"] = "missed" if clock() > float(m.end) else ("early" if clock() < float(m.start) else "now")
			out.append(copy)
	return out


func _physics_process(delta: float) -> void:
	if not is_host() or state.get("phase") != "playing": return
	for pid in state.players:
		var p: Dictionary = state.players[pid]
		_motion_age[pid] = float(_motion_age.get(pid, 0.0)) + delta
		var direction: Vector2 = _motion.get(pid, Vector2.ZERO) if float(_motion_age[pid]) < 0.4 else Vector2.ZERO
		if p.ready: direction = Vector2.ZERO
		if direction.length_squared() > 0.01:
			p.facing = direction.normalized()
			p.pos = World.move(p.area, p.pos, direction.limit_length() * (World.CAR_SPEED if p.driving else World.WALK_SPEED) * delta, p.driving)
			if p.driving: p.car_pos = p.pos
	_spatial_tick += delta
	if _spatial_tick >= 0.08:
		_spatial_tick = 0.0
		_mark()


func _host_tick(dt: float) -> void:
	_refresh -= dt
	if _refresh <= 0.0:
		_refresh += REFRESH_EVERY
		_refresh_market()
	if state.remaining <= 0.0: _end_match()


func _interact(pid: int, p: Dictionary) -> void:
	if p.area == "home":
		if p.pos.distance_to(World.DOOR_INSIDE) < 27:
			p.area = "town"
			p.pos = World.DOOR_OUTSIDE
		elif p.pos.distance_to(World.BENCH) < 50:
			_notify(pid, "Workbench ready. Open the workbench with B; T opens tuning.")
		else: _notify(pid, "Walk to the door, workbench, or armchair. P opens your phone.")
		return
	if p.driving:
		# Park, then step out beside the vehicle only where a pedestrian can stand.
		for off in [Vector2(0, 22), Vector2(22, 0), Vector2(-22, 0), Vector2(0, -22)]:
			if World.clear_at("town", p.car_pos + off, 5):
				p.driving = false
				p.pos = p.car_pos + off
				return
		_notify(pid, "No room to get out. Move the car to an open spot.")
		return
	for m: Dictionary in active_meetings(p):
		if p.pos.distance_to(m.pos) <= 28:
			_handoff(pid, p, int(m.listing_id))
			return
	if p.pos.distance_to(World.DOOR_OUTSIDE) < 28:
		p.area = "home"
		p.pos = World.DOOR_INSIDE - Vector2(0, 16)
		return
	if p.pos.distance_to(p.car_pos) < 34:
		if p.cash < 3: _notify(pid, "Need $3 for fuel. You can still walk to a meeting."); return
		p.cash -= 3
		p.driving = true
		p.pos = p.car_pos
		_notify(pid, "In the car. WASD / arrows to drive; E to park and get out. Fuel $3.")
	else: _notify(pid, "E: car, home door, or a scheduled contact nearby. Use P for appointments.")


func _handoff(pid: int, p: Dictionary, lid: int) -> void:
	var l := _listing(lid)
	if l.is_empty() or l.status != "available" or not p.meetings.has(lid) or not p.offers.has(lid):
		_fail(pid, "No live agreed meeting for this listing."); return
	var m: Dictionary = p.meetings[lid]
	if p.area != "town" or p.driving or p.pos.distance_to(m.pos) > 28:
		_fail(pid, "Park and walk up to the contact at the agreed place."); return
	if clock() < float(m.start): _fail(pid, "You're early. Meeting starts " + Trade.stamp(m.start) + ". W waits in solo."); return
	if clock() > float(m.end): _fail(pid, "They left. Message them to arrange another time."); return
	var price := int(p.offers[lid])
	if int(l.get("owner", 0)) > 0:
		if int(l.owner) != pid: return
		var idx := -1
		for i in p.inventory.size():
			if int(p.inventory[i].id) == int(l.item_id): idx = i
		if idx < 0: _fail(pid, "The listed part is no longer in your inventory."); return
		p.inventory.remove_at(idx)
		p.cash += price
		_event("%s sold %s to %s for $%d" % [p.name, l.name, l.seller, price])
	else:
		price = mini(price, int(l.price))
		if p.cash < price: _fail(pid, "Not enough cash for the agreed price."); return
		p.cash -= price
		var item: Dictionary = l.duplicate(true)
		item.price = price
		p.inventory.append(item)
		_event("%s collected %s for $%d" % [p.name, l.name, price])
	l.status = "sold"
	l.buyer = pid
	p.offers.erase(lid)
	p.meetings.erase(lid)
	_notify(pid, "Handoff complete: %s for $%d." % [l.name, price])


func _post_sale(pid: int, p: Dictionary, d: Dictionary) -> void:
	var id := int(_num(d.get("item_id"), -99999))
	var ask := int(_num(d.get("price"), 0))
	if ask < 1 or ask > 5000: _fail(pid, "Choose an asking price from $1 to $5,000."); return
	for l in state.listings:
		if int(l.get("owner", 0)) == pid and int(l.get("item_id", 0)) == id and l.status == "available":
			_fail(pid, "This part already has a listing."); return
	var item := {}
	for it in p.inventory:
		if int(it.id) == id: item = it
	if item.is_empty(): _fail(pid, "Only spare parts you own can be listed."); return
	var l: Dictionary = item.duplicate(true)
	l.id = _next_id
	_next_id += 1
	l["owner"] = pid
	l["item_id"] = id
	l["buyer_max"] = maxi(5, int(maxf(15, float(item.price)) * _rng.randf_range(1.05, 1.65)))
	l.price = ask
	l.status = "available"
	var contact: Dictionary = Catalog.SELLERS[_rng.randi_range(0, Catalog.SELLERS.size() - 1)]
	l.seller = contact.name
	l.personality = contact.personality
	l.location = contact.location
	l.pos = Catalog.LOCATIONS[l.location]
	l["first_offer"] = maxi(1, mini(ask, int(l.buyer_max * 0.65)))
	state.listings.append(l)
	_anchors[l.id] = true
	_floors[l.id] = 1
	p.counters[l.id] = l.first_offer
	_say(p, l.id, l.seller, "Hi, is this still for sale? Would you take $%d? I can collect if we arrange a time." % l.first_offer)
	_notify(pid, "%s messaged about your listing. Check Messages on your phone." % l.seller)


func _wait(pid: int, p: Dictionary) -> void:
	if state.mode != "solo": _fail(pid, "The clock is shared in LAN. Waiting cannot skip other players' time."); return
	if p.driving: _fail(pid, "Park before waiting."); return
	var skip := 30.0
	for m: Dictionary in active_meetings(p):
		if m.status == "early" and p.area == "town" and p.pos.distance_to(m.pos) < 48:
			skip = minf(120, maxf(1, float(m.start) - clock()))
			break
	state.remaining = maxf(0, state.remaining - skip)
	_notify(pid, "Waited %d game minutes. %s" % [int(skip), Trade.stamp(clock())])
	if state.remaining <= 0: _end_match()


func _refresh_market() -> void:
	var trips := {}
	for pid in state.players:
		if not state.players[pid].trip.is_empty():
			trips[int(state.players[pid].trip.listing_id)] = true
	var pool: Array = []
	for l in state.listings:
		if l.status == "available" and not _anchors.has(l.id) and not trips.has(l.id) and int(l.get("owner", 0)) == 0:
			var scheduled := false
			for p: Dictionary in state.players.values():
				if p.meetings.has(l.id) and float(p.meetings[l.id].end) >= clock(): scheduled = true
			if not scheduled: pool.append(l)
	pool.shuffle()
	for l in pool.slice(0, mini(2, pool.size())):
		l.status = "expired"
		_event("%s took '%s' off the market" % [l.seller, l.name])
	for k in 2:
		var l := _add_listing(Catalog.random_pick(_rng), false)
		_event("New listing: %s - $%d (%s)" % [l.name, l.price, l.location])
	for c in Catalog.CATEGORIES:
		var n := 0
		for l in state.listings:
			if l.category == c and l.status == "available":
				n += 1
		if n < 2:
			var l := _add_listing(Catalog.random_pick(_rng, c), false)
			_event("Restocked: %s - $%d" % [l.name, l.price])
	for l in pool.slice(2, 3):
		var cut := int(l.price * 0.9)
		l.price = cut
		_floors[l.id] = mini(_floors[l.id], cut)
		_event("Price drop: %s now $%d" % [l.name, cut])
	var dead: Array = []
	for l in state.listings:
		if l.status != "available":
			dead.append(l)
	while dead.size() > 20:
		state.listings.erase(dead.pop_front())
	_mark()


# ------------------------------------------------------------------ actions

func _num(v: Variant, d: float = 0.0) -> float:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		var f := float(v)
		return d if is_nan(f) or is_inf(f) else f
	return d


func _listing(id: int) -> Dictionary:
	for l in state.listings:
		if l.id == id:
			return l
	return {}


func _notify(pid: int, msg: String) -> void:
	if pid == local_id():
		notice.emit(msg)
	elif pid > 1:
		_cl_notice.rpc_id(pid, msg)


func _fail(pid: int, msg: String) -> void:
	_notify(pid, msg)


func _handle(pid: int, action: String, data: Dictionary) -> void:
	if state.phase != "playing" or not state.players.has(pid):
		return
	var p: Dictionary = state.players[pid]
	if p.ready:
		_fail(pid, "Your rig is locked; waiting for the match to end.")
		return
	match action:
		"move":
			var v: Variant = data.get("direction", Vector2.ZERO)
			if v is Vector2 and is_finite(v.x) and is_finite(v.y):
				_motion[pid] = v.limit_length()
				_motion_age[pid] = 0.0
			return
		"interact": _interact(pid, p)
		"handoff": _handoff(pid, p, int(_num(data.get("listing_id"), -1)))
		"post_sale": _post_sale(pid, p, data)
		"cancel_sale":
			var listing := _listing(int(_num(data.get("listing_id"), -1)))
			if not listing.is_empty() and int(listing.get("owner", 0)) == pid and listing.status == "available": listing.status = "cancelled"
		"wait": _wait(pid, p)
		"chat": _do_chat(pid, p, data)
		"travel": _do_travel(pid, p, data)
		"install": _do_install(pid, p, data)
		"tune": _do_tune(pid, p, data)
		"finish": _do_finish(pid, p)
		_: _fail(pid, "Unknown action '%s'" % action)
	_mark()


func _say(p: Dictionary, lid: int, speaker: String, text: String, pending: bool = false) -> void:
	if not p.chats.has(lid):
		p.chats[lid] = []
	var arr: Array = p.chats[lid]
	var m := {"speaker": speaker, "text": text}
	if pending:
		m["pending"] = true
	arr.append(m)
	while arr.size() > MAX_CHAT:
		arr.pop_front()


func _do_chat(pid: int, p: Dictionary, d: Dictionary) -> void:
	var lid := int(_num(d.get("listing_id"), -1))
	var text := str(d.get("text", "")).strip_edges().left(MAX_TEXT)
	var l := _listing(lid)
	if l.is_empty() or l.status != "available" or text == "":
		_fail(pid, "Pick a listing and type a message.")
		return
	if int(l.get("owner", 0)) > 0 and int(l.owner) != pid:
		_fail(pid, "This is another player's private buyer conversation."); return
	if _pending_by.has(pid):
		_fail(pid, "Wait for the seller to answer your last message first.")
		return
	var hist: Array = []
	for m in p.chats.get(lid, []):
		if m.speaker != "system" and not m.get("pending", false):
			hist.append({"speaker": m.speaker, "text": m.text})
	_say(p, lid, p.name, text)
	_say(p, lid, "system", "%s is typing..." % l.seller, true)
	_serial += 1
	_pending[_serial] = {"pid": pid, "lid": lid, "match": state.match_id, "text": text}
	_pending_by[pid] = _serial
	var context: Dictionary = l.duplicate()
	context["seller_floor"] = int(_floors[lid])
	context["prior_counter"] = int(p.counters.get(lid, 0))
	context["sale_side"] = int(l.get("owner", 0)) == pid
	context["now"] = Trade.stamp(clock())
	context["meeting_options"] = contact_options(l)
	context["meeting_proposal"] = p.meeting_proposals.get(lid, {})
	context["agreed_price"] = int(p.offers.get(lid, 0))
	context["availability"] = Trade.profile(l.seller, l.location).note
	_pending[_serial]["options"] = context.meeting_options
	_seller.submit(_serial, context, hist, text)


func _on_seller_reply(req: int, ok: bool, decision: Dictionary, error: String) -> void:
	if not _pending.has(req): return
	var job: Dictionary = _pending[req]
	_pending.erase(req)
	_pending_by.erase(job.pid)
	if job.match != state.match_id or state.phase != "playing" or not state.players.has(job.pid): return
	var p: Dictionary = state.players[job.pid]
	if p.ready: return
	var l := _listing(job.lid)
	if l.is_empty(): return
	var arr: Array = p.chats.get(job.lid, [])
	for i in range(arr.size() - 1, -1, -1):
		if arr[i].get("pending", false): arr.remove_at(i)
	if l.status != "available":
		_say(p, job.lid, "system", "This listing is no longer available.")
		_mark()
		return
	var counter := int(p.counters.get(job.lid, 0))
	var offline_context: Dictionary = l.duplicate(true)
	offline_context["sale_side"] = int(l.get("owner", 0)) == int(job.pid)
	offline_context["meeting_options"] = job.get("options", [])
	offline_context["meeting_proposal"] = p.meeting_proposals.get(l.id, {})
	var fallback: Dictionary = _seller.offline_decision(offline_context, job.text, counter)
	if not ok:
		if error != "": _say(p, job.lid, "system", "Seller AI error: %s. Using offline reply." % error)
		decision = fallback
	var intent: String = str(decision.get("intent", "none"))
	var amount: int = int(decision.get("amount", 0))
	var action: String = str(decision.get("seller_action", "none"))
	var proposal: int = int(decision.get("counter_amount", 0))
	var line: String = str(decision.get("text", ""))
	var query: String = str(job.text).to_lower()
	var selling: bool = int(l.get("owner", 0)) == int(job.pid)
	var floor_price: int = 1 if selling else int(_floors[job.lid])
	var ceiling: int = int(l.buyer_max) if selling else int(l.price)
	# Specific safeguards for questions and unsupported prices; semantic interpretation belongs to the seller model.
	var question_only := ("fit" in query or "compat" in query or "socket" in query or "asking price" in query or "still available" in query) and "?" in query
	if question_only: intent = "none"
	if intent == "offer" and not _amount_in_message(query, amount, int(l.price)):
		intent = "none"
	if intent == "accept_counter":
		if counter <= 0:
			intent = "offer" if _amount_in_message(query, amount, int(l.price)) else "none"
		else: amount = counter
	# A logistics reply can reaffirm an already accepted price without a new monetary commitment.
	if p.offers.has(job.lid) and amount == int(p.offers[job.lid]) and action == "accept" and str(decision.get("meeting_action", "none")) != "none":
		intent = "none"
		action = "none"
	if l.personality != "Nerdy" and ("socket" in query or "compat" in query or "fit" in query):
		var reply_lower := line.to_lower()
		if not ("not sure" in reply_lower or "no idea" in reply_lower or "don't know" in reply_lower or "unsure" in reply_lower or "dunno" in reply_lower):
			line = "I'm not really sure about that, sorry."
	if intent in ["offer", "accept_counter"] and action == "accept" and amount >= floor_price and amount <= ceiling and not ("confirm" in line.to_lower() or "if you" in line.to_lower()):
		p.offers[job.lid] = amount
		p.counters.erase(job.lid)
		_notify(job.pid, "Seller agreed to $%d. Pickup is not reserved; first arrival wins." % amount)
	elif action == "counter" and proposal >= floor_price and proposal <= ceiling:
		p.counters[job.lid] = proposal
	elif not ok and intent == "offer" and amount < floor_price:
		var mix: float = Catalog.PERSONALITIES[l.personality].mix
		proposal = clampi(int(round(floor_price + (l.price - floor_price) * mix)), floor_price, l.price)
		p.counters[job.lid] = proposal
		line = "That's too low. How about $%d?" % proposal
	elif action in ["accept", "counter"]:
		# Never present an invalid or ungrounded proposed transaction as confirmed.
		_say(p, job.lid, "system", "Seller response could not be validated; please clarify your offer.")
		line = "Could you clarify what you have in mind?"
	_say(p, job.lid, l.seller, ("" if ok else "[offline] ") + line)
	_apply_meeting(p, l, decision, job.get("options", []))
	_mark()


func _apply_meeting(p: Dictionary, l: Dictionary, d: Dictionary, offered: Array) -> void:
	var action := str(d.get("meeting_action", "none"))
	var id := str(d.get("meeting_id", ""))
	if action == "none" or id == "": return
	var proposed: Dictionary = p.meeting_proposals.get(l.id, {})
	var chosen := Trade.find_option(offered, id)
	if chosen.is_empty() and str(proposed.get("id", "")) == id: chosen = proposed.duplicate(true)
	if chosen.is_empty() or float(chosen.end) <= clock(): return
	if action == "propose":
		p.meeting_proposals[l.id] = chosen
	elif action == "accept" and p.offers.has(l.id):
		if _meeting_conflict(str(l.seller), int(l.id), chosen):
			_say(p, l.id, "system", "They have another meeting at that time now. Ask for a different place or time.")
			return
		p.meetings[l.id] = chosen
		p.meeting_proposals.erase(l.id)
		_say(p, l.id, "system", "Meeting confirmed: " + chosen.label + ". Park and walk up to complete the handoff. Not reserved.")


func _amount_in_message(text: String, amount: int, ask: int) -> bool:
	if amount <= 0: return false
	if amount == ask and ("asking" in text or "full price" in text): return true
	# A model-classified purchase commitment without an amount naturally means the listed price.
	if amount == ask and ("take it" in text or "buy it" in text or "purchase it" in text) and not ("not " in text or "won't " in text or "don't " in text or "?" in text.split(",")[0]):
		return true
	var rx := RegEx.create_from_string("(?<![0-9])[0-9]+(?![0-9])")
	for m in rx.search_all(text):
		if int(m.get_string()) == amount: return true
	if amount > 999: return false
	var units := ["", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
	var tens := ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
	var words := ""
	var remainder := amount
	if amount >= 100:
		words = units[int(amount / 100)] + " hundred"
		remainder = amount % 100
	if remainder > 0:
		var tail: String = units[remainder] if remainder < 20 else tens[int(remainder / 10)] + (" " + units[remainder % 10] if remainder % 10 else "")
		words += (" " if words != "" else "") + tail
	var normalized := " " + text.replace("-", " ").replace(" and ", " ") + " "
	return (" " + words + " ") in normalized or normalized.contains(" " + words + ",") or normalized.contains(" " + words + ".") or normalized.contains(" " + words + "?")



func _do_travel(pid: int, _p: Dictionary, _d: Dictionary) -> void:
	_fail(pid, "Walk outside to your car and drive there. P shows agreed meeting places and times.")


func _busy_block(pid: int, p: Dictionary) -> bool:
	if p.area != "home" or p.pos.distance_to(World.BENCH) > 58:
		_fail(pid, "Return home and walk to the workbench first.")
		return true
	if p.busy > 0.0:
		_fail(pid, "Workbench busy for %d more game minutes." % ceili(p.busy))
		return true
	return false


func _do_install(pid: int, p: Dictionary, d: Dictionary) -> void:
	if _busy_block(pid, p):
		return
	var id := int(_num(d.get("item_id"), -1))
	var idx := -1
	for i in p.inventory.size():
		if p.inventory[i].id == id:
			idx = i
	if idx < 0:
		_fail(pid, "You do not own that part.")
		return
	var item: Dictionary = p.inventory[idx]
	for listing in state.listings:
		if int(listing.get("owner", 0)) == pid and int(listing.get("item_id", -99999)) == id and listing.status == "available":
			_fail(pid, "Cancel the sale listing before installing this part."); return
	var why := compatibility(item, p)
	if why != "":
		_fail(pid, "Cannot install: " + why)
		return
	p.inventory.remove_at(idx)
	var cat: String = item.category
	if p.installed.has(cat):
		p.inventory.append(p.installed[cat])
	p.installed[cat] = item
	p.tuning.erase(cat)
	p.busy = INSTALL_MIN
	var rest := build_issues(p)
	_notify(pid, "Installed %s." % item.name + ("" if rest.is_empty() else " Still: " + rest[0]))


func _do_tune(pid: int, p: Dictionary, d: Dictionary) -> void:
	if _busy_block(pid, p):
		return
	var cat := str(d.get("category", ""))
	if cat not in Catalog.TUNABLE or not p.installed.has(cat):
		_fail(pid, "Install a CPU, GPU or RAM before tuning it.")
		return
	var clock := snappedf(clampf(_num(d.get("clock"), 1.0), 1.0, 1.6), 0.01)
	var volt := snappedf(clampf(_num(d.get("voltage"), 1.0), 1.0, 1.6), 0.01)
	p.busy = TUNE_MIN
	var item: Dictionary = p.installed[cat]
	if volt > Catalog.MAX_SAFE_VOLTAGE + 0.0001:
		p.installed.erase(cat)
		p.tuning.erase(cat)
		p.destroyed.append(item.name)
		_event("%s fried their %s at %.2fV!" % [p.name, item.name, volt])
		_notify(pid, "BANG! %.2fV is above %.2fV and destroyed your %s permanently." % [volt, Catalog.MAX_SAFE_VOLTAGE, item.name])
		return
	p.tuning[cat] = {"clock": clock, "voltage": volt}
	var m: float = Catalog.multiplier(clock, volt)
	var stable: float = Catalog.stable_clock(volt)
	var msg := "%s stress test at clock x%.2f / %.2fV: score x%.2f." % [cat.to_upper(), clock, volt, m]
	if clock > stable + 0.0005:
		msg += " UNSTABLE (stable up to x%.2f at this voltage); raise voltage (max safe %.2fV) or lower clock." % [stable, Catalog.MAX_SAFE_VOLTAGE]
	var iss := build_issues(p)
	for i in iss:
		if i.begins_with("PSU"):
			msg += " " + i
	_notify(pid, msg)


func _do_finish(pid: int, p: Dictionary) -> void:
	if _busy_block(pid, p): return
	p.ready = true
	p.trip = {}
	p.score = preview_score(p)
	_event("%s finished their rig." % p.name)
	_check_all_ready()


func _check_all_ready() -> void:
	for pid in state.players:
		if not state.players[pid].ready:
			return
	_end_match()


func _event(text: String) -> void:
	state.events.append(text)
	while state.events.size() > MAX_EVENTS:
		state.events.pop_front()


func _mark() -> void:
	_dirty = true


# ------------------------------------------------------------------ networking

func _send_snapshots() -> void:
	for pid in state.players:
		if pid == 1 or not pid in multiplayer.get_peers():
			continue
		_cl_state.rpc_id(pid, _view_for(pid))


func _view_for(pid: int) -> Dictionary:
	var v: Dictionary = state.duplicate(true)
	for id in v.players:
		if id != pid:
			v.players[id].chats = {}
			v.players[id].offers = {}
			v.players[id].counters = {}
			v.players[id].meeting_proposals = {}
	for listing: Dictionary in v.listings:
		listing.erase("buyer_max")
	return v


@rpc("authority", "call_remote", "reliable")
func _cl_state(s: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	state = s
	_dirty = true


@rpc("authority", "call_remote", "reliable")
func _cl_notice(msg: String) -> void:
	notice.emit(msg)


@rpc("any_peer", "call_remote", "reliable")
func _srv_act(action: String, data: Dictionary) -> void:
	if is_host():
		_handle(multiplayer.get_remote_sender_id(), action, data)


@rpc("any_peer", "call_remote", "reliable")
func _srv_hello(pname: String) -> void:
	if not is_host():
		return
	var pid := multiplayer.get_remote_sender_id()
	if state.phase != "lobby" or state.players.size() >= MAX_PLAYERS or state.players.has(pid):
		multiplayer.multiplayer_peer.disconnect_peer(pid)
		return
	state.players[pid] = _new_player(pname)
	_event("%s joined" % state.players[pid].name)
	_mark()


func _on_peer_connected(pid: int) -> void:
	if is_host() and state.phase != "lobby":
		multiplayer.multiplayer_peer.disconnect_peer(pid)


func _on_peer_disconnected(pid: int) -> void:
	if not is_host() or not state.players.has(pid):
		return
	var nm: String = state.players[pid].name
	if state.phase == "lobby":
		state.players.erase(pid)
	elif state.phase == "playing":
		var p: Dictionary = state.players[pid]
		p.ready = true
		p.trip = {}
		p.score = preview_score(p)
		_event("%s disconnected" % nm)
		_check_all_ready()
	notice.emit("%s left." % nm)
	_mark()


func _on_connected() -> void:
	_srv_hello.rpc_id(1, _join_name)


func _on_conn_failed() -> void:
	leave()
	notice.emit("Could not reach the host. Check the address and that the host opened a lobby (UDP port %d)." % PORT)


func _on_server_gone() -> void:
	leave()
	notice.emit("Disconnected from host.")
