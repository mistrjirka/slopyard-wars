extends VBoxContainer
## Browse controls keep focus while live stock and prices change underneath them.
signal listing_selected(id: int)
const Catalog = preload("res://src/data/catalog.gd")
const K = preload("res://src/ui/ui_kit.gd")
const Query = preload("res://src/trading/marketplace_query.gd")
const ListingCardScene = preload("res://src/trading/listing_card.tscn")
const Relationships = preload("res://src/trading/contact_relationships.gd")
const SORTS := ["price_asc", "price_desc", "newest"]
var filters: Dictionary
var _listings: Array
var _player: Dictionary
@onready var _search: LineEdit = $Controls/Search
@onready var _type: OptionButton = $Controls/Type
@onready var _order: OptionButton = $Controls/Order
@onready var _reset_button: Button = $Controls/Reset
@onready var _grid: GridContainer = $Scroll/Grid
@onready var _count: Label = $Count
@onready var _empty: Label = $Empty
@onready var _scroll: ScrollContainer = $Scroll
var _visible_listings: Array = []


static func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func setup(saved_filters: Dictionary, listings: Array, player: Dictionary) -> void:
	filters = saved_filters
	add_theme_constant_override("separation", 8)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_search.placeholder_text = "Search parts or sellers..."
	_search.text = str(filters.query)
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type.clear()
	_type.add_item("All part types")
	for category: String in Catalog.CATEGORIES:
		_type.add_item("GPU / graphics" if category == "gpu" else K.CAT_LABEL[category])
	_type.select(Catalog.CATEGORIES.find(str(filters.category)) + 1)
	_order.clear()
	for title in ["Price: low to high", "Price: high to low", "Newest listings"]:
		_order.add_item(title)
	_order.select(maxi(0, SORTS.find(str(filters.sort))))
	if not _reset_button.pressed.is_connected(_reset):
		_reset_button.pressed.connect(_reset)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not _search.text_changed.is_connected(_on_search_changed):
		_search.text_changed.connect(_on_search_changed)
	if not _type.item_selected.is_connected(_on_type_selected):
		_type.item_selected.connect(_on_type_selected)
	if not _order.item_selected.is_connected(_on_order_selected):
		_order.item_selected.connect(_on_order_selected)
	update_listings(listings, player)


func _on_search_changed(value: String) -> void:
	filters.query = value
	_filter_changed()


func _on_type_selected(index: int) -> void:
	filters.category = "" if index == 0 else Catalog.CATEGORIES[index - 1]
	_filter_changed()


func _on_order_selected(index: int) -> void:
	filters.sort = SORTS[index]
	_filter_changed()


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
	var scroll_position := _scroll.scroll_vertical
	_listings = listings
	_player = player
	_visible_listings = Query.select(listings, filters)
	_clear(_grid)
	_count.text = "%d matching listing%s" % [_visible_listings.size(), "" if _visible_listings.size() == 1 else "s"]
	var blocked_count := _visible_listings.filter(func(item): return Relationships.blocked(_player, item)).size()
	if blocked_count > 0:
		_count.text += " · %d blocked for you" % blocked_count
	_empty.visible = _visible_listings.is_empty()
	for item: Dictionary in _visible_listings:
		var card: PanelContainer = _card(item)
		_grid.add_child(card)
		card.setup(item, Relationships.blocked(_player, item), _has_messaged(int(item.id)))
	_scroll.set_deferred("scroll_vertical", scroll_position)


func _has_messaged(listing_id: int) -> bool:
	for message: Dictionary in _player.get("chats", {}).get(listing_id, []):
		if str(message.get("speaker", "")) == str(_player.get("name", "")) and not str(message.get("text", "")).strip_edges().is_empty():
			return true
	return false


func _card(item: Dictionary) -> Control:
	var card: PanelContainer = ListingCardScene.instantiate()
	# content already in scene (setup runs once the card enters the tree; see below)
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			listing_selected.emit(int(item.id))
		elif event.is_action_pressed("ui_accept"):
			card.accept_event()
			listing_selected.emit(int(item.id)))
	return card
