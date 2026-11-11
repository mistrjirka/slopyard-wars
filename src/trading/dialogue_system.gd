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
	# Stable IDs keep unread tracking correct when the capped history drops old messages.
	p["chat_serial"] = int(p.get("chat_serial", 0)) + 1
	var m := {"speaker": speaker, "text": text, "id": p.chat_serial}
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
	pending[serial] = {"pid": pid, "lid": lid, "match": state.match_id, "text": text,
		"deadline_ms": Time.get_ticks_msec() + int(session.seller.TIMEOUT * 1000.0)}
	var delay := Characters.for_listing(l).reply_delay_seconds
	pending[serial]["deliver_at"] = session.clock() if state.get("assembly_test", false) else session.clock() + session.rng.randf_range(delay.x, delay.y) * Config.RATE * delay_scale
	pending_by[pid] = serial
	var context: Dictionary = l.duplicate()
	context["seller_floor"] = int(session.market.floors[lid])
	context["prior_counter"] = int(p.counters.get(lid, 0))
	context["sale_side"] = int(l.get("owner", 0)) == pid
	context["now"] = Trade.stamp(session.clock())
	context["meeting_options"] = session.market.contact_options(l)
	context["meeting_proposal"] = p.meeting_proposals.get(lid, {})
	context["confirmed_meeting"] = p.meetings.get(lid, {})
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
	pending[serial]["context"] = context
	pending[serial]["history"] = hist
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
	offline_context["agreed_price"] = int(p.offers.get(l.id, 0))
	var fallback: Dictionary = session.seller.offline_decision(offline_context, job.text, counter)
	if not ok:
		if error != "":
			say(p, job.lid, "system", "Offline reply used.")
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
	# A rejected financial effect does not establish that ordinary conversation was unclear.
	# Give the producer one bounded correction with the original message/history before
	# replacing a potentially false promise. No relationship or agreement has mutated yet.
	var reaffirming: bool = p.offers.has(job.lid) and amount == int(p.offers[job.lid]) and action == "accept" and str(decision.get("meeting_action", "none")) != "none"
	var invalid_price: bool = action == "accept" and not reaffirming and (intent not in ["offer", "accept_counter"] or amount < floor_price or amount > ceiling or "confirm" in line.to_lower() or "if you" in line.to_lower())
	invalid_price = invalid_price or (action == "counter" and (proposal < floor_price or proposal > ceiling))
	var repair_time := (int(job.get("deadline_ms", 0)) - Time.get_ticks_msec()) / 1000.0
	if ok and invalid_price and not job.get("repair_attempted", false) and job.has("context") and repair_time > 1.0 and session.seller.is_live() and str(decision.get("contact_action", "none")) == "none":
		job["repair_attempted"] = true
		job.erase("response")
		pending[req] = job
		pending_by[job.pid] = req
		say(p, job.lid, "system", "%s is typing..." % l.seller, true)
		var context: Dictionary = job.context.duplicate(true)
		context["now"] = Trade.stamp(session.clock())
		context["meeting_options"] = session.market.contact_options(l)
		pending[req]["options"] = context.meeting_options
		session.seller.submit(req, context, job.history, job.text, "The proposed price action is not supported by a grounded human commitment or is outside your permitted price range. Re-evaluate what the human is replying to. For ordinary conversation set intent=none and seller_action=none, and answer their actual remark. Never claim an unrecorded deal.", repair_time)
		session.mark_changed()
		return
	# A logistics reply can reaffirm an already accepted price without a new monetary commitment.
	var social_offer := amount if intent == "offer" else (int(fallback.amount) if fallback.intent == "offer" else 0)
	var relationship := Relationships.assess(p, l, job.text, social_offer, str(decision.get("contact_action", "none")))
	if relationship.blocked:
		_end_relationship(p, l)
		var character := Characters.for_listing(l)
		var authored_refusal: String = str(character.refusal_by_reason.get(relationship.reason, character.refusal_line))
		var refusal: String = line if ok and decision.get("contact_action", "none") == "block" and action == "none" else authored_refusal
		say(p, job.lid, l.seller, public_reply(refusal, l, p, job.lid))
		say(p, job.lid, "system", "Blocked for this run. Their listings and meetings are unavailable.")
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
		if action in ["accept", "counter"] or intent in ["offer", "accept_counter"] or str(decision.get("meeting_action", "none")) != "none":
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
		session.notify_player(job.pid, "Agreed $%d. First arrival wins." % amount)
	elif action == "counter" and proposal >= floor_price and proposal <= ceiling:
		p.counters[job.lid] = proposal
	elif not ok and intent == "offer" and amount < floor_price:
		var character := Characters.for_listing(l)
		var mix: float = character.counter_bias
		proposal = clampi(int(round(floor_price + (l.price - floor_price) * mix)), floor_price, l.price)
		p.counters[job.lid] = proposal
		line = Characters.line(character.price_counter, proposal)
	elif action in ["accept", "counter"]:
		# Correction exhausted: state the missing agreement, not that the human's chat was unclear.
		if int(p.offers.get(job.lid, 0)) > 0:
			line = "Our agreed price is still $%d." % int(p.offers[job.lid])
		else:
			line = "We haven't agreed a price. If you want the part, send the price you're offering." if not selling else "We haven't agreed a price. What price would you sell it for?"
		decision = decision.duplicate()
		decision["meeting_action"] = "none"
	# Validate logistics BEFORE showing any NPC promise. The same shared commit path
	# serves typed dialogue and exact slot clicks; its recovery replaces rejected promises.
	var meeting_result := apply_meeting(p, l, decision, job.get("options", []))
	if not str(meeting_result.get("recovery", "")).is_empty():
		line = str(meeting_result.recovery)
	line = public_reply(line, l, p, job.lid)
	say(p, job.lid, l.seller, ("" if ok else "[offline] ") + line)
	if str(meeting_result.get("confirmation", "")) != "":
		say(p, job.lid, "system", str(meeting_result.confirmation))
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


## Both model decisions and exact quick choices resolve host-owned slots here.
func _meeting_choice(p: Dictionary, l: Dictionary, id: String, offered: Array = []) -> Dictionary:
	if state.phase != "playing" or l.is_empty() or l.status != "available" or p.ready or Relationships.blocked(p, l):
		return {}
	var pid := 0
	for key in state.players:
		if is_same(state.players[key], p):
			pid = int(key)
			break
	if pid == 0 or (int(l.get("owner", 0)) > 0 and int(l.owner) != pid):
		return {}
	if int(l.get("owner", 0)) == pid and not l.get("buyer_contacted", true):
		return {}
	var chosen := Trade.find_option(session.market.contact_options(l), id)
	# These are the host's canonical snapshot sent with an asynchronous model job,
	# never client-supplied slot data. Revalidate the lead time after reply delay.
	if chosen.is_empty():
		chosen = Trade.find_option(offered, id)
	var proposed: Dictionary = p.meeting_proposals.get(l.id, {})
	if chosen.is_empty() and str(proposed.get("id", "")) == id:
		chosen = proposed.duplicate(true)
	var confirmed: Dictionary = p.meetings.get(l.id, {})
	var reaffirming: bool = str(confirmed.get("id", "")) == id and float(confirmed.get("end", 0)) > session.clock()
	if reaffirming:
		chosen = confirmed.duplicate(true)
	elif not Trade.can_agree(chosen, session.clock()):
		return {}
	if session.market.meeting_conflict(str(l.seller), int(l.id), chosen):
		return {}
	return chosen


func choose_meeting(pid: int, p: Dictionary, d: Dictionary) -> void:
	if str(d.get("match_id", "")) != str(state.match_id) or pending_by.has(pid):
		session.notify_player(pid, "Wait for the current conversation to finish, then choose a time.")
		return
	var l: Dictionary = session.market.listing(int(session.number(d.get("listing_id"), -1)))
	var id := str(d.get("meeting_id", ""))
	var chosen := _meeting_choice(p, l, id)
	if chosen.is_empty() or int(p.offers.get(l.get("id", -1), 0)) <= 0:
		session.notify_player(pid, "That meeting choice is no longer available. Check the current times or agree a price first.")
		return
	# An exact slot click is consent to logistics, never a new price or reservation.
	say(p, l.id, p.name, "Let's meet: " + str(chosen.label) + ".")
	var result := apply_meeting(p, l, {"meeting_action": "accept", "meeting_id": id}, [])
	if str(result.get("confirmation", "")) != "":
		say(p, l.id, "system", str(result.confirmation))
	elif str(result.get("recovery", "")) != "":
		say(p, l.id, "system", str(result.recovery))


func apply_meeting(p: Dictionary, l: Dictionary, d: Dictionary, offered: Array) -> Dictionary:
	var action := str(d.get("meeting_action", "none"))
	if action not in ["propose", "accept"]:
		return {}
	var chosen := _meeting_choice(p, l, str(d.get("meeting_id", "")), offered)
	if chosen.is_empty():
		p.meeting_proposals.erase(l.id)
		return {"recovery": "That time is no longer available. Let's choose a current time, at least an hour from now."}
	if action == "propose":
		p.meeting_proposals[l.id] = chosen
		# The host owns whether this is tentative, regardless of the model's prose.
		var proposal_line := "Could you meet " + str(chosen.label) + "?"
		if int(p.offers.get(l.id, 0)) <= 0:
			proposal_line += " We still need to agree a price before confirming."
		return {"recovery": proposal_line}
	if int(p.offers.get(l.id, 0)) <= 0:
		# Keep the feasible proposal for recovery, but never imply an accepted appointment.
		p.meeting_proposals[l.id] = chosen
		return {"recovery": "Before we confirm a meeting, we need to agree a price. Send the price you'd agree to."}
	return _commit_meeting(p, l, chosen)


func _commit_meeting(p: Dictionary, l: Dictionary, chosen: Dictionary) -> Dictionary:
	p.meetings[l.id] = chosen
	p.meeting_proposals.erase(l.id)
	return {"confirmation": "Meeting confirmed: " + chosen.label + ". Park and walk up to complete the handoff. Not reserved."}


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
