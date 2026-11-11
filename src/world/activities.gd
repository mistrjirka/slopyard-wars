extends RefCounted
const ActivityDefinition = preload("res://src/data/world_activity_definition.gd")
const ALL: Array = preload("res://resources/world_activities.tres").activities


static func find(id: String) -> ActivityDefinition:
	for activity: ActivityDefinition in ALL:
		if str(activity.id) == id:
			return activity
	return null


static func nearby(player: Dictionary) -> ActivityDefinition:
	if player.is_empty() or bool(player.get("driving", false)):
		return null
	var nearest: ActivityDefinition
	var distance := INF
	for activity: ActivityDefinition in ALL:
		if player.get("area", "") != activity.area:
			continue
		var candidate: float = Vector2(player.pos).distance_to(activity.position)
		if candidate <= activity.radius and candidate < distance:
			nearest = activity
			distance = candidate
	return nearest


static func cost_text(activity: ActivityDefinition) -> String:
	if activity.kind == "clean":
		return "From $%d · %d game minutes · once per part/run" % [activity.cash_cost, activity.minutes_cost]
	var limit := " · once per run" if activity.once_per_run else (" · %d/day" % activity.uses_per_day if activity.uses_per_day > 0 else "")
	return "$%d · %d game minutes%s" % [activity.cash_cost, activity.minutes_cost, limit]
