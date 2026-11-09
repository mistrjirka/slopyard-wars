extends RefCounted
## New content and mechanics: no provider calls, deterministic damage rolls.
const Characters = preload("res://src/data/characters.gd")
const Catalog = preload("res://src/data/catalog.gd")
const Stats = preload("res://src/data/hardware_stats.gd")
const Overclock = preload("res://src/workshop/overclock_rules.gd")
const Activities = preload("res://src/world/activities.gd")
const World = preload("res://src/world/world_rules.gd")
const Trade = preload("res://src/trading/trade_rules.gd")
const Rig = preload("res://src/workshop/rig_rules.gd")
const Art = preload("res://src/ui/art_library.gd")
var game: Node
var check: Callable


func run(session: Node, assertion: Callable) -> void:
	game = session
	check = assertion
	_characters()
	_hardware()
	_resale_condition()
	_overclocking()
	_stock_reliability()
	_gpu_fires()
	_activities()
	await _interfaces()


func fresh() -> Dictionary:
	game.solo("Content Test", 1000, "Balanced")
	game.set_process(false)
	game.set_physics_process(false)
	return game.me()


func _characters() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 3
	var ids := {}
	var greetings := {}
	for character: Resource in Characters.ALL:
		check.call(not ids.has(character.id), "Character IDs are unique: " + str(character.id))
		ids[character.id] = true
		check.call(character.system_prompt.length() > 120 and character.tagline != "", "Character has a usable authored voice: " + character.display_name)
		for place: String in character.meeting_places:
			check.call(Catalog.LOCATIONS.has(place), "Character meeting place exists: " + place)
		for hours: Vector2i in character.hours:
			check.call(hours.x >= 0 and hours.x < hours.y and hours.y <= 24, "Character schedule is valid")
		var listing := Catalog.build_listing(random, Catalog.PARTS[0], 100)
		listing.character_id = str(character.id)
		listing.seller = character.display_name
		listing.location = character.meeting_places[0]
		var request: Dictionary = game.seller._body(listing, [], "Hello")
		var prompt: String = request.messages[0].content
		check.call(prompt.contains(character.system_prompt), "LLM receives the selected character's full system prompt")
		check.call(prompt.contains("Condition") and prompt.contains("Verified hardware notes"), "LLM gets factual hardware context")
		var reply: Dictionary = game.seller.offline_decision(listing, "Is it still available?", 0)
		greetings[reply.text] = true
		var options := Trade.options(character.display_name, listing.location, Trade.START)
		check.call(not options.is_empty(), "Each contact has feasible appointments")
		for option: Dictionary in options:
			check.call(str(option.place) in character.meeting_places, "Appointment respects authored meeting places")
	check.call(greetings.size() == Characters.ALL.size(), "Offline characters retain distinct greetings")


func _hardware() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 8
	var ids := {}
	var families := {}
	var forbidden := RegEx.create_from_string("(?i)\\b(nvidia|amd|geforce|radeon|gtx|rtx|rx)\\b")
	for part: Resource in Catalog.PARTS:
		check.call(not ids.has(part.model_id) and str(part.model_id) != "", "Hardware model IDs are stable and unique")
		ids[part.model_id] = true
		check.call(forbidden.search(part.display_name) == null, "Hardware uses fictional branding: " + part.display_name)
		check.call(part.manufacturer != "" and part.product_family != "", "Manufacturer and product family are editable fields")
		families[part.product_family] = true
		var item := Catalog.build_listing(random, part, ids.size())
		check.call(item.condition >= part.condition_min and item.condition <= part.condition_max, "Per-unit condition respects model bounds")
		check.call(Catalog.spec_text(item).contains("Condition") and Catalog.spec_text(item).contains("guide"), "Every purchasable category has condition and value notes")
		var pristine: Dictionary = item.duplicate(true)
		pristine.condition = 100
		check.call(Stats.stock_score(pristine) >= Stats.stock_score(item), "Wear never improves stock performance")
		if item.category in Rig.TUNABLE:
			var installed := {item.category: item}
			var preset := Overclock.safe_preset(item, installed)
			var result := Overclock.evaluate(item, preset.clock, preset.voltage, installed)
			var stock_risk := 1.0 - (1.0 - Stats.stock_failure_chance(item)) * (1.0 - Stats.stock_fire_chance(item))
			check.call(is_equal_approx(result.damage_chance, stock_risk), "Conservative preset adds no risk beyond the model flaw: " + item.name)
			check.call(is_equal_approx(Overclock.evaluate(item, 1, 1, installed).damage_chance, stock_risk), "Stock respects authored reliability")
			check.call(Overclock.evaluate(item, 1.6, 1.41, installed).damage_chance == 1, "Hard overvoltage always destroys hardware")
	check.call(families.has("LuckyForce") and families.has("Ladeon") and families.has("LuckyZen") and families.has("LuckyCore"), "Requested fictional families are present")
	for number in ["4090", "5060", "5070", "5080", "5090", "9060", "9070", "750", "1060", "1660"]:
		check.call(Catalog.PARTS.any(func(part): return number in part.display_name), "Catalogue includes modern and older series " + number)
	check.call(Catalog.PARTS.any(func(part): return part.display_name == "LuckyZen 7 5800X5D"), "Older cache-focused CPU uses X5D suffix")
	check.call(Catalog.PARTS.any(func(part): return part.display_name == "LuckyZen 9 7950X5D"), "Newer cache-focused CPU uses X5D suffix")
	check.call(Catalog.PARTS.any(func(part): return part.display_name == "LuckyCore L7-4790L"), "Unlocked LuckyCore uses L suffix")


func _resale_condition() -> void:
	var player := fresh()
	var item: Dictionary = player.inventory[0]
	item.reference_base = 400
	# Ignore stale legacy data: market value must use the item's current condition.
	item["reference_price"] = 9999
	item.condition = 20
	game.rng.seed = 42
	game.act("post_sale", {"item_id": item.id, "price": 400})
	var worn: Dictionary = game.state.listings[-1]
	var buyer := Characters.for_listing(worn)
	check.call(int(worn.buyer_max) <= int(Stats.reference_price(item) * buyer.buyer_budget_range.y), "Buyer valuation uses current condition, not cached value")
	game.act("cancel_sale", {"listing_id": worn.id})
	item.condition = 100
	game.rng.seed = 42
	game.act("post_sale", {"item_id": item.id, "price": 400})
	check.call(game.state.listings[-1].buyer_max > worn.buyer_max, "Same buyer values a healthy part more than a worn one")


func _overclocking() -> void:
	var player := fresh()
	var item: Dictionary = game.state.listings.filter(func(part): return part.category == "cpu")[0].duplicate(true)
	item.condition = 90
	player.installed.cpu = item
	player.pos = World.BENCH + Vector2(0, 30)
	var before := item.duplicate(true)
	var risk := Overclock.evaluate(item, 1.4, 1.32, player.installed)
	var lucky := Overclock.evaluate(item, 1.4, 1.32, player.installed, {"lucky_tests": 1})
	check.call(risk.damage_chance > 0 and risk.damage_chance < 1, "Moderate overclock has a genuine probability, not just a threshold")
	check.call(is_equal_approx(lucky.damage_chance, risk.damage_chance * 0.75), "Lucky blessing reduces probability by exactly 25 percent")
	check.call(Overclock.evaluate(item, 1.4, 1.41, player.installed, {"lucky_tests": 1}).damage_chance == 1, "Lucky cannot bypass the hard limit")
	var cooler := Overclock.evaluate(item, 1.4, 1.32, player.installed, {"cooling_bonus": 12})
	check.call(cooler.temperature < risk.temperature and cooler.damage_chance <= risk.damage_chance, "Cooling upgrade improves thermal margin")
	var worn: Dictionary = item.duplicate(true)
	worn.condition = 40
	check.call(Overclock.evaluate(worn, 1.4, 1.32, player.installed).damage_chance >= risk.damage_chance, "Worn parts are no safer than healthy ones")
	check.call(item == before, "Risk previews never mutate hardware")
	check.call(Overclock.fails(0.3, 0.2) and not Overclock.fails(0.3, 0.4) and not Overclock.fails(0, 0), "Damage roll respects its probability boundary")
	game.act("tune", {"category": "cpu", "clock": 1.4, "voltage": 1.32, "risk_quote": 0.0})
	check.call(player.busy == 0 and player.tuning.is_empty(), "Stale risk confirmation is refused without consuming time")
	game.act("tune", {"category": "cpu", "clock": 1.4, "voltage": 1.32, "risk_quote": NAN})
	check.call(player.busy == 0, "Non-finite risk quotes are rejected")
	player.workshop_modifiers.lucky_tests = 1
	game.act("tune", {"category": "cpu", "clock": 1.0, "voltage": 1.0})
	check.call(player.workshop_modifiers.lucky_tests == 1 and item.condition == 90, "Safe tests preserve blessing and condition")
	player.busy = 0
	_seed_for(float(lucky.damage_chance), false)
	game.act("tune", {"category": "cpu", "clock": 1.4, "voltage": 1.32})
	check.call(player.installed.has("cpu") and item.condition < 90, "Survived risky tests cause lasting wear")
	check.call(player.workshop_modifiers.lucky_tests == 0, "Risky test consumes exactly one blessing")
	player.busy = 0
	risk = Overclock.evaluate(item, 1.4, 1.32, player.installed)
	_seed_for(float(risk.damage_chance), true)
	game.act("tune", {"category": "cpu", "clock": 1.4, "voltage": 1.32})
	check.call(not player.installed.has("cpu") and player.destroyed.has(item.name), "Host probabilistic failure actually removes the part")


func _stock_reliability() -> void:
	var fault_rates := {"luckycore_l7_13700l": 0.12, "luckycore_l9_13900l": 0.18,
		"luckycore_l7_14700l": 0.15, "luckycore_l9_14900l": 0.22}
	for model: String in fault_rates:
		var player := _reliability_rig(model)
		var item: Dictionary = player.installed.cpu
		var stock := Overclock.evaluate(item, 1, 1, player.installed)
		check.call(is_equal_approx(stock.damage_chance, fault_rates[model]), "Pristine faulty CPU has its authored stock failure rate")
		check.call(game.preview_score(player).valid, "Added CPU has a compatible playable platform")
		check.call(Catalog.spec_text(item).contains("RELIABILITY WARNING"), "Listings disclose stock reliability risk")
		var preset := Overclock.safe_preset(item, player.installed)
		check.call(preset.clock == 1 and preset.voltage == 1, "Faulty CPU conservative preset falls back to stock")
		var lucky := Overclock.evaluate(item, 1, 1, player.installed, {"lucky_tests": 1})
		check.call(is_equal_approx(lucky.damage_chance, stock.damage_chance * 0.75) and lucky.uses_luck, "Lucky can reduce the stock reliability risk")
		check.call(is_equal_approx(Overclock.evaluate(item, 1, 1, player.installed, {"cooling_bonus": 100}).damage_chance, stock.damage_chance), "Cooling cannot remove a model reliability flaw")
		item.condition = 40
		check.call(Overclock.evaluate(item, 1, 1, player.installed).damage_chance > stock.damage_chance, "Wear worsens faulty-model stock reliability")
	for model in ["luckycore_l7_12700l", "luckycore_l9_12900l", "luckycore_l5_13400", "luckycore_l5_14400"]:
		var player := _reliability_rig(model)
		check.call(Overclock.evaluate(player.installed.cpu, 1, 1, player.installed).damage_chance == 0, "Earlier and mainstream alternatives have no inherent fault: " + model)
	var player := _reliability_rig("luckycore_l9_13900l")
	var rng_state: int = game.rng.state
	game.preview_score(player)
	game.preview_score(player)
	check.call(game.rng.state == rng_state and not player.benchmark_checked and player.installed.cpu.condition == 100, "Score previews neither test nor wear a faulty CPU")
	_seed_for(0.18, true)
	game.act("tune", {"category": "cpu", "clock": 1.0, "voltage": 1.0})
	check.call(not player.installed.has("cpu"), "Stock stress test can actually destroy a faulty CPU")
	player = _reliability_rig("luckycore_l9_13900l")
	_seed_for(0.18, true)
	game.act("finish")
	check.call(game.state.phase == "results" and player.score.total == 0 and not player.installed.has("cpu"), "Skipping tuning cannot bypass final benchmark reliability risk")
	player = _reliability_rig("luckycore_l9_13900l")
	player.workshop_modifiers.lucky_tests = 1
	_seed_for(0.18 * 0.75, false)
	game.act("finish")
	check.call(player.score.total > 0 and player.installed.cpu.condition == 98 and player.workshop_modifiers.lucky_tests == 0, "Successful final test consumes blessing and applies wear exactly once")
	rng_state = game.rng.state
	game.workshop.final_score(1, player)
	check.call(game.rng.state == rng_state and player.installed.cpu.condition == 98, "Repeated final scoring does not reroll or wear hardware")
	player = _reliability_rig("luckycore_l9_13900l")
	_seed_for(0.18, true)
	game.state.remaining = 0.1
	game.advance_time(1)
	check.call(game.state.phase == "results" and player.score.total == 0 and not player.installed.has("cpu"), "Waiting for the deadline cannot bypass the reliability test")


func _gpu_fires() -> void:
	var rates := {"luckyforce_ltx_4090": 0.015, "luckyforce_ltx_5090": 0.025}
	check.call(Catalog.PARTS.filter(func(part): return part.fire_base_chance > 0).size() == 2, "Only the two authored flagship models have connector fire risk")
	for model: String in rates:
		var player := _fire_rig(model)
		var gpu: Dictionary = player.installed.gpu
		var stock := Overclock.evaluate(gpu, 1, 1, player.installed)
		var hot := Overclock.evaluate(gpu, 1.3, 1.3, player.installed)
		check.call(game.preview_score(player).valid, "Fire-prone GPU has a playable powered rig")
		check.call(is_equal_approx(stock.fire_chance, rates[model]) and is_equal_approx(stock.damage_chance, rates[model]), "Stock connector risk matches authored probability")
		check.call(hot.fire_chance > stock.fire_chance and hot.damage_chance >= hot.fire_chance, "Overclock raises fire probability within total destruction probability")
		check.call(Catalog.spec_text(gpu).contains("CONNECTOR FIRE"), "Buying notes disclose connector risk before purchase")
		var better: Dictionary = player.installed.duplicate(true)
		better.psu.support_quality = 100
		var worse: Dictionary = player.installed.duplicate(true)
		worse.psu.support_quality = 10
		check.call(Overclock.evaluate(gpu, 1.3, 1.3, better).fire_chance < Overclock.evaluate(gpu, 1.3, 1.3, worse).fire_chance, "Strong PSU regulation reduces extra-power connector risk")
		var cool := Overclock.evaluate(gpu, 1.3, 1.3, player.installed, {"cooling_bonus": 12})
		check.call(cool.temperature < hot.temperature and cool.fire_chance < hot.fire_chance, "Paste reduces the heat-related portion of heavy-OC fire risk")
		check.call(is_equal_approx(Overclock.evaluate(gpu, 1, 1, player.installed, {"cooling_bonus": 100}).fire_chance, stock.fire_chance), "Paste cannot cure the inherent connector flaw")
		var lucky := Overclock.evaluate(gpu, 1.3, 1.3, player.installed, {"lucky_tests": 1})
		check.call(is_equal_approx(lucky.fire_chance, hot.fire_chance * 0.75) and is_equal_approx(lucky.damage_chance, hot.damage_chance * 0.75), "Lucky reduces both fire and overall risk once")
		var preset := Overclock.safe_preset(gpu, player.installed)
		check.call(preset.clock == 1 and preset.voltage == 1, "Fire-prone models have a stock fallback, not a zero-risk preset")
		check.call(Overclock.failure_mode(hot, 0) == "fire" and Overclock.failure_mode(hot, hot.fire_chance) == "damage" and Overclock.failure_mode(hot, hot.damage_chance) == "", "Single roll has distinct fire, other damage and survival intervals")
		var worn := gpu.duplicate(true)
		worn.condition = 30
		check.call(Overclock.evaluate(worn, 1.3, 1.3, player.installed).fire_chance > hot.fire_chance, "Wear increases connector fire risk")
		var renamed := gpu.duplicate(true)
		renamed.name = "Artist's experimental toaster"
		renamed.model_id = "custom_test_model"
		check.call(is_equal_approx(Overclock.evaluate(renamed, 1, 1, player.installed).fire_chance, stock.fire_chance), "Fire mechanics use authored fields, never model-name checks")
		var normal := gpu.duplicate(true)
		normal.fire_base_chance = 0
		check.call(Overclock.evaluate(normal, 1.6, 1.6, player.installed).fire_chance == 0, "Ordinary hardware cannot acquire the special fire failure mode")
		var hard := Overclock.evaluate(gpu, 1.6, 1.41, player.installed, {"lucky_tests": 1})
		check.call(hard.damage_chance == 1 and hard.fire_chance <= 1 and not hard.uses_luck, "Fire mode preserves hard-overvoltage guaranteed destruction")
		var saved := player.duplicate(true)
		var rng_state: int = game.rng.state
		Overclock.final_tests(player.installed, player.tuning, player.workshop_modifiers)
		game.preview_score(player)
		check.call(player == saved and game.rng.state == rng_state, "Fire and final-test previews are pure")
		player.workshop_modifiers.lucky_tests = 1
		_seed_for(stock.fire_chance * 0.75, true)
		game.act("tune", {"category": "gpu", "clock": 1.0, "voltage": 1.0})
		check.call(not player.installed.has("gpu") and player.destroyed.has(gpu.name) and player.last_stress_test.failure_mode == "fire", "Host fire outcome permanently removes the GPU and identifies the cause")
		check.call(player.installed.cpu == saved.installed.cpu and player.installed.psu == saved.installed.psu and player.inventory == saved.inventory, "GPU fire leaves the other hardware and inventory intact")
		check.call(player.workshop_modifiers.lucky_tests == 0 and not player.tuning.has("gpu"), "Fire consumes its blessing and clears obsolete tuning")
		player = _fire_rig(model)
		_seed_for(rates[model], false)
		game.act("finish")
		check.call(player.score.valid and player.installed.gpu.condition == 99, "Successful final GPU test applies wear")
		rng_state = game.rng.state
		game.workshop.final_score(1, player)
		check.call(game.rng.state == rng_state and player.installed.gpu.condition == 99, "Final GPU test cannot reroll or apply wear twice")
		player = _fire_rig(model)
		_seed_for(rates[model], true)
		game.act("finish")
		check.call(game.state.phase == "results" and not player.installed.has("gpu") and player.score.valid and player.score.gpu == 400, "Final connector fire falls back to usable integrated graphics")
		player = _fire_rig(model)
		player.installed.cpu.integrated = false
		_seed_for(rates[model], true)
		game.state.remaining = 0.1
		game.advance_time(1)
		check.call(game.state.phase == "results" and not player.installed.has("gpu") and player.score.total == 0, "Deadline also tests connector risk; without iGPU, destruction leaves zero score")
	var player := _fire_rig("luckyforce_ltx_5090", "luckycore_l9_13900l")
	player.workshop_modifiers.lucky_tests = 1
	var tests := Overclock.final_tests(player.installed, player.tuning, player.workshop_modifiers)
	check.call(tests.size() == 2 and tests[0].category == "cpu" and tests[0].result.uses_luck and not tests[1].result.uses_luck and is_equal_approx(tests[1].result.fire_chance, 0.025), "Final plan assigns a single blessing in CPU then GPU order")
	_seed_for(tests[0].result.damage_chance, true)
	game.act("finish")
	check.call(not player.installed.has("cpu") and player.installed.gpu.condition == 100, "Final tests stop if CPU failure prevents the rig from running")


func _fire_rig(gpu_model: String, cpu_model: String = "luckycore_l7_12700l") -> Dictionary:
	var player := _reliability_rig(cpu_model)
	for model in [gpu_model, "titanforge_1000w"]:
		var template: Resource = Catalog.PARTS.filter(func(part): return str(part.model_id) == model)[0]
		var item := Catalog.build_listing(game.rng, template, 9100 if model == gpu_model else 9101)
		item.condition = 100
		player.installed[item.category] = item
	return player


func _reliability_rig(model: String) -> Dictionary:
	var player := fresh()
	var templates := [
		Catalog.PARTS.filter(func(part): return str(part.model_id) == model)[0],
		Catalog.PARTS.filter(func(part): return part.category == "case" and part.stats.get("form") == "ATX")[0],
		Catalog.PARTS.filter(func(part): return str(part.model_id) == "luckyboard_l670m")[0],
		Catalog.PARTS.filter(func(part): return part.category == "ram" and part.stats.get("memory") == "DDR4")[0],
		Catalog.PARTS.filter(func(part): return part.category == "storage")[0],
		Catalog.PARTS.filter(func(part): return part.category == "psu" and part.stats.get("capacity", 0) >= 500)[0],
	]
	for i in templates.size():
		var item := Catalog.build_listing(game.rng, templates[i], 9000 + i)
		item.condition = 100
		player.installed[item.category] = item
	player.pos = World.BENCH + Vector2(0, 30)
	return player


func _seed_for(chance: float, failure: bool) -> void:
	var random := RandomNumberGenerator.new()
	for value in 1000:
		random.seed = value
		if Overclock.fails(chance, random.randf()) == failure:
			game.rng.seed = value
			return
	check.call(false, "Found deterministic RNG fixture for damage outcome")


func _activities() -> void:
	var ids := {}
	for activity: Resource in Activities.ALL:
		check.call(not ids.has(activity.id), "Activity IDs are unique")
		ids[activity.id] = true
		check.call(World.clear_at(activity.area, activity.position, 5), "Activity is reachable: " + activity.display_name)
		check.call(Art.WORLD.has(activity.art_key), "Activity's replaceable artwork is registered")
		check.call(activity.overlay_art_key == "" or Art.WORLD.has(activity.overlay_art_key), "Activity overlay artwork is registered")
		check.call(activity.cash_cost >= 0 and activity.minutes_cost >= 0, "Activity costs are valid")
		for model: String in activity.loot_models:
			check.call(Catalog.PARTS.any(func(part): return str(part.model_id) == model), "Salvage references an existing stable model ID")
	var player := fresh()
	var shrine := Activities.find("lucky_square")
	var cash: int = player.cash
	game.act("world_activity", {"activity_id": "lucky_square"})
	check.call(player.cash == cash and player.workshop_modifiers.lucky_tests == 0, "Remote shrine use is refused")
	player.area = "town"
	player.pos = shrine.position
	player.driving = true
	game.act("world_activity", {"activity_id": "lucky_square"})
	check.call(player.cash == cash, "Cannot pray through a car window")
	player.driving = false
	var time: float = game.state.remaining
	game.act("world_activity", {"activity_id": "lucky_square"})
	check.call(player.cash == cash - shrine.cash_cost and game.state.remaining == time - shrine.minutes_cost, "Prayer charges the advertised cash and time")
	check.call(player.workshop_modifiers.lucky_tests == 1, "Prayer grants a Lucky blessing")
	game.act("world_activity", {"activity_id": "lucky_square"})
	check.call(player.cash == cash - shrine.cash_cost, "Repeated prayers cannot stack or charge twice")
	player.workshop_modifiers.lucky_tests = 0
	game.act("world_activity", {"activity_id": "lucky_square"})
	check.call(player.workshop_modifiers.lucky_tests == 0, "Daily prayer cap survives using the blessing")
	game.state.remaining -= 1440
	game.act("world_activity", {"activity_id": "lucky_square"})
	check.call(player.workshop_modifiers.lucky_tests == 1, "Prayer renews on the next day")
	player = fresh()
	player.area = "town"
	player.pos = Activities.find("dubious_bin").position
	var count: int = player.inventory.size()
	game.act("world_activity", {"activity_id": "dubious_bin"})
	var salvage: Dictionary = player.inventory[-1]
	check.call(player.inventory.size() == count + 1 and salvage.condition >= 45 and salvage.condition <= 70, "Salvage grants one worn component")
	game.act("world_activity", {"activity_id": "dubious_bin"})
	check.call(player.inventory.size() == count + 1, "Cannot farm the salvage bin repeatedly")
	player.pos = Activities.find("dust_busters").position
	var condition: int = salvage.condition
	game.act("world_activity", {"activity_id": "dust_busters", "item_id": salvage.id})
	check.call(salvage.condition == mini(100, condition + 12), "Cleaning improves the selected owned part")
	cash = player.cash
	game.act("world_activity", {"activity_id": "dust_busters", "item_id": salvage.id})
	check.call(player.cash == cash, "Cleaning cannot be repeated on the same part")
	var spare: Dictionary = player.inventory[0]
	game.act("post_sale", {"item_id": spare.id, "price": 12})
	game.act("world_activity", {"activity_id": "dust_busters", "item_id": spare.id})
	check.call(player.cash == cash, "Listed parts cannot be cleaned behind the listing's back")
	player.pos = Activities.find("paste_club").position
	game.act("world_activity", {"activity_id": "paste_club"})
	check.call(player.workshop_modifiers.cooling_bonus == 12, "Paste Club grants the declared cooling preparation")
	check.call(player.workshop_modifiers.cooling_name == Activities.find("paste_club").reward_name, "Applied special paste retains its authored name")
	cash = player.cash
	game.act("world_activity", {"activity_id": "paste_club"})
	check.call(player.cash == cash, "Permanent preparation cannot stack")
	player = fresh()
	game.state.mode = "lan"
	player.area = "town"
	player.pos = shrine.position
	time = game.state.remaining
	game.act("world_activity", {"activity_id": "lucky_square"})
	check.call(game.state.remaining == time and player.busy == shrine.minutes_cost, "LAN activity uses personal busy time, never advances shared clock")
	player = fresh()
	check.call(player.workshop_modifiers.lucky_tests == 0 and player.world_visits.is_empty(), "Replay resets blessings, services and encounter limits")


func _interfaces() -> void:
	var player := fresh()
	var shell: Control = load("res://scenes/main.tscn").instantiate()
	game.changed.emit()
	root_add(shell)
	await game.get_tree().process_frame
	var screen: Control = shell.get_node("Screens").get_child(0)
	player.area = "town"
	player.pos = Activities.find("lucky_square").position
	screen._dialogs.open_activity(Activities.find("lucky_square"))
	await game.get_tree().process_frame
	check.call(screen._dialogs.visible, "Activity dialog mounts using editable content")
	screen._dialogs.close()
	player.area = "home"
	player.pos = World.BENCH + Vector2(0, 30)
	player.installed.cpu = game.state.listings.filter(func(item): return item.category == "cpu")[0].duplicate(true)
	screen._open_workspace("tune")
	await game.get_tree().process_frame
	screen._tune._safe_preset()
	check.call(screen._tune._warn_lbl.text.contains("Zero destruction risk"), "Tuning UI displays the actual safe-preset result")
	screen._tune._set_draft(1.4, 1.41)
	check.call(screen._tune._prev.text.contains("After guaranteed destruction"), "Fatal tuning projects the loss of the component")
	check.call(player.installed.has("cpu"), "Fatal tuning preview leaves the actual component untouched")
	var faulty: Resource = Catalog.PARTS.filter(func(part): return str(part.model_id) == "luckycore_l7_13700l")[0]
	player.installed.cpu = Catalog.build_listing(game.rng, faulty, 9999)
	screen._tune.refresh()
	screen._tune._safe_preset()
	check.call(screen._tune._safe.text == "LOWEST RISK: STOCK" and screen._tune._warn_lbl.text.contains("MODEL RELIABILITY FLAW"), "Faulty CPU UI never labels its stock preset safe")
	var confirmations: Array = []
	screen._tune.ask = func(_title, body, _label, _action): confirmations.append(body)
	screen._tune._apply()
	check.call(confirmations.size() == 1 and player.installed.has("cpu"), "Stock test requires confirmation when the model is risky")
	var flagship: Resource = Catalog.PARTS.filter(func(part): return str(part.model_id) == "luckyforce_ltx_5090")[0]
	player.installed.gpu = Catalog.build_listing(game.rng, flagship, 10000)
	player.installed.gpu.condition = 100
	player.workshop_modifiers.cooling_bonus = 12
	player.workshop_modifiers["cooling_name"] = Activities.find("paste_club").reward_name
	screen._tune._select("gpu")
	screen._tune._safe_preset()
	check.call(screen._tune._safe.text == "LOWEST RISK: STOCK" and screen._tune._warn_lbl.text.contains("CONNECTOR FIRE: 2.5%"), "GPU UI discloses exact stock fire chance and never calls it safe")
	check.call(screen._tune._info.text.contains("LuckyGoop Dragon Chill applied: +12 cooling"), "Tuning displays the applied named paste")
	screen._tune._apply()
	check.call(confirmations.size() == 2 and confirmations[-1].contains("CONNECTOR FIRE: 2.5%"), "Stress-test confirmation includes fire probability")
	_seed_for(0.025, true)
	game.act("tune", {"category": "gpu", "clock": 1.0, "voltage": 1.0})
	screen._tune.refresh()
	check.call(screen._tune._outcome.visible and not screen._tune._body.visible and screen._tune._outcome.text.contains("CONNECTOR FIRE"), "Destroyed GPU leaves a visible fire explanation at the bench")
	screen._toggle_phone()
	screen._phone.set_unfolded(true)
	screen._phone.open_listing(game.state.listings[0].id)
	await game.get_tree().process_frame
	check.call(screen._phone.selected == game.state.listings[0].id, "Expanded hardware notes and character thread mount")
	shell.queue_free()
	await game.get_tree().process_frame
	player = _fire_rig("luckyforce_ltx_5090", "luckycore_l9_13900l")
	player.workshop_modifiers.lucky_tests = 1
	var bench: Control = load("res://src/workshop/bench_view.gd").new()
	confirmations.clear()
	bench.ask = func(_title, body, _label, _action): confirmations.append(body)
	bench._finish()
	check.call(confirmations.size() == 1 and confirmations[0].contains("13.5% destruction chance") and confirmations[0].contains("2.5% CONNECTOR FIRE"), "Finish dialog quotes a blessed CPU and unblessed GPU in test order")
	bench.free()


func root_add(node: Node) -> void:
	game.get_tree().root.add_child(node)
