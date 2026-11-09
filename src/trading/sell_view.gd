extends VBoxContainer
## Public valuation and asking-price help; all sales still go through the host.
signal listing_selected(id: int)
const K = preload("res://src/ui/ui_kit.gd")
const Stats = preload("res://src/data/hardware_stats.gd")
var _drafts: Dictionary


func setup(player: Dictionary, listings: Array, price_drafts: Dictionary) -> void:
	_drafts = price_drafts
	add_theme_constant_override("separation", 8)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(K.lbl("YOUR SPARE PARTS", "H2"))
	add_child(K.lbl("Prices below account for condition. They are guides, not guaranteed offers. Buyers haggle in Messages; you only get paid at the meeting. Cancel a listing before installing its part.", "Muted", null, true))
	var scroll := K.scroll()
	add_child(scroll)
	var box := K.vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	for item: Dictionary in player.inventory:
		var active := {}
		for listing: Dictionary in listings:
			if int(listing.get("owner", 0)) == Game.local_id() and int(listing.get("item_id", -99999)) == int(item.id) and listing.status == "available":
				active = listing
		box.add_child(_card(item, active))
	if player.inventory.is_empty():
		box.add_child(K.lbl("No spare parts. Installed components must be replaced at the workbench before selling.", "Muted", null, true))


func _card(item: Dictionary, active: Dictionary) -> Control:
	var card := K.panel("Card")
	var content := K.vbox(6)
	card.add_child(content)
	content.add_child(K.lbl(str(item.name), "Mono", null, true))
	var guide := Stats.sale_guide(item)
	content.add_child(K.lbl("Condition %d/100 · estimated used value $%d\nSuggested ask $%d–$%d · quick-deal guide $%d" % [item.get("condition", 100), guide.value, guide.ask_low, guide.ask_high, guide.quick], "Tiny", K.LIME, true))
	if not active.is_empty():
		var contacted: bool = active.get("buyer_contacted", true)
		var status := "%s is interested" % active.seller if contacted else "Waiting for interest — high asks may get no replies"
		content.add_child(K.lbl("Listed $%d · %s" % [int(active.price), status], "Tiny", K.SKY, true))
		content.add_child(K.lbl(Stats.sale_advice(item, int(active.price)), "Tiny", K.MUTED, true))
		var actions := K.hbox(6)
		if contacted:
			actions.add_child(K.btn("Chat with buyer", "", func(): listing_selected.emit(int(active.id))))
		actions.add_child(K.btn("Cancel listing", "GhostButton", func(): Game.act("cancel_sale", {"listing_id": active.id})))
		content.add_child(actions)
		return card
	var row := K.hbox(6)
	var price := SpinBox.new()
	price.min_value = 1
	price.max_value = 5000
	price.value = int(_drafts.get(int(item.id), guide.value))
	price.prefix = "$"
	row.add_child(price)
	row.add_child(K.btn("Use guide: $%d" % guide.value, "GhostButton", func(): price.value = guide.value))
	row.add_child(K.btn("Quick deal: $%d" % guide.quick, "GhostButton", func(): price.value = guide.quick))
	row.add_child(K.btn("Post listing", "PrimaryButton", func(): Game.act("post_sale", {"item_id": item.id, "price": int(price.value)})))
	content.add_child(row)
	var advice := K.lbl(Stats.sale_advice(item, int(price.value)), "Tiny", K.MUTED, true)
	content.add_child(advice)
	price.value_changed.connect(func(value: float):
		_drafts[int(item.id)] = int(value)
		advice.text = Stats.sale_advice(item, int(value)))
	return card
