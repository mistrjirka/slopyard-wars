extends RefCounted
## Authority for world encounters: validates proximity and all costs before applying rewards.
const Activities = preload("res://src/world/activities.gd")
const Catalog = preload("res://src/data/catalog.gd")
const Rig = preload("res://src/workshop/rig_rules.gd")
const Stats = preload("res://src/data/hardware_stats.gd")
var session: Node


func _init(game_session: Node) -> void:
	session = game_session


func eligible_parts(player: Dictionary) -> Array:
	var parts: Array = player.inventory.duplicate()
	parts.append_array(player.installed.values())
	return parts.filter(func(item):
		return int(item.get("condition", 100)) < 100 and not player.serviced_parts.has(int(item.id)) and not _listed(int(item.id)))


func _listed(item_id: int) -> bool:
	for listing: Dictionary in session.state.listings:
		if listing.status == "available" and int(listing.get("item_id", -99999)) == item_id and int(listing.get("owner", 0)) > 0:
			# Inventory identities are unique across the match.
			return true
	return false


func cash_cost(activity: Resource, item: Dictionary = {}) -> int:
	if activity.kind == "clean" and not item.is_empty():
		return maxi(activity.cash_cost, roundi(Stats.reference_price(item) * 0.08))
	return int(activity.cash_cost)


func unavailable_reason(player: Dictionary, activity: Resource, item: Dictionary = {}) -> String:
	if activity == null:
		return "That activity is not available."
	if player.area != activity.area or player.driving or Vector2(player.pos).distance_to(activity.position) > activity.radius:
		return "Park and walk up to the activity first."
	if player.ready or float(player.busy) > 0:
		return "Finish your current job before starting another."
	var cost := cash_cost(activity, item)
	if int(player.cash) < cost:
		return "You need $%d for this." % cost
	var day := int(session.clock()) / 1440
	var visit: Dictionary = player.world_visits.get(str(activity.id), {})
	if activity.once_per_run and not visit.is_empty():
		return "Already claimed this run. The staff remember you."
	var practice := bool(session.state.get("assembly_test", false))
	if int(visit.get("day", -1)) == day and activity.uses_per_day > 0 and int(visit.get("uses", 0)) >= activity.uses_per_day:
		return "Already used in this practice session. Restart practice to reset." if practice else "Come back tomorrow. Even the bin needs personal space."
	if not practice and float(visit.get("next", 0)) > session.clock():
		return "Try again in %d game minutes." % ceili(float(visit.next) - session.clock())
	if activity.kind == "lucky" and int(player.workshop_modifiers.lucky_tests) > 0:
		return "You already have a Lucky charm. It waits for your next risky test."
	if session.state.mode == "solo" and float(session.state.remaining) <= activity.minutes_cost:
		return "There is not enough time before the deadline."
	return ""


func use(pid: int, player: Dictionary, data: Dictionary) -> void:
	var activity := Activities.find(str(data.get("activity_id", "")))
	var why := unavailable_reason(player, activity)
	if why != "":
		session.notify_player(pid, why)
		return
	var selected: Dictionary = {}
	var loot: Resource
	if activity.kind == "clean":
		var item_id := int(session.number(data.get("item_id"), -99999))
		for item: Dictionary in eligible_parts(player):
			if int(item.id) == item_id:
				selected = item
		if selected.is_empty():
			session.notify_player(pid, "Choose an owned, unlisted part that has not already been serviced.")
			return
	elif activity.kind == "salvage":
		var pool := Catalog.PARTS.filter(func(part): return str(part.model_id) in activity.loot_models)
		if pool.is_empty():
			session.notify_player(pid, "The bin is empty today.")
			return
		loot = pool[session.rng.randi_range(0, pool.size() - 1)]
	# Quote again from the current owned item, never from a client-supplied fee.
	var cost := cash_cost(activity, selected)
	if int(player.cash) < cost:
		session.notify_player(pid, "You need $%d for this." % cost)
		return
	# All validation has completed. Charge, record use and grant once in one synchronous action.
	player.cash -= cost
	var day := int(session.clock()) / 1440
	var previous: Dictionary = player.world_visits.get(str(activity.id), {})
	player.world_visits[str(activity.id)] = {"day": day,
		"uses": int(previous.get("uses", 0)) + 1 if int(previous.get("day", -1)) == day else 1,
		"next": session.clock() + activity.cooldown_minutes}
	var line := str(activity.result_lines[session.rng.randi_range(0, activity.result_lines.size() - 1)]) if not activity.result_lines.is_empty() else "Done."
	match activity.kind:
		"lucky":
			player.workshop_modifiers.lucky_tests = 1
		"cooling":
			player.workshop_modifiers.cooling_bonus = activity.strength
			player.workshop_modifiers["cooling_name"] = activity.reward_name if activity.reward_name != "" else activity.display_name
			line += " %s applied: +%d rig cooling for this run." % [player.workshop_modifiers.cooling_name, activity.strength]
		"clean":
			selected.condition = mini(100, int(selected.condition) + activity.strength)
			player.serviced_parts[int(selected.id)] = true
			line += " %s: condition %d/100." % [selected.name, selected.condition]
		"salvage":
			var item := Catalog.build_listing(session.rng, loot, session.market.next_id)
			session.market.next_id += 1
			item.condition = session.rng.randi_range(activity.loot_condition.x, activity.loot_condition.y)
			item.price = 0
			item.status = "owned"
			player.inventory.append(item)
			line += " Found %s (%d/100 condition)." % [item.name, item.condition]
		"advice":
			var issues := Rig.issues(player.installed, player.tuning)
			line += " " + (issues[0] if not issues.is_empty() else "Your rig boots! Compare safe presets before gambling on more voltage.")
	if session.state.mode == "solo":
		session.advance_time(activity.minutes_cost)
	else:
		player.busy = float(activity.minutes_cost)
	session.record_event("%s visited %s." % [player.name, activity.display_name])
	session.text_player(pid, line, activity.display_name)
