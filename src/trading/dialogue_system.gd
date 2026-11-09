extends RefCounted
## Validates asynchronous counterparty proposals before changing agreements.

const Config = preload("res://src/core/game_config.gd")
const Characters = preload("res://src/data/characters.gd")
const Trade = preload("res://src/trading/trade_rules.gd")

var session: Node
var state: Dictionary:
	get:
		return session.state

var pending: Dictionary = {}
var pending_by: Dictionary = {}
var serial := 0


func _init(game_session: Node) -> void:
	session = game_session


func say(p: Dictionary, lid: int, speaker: String, text: String, pending: bool = false) -> void:
	if not p.chats.has(lid):
		p.chats[lid] = []
	var arr: Array = p.chats[lid]
	var m := {"speaker": speaker, "text": text}
	if pending:
		m["pending"] = true
	arr.append(m)
	while arr.size() > Config.MAX_CHAT:
		arr.pop_front()


func chat(pid: int, p: Dictionary, d: Dictionary) -> void:
	var lid = int(session.number(d.get("listing_id"), -1))
	var text := str(d.get("text", "")).strip_edges().left(Config.MAX_TEXT)
	var l = session.market.listing(lid)
	if l.is_empty() or l.status != "available" or text == "":
		session.notify_player(pid, "Pick a listing and type a message.")
		return
	if int(l.get("owner", 0)) > 0 and int(l.owner) != pid:
		session.notify_player(pid, "This is another player's private buyer conversation.")
		return
	if pending_by.has(pid):
		session.notify_player(pid, "Wait for the seller to answer your last message first.")
		return
	var hist: Array = []
	for m in p.chats.get(lid, []):
		if m.speaker != "system" and not m.get("pending", false):
			hist.append({"speaker": m.speaker, "text": m.text})
	say(p, lid, p.name, text)
	say(p, lid, "system", "%s is typing..." % l.seller, true)
	serial += 1
	pending[serial] = {"pid": pid, "lid": lid, "match": state.match_id, "text": text}
	pending_by[pid] = serial
	var context: Dictionary = l.duplicate()
	context["seller_floor"] = int(session.market.floors[lid])
	context["prior_counter"] = int(p.counters.get(lid, 0))
	context["sale_side"] = int(l.get("owner", 0)) == pid
	context["now"] = Trade.stamp(session.clock())
	context["meeting_options"] = session.market.contact_options(l)
	context["meeting_proposal"] = p.meeting_proposals.get(lid, {})
	context["agreed_price"] = int(p.offers.get(lid, 0))
	context["availability"] = Trade.profile(l.seller, l.location).note
	pending[serial]["options"] = context.meeting_options
	session.seller.submit(serial, context, hist, text)


func receive_reply(req: int, ok: bool, decision: Dictionary, error: String) -> void:
	if not pending.has(req):
		return
	var job: Dictionary = pending[req]
	pending.erase(req)
	pending_by.erase(job.pid)
	if job.match != state.match_id or state.phase != "playing" or not state.players.has(job.pid):
		return
	var p: Dictionary = state.players[job.pid]
	if p.ready:
		return
	var l = session.market.listing(job.lid)
	if l.is_empty():
		return
	var arr: Array = p.chats.get(job.lid, [])
	for i in range(arr.size() - 1, -1, -1):
		if arr[i].get("pending", false):
			arr.remove_at(i)
	if l.status != "available":
		say(p, job.lid, "system", "This listing is no longer available.")
		session.mark_changed()
		return
	var counter := int(p.counters.get(job.lid, 0))
	var offline_context: Dictionary = l.duplicate(true)
	offline_context["sale_side"] = int(l.get("owner", 0)) == int(job.pid)
	offline_context["meeting_options"] = job.get("options", [])
	offline_context["meeting_proposal"] = p.meeting_proposals.get(l.id, {})
	var fallback: Dictionary = session.seller.offline_decision(offline_context, job.text, counter)
	if not ok:
		if error != "":
			say(p, job.lid, "system", "Seller AI error: %s. Using offline reply." % error)
		decision = fallback
	var intent: String = str(decision.get("intent", "none"))
	var amount: int = int(decision.get("amount", 0))
	var action: String = str(decision.get("seller_action", "none"))
	var proposal: int = int(decision.get("counter_amount", 0))
	var line: String = str(decision.get("text", ""))
	var query: String = str(job.text).to_lower()
	var selling: bool = int(l.get("owner", 0)) == int(job.pid)
	var floor_price: int = 1 if selling else int(session.market.floors[job.lid])
	var ceiling: int = int(l.buyer_max) if selling else int(l.price)
	# Specific safeguards for questions and unsupported prices; semantic interpretation belongs to the seller model.
	var question_only := ("fit" in query or "compat" in query or "socket" in query or "asking price" in query or "still available" in query) and "?" in query
	if question_only:
		intent = "none"
	if intent == "offer" and not amount_in_message(query, amount, int(l.price)):
		intent = "none"
	if intent == "accept_counter":
		if counter <= 0:
			intent = "offer" if amount_in_message(query, amount, int(l.price)) else "none"
		else:
			amount = counter
	# A logistics reply can reaffirm an already accepted price without a new monetary commitment.
	if p.offers.has(job.lid) and amount == int(p.offers[job.lid]) and action == "accept" and str(decision.get("meeting_action", "none")) != "none":
		intent = "none"
		action = "none"
	if intent in ["offer", "accept_counter"] and action == "accept" and amount >= floor_price and amount <= ceiling and not ("confirm" in line.to_lower() or "if you" in line.to_lower()):
		p.offers[job.lid] = amount
		p.counters.erase(job.lid)
		session.notify_player(job.pid, "Contact agreed to $%d. Pickup is not reserved; first arrival wins." % amount)
	elif action == "counter" and proposal >= floor_price and proposal <= ceiling:
		p.counters[job.lid] = proposal
	elif not ok and intent == "offer" and amount < floor_price:
		var character := Characters.for_listing(l)
		var mix: float = character.counter_bias
		proposal = clampi(int(round(floor_price + (l.price - floor_price) * mix)), floor_price, l.price)
		p.counters[job.lid] = proposal
		line = Characters.line(character.price_counter, proposal)
	elif action in ["accept", "counter"]:
		# Never present an invalid or ungrounded proposed transaction as confirmed.
		say(p, job.lid, "system", "Seller response could not be validated; please clarify your offer.")
		line = "Could you clarify what you have in mind?"
	say(p, job.lid, l.seller, ("" if ok else "[offline] ") + line)
	apply_meeting(p, l, decision, job.get("options", []))
	session.mark_changed()


func apply_meeting(p: Dictionary, l: Dictionary, d: Dictionary, offered: Array) -> void:
	var action := str(d.get("meeting_action", "none"))
	var id := str(d.get("meeting_id", ""))
	if action == "none" or id == "":
		return
	var proposed: Dictionary = p.meeting_proposals.get(l.id, {})
	var chosen := Trade.find_option(offered, id)
	if chosen.is_empty() and str(proposed.get("id", "")) == id:
		chosen = proposed.duplicate(true)
	if chosen.is_empty() or float(chosen.end) <= session.clock():
		return
	if action == "propose":
		p.meeting_proposals[l.id] = chosen
	elif action == "accept" and p.offers.has(l.id):
		if session.market.meeting_conflict(str(l.seller), int(l.id), chosen):
			say(p, l.id, "system", "They have another meeting at that time now. Ask for a different place or time.")
			return
		p.meetings[l.id] = chosen
		p.meeting_proposals.erase(l.id)
		say(p, l.id, "system", "Meeting confirmed: " + chosen.label + ". Park and walk up to complete the handoff. Not reserved.")


func amount_in_message(text: String, amount: int, ask: int) -> bool:
	if amount <= 0:
		return false
	if amount == ask and ("asking" in text or "full price" in text):
		return true
	# A model-classified purchase commitment without an amount naturally means the listed price.
	if amount == ask and ("take it" in text or "buy it" in text or "purchase it" in text) and not ("not " in text or "won't " in text or "don't " in text or "?" in text.split(",")[0]):
		return true
	var rx := RegEx.create_from_string("(?<![0-9])[0-9]+(?![0-9])")
	for m in rx.search_all(text):
		if int(m.get_string()) == amount:
			return true
	if amount > 999:
		return false
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
