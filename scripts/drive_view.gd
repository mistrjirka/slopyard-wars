extends HBoxContainer
## City map + pickup trip tracking. Driving is a deliberate destination choice; the car animates along the route.
const K = preload("res://scripts/ui_kit.gd")
const CityMap = preload("res://scripts/city_map.gd")
const PartArt = preload("res://scripts/part_art.gd")
const Catalog = preload("res://scripts/catalog.gd")

signal open_listing(id: int)
signal went_driving

var sel_id: int = -1
var _map: Control
var _trip_title: Label
var _trip_sub: Label
var _trip_bar: ProgressBar
var _trip_box: PanelContainer
var _sel_box: VBoxContainer
var _deals_box: VBoxContainer
var _feed_box: VBoxContainer
var _deal_sig: String = ""
var _feed_sig: String = ""
var _sel_sig: String = ""
var _map_sig: String = ""

func _init() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := K.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.0
	add_child(left)
	var head := K.hbox(8)
	head.add_child(K.lbl("PICKUP MAP", "H2"))
	head.add_child(K.lbl("Click a pin to inspect it, then drive there. Your car is the lime truck.", "Muted"))
	left.add_child(head)
	_map = CityMap.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.custom_minimum_size = Vector2(480, 320)
	_map.pin_clicked.connect(func(id: int): sel_id = id; _sel_sig = ""; _map_sig = ""; refresh())
	var frame := K.panel("Inset")
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(_map)
	left.add_child(frame)
	var right_sc := K.scroll()
	right_sc.custom_minimum_size.x = 360
	right_sc.size_flags_horizontal = Control.SIZE_FILL
	add_child(right_sc)
	var right := K.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_sc.add_child(right)
	_trip_box = K.panel("Card")
	var tv := K.vbox(6)
	tv.add_child(K.lbl("CAR STATUS", "Eyebrow"))
	_trip_title = K.lbl("", "H2", null, true)
	tv.add_child(_trip_title)
	_trip_bar = ProgressBar.new()
	_trip_bar.custom_minimum_size.y = 14
	_trip_bar.show_percentage = false
	_trip_bar.max_value = 1.0
	_trip_bar.step = 0.001
	tv.add_child(_trip_bar)
	_trip_sub = K.lbl("", "Muted", null, true)
	tv.add_child(_trip_sub)
	_trip_box.add_child(tv)
	right.add_child(_trip_box)
	var sp := K.panel("Card")
	_sel_box = K.vbox(6)
	sp.add_child(_sel_box)
	right.add_child(sp)
	var dp := K.panel("Card")
	var dv := K.vbox(6)
	dv.add_child(K.lbl("YOUR AGREED DEALS", "Eyebrow"))
	_deals_box = K.vbox(6)
	dv.add_child(_deals_box)
	dp.add_child(dv)
	right.add_child(dp)
	var fp := K.panel("Card")
	var fv := K.vbox(4)
	fv.add_child(K.lbl("MARKET FEED", "Eyebrow"))
	_feed_box = K.vbox(3)
	fv.add_child(_feed_box)
	fp.add_child(fv)
	right.add_child(fp)

func _me() -> Dictionary:
	return Game.me()

func _listing(id: int) -> Dictionary:
	for l in Game.state.listings:
		if int(l.id) == id:
			return l
	return {}

## cheap per-frame tick: car progress and ETA only
func tick() -> void:
	if not is_visible_in_tree():
		return
	var me := _me()
	var trip: Dictionary = me.get("trip", {})
	if trip.is_empty():
		_map.progress = 0.0
		return
	var total: float = maxf(1.0, float(trip.total))
	var prog: float = clampf(1.0 - float(trip.remaining) / total, 0.0, 1.0)
	_map.progress = prog
	_trip_bar.value = prog
	var left: float = maxf(0.0, float(trip.remaining))
	_trip_sub.text = "ETA %d game min (%d s real). Fuel paid: %s. You pay %s on arrival if the part is still there." % [ceili(left), ceili(left / 6.0), K.money(trip.get("fuel", 0)), K.money(trip.get("price", 0))]

func refresh() -> void:
	if not is_visible_in_tree():
		return
	var me := _me()
	var trip: Dictionary = me.get("trip", {})
	var lst: Array = Game.state.listings
	var msig := "%d|%s|%s" % [sel_id, str(trip.get("listing_id", -1)), str(lst.size())]
	for l in lst:
		msig += str(l.id) + str(l.status).left(1)
	if msig != _map_sig:
		_map_sig = msig
		_map.set_data(lst, trip, sel_id)
		if trip.is_empty():
			_map.home_pos = me.get("pos", Catalog.HOME)
			_map.queue_redraw()
	# car status
	if trip.is_empty():
		_trip_title.text = "Parked at the garage" if me.get("pos", Catalog.HOME) == Catalog.HOME else "Parked after last pickup"
		_trip_bar.value = 0.0
		_trip_sub.text = "Choose a listing below. Parts only count once picked up: you drive there, pay on arrival, and the part lands in your inventory."
	else:
		var dest := _listing(int(trip.listing_id))
		_trip_title.text = "Driving to %s" % String(dest.get("location", "pickup")) + " for " + String(dest.get("name", "a part"))
		tick()
	# selected
	var l := _listing(sel_id)
	var ssig := "%d|%s|%s|%d|%s" % [sel_id, str(l.get("status", "")), str(l.get("price", 0)), int(me.get("cash", 0)), str(trip.is_empty())]
	var offers: Dictionary = me.get("offers", {})
	ssig += str(K.geti(offers, sel_id, 0))
	if ssig != _sel_sig:
		_sel_sig = ssig
		_rebuild_selected(l, me, trip)
	# deals
	var dsig := str(offers.keys()) + str(offers.values()) + str(trip.is_empty()) + str(int(me.get("cash", 0)))
	for x in lst:
		dsig += str(x.id) + str(x.status).left(1)
	if dsig != _deal_sig:
		_deal_sig = dsig
		_rebuild_deals(me, trip)
	var fsig := str(Game.state.events.hash())
	if fsig != _feed_sig:
		_feed_sig = fsig
		K.clear(_feed_box)
		var ev: Array = Game.state.events
		for i in range(ev.size() - 1, maxi(-1, ev.size() - 9), -1):
			_feed_box.add_child(K.lbl(String(ev[i]), "Tiny", K.CREAM if i == ev.size() - 1 else K.MUTED, true))

func _rebuild_selected(l: Dictionary, me: Dictionary, trip: Dictionary) -> void:
	K.clear(_sel_box)
	_sel_box.add_child(K.lbl("SELECTED STOP", "Eyebrow"))
	if l.is_empty():
		_sel_box.add_child(K.lbl("No pin selected.", "Muted"))
		return
	var h := K.hbox(10)
	var art: Control = PartArt.new()
	art.custom_minimum_size = Vector2(90, 63)
	art.show_item(l, l.status != "available")
	h.add_child(art)
	var v := K.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(K.lbl(String(l.name), "Mono", null, true))
	v.add_child(K.lbl("%s - %s" % [l.location, l.seller], "Tiny"))
	v.add_child(K.lbl(K.money(l.price), "Big", K.LIME))
	h.add_child(v)
	_sel_box.add_child(h)
	var p: Vector2 = me.get("pos", Catalog.HOME)
	var dist: float = p.distance_to(l.pos)
	var mins := int(15 + dist * 0.25)
	var fuel := int(5 + dist * 0.02)
	var offer = K.geti(me.get("offers", {}), int(l.id))
	var price: int = mini(int(offer), int(l.price)) if offer != null else int(l.price)
	_sel_box.add_child(K.lbl("Trip: ~%d game min, fuel %s. Pay %s at pickup%s." % [mins, K.money(fuel), K.money(price), " (your agreed deal)" if offer != null else " (agree in chat first)"], "Muted", null, true))
	var row := K.hbox(6)
	var go := K.btn("DRIVE HERE", "PrimaryButton", func():
		Game.act("travel", {"listing_id": int(l.id)})
		went_driving.emit())
	var why := ""
	if l.status != "available": why = "UNAVAILABLE"
	elif offer == null: why = "AGREE IN CHAT FIRST"
	elif not trip.is_empty(): why = "ALREADY DRIVING"
	elif int(me.get("cash", 0)) < price + fuel: why = "NEED " + K.money(price + fuel)
	go.disabled = why != ""
	if why != "": go.text = why
	row.add_child(go)
	row.add_child(K.btn("AD & CHAT", "GhostButton", func(): open_listing.emit(int(l.id))))
	_sel_box.add_child(row)
	var f: String = Game.compatibility(l, me)
	if f != "" and not f.begins_with("Install a"):
		_sel_box.add_child(K.lbl("Warning: " + f, "Tiny", K.DANGER, true))

func _rebuild_deals(me: Dictionary, trip: Dictionary) -> void:
	K.clear(_deals_box)
	var n := 0
	var offers: Dictionary = me.get("offers", {})
	for k in offers:
		var l := _listing(int(k))
		if l.is_empty() or l.status != "available":
			continue
		n += 1
		var r := K.hbox(6)
		var t := K.lbl("%s  %s" % [K.money(offers[k]), l.name], "Tiny", K.CREAM, false)
		t.clip_text = true
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(t)
		r.add_child(K.btn("SHOW", "GhostButton", func(): sel_id = int(l.id); _sel_sig = ""; _map_sig = ""; refresh()))
		_deals_box.add_child(r)
	if n == 0:
		_deals_box.add_child(K.lbl("None yet. Chat agreements appear here (they do NOT reserve the part).", "Muted", null, true))
