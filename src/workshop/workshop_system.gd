extends RefCounted
## Owns workbench proximity, inventory installation, tuning and finish actions.

const Overclock = preload("res://src/workshop/overclock_rules.gd")
const Config = preload("res://src/core/game_config.gd")
const RigRules = preload("res://src/workshop/rig_rules.gd")
const World = preload("res://src/world/world_rules.gd")

var session: Node
var state: Dictionary:
	get:
		return session.state


func _init(game_session: Node) -> void:
	session = game_session


func compatibility(item: Dictionary, player: Dictionary) -> String:
	if item.is_empty() or not player.has("installed"):
		return "Unknown part"
	var rest: Dictionary = player.installed.duplicate()
	rest.erase(item.get("category", ""))
	return RigRules.compat(item, rest)


func build_issues(player: Dictionary) -> Array[String]:
	return RigRules.issues(player.get("installed", {}), player.get("tuning", {}))


func preview_score(player: Dictionary) -> Dictionary:
	return RigRules.score(player.get("installed", {}), player.get("tuning", {}), str(state.objective), player.get("workshop_modifiers", {}))


func busy_block(pid: int, p: Dictionary) -> bool:
	if p.area != "home" or p.pos.distance_to(World.BENCH) > 58:
		session.notify_player(pid, "Return home and walk to the workbench first.")
		return true
	if p.busy > 0.0:
		session.notify_player(pid, "Workbench busy for %d more game minutes." % ceili(p.busy))
		return true
	return false


func install(pid: int, p: Dictionary, d: Dictionary) -> void:
	if busy_block(pid, p):
		return
	var id = int(session.number(d.get("item_id"), -1))
	var idx := -1
	for i in p.inventory.size():
		if p.inventory[i].id == id:
			idx = i
	if idx < 0:
		session.notify_player(pid, "You do not own that part.")
		return
	var item: Dictionary = p.inventory[idx]
	for listing in state.listings:
		if int(listing.get("owner", 0)) == pid and int(listing.get("item_id", -99999)) == id and listing.status == "available":
			session.notify_player(pid, "Cancel the sale listing before installing this part.")
			return
	var why := compatibility(item, p)
	if why != "":
		session.notify_player(pid, "Cannot install: " + why)
		return
	p.inventory.remove_at(idx)
	var cat: String = item.category
	if p.installed.has(cat):
		p.inventory.append(p.installed[cat])
	p.installed[cat] = item
	p.tuning.erase(cat)
	p.busy = Config.INSTALL_MIN
	var rest := build_issues(p)
	session.notify_player(pid, "Installed %s." % item.name + ("" if rest.is_empty() else " Still: " + rest[0]))


func tune(pid: int, p: Dictionary, d: Dictionary) -> void:
	if busy_block(pid, p):
		return
	var cat := str(d.get("category", ""))
	if cat not in RigRules.TUNABLE or not p.installed.has(cat):
		session.notify_player(pid, "Install a CPU, GPU or RAM before tuning it.")
		return
	var clock = snappedf(clampf(session.number(d.get("clock"), 1.0), 1.0, 1.6), 0.01)
	var volt = snappedf(clampf(session.number(d.get("voltage"), 1.0), 1.0, 1.6), 0.01)
	var item: Dictionary = p.installed[cat]
	var modifiers: Dictionary = p.get("workshop_modifiers", {})
	var result := Overclock.evaluate(item, clock, volt, p.installed, modifiers)
	if d.has("item_id") and int(session.number(d.item_id, -99999)) != int(item.id):
		session.notify_player(pid, "The part changed. Review the new stress-test estimate first.")
		return
	if d.has("risk_quote") and absf(float(session.number(d.risk_quote, -1)) - float(result.damage_chance)) > 0.001:
		session.notify_player(pid, "The risk changed. Review the updated estimate before testing.")
		return
	p.busy = Config.TUNE_MIN
	_resolve_test(pid, p, cat, clock, volt, result)


func _resolve_test(pid: int, p: Dictionary, cat: String, clock: float, volt: float, result: Dictionary) -> void:
	var item: Dictionary = p.installed[cat]
	var modifiers: Dictionary = p.get("workshop_modifiers", {})
	if result.uses_luck:
		modifiers.lucky_tests = maxi(0, int(modifiers.get("lucky_tests", 0)) - 1)
	var failure := Overclock.failure_mode(result, session.rng.randf())
	if failure != "":
		p.installed.erase(cat)
		p.tuning.erase(cat)
		p.destroyed.append(item.name)
		p["last_stress_test"] = {"part": item.name, "category": cat, "destroyed": true, "risk": result.damage_chance,
			"failure_mode": failure, "fire_risk": result.fire_chance}
		if failure == "fire":
			session.record_event("%s's %s caught fire at the power connector (%.1f%% fire risk)." % [p.name, item.name, result.fire_chance * 100])
			session.notify_player(pid, "FIRE! %s is permanently destroyed. The connector has unlocked Dragon Breath mode. Fire chance was %.1f%%; the rest of the rig is intact." % [item.name, result.fire_chance * 100])
			return
		session.record_event("%s released the magic smoke from %s (%.1f%% risk)." % [p.name, item.name, result.damage_chance * 100])
		session.notify_player(pid, "BANG! %s is permanently destroyed. The test had a %.1f%% failure chance. The smoke is not an upgrade." % [item.name, result.damage_chance * 100])
		return
	item["condition"] = maxi(1, int(item.get("condition", 100)) - int(result.wear))
	p.tuning[cat] = {"clock": clock, "voltage": volt}
	p["last_stress_test"] = {"part": item.name, "destroyed": false, "risk": result.damage_chance}
	var message := "%s survived: clock %.2fx / voltage %.2fx. %.1f%% risk; condition now %d/100." % [item.name, clock, volt, result.damage_chance * 100, item.condition]
	if clock > float(result.stable_clock) + 0.0005:
		message += " Unstable clocks reduce the score. Try the safe preset."
	if result.wear > 0:
		message += " Pushing your luck wore the part down."
	session.notify_player(pid, message)



## Resolve the final benchmark once, including when the deadline or disconnect finishes a rig.
func final_score(pid: int, p: Dictionary) -> Dictionary:
	if not p.get("benchmark_checked", false):
		p["benchmark_checked"] = true
		if build_issues(p).is_empty():
			for test: Dictionary in Overclock.final_tests(p.installed, p.tuning, p.workshop_modifiers):
				if not build_issues(p).is_empty():
					break
				_resolve_test(pid, p, test.category, test.clock, test.voltage, test.result)
	return preview_score(p)


func finish(pid: int, p: Dictionary) -> void:
	if busy_block(pid, p):
		return
	p.ready = true
	p.score = final_score(pid, p)
	session.record_event("%s finished their rig." % p.name)
	session.check_all_ready()
