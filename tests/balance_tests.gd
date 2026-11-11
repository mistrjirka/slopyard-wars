extends RefCounted
## Economy outcomes: attainable builds, real services/trades, meaningful upgrades
## and comparable personal bests. Never calls the dialogue provider.
const Catalog = preload("res://src/data/catalog.gd")
const Stats = preload("res://src/data/hardware_stats.gd")
const Rig = preload("res://src/workshop/rig_rules.gd")
const Overclock = preload("res://src/workshop/overclock_rules.gd")
const Activities = preload("res://src/world/activities.gd")
const Characters = preload("res://src/data/characters.gd")
const Store = preload("res://src/core/score_store.gd")
const World = preload("res://src/world/world_rules.gd")
const K = preload("res://src/ui/ui_kit.gd")
const Config = preload("res://src/core/game_config.gd")
var game: Node
var check: Callable


func run(session: Node, assertion: Callable) -> void:
	game = session
	check = assertion
	_supply()
	_market()
	_services()
	_benchmarks()
	_runs()
	_records()
	await _service_interface()


func fresh(budget: int = 1000, days: int = 2) -> Dictionary:
	game.solo("Balance Test", budget, "Balanced", days)
	game.set_process(false)
	game.set_physics_process(false)
	return game.me()


func item(model: String, id: int = 9000) -> Dictionary:
	var template: Resource = Catalog.PARTS.filter(func(part): return str(part.model_id) == model)[0]
	var part := Catalog.build_listing(game.rng, template, id)
	part.condition = 90
	return part


func rig(models: Array) -> Dictionary:
	var installed := {}
	for model: String in models:
		var part := item(model, 9000 + installed.size())
		installed[part.category] = part
	return installed


func _supply() -> void:
	var worst := 0
	for seed_value in 32:
		game.rng.seed = seed_value
		fresh(600)
		var cost := Rig.cheapest_build(game.state.listings)
		worst = maxi(worst, cost)
		check.call(cost > 0 and cost <= 450, "Seed %d leaves at least $150 of the minimum budget beyond a working rig" % seed_value)
		for socket: String in ["OX3", "OX4", "NX5", "LX7"]:
			var stock: Array = game.state.listings.filter(func(part): return part.category not in ["cpu", "motherboard"] or part.socket == socket)
			check.call(Rig.cheapest_build(stock) > 0, "Seed %d has a complete %s upgrade path" % [seed_value, socket])
	print("BALANCE: worst cheapest initial rig across 32 seeds: $%d / $600" % worst)


func _market() -> void:
	var player := fresh()
	var part := item("luckyforce_ltx_5080")
	part.condition = 30
	var worn := Stats.reference_price(part)
	part.condition = 100
	check.call(worn < Stats.reference_price(part) * 0.5, "Heavily worn premium parts lose more than half their resale value")
	for template: Resource in Catalog.PARTS:
		var listing := Catalog.build_listing(game.rng, template, 1)
		var guide := Stats.reference_price(listing)
		check.call(listing.price >= roundi(guide * 0.85) and listing.price <= roundi(guide * 1.20), "Asking price follows actual unit condition: " + str(template.model_id))
	# Mean normal offers should not create a guaranteed profit on ordinary stock.
	var buyer_sum := 0.0
	for contact: Resource in Characters.ALL:
		buyer_sum += (contact.buyer_budget_range.x + contact.buyer_budget_range.y) / 2.0
	check.call(buyer_sum / Characters.ALL.size() < 1.0, "Average buyer valuation leaves profit to bargain hunting rather than every purchase")
	# Keep ordinary stock alive through repeated refreshes. Even repeated cuts
	# must stop above a viable used-price floor; agreed prices cannot change.
	var protected: Dictionary = game.state.listings[0]
	player.offers[protected.id] = protected.price
	var agreed: int = protected.price
	for refresh in 60:
		game.market.refresh()
		for listing: Dictionary in game.state.listings:
			if listing.status != "available" or int(listing.get("owner", 0)) > 0:
				continue
			check.call(listing.price >= maxi(5, roundi(Stats.reference_price(listing) * 0.75)), "Repeated refreshes cannot collapse used prices")
	check.call(protected.status == "available" and protected.price == agreed and player.offers[protected.id] == agreed, "Bargained listings retain their price across refreshes")
	# The spare remains a real catch-up source of cash, paid only at a handoff.
	var spare: Dictionary = player.inventory[0]
	var cash: int = player.cash
	game.act("post_sale", {"item_id": spare.id, "price": Stats.sale_guide(spare).quick})
	var sale: Dictionary = game.state.listings[-1]
	check.call(player.cash == cash and sale.buyer_contacted, "A quick-priced spare attracts interest without granting money early")
	player.offers[sale.id] = sale.first_offer
	player.meetings[sale.id] = {"start": game.clock(), "end": game.clock() + 90, "pos": sale.pos, "place": sale.location}
	player.area = "town"
	player.pos = game.market.meeting_position(player.meetings[sale.id])
	game.act("handoff", {"listing_id": sale.id})
	game.act("handoff", {"listing_id": sale.id})
	check.call(player.cash == cash + sale.first_offer and not player.inventory.has(spare), "Selling worn spares still earns cash exactly once")


func _services() -> void:
	var player := fresh()
	var clinic := Activities.find("dust_busters")
	var paste := Activities.find("paste_club")
	var part := item("luckyforce_ltx_5090")
	part.condition = 60
	player.inventory.append(part)
	player.area = "town"
	player.pos = clinic.position + Vector2(0, 24)
	var fee: int = game.activities.cash_cost(clinic, part)
	check.call(fee > game.activities.cash_cost(clinic, player.inventory[0]), "Premium hardware costs more to service than the starter spare")
	player.cash = fee - 1
	var before: float = game.state.remaining
	game.act("world_activity", {"activity_id": clinic.id, "item_id": part.id, "cash_cost": 0})
	check.call(player.cash == fee - 1 and part.condition == 60 and not player.serviced_parts.has(part.id) and game.state.remaining == before, "Unaffordable service cannot charge, restore condition or consume time/use")
	player.cash = fee
	game.act("world_activity", {"activity_id": clinic.id, "item_id": part.id, "cash_cost": 0})
	check.call(player.cash == 0 and part.condition == 72 and player.serviced_parts.has(part.id), "Service charges the host quote and restores the chosen part")
	check.call(game.state.remaining == before - clinic.minutes_cost, "Service deducts the advertised time")
	player.pos = paste.position + Vector2(0, 24)
	player.cash = paste.cash_cost - 1
	game.act("world_activity", {"activity_id": paste.id})
	check.call(player.workshop_modifiers.cooling_bonus == 0, "Premium paste cannot be purchased without its full fee")
	player.cash = paste.cash_cost
	game.act("world_activity", {"activity_id": paste.id})
	check.call(player.cash == 0 and player.workshop_modifiers.cooling_bonus == paste.strength, "Premium paste remains a purchasable once-per-run preparation")


func _benchmarks() -> void:
	var budget := rig(["tin_can_matx", "ampere_350w", "voltra_v4_b250_matx", "nimbus_n4_1200", "quill_8gb_ddr4_2400", "flashy_120gb_sata_ssd"])
	check.call(Rig.score(budget, {}, "Balanced").valid, "Entry rig works without paste, servicing or a shrine visit")
	var stock := Rig.score(budget, {}, "Balanced")
	check.call(stock == Rig.score(budget, {}, "Balanced", {"cooling_bonus": 12}), "Paid premium paste is optional and adds no stock score")
	var high := rig(["glasshouse_atx_rgb", "titanforge_1000w", "voltra_v4_z390_ultra_atx", "nimbus_n4_1200", "quill_8gb_ddr4_2400", "flashy_120gb_sata_ssd"])
	var low_tune := Overclock.safe_preset(budget.cpu, budget)
	var high_tune := Overclock.safe_preset(high.cpu, high)
	check.call(high_tune.clock >= low_tune.clock + 0.02, "Investment in case, board and supply earns visible safe clock headroom")
	var tuned := Overclock.evaluate(high.cpu, high_tune.clock, high_tune.voltage, high)
	var cooled := Overclock.evaluate(high.cpu, high_tune.clock, high_tune.voltage, high, {"cooling_bonus": 12})
	check.call(cooled.temperature < tuned.temperature and cooled.stable_clock > tuned.stable_clock, "Premium paste still improves an enthusiast rig's cooling and headroom")
	check.call(Rig.power_draw(budget, {"cpu": {"clock": 1.2, "voltage": 1.3}}) > Rig.power_draw(budget, {}), "Overclocking draws extra supply capacity")
	# Equal-budget illustrative builds: replace weak subsystems rather than just
	# adding the most expensive storage drive to the cheapest possible platform.
	var balanced := rig(["tin_can_matx", "ampere_350w", "voltra_v4_b250_matx", "nimbus_n4_2700x", "quill_32gb_ddr4_3600", "bolt_1tb_nvme_gen4", "arcadia_a580"])
	var drive_only := rig(["tin_can_matx", "ampere_350w", "voltra_v3_a55_matx", "kestrel_k3_2200", "quill_4gb_ddr3_1333", "bolt_2tb_nvme_gen5"])
	check.call(Rig.score(balanced, {}, "Balanced").total > Rig.score(drive_only, {}, "Balanced").total, "Balanced objective rewards improving the whole rig over a single top drive")
	check.call(Rig.score(drive_only, {}, "Storage").total > Rig.score(drive_only, {}, "GPU").total, "A specialized objective still rewards the chosen subsystem")
	var one := budget.duplicate(true)
	one.cpu.cpu = Rig.REF.cpu
	var two := one.duplicate(true)
	two.cpu.cpu *= 2.0
	var three := two.duplicate(true)
	three.cpu.cpu *= 1.5
	var first_gain: int = Rig.score(two, {}, "CPU").total - Rig.score(one, {}, "CPU").total
	var next_gain: int = Rig.score(three, {}, "CPU").total - Rig.score(two, {}, "CPU").total
	check.call(first_gain > next_gain and next_gain > 0, "Extra performance always rewards the player, with diminishing returns")
	# Roll a short session's worth of tests across many repeatable seeds. Fire
	# and CPU faults now occur often enough to be observed, without affecting
	# unaffected models or previews.
	for model: String in ["luckyforce_ltx_4090", "luckyforce_ltx_5090", "luckycore_l7_13700l", "luckycore_l9_14900l"]:
		var part := item(model)
		var result := Overclock.evaluate(part, 1, 1, high)
		var random := RandomNumberGenerator.new()
		random.seed = 456
		var failures := 0
		for attempt in 1000:
			if Overclock.failure_mode(result, random.randf()) != "":
				failures += 1
		check.call(failures >= 75 and failures <= 450, "Authored defects are observable in ordinary tests: " + model)
		check.call(Overclock.evaluate(part, 1, 1, high, {"lucky_tests": 1}).damage_chance < result.damage_chance, "A shrine blessing remains useful for " + model)


func _records() -> void:
	# Deliberately isolate files, and exercise actual game completion/loading.
	var previous_path: String = game.score_path
	game.score_path = "res://artifacts/balance_scores.json"
	Store.save_best({"Balanced": 99999}, game.score_path)
	var player := fresh(600)
	check.call(player.best == 0, "Old-economy high scores remain saved without blocking new records")
	player.installed = rig(["tin_can_matx", "ampere_350w", "voltra_v3_a55_matx", "kestrel_k3_2200", "quill_4gb_ddr3_1333", "spindle_500gb_hdd"])
	player.pos = World.BENCH + Vector2(0, 24)
	game.act("finish")
	var earned: int = player.score.total
	check.call(earned > 0 and player.new_best and Store.load_best(game.score_path).get(Store.key("Balanced", 600, 2)) == earned, "A completed budget rig earns a comparable, persistent best")
	player = fresh(600)
	check.call(player.best == earned and not player.new_best, "Replay loads its own record and resets the new-best flag")
	player = fresh(1000)
	check.call(player.best == 0, "A larger budget has its own personal best")
	player = fresh(600, 1)
	check.call(player.best == 0 and Store.load_best(game.score_path).Balanced == 99999, "A shorter run has its own best and preserves legacy records")
	game.score_path = previous_path


func _chat_now(listing_id: int, message: String) -> void:
	game.act("chat", {"listing_id": listing_id, "text": message})
	if game.dialogue.pending_by.has(1):
		# Use the normal validated offline reply immediately; the provider's
		# presentation timer is tested elsewhere and is irrelevant to balance.
		game.dialogue.receive_reply(int(game.dialogue.pending_by[1]), false, {}, "")


func _runs() -> void:
	for budget: int in [600, 1000]:
		game.rng.seed = 819
		var player := fresh(budget, 1)
		var plan: Array = []
		var limits := {"motherboard": 110, "cpu": 220 if budget == 1000 else 125,
			"ram": 100 if budget == 1000 else 65, "storage": 150 if budget == 1000 else 75,
			"psu": 100, "gpu": 200}
		for category: String in ["motherboard", "cpu", "ram", "storage", "psu", "gpu"]:
			if category == "gpu" and budget == 600:
				continue
			var candidates: Array = game.state.listings.filter(func(part):
				if part.category != category or part.status != "available" or part.price > limits[category]:
					return false
				if category in ["cpu", "motherboard"]:
					return part.socket == "OX4" and part.integrated and part.form != "ATX"
				if category == "ram":
					return part.memory == "DDR4"
				return true)
			candidates.sort_custom(func(a, b):
				return a.price < b.price if category in ["motherboard", "psu"] else Stats.stock_score(a) > Stats.stock_score(b))
			check.call(not candidates.is_empty(), "A $%d run can source its %s within the planned allowance" % [budget, category])
			if candidates.is_empty():
				return
			plan.append(candidates[0])
		var bill := 0
		for listing: Dictionary in plan:
			bill += int(listing.price)
			if Characters.for_listing(listing).requires_conversation:
				_chat_now(listing.id, "How are you?")
			_chat_now(listing.id, "I'll pay $%d" % listing.price)
			check.call(player.offers.has(listing.id), "Full asking price can be agreed in the offline loop")
			var options: Array = game.contact_options(listing)
			check.call(not options.is_empty(), "Planned purchase has a canonical pickup window")
			if options.is_empty():
				return
			game.act("choose_meeting", {"listing_id": listing.id, "meeting_id": options[0].id, "match_id": game.state.match_id})
			check.call(player.meetings.has(listing.id), "Shopping run confirms its appointments through the normal action")
		check.call(bill <= budget - 30, "A $%d shopping plan retains a travel/recovery reserve at full asking prices" % budget)
		plan.sort_custom(func(a, b): return player.meetings[a.id].start < player.meetings[b.id].start)
		for listing: Dictionary in plan:
			var meeting: Dictionary = player.meetings[listing.id]
			# Allow ten game minutes between each pickup plus any wait. World
			# collision/pathfinding and physical assembly are tested separately.
			game.advance_time(maxf(0, float(meeting.start) - game.clock()) + 10)
			player.area = "town"
			player.pos = game.market.meeting_position(meeting)
			game.act("handoff", {"listing_id": listing.id})
			check.call(listing.status == "sold", "Shopping plan can physically collect its part before the window closes")
		game.advance_time(20)
		player.area = "home"
		player.pos = World.BENCH + Vector2(0, 24)
		for category: String in ["case", "motherboard", "cpu", "ram", "psu", "storage", "gpu"]:
			var owned: Array = player.inventory.filter(func(part): return part.category == category)
			if not owned.is_empty():
				game.act("install", {"item_id": owned[0].id})
		check.call(game.build_issues(player).is_empty(), "Shopping plan becomes a complete compatible powered rig")
		for category: String in ["cpu", "ram", "gpu"]:
			if not player.installed.has(category):
				continue
			var preset := Overclock.safe_preset(player.installed[category], player.installed)
			var proposed: Dictionary = player.tuning.duplicate(true)
			proposed[category] = preset
			# A destruction-free setting can still need a larger PSU. Keep stock
			# for this component when the planned supply lacks the extra capacity.
			if not Rig.issues(player.installed, proposed).is_empty():
				preset = {"clock": 1.0, "voltage": 1.0}
			game.act("tune", {"category": category, "clock": preset.clock, "voltage": preset.voltage})
			game.advance_time(Config.TUNE_MIN)
			check.call(game.build_issues(player).is_empty(), "Shopping run keeps its tuning within the installed PSU capacity")
		game.act("finish")
		check.call(game.state.phase == "results" and player.score.total > 0 and player.cash == budget - bill, "A $%d run can buy, collect, assemble, tune and finish within one day without paid preparations" % budget)
		print("BALANCE RUN: $%d, spent $%d, cash $%d, score %d, finished at minute %d" % [budget, bill, player.cash, player.score.total, int(game.clock())])


func _service_interface() -> void:
	var player := fresh()
	player.area = "town"
	var clinic := Activities.find("dust_busters")
	player.pos = clinic.position + Vector2(0, 24)
	var premium := item("luckyforce_ltx_5090")
	premium.condition = 60
	player.inventory.append(premium)
	for resolution: Vector2i in [Vector2i(1152, 720), Vector2i(1440, 900)]:
		var viewport := SubViewport.new()
		viewport.size = resolution
		game.get_tree().root.add_child(viewport)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.theme = K.make_theme()
		viewport.add_child(center)
		var dialog: Control = load("res://src/ui/activity_dialog.tscn").instantiate()
		center.add_child(dialog)
		dialog.setup(clinic)
		dialog._choice.select(1)
		dialog._choice.item_selected.emit(1)
		for frame in 4:
			await game.get_tree().process_frame
		check.call(dialog._cost.text.begins_with("$%d" % game.activities.cash_cost(clinic, premium)) and dialog._cost.text.contains("60 → 72"), "Service chooser displays the selected part's real fee and improvement")
		check.call(dialog.size.x <= resolution.x and dialog.size.y <= resolution.y, "Quoted service fits %dx%d" % [resolution.x, resolution.y])
		player.cash = 15
		dialog._choice.item_selected.emit(1)
		check.call(dialog._use_button.disabled and dialog._reason.text.contains("You need"), "Service chooser disables an unaffordable premium quote")
		dialog._choice.select(0)
		dialog._choice.item_selected.emit(0)
		check.call(not dialog._use_button.disabled, "Switching back to an affordable spare updates the service action")
		player.cash = 1000
		viewport.queue_free()
		await game.get_tree().process_frame
