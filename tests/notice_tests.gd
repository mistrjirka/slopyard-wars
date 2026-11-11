extends RefCounted
## World texts, read-only phone history and immediate invalid-action feedback.
const Activities = preload("res://src/world/activities.gd")
const World = preload("res://src/world/world_rules.gd")
const Snapshot = preload("res://src/network/snapshot.gd")
var game: Node
var check: Callable
var phone: Control
var screen: Control
var viewport: SubViewport


func run(session: Node, assertion: Callable) -> void:
	game = session
	check = assertion
	game.solo("Lucky", 1000, "Balanced")
	game.set_process(false)
	game.set_physics_process(false)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	game.get_tree().root.add_child(viewport)
	var shell: Control = load("res://src/main.tscn").instantiate()
	viewport.add_child(shell)
	await settle()
	screen = shell.get_node("Screens").get_child(0)
	phone = screen._phone
	check.call(not shell.has_node("Toasts/Lucky") and shell._toasts.get_child_count() == 0,
		"The world has no Lucky portrait, bubble or history widget")
	check.call(game.me().lucky_messages.is_empty(), "Lucky is absent until the first world-event text")
	var player: Dictionary = game.me()
	player.area = "town"
	player.pos = Vector2(1100, 800)
	game.act("interact")
	check.call(screen._feedback_remaining > 0 and screen._context_label.text.begins_with("E:") and player.lucky_messages.is_empty(),
		"Pressing E away from an interaction gives bottom-bar feedback without texting Lucky")
	var shrine: Resource = Activities.ALL.filter(func(activity): return activity.kind == "lucky")[0]
	player.pos = shrine.position
	game.act("world_activity", {"activity_id": shrine.id})
	screen.refresh()
	check.call(player.lucky_messages.size() == 1 and player.lucky_messages[0].text.contains("Lucky"),
		"A successful shrine visit creates Lucky's first incoming text")
	check.call(player.lucky_messages[0].place == shrine.display_name, "Lucky records the exact activity as the message's place")
	check.call(screen.get_node("Topbar/Row/PhoneBtn").text.contains("1") and not screen._phone_layer.visible,
		"A small unread count announces the text without opening the phone")
	var count: int = player.lucky_messages.size()
	game.act("world_activity", {"activity_id": shrine.id})
	check.call(player.lucky_messages.size() == count and screen._feedback_remaining > 0,
		"An unavailable activity keeps its rejection in the bottom bar")
	screen._toggle_phone()
	var deadline := Time.get_ticks_msec() + 3000
	while screen._phone_motion != "open" and Time.get_ticks_msec() < deadline:
		await game.get_tree().process_frame
	await settle()
	phone._body.get_child(0).get_node("Unfold").pressed.emit()
	phone.set_unfolded(false)
	await settle()
	var inbox: Control = phone._body.get_child(0)
	check.call(inbox.box.get_child_count() == 2 and inbox.box.get_child(1).seller_label.text.begins_with("Lucky"),
		"Lucky magically appears as a separate inbox contact on the cover")
	check.call(inbox.box.get_child(1)._unread_dot.visible, "Lucky's unread contact has a blue dot")
	inbox.box.get_child(1).pressed.emit()
	await settle()
	check.call(phone.selected == phone.LUCKY_CONTACT_ID and phone._log.get_child_count() == 1,
		"Selecting Lucky opens his saved text history")
	check.call(phone._log.get_child(0).place_label.text == "From " + shrine.display_name,
		"Lucky's message header includes the place where the event happened")
	player.area = "home"
	phone.refresh()
	check.call(player.lucky_messages[0].place == shrine.display_name and phone._log.get_child(0).place_label.text.contains(shrine.display_name),
		"Travelling later does not change a historical message's place")
	check.call(not is_instance_valid(phone._composer) and not is_instance_valid(phone._send),
		"Lucky's conversation has no composer or send button")
	check.call(not phone._lucky_view.portrait_panel.visible and phone.lucky_unread_count() == 0,
		"The cover keeps Lucky's texts readable and marks them read")
	phone._send_text("Can you hear me?")
	check.call(player.lucky_messages.size() == count and not player.chats.has(phone.LUCKY_CONTACT_ID),
		"Even direct send attempts cannot reply to Lucky or create a trading conversation")
	phone.set_unfolded(true)
	await settle()
	check.call(phone._lucky_view.portrait_panel.visible and phone._lucky_view.portrait.texture.resource_path == "res://assets/decorations/lucky/statue_lucky.png",
		"The unfolded conversation displays the existing Lucky asset on the left")
	check_layout("Unfolded Lucky conversation")
	for index in 60:
		game.text_player(game.local_id(), "World text %d. May your frames be high and your magic smoke remain inside." % index)
	phone.refresh()
	await settle()
	check.call(phone._log.get_child_count() == 61 and phone._lucky_view._at_latest(), "Lucky retains more than forty texts and follows the newest")
	var view: Control = phone._lucky_view
	var newest_scroll: int = phone._scroll.scroll_vertical
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.position = phone._scroll.get_global_rect().get_center()
	wheel.global_position = wheel.position
	wheel.pressed = true
	phone._viewport.push_input(wheel, true)
	wheel = wheel.duplicate()
	wheel.pressed = false
	phone._viewport.push_input(wheel, true)
	await settle()
	check.call(phone._scroll.scroll_vertical < newest_scroll, "The phone's captured viewport accepts mouse-wheel history scrolling")
	phone._scroll.scroll_vertical = 0
	await settle()
	game.text_player(game.local_id(), "One more text while reading the first.")
	phone.refresh()
	await settle()
	check.call(phone._lucky_view == view and phone._scroll.scroll_vertical == 0 and view.latest_button.visible,
		"Incoming texts preserve the conversation and the reader's scroll position")
	view.latest_button.pressed.emit()
	await settle()
	check.call(view._at_latest(), "New messages button returns to the latest Lucky text")
	viewport.size = Vector2i(1152, 720)
	await settle()
	check_layout("Lucky conversation at the minimum window size")
	phone.set_unfolded(false)
	await settle()
	check_layout("Lucky conversation on the cover")
	check.call(not phone._lucky_view.portrait_panel.visible and phone._log.get_child_count() == 62,
		"Folding retains the full read-only history")
	# Switching to Lucky and back must preserve a real seller's draft.
	var listing_id: int = game.state.listings[0].id
	phone.open_listing(listing_id)
	phone._composer.text = "Keep this seller draft."
	phone.open_lucky()
	phone.open_listing(listing_id)
	check.call(phone._composer.text == "Keep this seller draft.", "Lucky's special conversation does not overwrite seller drafts")
	phone._inbox()
	game.text_player(game.local_id(), "Another unread world text.")
	phone.refresh()
	await settle()
	check.call(phone.lucky_unread_count() == 1, "Other conversations leave new Lucky texts unread")
	check.call(phone._body.get_child(0).box.get_child(1)._unread_dot.visible, "A new Lucky text restores the inbox dot")
	phone.open_lucky()
	phone._inbox()
	check.call(not phone._body.get_child(0).box.get_child(1)._unread_dot.visible, "Reading Lucky's conversation clears its dot")
	var listing: Dictionary = game.state.listings[0]
	game.dialogue.say(player, listing_id, listing.seller, "First unread reply.")
	phone.refresh()
	var seller_row: Button = phone._body.get_child(0).box.get_child(2)
	check.call(seller_row._unread_dot.visible and phone.unread_count() == 1, "Unread seller replies receive the same blue dot")
	seller_row.set_meeting_confirmed(true)
	check.call(not seller_row._unread_dot.get_rect().intersects(seller_row._meeting_badge.get_rect()),
		"Unread dots leave confirmed-meeting badges visible")
	seller_row.pressed.emit()
	phone._inbox()
	check.call(not phone._body.get_child(0).box.get_child(2)._unread_dot.visible and phone.unread_count() == 0,
		"Opening a seller conversation clears its unread indicator")
	game.dialogue.say(player, listing_id, player.name, "My own message.")
	game.dialogue.say(player, listing_id, "system", "The seller is typing...", true)
	phone.refresh()
	check.call(phone.unread_count() == 0, "Outgoing messages and typing placeholders never count as unread")
	for index in 30:
		game.dialogue.say(player, listing_id, listing.seller, "The same reply.")
	phone.open_listing(listing_id)
	phone._inbox()
	var history_size: int = player.chats[listing_id].size()
	game.dialogue.say(player, listing_id, listing.seller, "The same reply.")
	phone.refresh()
	check.call(player.chats[listing_id].size() == history_size and phone.unread_count() == 1,
		"Repeated replies remain unread even after the capped conversation drops older messages")
	var buyer_listing: Dictionary = game.state.listings[1]
	buyer_listing.owner = game.local_id()
	buyer_listing.seller = "Test Buyer"
	game.dialogue.say(player, buyer_listing.id, buyer_listing.seller, "Can I buy your part?")
	phone.refresh()
	var buyer_row: Button = phone._body.get_child(0).box.get_child(2)
	check.call(buyer_row.seller_label.text.contains("BUYER") and buyer_row._unread_dot.visible and phone.unread_count() == 2,
		"Unread buyer messages are counted independently from seller messages")
	buyer_row.pressed.emit()
	phone._inbox()
	check.call(not phone._body.get_child(0).box.get_child(2)._unread_dot.visible and phone.unread_count() == 1,
		"Reading a buyer's messages leaves the seller's unread message intact")
	screen._feedback_remaining = 0
	screen._update_world_hud()
	check.call(not screen._context_label.text.contains("Another unread"), "World texts do not replace immediate bottom-bar guidance")
	game.state.players[2] = preload("res://src/core/state_factory.gd").player("Other player")
	game.text_player(2, "Another player's private Lucky text.")
	var snapshot: Dictionary = Snapshot.for_player(game.state, 1)
	check.call(snapshot.players[2].lucky_messages.is_empty() and snapshot.players[1].lucky_messages.size() == 63,
		"LAN snapshots retain the recipient's Lucky history and hide other players' texts")
	viewport.queue_free()
	await game.get_tree().process_frame
	await _meeting_reminders()


func _reminder_fixture() -> Dictionary:
	game.solo("Meeting reminder", 1000, "Balanced")
	game.set_process(false)
	game.set_physics_process(false)
	var player: Dictionary = game.me()
	for listing: Dictionary in game.state.listings:
		for slot: Dictionary in game.contact_options(listing):
			if float(slot.start) >= 1080.0:
				continue
			player.offers[listing.id] = int(listing.price)
			game.act("choose_meeting", {"match_id": game.state.match_id, "listing_id": listing.id, "meeting_id": slot.id})
			check.call(player.meetings.has(listing.id), "Reminder fixture confirms a real host-owned meeting")
			return {"player": player, "listing": listing, "meeting": player.meetings.get(listing.id, {})}
	check.call(false, "Reminder fixture finds a morning/daytime contact")
	return {}


func _reminder_messages(player: Dictionary) -> Array:
	return player.lucky_messages.filter(func(message: Dictionary): return str(message.text).begins_with("Meeting "))


func _meeting_reminders() -> void:
	var fixture := _reminder_fixture()
	if fixture.is_empty():
		return
	var player: Dictionary = fixture.player
	var listing: Dictionary = fixture.listing
	var meeting: Dictionary = fixture.meeting
	var other := preload("res://src/core/state_factory.gd").player("Other recipient")
	other.offers[listing.id] = int(listing.price)
	other.meetings[listing.id] = meeting.duplicate(true)
	game.state.players[2] = other
	viewport = SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	game.get_tree().root.add_child(viewport)
	var shell: Control = load("res://src/main.tscn").instantiate()
	viewport.add_child(shell)
	await settle()
	screen = shell._screen
	phone = screen._phone
	var unread_before: int = phone.unread_count()
	game.advance_time(float(meeting.start) - 20.25 - game.clock())
	check.call(_reminder_messages(player).is_empty(), "Phone reminder is not sent before the twenty-minute threshold")
	game.advance_time(0.25)
	game.changed.emit()
	var messages := _reminder_messages(player)
	check.call(messages.size() == 1 and messages[0].text.contains("20 min") and messages[0].text.contains(listing.seller) and messages[0].text.contains(meeting.place) and messages[0].place == meeting.place, "Twenty-minute phone reminder names the contact and exact meeting place")
	check.call(phone.lucky_unread_count() == 1 and phone.unread_count() == unread_before + 1 and not screen._phone_layer.visible, "Reminder arrives as an unread phone notification without opening it")
	var snapshot := Snapshot.for_player(game.state, 1)
	check.call(_reminder_messages(other).size() == 1 and snapshot.players[2].lucky_messages.is_empty(), "Each recipient gets a private reminder without exposing another player's history")
	game.advance_time(1)
	game.act("choose_meeting", {"match_id": game.state.match_id, "listing_id": listing.id, "meeting_id": meeting.id})
	game.advance_time(1)
	check.call(_reminder_messages(player).size() == 1 and player.meetings[listing.id].get("reminder_sent", false), "Further ticks and reaffirming the same slot cannot repeat its reminder")
	screen._toggle_phone()
	var deadline := Time.get_ticks_msec() + 3000
	while screen._phone_motion != "open" and Time.get_ticks_msec() < deadline:
		await game.get_tree().process_frame
	var intro: Button = phone._body.get_child(0).get_node_or_null("Unfold")
	if intro != null:
		intro.pressed.emit()
	phone.set_unfolded(false)
	phone.open_lucky()
	await settle()
	check.call(phone._log.get_child_count() == 1 and phone._log.get_child(0).place_label.text == "From " + str(meeting.place) and phone.lucky_unread_count() == 0, "Opening Lucky displays the saved meeting reminder and clears its notification")
	var choices: Array = game.contact_options(listing)
	check.call(not choices.is_empty(), "A later meeting remains available for reminder rescheduling")
	if not choices.is_empty():
		game.act("choose_meeting", {"match_id": game.state.match_id, "listing_id": listing.id, "meeting_id": choices[0].id})
		var rescheduled: Dictionary = player.meetings[listing.id]
		check.call(rescheduled.id != meeting.id and not rescheduled.get("reminder_sent", false), "Rescheduling creates a fresh reminder rather than inheriting the old flag")
		game.advance_time(float(rescheduled.start) - 20.0 - game.clock())
		check.call(_reminder_messages(player).size() == 2 and rescheduled.get("reminder_sent", false), "The rescheduled meeting receives exactly its own twenty-minute reminder")
	viewport.queue_free()
	await game.get_tree().process_frame
	for reason: String in ["unagreed", "blocked", "sold", "cancelled", "ready", "expired", "already_started"]:
		fixture = _reminder_fixture()
		if fixture.is_empty():
			return
		player = fixture.player
		listing = fixture.listing
		meeting = fixture.meeting
		match reason:
			"unagreed": player.offers.erase(listing.id)
			"blocked": player.contact_relations[str(listing.character_id)] = {"blocked": true}
			"sold": listing.status = "sold"
			"cancelled": player.meetings.erase(listing.id)
			"ready": player.ready = true
			"already_started": game.state.remaining = game.deadline() - (float(meeting.start) + 5.0)
		var advance: float = 1.0 if reason == "already_started" else float(meeting.start) - 20.0 - game.clock()
		if reason == "expired":
			advance = float(meeting.end) - game.clock() + 1.0
		game.advance_time(advance)
		check.call(_reminder_messages(player).is_empty(), "No stale or unavailable meeting reminder: " + reason)
	fixture = _reminder_fixture()
	if not fixture.is_empty():
		player = fixture.player
		meeting = fixture.meeting
		game.advance_time(float(meeting.start) - game.clock() + 5.0)
		messages = _reminder_messages(player)
		check.call(messages.size() == 1 and messages[0].text.begins_with("Meeting now:"), "Skipping over the reminder and start reports an open meeting, not a false future time")


func settle() -> void:
	for frame in 8:
		await game.get_tree().process_frame


func check_layout(context: String) -> void:
	var display: Rect2 = phone._device._display.get_global_rect()
	var scroll: Rect2 = phone._scroll.get_global_rect()
	check.call(display.encloses(scroll) and scroll.size.y > 150, context + " keeps useful scrolling history inside the display")
	var horizontal: ScrollBar = phone._scroll.get_h_scroll_bar()
	check.call(horizontal.max_value <= horizontal.page + 1, context + " wraps text without horizontal scrolling")
	if phone.unfolded:
		var portrait: Rect2 = phone._lucky_view.portrait.get_global_rect()
		check.call(display.encloses(portrait) and portrait.end.x < scroll.position.x and portrait.size.x > 100,
			context + " places a large Lucky portrait left of the messages")
		check.call(is_equal_approx(scroll.end.y, phone._lucky_view.portrait_panel.get_global_rect().end.y),
			context + " fills the right half down to the bottom of the phone content")
