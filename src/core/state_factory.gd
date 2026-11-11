extends RefCounted
## Fresh serializable state. Never reuse nested dictionaries across players or runs.
const Config = preload("res://src/core/game_config.gd")
const World = preload("res://src/world/world_rules.gd")
const Catalog = preload("res://src/data/catalog.gd")


static func blank() -> Dictionary:
	return {"phase": "menu", "mode": "solo", "assembly_test": false, "remaining": Config.TOTAL_MINUTES, "match_days": Config.DEFAULT_MATCH_DAYS,
		"total_minutes": Config.TOTAL_MINUTES, "deadline": Config.DEADLINE, "budget": 1000, "objective": "Balanced",
		"players": {}, "listings": [], "events": [], "ranking": [], "seller_status": "", "match_id": 0}


## Sandbox-owned IDs are negative, separate from the market's positive listing IDs.
static func assembly_test_inventory(rng: RandomNumberGenerator) -> Array:
	var inventory: Array = []
	for i in Catalog.PARTS.size():
		var item := Catalog.build_listing(rng, Catalog.PARTS[i], -(i + 1))
		item.status = "owned"
		inventory.append(item)
	return inventory


static func player(pname: String) -> Dictionary:
	var n := pname.strip_edges().left(16)
	return {"name": n if n != "" else "Player", "cash": 0, "inventory": [], "installed": {}, "tuning": {}, "chats": {}, "chat_serial": 0,
		"offers": {}, "counters": {}, "meetings": {}, "meeting_proposals": {}, "contact_relations": {}, "lucky_messages": [], "area": "home", "driving": false, "car_pos": World.CAR_START, "facing": Vector2.DOWN, "ready": false, "score": {}, "best": 0, "busy": 0.0, "pos": World.SPAWN, "destroyed": [],
		"workshop_modifiers": {"cooling_bonus": 0, "lucky_tests": 0, "assembly_mistakes": 0, "assembly_fasteners": {}}, "world_visits": {}, "serviced_parts": {}, "last_stress_test": {}, "benchmark_checked": false}
