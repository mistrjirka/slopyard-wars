extends Node
## Session facade: lifecycle, clock and RPC boundary. Gameplay belongs to the injected systems.
## Only this Node transports state; UI calls act() and never sends coordinates or balances.

signal changed
signal notice(message: String)
## Accepted manual install/reinstall only; startup seeding bypasses this action event.
signal component_installed(item_id: int)
## Emitted only after an authoritative roll and its permanent consequences are applied.
signal stress_test_resolved(outcome: Dictionary)

const LanTransport = preload("res://src/network/lan_transport.gd")
const Snapshot = preload("res://src/network/snapshot.gd")
const Config = preload("res://src/core/game_config.gd")
const RigRules = preload("res://src/workshop/rig_rules.gd")
const Catalog = preload("res://src/data/catalog.gd")
const Trade = preload("res://src/trading/trade_rules.gd")
const StateFactory = preload("res://src/core/state_factory.gd")
const World = preload("res://src/world/world_rules.gd")
const ScoreStore = preload("res://src/core/score_store.gd")
const SellerScript = preload("res://src/trading/seller_service.gd")
const MarketSystem = preload("res://src/trading/market_system.gd")
const DialogueSystem = preload("res://src/trading/dialogue_system.gd")
const MovementSystem = preload("res://src/world/movement_system.gd")
const ActivitySystem = preload("res://src/world/activity_system.gd")
const WorkshopSystem = preload("res://src/workshop/workshop_system.gd")

var state: Dictionary = {}
var score_path := Config.SAVE_PATH
var seller: Node
var rng := RandomNumberGenerator.new()
var market := MarketSystem.new(self)
var dialogue := DialogueSystem.new(self)
var movement := MovementSystem.new(self)
var workshop := WorkshopSystem.new(self)
var activities := ActivitySystem.new(self)
var _dirty := false
var _hb_t := 0.0
var _refresh := 0.0
var _network: Node
var _match_serial := 0


func _ready() -> void:
	rng.randomize()
	state = StateFactory.blank()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	seller = SellerScript.new()
	seller.name = "SellerService"
	add_child(seller)
	seller.reply.connect(dialogue.receive_reply)
	_network = LanTransport.new()
	_network.name = "Network"
	add_child(_network)
	_network.action_received.connect(_handle)
	_network.hello_received.connect(_on_hello)
	_network.peer_arrived.connect(_on_peer_connected)
	_network.peer_left.connect(_on_peer_disconnected)
	_network.snapshot_received.connect(_receive_snapshot)
	_network.notice_received.connect(func(message: String): notice.emit(message))
	_network.connection_failed.connect(_on_conn_failed)
	_network.server_left.connect(_on_server_gone)


func local_id() -> int:
	return multiplayer.get_unique_id()


func is_host() -> bool:
	return multiplayer.is_server()


func me() -> Dictionary:
	return state.players.get(local_id(), {})


func seller_status() -> String:
	return seller.status() if is_host() else str(state.get("seller_status", ""))


## Local settings only: these never enter match state or the network transport.
func openrouter_key() -> String:
	return seller.get_api_key()


func set_openrouter_key(value: String) -> void:
	seller.set_api_key(value)


func solo(player_name: String, budget: int = 1000, objective: String = "Balanced", match_days: int = Config.DEFAULT_MATCH_DAYS) -> void:
	leave()
	state.mode = "solo"
	state.players[1] = StateFactory.player(player_name)
	_begin(budget, objective, match_days)


## Local-only sandbox: no LAN entry point or action grants test-mode inventory.
func start_assembly_test(player_name: String) -> void:
	leave()
	state.mode = "solo"
	state.players[1] = StateFactory.player(player_name)
	_begin(1000, "Balanced", Config.DEFAULT_MATCH_DAYS, true)


## Multiplayer entry points remain callable for compatibility, but never open a connection.
func host(_player_name: String, _match_days: int = Config.DEFAULT_MATCH_DAYS) -> Error:
	notice.emit("Solo only: multiplayer is disabled. Start a solo high-score run from Play.")
	return ERR_UNAVAILABLE


func join_game(_address: String, _player_name: String) -> Error:
	notice.emit("Solo only: multiplayer is disabled. Start a solo high-score run from Play.")
	return ERR_UNAVAILABLE


func leave() -> void:
	seller.cancel_all()
	_network.close()
	dialogue.pending.clear()
	dialogue.pending_by.clear()
	state = StateFactory.blank()
	movement.motion.clear()
	movement.motion_age.clear()
	mark_changed()


func start_match(_budget: int = 1000, _objective: String = "Balanced", _match_days: int = -1) -> void:
	notice.emit("Solo only: lobbies are disabled. Start a solo high-score run from Play.")


## Lobby configuration is disabled; solo() still accepts the selected run length.
func set_match_days(_days: int) -> void:
	notice.emit("Solo only: choose your run length in Play; lobbies are disabled.")


func act(action: String, data: Dictionary = {}) -> void:
	if is_host():
		_handle(local_id(), action, data)
	elif state.phase == "playing":
		_network.send_action(action, data)


func _begin(budget: int, objective: String, match_days: int, assembly_test: bool = false) -> void:
	state.assembly_test = assembly_test
	state.budget = clampi(budget, 600, 5000)
	state.objective = objective if objective in RigRules.WEIGHTS else "Balanced"
	_match_serial += 1
	state.match_id = _match_serial
	state.match_days = clampi(match_days, Config.MIN_MATCH_DAYS, Config.MAX_MATCH_DAYS)
	state.total_minutes = Config.duration_for_days(state.match_days)
	state.deadline = Config.deadline_for_days(state.match_days)
	state.remaining = state.total_minutes
	state.events = []
	state.ranking = []
	state.listings = []
	market.floors.clear()
	movement.motion.clear()
	movement.motion_age.clear()
	market.anchors.clear()
	market.sale_interest.clear()
	dialogue.pending.clear()
	dialogue.pending_by.clear()
	market.next_id = 1
	_movement_tick_reset()
	_refresh = Config.REFRESH_EVERY
	seller.begin_match()
	var best := {} if assembly_test else ScoreStore.load_best(score_path)
	var player_ids: Array = state.players.keys()
	player_ids.sort()
	var car_slot := 0
	for pid in player_ids:
		var p: Dictionary = state.players[pid]
		var nm: String = p.name
		p.merge(StateFactory.player(nm), true)
		# Four separated bays on the open road; solo retains the original bay.
		p.car_pos = World.CAR_START + Vector2(car_slot * 48, 0)
		car_slot += 1
		p.cash = state.budget
		if assembly_test:
			p.pos = World.BENCH + Vector2(0, 28)
			p.inventory = StateFactory.assembly_test_inventory(rng)
			_seed_test_rig(int(pid), p)
			continue
		# A visible old spare makes the selling path usable before the first purchase.
		var spare: Dictionary = Catalog.build_listing(rng, Catalog.PARTS[0], -int(pid))
		spare.name = "Your spare Tin Can mATX"
		spare.status = "owned"
		p.inventory.append(spare)
		p.best = int(best.get(ScoreStore.key(state.objective, state.budget, state.match_days), 0)) if state.mode == "solo" else 0
	if not assembly_test:
		for pick in Catalog.initial_picks(rng, state.players.size()):
			market.add_listing(pick.tpl, pick.anchor)
	state.phase = "playing"
	if assembly_test:
		record_event("Assembly test: all catalog parts supplied. Deadline paused; scores are not saved.")
	else:
		record_event("%d-day challenge begins. Deadline %s. Objective: %s. Budget $%d." % [state.match_days, Trade.stamp(deadline()), state.objective, state.budget])
	mark_changed()


## Use the real installation path, including compatibility and build-local mount data.
func _seed_test_rig(pid: int, p: Dictionary) -> void:
	for category in ["case", "psu", "motherboard", "cpu", "ram", "storage", "gpu"]:
		var selected: Dictionary = {}
		for item: Dictionary in p.inventory:
			if item.category != category or workshop.compatibility(item, p) != "":
				continue
			if category == "case" and item.form != "ATX":
				continue
			if selected.is_empty() or (category == "psu" and int(item.capacity) > int(selected.capacity)):
				selected = item
		if not selected.is_empty():
			workshop.install(pid, p, {"item_id": selected.id})


func end_match() -> void:
	if state.phase != "playing":
		return
	seller.cancel_all()
	dialogue.pending.clear()
	dialogue.pending_by.clear()
	for pid in state.players:
		var p: Dictionary = state.players[pid]
		p.ready = true
		p.score = workshop.final_score(pid, p)
	var ids: Array = state.players.keys()
	ids.sort_custom(func(a, b): return state.players[a].score.total > state.players[b].score.total \
			or (state.players[a].score.total == state.players[b].score.total and state.players[a].cash > state.players[b].cash))
	state.ranking = ids
	state.phase = "results"
	state.remaining = maxf(0.0, state.remaining)
	if state.mode == "solo" and not state.get("assembly_test", false):
		var p: Dictionary = state.players[1]
		var best := ScoreStore.load_best(score_path)
		var score_key := ScoreStore.key(state.objective, state.budget, state.match_days)
		if p.score.total > int(best.get(score_key, 0)):
			best[score_key] = p.score.total
			ScoreStore.save_best(best, score_path)
			p.best = p.score.total
			p["new_best"] = true
			notice.emit("New solo high score: %d" % p.score.total)
	record_event("Match over.")
	mark_changed()


func _process(delta: float) -> void:
	if state.phase == "playing":
		advance_time(delta * Config.RATE)
	if is_host():
		_hb_t += delta
		if _hb_t >= 1.0:
			_hb_t = 0.0
			_dirty = true
		if _dirty:
			state.seller_status = seller.status()
	if _dirty:
		_dirty = false
		changed.emit()
		if is_host() and state.mode == "lan":
			_send_snapshots()


func clock() -> float:
	return deadline() - float(state.remaining)


func deadline() -> float:
	return float(state.get("deadline", Config.DEADLINE))


func _host_tick(dt: float) -> void:
	if state.remaining <= 0.0:
		end_match()
		return
	dialogue.tick()
	market.deliver_interest()
	market.remind_meetings(dt)
	for threshold in [60.0, Config.BUILD_REMINDER_MINUTES]:
		if float(state.remaining) <= threshold and float(state.remaining) + dt > threshold:
			var message := "Final hour! Finish your build at the workbench before the match deadline." if threshold == 60 else "Three game hours left. Time to bring the bargains home: leave room for assembly and stress tests."
			record_event(message)
			for pid in state.players:
				if not state.players[pid].ready:
					text_player(pid, message)
			break
	_refresh -= dt
	while _refresh <= 0.0:
		_refresh += Config.REFRESH_EVERY
		market.refresh()


func number(v: Variant, d: float = 0.0) -> float:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		var f := float(v)
		return d if is_nan(f) or is_inf(f) else f
	return d


func notify_player(pid: int, msg: String) -> void:
	if pid == local_id():
		notice.emit(msg)
	elif pid > 1:
		_network.send_notice(pid, msg)


## World-event texts are private match history, separate from immediate action feedback.
func text_player(pid: int, msg: String, place: String = "") -> void:
	if not state.players.has(pid) or msg.strip_edges().is_empty():
		return
	var player: Dictionary = state.players[pid]
	var origin := place.strip_edges()
	if origin.is_empty():
		origin = "Home" if player.area == "home" else "Town"
	player.lucky_messages.append({"speaker": "Lucky", "text": msg, "minute": clock(), "place": origin})
	mark_changed()


func _handle(pid: int, action: String, data: Dictionary) -> void:
	if state.phase != "playing" or not state.players.has(pid):
		return
	var p: Dictionary = state.players[pid]
	if p.ready:
		notify_player(pid, "Your rig is locked; waiting for the match to end.")
		return
	match action:
		"move":
			var v: Variant = data.get("direction", Vector2.ZERO)
			if v is Vector2 and is_finite(v.x) and is_finite(v.y):
				movement.motion[pid] = v.limit_length()
				movement.motion_age[pid] = 0.0
			return
		"interact": movement.interact(pid, p)
		"handoff": market.handoff(pid, p, int(number(data.get("listing_id"), -1)))
		"post_sale": market.post_sale(pid, p, data)
		"cancel_sale":
			var listing := market.listing(int(number(data.get("listing_id"), -1)))
			if not listing.is_empty() and int(listing.get("owner", 0)) == pid and listing.status == "available":
				listing.status = "cancelled"
		"world_activity": activities.use(pid, p, data)
		"wait": movement.wait(pid, p)
		"sleep": movement.sleep(pid, p)
		"chat": dialogue.chat(pid, p, data)
		"choose_meeting": dialogue.choose_meeting(pid, p, data)
		"install":
			if workshop.install(pid, p, data) and pid == local_id():
				component_installed.emit(int(number(data.get("item_id"), -1)))
		"uninstall": workshop.uninstall(pid, p, data)
		"assembly_damage": workshop.assembly_damage(pid, p, data)
		"tune": workshop.tune(pid, p, data)
		"finish": workshop.finish(pid, p)
		_: notify_player(pid, "Unknown action '%s'" % action)
	mark_changed()


## Store the same authoritative outcome consumed by the tuning view and result dialog.
func publish_stress_result(pid: int, outcome: Dictionary) -> void:
	var player: Dictionary = state.players[pid]
	outcome["serial"] = int(player.get("last_stress_test", {}).get("serial", 0)) + 1
	player["last_stress_test"] = outcome.duplicate(true)
	mark_changed()
	if pid == local_id():
		stress_test_resolved.emit(outcome.duplicate(true))


func check_all_ready() -> void:
	for pid in state.players:
		if not state.players[pid].ready:
			return
	end_match()


func record_event(text: String) -> void:
	state.events.append(text)
	while state.events.size() > Config.MAX_EVENTS:
		state.events.pop_front()


func mark_changed() -> void:
	_dirty = true


func _send_snapshots() -> void:
	for pid in state.players:
		if pid == 1 or not pid in multiplayer.get_peers():
			continue
		_network.send_snapshot(pid, Snapshot.for_player(state, pid))


func _receive_snapshot(snapshot: Dictionary) -> void:
	state = snapshot
	mark_changed()


func _on_hello(pid: int, player_name: String) -> void:
	if not is_host():
		return
	if state.phase != "lobby" or state.players.size() >= Config.MAX_PLAYERS or state.players.has(pid):
		multiplayer.multiplayer_peer.disconnect_peer(pid)
		return
	state.players[pid] = StateFactory.player(player_name)
	record_event("%s joined" % state.players[pid].name)
	mark_changed()


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
		p.score = workshop.final_score(pid, p)
		record_event("%s disconnected" % nm)
		check_all_ready()
	notice.emit("%s left." % nm)
	mark_changed()


func _on_conn_failed() -> void:
	leave()
	notice.emit("Could not reach the host. Check the address and that the host opened a lobby (UDP port %d)." % Config.PORT)


func _on_server_gone() -> void:
	leave()
	notice.emit("Disconnected from host.")


func _physics_process(delta: float) -> void:
	movement.tick(delta)


func _movement_tick_reset() -> void:
	movement.spatial_tick = 0.0
	_hb_t = 0.0


func advance_time(minutes: float) -> void:
	var assembly_test := bool(state.get("assembly_test", false))
	if not assembly_test:
		state.remaining = maxf(0.0, float(state.remaining) - minutes)
	# Stress tests and activities still complete at the normal rate in the sandbox.
	for player: Dictionary in state.players.values():
		player.busy = maxf(0.0, float(player.busy) - minutes)
	if is_host() and not assembly_test:
		_host_tick(minutes)


func compatibility(item: Dictionary, player: Dictionary) -> String:
	return workshop.compatibility(item, player)


func build_issues(player: Dictionary) -> Array[String]:
	return workshop.build_issues(player)


func preview_score(player: Dictionary) -> Dictionary:
	return workshop.preview_score(player)


func contact_options(listing: Dictionary) -> Array:
	return market.contact_options(listing)


func active_meetings(player: Dictionary) -> Array:
	return market.active_meetings(player)
