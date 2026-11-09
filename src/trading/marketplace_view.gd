extends VBoxContainer
## Browse controls keep focus while live stock and prices change underneath them.
signal listing_selected(id: int)
const K = preload("res://src/ui/ui_kit.gd")
const Catalog = preload("res://src/data/catalog.gd")
const Stats = preload("res://src/data/hardware_stats.gd")
const Art = preload("res://src/ui/part_art.gd")
const Query = preload("res://src/trading/marketplace_query.gd")
const Relationships = preload("res://src/trading/contact_relationships.gd")
const SORTS := ["price_asc", "price_desc", "newest"]
var filters: Dictionary
var _listings: Array
var _player: Dictionary
var _search: LineEdit
var _type: OptionButton
var _order: OptionButton
var _grid: GridContainer
var _count: Label
var _empty: Label
var _scroll: ScrollContainer
var _visible_listings: Array = []


func setup(saved_filters: Dictionary, listings: Array, player: Dictionary) -> void:
	filters = saved_filters
	add_theme_constant_override("separation", 8)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(K.lbl("Filter your shortlist, then message a seller to agree price, place and time.", "Muted", null, true))
	var controls := K.hbox(8)
	add_child(controls)
	_search = LineEdit.new()
	_search.placeholder_text = "Search parts or sellers..."
	_search.text = str(filters.query)
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(_search)
	_type = OptionButton.new()
	_type.add_item("All part types")
	for category: String in Catalog.CATEGORIES:
		_type.add_item("GPU / graphics" if category == "gpu" else K.CAT_LABEL[category])
	_type.select(Catalog.CATEGORIES.find(str(filters.category)) + 1)
	controls.add_child(_type)
	_order = OptionButton.new()
	for title in ["Price: low to high", "Price: high to low", "Newest listings"]:
		_order.add_item(title)
	_order.select(maxi(0, SORTS.find(str(filters.sort))))
	controls.add_child(_order)
	controls.add_child(K.btn("Reset", "GhostButton", _reset))
	_count = K.lbl("", "Tiny", K.MUTED)
	add_child(_count)
	_empty = K.lbl("No matching parts. Try another type or clear your search.", "Muted", null, true)
	add_child(_empty)
	_scroll = K.scroll()
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_scroll.add_child(_grid)
	_search.text_changed.connect(func(value: String): filters.query = value; _filter_changed())
	_type.item_selected.connect(func(index: int): filters.category = "" if index == 0 else Catalog.CATEGORIES[index - 1]; _filter_changed())
	_order.item_selected.connect(func(index: int): filters.sort = SORTS[index]; _filter_changed())
	update_listings(listings, player)


func _reset() -> void:
	filters.merge({"query": "", "category": "", "sort": "price_asc"}, true)
	_search.text = ""
	_type.select(0)
	_order.select(0)
	_filter_changed()


func _filter_changed() -> void:
	_scroll.scroll_vertical = 0
	update_listings(_listings, _player)


func update_listings(listings: Array, player: Dictionary) -> void:
	_listings = listings
	_player = player
	_visible_listings = Query.select(listings, filters)
	K.clear(_grid)
	_count.text = "%d matching listing%s" % [_visible_listings.size(), "" if _visible_listings.size() == 1 else "s"]
	var blocked_count := _visible_listings.filter(func(item): return Relationships.blocked(_player, item)).size()
	if blocked_count > 0:
		_count.text += " · %d blocked for you" % blocked_count
	_empty.visible = _visible_listings.is_empty()
	for item: Dictionary in _visible_listings:
		_grid.add_child(_card(item))


func _card(item: Dictionary) -> Control:
	var blocked := Relationships.blocked(_player, item)
	var card := K.panel("CardTight")
	if blocked:
		card.add_theme_stylebox_override("panel", K.box(K.NAVY1, K.DANGER, 8, 1, 10, 8))
	card.tooltip_text = "This seller blocked you for this run. You can view the conversation, but cannot message or buy from them." if blocked else "Message this seller to arrange a deal."
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var box := K.vbox(3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if blocked:
		box.add_child(K.lbl("SELLER BLOCKED YOU", "Eyebrow", K.DANGER, true))
	var art: Control = Art.new()
	art.custom_minimum_size = Vector2(150, 72)
	art.show_item(item)
	if blocked:
		art.modulate = Color(0.55, 0.55, 0.55)
	box.add_child(art)
	box.add_child(K.lbl("$%d" % int(item.price), "Big", K.MUTED if blocked else K.SKY))
	var name_label := K.lbl(str(item.get("manufacturer", "")) + " " + str(item.name), "", K.MUTED if blocked else K.CREAM, true)
	name_label.custom_minimum_size.x = 180
	box.add_child(name_label)
	var detail := "Condition %d/100" % int(item.get("condition", 100))
	if str(item.category) in ["cpu", "gpu", "ram", "storage"]:
		detail += " · stock %d" % roundi(Stats.stock_score(item))
	if float(item.get("oc_potential", 0)) > 0:
		detail += " · OC +%d%%" % roundi(float(item.oc_potential) * 100)
	box.add_child(K.lbl(detail, "Tiny", K.LIME, true))
	var fault := Stats.stock_failure_chance(item)
	if fault > 0:
		box.add_child(K.lbl("RELIABILITY WARNING · %.1f%% stock failure risk" % (fault * 100), "Tiny", K.ORANGE, true))
	var fire := Stats.stock_fire_chance(item)
	if fire > 0:
		box.add_child(K.lbl("CONNECTOR FIRE · %.1f%% at stock; higher when overclocked" % (fire * 100), "Tiny", K.ORANGE, true))
	box.add_child(K.lbl(Stats.value_text(item), "Tiny", K.MUTED, true))
	box.add_child(K.lbl(str(item.seller) + " · " + str(item.location), "Tiny", K.DANGER if blocked else null, true))
	card.add_child(box)
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			listing_selected.emit(int(item.id)))
	return card
