extends Control
## LuckyFold app controller. Cover messages and unfolded marketplace share one conversation/draft state.
const Device = preload("res://src/trading/luckyfold_shell.gd")
const Stats = preload("res://src/data/hardware_stats.gd")
const Characters = preload("res://src/data/characters.gd")
const K = preload("res://src/ui/ui_kit.gd")
const Art = preload("res://src/ui/part_art.gd")
const Trade = preload("res://src/trading/trade_rules.gd")
const Catalog = preload("res://src/data/catalog.gd")
signal close_requested
signal track_requested(listing_id: int)
var page := "browse"
var selected := -1
var _body: VBoxContainer
var _clock: Label
var _tabs := {}
var _sig := ""
var _composer: LineEdit
var _send: Button
var _log: VBoxContainer
var _scroll: ScrollContainer
var _context: Label
var _search := ""
var _slots := false
var _drafts := {}
var _device: Control
var _nav: HBoxContainer
var _mode_button: Button
var _heading: Label
var unfolded: bool:
	get:
		return _device.unfolded


func _init() -> void:
	_device = Device.new()
	_device.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_device)
	_device.minimum_size_changed.connect(_sync_size)
	_sync_size()
	var shell: VBoxContainer = _device.content
	var status := K.hbox(8)
	_clock = K.lbl("", "Tiny", K.SKY)
	status.add_child(_clock)
	status.add_child(K.spacer())
	status.add_child(K.btn("×", "GhostButton", func(): close_requested.emit()))
	shell.add_child(status)
	var brand := K.hbox(8)
	_heading = K.lbl("QUICK MESSAGES", "H2", K.SKY)
	brand.add_child(_heading)
	brand.add_child(K.spacer())
	_mode_button = K.btn("UNFOLD", "PrimaryButton", _toggle_fold)
	brand.add_child(_mode_button)
	shell.add_child(brand)
	_nav = K.hbox(6)
	for tab in [["browse", "Browse"], ["messages", "Messages"], ["sell", "Sell"]]:
		var b := K.btn(tab[1], "TabButton", _show.bind(tab[0]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_nav.add_child(b)
		_tabs[tab[0]] = b
	shell.add_child(_nav)
	_nav.hide()
	_body = K.vbox(8)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(_body)
	shell.add_child(K.lbl("P / Esc: pocket · clock keeps running", "Tiny", K.MUTED, true))


func _sync_size() -> void:
	custom_minimum_size = _device.get_combined_minimum_size()


func _toggle_fold() -> void:
	set_unfolded(not unfolded)


func set_unfolded(value: bool) -> void:
	_save_draft()
	_device.set_unfolded(value)
	_nav.visible = value
	_heading.text = "MARKETPLACE" if value else "QUICK MESSAGES"
	_mode_button.text = "FOLD" if value else "UNFOLD"
	_mode_button.tooltip_text = "Use the cover screen for messages" if value else "Open the full marketplace"
	_sig = ""
	refresh()


func _open_marketplace() -> void:
	_save_draft()
	page = "browse"
	set_unfolded(true)


func _inbox() -> void:
	_save_draft()
	_composer = null
	selected = -1
	_show("messages")


func open_listing(id: int) -> void:
	_save_draft()
	_composer = null
	selected = id
	_slots = false
	_show("messages")


func _show(which: String) -> void:
	_save_draft()
	page = which
	if which != "messages" and not unfolded:
		set_unfolded(true)
	_sig = ""
	refresh()


func _save_draft() -> void:
	if is_instance_valid(_composer):
		_drafts[selected] = _composer.text


func _listing(id: int) -> Dictionary:
	for l in Game.state.listings:
		if int(l.id) == id:
			return l
	return {}


func refresh() -> void:
	if not is_visible_in_tree() or Game.me().is_empty():
		return
	_clock.text = Trade.stamp(Game.clock()) + "   ·   $%d" % int(Game.me().cash)
	var me: Dictionary = Game.me()
	var active_page := page if unfolded else "messages"
	var sig := str(unfolded) + active_page + str(selected)
	sig += str(_waiting_for_reply()) + str(me.ready)
	if active_page == "messages" and selected >= 0:
		var l := _listing(selected)
		sig += str(me.chats.get(selected, [])).sha256_text() + str(me.offers.get(selected, 0)) + str(me.meetings.get(selected, {})) + str(l.get("status", "gone")) + str(_slots)
		if me.meetings.has(selected):
			sig += str(Game.clock() > float(me.meetings[selected].end))
	elif active_page == "sell":
		sig += str(me.inventory) + str(Game.state.listings.filter(func(l): return int(l.get("owner", 0)) == Game.local_id()))
	else:
		for l in Game.state.listings:
			sig += "%d%s%d" % [l.id, l.status, l.price]
		if active_page == "messages":
			sig += str(me.chats) + str(me.meetings)
	if sig == _sig:
		return
	var refocus := is_instance_valid(_composer) and _composer.has_focus()
	var caret := _composer.caret_column if refocus else 0
	_save_draft()
	_sig = sig
	K.clear(_body)
	_composer = null
	for key in _tabs:
		_tabs[key].button_pressed = key == active_page
	if active_page == "browse":
		_browse()
	elif active_page == "sell":
		_sell()
	elif selected < 0:
		_threads()
	else:
		_thread()
	if refocus and is_instance_valid(_composer):
		_composer.grab_focus()
		_composer.caret_column = caret


func _browse() -> void:
	var hint := K.lbl("Message someone. Agree a price, then a place and time. No checkout button.", "Muted", null, true)
	_body.add_child(hint)
	var search := LineEdit.new()
	search.placeholder_text = "Search parts or sellers..."
	search.text = _search
	_body.add_child(search)
	var scroll := K.scroll()
	_body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var cards: Array = []
	for l in Game.state.listings:
		if int(l.get("owner", 0)) != 0 or l.status != "available":
			continue
		var card := K.panel("CardTight")
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var box := K.vbox(3)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var art: Control = Art.new()
		art.custom_minimum_size = Vector2(150, 72)
		art.show_item(l)
		box.add_child(art)
		box.add_child(K.lbl("$%d" % int(l.price), "Big", K.SKY))
		var name_label := K.lbl(str(l.get("manufacturer", "")) + " " + str(l.name), "", K.CREAM, true)
		name_label.custom_minimum_size.x = 180
		box.add_child(name_label)
		var detail := "Condition %d/100" % int(l.get("condition", 100))
		if str(l.category) in ["cpu", "gpu", "ram", "storage"]:
			detail += " · stock %d" % roundi(Stats.stock_score(l))
		if float(l.get("oc_potential", 0)) > 0:
			detail += " · OC +%d%%" % roundi(float(l.oc_potential) * 100)
		box.add_child(K.lbl(detail, "Tiny", K.LIME, true))
		var stock_fault := Stats.stock_failure_chance(l)
		if stock_fault > 0:
			box.add_child(K.lbl("RELIABILITY WARNING · %.1f%% stock failure risk" % (stock_fault * 100), "Tiny", K.ORANGE, true))
		var fire := Stats.stock_fire_chance(l)
		if fire > 0:
			box.add_child(K.lbl("CONNECTOR FIRE · %.1f%% at stock; higher when overclocked" % (fire * 100), "Tiny", K.ORANGE, true))
		box.add_child(K.lbl(Stats.value_text(l), "Tiny", K.MUTED, true))
		box.add_child(K.lbl(str(l.seller) + " · " + str(l.location), "Tiny", null, true))
		card.add_child(box)
		card.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				open_listing(int(l.id)))
		grid.add_child(card)
		cards.append([card, (str(l.name) + str(l.seller) + str(l.category)).to_lower()])
	search.text_changed.connect(func(t: String):
		_search = t
		for pair in cards:
			pair[0].visible = t == "" or t.to_lower() in pair[1])
	for pair in cards:
		pair[0].visible = _search == "" or _search.to_lower() in pair[1]


func _threads() -> void:
	_body.add_child(K.lbl("INBOX", "Eyebrow"))
	if not unfolded:
		_body.add_child(K.lbl("Reply here. Unfold to browse parts, inspect specs or sell a spare.", "Muted", null, true))
		var meetings: Array = Game.active_meetings(Game.me())
		if not meetings.is_empty():
			_body.add_child(K.lbl("APPOINTMENT · " + str(meetings[0].label), "Tiny", K.LIME, true))
	var scroll := K.scroll()
	_body.add_child(scroll)
	var box := K.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var me: Dictionary = Game.me()
	if me.chats.is_empty():
		box.add_child(K.lbl("No messages yet. Local bargains and questionable life advice await inside.", "Muted", null, true))
	var ids: Array = me.chats.keys()
	ids.reverse()
	for id in ids:
		var l := _listing(int(id))
		if l.is_empty():
			continue
		var msgs: Array = me.chats[id]
		var last: String = str(msgs[-1].text) if not msgs.is_empty() else "Start a conversation"
		var width := 80 if unfolded else 38
		var b := K.btn(str(l.seller) + (" · BUYER" if int(l.get("owner", 0)) > 0 else "") + "\n" + str(l.name).left(width) + "\n" + last.left(width), "", open_listing.bind(int(id)))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.custom_minimum_size.y = 82
		box.add_child(b)
	if not unfolded:
		_body.add_child(K.btn("Unfold marketplace", "PrimaryButton", _open_marketplace))


func _thread() -> void:
	var l := _listing(selected)
	if l.is_empty():
		_body.add_child(K.lbl("This old listing is gone.", "Muted"))
		_body.add_child(K.btn("All messages", "", _inbox))
		return
	var me: Dictionary = Game.me()
	var head := K.hbox(8)
	head.add_child(K.btn("‹", "GhostButton", _inbox))
	var contact := K.lbl(str(l.seller), "H2", K.SKY)
	contact.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contact.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(contact)
	head.add_child(K.lbl("BUYER" if int(l.get("owner", 0)) > 0 else "SELLER", "Tiny"))
	_body.add_child(head)
	_body.add_child(K.lbl(str(l.name) + " · Asking $%d" % int(l.price), "Tiny", null, true))
	var panes := K.hbox(16)
	panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(panes)
	if unfolded:
		var specifications := K.scroll()
		specifications.custom_minimum_size.x = 310
		panes.add_child(specifications)
		var details := K.vbox(10)
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		specifications.add_child(details)
		details.add_child(K.lbl(Characters.for_listing(l).tagline, "Tiny", K.SKY, true))
		details.add_child(K.lbl("HARDWARE NOTES", "Eyebrow"))
		details.add_child(K.lbl(Catalog.spec_text(l), "Tiny", K.MUTED, true))
		var schedule := Trade.profile(l.seller, l.location)
		details.add_child(K.lbl(str(schedule.note) + " Meets: " + ", ".join(schedule.places), "Tiny", K.SKY, true))
		_meeting_actions(details, l)
	var conversation := K.vbox(8)
	conversation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conversation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panes.add_child(conversation)
	_context = K.lbl("", "Tiny", K.CREAM, true)
	if me.meetings.has(selected):
		var m: Dictionary = me.meetings[selected]
		_context.text = ("MISSED — arrange another time: " if Game.clock() > float(m.end) else "MEETING: ") + str(m.label)
	elif me.offers.has(selected):
		_context.text = "Price agreed: $%d. Still arrange place and time." % int(me.offers[selected])
	else:
		_context.text = "No price agreement yet. Ask or make an offer in your own words."
	if l.status != "available":
		_context.text = str(l.status).to_upper() + " · this listing is no longer available."
	conversation.add_child(_context)
	if not unfolded:
		_meeting_actions(conversation, l)
	_scroll = K.scroll()
	_scroll.custom_minimum_size.y = 96
	conversation.add_child(_scroll)
	_log = K.vbox(6)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_log)
	var pending := false
	for msg: Dictionary in me.chats.get(selected, []):
		pending = pending or bool(msg.get("pending", false))
		var bubble := K.panel("BubbleMe" if str(msg.speaker) == str(me.name) else "BubbleThem")
		var col := K.SKY if str(msg.speaker) == str(me.name) else K.CREAM
		if msg.speaker == "system":
			col = K.ORANGE
		bubble.add_child(K.lbl(str(msg.speaker) + "\n" + str(msg.text), "", col, true))
		_log.add_child(bubble)
	if me.chats.get(selected, []).is_empty():
		_log.add_child(K.lbl("Say hello. People won't always know the specs, and they have lives outside the marketplace.", "Muted", null, true))
	var row := K.hbox(6)
	_composer = LineEdit.new()
	_composer.placeholder_text = "Quick message..." if not unfolded else "Message..."
	_composer.max_length = 240
	_composer.text = str(_drafts.get(selected, ""))
	_composer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_composer.text_submitted.connect(_send_text)
	row.add_child(_composer)
	_send = K.btn("Send", "PrimaryButton", func(): _send_text(_composer.text))
	_send.disabled = pending or _waiting_for_reply() or l.status != "available" or me.ready
	row.add_child(_send)
	conversation.add_child(row)
	var quick := K.hbox(4)
	for choice in [["Available?", "Is it still available?"], ["Confirm terms", "Yes, that price, time and place works."]]:
		var b := K.btn(choice[0], "GhostButton", _send_text.bind(choice[1]))
		b.tooltip_text = choice[1]
		b.add_theme_font_size_override("font_size", 11)
		b.disabled = _send.disabled
		quick.add_child(b)
	conversation.add_child(quick)
	_scroll_bottom.call_deferred(weakref(_scroll))


func _meeting_actions(parent: VBoxContainer, listing: Dictionary) -> void:
	var actions := K.hbox(6)
	actions.add_child(K.btn("Meeting times", "GhostButton", func(): _slots = not _slots; _sig = ""; refresh()))
	if Game.me().meetings.has(selected):
		actions.add_child(K.btn("Track", "PrimaryButton", func(): track_requested.emit(selected)))
	parent.add_child(actions)
	if not _slots:
		return
	var choices := K.vbox(4)
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if unfolded:
		parent.add_child(choices)
	else:
		var scroll := K.scroll()
		scroll.custom_minimum_size.y = 80
		scroll.size_flags_vertical = Control.SIZE_FILL
		scroll.add_child(choices)
		parent.add_child(scroll)
	for slot: Dictionary in Game.contact_options(listing):
		var b := K.btn(str(slot.label), "GhostButton", _send_text.bind("Can we meet " + str(slot.label) + "?"))
		b.add_theme_font_size_override("font_size", 11)
		b.clip_text = true
		b.tooltip_text = str(slot.label)
		choices.add_child(b)


func _scroll_bottom(scroll_reference: WeakRef) -> void:
	await get_tree().process_frame
	var scroll: ScrollContainer = scroll_reference.get_ref()
	if is_instance_valid(scroll) and scroll.is_inside_tree():
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _waiting_for_reply() -> bool:
	for messages: Array in Game.me().get("chats", {}).values():
		for message: Dictionary in messages:
			if message.get("pending", false):
				return true
	return false


func _send_text(text: String) -> void:
	var listing := _listing(selected)
	if text.strip_edges() == "" or listing.is_empty() or listing.status != "available" or Game.me().ready:
		return
	if _waiting_for_reply():
		return
	if not is_visible_in_tree():
		return
	Game.act("chat", {"listing_id": selected, "text": text})
	_drafts[selected] = ""
	if is_instance_valid(_composer):
		_composer.text = ""


func _sell() -> void:
	_body.add_child(K.lbl("YOUR SPARE PARTS", "H2"))
	_body.add_child(K.lbl("List an owned spare. Buyers will haggle in Messages. Sold parts are handed over at a scheduled meeting; no instant money. Cancel a listing to install its part.", "Muted", null, true))
	var scroll := K.scroll()
	_body.add_child(scroll)
	var box := K.vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var me: Dictionary = Game.me()
	for item: Dictionary in me.inventory:
		var active := {}
		for l in Game.state.listings:
			if int(l.get("owner", 0)) == Game.local_id() and int(l.get("item_id", -99999)) == int(item.id) and l.status == "available":
				active = l
		var card := K.panel("Card")
		var v := K.vbox(6)
		v.add_child(K.lbl(str(item.name), "Mono", null, true))
		if not active.is_empty():
			v.add_child(K.lbl("Listed $%d · %s is interested" % [int(active.price), active.seller], "Tiny", K.SKY))
			var row := K.hbox(6)
			row.add_child(K.btn("Chat with buyer", "", open_listing.bind(int(active.id))))
			row.add_child(K.btn("Cancel listing", "GhostButton", func(): Game.act("cancel_sale", {"listing_id": active.id})))
			v.add_child(row)
		else:
			var row := K.hbox(6)
			var price := SpinBox.new()
			price.min_value = 1
			price.max_value = 5000
			price.value = maxi(5, int(item.price))
			price.prefix = "$"
			row.add_child(price)
			row.add_child(K.btn("Post listing", "PrimaryButton", func(): Game.act("post_sale", {"item_id": item.id, "price": int(price.value)})))
			v.add_child(row)
		card.add_child(v)
		box.add_child(card)
	if me.inventory.is_empty():
		box.add_child(K.lbl("No spare parts. Installed components must be replaced at the workbench before selling.", "Muted", null, true))
