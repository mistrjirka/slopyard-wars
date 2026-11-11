extends RefCounted
## Owns workbench proximity, inventory installation, tuning and finish actions.

const Overclock = preload("res://src/workshop/overclock_rules.gd")
const Config = preload("res://src/core/game_config.gd")
const RigRules = preload("res://src/workshop/rig_rules.gd")
const World = preload("res://src/world/world_rules.gd")

## Assembly damage is host-authoritative: the minigame reports a strike, the host validates and applies it.
const ASSEMBLY_MAX_STRIKES := 5
const ASSEMBLY_WEAR := 5
## Error -> the part categories it can physically happen to. PSU/GPU bracket screws are immune by design.
const ASSEMBLY_REASONS := {
	"extra_standoff": ["motherboard"],
	"socket_pins": ["motherboard"],
	"gpu_impact": ["gpu"],
	"overtighten": ["motherboard", "cpu", "ram", "storage"],
}
const ASSEMBLY_REASON_TEXT := {
	"extra_standoff": "an extra standoff",
	"socket_pins": "touching exposed socket pins",
	"gpu_impact": "forced insertion",
	"overtighten": "over-tightened screws",
}

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


func _inventory_index(p: Dictionary, id: int) -> int:
	for i in p.inventory.size():
		if int(p.inventory[i].id) == id:
			return i
	return -1


func install(pid: int, p: Dictionary, d: Dictionary) -> void:
	if busy_block(pid, p):
		return
	var id = int(session.number(d.get("item_id"), -1))
	var idx := _inventory_index(p, id)
	var item := {}
	var reinstall := false
	if idx >= 0:
		item = p.inventory[idx]
	else:
		# An owned part already mounted can be reinstalled to correct paste or cooler seating.
		for slot in p.installed:
			if int(p.installed[slot].id) == id and str(p.installed[slot].get("category", "")) == str(slot):
				item = p.installed[slot]
				reinstall = true
				break
	if item.is_empty():
		session.notify_player(pid, "You do not own that part.")
		return
	for listing in state.listings:
		if int(listing.get("owner", 0)) == pid and int(listing.get("item_id", -99999)) == id and listing.status == "available":
			session.notify_player(pid, "Cancel the sale listing before installing this part.")
			return
	var why := compatibility(item, p)
	if why != "":
		session.notify_player(pid, "Cannot install: " + why)
		return
	var cat: String = item.category
	if not reinstall and p.installed.has(cat):
		session.notify_player(pid, "Uninstall the mounted %s from Your Rig first." % cat)
		return
	var expected: int = RigRules.expected_fasteners(item)
	# Omitted counts preserve direct-install callers; explicitly malformed counts never mutate the build.
	var raw_seated: float = session.number(d.get("screws_seated", expected), -1)
	if raw_seated != floorf(raw_seated) or raw_seated < 0.0 or raw_seated > float(expected):
		session.notify_player(pid, "Invalid seated screw count.")
		return
	var seated := int(raw_seated)
	var supports := expected
	if cat == "motherboard":
		var raw_supports: float = session.number(d.get("supports", expected), -1)
		if raw_supports != floorf(raw_supports) or raw_supports < float(seated) or raw_supports > float(expected) or seated < RigRules.BOARD_MIN_SCREWS:
			session.notify_player(pid, "Not enough supported screws.")
			return
		supports = int(raw_supports)
	elif seated != expected:
		session.notify_player(pid, "Not enough screws.")
		return
	if not reinstall:
		p.inventory.remove_at(idx)
	p.installed[cat] = item
	var fasteners: Dictionary = p.workshop_modifiers.get("assembly_fasteners", {})
	var coverage := {"item_id": id, "seated": seated}
	if cat == "motherboard":
		coverage["supports"] = supports
	fasteners[cat] = coverage
	p.workshop_modifiers["assembly_fasteners"] = fasteners
	p.tuning.erase(cat)
	# Assembly is the installation work; completion must not start a second timer.
	var message := ("Reinstalled %s." if reinstall else "Installed %s.") % item.name
	if cat == "cpu":
		# Mount quality and paste coverage belong to the player's build, not to the tradeable part.
		var quality := clampf(session.number(d.get("mount_quality"), 1.0), 0.0, 1.0)
		p.workshop_modifiers["cpu_mount_quality"] = quality
		# The paste minigame reports a raw 0..3 amount; 1.0 already means "enough", more is not penalised.
		p.workshop_modifiers["cpu_paste_amount"] = clampf(session.number(d.get("paste_amount"), 1.0), 0.0, 1.0)
		if quality < 0.999:
			message += " The cooler mount is uneven (quality %d%%): expect less clock headroom and more heat." % roundi(quality * 100.0)
	var rest := build_issues(p)
	session.notify_player(pid, message + ("" if rest.is_empty() else " Still: " + rest[0]))


## Returns exactly the mounted part, including physical wear, without removing any other slot.
func uninstall(pid: int, p: Dictionary, d: Dictionary) -> void:
	if busy_block(pid, p):
		return
	var cat := str(d.get("category", ""))
	var raw_id: float = session.number(d.get("item_id"), -1)
	var item: Dictionary = p.installed.get(cat, {})
	if raw_id != floorf(raw_id) or item.is_empty() or str(item.get("category", "")) != cat or int(item.get("id", -2)) != int(raw_id):
		session.notify_player(pid, "The mounted part changed. Review Your Rig before uninstalling.")
		return
	p.installed.erase(cat)
	p.inventory.append(item)
	p.tuning.erase(cat)
	var fasteners: Dictionary = p.workshop_modifiers.get("assembly_fasteners", {})
	fasteners.erase(cat)
	p.workshop_modifiers["assembly_fasteners"] = fasteners
	if cat == "cpu":
		p.workshop_modifiers.erase("cpu_mount_quality")
		p.workshop_modifiers.erase("cpu_paste_amount")
	var rest := build_issues(p)
	session.notify_player(pid, "Uninstalled %s. Returned to inventory." % item.name + ("" if rest.is_empty() else " Still: " + rest[0]))


## Applies one reported assembly mistake to a spare or mounted part the player owns. Idempotent per strike count;
## the counter lives on the part so it survives cancelling or retrying the minigame and follows the part
## through every existing sale path (listings and handoffs duplicate the whole item dictionary).
func assembly_damage(pid: int, p: Dictionary, d: Dictionary) -> void:
	if busy_block(pid, p):
		return
	var reason := str(d.get("reason", ""))
	if not ASSEMBLY_REASONS.has(reason):
		session.notify_player(pid, "Unrecognised assembly mistake.")
		return
	var raw_strike: float = session.number(d.get("strike"), -1.0)
	if raw_strike != floorf(raw_strike) or raw_strike < 1.0 or raw_strike > float(ASSEMBLY_MAX_STRIKES):
		session.notify_player(pid, "Invalid assembly strike count.")
		return
	var strike := int(raw_strike)
	var id := int(session.number(d.get("item_id"), -1))
	var idx := _inventory_index(p, id)
	var item := {}
	var mounted_cat := ""
	if idx >= 0:
		item = p.inventory[idx]
	else:
		# Already mounted parts take damage too: a botched retry can ruin the installed part.
		for slot in p.installed:
			if int(p.installed[slot].id) == id and str(p.installed[slot].get("category", "")) == str(slot):
				item = p.installed[slot]
				mounted_cat = str(slot)
				break
	if item.is_empty():
		session.notify_player(pid, "You do not own that part.")
		return
	var cat := str(item.get("category", ""))
	if cat not in ASSEMBLY_REASONS[reason]:
		session.notify_player(pid, "That mistake cannot happen to %s." % item.name)
		return
	# The counter is checked before the listing/compatibility gates so a repeated report is a no-op.
	var current := int(item.get("assembly_strikes", 0))
	if strike <= current:
		return  # Duplicate or outdated report: damage is applied once per strike.
	if strike != current + 1:
		session.notify_player(pid, "That assembly strike no longer matches this part.")
		return
	var assembly_item_id := id
	if reason == "socket_pins":
		if mounted_cat != "motherboard":
			session.notify_player(pid, "Socket-pin damage requires the installed motherboard.")
			return
		assembly_item_id = int(session.number(d.get("assembly_item_id"), -1))
		var cpu: Dictionary = p.installed.get("cpu", {})
		var cpu_idx := _inventory_index(p, assembly_item_id)
		if cpu_idx >= 0:
			cpu = p.inventory[cpu_idx]
		if cpu.get("category") != "cpu" or int(cpu.get("id", -1)) != assembly_item_id or str(cpu.get("socket", "")) == "OX4":
			session.notify_player(pid, "Socket-pin damage requires an owned LGA CPU installation.")
			return
		var cpu_why := compatibility(cpu, p)
		if cpu_why != "":
			session.notify_player(pid, "Cannot assemble: " + cpu_why)
			return
	for listing in state.listings:
		if int(listing.get("owner", 0)) == pid and int(listing.get("item_id", -99999)) in [id, assembly_item_id] and listing.status == "available":
			session.notify_player(pid, "Cancel the sale listing before working on this part.")
			return
	var why := compatibility(item, p)
	if why != "":
		session.notify_player(pid, "Cannot assemble: " + why)
		return
	item["assembly_strikes"] = strike
	# Count accepted reports, including the fatal strike, independently of the part's previous owner.
	p.workshop_modifiers["assembly_mistakes"] = int(p.workshop_modifiers.get("assembly_mistakes", 0)) + 1
	var cause: String = ASSEMBLY_REASON_TEXT[reason]
	if strike >= ASSEMBLY_MAX_STRIKES:
		if mounted_cat != "":
			# Destroying the mounted part leaves nothing behind: no spare appears in the inventory.
			p.installed.erase(mounted_cat)
			p.tuning.erase(mounted_cat)
		else:
			p.inventory.remove_at(idx)
		p.destroyed.append(item.name)
		session.record_event("%s wrecked %s while assembling (%s, strike %d/%d)." % [p.name, item.name, cause, strike, ASSEMBLY_MAX_STRIKES])
		session.notify_player(pid, "%s is destroyed: %s caused the final defect on strike %d/%d. The part is gone for good." % [item.name, cause, strike, ASSEMBLY_MAX_STRIKES])
		return
	item["condition"] = maxi(1, int(item.get("condition", 100)) - ASSEMBLY_WEAR)
	var left := ASSEMBLY_MAX_STRIKES - strike
	session.record_event("%s damaged %s while assembling (%s, strike %d/%d)." % [p.name, item.name, cause, strike, ASSEMBLY_MAX_STRIKES])
	session.notify_player(pid, "%s took damage from %s: strike %d/%d, condition %d/100. %d more strike%s will destroy it." % [item.name, cause, strike, ASSEMBLY_MAX_STRIKES, int(item.condition), left, "" if left == 1 else "s"])


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
