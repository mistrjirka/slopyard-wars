extends RefCounted
const Characters = preload("res://src/data/characters.gd")
const Catalog = preload("res://src/data/catalog.gd")
const Stats = preload("res://src/data/hardware_stats.gd")
const Relationships = preload("res://src/trading/contact_relationships.gd")
const Snapshot = preload("res://src/network/snapshot.gd")
var game: Node
var check: Callable


func run(session: Node, assertion: Callable) -> void:
	game = session
	check = assertion
	for character: Resource in Characters.ALL:
		check.call(character.backstory.length() > 300 and character.conversation_hooks.size() >= 3, "Character has a detailed biography and three conversation hooks")
		check.call(not character.texting_style.is_empty() and not character.current_situation.is_empty() and character.dialogue_examples.size() >= 2, "Character has an authored texting voice, current activity and dialogue examples")
		check.call(character.reply_delay_seconds.x >= 2 and character.reply_delay_seconds.y >= character.reply_delay_seconds.x, "Reply pace has a usable authored range")
	var player := fresh()
	var listing: Dictionary = game.state.listings.filter(func(item): return not Characters.for_listing(item).requires_conversation)[0]
	var body: Dictionary = game.seller._body(listing, [], "Tell me about yourself")
	check.call(body.messages[0].content.contains(Characters.for_listing(listing).backstory) and body.messages[0].content.contains("silent decision constraints"), "LLM receives biography and private-negotiation instructions")
	var character: Resource = Characters.for_listing(listing)
	check.call(body.messages[0].content.contains(character.texting_style) and body.messages[0].content.contains(character.current_situation) and body.messages[0].content.contains(character.dialogue_examples[0]), "Provider receives the authored voice and situational context")
	check.call(not body.messages[0].content.contains("Used-price guide $") and Catalog.spec_text(listing).contains("Used-price guide $"), "NPC context excludes the UI's price-guide commentary while the marketplace retains it")
	var chip: Dictionary = Catalog.build_listing(game.rng, Catalog.PARTS.filter(func(part): return str(part.model_id) == "luckycore_l9_14900l")[0], 999)
	check.call(Catalog.spec_text(chip, false).contains("RELIABILITY WARNING") and Catalog.spec_text(chip, false).contains("Socket"), "Conversational fact context still discloses known defects and compatibility")
	game.dialogue.serial += 1
	var req: int = game.dialogue.serial
	game.dialogue.pending[req] = {"pid": 1, "lid": listing.id, "match": game.state.match_id, "text": "Hello", "deliver_at": game.clock() + 5, "options": []}
	game.dialogue.pending_by[1] = req
	game.dialogue.say(player, listing.id, "system", "Typing...", true)
	game.dialogue.receive_reply(req, true, {"intent": "none", "seller_action": "none", "text": "Hello from the garage."}, "")
	check.call(game.dialogue.pending.has(req) and player.chats[listing.id].size() == 1, "Fast provider result remains hidden until the delivery time")
	game.advance_time(4)
	check.call(game.dialogue.pending.has(req), "Tick before delivery time does not release the response")
	game.advance_time(1)
	check.call(not game.dialogue.pending.has(req) and player.chats[listing.id][-1].text == "Hello from the garage.", "Due response is delivered and the pending state cleared")
	game.dialogue.tick()
	check.call(player.chats[listing.id].size() == 1, "Reply is not duplicated by later ticks")
	player.offers[listing.id] = 25
	var safe: String = game.dialogue.public_reply("That is still well above the set minimum of $12.", listing, player, listing.id)
	check.call(not safe.contains("minimum") and not safe.contains("12") and safe.contains("25"), "Threshold leak is replaced with the actual agreed public price")
	check.call(game.dialogue.public_reply("My cat owns the good chair.", listing, player, listing.id) == "My cat owns the good chair.", "Ordinary character dialogue is preserved")
	safe = game.dialogue.public_reply("Fair point about the risk. That is above my minimum of $12.", listing, player, listing.id)
	check.call(safe.begins_with("Fair point about the risk.") and safe.contains("25") and not safe.contains("12"), "Privacy repair keeps the character's safe reaction and repairs only the leak")
	safe = game.dialogue.public_reply("I'll take $25. That is above my minimum of $12.", listing, player, listing.id)
	check.call(safe == "I'll take $25.", "Privacy repair does not add a second price template to an already clear public offer")
	safe = game.dialogue.public_reply("I measured 3.5 watts. My internal limit is $12.", listing, player, listing.id)
	check.call(safe.begins_with("I measured 3.5 watts.") and not safe.contains("12"), "Filtering preserves decimals inside safe sentences")
	player = fresh()
	game.market.interest_delay_scale = 1
	var item: Dictionary = player.inventory[0]
	game.act("post_sale", {"item_id": item.id, "price": Stats.reference_price(item)})
	listing = game.state.listings[-1]
	check.call(not listing.buyer_contacted and not player.chats.has(listing.id) and game.market.sale_interest.has(listing.id), "Fairly priced sale waits before the first buyer message")
	game.act("chat", {"listing_id": listing.id, "text": "Hello"})
	check.call(not player.chats.has(listing.id), "Cannot message a prospective buyer before they contact the seller")
	game.advance_time(19)
	check.call(listing.buyer_contacted and player.chats[listing.id].size() == 1, "Fairly priced listing gets its delayed buyer opening")
	game.market.deliver_interest()
	check.call(player.chats[listing.id].size() == 1, "Buyer opening is delivered once")
	game.act("cancel_sale", {"listing_id": listing.id})
	game.act("post_sale", {"item_id": item.id, "price": 5000})
	listing = game.state.listings[-1]
	check.call(not listing.buyer_contacted and not game.market.sale_interest.has(listing.id), "Wildly overpriced listing attracts no buyer")
	game.advance_time(100)
	check.call(not player.chats.has(listing.id), "Time passing does not fabricate interest in an outrageous ask")
	game.act("cancel_sale", {"listing_id": listing.id})
	game.act("post_sale", {"item_id": item.id, "price": Stats.reference_price(item)})
	listing = game.state.listings[-1]
	game.act("cancel_sale", {"listing_id": listing.id})
	game.advance_time(19)
	check.call(not player.chats.has(listing.id) and not game.market.sale_interest.has(listing.id), "Cancelled listings cannot send a late buyer notification")
	game.market.interest_delay_scale = 0
	_relationships()
	_clarifications()
	_bargaining_voice()
	_counter_direction()
	_contextual_blocks()


func _contextual_blocks() -> void:
	var player := fresh()
	var listing: Dictionary = game.state.listings[0]
	listing.character_id = "bea"
	listing.seller = Characters.find("bea").display_name
	listing.price = 328
	game.market.floors[listing.id] = 280
	var other: Dictionary = game.state.listings[1]
	other.character_id = "bea"
	other.seller = listing.seller
	player.offers[other.id] = 300
	player.counters[other.id] = 310
	player.meeting_proposals[other.id] = {"id": "old_proposal"}
	player.meetings[other.id] = {"id": "old_meeting"}
	_deliver(player, listing, "I'll pay $100", {"intent": "offer", "amount": 100, "seller_action": "none", "contact_action": "warn", "text": "Please stop lowballing."})
	check.call(Relationships.relation(player, Characters.find("bea")).strikes == 1, "The first lowball is a single offence without requiring confirmation")
	check.call(Relationships.blocked(player, listing) and Relationships.blocked(player, other), "A single extreme lowball blocks the character across listings")
	check.call(player.offers.is_empty() and player.counters.is_empty() and player.meetings.is_empty() and player.meeting_proposals.is_empty(), "Blocking takes precedence over all price and meeting decisions and cancels existing deals")
	check.call(player.chats[listing.id][-2].text == Characters.find("bea").refusal_by_reason.lowball, "A forced lowball block uses the authored lowball comeback rather than a generic refusal")
	game.act("chat", {"listing_id": other.id, "text": "Hello again"})
	check.call(not game.dialogue.pending_by.has(1) and not player.chats.has(other.id), "Blocked contact cannot receive messages through a different listing")
	player = fresh()
	listing = game.state.listings[0]
	listing.character_id = "bea"
	var farewell := "That's enough. I'm done dealing with you."
	_deliver(player, listing, "Stop wasting my time", {"intent": "none", "seller_action": "none", "contact_action": "block", "text": farewell})
	check.call(Relationships.blocked(player, listing) and player.chats[listing.id][-2].text == farewell, "A first-turn contextual refusal ends trading and preserves the model's farewell")
	player = fresh()
	listing = game.state.listings[0]
	listing.character_id = "bea"
	listing.price = 328
	for message in ["How is your mum?", "Does it run at 100 MHz?", "Too expensive given the failure risk", "What?"]:
		var assessment := Relationships.assess(player, listing, message, 0)
		check.call(not assessment.warning and not assessment.blocked, "Ordinary family, technical and bargaining questions do not automatically provoke a block")
	check.call(Relationships.assess(player, listing, "100", 0).warning, "A bare repeated price is recognized for offline lowball enforcement")
	for message in ["I dont care about your snail", "I don't care about your snail", "Nobody cares about your snail!"]:
		player = fresh()
		listing = game.state.listings[0]
		listing.character_id = "gus"
		_deliver(player, listing, message, {"intent": "none", "seller_action": "none", "text": "Fair enough, no hard feelings."})
		check.call(Relationships.blocked(player, listing), "Gus's authored boundary blocks a dismissive snail comment even if the model is too forgiving")
		check.call(player.chats[listing.id][-2].text.contains("Sir Buffering"), "Gus defends his snail even when the provider failed to write a refusal")
	player = fresh()
	listing = game.state.listings[0]
	listing.character_id = "gus"
	for message in ["I don't understand snail racing", "Could we talk about the CPU please?", "What is Sir Buffering?"]:
		check.call(not Relationships.assess(player, listing, message, 0).blocked, "Gus tolerates polite redirection and genuine confusion")
	player = fresh()
	listing = game.state.listings[0]
	listing.character_id = "bea"
	listing.price = 328
	_deliver(player, listing, "I'll pay $100", {"intent": "none", "seller_action": "none", "text": "Please confirm your offer."})
	check.call(Relationships.blocked(player, listing), "An explicit lowball blocks immediately even when the model asks for confirmation")
	for character: Resource in Characters.ALL:
		check.call(character.refusal_by_reason.has_all(["hobby", "lowball", "conduct"]), "Each character has reason-specific fallback refusals")
		check.call(not character.sensitive_topics.is_empty() and not character.personal_boundaries.is_empty(), "Every character has authored personal boundaries")
		player = fresh()
		listing = game.state.listings[0]
		listing.character_id = str(character.id)
		var topic: String = character.sensitive_topics[0]
		check.call(not Relationships.assess(player, listing, "Could you tell me about your " + topic + "?", 0).blocked, "Interest in a hobby remains welcome")
		_deliver(player, listing, "I don't care about your " + topic, {"intent": "none", "seller_action": "none", "text": "No hard feelings."})
		check.call(Relationships.blocked(player, listing), "Dismissing an authored hobby blocks immediately across the whole cast")
	player = fresh()
	listing = game.state.listings[0]
	listing.character_id = "gus"
	var preview := Relationships.preview(player, listing, "I don't care about your snail", 0)
	check.call(preview.blocked and preview.reason == "hobby" and player.contact_relations.is_empty(), "Refusal preview tells generation the reason without mutating or double-counting relationship state")
	var novel := "That slime-covered athlete of yours is a monument to wasted afternoons."
	check.call(not Relationships.dismisses_interest(novel, Characters.find("gus").sensitive_topics), "Unfamiliar phrasing genuinely bypasses the literal fallback matcher")
	var reply := "He's got more grace in one eyestalk than you've shown here. Find another seller."
	_deliver(player, listing, novel, {"intent": "none", "seller_action": "none", "contact_action": "block", "text": reply})
	check.call(Relationships.blocked(player, listing) and player.chats[listing.id][-2].text == reply, "Semantic model refusal works without any keyword match and retains its contextual comeback")


func _counter_direction() -> void:
	var player := fresh()
	var listing: Dictionary = game.state.listings[0]
	listing.character_id = "bella"
	listing.seller = Characters.find("bella").display_name
	listing.price = 1000
	game.market.floors[listing.id] = 800
	_deliver(player, listing, "What about 900? For the 100 I save I will buy fire extinguisher", {"intent": "offer", "amount": 900, "seller_action": "counter", "counter_amount": 850, "text": "Let me counter at eight fifty."})
	check.call(player.offers.get(listing.id) == 900 and not player.counters.has(listing.id), "Seller accepts the grounded $900 offer instead of undercutting it at $850")
	check.call(player.chats[listing.id][-1].text.contains("900") and not player.chats[listing.id][-1].text.contains("fifty"), "Corrected acceptance text matches the host-approved price")
	player.offers.clear()
	_deliver(player, listing, "What about 700", {"intent": "offer", "amount": 700, "seller_action": "counter", "counter_amount": 850, "text": "I can do $850."})
	check.call(not player.offers.has(listing.id) and player.counters.get(listing.id) == 850, "Seller countering above a below-floor offer remains valid")
	player.counters.clear()
	_deliver(player, listing, "What about 900", {"intent": "offer", "amount": 900, "seller_action": "counter", "counter_amount": 750, "text": "How about $750?"})
	check.call(player.offers.is_empty() and player.counters.is_empty(), "An out-of-bounds counter is rejected rather than treated as a valid willingness to deal")
	listing.owner = 1
	listing.buyer_max = 1100
	_deliver(player, listing, "Could you do $900?", {"intent": "offer", "amount": 900, "seller_action": "counter", "counter_amount": 850, "text": "Would you take $850?"})
	check.call(player.offers.is_empty() and player.counters.get(listing.id) == 850, "NPC buyer can legitimately counter below the player's asking price")
	player.counters.clear()
	_deliver(player, listing, "Could you do $900?", {"intent": "offer", "amount": 900, "seller_action": "counter", "counter_amount": 950, "text": "I'll offer $950 instead."})
	check.call(player.offers.get(listing.id) == 900 and not player.counters.has(listing.id), "NPC buyer accepts the grounded asking price instead of overbidding it")
	player.offers.clear()
	player.counters[listing.id] = 800
	_deliver(player, listing, "Could you do $900?", {"intent": "accept_counter", "amount": 800, "seller_action": "accept", "text": "Eight hundred works. Deal."})
	check.call(not player.offers.has(listing.id) and player.counters.get(listing.id) == 800, "An explicit new $900 ask cannot be misread as accepting the old $800 counter")
	check.call(not player.chats[listing.id][-1].text.contains("Eight hundred"), "Rejected acceptance does not display the model's false agreement")
	_deliver(player, listing, "Yes, deal", {"intent": "accept_counter", "amount": 800, "seller_action": "accept", "text": "$800 works."})
	check.call(player.offers.get(listing.id) == 800, "An actual yes still accepts the previous counter")


func _bargaining_voice() -> void:
	var player := fresh()
	var listing: Dictionary = game.state.listings[0]
	listing.character_id = "bea"
	listing.seller = Characters.find("bea").display_name
	listing.price = 406
	game.market.floors[listing.id] = 365
	var reaction := "You're not wrong about the risk. I'd take $385."
	_deliver(player, listing, "Can you go lower because it might die?", {"intent": "none", "seller_action": "counter", "counter_amount": 385, "text": reaction})
	check.call(player.counters.get(listing.id) == 385 and player.chats[listing.id][-1].text == reaction, "A risk-based counteroffer preserves the live character's reaction")
	var holding := "Bit of a leap from $385 to $340. I'm staying at $385."
	_deliver(player, listing, "What about 340", {"intent": "offer", "amount": 340, "seller_action": "counter", "counter_amount": 385, "text": holding})
	check.call(player.counters.get(listing.id) == 385 and player.chats[listing.id][-1].text == holding, "Holding the same price keeps a new contextual response instead of repeating a stock line")
	check.call(not player.offers.has(listing.id) and player.meeting_proposals.is_empty(), "Conversation does not invent an agreement or appointment")


func _clarifications() -> void:
	var player := fresh()
	var listing: Dictionary = game.state.listings[0]
	listing.character_id = "gus"
	listing.seller = Characters.find("gus").display_name
	listing.price = 100
	game.market.floors[listing.id] = 70
	var greeting := "Yes, still available. You've caught me watching Sir Buffering's race."
	_deliver(player, listing, "Hi, is this still available?", {"intent": "none", "seller_action": "none", "text": greeting})
	check.call(player.chats[listing.id][-1].text == greeting, "Hobby preference preserves the model's actual availability response")
	check.call(Relationships.engages(player, listing, "What?"), "Context recognizes a clarification before generating the next response")
	var explanation := "Sir Buffering is my racing snail. The first corner is a long-term project."
	_deliver(player, listing, "What?", {"intent": "none", "seller_action": "none", "text": explanation})
	check.call(player.chats[listing.id][-1].text == explanation, "What receives the explanation instead of a repeated hobby invitation")
	var reason := "I used to drive buses. These days I prefer passengers who carry their own houses."
	_deliver(player, listing, "Why?", {"intent": "none", "seller_action": "none", "text": reason})
	check.call(player.chats[listing.id][-1].text == reason, "Why retains the character's contextual answer")
	_deliver(player, listing, "I'll pay $100", {"intent": "offer", "amount": 100, "seller_action": "accept", "text": "That works."})
	check.call(player.offers.get(listing.id) == 100, "Normal bargaining works after a clarification without knowing hobby keywords")
	check.call(Relationships.relation(player, Characters.find("gus")).strikes == 0, "Confused follow-up questions do not cost patience")
	player = fresh()
	listing = game.state.listings[0]
	listing.character_id = "gus"
	Relationships.assess(player, listing, "Hello", 0)
	check.call(Relationships.engages(player, listing, "Oh, that sounds fun") and not Relationships.engages(player, listing, "I'll pay $100"), "Ordinary acknowledgement counts, while repeating a price does not masquerade as personal conversation")


func _relationships() -> void:
	var player := fresh()
	var listing: Dictionary = game.state.listings[0]
	listing.character_id = "gus"
	listing.seller = Characters.find("gus").display_name
	listing.price = 100
	game.market.floors[listing.id] = 70
	_deliver(player, listing, "I'll pay $100", {"intent": "offer", "amount": 100, "seller_action": "accept", "text": "Sure."})
	check.call(not player.offers.has(listing.id) and player.chats[listing.id][-1].text.contains("Sir Buffering"), "Hobby-first seller invites conversation instead of accepting a price immediately")
	_deliver(player, listing, "How is Sir Buffering doing?", {"intent": "none", "seller_action": "none", "text": "Still negotiating the first corner."})
	check.call(Relationships.relation(player, Characters.find("gus")).introduced, "A sincere hobby question satisfies the conversation preference")
	_deliver(player, listing, "I'll pay $100", {"intent": "offer", "amount": 100, "seller_action": "accept", "text": "That works."})
	check.call(player.offers.get(listing.id) == 100, "Normal trade works after the brief hobby conversation")
	var other: Dictionary = game.state.listings[1]
	other.character_id = "gus"
	other.seller = listing.seller
	check.call(not Relationships.assess(player, other, "Hello", 0).needs_conversation, "Conversation rapport follows the character across listings")
	player = fresh()
	listing = game.state.listings[0]
	listing.character_id = "greta"
	listing.seller = Characters.find("greta").display_name
	listing.price = 100
	game.market.floors[listing.id] = 80
	other = game.state.listings[1]
	other.character_id = "greta"
	other.seller = listing.seller
	player.offers[other.id] = 100
	player.meetings[other.id] = {"pos": other.pos, "start": game.clock(), "end": game.clock() + 90}
	_deliver(player, listing, "I'll pay $5", {"intent": "offer", "amount": 5, "seller_action": "counter", "counter_amount": 90, "text": "No."})
	check.call(Relationships.blocked(player, other) and not player.offers.has(other.id) and not player.meetings.has(other.id), "First extreme lowball ends all deals with that character")
	game.act("chat", {"listing_id": other.id, "text": "I'll pay full price"})
	check.call(not game.dialogue.pending_by.has(1), "Blocked contact cannot be bypassed through another listing")
	var cash: int = player.cash
	player.offers[other.id] = 1
	player.meetings[other.id] = {"pos": other.pos, "start": game.clock() - 1, "end": game.clock() + 90}
	player.area = "town"
	player.pos = other.pos
	game.act("handoff", {"listing_id": other.id})
	check.call(player.cash == cash and other.status == "available", "Handoff authority refuses stale agreements with a blocked contact")
	game.state.players[2] = preload("res://src/core/state_factory.gd").player("Other")
	check.call(not Relationships.blocked(game.state.players[2], other), "One player's refusal does not block other LAN players")
	check.call(Snapshot.for_player(game.state, 2).players[1].contact_relations.is_empty(), "Relationship history stays private in other players' snapshots")
	player = fresh()
	check.call(player.contact_relations.is_empty(), "Starting a fresh run resets refusals and rapport")
	listing = game.state.listings[0]
	check.call(Relationships.assess(player, listing, "You are an idiot", 0).warning, "Direct personal insults cost patience")
	player = fresh()
	listing = game.state.listings[0]
	Relationships.assess(player, listing, "Are you there yet?", 0)
	Relationships.assess(player, listing, "Are you there yet?", 0)
	check.call(Relationships.assess(player, listing, "Are you there yet?", 0).warning, "Repeated copy-paste messages cost patience")


func _deliver(player: Dictionary, listing: Dictionary, text: String, decision: Dictionary) -> void:
	game.dialogue.serial += 1
	var req: int = game.dialogue.serial
	game.dialogue.pending[req] = {"pid": 1, "lid": listing.id, "match": game.state.match_id, "text": text, "deliver_at": game.clock(), "options": []}
	game.dialogue.pending_by[1] = req
	game.dialogue.receive_reply(req, true, decision, "")


func fresh() -> Dictionary:
	game.solo("Conversation Test", 1000, "Balanced")
	game.set_process(false)
	game.set_physics_process(false)
	return game.me()
