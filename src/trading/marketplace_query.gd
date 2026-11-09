extends RefCounted
## Pure browsing rules. Never reorder or alter the shared marketplace.


static func select(listings: Array, filters: Dictionary) -> Array:
	var query := str(filters.get("query", "")).strip_edges().to_lower()
	var category := str(filters.get("category", ""))
	var result: Array = []
	for item: Dictionary in listings:
		if int(item.get("owner", 0)) != 0 or item.get("status", "") != "available":
			continue
		if category != "" and item.get("category", "") != category:
			continue
		var searchable := "%s %s %s %s" % [item.get("name", ""), item.get("seller", ""), item.get("manufacturer", ""), item.get("category", "")]
		if query != "" and not searchable.to_lower().contains(query):
			continue
		result.append(item)
	var order := str(filters.get("sort", "price_asc"))
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		if order == "newest":
			return int(a.id) > int(b.id)
		if int(a.price) == int(b.price):
			return int(a.id) < int(b.id)
		return int(a.price) > int(b.price) if order == "price_desc" else int(a.price) < int(b.price))
	return result
