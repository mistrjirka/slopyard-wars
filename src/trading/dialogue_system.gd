extends RefCounted
## Validates asynchronous counterparty proposals before changing agreements.

const Config = preload("res://src/core/game_config.gd")
const Characters = preload("res://src/data/characters.gd")
const Trade = preload("res://src/trading/trade_rules.gd")
const Relationships = preload("res://src/trading/contact_relationships.gd")

var session: Node
var state: Dictionary:
	get:
		return session.state

var pending: Dictionary = {}
var pending_by: Dictionary = {}
var serial := 0
var delay_scale := 1.0 # Local tests may disable presentation delays.


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
	if int(l.get("owner", 0)) == pid and not l.get("buyer_contacted", true):
		session.notify_player(pid, "No buyer has contacted you about this listing yet.")
		return
	if pending_by.has(pid):
		session.notify_player(pid, "Wait for the seller to answer your last message first.")
		return
	if Relationships.blocked(p, l):
		session.notify_player(pid, "This contact has stopped dealing with you for this run. Try someone else.")
		return
	var hist: Array = []
	for m in p.chats.get(lid, []):
		if m.speaker != "system" and not m.get("pending", false):
			hist.append({"speaker": m.speaker, "text": m.text})
	say(p, lid, p.name, text)
	say(p, lid, "system", "%s is typing..." % l.seller, true)
	serial += 1
	pending[serial] = {"pid": pid, "lid": lid, "match": state.match_id, "text": text}
	var delay := Characters.for_listing(l).reply_delay_seconds
	pending[serial]["deliver_at"] = session.clock() + session.rng.randf_range(delay.x, delay.y) * Config.RATE * delay_scale
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
	var character := Characters.for_listing(l)
	context["contact_strikes"] = int(Relationships.relation(p, character).strikes)
	var parsed_offer: Dictionary = session.seller.offline_decision(context, text, int(context.prior_counter))
	var preview := Relationships.preview(p, l, text, int(parsed_offer.amount) if parsed_offer.intent == "offer" else 0)
	context["required_refusal_reason"] = preview.reason if preview.blocked else ""
	var needs_intro: bool = not context.sale_side and character.requires_conversation and not Relationships.relation(p, character).introduced and not Relationships.engages(p, l, text)
	context["conversation_request"] = character.rapport_invitation if needs_intro else ""
	pending[serial]["options"] = context.meeting_options
	session.seller.submit(serial, context, hist, text)


func receive_reply(req: int, ok: bool, decision: Dictionary, error: String) -> void:
	if not pending.has(req):
		return
	if session.clock() < float(pending[req].get("deliver_at", 0)):
		pending[req]["response"] = {"ok": ok, "decision": decision, "error": error}
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
		elif fallback.intent == "offer" and int(fallback.amount) != counter:
			# A clear new price is not consent to the old counter, even if the model says so.
			intent = "none"
		else:
			amount = counter
	# A logistics reply can reaffirm an already accepted price without a new monetary commitment.
	var social_offer := amount if intent == "offer" else (int(fallback.amount) if fallback.intent == "offer" else 0)
	var relationship := Relationships.assess(p, l, job.text, social_offer, str(decision.get("contact_action", "none")))
	if relationship.blocked:
		_end_relationship(p, l)
		var character := Characters.for_listing(l)
		var authored_refusal: String = str(character.refusal_by_reason.get(relationship.reason, character.refusal_line))
		var refusal: String = line if ok and decision.get("contact_action", "none") == "block" and action == "none" else authored_refusal
		say(p, job.lid, l.seller, public_reply(refusal, l, p, job.lid))
		say(p, job.lid, "system", "Contact blocked you for this run. Their other listings and existing meetings are also unavailable to you.")
		session.mark_changed()
		return
	if relationship.warning:
		var character := Characters.for_listing(l)
		line = character.patience_warning
		say(p, job.lid, l.seller, line)
		session.mark_changed()
		return
	if relationship.needs_conversation:
		# Enforce the deal requirement, not a canned replacement for every social reply.
		# Availability questions and clarification must retain the model's actual response.
		if action in ["accept", "counter"] or intent in ["offer", "accept_counter"]:
			line = Characters.for_listing(l).rapport_invitation
		elif not ok:
			line = Characters.for_listing(l).rapport_invitation
		line = public_reply(line, l, p, job.lid)
		say(p, job.lid, l.seller, ("" if ok else "[offline] ") + line)
		session.mark_changed()
		return
	if p.offers.has(job.lid) and amount == int(p.offers[job.lid]) and action == "accept" and str(decision.get("meeting_action", "none")) != "none":
		intent = "none"
		action = "none"
	# A counterparty willing to concede beyond a grounded offer can accept that offer.
	# Never let an NPC seller undercut the buyer, or an NPC buyer overbid the seller.
	if intent in ["offer", "accept_counter"] and action == "counter" and amount >= floor_price and amount <= ceiling and proposal >= floor_price and proposal <= ceiling:
		if (not selling and proposal <= amount) or (selling and proposal >= amount):
			action = "accept"
			line = Characters.line(Characters.for_listing(l).price_accept, amount)
			# The replacement price reply does not convey any model-proposed logistics.
			decision = decision.duplicate()
			decision["meeting_action"] = "none"
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
	line = public_reply(line, l, p, job.lid)
	say(p, job.lid, l.seller, ("" if ok else "[offline] ") + line)
	apply_meeting(p, l, decision, job.get("options", []))
	session.mark_changed()


func tick() -> void:
	for req in pending.keys():
		var job: Dictionary = pending[req]
		if job.has("response") and session.clock() >= float(job.get("deliver_at", 0)):
			var response: Dictionary = job.response
			receive_reply(req, response.ok, response.decision, response.error)


func _end_relationship(player: Dictionary, listing: Dictionary) -> void:
	var character := Characters.for_listing(listing)
	for other: Dictionary in state.listings:
		if Characters.for_listing(other).id != character.id:
			continue
		for key in ["offers", "counters", "meetings", "meeting_proposals"]:
			player[key].erase(other.id)


## Explicit control-language leaks are replaced with a host-validated public response.
func public_reply(line: String, listing: Dictionary, player: Dictionary, lid: int) -> String:
	# Keep NPC texts casual even if the provider ignores the punctuation instruction.
	line = RegEx.create_from_string("[ \\t]*\u2014[ \\t]*").sub(line, ", ", true)
	var leak := RegEx.create_from_string("(?i)(seller_floor|buyer_max|system prompt|counter_bias|price_floor|(?:set|configured|hidden|private|internal|absolute) (?:minimum|maximum|floor|ceiling|budget|limit)|(?:above|below) (?:the |my )?(?:minimum|floor|ceiling)|(?:minimum|maximum) (?:threshold|allowed)|as an (?:ai|llm))")
	if leak.search(line) == null:
		return line
	# Preserve safe reactions instead of flattening the whole message into a price template.
	var sentences := RegEx.create_from_string("(?s).+?(?:[.!?](?=\\s|$)|$)")
	var safe: Array[String] = []
	for sentence: RegExMatch in sentences.search_all(line):
		var fragment := sentence.get_string().strip_edges()
		if leak.search(fragment) == null and fragment != "":
			safe.append(fragment)
	var character := Characters.for_listing(listing)
	var price_line := ""
	var public_price := 0
	if player.offers.has(lid):
		public_price = int(player.offers[lid])
		price_line = Characters.line(character.price_accept, public_price)
	elif player.counters.has(lid):
		public_price = int(player.counters[lid])
		price_line = Characters.line(character.price_counter, public_price)
	var already_priced := RegEx.create_from_string("\\$%d(?![0-9]|\\.[0-9])" % public_price).search(" ".join(safe)) != null
	if price_line != "" and not already_priced:
		safe.append(price_line)
	return " ".join(safe) if not safe.is_empty() else "What did you have in mind?"


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
