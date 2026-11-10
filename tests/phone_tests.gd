extends RefCounted
## Real Control layout and offline messaging; no interactive playtest or paid provider calls.
const K = preload("res://src/ui/ui_kit.gd")
var game: Node
var check: Callable
var phone: Control


func run(session: Node, assertion: Callable) -> void:
	game = session
	check = assertion
	game.solo("Fold Test", 1000, "Balanced")
	game.set_process(false)
	game.set_physics_process(false)
	var player: Dictionary = game.me()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	game.get_tree().root.add_child(viewport)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.theme = K.make_theme()
	viewport.add_child(center)
	phone = load("res://src/trading/phone.tscn").instantiate()
	center.add_child(phone)
	phone.refresh()
	await settle()
	check.call(not phone.unfolded and not phone._nav.visible, "LuckyFold opens on the cover inbox")
	check.call(phone._device._brand.visible and phone._device._brand.text == "LuckyFold Duo", "Cover has the requested live brand label")
	check.call(phone._device._brand.position.y >= phone._device._display.get_rect().end.y, "Brand occupies the free space below the cover display")
	check.call(not phone._device._fault.visible, "Healthy cover display hides the inner-screen fault")
	check.call(phone._device._fault.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Display fault cannot steal clicks")
	check.call(phone.size.x < 500 and phone.size.y <= viewport.size.y, "Cover fits a 1280x720 viewport")
	phone._open_marketplace()
	await settle()
	check.call(phone.unfolded and phone.page == "browse" and phone._nav.visible, "Unfolding exposes the full marketplace")
	check.call(phone._device._fault.visible and not phone._device._brand.visible, "Inner display shows its fault without the cover label")
	check.call(phone.size.x > 900 and phone.size.x <= viewport.size.x, "Unfolded device uses the wider screen")
	var listing: Dictionary = game.state.listings[0]
	phone.open_listing(listing.id)
	await settle()
	phone._composer.text = "Does Lucky approve of this one?"
	phone._composer.grab_focus()
	phone._composer.caret_column = 8
	phone.set_unfolded(false)
	await settle()
	check.call(phone.selected == listing.id and phone._composer.text == "Does Lucky approve of this one?", "Folding preserves the selected conversation and draft")
	check.call(phone._composer.has_focus() and phone._composer.caret_column == 8, "Folding preserves composer focus and caret")
	check_layout("Cover conversation")
	phone._slots = true
	phone._sig = ""
	phone.refresh()
	await settle()
	check_layout("Cover meeting suggestions")
	phone._slots = false
	phone._send_text("Is it still available?")
	phone.refresh()
	check.call(player.chats.has(listing.id) and phone._send.disabled, "Cover messages use the real host dialogue path")
	phone.set_unfolded(true)
	await settle()
	check.call(phone._composer.text == "", "Sent cover message is not restored as an unsent draft")
	var other: Dictionary = game.state.listings[1]
	phone.open_listing(other.id)
	phone._composer.text = "Keep this draft while waiting"
	phone._send_text(phone._composer.text)
	check.call(not player.chats.has(other.id) and phone._composer.text == "Keep this draft while waiting", "Pending reply in another thread preserves the new draft")
	await game.get_tree().create_timer(0.6).timeout
	phone.refresh()
	check.call(not phone._send.disabled, "Composer unlocks after another thread's reply")
	phone.open_listing(listing.id)
	await settle()
	check.call(phone._log.get_child_count() >= 2, "Unfolded thread contains the same cover conversation and reply")
	check_layout("Unfolded conversation")
	var rows: Array = phone._log.get_children()
	var incoming: Control
	var outgoing: Control
	for row: Control in rows:
		if row.alignment == BoxContainer.ALIGNMENT_BEGIN:
			incoming = row.get_child(0)
		elif row.alignment == BoxContainer.ALIGNMENT_END:
			outgoing = row.get_child(0)
	check.call(is_instance_valid(incoming) and is_instance_valid(outgoing) and incoming.global_position.x < outgoing.global_position.x,
		"Incoming bubbles are visibly left of outgoing bubbles")
	phone.set_unfolded(false)
	phone._inbox()
	await settle()
	var old_sig: String = phone._sig
	game.dialogue.say(player, listing.id, listing.seller, "A new reply on the cover.")
	phone.refresh()
	check.call(phone._sig != old_sig, "Cover inbox updates existing threads when new replies arrive")
	phone.open_listing(other.id)
	check.call(phone._composer.text == "Keep this draft while waiting", "Drafts stay associated with the correct listing")
	other.status = "sold"
	phone.refresh()
	phone._send_text("Too late")
	check.call(phone._send.disabled and not player.chats.has(other.id), "Sold listings disable cover and inner-screen messaging")
	phone._show("sell")
	await settle()
	check.call(phone.unfolded and phone.page == "sell", "Selling automatically opens the full display")
	phone.set_unfolded(false)
	phone.set_unfolded(true)
	check.call(phone.page == "sell", "Folding restores the last marketplace tab")
	viewport.size = Vector2i(1440, 900)
	await settle()
	check.call(phone.size.y == 760 and phone.size.x == 1000, "Device adapts to the larger supported viewport")
	phone.open_listing(listing.id)
	await settle()
	check_layout("Larger unfolded conversation")
	var relationships = preload("res://src/trading/contact_relationships.gd")
	relationships.assess(player, listing, "You are an idiot", 0, "warn")
	relationships.assess(player, listing, "Enough", 0, "block")
	other.status = "available"
	other.character_id = listing.character_id
	other.seller = listing.seller
	phone.open_listing(other.id)
	await settle()
	check.call(not phone._composer.editable and phone._send.disabled, "Unfolded phone locks typing and sending on another listing from a blocked contact")
	phone.set_unfolded(false)
	await settle()
	check.call(not phone._composer.editable and phone._send.disabled, "Cover phone also locks a blocked contact's other listing")
	viewport.queue_free()
	await settle()


func settle() -> void:
	for frame in 4:
		await game.get_tree().process_frame


func check_layout(context: String) -> void:
	var display: Rect2 = phone._device._display.get_global_rect()
	check.call(display.encloses(phone._composer.get_global_rect()) and display.encloses(phone._send.get_global_rect()), context + " keeps message controls inside the display")
	check.call(phone._scroll.size.y >= 90, context + " retains usable message history space")
	if phone.unfolded:
		var fault: TextureRect = phone._device._fault
		var image: Image = fault.texture.get_image()
		var first_damaged_row := float(image.get_used_rect().position.y) / image.get_height()
		var damage_top := fault.global_position.y + fault.size.y * first_damaged_row
		var damage_bottom: float = fault.global_position.y + fault.size.y * phone._device.DISPLAY_FAULT_BAND_BOTTOM
		var composer: Rect2 = phone._composer.get_global_rect()
		check.call(composer.position.y >= damage_top and composer.position.y < damage_bottom,
			context + " tucks the message box's upper edge behind the broken line")
		for control: Control in [phone._composer, phone._send]:
			var font: Font = control.get_theme_font("font")
			var text_top: float = control.global_position.y + (control.size.y - font.get_height(control.get_theme_font_size("font_size"))) * 0.5
			check.call(text_top > damage_bottom, context + " keeps input and Send text below the damaged rows")
		check.call(composer.position.x >= phone._device.message_text_left() - 1,
			context + " keeps typing to the right of the damaged vertical column")
		var conversation: Control = phone._composer.get_parent().get_parent()
		check.call(conversation.get_child(-2).get_global_rect().end.y < damage_top,
			context + " keeps quick replies above the damaged display")
		check.call(composer.end.y < phone._device._caption.global_position.y,
			context + " leaves the mood-lighting footer clear")
