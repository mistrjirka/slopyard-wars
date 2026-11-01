extends HBoxContainer
## Social classifieds: illustrated listings, seller conversations and agreed pickups.
const K = preload("res://scripts/ui_kit.gd")
const PartArt = preload("res://scripts/part_art.gd")
const Catalog = preload("res://scripts/catalog.gd")

signal went_driving
var ask: Callable = Callable()   # set by main: ask(title, text, ok_label, callable)

var sel_id: int = -1
var cat_filter: String = "all"
var fits_only: bool = false
var afford_only: bool = false
var query: String = ""
var sort_mode: int = 0

var _list_box: VBoxContainer
var _count: Label
var _search: LineEdit
var _chips: Dictionary = {}
var _fits_btn: Button
var _afford_btn: Button
var _sort: OptionButton
var _list_sig: String = ""
var _chat_sig: String = ""

var _empty: Control
var _detail: VBoxContainer
var _art: Control
var _name: Label
var _pills: HBoxContainer
var _price: Label
var _where: Label
var _seller_avatar: Label
var _seller_name: Label
var _seller_place: Label
var _specs: Label
var _desc: Label
var _fit_panel: PanelContainer
var _fit_lbl: Label
var _deal: Label
var _trip_lbl: Label
var _buy_btn: Button
var _chat_title: Label
var _chat_status: Label
var _chat_scroll: ScrollContainer
var _chat_box: VBoxContainer
var _chat_edit: LineEdit
var _send_btn: Button

func _init() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_left()
	_build_right()

# ------------------------------------------------------------------ construction

func _build_left() -> void:
	var left := K.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	left.custom_minimum_size.x = 420
	add_child(left)
	var head := K.hbox(8)
	head.add_child(K.lbl("MARKETPLACE", "H2"))
	_count = K.lbl("", "Tiny")
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_count)
	left.add_child(head)
	_search = LineEdit.new()
	_search.placeholder_text = "Search parts, sellers, places..."
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(t: String): query = t.strip_edges().to_lower(); _list_sig = ""; refresh())
	left.add_child(_search)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	var grp := ButtonGroup.new()
	var all := K.btn("ALL", "ChipButton")
	all.button_group = grp
	all.button_pressed = true
	all.pressed.connect(_set_cat.bind("all"))
	flow.add_child(all)
	_chips["all"] = all
	for c in K.CATS:
		var b := K.btn(K.CAT_LABEL[c] if c != "motherboard" else "BOARD", "ChipButton")
		b.button_group = grp
		b.pressed.connect(_set_cat.bind(c))
		flow.add_child(b)
		_chips[c] = b
	left.add_child(flow)
	var row := K.hbox(6)
	_fits_btn = K.btn("FITS MY RIG", "ChipButton")
	_fits_btn.tooltip_text = "Only parts compatible with what is already installed"
	_fits_btn.toggled.connect(func(on: bool): fits_only = on; _list_sig = ""; refresh())
	row.add_child(_fits_btn)
	_afford_btn = K.btn("AFFORDABLE", "ChipButton")
	_afford_btn.tooltip_text = "Only parts you can pay for"
	_afford_btn.toggled.connect(func(on: bool): afford_only = on; _list_sig = ""; refresh())
	row.add_child(_afford_btn)
	row.add_child(K.spacer())
	_sort = OptionButton.new()
	for s in ["Price: low to high", "Price: high to low", "Closest first"]:
		_sort.add_item(s)
	_sort.item_selected.connect(func(i: int): sort_mode = i; _list_sig = ""; refresh())
	row.add_child(_sort)
	left.add_child(row)
	var sc := K.scroll()
	left.add_child(sc)
	_list_box = K.vbox(8)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list_box)

func _build_right() -> void:
	var host := K.panel("Card")
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_stretch_ratio = 1.25
	host.custom_minimum_size.x = 470
	add_child(host)
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.add_child(holder)
	var empty := VBoxContainer.new()
	empty.set_anchors_preset(Control.PRESET_FULL_RECT)
	empty.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := K.lbl("PICK A LISTING", "H2")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s := K.lbl("Select a card to read the ad, chat with the seller, haggle and plan the pickup drive.", "Muted", null, true)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.add_child(t)
	empty.add_child(s)
	holder.add_child(empty)
	_empty = empty
	var sc := K.scroll()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(sc)
	_detail = K.vbox(10)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_detail)
	sc.visible = true
	_detail.set_meta("scroll", sc)
	# header
	var top := K.hbox(14)
	_art = PartArt.new()
	_art.custom_minimum_size = Vector2(150, 105)
	top.add_child(_art)
	var info := K.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name = K.lbl("", "H2", null, true)
	info.add_child(_name)
	_pills = K.hbox(6)
	info.add_child(_pills)
	_price = K.lbl("", "Display")
	_price.add_theme_font_size_override("font_size", 34)
	_price.add_theme_color_override("font_color", K.SKY)
	info.add_child(_price)
	_where = K.lbl("", "Muted", null, true)
	info.add_child(_where)
	top.add_child(info)
	_detail.add_child(top)
	var profile := K.hbox(10)
	var avatar := K.panel("CardTight")
	avatar.add_theme_stylebox_override("panel", K.box(Color("245aa0"), K.SKY, 24, 1, 10, 6))
	_seller_avatar = K.lbl("", "Big", Color.WHITE)
	_seller_avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar.add_child(_seller_avatar)
	profile.add_child(avatar)
	var profile_text := K.vbox(1)
	_seller_name = K.lbl("", "Mono", K.CREAM)
	_seller_place = K.lbl("", "Tiny", K.MUTED)
	profile_text.add_child(_seller_name)
	profile_text.add_child(_seller_place)
	profile.add_child(profile_text)
	_detail.add_child(profile)
	_specs = K.lbl("", "Mono", K.SKY, true)
	_detail.add_child(_specs)
	_desc = K.lbl("", "Muted", null, true)
	_detail.add_child(_desc)
	_fit_panel = K.panel("CardTight")
	_fit_lbl = K.lbl("", "", K.CREAM, true)
	_fit_panel.add_child(_fit_lbl)
	_detail.add_child(_fit_panel)
	_detail.add_child(K.hrule())
	_deal = K.lbl("", "Mono", K.SKY, true)
	_detail.add_child(_deal)
	_trip_lbl = K.lbl("", "Muted", null, true)
	_detail.add_child(_trip_lbl)
	_buy_btn = K.btn("PICK UP", "PrimaryButton", _buy)
	_detail.add_child(_buy_btn)
	_detail.add_child(K.hrule())
	# chat
	var ch := K.hbox(8)
	_chat_title = K.lbl("CHAT", "Eyebrow")
	ch.add_child(_chat_title)
	_chat_status = K.lbl("", "Tiny")
	_chat_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ch.add_child(_chat_status)
	_detail.add_child(ch)
	var cp := K.panel("Inset")
	cp.add_theme_stylebox_override("panel", K.box(Color("0d1b34"), Color("2b568c"), 10, 1, 10, 8))
	cp.custom_minimum_size.y = 170
	_chat_scroll = K.scroll()
	_chat_scroll.custom_minimum_size.y = 150
	_chat_box = K.vbox(6)
	_chat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_scroll.add_child(_chat_box)
	cp.add_child(_chat_scroll)
	_detail.add_child(cp)
	var qs := HFlowContainer.new()
	for q in ["Is it still available?", "Does it work? Any issues?", "What is the lowest you would take?"]:
		var b := K.btn(q, "GhostButton", _send_chat.bind(q))
		qs.add_child(b)
	_detail.add_child(qs)
	var crow := K.hbox(6)
	_chat_edit = LineEdit.new()
	_chat_edit.placeholder_text = "Write a message..."
	_chat_edit.max_length = 240
	_chat_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_edit.text_submitted.connect(func(t: String): _send_chat(t))
	crow.add_child(_chat_edit)
	_send_btn = K.btn("SEND", "", func(): _send_chat(_chat_edit.text))
	_send_btn.add_theme_stylebox_override("normal", K.box(Color("2166bd"), Color("3889ee"), 12, 1, 16, 8))
	_send_btn.add_theme_stylebox_override("hover", K.box(Color("3182df"), K.SKY, 12, 1, 16, 8))
	crow.add_child(_send_btn)
	_detail.add_child(crow)

# ------------------------------------------------------------------ helpers

func _me() -> Dictionary:
	return Game.me()

func _sel() -> Dictionary:
	for l in Game.state.listings:
		if int(l.id) == sel_id:
			return l
	return {}

func _fit(l: Dictionary) -> Array:
	var why: String = Game.compatibility(l, _me())
	if why == "":
		return ["ok", "Fits your rig"]
	if why.begins_with("Install a"):
		return ["wait", "Needs: " + why.replace("Install a ", "").replace(" first", "") + " installed first"]
	return ["bad", "WON'T FIT: " + why]

func _fit_color(kind: String) -> Color:
	return {"ok": K.LIME, "wait": K.SKY, "bad": K.DANGER}.get(kind, K.MUTED)

func _dist(l: Dictionary) -> float:
	var p: Vector2 = _me().get("pos", Catalog.HOME)
	return p.distance_to(l.pos)

func _price_for(l: Dictionary) -> int:
	var offers: Dictionary = _me().get("offers", {})
	var o = K.geti(offers, int(l.id))
	return mini(int(o), int(l.price)) if o != null else int(l.price)

func _set_cat(c: String) -> void:
	cat_filter = c
	_list_sig = ""
	refresh()

func select(id: int) -> void:
	sel_id = id
	_list_sig = ""
	_chat_sig = ""
	refresh()

# ------------------------------------------------------------------ refresh

func refresh() -> void:
	if not is_visible_in_tree():
		return
	var me := _me()
	var pending_sig := PackedStringArray()
	for l in Game.state.listings:
		pending_sig.append("%d%s%d" % [l.id, str(l.status).left(1), l.price])
	var owned := PackedStringArray()
	for k in me.get("installed", {}):
		owned.append("%s%d" % [k, int(me.installed[k].id)])
	for it in me.get("inventory", []):
		owned.append(str(int(it.id)))
	var sig := "%s|%s|%s|%d|%s|%d|%d|%s|%d" % [",".join(pending_sig), cat_filter, query, sel_id, ",".join(owned), int(me.get("cash", 0)), sort_mode, str(fits_only) + str(afford_only), 1 if me.get("trip", {}).is_empty() else 0]
	if sig != _list_sig:
		_list_sig = sig
		_rebuild_list()
	_update_detail()

func _rebuild_list() -> void:
	K.clear(_list_box)
	var me := _me()
	var cash: int = int(me.get("cash", 0))
	var rows: Array = []
	var gone: Array = []
	for l in Game.state.listings:
		if cat_filter != "all" and l.category != cat_filter:
			continue
		if query != "" and not (String(l.name).to_lower().contains(query) or String(l.seller).to_lower().contains(query) or String(l.location).to_lower().contains(query) or String(l.category).contains(query)):
			continue
		if l.status != "available":
			gone.append(l)
			continue
		var f := _fit(l)
		if fits_only and f[0] != "ok":
			continue
		if afford_only and int(l.price) > cash:
			continue
		rows.append(l)
	match sort_mode:
		0: rows.sort_custom(func(a, b): return a.price < b.price)
		1: rows.sort_custom(func(a, b): return a.price > b.price)
		2: rows.sort_custom(func(a, b): return _dist(a) < _dist(b))
	_count.text = "%d for sale" % rows.size()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_child(grid)
	for l in rows:
		grid.add_child(_card(l))
	if rows.is_empty():
		var e := K.panel("Inset")
		e.add_child(K.lbl("Nothing matches. Clear a filter, or wait: the market restocks every ~15 seconds.", "Muted", null, true))
		_list_box.add_child(e)
	if not gone.is_empty():
		_list_box.add_child(K.lbl("SOLD / GONE", "Eyebrow", K.FAINT))
		var gone_grid := GridContainer.new()
		gone_grid.columns = 2
		gone_grid.add_theme_constant_override("h_separation", 8)
		gone_grid.add_theme_constant_override("v_separation", 8)
		_list_box.add_child(gone_grid)
		for l in gone:
			gone_grid.add_child(_card(l))

func _card(l: Dictionary) -> Control:
	var live: bool = l.status == "available"
	var selected: bool = int(l.id) == sel_id
	var p := K.panel("CardTight")
	if selected: p.add_theme_stylebox_override("panel", K.box(Color("1a315b"), K.SKY, 8, 2, 14, 12))
	p.focus_mode = Control.FOCUS_ALL
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var lid: int = int(l.id)
	p.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			select(lid)
		elif e is InputEventKey and e.pressed and (e.keycode == KEY_ENTER or e.keycode == KEY_SPACE):
			select(lid))
	var content := K.vbox(4)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var art: Control = PartArt.new()
	art.custom_minimum_size = Vector2(120, 105)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.show_item(l, not live)
	content.add_child(art)
	var pl := K.lbl(K.money(l.price), "Big", K.SKY if live else K.FAINT)
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(pl)
	var n := K.lbl(String(l.name), "", K.CREAM if live else K.FAINT)
	n.clip_text = true
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(n)
	var sub := K.lbl("%s · %s" % [l.seller, l.location], "Tiny")
	sub.clip_text = true
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(sub)
	if not live:
		var status := K.lbl(String(l.status).to_upper(), "Tiny", K.DANGER)
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(status)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(content)
	return p

func _update_detail() -> void:
	var l := _sel()
	var sc: Control = _detail.get_meta("scroll")
	sc.visible = not l.is_empty()
	_empty.visible = l.is_empty()
	if l.is_empty():
		return
	var me := _me()
	var live: bool = l.status == "available"
	_art.show_item(l, not live)
	_name.text = String(l.name)
	K.clear(_pills)
	_pills.add_child(K.pill(String(K.CAT_LABEL.get(l.category, "")), K.cat_color(l.category)))
	_pills.add_child(K.pill("PRIVATE SELLER", K.SKY))
	if not live:
		_pills.add_child(K.pill(String(l.status).to_upper(), K.DANGER))
	_price.text = K.money(l.price)
	_where.text = "%d units away" % int(_dist(l))
	_seller_avatar.text = String(l.seller).left(1).to_upper()
	_seller_name.text = String(l.seller)
	_seller_place.text = "%s · private seller" % l.location
	_specs.text = "Hardware notes: " + Catalog.spec_text(l)
	_desc.text = "\"%s\"" % l.description
	var f := _fit(l)
	_fit_lbl.text = String(f[1]) + ("" if f[0] != "bad" else "\nRecovery: buy a part that matches your board/case instead, or replace the other part. Use the FITS MY RIG filter.")
	var fc := _fit_color(f[0])
	_fit_panel.add_theme_stylebox_override("panel", K.box(Color(fc, 0.1), Color(fc, 0.8), 6, 1, 10, 8))
	_fit_lbl.add_theme_color_override("font_color", fc)
	var lid: int = int(l.id)
	var offer = K.geti(me.get("offers", {}), lid)
	var ready: bool = bool(me.get("ready", false))
	var driving: bool = not me.get("trip", {}).is_empty()
	var price: int = _price_for(l)
	var fuel: int = int(5 + _dist(l) * 0.02)
	var mins: int = int(15 + _dist(l) * 0.25)
	_deal.text = ("Deal agreed: %s (not reserved - another buyer can still take it first!)" % K.money(offer)) if offer != null else "No agreement yet. Message the seller to agree a price."
	_deal.add_theme_color_override("font_color", K.LIME if offer != null else K.MUTED)
	_trip_lbl.text = "Pickup trip: ~%d game min, fuel %s. %s" % [mins, K.money(fuel), ("Pay %s on arrival if still available." % K.money(price)) if offer != null else "Agree a price in chat before travelling."]
	_buy_btn.text = "DRIVE TO PICK UP for %s" % K.money(price)
	var why := ""
	if not live: why = "Listing is %s" % l.status
	elif offer == null: why = "Agree in chat first"
	elif ready: why = "Rig locked"
	elif driving: why = "You are already driving"
	elif int(me.get("cash", 0)) < price + fuel: why = "Need %s incl. fuel" % K.money(price + fuel)
	_buy_btn.disabled = why != ""
	if why != "":
		_buy_btn.text = why.to_upper()
	_chat_title.text = "CHAT WITH %s" % String(l.seller).to_upper()
	_chat_status.text = Game.seller_status()
	# chat log
	var chats: Dictionary = me.get("chats", {})
	var msgs: Array = K.geti(chats, lid, [])
	var sig := "%d|%s" % [lid, str(msgs).hash()]
	var pending: bool = false
	for m in msgs:
		if m.get("pending", false):
			pending = true
	_send_btn.disabled = pending or not live
	if sig != _chat_sig:
		_chat_sig = sig
		K.clear(_chat_box)
		if msgs.is_empty():
			_chat_box.add_child(K.lbl("No messages yet. Ask about condition, history or price. The seller replies in character.", "Muted", null, true))
		for m in msgs:
			_chat_box.add_child(_bubble(m, String(me.get("name", ""))))
		_scroll_chat.call_deferred()

func _scroll_chat() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	var bar := _chat_scroll.get_v_scroll_bar()
	_chat_scroll.scroll_vertical = int(bar.max_value)

func _bubble(m: Dictionary, my_name: String) -> Control:
	var sp: String = String(m.speaker)
	var row := HBoxContainer.new()
	if sp == "system":
		var t := K.lbl(String(m.text), "Tiny", K.ORANGE if not m.get("pending", false) else K.SKY, true)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(t)
		return row
	var mine: bool = sp == my_name
	var b := K.panel("BubbleMe" if mine else "BubbleThem")
	if mine: b.add_theme_stylebox_override("panel", K.box(Color("174a8b"), K.SKY, 10, 1, 12, 8))
	var v := K.vbox(2)
	v.add_child(K.lbl(sp, "Tiny", K.SKY if mine else K.CREAM))
	var txt := String(m.text)
	var offline := txt.begins_with("[offline]")
	if offline:
		txt = txt.trim_prefix("[offline]").strip_edges()
		v.add_child(K.pill("OFFLINE SCRIPTED REPLY", K.FAINT))
	var tl := K.lbl(txt, "", K.CREAM, true)
	tl.custom_minimum_size.x = 180
	v.add_child(tl)
	b.add_child(v)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END if mine else Control.SIZE_SHRINK_BEGIN
	b.custom_minimum_size.x = 120
	var spacer := K.spacer(true)
	spacer.size_flags_stretch_ratio = 0.3
	if mine:
		row.add_child(spacer)
		row.add_child(b)
	else:
		row.add_child(b)
		row.add_child(spacer)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = 2.0
	return row

# ------------------------------------------------------------------ actions

func _send_chat(text: String) -> void:
	var t := text.strip_edges()
	if t == "" or sel_id < 0:
		return
	var msgs: Array = K.geti(_me().get("chats", {}), sel_id, [])
	for m in msgs:
		if m.get("pending", false):
			return
	Game.act("chat", {"listing_id": sel_id, "text": t})
	_chat_edit.text = ""
	_chat_edit.grab_focus()

func _buy() -> void:
	var l := _sel()
	if l.is_empty():
		return
	var f := _fit(l)
	var lid: int = int(l.id)
	var go := func():
		Game.act("travel", {"listing_id": lid})
		went_driving.emit()
	if f[0] == "bad" and ask.is_valid():
		ask.call("Buy a part that does not fit?", "%s\n\nIt will not install with your current rig. You could still use it if you swap another part. Drive there anyway?" % f[1], "Drive anyway", go)
	else:
		go.call()
