extends SceneTree
## Run: godot --headless --path . --script res://tests/run_tests.gd
## No HTTP requests and no changes to the player's real high scores.
const Catalog = preload("res://src/data/catalog.gd")
const Rig = preload("res://src/workshop/rig_rules.gd")
const Overclock = preload("res://src/workshop/overclock_rules.gd")
const World = preload("res://src/world/world_rules.gd")
const Factory = preload("res://src/core/state_factory.gd")
const Store = preload("res://src/core/score_store.gd")
const Snapshot = preload("res://src/network/snapshot.gd")
const Config = preload("res://src/core/game_config.gd")
const Art = preload("res://src/ui/art_library.gd")

var game: Node
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("FAIL: " + description)


func fresh() -> Dictionary:
	game.solo("Test Scrapper", 1000, "Balanced")
	game.set_process(false)
	game.set_physics_process(false)
	return game.me()


func _run() -> void:
	game = root.get_node("Game")
	game.seller.online_enabled = false
	game.dialogue.delay_scale = 0
	game.market.interest_delay_scale = 0
	game.score_path = "res://artifacts/test_scores.json"
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	_test_data_and_rules()
	_test_movement_and_clock()
	_test_buying()
	_test_selling_and_building()
	await _test_dialogue()
	_test_privacy_and_lifecycle()
	await preload("res://tests/content_tests.gd").new().run(game, expect)
	await preload("res://tests/phone_tests.gd").new().run(game, expect)
	await preload("res://tests/notice_tests.gd").new().run(game, expect)
	await preload("res://tests/marketplace_tests.gd").new().run(game, expect)
	preload("res://tests/conversation_tests.gd").new().run(game, expect)
	await _test_screens()
	game.leave()
	await process_frame
	print("REGRESSION: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		print("  " + failure)
	quit(0 if failures.is_empty() else 1)


func _wait_phone_motion(screen: Control, motion: String) -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while screen._phone_motion != motion and Time.get_ticks_msec() < deadline:
		await process_frame
	expect(screen._phone_motion == motion, "Phone transition reaches " + motion)


func _type_key(text: String) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = text.to_upper().unicode_at(0)
	event.physical_keycode = event.keycode
	event.unicode = text.unicode_at(0)
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)


func _test_data_and_rules() -> void:
	expect(Catalog.PARTS.size() == 75, "Hardware roster includes older and current fictional models")
	var bindings := {"move_left": KEY_LEFT, "move_right": KEY_RIGHT, "move_up": KEY_UP, "move_down": KEY_DOWN}
	for action: String in bindings:
		var found := false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey and event.physical_keycode == bindings[action]:
				found = true
		expect(found, "Input Map includes arrow binding for " + action)
	var random := RandomNumberGenerator.new()
	random.seed = 42
	var installed := {}
	var identity := 1
	for category in ["case", "motherboard", "cpu", "ram", "storage", "psu"]:
		for part: Resource in Catalog.PARTS:
			if part.category != category:
				continue
			var item := Catalog.build_listing(random, part, identity)
			if Rig.compat(item, installed) == "":
				installed[category] = item
				identity += 1
				break
	expect(Rig.score(installed, {}, "Balanced").valid, "Budget build runs with integrated graphics")
	expect(Rig.score(installed, {}, "Balanced").total > 0, "Valid rig scores above zero")
	var incompatible: Dictionary = installed.cpu.duplicate(true)
	incompatible.socket = "WRONG"
	expect(Rig.compat(incompatible, installed) != "", "Mismatched socket refused")
	var weak: Dictionary = installed.duplicate(true)
	weak.psu.capacity = 1
	expect(not Rig.score(weak, {}, "Balanced").valid, "Overloaded PSU invalidates score")
	expect(Rig.score({}, {}, "Balanced").total == 0, "Incomplete rig scores zero")
	var safe := Overclock.safe_preset(installed.cpu, installed)
	var tuned := {"cpu": safe}
	expect(Rig.score(installed, tuned, "Balanced").cpu > Rig.score(installed, {}, "Balanced").cpu, "Safe overclock improves actual rig performance")
	expect(Overclock.evaluate(installed.cpu, 1.6, 1.0, installed).multiplier < 1.0, "Unstable overclock loses performance")
	var a := Factory.player("A")
	var b := Factory.player("B")
	a.inventory.append({"id": 1})
	expect(b.inventory.is_empty(), "Players have independent nested state")
	for category: String in Catalog.CATEGORIES:
		expect(Art.part(category, {}, false) != null and Art.part(category, {}, true) != null,
			"Small and detail artwork loads for " + category)
	for key: String in Art.WORLD:
		expect(Art.WORLD[key] is Texture2D, "World art loads: " + key)
	for seed_value in 5:
		random.seed = seed_value
		var stock: Array = []
		for pick: Dictionary in Catalog.initial_picks(random, 1):
			stock.append(Catalog.build_listing(random, pick.tpl, stock.size() + 1))
		expect(Rig.cheapest_build(stock) > 0 and Rig.cheapest_build(stock) <= 600,
			"Starter supply supports the smallest budget, seed %d" % seed_value)


func _test_movement_and_clock() -> void:
	var player := fresh()
	var before: Vector2 = player.pos
	game.act("move", {"direction": Vector2(100, 0)})
	game.movement.tick(0.1)
	expect(player.pos.distance_to(before) <= World.WALK_SPEED * 0.1 + 0.01, "Movement input is normalized")
	before = player.pos
	game.movement.tick(0.5)
	expect(player.pos == before, "Stale movement stops")
	expect(World.clear_at("home", World.move("home", World.SPAWN, Vector2(0, -1000), false), 5), "Large motion cannot tunnel outside room")
	player.pos = World.DOOR_INSIDE
	game.act("interact")
	expect(player.area == "town" and player.pos == World.DOOR_OUTSIDE, "Door exits home")
	player.pos = player.car_pos
	var cash: int = player.cash
	game.act("interact")
	expect(player.driving and player.cash == cash - 3, "Entering car charges fuel once")
	game.act("interact")
	expect(not player.driving and World.clear_at("town", player.pos, 5), "Parking finds a walkable exit")
	player.busy = 10.0
	var remaining: float = game.state.remaining
	game.act("wait")
	expect(game.state.remaining == remaining - 30.0 and player.busy == 0.0, "Solo wait advances clock and workbench together")
	game.state.mode = "lan"
	remaining = game.state.remaining
	game.act("wait")
	expect(game.state.remaining == remaining, "LAN wait never skips the shared clock")


func agree(player: Dictionary, listing: Dictionary, early: bool = false) -> Dictionary:
	var meeting := {"id": "test", "place": listing.location, "pos": Catalog.LOCATIONS[listing.location],
		"start": game.clock() + (30 if early else -1), "end": game.clock() + 90, "label": "Test appointment"}
	player.offers[listing.id] = listing.price
	player.meetings[listing.id] = meeting
	return meeting


func _test_buying() -> void:
	var player := fresh()
	var listing: Dictionary = game.state.listings[0]
	var meeting := agree(player, listing, true)
	var cash: int = player.cash
	var count: int = player.inventory.size()
	game.act("handoff", {"listing_id": listing.id})
	expect(player.cash == cash and player.inventory.size() == count, "Cannot trade remotely from home")
	player.area = "town"
	player.pos = meeting.pos
	game.act("handoff", {"listing_id": listing.id})
	expect(player.cash == cash, "Early handoff refused")
	game.advance_time(30)
	game.act("handoff", {"listing_id": listing.id})
	expect(player.cash == cash - listing.price and player.inventory.size() == count + 1, "Purchase transfers exact cash and one part")
	game.act("handoff", {"listing_id": listing.id})
	expect(player.inventory.size() == count + 1 and player.cash == cash - listing.price, "Duplicate purchase is idempotent")
	listing = game.state.listings[1]
	meeting = agree(player, listing)
	meeting.end = game.clock() - 1
	player.pos = meeting.pos
	cash = player.cash
	game.act("handoff", {"listing_id": listing.id})
	expect(player.cash == cash, "Missed appointment never charges cash")


func _test_selling_and_building() -> void:
	var player := fresh()
	var spare: Dictionary = player.inventory[0]
	game.act("post_sale", {"item_id": spare.id, "price": 15})
	var listing: Dictionary = game.state.listings[-1]
	var count: int = game.state.listings.size()
	game.act("post_sale", {"item_id": spare.id, "price": 15})
	expect(game.state.listings.size() == count, "Cannot list the same spare twice")
	player.pos = World.BENCH + Vector2(0, 30)
	game.act("install", {"item_id": spare.id})
	expect(player.installed.is_empty(), "Live sale locks installation")
	game.act("cancel_sale", {"listing_id": listing.id})
	game.act("install", {"item_id": spare.id})
	expect(player.installed.has("case") and player.inventory.is_empty(), "Cancelling sale unlocks installation")
	player = fresh()
	spare = player.inventory[0]
	game.act("post_sale", {"item_id": spare.id, "price": 15})
	listing = game.state.listings[-1]
	var meeting := agree(player, listing)
	player.area = "town"
	player.pos = meeting.pos
	var cash: int = player.cash
	game.act("handoff", {"listing_id": listing.id})
	game.act("handoff", {"listing_id": listing.id})
	expect(player.cash == cash + 15 and player.inventory.is_empty(), "Sale credits and removes the exact spare once")
	player = fresh()
	player.pos = World.BENCH + Vector2(0, 30)
	var cpu: Dictionary = game.state.listings.filter(func(item): return item.category == "cpu")[0].duplicate(true)
	player.installed.cpu = cpu
	game.act("tune", {"category": "cpu", "clock": 1.3, "voltage": 1.41})
	expect(not player.installed.has("cpu") and player.destroyed.has(cpu.name), "Unsafe voltage permanently destroys part")
	game.act("install", {"item_id": player.inventory[0].id})
	expect(not player.installed.has("case"), "Busy workbench refuses overlapping jobs")


func send_chat(listing_id: int, message: String) -> void:
	game.act("chat", {"listing_id": listing_id, "text": message})
	await create_timer(0.6).timeout


func _test_dialogue() -> void:
	var player := fresh()
	var listing: Dictionary = game.state.listings.filter(func(item): return not preload("res://src/data/characters.gd").for_listing(item).requires_conversation)[0]
	await send_chat(listing.id, "I'll pay $%d" % listing.price)
	expect(player.offers.has(listing.id), "Offline chat agrees a grounded asking price")
	expect(player.meeting_proposals.has(listing.id) and not player.meetings.has(listing.id), "A proposal alone is not a confirmed meeting")
	await send_chat(listing.id, "Yes, that price, time and place works.")
	expect(player.meetings.has(listing.id), "Offline chat confirms a canonical appointment")
	var next: Dictionary = game.state.listings.filter(func(item): return item.id != listing.id)[0]
	await send_chat(next.id, "Does it fit my socket?")
	expect(not player.offers.has(next.id), "Specification questions cannot create price commitments")
	game.act("chat", {"listing_id": next.id, "text": "I'll pay full price"})
	var old_id: int = game.state.match_id
	player = fresh()
	await create_timer(0.6).timeout
	expect(game.state.match_id > old_id and player.offers.is_empty(), "Late replies cannot mutate a replacement match")


func _test_privacy_and_lifecycle() -> void:
	var player := fresh()
	player.chats[1] = [{"text": "private"}]
	player.offers[1] = 17
	player.counters[1] = 18
	player.meeting_proposals[1] = {"id": "private"}
	game.state.players[2] = Factory.player("Peer")
	game.act("post_sale", {"item_id": player.inventory[0].id, "price": 15})
	var snapshot: Dictionary = Snapshot.for_player(game.state, 2)
	expect(snapshot.players[1].chats.is_empty() and snapshot.players[1].offers.is_empty(), "Snapshots hide other players' chats and agreed prices")
	expect(snapshot.players[1].counters.is_empty() and snapshot.players[1].meeting_proposals.is_empty(), "Snapshots hide private negotiation state")
	expect(not snapshot.listings[-1].has("buyer_max"), "Snapshots hide NPC buyer ceilings")
	expect(not player.chats.is_empty(), "Snapshot filtering never mutates authority")
	game.state.players.erase(2)
	game.state.remaining = 0.1
	game.advance_time(1)
	expect(game.state.phase == "results" and player.score.total == 0, "Deadline finishes an incomplete build safely")
	var old_id: int = game.state.match_id
	player = fresh()
	expect(game.state.match_id > old_id and player.cash == 1000, "Replay resets run state with a fresh identity")
	Store.save_best({"Balanced": 123, "CPU": "corrupt", "GPU": -2}, game.score_path)
	var saved := Store.load_best(game.score_path)
	expect(saved.Balanced == 123 and not saved.has("CPU") and saved.GPU == 0, "High scores round-trip and malformed values are sanitized")


func _test_screens() -> void:
	game.leave()
	var shell: Control = load("res://src/main.tscn").instantiate()
	root.add_child(shell)
	await process_frame
	expect(shell.get_node("Screens").get_child_count() == 1, "Menu mounts as an independent screen")
	var player := fresh()
	game.changed.emit()
	await process_frame
	var screen: Control = shell.get_node("Screens").get_child(0)
	expect(screen.has_method("_toggle_phone"), "Solo transition mounts game screen")
	var notice := "Lucky hears your prayer. One risky test gets 25% less danger."
	game.text_player(game.local_id(), notice)
	game.notice.emit("Walk to the door, workbench, or armchair. P opens your phone.")
	expect(game.me().lucky_messages.back().text == notice and screen._context_label.text.begins_with("Walk to"),
		"World texts reach Lucky while action feedback stays in the bottom bar")
	screen._toggle_phone()
	expect(screen._phone_motion == "opening" and screen._phone_slide == 1.0, "Phone starts below the viewport")
	expect(screen._phone._viewport.gui_disable_input, "Phone input is locked during entry")
	expect(screen._phone._viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"Off-screen cover renders before entry rather than waiting for texture visibility")
	await create_timer(0.12).timeout
	expect(screen._phone_slide < 0.7 and screen._phone_slide > 0.0, "Phone entry eases out rather than moving linearly")
	await _wait_phone_motion(screen, "open")
	for frame in 3:
		await process_frame
	expect(screen._phone_layer.visible, "Phone opens after solo start")
	var device: Control = screen._phone._device
	expect(device._brand.is_visible_in_tree() and device.get_global_rect().encloses(device._brand.get_global_rect()),
		"First opening a previously hidden phone places its brand inside the casing")
	expect(device._display.size.x > 0 and device._display.size.y > 0,
		"First phone opening lays out the cover display without a fold cycle")
	var initial_brand: Rect2 = device._brand.get_rect()
	screen._phone.set_unfolded(true)
	for frame in 3:
		await process_frame
	screen._phone.set_unfolded(false)
	for frame in 3:
		await process_frame
	expect(device._brand.get_rect().is_equal_approx(initial_brand), "Refolding preserves the correct first-open brand position")
	screen._phone.set_unfolded(true)
	screen._toggle_phone()
	screen._toggle_phone()
	await _wait_phone_motion(screen, "opening")
	expect(not screen._phone.unfolded and not screen._phone.is_folding(),
		"Previously unfolded phone starts entry closed without unfolding during the slide")
	await create_timer(0.12).timeout
	expect(screen._phone_motion == "opening" and not screen._phone.unfolded,
		"Previously unfolded phone stays closed throughout entry")
	await _wait_phone_motion(screen, "open")
	for frame in 3:
		await process_frame
	expect(screen._phone.unfolded and screen._phone.size.x > 500 and device._fault.visible,
		"Taking the phone out again automatically unfolds the remembered display after entry")
	screen._phone.set_unfolded(false)
	screen._close_phone()
	await _wait_phone_motion(screen, "hidden")
	screen._toggle_phone()
	await _wait_phone_motion(screen, "open")
	expect(not screen._phone.unfolded and not screen._phone.is_folding(),
		"Phone put away folded remains closed after entry")
	screen._phone.set_unfolded(true)
	var listing_id: int = game.state.listings[0].id
	screen._phone.open_listing(listing_id)
	for unfolded in [false, true]:
		screen._phone.set_unfolded(unfolded)
		await process_frame
		root.gui_release_focus()
		screen._phone._composer.grab_focus()
		screen._phone._composer.text = ""
		for letter in "tmbpewasd":
			_type_key(letter)
		expect(screen._phone._composer.text == "tmbpewasd", "Phone typing receives shortcut letters once in mode " + str(unfolded))
		expect(screen._phone_motion == "open" and not screen._workspace.visible and not screen._map_layer.visible,
			"Typing does not activate world shortcuts")
	screen._phone._composer.text = "Keep this message in my pocket"
	screen._phone.close_requested.emit()
	screen._toggle_phone()
	await _wait_phone_motion(screen, "open")
	for frame in 3:
		await process_frame
	expect(screen._phone.unfolded and screen._phone.selected == listing_id and screen._phone._composer.text == "Keep this message in my pocket",
		"Closing and reopening preserves the unfolded phone, conversation and draft")
	expect(screen._phone._viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS and screen._phone._screen.modulate.a == 1.0,
		"Reopened phone restores live rendering and opacity")
	# Simulate a fold still in flight without requiring GPU snapshots in headless CI.
	screen._phone.set_unfolded(true)
	screen._phone._folding = true
	screen._phone.close_requested.emit()
	expect(screen._phone_motion == "closing_fold" and screen._phone_layer.visible,
		"Pocketing waits for an in-flight fold")
	await create_timer(0.05).timeout
	expect(is_zero_approx(screen._phone_slide), "Phone stays on screen until folding finishes")
	screen._phone._finish_fold()
	await process_frame
	expect(not screen._phone.unfolded, "Phone folds shut before sliding out")
	expect(screen._phone._viewport.gui_disable_input, "Finishing a fold keeps input locked while pocketing")
	await _wait_phone_motion(screen, "hidden")
	expect(not screen._phone_layer.visible and is_equal_approx(screen._phone_slide, 1.0), "Phone hides only after reaching the pocket")
	await process_frame
	expect(screen._phone._viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Pocketed phone stops rendering")
	# Cancel before the render-preparation await finishes; stale entry work must not restart it.
	screen._toggle_phone()
	screen._close_phone()
	await _wait_phone_motion(screen, "hidden")
	expect(not screen._phone_layer.visible, "Closing before the first render cancels the pending reveal")
	expect(screen._phone_reopen_unfolded, "Cancelling before the first render retains the remembered unfolded mode")
	screen._toggle_phone()
	await create_timer(0.08).timeout
	expect(not screen._phone.unfolded, "Interrupted entry still shows the closed phone")
	screen._close_phone()
	await _wait_phone_motion(screen, "hidden")
	expect(not screen._phone_layer.visible, "Closing during entry cancels the old entry tween")
	expect(screen._phone_reopen_unfolded, "Cancelling during entry retains the remembered unfolded mode")
	screen._toggle_phone()
	await _wait_phone_motion(screen, "open")
	expect(screen._phone.unfolded, "Reopening after interrupted entries restores the remembered unfolded mode")
	expect(is_zero_approx(screen._phone_slide) and not screen._phone._viewport.gui_disable_input, "Reopening restores position and input")
	screen._toggle_map()
	await _wait_phone_motion(screen, "hidden")
	await process_frame
	expect(screen._map_layer.visible and not screen._phone_layer.visible, "Map and phone overlays exclude each other")
	player.pos = World.BENCH + Vector2(0, 30)
	screen._open_workspace("bench")
	await process_frame
	expect(screen._workspace.visible and screen._bench.visible, "Workbench mounts next to the home bench")
	screen._open_workspace("tune")
	await process_frame
	expect(screen._tune.visible, "Tuning screen mounts")
	game.end_match()
	game.changed.emit()
	await process_frame
	expect(shell.get_node("Screens").get_child(0).has_signal("replay"), "Results screen mounts")
	expect(game.me().lucky_messages[0].text == notice, "Lucky's texts remain in match history after the deadline")
	game.solo("Replay", 600, "CPU")
	game.changed.emit()
	await process_frame
	expect(shell.get_node("Screens").get_child_count() == 1, "Replay disposes previous screen subtree")
	expect(game.me().lucky_messages.is_empty(), "Replay starts a fresh Lucky conversation")
	shell.queue_free()
	await process_frame
