extends PanelContainer
## In-world phone. Browse, Messages and Sell share the host's listing/chat identities.
const K = preload("res://scripts/ui_kit.gd")
const Art = preload("res://scripts/part_art.gd")
const Trade = preload("res://scripts/trade_rules.gd")
const Catalog = preload("res://scripts/catalog.gd")
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

func _init() -> void:
	custom_minimum_size = Vector2(584, 740)
	add_theme_stylebox_override("panel", K.box(Color("111b2c"), Color("51647c"), 28, 5, 18, 12))
	var shell := K.vbox(8)
	add_child(shell)
	var status := K.hbox(8)
	_clock = K.lbl("", "Tiny", K.SKY)
	status.add_child(_clock)
	status.add_child(K.spacer())
	status.add_child(K.lbl("SLOPHONE  ·  LTE  ▰", "Tiny"))
	status.add_child(K.btn("×", "GhostButton", func(): close_requested.emit()))
	shell.add_child(status)
	var brand := K.hbox(8)
	brand.add_child(K.lbl("marketplace", "Title", K.SKY))
	brand.add_child(K.spacer())
	brand.add_child(K.lbl("local people · real deals", "Tiny"))
	shell.add_child(brand)
	var nav := K.hbox(6)
	for tab in [["browse", "Browse"], ["messages", "Messages"], ["sell", "Sell"]]:
		var b := K.btn(tab[1], "TabButton", _show.bind(tab[0]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_child(b)
		_tabs[tab[0]] = b
	shell.add_child(nav)
	_body = K.vbox(8)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(_body)
	shell.add_child(K.lbl("P / Esc to pocket phone   ·   world clock keeps running", "Tiny", K.MUTED))

func open_listing(id: int) -> void:
	_save_draft()
	_composer = null
	selected = id
	_slots = false
	_show("messages")

func _show(which: String) -> void:
	_save_draft()
	page = which
	_sig = ""
	refresh()

func _save_draft() -> void:
	if is_instance_valid(_composer): _drafts[selected] = _composer.text

func _listing(id: int) -> Dictionary:
	for l in Game.state.listings:
		if int(l.id) == id: return l
	return {}

func refresh() -> void:
	if not is_visible_in_tree() or Game.me().is_empty(): return
	_clock.text = Trade.stamp(Game.clock()) + "   ·   $%d" % int(Game.me().cash)
	var me: Dictionary = Game.me()
	var sig := page + str(selected)
	if page == "messages" and selected >= 0:
		var l := _listing(selected)
		sig += str(me.chats.get(selected, [])).sha256_text() + str(me.offers.get(selected, 0)) + str(me.meetings.get(selected, {})) + str(l.get("status", "gone")) + str(_slots)
	elif page == "sell":
		sig += str(me.inventory) + str(Game.state.listings.filter(func(l): return int(l.get("owner", 0)) == Game.local_id()))
	else:
		for l in Game.state.listings:
			sig += "%d%s%d" % [l.id, l.status, l.price]
		if page == "messages": sig += str(me.chats.keys())
	if sig == _sig: return
	var refocus := is_instance_valid(_composer) and _composer.has_focus()
	var caret := _composer.caret_column if refocus else 0
	_save_draft()
	_sig = sig
	K.clear(_body)
	_composer = null
	for key in _tabs: _tabs[key].button_pressed = key == page
	if page == "browse": _browse()
	elif page == "sell": _sell()
	elif selected < 0: _threads()
	else: _thread()
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
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var cards: Array = []
	for l in Game.state.listings:
		if int(l.get("owner", 0)) != 0 or l.status != "available": continue
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
		var name_label := K.lbl(str(l.name), "", K.CREAM, true)
		name_label.custom_minimum_size.x = 180
		box.add_child(name_label)
		box.add_child(K.lbl(str(l.seller) + " · " + str(l.location), "Tiny", null, true))
		card.add_child(box)
		card.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: open_listing(int(l.id)))
		grid.add_child(card)
		cards.append([card, (str(l.name) + str(l.seller) + str(l.category)).to_lower()])
	search.text_changed.connect(func(t: String):
		_search = t
		for pair in cards: pair[0].visible = t == "" or t.to_lower() in pair[1])
	for pair in cards: pair[0].visible = _search == "" or _search.to_lower() in pair[1]

func _threads() -> void:
	_body.add_child(K.lbl("MESSAGES", "H2"))
	var scroll := K.scroll()
	_body.add_child(scroll)
	var box := K.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var me: Dictionary = Game.me()
	if me.chats.is_empty(): box.add_child(K.lbl("No conversations. Browse an item, or list a spare part to hear from a buyer.", "Muted", null, true))
	for id in me.chats:
		var l := _listing(int(id))
		if l.is_empty(): continue
		var msgs: Array = me.chats[id]
		var last: String = str(msgs[-1].text) if not msgs.is_empty() else "Start a conversation"
		var b := K.btn(str(l.seller) + (" · BUYER" if int(l.get("owner", 0)) > 0 else "") + "\n" + str(l.name) + "\n" + last.left(70), "", open_listing.bind(int(id)))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 86
		box.add_child(b)

func _thread() -> void:
	var l := _listing(selected)
	if l.is_empty():
		_body.add_child(K.lbl("This old listing is gone.", "Muted"))
		_body.add_child(K.btn("All messages", "", func(): selected = -1; _show("messages")))
		return
	var me: Dictionary = Game.me()
	var head := K.hbox(8)
	head.add_child(K.btn("‹", "GhostButton", func(): selected = -1; _show("messages")))
	head.add_child(K.lbl(str(l.seller), "H2", K.SKY))
	head.add_child(K.lbl("BUYER" if int(l.get("owner", 0)) > 0 else "SELLER", "Tiny"))
	_body.add_child(head)
	_body.add_child(K.lbl(str(l.name) + " · Asking $%d" % int(l.price), "Mono", null, true))
	_body.add_child(K.lbl("Your hardware notes: " + Catalog.spec_text(l), "Tiny", K.MUTED, true))
	var schedule := Trade.profile(l.seller, l.location)
	_body.add_child(K.lbl(str(schedule.note) + " Meets: " + ", ".join(schedule.places), "Tiny", K.SKY, true))
	_context = K.lbl("", "Tiny", K.CREAM, true)
	if me.meetings.has(selected):
		var m: Dictionary = me.meetings[selected]
		_context.text = ("MISSED — arrange another time: " if Game.clock() > float(m.end) else "MEETING: ") + str(m.label)
	elif me.offers.has(selected): _context.text = "Price agreed: $%d. Still arrange place and time." % int(me.offers[selected])
	else: _context.text = "No price agreement yet. Ask, negotiate, or make an offer in your own words."
	if l.status != "available": _context.text = str(l.status).to_upper() + " · this listing is no longer available."
	_body.add_child(_context)
	var actions := K.hbox(6)
	actions.add_child(K.btn("Meeting suggestions", "GhostButton", func(): _slots = not _slots; _sig = ""; refresh()))
	if me.meetings.has(selected): actions.add_child(K.btn("Track on map", "PrimaryButton", func(): track_requested.emit(selected)))
	_body.add_child(actions)
	if _slots:
		var ss := K.scroll()
		ss.custom_minimum_size.y = 112
		ss.size_flags_vertical = Control.SIZE_FILL
		var choices := K.vbox(4)
		choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ss.add_child(choices)
		for slot: Dictionary in Game.contact_options(l):
			var b := K.btn(str(slot.label), "GhostButton", func(): _send_text("Can we meet " + str(slot.label) + "?"))
			b.add_theme_font_size_override("font_size", 11)
			choices.add_child(b)
		_body.add_child(ss)
	_scroll = K.scroll()
	_scroll.custom_minimum_size.y = 160
	_body.add_child(_scroll)
	_log = K.vbox(6)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_log)
	var pending := false
	for msg: Dictionary in me.chats.get(selected, []):
		pending = pending or bool(msg.get("pending", false))
		var bubble := K.panel("BubbleMe" if str(msg.speaker) == str(me.name) else "BubbleThem")
		var col := K.SKY if str(msg.speaker) == str(me.name) else K.CREAM
		if msg.speaker == "system": col = K.ORANGE
		var label := K.lbl(str(msg.speaker) + "\n" + str(msg.text), "", col, true)
		label.custom_minimum_size.x = 410
		bubble.add_child(label)
		_log.add_child(bubble)
	if me.chats.get(selected, []).is_empty(): _log.add_child(K.lbl("Say hello. People won't always know the specs, and they have lives outside the marketplace.", "Muted", null, true))
	var row := K.hbox(6)
	_composer = LineEdit.new()
	_composer.placeholder_text = "Message..."
	_composer.max_length = 240
	_composer.text = str(_drafts.get(selected, ""))
	_composer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_composer.text_submitted.connect(_send_text)
	row.add_child(_composer)
	_send = K.btn("Send", "PrimaryButton", func(): _send_text(_composer.text))
	_send.disabled = pending or l.status != "available"
	row.add_child(_send)
	_body.add_child(row)
	var quick := K.hbox(4)
	for text in ["Is it still available?", "Yes, that price, time and place works."]:
		var b := K.btn(text, "GhostButton", _send_text.bind(text))
		b.add_theme_font_size_override("font_size", 11)
		b.disabled = pending or l.status != "available"
		quick.add_child(b)
	_body.add_child(quick)
	_scroll_bottom.call_deferred()

func _scroll_bottom() -> void:
	await get_tree().process_frame
	if is_instance_valid(_scroll): _scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _send_text(text: String) -> void:
	if text.strip_edges() == "": return
	Game.act("chat", {"listing_id": selected, "text": text})
	_drafts[selected] = ""
	if is_instance_valid(_composer): _composer.text = ""

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
			if int(l.get("owner", 0)) == Game.local_id() and int(l.get("item_id", -99999)) == int(item.id) and l.status == "available": active = l
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
	if me.inventory.is_empty(): box.add_child(K.lbl("No spare parts. Installed components must be replaced at the workbench before selling.", "Muted", null, true))
