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
	_unstable_overclocking()
	_voltage_only_risk()
	_manual_finish_guard()
	_stock_reliability()
	_gpu_fires()
	_activities()
	await _interfaces()
	await _socket_damage_interface()
	await _installation_feedback_and_ram_return()
	await _meeting_indicator_deadlines()


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
	var outcomes: Array[Dictionary] = []
	var receive_outcome := func(outcome: Dictionary): outcomes.append(outcome)
	game.stress_test_resolved.connect(receive_outcome)
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
	check.call(not player.last_stress_test.destroyed and player.last_stress_test.source == "tuning" and player.last_stress_test.category == "cpu" and game.state.phase == "playing", "Actual safe-test success publishes a complete outcome without finishing the run")
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
	check.call(player.last_stress_test.destroyed and player.last_stress_test.failure_mode == "damage" and game.state.phase == "playing", "Actual destruction publishes failure while the run continues")
	check.call(outcomes.size() == 3 and not outcomes[0].destroyed and not outcomes[1].destroyed and outcomes[2].destroyed and outcomes[2].serial == 3, "Only actual outcomes emit the authoritative result event, with increasing serials")
	game.stress_test_resolved.disconnect(receive_outcome)


func _unstable_overclocking() -> void:
	var player := _reliability_rig("luckycore_l7_12700l")
	var item: Dictionary = player.installed.cpu
	game.act("tune", {"category": "cpu", "clock": 1.6, "voltage": 1.0})
	check.call(player.last_stress_test.failure_mode == "unstable" and not player.last_stress_test.destroyed and not player.last_stress_test.applied, "Unstable zero-risk test reports non-destructive failed OC, not success")
	check.call(player.tuning.is_empty() and item.condition == 100 and player.busy > 0 and game.state.phase == "playing", "Failed stock-voltage OC retains implicit stock and costs test time without inventing wear")
	player.busy = 0
	var preset := Overclock.safe_preset(item, player.installed)
	game.act("tune", {"category": "cpu", "clock": preset.clock, "voltage": preset.voltage})
	check.call(player.last_stress_test.applied and player.last_stress_test.failure_mode == "" and player.tuning.cpu.clock == preset.clock, "Stable successful test applies the proposed tune")
	var working: Dictionary = player.tuning.duplicate(true)
	player.busy = 0
	player.workshop_modifiers.lucky_tests = 1
	var result := Overclock.evaluate(item, 1.6, 1.32, player.installed, player.workshop_modifiers)
	check.call(result.stable_clock < 1.6 and result.damage_chance > 0 and result.uses_luck, "Risky unstable fixture has electrical risk and a consumed blessing")
	_seed_for(result.damage_chance, false)
	game.act("tune", {"category": "cpu", "clock": 1.6, "voltage": 1.32})
	check.call(player.tuning == working and player.installed.has("cpu") and player.destroyed.is_empty(), "Surviving unstable test keeps the last working tuning and all hardware")
	check.call(item.condition == 100 - int(result.wear) and player.workshop_modifiers.lucky_tests == 0 and player.busy > 0, "Unstable survivor still pays voltage wear, Lucky and test time")
	check.call(player.last_stress_test.failure_mode == "unstable" and player.last_stress_test.applied_clock == preset.clock and player.last_stress_test.applied_voltage == preset.voltage, "Unstable outcome names retained settings separately from attempted settings")
	player.busy = 0
	game.act("tune", {"category": "cpu", "clock": 1.6, "voltage": 1.41})
	check.call(player.last_stress_test.destroyed and player.last_stress_test.failure_mode == "damage" and not player.last_stress_test.applied and not player.installed.has("cpu"), "Guaranteed destruction takes precedence over instability; failed OC cannot bypass electrical damage")


func _voltage_only_risk() -> void:
	for template: Resource in Catalog.PARTS:
		if template.category not in Rig.TUNABLE:
			continue
		var item := Catalog.build_listing(game.rng, template, 9900)
		for health in [30, 100]:
			item.condition = health
			for modifiers: Dictionary in [{}, {"cooling_bonus": 12, "cpu_mount_quality": 0.0, "lucky_tests": 1}]:
				var previous := {"damage_chance": 0.0, "fire_chance": 0.0}
				for voltage_step in range(61):
					var voltage := 1.0 + voltage_step / 100.0
					var baseline := Overclock.evaluate(item, 1.0, voltage, {}, modifiers)
					var invariant := true
					for clock_step in range(61):
						var result := Overclock.evaluate(item, 1.0 + clock_step / 100.0, voltage, {}, modifiers)
						invariant = invariant and result.damage_chance == baseline.damage_chance and result.fire_chance == baseline.fire_chance
					check.call(invariant, "Every clock 1..1.6 has identical risk at fixed voltage: %s %.2fV" % [item.name, voltage])
					check.call(baseline.damage_chance >= previous.damage_chance and baseline.fire_chance >= previous.fire_chance, "Voltage never decreases stress within existing probability caps")
					previous = baseline


func _manual_finish_guard() -> void:
	var player := fresh()
	player.pos = World.BENCH
	var before: int = game.rng.state
	game.act("finish")
	check.call(game.state.phase == "playing" and not player.ready and not player.benchmark_checked and game.rng.state == before, "Incomplete manual benchmark is refused without locking, rolling or ending the run")
	game.state.remaining = 0.1
	game.advance_time(1)
	check.call(game.state.phase == "results" and player.ready and player.score.total == 0, "Deadline still ends incomplete builds")
	player = _reliability_rig("luckycore_l7_12700l")
	var capacity: int = player.installed.psu.capacity
	player.installed.psu.capacity = 1
	game.act("finish")
	check.call(game.state.phase == "playing" and not player.ready and not player.benchmark_checked, "Manual benchmark refuses installed but overloaded builds")
	player.installed.psu.capacity = capacity
	check.call(not player.installed.has("gpu") and Rig.igpu_usable(player.installed), "Complete iGPU build needs no discrete GPU")
	game.act("finish")
	check.call(game.state.phase == "results" and player.score.valid, "Manual benchmark accepts a complete valid iGPU build")


func _stock_reliability() -> void:
	var fault_rates := {"luckycore_l7_13700l": 0.20, "luckycore_l9_13900l": 0.28,
		"luckycore_l7_14700l": 0.24, "luckycore_l9_14900l": 0.34}
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
	_seed_for(0.28, true)
	game.act("tune", {"category": "cpu", "clock": 1.0, "voltage": 1.0})
	check.call(not player.installed.has("cpu"), "Stock stress test can actually destroy a faulty CPU")
	player = _reliability_rig("luckycore_l9_13900l")
	_seed_for(0.28, true)
	game.act("finish")
	check.call(game.state.phase == "results" and player.score.total == 0 and not player.installed.has("cpu"), "Skipping tuning cannot bypass final benchmark reliability risk")
	player = _reliability_rig("luckycore_l9_13900l")
	player.workshop_modifiers.lucky_tests = 1
	_seed_for(0.28 * 0.75, false)
	game.act("finish")
	check.call(player.score.total > 0 and player.installed.cpu.condition == 98 and player.workshop_modifiers.lucky_tests == 0, "Successful final test consumes blessing and applies wear exactly once")
	rng_state = game.rng.state
	game.workshop.final_score(1, player)
	check.call(game.rng.state == rng_state and player.installed.cpu.condition == 98, "Repeated final scoring does not reroll or wear hardware")
	player = _reliability_rig("luckycore_l9_13900l")
	_seed_for(0.28, true)
	game.state.remaining = 0.1
	game.advance_time(1)
	check.call(game.state.phase == "results" and player.score.total == 0 and not player.installed.has("cpu"), "Waiting for the deadline cannot bypass the reliability test")


func _gpu_fires() -> void:
	var rates := {"luckyforce_ltx_4090": 0.10, "luckyforce_ltx_5090": 0.14}
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
		check.call(cool.temperature < hot.temperature and cool.fire_chance <= hot.fire_chance, "Cooling lowers gameplay heat and never increases voltage-driven connector risk")
		# At stock clock / legal 1.40 voltage, poor case airflow puts BOTH authored GPUs
		# above the risk-heat threshold. This must detect removal of the cooling modifier.
		var hot_platform: Dictionary = player.installed.duplicate(true)
		hot_platform.case.support_quality = 0
		var heat_risk := Overclock.evaluate(gpu, 1.0, 1.40, hot_platform)
		var cooled_risk := Overclock.evaluate(gpu, 1.0, 1.40, hot_platform, {"cooling_bonus": 12})
		check.call(cooled_risk.fire_chance < heat_risk.fire_chance and cooled_risk.damage_chance < heat_risk.damage_chance, "Cooling strictly reduces heat-derived fire and destruction risk at legal hot voltage")
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
		var expected_condition := 100 - ceili(float(rates[model]) * 8)
		check.call(player.score.valid and player.installed.gpu.condition == expected_condition, "Successful final GPU test applies wear")
		rng_state = game.rng.state
		game.workshop.final_score(1, player)
		check.call(game.rng.state == rng_state and player.installed.gpu.condition == expected_condition, "Final GPU test cannot reroll or apply wear twice")
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
	check.call(tests.size() == 2 and tests[0].category == "cpu" and tests[0].result.uses_luck and not tests[1].result.uses_luck and is_equal_approx(tests[1].result.fire_chance, 0.14), "Final plan assigns a single blessing in CPU then GPU order")
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


func _activity_approach(activity: Resource) -> Vector2:
	# Stand just south of the visible foundation, not inside the now-solid prop.
	return activity.position + Vector2(0, 12)


func _activities() -> void:
	var ids := {}
	for activity: Resource in Activities.ALL:
		check.call(not ids.has(activity.id), "Activity IDs are unique")
		ids[activity.id] = true
		var approach := _activity_approach(activity)
		check.call(approach.distance_to(activity.position) <= activity.radius and World.clear_at(activity.area, approach, 5), "Activity has a clear nearby interaction position: " + activity.display_name)
		var props := World.activity_props(activity.area).filter(func(prop): return prop.activity == activity)
		check.call(props.size() == 1, "Activity has one physical base: " + activity.display_name)
		if props.size() == 1:
			var base: Rect2 = props[0].solid
			check.call(not World.clear_at(activity.area, base.get_center(), 5), "Activity base is solid: " + activity.display_name)
			var stopped := World.move(activity.area, approach, Vector2(0, -40), false)
			check.call(stopped.y < approach.y and stopped.y >= base.end.y + 5 and World.clear_at(activity.area, stopped, 5), "Walking up to the activity stops at its base: " + activity.display_name)
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
	player.pos = _activity_approach(shrine)
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
	game.advance_time(1440.0 - game.clock())
	time = game.state.remaining
	game.act("world_activity", {"activity_id": "lucky_square"})
	check.call(game.state.phase == "playing" and player.workshop_modifiers.lucky_tests == 1 and player.cash == cash - 2 * shrine.cash_cost and game.state.remaining == time - shrine.minutes_cost, "Prayer becomes usable again on the next game day after advancing session time")
	player = fresh()
	player.area = "town"
	player.pos = _activity_approach(Activities.find("dubious_bin"))
	var count: int = player.inventory.size()
	game.act("world_activity", {"activity_id": "dubious_bin"})
	var salvage: Dictionary = player.inventory[-1]
	check.call(player.inventory.size() == count + 1 and salvage.condition >= 45 and salvage.condition <= 70, "Salvage grants one worn component")
	game.act("world_activity", {"activity_id": "dubious_bin"})
	check.call(player.inventory.size() == count + 1, "Cannot farm the salvage bin repeatedly")
	game.advance_time(1440.0 - game.clock())
	game.act("world_activity", {"activity_id": "dubious_bin"})
	check.call(player.inventory.size() == count + 2, "Salvage replenishes on the next game day after advancing session time")
	player.pos = _activity_approach(Activities.find("dust_busters"))
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
	player.pos = _activity_approach(Activities.find("paste_club"))
	game.act("world_activity", {"activity_id": "paste_club"})
	check.call(player.workshop_modifiers.cooling_bonus == 12, "Paste Club grants the declared cooling preparation")
	check.call(player.workshop_modifiers.cooling_name == Activities.find("paste_club").reward_name, "Applied special paste retains its authored name")
	cash = player.cash
	game.act("world_activity", {"activity_id": "paste_club"})
	check.call(player.cash == cash, "Permanent preparation cannot stack")
	player = fresh()
	game.state.mode = "lan"
	player.area = "town"
	player.pos = _activity_approach(shrine)
	time = game.state.remaining
	game.act("world_activity", {"activity_id": "lucky_square"})
	check.call(game.state.remaining == time and player.busy == shrine.minutes_cost, "LAN activity uses personal busy time, never advances shared clock")
	player = fresh()
	check.call(player.workshop_modifiers.lucky_tests == 0 and player.world_visits.is_empty(), "Replay resets blessings, services and encounter limits")


func _interfaces() -> void:
	var player := fresh()
	var shell: Control = load("res://src/main.tscn").instantiate()
	game.changed.emit()
	root_add(shell)
	await game.get_tree().process_frame
	var screen: Control = shell.get_node("Screens").get_child(0)
	player.area = "town"
	player.pos = _activity_approach(Activities.find("lucky_square"))
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
	check.call(screen._tune._safe.text == "LOWEST RISK: STOCK" and screen._tune._warn_lbl.text.contains("CONNECTOR FIRE: 14.0%"), "GPU UI discloses exact stock fire chance and never calls it safe")
	check.call(screen._tune._info.text.contains("LuckyGoop Dragon Chill applied: +12 cooling"), "Tuning displays the applied named paste")
	screen._tune._apply()
	check.call(confirmations.size() == 2 and confirmations[-1].contains("CONNECTOR FIRE: 14.0%"), "Stress-test confirmation includes fire probability")
	_seed_for(0.14, true)
	game.act("tune", {"category": "gpu", "clock": 1.0, "voltage": 1.0})
	screen._tune.refresh()
	check.call(screen._tune._outcome.visible and not screen._tune._body.visible and screen._tune._outcome.text.contains("CONNECTOR FIRE"), "Destroyed GPU leaves a visible fire explanation at the bench")
	check.call(screen._tune._empty.visible and screen._tune._empty.text.contains("press B") and not screen._tune._empty.text.contains("tab"), "Missing-part guidance explains the actual route back to assembly")
	screen._toggle_phone()
	screen._phone.set_unfolded(true)
	screen._phone.open_listing(game.state.listings[0].id)
	await game.get_tree().process_frame
	check.call(screen._phone.selected == game.state.listings[0].id, "Expanded hardware notes and character thread mount")
	shell.queue_free()
	await game.get_tree().process_frame
	player = _fire_rig("luckyforce_ltx_5090", "luckycore_l9_13900l")
	player.workshop_modifiers.lucky_tests = 1
	var bench: Control = load("res://src/workshop/bench_view.tscn").instantiate()
	confirmations.clear()
	bench.ask = func(_title, body, _label, _action): confirmations.append(body)
	bench._finish()
	check.call(confirmations.size() == 1 and confirmations[0].contains("21.0% destruction chance") and confirmations[0].contains("14.0% CONNECTOR FIRE"), "Finish dialog quotes a blessed CPU and unblessed GPU in test order")
	bench.free()


func _assembly_tap(assembly: Control, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = true
	assembly._gui_input(event)
	event.pressed = false
	assembly._gui_input(event)


func _installation_feedback_and_ram_return() -> void:
	var accepted: Array[int] = []
	var on_install := func(id: int): accepted.append(id)
	game.component_installed.connect(on_install)
	game.start_assembly_test("Install feedback")
	game.set_process(false)
	game.set_physics_process(false)
	check.call(accepted.is_empty(), "Startup seed does not announce manual installation")
	var player: Dictionary = game.me()
	var shell: Control = load("res://src/main.tscn").instantiate()
	root_add(shell)
	await game.get_tree().process_frame
	var screen: Control = shell._screen
	var board: Dictionary = player.installed.motherboard
	var ram: Dictionary = player.installed.ram
	ram.condition = 73
	ram["assembly_strikes"] = 2
	var ram_before := ram.duplicate(true)
	var others: Dictionary = player.installed.duplicate(true)
	others.erase("motherboard")
	others.erase("ram")
	player.tuning.ram = {"clock": 1.1, "voltage": 1.05}
	var before := player.duplicate(true)
	game.act("uninstall", {"category": "motherboard", "item_id": int(board.id) - 1})
	check.call(player == before, "Stale motherboard uninstall returns nothing and changes no metadata")
	player.busy = 10.0
	before = player.duplicate(true)
	game.act("uninstall", {"category": "motherboard", "item_id": board.id})
	check.call(player == before, "Busy motherboard uninstall cannot partially return RAM")
	player.busy = 0.0
	var count: int = player.inventory.size()
	game.act("uninstall", {"category": "motherboard", "item_id": board.id})
	check.call(not player.installed.has("motherboard") and not player.installed.has("ram") and player.inventory.size() == count + 2, "Manual motherboard uninstall returns exactly motherboard and RAM")
	check.call(player.inventory.filter(func(part: Dictionary): return int(part.id) == int(ram.id)) == [ram_before], "Returned RAM preserves identity, wear and physical damage exactly once")
	check.call(not player.tuning.has("ram") and not player.workshop_modifiers.assembly_fasteners.has("ram") and not player.workshop_modifiers.assembly_fasteners.has("motherboard"), "Returned RAM and motherboard lose installation metadata")
	check.call(player.installed == others, "Motherboard removal preserves CPU, GPU and other slots")
	game.act("uninstall", {"category": "motherboard", "item_id": board.id})
	check.call(player.inventory.size() == count + 2, "Repeated uninstall cannot duplicate returned RAM")
	check.call(accepted.is_empty() and not screen._installed_feedback.visible, "Uninstall and rejected actions never show installation success")
	game.act("install", {"item_id": board.id})
	check.call(accepted == [int(board.id)] and screen._installed_feedback.visible and not screen._dialogs.visible, "Accepted installation shows passive success without a dialog")
	var first_tween: Tween = screen._installed_tween
	game.act("install", {"item_id": ram.id})
	check.call(accepted.size() == 2 and not first_tween.is_valid() and screen._installed_feedback.modulate.a == 1.0, "Back-to-back installs restart one feedback Tween")
	await game.get_tree().create_timer(1.25).timeout
	screen._dialogs.open_assembly(ram)
	screen._dialogs._assembly.cancelled.emit()
	check.call(accepted.size() == 2 and not screen._installed_feedback.visible, "Cancelling assembly cannot show installation success")
	game.act("install", {"item_id": ram.id, "screws_seated": -1})
	check.call(accepted.size() == 2 and not screen._installed_feedback.visible, "Rejected reinstall cannot show installation success")
	screen._dialogs.open_assembly(ram)
	var assembly: Control = screen._dialogs._assembly
	assembly.completed.emit({"mount_quality": 1.0, "paste_amount": 1.0, "screws_seated": Rig.expected_fasteners(ram), "supports": Rig.expected_fasteners(ram)})
	check.call(accepted.size() == 3 and not screen._dialogs.visible and screen._installed_feedback.visible, "Accepted reinstall closes assembly then shows success")
	await game.get_tree().create_timer(1.25).timeout
	check.call(not screen._installed_feedback.visible, "Installation success fades and hides without confirmation")
	game.component_installed.disconnect(on_install)
	shell.queue_free()
	await game.get_tree().process_frame


func _meeting_indicator_deadlines() -> void:
	var player := fresh()
	player.area = "town"
	var listing: Dictionary = {}
	var slot: Dictionary = {}
	for candidate: Dictionary in game.state.listings:
		for option: Dictionary in game.contact_options(candidate):
			if option.end - option.start >= 90 and option.end - 30 - game.clock() > 120.25 and option.end + 0.25 < game.deadline():
				listing = candidate
				slot = option.duplicate(true)
				break
		if not slot.is_empty():
			break
	check.call(not slot.is_empty(), "Indicator fixture has a future canonical meeting window")
	if slot.is_empty():
		return
	var other: Dictionary = game.state.listings.filter(func(part: Dictionary): return int(part.id) != int(listing.id))[0]
	var sooner := slot.duplicate(true)
	sooner.end = float(slot.end) - 30.0
	player.offers[listing.id] = int(listing.price)
	player.offers[other.id] = int(other.price)
	player.meetings[listing.id] = slot
	player.meetings[other.id] = sooner
	var shell: Control = load("res://src/main.tscn").instantiate()
	root_add(shell)
	await game.get_tree().process_frame
	var screen: Control = shell._screen
	var indicators: Control = screen._meeting_indicators
	var inverse := indicators.get_global_transform_with_canvas().affine_inverse()
	var destination: Vector2 = game.market.meeting_position(slot)
	var target: Vector2 = inverse * screen._world.world_to_screen(destination)
	var offscreen := Rect2(Vector2(-10000, -10000), Vector2(400, 300))
	var onscreen := Rect2(target - Vector2(100, 100), Vector2(200, 200))
	var end: float = sooner.end
	game.advance_time(end - 120.25 - game.clock())
	check.call(indicators._meeting_groups(player, game.clock(), offscreen).is_empty(), "Edge pointers stay hidden more than two hours before all pickup deadlines")
	check.call(indicators._meeting_groups(player, game.clock(), onscreen).size() == 1, "Visible destination dots retain their existing earlier guidance")
	game.advance_time(0.25)
	var groups: Dictionary = indicators._meeting_groups(player, game.clock(), offscreen)
	check.call(groups.size() == 1 and groups.has(destination) and groups[destination].times.size() == 1 and groups[destination].ends[int(slot.start)] == end, "Edge pointer appears at exactly two hours and excludes later shared pickups outside that range")
	game.advance_time(60)
	var clock := "%02d:%02d" % [(int(slot.start) % 1440) / 60, int(slot.start) % 60]
	check.call(indicators._time_text(int(slot.start), game.clock(), end) == clock, "Exactly one hour remaining still shows the meeting clock time")
	game.advance_time(1)
	groups = indicators._meeting_groups(player, game.clock(), offscreen)
	check.call(groups.has(destination) and indicators._time_text(int(slot.start), game.clock(), groups[destination].ends[int(slot.start)]) == "59m left", "Under one hour the shared marker counts down to its soonest deadline")
	game.advance_time(49)
	groups = indicators._meeting_groups(player, game.clock(), offscreen)
	check.call(groups.has(destination) and groups[destination].urgency == 2 and indicators._time_text(int(slot.start), game.clock(), end) == "10m left", "Final ten minutes retain red urgency and a remaining-minute label")
	game.advance_time(10.25)
	groups = indicators._meeting_groups(player, game.clock(), offscreen)
	check.call(groups.size() == 1 and groups.has(destination) and groups[destination].ends[int(slot.start)] == slot.end and groups[destination].urgency == 1, "Expired shared pickups cannot retain the earlier countdown or red urgency")
	game.advance_time(float(slot.end) - game.clock() + 0.25)
	check.call(indicators._meeting_groups(player, game.clock(), offscreen).is_empty(), "Edge pointer disappears after every shared pickup window has expired")
	shell.queue_free()
	await game.get_tree().process_frame


func _socket_damage_interface() -> void:
	var player := _reliability_rig("luckycore_l7_12700l")
	var cpu: Dictionary = player.installed.cpu
	var cpu_condition: int = cpu.condition
	var board: Dictionary = player.installed.motherboard
	game.act("uninstall", {"category": "cpu", "item_id": cpu.id})
	var shell: Control = load("res://src/main.tscn").instantiate()
	root_add(shell)
	await game.get_tree().process_frame
	var screen: Control = shell.get_node("Screens").get_child(0)
	screen._dialogs.open_assembly(cpu)
	var assembly: Control = screen._dialogs._assembly
	check.call(is_instance_valid(assembly), "Owned CPU opens against the installed socket")
	if not is_instance_valid(assembly):
		shell.queue_free()
		await game.get_tree().process_frame
		return
	_assembly_tap(assembly, assembly.steps[0].pts[0].p)
	var pins: Rect2 = assembly._socket_pins_rect()
	for strike in range(1, 6):
		_assembly_tap(assembly, pins.get_center())
		game.changed.emit()
		check.call(int(cpu.get("assembly_strikes", 0)) == 0 and cpu.condition == cpu_condition, "Exposed-pin clicks never damage the CPU")
		if strike < 5:
			check.call(int(board.get("assembly_strikes", 0)) == strike, "Exposed-pin click adds one persistent motherboard strike")
	check.call(not player.installed.has("motherboard") and player.destroyed.has(board.name), "Fifth exposed-pin click destroys the motherboard")
	check.call(assembly._socket_destroyed and assembly._hint.text.contains("Replace the destroyed motherboard"), "Destroyed-socket warning names the actual damaged part")
	# Ordinary state refreshes must not dismiss the warning or leave a stale socket.
	game.changed.emit()
	await game.get_tree().process_frame
	game.changed.emit()
	await game.get_tree().process_frame
	var warning_stays := is_instance_valid(screen._dialogs._assembly)
	check.call(warning_stays and screen._dialogs.visible, "Destroyed-socket warning survives subsequent host refreshes")
	if warning_stays:
		assembly = screen._dialogs._assembly
		check.call(assembly._socket_destroyed and not assembly._retry.visible and (not assembly._primary.visible or assembly._primary.disabled), "Destroyed socket cannot be retried or committed")
		assembly._primary_pressed()
	check.call(not player.installed.has("cpu") and player.inventory.any(func(part: Dictionary): return int(part.id) == int(cpu.id)), "Destroyed socket leaves the undamaged CPU owned but uninstalled")
	var template: Resource = Catalog.PARTS.filter(func(part): return part.model_id == board.model_id)[0]
	var replacement := Catalog.build_listing(game.rng, template, 99001)
	player.inventory.append(replacement)
	game.act("install", {"item_id": replacement.id})
	game.changed.emit()
	await game.get_tree().process_frame
	check.call(int(player.installed.get("motherboard", {}).get("id", -1)) == int(replacement.id) and not is_instance_valid(screen._dialogs._assembly), "Replacing the motherboard closes the old socket's assembly dialog")
	shell.queue_free()
	await game.get_tree().process_frame


func root_add(node: Node) -> void:
	game.get_tree().root.add_child(node)
