extends RefCounted
## Owns stock, private prices, appointments and atomic physical handoffs.

const Characters = preload("res://src/data/characters.gd")
const Catalog = preload("res://src/data/catalog.gd")
const Stats = preload("res://src/data/hardware_stats.gd")
const Trade = preload("res://src/trading/trade_rules.gd")
const Relationships = preload("res://src/trading/contact_relationships.gd")

var session: Node
var state: Dictionary:
	get:
		return session.state

var next_id := 1
var floors: Dictionary = {}
var anchors: Dictionary = {}
var sale_interest: Dictionary = {}
var interest_delay_scale := 1.0


func _init(game_session: Node) -> void:
	session = game_session


func add_listing(tpl: Resource, anchor: bool) -> Dictionary:
	var contact := _available_contact(tpl.model_id)
	if contact == null:
		return {}
	var l: Dictionary = Catalog.build_listing(session.rng, tpl, next_id, contact)
	next_id += 1
	l.pos = Catalog.LOCATIONS[l.location]
	l["owner"] = 0
	var character := Characters.for_listing(l)
	floors[l.id] = int(round(l.price * clampf(character.price_floor_fraction + session.rng.randf_range(-0.03, 0.03), 0.5, 1.0)))
	if anchor:
		anchors[l.id] = true
	state.listings.append(l)
	return l


## NPC stock is one seller/model identity, not a fresh chat on every random draw.
## Player-owned sales remain distinct physical items and do not use this deduplication.
func _available_contact(model_id: String = "") -> Resource:
	var available := Characters.ALL.filter(func(contact):
		if not model_id.is_empty():
			for item: Dictionary in state.listings:
				if int(item.get("owner", 0)) == 0 and str(item.get("character_id", "")) == str(contact.id) and str(item.get("model_id", "")) == model_id:
					if item.status == "available" or _referenced(int(item.id)):
						return false
		return not Trade.options(contact.display_name, contact.meeting_places[0], session.clock(), session.deadline()).is_empty())
	return null if available.is_empty() else available[session.rng.randi_range(0, available.size() - 1)]


func contact_options(listing: Dictionary) -> Array:
	var out: Array = []
	for option: Dictionary in Trade.options(str(listing.seller), str(listing.location), session.clock(), session.deadline()):
		if not meeting_conflict(str(listing.seller), int(listing.id), option):
			out.append(option)
	return out


func meeting_conflict(contact: String, listing_id: int, candidate: Dictionary) -> bool:
	for player: Dictionary in state.players.values():
		for id in player.get("meetings", {}):
			if int(id) == listing_id:
				continue
			var other := listing(int(id))
			if other.is_empty() or other.status != "available" or str(other.seller) != contact:
				continue
			var existing: Dictionary = player.meetings[id]
			if float(existing.end) <= session.clock():
				continue
			if float(candidate.start) < float(existing.end) and float(candidate.end) > float(existing.start) and candidate.place != existing.place:
				return true
	return false


func active_meetings(player: Dictionary) -> Array:
	var out: Array = []
	for lid in player.get("meetings", {}):
		var m: Dictionary = player.meetings[lid]
		var l := listing(int(lid))
		if not l.is_empty() and l.status == "available":
			var copy: Dictionary = m.duplicate(true)
			copy["listing_id"] = int(lid)
			copy["name"] = l.name
			copy["contact"] = l.seller
			copy["side"] = "sell" if int(l.get("owner", 0)) > 0 else "buy"
			copy["status"] = "missed" if session.clock() > float(m.end) else ("early" if session.clock() < float(m.start) else "now")
			out.append(copy)
	return out


func handoff(pid: int, p: Dictionary, lid: int) -> void:
	var l := listing(lid)
	if not l.is_empty() and Relationships.blocked(p, l):
		session.notify_player(pid, "This contact has ended trading with you.")
		return
	if l.is_empty() or l.status != "available" or not p.meetings.has(lid) or not p.offers.has(lid):
		session.notify_player(pid, "No live agreed meeting for this listing.")
		return
	var m: Dictionary = p.meetings[lid]
	if p.area != "town" or p.driving or p.pos.distance_to(m.pos) > 28:
		session.notify_player(pid, "Park and walk up to the contact at the agreed place.")
		return
	if session.clock() < float(m.start):
		if bool(state.get("assembly_test", false)):
			session.notify_player(pid, "The practice clock is paused. Use a normal run for timed pickups.")
			return
		session.notify_player(pid, "You're early. Meeting starts " + Trade.stamp(m.start) + ". Space waits in solo.")
		return
	if session.clock() > float(m.end):
		session.notify_player(pid, "They left. Message them to arrange another time.")
		return
	var price := int(p.offers[lid])
	if int(l.get("owner", 0)) > 0:
		if int(l.owner) != pid:
			return
		var idx := -1
		for i in p.inventory.size():
			if int(p.inventory[i].id) == int(l.item_id):
				idx = i
		if idx < 0:
			session.notify_player(pid, "The listed part is no longer in your inventory.")
			return
		p.inventory.remove_at(idx)
		p.cash += price
		session.record_event("%s sold %s to %s for $%d" % [p.name, l.name, l.seller, price])
	else:
		price = mini(price, int(l.price))
		if p.cash < price:
			session.notify_player(pid, "Not enough cash for the agreed price.")
			return
		p.cash -= price
		var item: Dictionary = l.duplicate(true)
		item.price = price
		p.inventory.append(item)
		session.record_event("%s collected %s for $%d" % [p.name, l.name, price])
	l.status = "sold"
	l.buyer = pid
	p.offers.erase(lid)
	p.meetings.erase(lid)
	session.text_player(pid, "Handoff complete: %s for $%d." % [l.name, price], str(m.get("place", l.location)))


func post_sale(pid: int, p: Dictionary, d: Dictionary) -> void:
	if bool(state.get("assembly_test", false)):
		session.notify_player(pid, "Selling is unavailable with the practice clock paused. Use a normal run to trade.")
		return
	var id = int(session.number(d.get("item_id"), -99999))
	var ask = int(session.number(d.get("price"), 0))
	if ask < 1 or ask > 5000:
		session.notify_player(pid, "Choose an asking price from $1 to $5,000.")
		return
	for l in state.listings:
		if int(l.get("owner", 0)) == pid and int(l.get("item_id", 0)) == id and l.status == "available":
			session.notify_player(pid, "This part already has a listing.")
			return
	var item := {}
	for it in p.inventory:
		if int(it.id) == id:
			item = it
	if item.is_empty():
		session.notify_player(pid, "Only spare parts you own can be listed.")
		return
	var contact := _available_contact()
	if contact == null:
		session.notify_player(pid, "No buyers have a meeting window left before the match deadline. Keep the spare and finish your build.")
		return
	var l: Dictionary = item.duplicate(true)
	l.id = next_id
	next_id += 1
	l["owner"] = pid
	l["item_id"] = id
	l["buyer_max"] = maxi(5, int(Stats.reference_price(item) * session.rng.randf_range(contact.buyer_budget_range.x, contact.buyer_budget_range.y)))
	l.price = ask
	l.status = "available"
	l.seller = contact.display_name
	l["character_id"] = str(contact.id)
	l.personality = contact.tagline
	l.location = contact.meeting_places[0]
	l.pos = Catalog.LOCATIONS[l.location]
	l["first_offer"] = maxi(1, mini(ask, int(l.buyer_max * 0.80)))
	l["buyer_contacted"] = false
	state.listings.append(l)
	anchors[l.id] = true
	floors[l.id] = 1
	var ratio := float(ask) / Stats.reference_price(item)
	var chance := clampf(1.0 - maxf(0, ratio - 1.15) * 2.0, 0, 1)
	if ratio <= contact.maximum_asking_ratio and session.rng.randf() < chance:
		var delay: float = session.rng.randf_range(contact.buyer_interest_delay_minutes.x, contact.buyer_interest_delay_minutes.y)
		delay *= 1.0 + maxf(0, ratio - 1.0) * 18.0
		sale_interest[l.id] = {"pid": pid, "match": state.match_id, "due": session.clock() + delay * interest_delay_scale}
	session.notify_player(pid, "Listing posted. Buyers may take a while; an ambitious asking price can attract no replies.")
	deliver_interest()


func deliver_interest() -> void:
	for lid in sale_interest.keys():
		var lead: Dictionary = sale_interest[lid]
		var item := listing(lid)
		if lead.match != state.match_id or item.is_empty() or item.status != "available" or not state.players.has(lead.pid) or state.players[lead.pid].ready:
			sale_interest.erase(lid)
			continue
		if session.clock() < float(lead.due):
			continue
		sale_interest.erase(lid)
		if contact_options(item).is_empty():
			continue
		var player: Dictionary = state.players[lead.pid]
		if Relationships.blocked(player, item):
			continue
		item.buyer_contacted = true
		player.counters[lid] = item.first_offer
		session.dialogue.say(player, lid, item.seller, Characters.line(Characters.for_listing(item).buyer_opening, int(item.first_offer)))
		session.notify_player(lead.pid, "%s messaged about your listing. Check Messages on your phone." % item.seller)
		session.mark_changed()


## Referenced rows are the durable identity behind private threads and agreements.
func _referenced(lid: int) -> bool:
	for player: Dictionary in state.players.values():
		for key in ["chats", "offers", "counters", "meetings", "meeting_proposals"]:
			if player.get(key, {}).has(lid):
				return true
	for job: Dictionary in session.dialogue.pending.values():
		if int(job.lid) == lid:
			return true
	return false


func refresh() -> void:
	var pool: Array = []
	for l in state.listings:
		if l.status == "available" and not anchors.has(l.id) and int(l.get("owner", 0)) == 0 and not _referenced(int(l.id)):
			pool.append(l)
	pool.shuffle()
	for l in pool.slice(0, mini(2, pool.size())):
		l.status = "expired"
		session.record_event("%s took '%s' off the market" % [l.seller, l.name])
	for k in 2:
		var l = add_listing(Catalog.random_pick(session.rng), false)
		if not l.is_empty():
			session.record_event("New listing: %s - $%d (%s)" % [l.name, l.price, l.location])
	for c in Catalog.CATEGORIES:
		var n := 0
		for l in state.listings:
			if l.category == c and l.status == "available":
				n += 1
		if n < 2:
			var l = add_listing(Catalog.random_pick(session.rng, c), false)
			if not l.is_empty():
				session.record_event("Restocked: %s - $%d" % [l.name, l.price])
	for l in pool.slice(2, 3):
		# Waiting is useful, but cannot turn a premium part into a $1 listing.
		var cut := maxi(maxi(5, roundi(Stats.reference_price(l) * 0.75)), roundi(l.price * 0.9))
		if cut >= int(l.price):
			continue
		l.price = cut
		floors[l.id] = mini(floors[l.id], cut)
		session.record_event("Price drop: %s now $%d" % [l.name, cut])
	var dead: Array = []
	for l in state.listings:
		if l.status != "available" and not _referenced(int(l.id)):
			dead.append(l)
	while dead.size() > 20:
		state.listings.erase(dead.pop_front())
	session.mark_changed()


func listing(id: int) -> Dictionary:
	for l in state.listings:
		if l.id == id:
			return l
	return {}
