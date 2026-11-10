extends VBoxContainer
## Public valuation and asking-price help; all sales still go through the host.
signal listing_selected(id: int)
const Stats = preload("res://src/data/hardware_stats.gd")
const SellCardScene = preload("res://src/trading/sell_card.tscn")
var _drafts: Dictionary
@onready var _box: VBoxContainer = $Scroll/Box
@onready var _empty: Label = $Scroll/Box/Empty


static func _clear(node: Node) -> void:
	for c in node.get_children():
		if c.name == "Empty":
			continue
		node.remove_child(c)
		c.queue_free()


func setup(player: Dictionary, listings: Array, price_drafts: Dictionary) -> void:
	_drafts = price_drafts
	if not _drafts.has("expanded_items"):
		_drafts["expanded_items"] = {}
	add_theme_constant_override("separation", 8)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_clear(_box)
	for item: Dictionary in player.inventory:
		var active := {}
		for listing: Dictionary in listings:
			if int(listing.get("owner", 0)) == Game.local_id() and int(listing.get("item_id", -99999)) == int(item.id) and listing.status == "available":
				active = listing
		_add_card(item, active)
	_box.move_child(_empty, -1)
	_empty.visible = player.inventory.is_empty()


func _add_card(item: Dictionary, active: Dictionary) -> void:
	var card: PanelContainer = SellCardScene.instantiate()
	_box.add_child(card)
	var draft_price := int(_drafts.get(int(item.id), Stats.sale_guide(item).value))
	var expanded_items: Dictionary = _drafts.get("expanded_items", {})
	card.setup(item, active, draft_price, bool(expanded_items.get(int(item.id), false)), _drafts.has(int(item.id)))
	if active.is_empty():
		card.expanded_changed.connect(func(expanded: bool):
			expanded_items[int(item.id)] = expanded
			_drafts["expanded_items"] = expanded_items)
		card.price.value_changed.connect(func(value: float): _drafts[int(item.id)] = int(value))
		card.post_requested.connect(func(price: int): Game.act("post_sale", {"item_id": item.id, "price": price}))
	else:
		card.chat_requested.connect(func(): listing_selected.emit(int(active.id)))
		card.cancel_requested.connect(func(): Game.act("cancel_sale", {"listing_id": active.id}))
