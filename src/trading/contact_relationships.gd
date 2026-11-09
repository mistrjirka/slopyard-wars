extends RefCounted
## Per-player, per-character social state. The host applies strikes and validates proposed refusals.
const Characters = preload("res://src/data/characters.gd")


static func relation(player: Dictionary, character: Resource) -> Dictionary:
	if not player.has("contact_relations"):
		player.contact_relations = {}
	var id := str(character.id)
	if not player.contact_relations.has(id):
		player.contact_relations[id] = {"strikes": 0, "blocked": false, "introduced": false, "invited": false, "last_text": "", "repeats": 0}
	return player.contact_relations[id]


static func blocked(player: Dictionary, listing: Dictionary) -> bool:
	return bool(player.get("contact_relations", {}).get(str(Characters.for_listing(listing).id), {}).get("blocked", false))


## A normal follow-up to an invitation counts as conversation, without a secret keyword.
## Used before generation too, so the prompt reflects the message being answered.
static func engages(player: Dictionary, listing: Dictionary, text: String) -> bool:
	var character := Characters.for_listing(listing)
	var social: Dictionary = player.get("contact_relations", {}).get(str(character.id), {})
	var query := text.strip_edges().to_lower()
	if query.is_empty():
		return false
	var price_talk := RegEx.create_from_string("(?i)([$€£]|\\b(?:pay|offer|price|buy|deal|discount|take it)\\b)").search(query) != null
	if social.get("invited", false) and not price_talk:
		return true
	if query.contains("about yourself") or query.contains("how are you"):
		return true
	for topic: String in character.rapport_keywords:
		if query.contains(topic.to_lower()) and not price_talk:
			return true
	return false


static func dismisses_interest(query: String, topics: PackedStringArray) -> bool:
	var patterns := [
		"^(?:i (?:don['’]?t|do not) care about|(?:nobody|no one|who) cares about) (.+)$",
		"^(?:your|that) (.+?) (?:is|are) (?:stupid|boring|pointless|pathetic|a waste of time)[.!?]*$"
	]
	for pattern: String in patterns:
		var hit := RegEx.create_from_string(pattern).search(query.to_lower())
		if hit == null:
			continue
		var subject := " " + RegEx.create_from_string("[^a-z0-9]+").sub(hit.get_string(1), " ", true).strip_edges() + " "
		for topic: String in topics:
			if subject.contains(" " + topic.to_lower() + " "):
				return true
	return false


static func preview(player: Dictionary, listing: Dictionary, text: String, offer: int) -> Dictionary:
	return assess({"contact_relations": player.get("contact_relations", {}).duplicate(true)}, listing, text, offer)


static func assess(player: Dictionary, listing: Dictionary, text: String, offer: int, contact_action: String = "none") -> Dictionary:
	var character := Characters.for_listing(listing)
	var social := relation(player, character)
	if social.blocked:
		return {"blocked": true, "warning": false, "needs_conversation": false, "reason": "conduct"}
	var query := text.strip_edges().to_lower()
	# Brief bargaining follow-ups may be classified as conversation rather than a new offer.
	# Recognize only explicit standalone price phrases, not numbers in technical questions.
	if offer <= 0:
		var repeated_offer := RegEx.create_from_string("^(?:(?:i said|i offered|what about|how about|i can do)\\s+)?[$€£]?([0-9]+)[.!?]?$").search(query)
		if repeated_offer:
			offer = int(repeated_offer.get_string(1))
	var rude := RegEx.create_from_string("(?i)\\b(you(?:'re| are)? (?:an? )?(?:idiot|moron|stupid)|shut up|fuck you)\\b").search(query) != null
	if query == social.last_text and query.length() > 12:
		social.repeats += 1
	else:
		social.repeats = 0
	social.last_text = query
	var lowball := int(listing.get("owner", 0)) == 0 and offer > 0 and offer < float(listing.price) * character.lowball_fraction
	var personal_boundary := dismisses_interest(query, character.sensitive_topics)
	var immediate: bool = rude or personal_boundary or (lowball and character.block_on_lowball) or contact_action == "block"
	var warning := immediate or lowball or int(social.repeats) >= 2 or contact_action == "warn"
	if warning:
		social.strikes += 1
		social.blocked = immediate or int(social.strikes) >= maxi(2, character.patience_limit)
	if not warning and offer <= 0 and engages(player, listing, text):
		social.introduced = true
	var needs_conversation: bool = int(listing.get("owner", 0)) == 0 and character.requires_conversation and not social.introduced
	if needs_conversation and not warning:
		social["invited"] = true
	return {"blocked": social.blocked, "warning": warning,
		"needs_conversation": needs_conversation, "reason": "hobby" if personal_boundary else ("lowball" if lowball else "conduct")}
