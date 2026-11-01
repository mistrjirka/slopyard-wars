extends Node
## Authoritative game backend (autoload "Game"). Host/solo own all state; LAN clients send actions by RPC
## and receive per-peer snapshots. See docs/backend.md.

signal changed
signal notice(message: String)

const Catalog := preload("res://scripts/catalog.gd")
const SellerScript := preload("res://scripts/seller_service.gd")
const PORT := 24680
const MAX_PLAYERS := 4
const RATE := 6.0                 # game minutes per real second
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
var _patience := {}      # "lid:pid" -> remaining rejected offers
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
		"offers": {}, "counters": {}, "trip": {}, "ready": false, "score": {}, "best": 0, "busy": 0.0, "pos": Catalog.HOME, "destroyed": []}


func _begin(budget: int, objective: String) -> void:
	state.budget = clampi(budget, 600, 5000)
	state.objective = objective if objective in Catalog.WEIGHTS else "Balanced"
	state.match_id += 1
	state.remaining = TOTAL_MINUTES
	state.events = []
	state.ranking = []
	state.listings = []
	_floors.clear()
	_patience.clear()
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
		p.best = int(best.get(state.objective, 0)) if state.mode == "solo" else 0
	for pick in Catalog.initial_picks(_rng, state.players.size()):
		_add_listing(pick.tpl, pick.anchor)
	state.phase = "playing"
	_event("Day 1 begins. Objective: %s. Budget $%d." % [state.objective, state.budget])
	_mark()


func _add_listing(tpl: Array, anchor: bool) -> Dictionary:
	var l: Dictionary = Catalog.build_listing(_rng, tpl, _next_id)
	_next_id += 1
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


func _host_tick(dt: float) -> void:
	var arrivals: Array = []
	for pid in state.players:
		var t: Dictionary = state.players[pid].trip
		if not t.is_empty() and t.remaining <= 0.0:
			arrivals.append(pid)
	arrivals.sort_custom(func(a, b): return state.players[a].trip.remaining < state.players[b].trip.remaining)
	for pid in arrivals:
		_arrive(pid)
	_refresh -= dt
	if _refresh <= 0.0:
		_refresh += REFRESH_EVERY
		_refresh_market()
	if state.remaining <= 0.0:
		_end_match()


func _arrive(pid: int) -> void:
	var p: Dictionary = state.players[pid]
	var t: Dictionary = p.trip
	var l := _listing(int(t.listing_id))
	p.trip = {}
	p.pos = t.destination
	_mark()
	if l.is_empty() or l.status != "available":
		_notify(pid, "Too late: %s was already taken (or gone) when you arrived. Fuel wasted." % (l.get("name", "that listing")))
		return
	var price := int(t.price)
	if p.cash < price:
		_notify(pid, "You arrived without enough cash for %s." % l.name)
		return
	p.cash -= price
	l.status = "sold"
	l.buyer = pid
	var item: Dictionary = l.duplicate(true)
	item.price = price
	p.inventory.append(item)
	p.offers.erase(l.id)
	_event("%s bought %s for $%d" % [p.name, l.name, price])
	_notify(pid, "Picked up %s for $%d. Check your inventory." % [l.name, price])


func _refresh_market() -> void:
	var trips := {}
	for pid in state.players:
		if not state.players[pid].trip.is_empty():
			trips[int(state.players[pid].trip.listing_id)] = true
	var pool: Array = []
	for l in state.listings:
		if l.status == "available" and not _anchors.has(l.id) and not trips.has(l.id):
			pool.append(l)
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
	var fallback: Dictionary = _seller.offline_decision(l, job.text, counter)
	if not ok:
		if error != "": _say(p, job.lid, "system", "Seller AI error: %s. Using offline reply." % error)
		decision = fallback
	var intent: String = str(decision.get("intent", "none"))
	var amount: int = int(decision.get("amount", 0))
	var action: String = str(decision.get("seller_action", "none"))
	var proposal: int = int(decision.get("counter_amount", 0))
	var line: String = str(decision.get("text", ""))
	var query: String = str(job.text).to_lower()
	var floor_price: int = int(_floors[job.lid])
	# Specific safeguards for questions and unsupported prices; semantic interpretation belongs to the seller model.
	var question_only := ("fit" in query or "compat" in query or "socket" in query or "asking price" in query or "still available" in query) and "?" in query
	if question_only: intent = "none"
	if intent == "offer" and not _amount_in_message(query, amount, int(l.price)):
		intent = "none"
	if intent == "accept_counter":
		if counter <= 0:
			intent = "offer" if _amount_in_message(query, amount, int(l.price)) else "none"
		else: amount = counter
	if l.personality != "Nerdy" and ("socket" in query or "compat" in query or "fit" in query):
		var reply_lower := line.to_lower()
		if not ("not sure" in reply_lower or "no idea" in reply_lower or "don't know" in reply_lower or "unsure" in reply_lower or "dunno" in reply_lower):
			line = "I'm not really sure about that, sorry."
	if intent in ["offer", "accept_counter"] and action == "accept" and amount >= floor_price and amount <= int(l.price) and not ("confirm" in line.to_lower() or "if you" in line.to_lower()):
		p.offers[job.lid] = amount
		p.counters.erase(job.lid)
		_notify(job.pid, "Seller agreed to $%d. Pickup is not reserved; first arrival wins." % amount)
	elif action == "counter" and proposal >= floor_price and proposal <= int(l.price):
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
	_mark()


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



func _do_travel(pid: int, p: Dictionary, d: Dictionary) -> void:
	var lid := int(_num(d.get("listing_id"), -1))
	var l := _listing(lid)
	if not p.trip.is_empty():
		_fail(pid, "You are already driving somewhere.")
		return
	if l.is_empty() or l.status != "available":
		_fail(pid, "That listing is no longer available.")
		return
	if not p.offers.has(lid):
		_fail(pid, "Agree a price with the seller in chat before travelling.")
		return
	var agreed: int = int(p.offers[lid])
	var price: int = mini(agreed, int(l.price))
	if agreed < 1 or price < int(_floors.get(lid, l.price)):
		_fail(pid, "That agreement is no longer valid.")
		return
	var dist: float = p.pos.distance_to(l.pos)
	var fuel := int(5 + dist * 0.02)
	if p.cash < price + fuel:
		_fail(pid, "Need $%d (price $%d + fuel $%d) but you have $%d." % [price + fuel, price, fuel, p.cash])
		return
	p.cash -= fuel
	var total := 15.0 + dist * 0.25
	p.trip = {"listing_id": lid, "remaining": total, "total": total, "origin": p.pos, "destination": l.pos,
		"fuel": fuel, "price": price}
	_event("%s drives to %s for %s" % [p.name, l.location, l.name])
	_notify(pid, "Driving to %s: %d game minutes, fuel $%d. Price at pickup $%d." % [l.location, int(total), fuel, price])


func _busy_block(pid: int, p: Dictionary) -> bool:
	if not p.trip.is_empty():
		_fail(pid, "You are out driving; get back to the workbench first (wait for pickup).")
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
