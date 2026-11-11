extends PanelContainer
## Ownership and live buying progress only, not a compatibility/assembly checklist.
const Entry = preload("res://src/ui/build_checklist_item.gd")
const Relationships = preload("res://src/trading/contact_relationships.gd")
const RigRules = preload("res://src/workshop/rig_rules.gd")


func _ready() -> void:
	Game.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var player: Dictionary = Game.me()
	if player.is_empty():
		return
	var owned: Dictionary = {}
	var owned_details: Dictionary = {}
	for item: Dictionary in player.get("inventory", []):
		owned[str(item.category)] = item
		owned_details[str(item.category)] = "Owned: " + str(item.name)
	var installed: Dictionary = player.get("installed", {})
	for category: String in installed:
		owned[category] = installed[category]
		owned_details[category] = "Installed: " + str(installed[category].name)
	if not owned.has("gpu") and RigRules.igpu_usable(installed):
		owned["gpu"] = installed.cpu
		owned_details["gpu"] = "Owned: integrated CPU graphics"
	var negotiating: Dictionary = {}
	var agreed: Dictionary = {}
	var chats: Dictionary = player.get("chats", {})
	var offers: Dictionary = player.get("offers", {})
	for listing: Dictionary in Game.state.listings:
		if int(listing.get("owner", 0)) != 0 or listing.status != "available" or Relationships.blocked(player, listing):
			continue
		var category := str(listing.category)
		if int(offers.get(listing.id, 0)) > 0:
			agreed[category] = "Agreed $%d with %s · pickup pending" % [int(offers[listing.id]), listing.seller]
		elif not chats.get(listing.id, []).is_empty():
			negotiating[category] = "Negotiating with " + str(listing.seller)
	for entry: Entry in $Box/Parts.get_children():
		var category: String = entry.category
		if owned.has(category):
			entry.show_status(Entry.Status.OWNED, str(owned_details[category]))
		elif agreed.has(category):
			entry.show_status(Entry.Status.AGREED, str(agreed[category]))
		elif negotiating.has(category):
			entry.show_status(Entry.Status.NEGOTIATING, str(negotiating[category]))
		else:
			entry.show_status(Entry.Status.MISSING, "Missing")
