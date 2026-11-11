extends RefCounted
## Shared buying/ownership facts for the build HUD and compatibility references.
const Relationships = preload("res://src/trading/contact_relationships.gd")
const K = preload("res://src/ui/ui_kit.gd")
enum Status { MISSING, NEGOTIATING, AGREED, OWNED }


static func color(status: Status) -> Color:
	match status:
		Status.OWNED: return Color("60d887")
		Status.AGREED: return Color("b9e5ae")
		Status.NEGOTIATING: return K.ORANGE
	return Color("8590a4")


static func tracked_parts(player: Dictionary, listings: Array) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	# Installed wins ties over inventory, then an agreed deal wins over a chat.
	var installed: Dictionary = player.get("installed", {})
	for category: String in installed:
		var item: Dictionary = installed[category]
		parts.append({"item": item, "status": Status.OWNED, "detail": "Installed: " + str(item.name)})
	for item: Dictionary in player.get("inventory", []):
		parts.append({"item": item, "status": Status.OWNED, "detail": "Owned: " + str(item.name)})
	var chats: Dictionary = player.get("chats", {})
	var offers: Dictionary = player.get("offers", {})
	for listing: Dictionary in listings:
		if int(listing.get("owner", 0)) != 0 or listing.status != "available" or Relationships.blocked(player, listing):
			continue
		var price := int(offers.get(listing.id, 0))
		if price > 0:
			parts.append({"item": listing, "status": Status.AGREED,
				"detail": "Agreed $%d with %s · pickup pending" % [price, listing.seller]})
		elif not chats.get(listing.id, []).is_empty():
			parts.append({"item": listing, "status": Status.NEGOTIATING,
				"detail": "Negotiating with " + str(listing.seller)})
	return parts
