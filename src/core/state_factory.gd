extends RefCounted
## Fresh serializable state. Never reuse nested dictionaries across players or runs.
const Config = preload("res://src/core/game_config.gd")
const World = preload("res://src/world/world_rules.gd")


static func blank() -> Dictionary:
	return {"phase": "menu", "mode": "solo", "remaining": Config.TOTAL_MINUTES, "budget": 1000, "objective": "Balanced",
		"players": {}, "listings": [], "events": [], "ranking": [], "seller_status": "", "match_id": 0}


static func player(pname: String) -> Dictionary:
	var n := pname.strip_edges().left(16)
	return {"name": n if n != "" else "Player", "cash": 0, "inventory": [], "installed": {}, "tuning": {}, "chats": {},
		"offers": {}, "counters": {}, "meetings": {}, "meeting_proposals": {}, "area": "home", "driving": false, "car_pos": World.CAR_START, "facing": Vector2.DOWN, "ready": false, "score": {}, "best": 0, "busy": 0.0, "pos": World.SPAWN, "destroyed": [],
		"workshop_modifiers": {"cooling_bonus": 0, "lucky_tests": 0}, "world_visits": {}, "serviced_parts": {}, "last_stress_test": {}, "benchmark_checked": false}
