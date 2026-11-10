extends RefCounted
## Marketplace usability and the shortened day's boundaries, without provider requests.
const Query = preload("res://src/trading/marketplace_query.gd")
const Stats = preload("res://src/data/hardware_stats.gd")
const Catalog = preload("res://src/data/catalog.gd")
const Characters = preload("res://src/data/characters.gd")
const Trade = preload("res://src/trading/trade_rules.gd")
const Config = preload("res://src/core/game_config.gd")
const K = preload("res://src/ui/ui_kit.gd")
var game: Node
var check: Callable


func run(session: Node, assertion: Callable) -> void:
	game = session
	check = assertion
	_query()
	_sale_values()
	_day()
	await _phone()


func fresh() -> Dictionary:
	game.solo("Marketplace Test", 1000, "Balanced")
	game.set_process(false)
	game.set_physics_process(false)
	return game.me()


func _query() -> void:
	var listings: Array = []
	for row in [[3, "gpu", 80], [1, "cpu", 120], [2, "gpu", 80], [4, "gpu", 20], [5, "ram", 30]]:
		listings.append({"id": row[0], "category": row[1], "price": row[2], "name": "Lucky part", "seller": "Sunny Dave", "manufacturer": "LVD", "status": "available", "owner": 0})
	var hidden: Dictionary = listings[0].duplicate()
	hidden.id = 6
	hidden.status = "sold"
	listings.append(hidden)
	var private: Dictionary = listings[0].duplicate()
	private.id = 7
	private.owner = 2
	listings.append(private)
	var before := listings.duplicate(true)
	var gpu := Query.select(listings, {"category": "gpu", "sort": "price_asc"})
	check.call(gpu.map(func(item): return item.id) == [4, 2, 3], "GPU filter sorts by price and breaks price ties consistently")
	check.call(Query.select(listings, {"category": "gpu", "sort": "price_desc"}).map(func(item): return item.id) == [2, 3, 4], "Descending price order is numeric and stable")
	check.call(Query.select(listings, {"sort": "newest"}).map(func(item): return item.id) == [5, 4, 3, 2, 1], "Newest sorting excludes unavailable listings and private buyers")
	check.call(Query.select(listings, {"category": "cpu", "query": "  SUNNY  "}).size() == 1, "Search combines with type and ignores case and surrounding whitespace")
	check.call(Query.select(listings, {"query": "lvd"}).size() == 5, "Search also recognizes fictional manufacturers")
	check.call(Query.select(listings, {"category": "psu"}).is_empty(), "A missing category produces an honest empty result")
	check.call(Query.select([], {}).is_empty() and listings == before, "Queries handle empty stock without changing shared data")
	for category: String in Catalog.CATEGORIES:
		var item := {"id": 1, "price": 1, "category": category, "status": "available"}
		check.call(Query.select([item], {"category": category}).size() == 1, "Filter supports category " + category)


func _sale_values() -> void:
	var item := {"reference_base": 400, "price": 1, "condition": 20, "buyer_max": 99999}
	var guide := Stats.sale_guide(item)
	check.call(guide.value == 320 and guide.quick == 256 and guide.ask_high == 368, "Sale guidance uses current condition and base value, not the purchase price")
	item.buyer_max = 1
	check.call(Stats.sale_guide(item) == guide, "Public sale advice does not reveal or depend on the private buyer ceiling")
	check.call(Stats.sale_advice(item, 5000).begins_with("Ambitious") and Stats.sale_advice(item, 1).begins_with("Below"), "Price feedback explains both excessive asks and underpricing")
	item.condition = 100
	check.call(Stats.sale_guide(item).value > guide.value, "Cleaning changes the suggested sale value")
	check.call(Stats.sale_guide({"reference_base": 0}).quick == 1 and Stats.sale_guide({"reference_base": 10000}).ask_high == 5000, "Suggested prices respect the host's listing limits")


func _day() -> void:
	var player := fresh()
	check.call(game.clock() == 480 and Config.DEADLINE == 1320 and Config.TOTAL_MINUTES < 1440, "Default run is a single 08:00–22:00 day")
	check.call(K.real_left(Config.TOTAL_MINUTES) == "18:40" and K.clock_text(Config.TOTAL_MINUTES).ends_with("08:00"), "Clock UI uses the configured start and real-time pace")
	for contact: Resource in Characters.ALL:
		var options := Trade.options(contact.display_name, contact.meeting_places[0], Trade.START)
		check.call(not options.is_empty(), "Every character can participate in the one-day run")
		for option: Dictionary in options:
			check.call(option.start >= Trade.START and option.end <= Config.DEADLINE and option.end - option.start >= 30, "Appointments are feasible and finish before the single-day deadline")
		check.call(Trade.options(contact.display_name, contact.meeting_places[0], Config.DEADLINE - 10).is_empty(), "No contact offers a tomorrow appointment after last call")
	game.state.remaining = 90
	for iteration in 6:
		var listing: Dictionary = game.market.add_listing(Catalog.PARTS[0], false)
		check.call(not listing.is_empty() and not game.contact_options(listing).is_empty(), "Late restocks choose contacts who can still meet tonight")
	game.act("post_sale", {"item_id": player.inventory[0].id, "price": 15})
	check.call(not game.contact_options(game.state.listings[-1]).is_empty(), "Late sale chooses a buyer with a remaining meeting window")
	game.act("cancel_sale", {"listing_id": game.state.listings[-1].id})
	game.state.remaining = 10
	var count: int = game.state.listings.size()
	game.act("post_sale", {"item_id": player.inventory[0].id, "price": 15})
	check.call(game.state.listings.size() == count and game.market.add_listing(Catalog.PARTS[0], false).is_empty(), "No unusable buyer or fresh listing is created after all meeting windows close")
	game.advance_time(10)
	check.call(game.state.phase == "results" and game.clock() == Config.DEADLINE, "Short day finalizes automatically at the configured deadline")


func _phone() -> void:
	var player := fresh()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	game.get_tree().root.add_child(viewport)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.theme = K.make_theme()
	viewport.add_child(center)
	var phone: Control = load("res://src/trading/phone.tscn").instantiate()
	center.add_child(phone)
	phone.set_unfolded(true)
	await settle()
	var view: Control = phone._browse_view
	var gpu_index: int = Catalog.CATEGORIES.find("gpu") + 1
	view._type.select(gpu_index)
	view._type.item_selected.emit(gpu_index)
	check.call(not view._visible_listings.is_empty() and view._visible_listings.all(func(item): return item.category == "gpu"), "Marketplace type dropdown actually filters the visible cards")
	view._order.select(1)
	view._order.item_selected.emit(1)
	check.call(view._visible_listings[0].price >= view._visible_listings[-1].price, "Price dropdown updates the visible card order")
	view._search.text = "this part does not exist"
	view._search.text_changed.emit(view._search.text)
	check.call(view._empty.visible and view._grid.get_child_count() == 0, "Empty searches display helpful feedback")
	view._search.grab_focus()
	view._search.caret_column = 4
	game.state.listings[0].price += 1
	phone.refresh()
	await settle()
	check.call(phone._browse_view == view and view._search.has_focus() and view._search.caret_column == 4, "A live marketplace update preserves the search field and typing focus")
	phone.set_unfolded(false)
	phone.set_unfolded(true)
	await settle()
	view = phone._browse_view
	check.call(view._type.selected == gpu_index and view._order.selected == 1 and view._search.text == "this part does not exist", "Type, sorting and search survive folding")
	view._reset()
	check.call(view.filters.category == "" and view.filters.sort == "price_asc" and not view._empty.visible, "Reset restores all types and ascending prices")
	phone._show("sell")
	await settle()
	var sale: Control = phone._body.get_child(0)
	var price: SpinBox = sale.find_children("*", "SpinBox", true, false)[0]
	check.call(price.value == Stats.sale_guide(player.inventory[0]).value, "Sell input defaults to current used value")
	price.value = 123
	player.inventory[0].condition -= 1
	phone.refresh()
	await settle()
	sale = phone._body.get_child(0)
	price = sale.find_children("*", "SpinBox", true, false)[0]
	check.call(price.value == 123, "An edited asking-price draft survives a refreshed valuation")
	var quick: Button = sale.find_children("*", "Button", true, false).filter(func(button): return button.text.begins_with("Quick deal:"))[0]
	quick.pressed.emit()
	check.call(price.value == Stats.sale_guide(player.inventory[0]).quick, "Quick-deal button fills the advertised price")
	check.call(phone.size.x <= viewport.size.x and phone.size.y <= viewport.size.y, "New browse and sale controls fit the supported 720p phone")
	viewport.queue_free()
	await settle()


func settle() -> void:
	for frame in 4:
		await game.get_tree().process_frame
