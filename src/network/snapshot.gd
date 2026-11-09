extends RefCounted
## Private negotiation data never leaves the authority for another player.


static func for_player(state: Dictionary, pid: int) -> Dictionary:
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
