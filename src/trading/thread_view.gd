extends VBoxContainer
## Listing details and chat share the unfolded display; the cover shows chat alone.
signal back_pressed
signal send_text(text: String)
signal messages_settled

const Stats = preload("res://src/data/hardware_stats.gd")
const Progress = preload("res://src/trading/part_progress.gd")
const PartArt = preload("res://src/ui/part_art.gd")
const Characters = preload("res://src/data/characters.gd")
const Relationships = preload("res://src/trading/contact_relationships.gd")
const MessageRowScene = preload("res://src/trading/message_row.tscn")
const MessageRow = preload("res://src/trading/message_row.gd")

@onready var split: HBoxContainer = $Split
@onready var gone_label: Label = $Gone
@onready var gone_back: Button = $GoneBack
@onready var header: HBoxContainer = $Header
@onready var back_btn: Button = $Header/Back
@onready var contact_label: Label = $Header/Contact
@onready var role_label: Label = $Header/Role
@onready var part_art: PartArt = $Split/Right/Panes/Conversation/HistoryScroll/HistoryContent/PartIdentity/Art
@onready var part_name: Label = $Split/Right/Panes/Conversation/HistoryScroll/HistoryContent/PartIdentity/Name
@onready var subtitle_label: Label = $Subtitle
@onready var compatibility_label: RichTextLabel = $Split/Right/Panes/Specs/Details/Compatibility
@onready var panes: HBoxContainer = $Split/Right/Panes
@onready var specs: ScrollContainer = $Split/Right/Panes/Specs
@onready var tagline_label: Label = $Split/Right/Panes/Specs/Details/Tagline
@onready var spec_text: Label = $Split/Right/Panes/Specs/Details/SpecText
@onready var conversation: VBoxContainer = $Split/Right/Panes/Conversation
@onready var context_label: Label = $Split/Right/Panes/Conversation/Context
@onready var history_scroll: ScrollContainer = $Split/Right/Panes/Conversation/HistoryScroll
@onready var log: VBoxContainer = $Split/Right/Panes/Conversation/HistoryScroll/HistoryContent/Log
@onready var composer_row: HBoxContainer = $Split/Right/Panes/Conversation/ComposerRow
@onready var fault_clearance: Control = $Split/Right/Panes/Conversation/ComposerRow/FaultClearance
@onready var composer: LineEdit = $Split/Right/Panes/Conversation/ComposerRow/Composer
@onready var send_btn: Button = $Split/Right/Panes/Conversation/ComposerRow/Send
@onready var quick_row: HBoxContainer = $Split/Right/Panes/Conversation/QuickRow
@onready var quick_a: Button = $Split/Right/Panes/Conversation/QuickRow/QuickA

var _messages_ready := false
var _fault_padding_settled := false
var _locked := true
var _quick_a_text := ""


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	gone_back.pressed.connect(func() -> void: back_pressed.emit())
	composer.text_changed.connect(func(_text: String) -> void: _update_send())
	composer.text_submitted.connect(_submit)
	send_btn.pressed.connect(func() -> void: _submit(composer.text))
	quick_a.pressed.connect(func() -> void: _submit(_quick_a_text))


func _update_send() -> void:
	send_btn.disabled = _locked or composer.text.strip_edges().is_empty()


func _submit(text: String) -> void:
	if not _locked and not text.strip_edges().is_empty():
		send_text.emit(text)


func _compatibility_reference(label: String, category: String, field: String, value: String, parts: Array[Dictionary]) -> String:
	var best: Dictionary = {}
	for part: Dictionary in parts:
		var item: Dictionary = part.item
		if str(item.category) != category or (field != "" and str(item.get(field, "")) != value):
			continue
		if int(part.status) > int(best.get("status", Progress.Status.MISSING)):
			best = part
	var text := label.replace("[", "[lb]")
	if best.is_empty():
		return text
	var item: Dictionary = best.item
	text += " (" + str(item.name).replace("[", "[lb]") + ")"
	return "[color=#%s]%s[/color]" % [Progress.color(best.status).to_html(false), text]


func _compatibility_text(item: Dictionary, me: Dictionary) -> String:
	var parts := Progress.tracked_parts(me, Game.state.listings)
	match str(item.category):
		"case":
			var forms: Array[String] = ["mATX"]
			if item.form == "ATX":
				forms.push_front("ATX")
			var labels: Array[String] = []
			for form: String in forms:
				labels.append(_compatibility_reference(form, "motherboard", "form", form, parts))
			return "Motherboards: " + ", ".join(labels)
		"motherboard":
			var cases := _compatibility_reference("ATX", "case", "form", "ATX", parts)
			if item.form == "mATX":
				cases += ", " + _compatibility_reference("mATX", "case", "form", "mATX", parts)
			return "CPUs: %s\nRAM: %s\nCases: %s" % [
				_compatibility_reference(str(item.socket) + " socket", "cpu", "socket", str(item.socket), parts),
				_compatibility_reference(str(item.memory), "ram", "memory", str(item.memory), parts), cases]
		"cpu":
			return "Motherboards: " + _compatibility_reference(str(item.socket) + " socket", "motherboard", "socket", str(item.socket), parts)
		"ram":
			return "Motherboards: " + _compatibility_reference(str(item.memory) + " memory slots", "motherboard", "memory", str(item.memory), parts)
		"gpu", "storage":
			return "Motherboards: " + _compatibility_reference("any model", "motherboard", "", "", parts)
		"psu":
			return "Cases: %s, %s\nCapacity must cover total build power." % [
				_compatibility_reference("ATX", "case", "form", "ATX", parts),
				_compatibility_reference("mATX", "case", "form", "mATX", parts)]
	return ""


func _specification_text(item: Dictionary) -> String:
	var lines: Array[String] = ["Condition: %d/100" % int(item.get("condition", 100))]
	var category := str(item.category)
	if int(item.get("cores", 0)) > 0:
		lines.append("Cores: %d" % int(item.cores))
	if int(item.get("capacity_gb", 0)) > 0:
		lines.append("Capacity: %d GB" % int(item.capacity_gb))
	if int(item.get("stock_clock_mhz", 0)) > 0:
		lines.append("Stock clock: %d MHz" % int(item.stock_clock_mhz))
	if category in ["cpu", "gpu", "ram", "storage"]:
		lines.append("Stock score: %d" % roundi(Stats.stock_score(item)))
	if float(item.get("watts", 0)) > 0:
		lines.append("Power draw: %d W" % int(item.watts))
	match category:
		"case": lines.append("Airflow: %d/100" % int(item.get("support_quality", 50)))
		"psu":
			lines.append("Power capacity: %d W" % int(item.capacity))
			lines.append("Power regulation: %d/100" % int(item.get("support_quality", 50)))
		"motherboard":
			lines.append("Board size: %s" % item.form)
			lines.append("VRM quality: %d/100" % int(item.get("support_quality", 50)))
			lines.append("Video outputs: " + ("yes, requires a CPU with integrated graphics" if item.integrated else "none"))
		"cpu":
			lines.append("Integrated graphics: " + ("%d stock score, needs motherboard video outputs" % roundi(Stats.stock_score(item, "gpu")) if item.integrated else "none"))
	if category in ["cpu", "gpu", "ram"]:
		lines.append("OC headroom: +%d%%" % roundi(float(item.get("oc_potential", 0)) * 100))
		lines.append("Voltage comfort: %.2fx" % float(item.get("voltage_limit", 1.3)))
		lines.append("Heat load: %.2fx" % float(item.get("thermal_load", 1)))
	var fault := Stats.stock_failure_chance(item)
	if fault > 0:
		lines.append("Failure risk: %.1f%% per stock test / benchmark" % (fault * 100))
	var fire := Stats.stock_fire_chance(item)
	if fire > 0:
		lines.append("Connector fire risk: %.1f%% per stock test / benchmark" % (fire * 100))
	lines.append("Used-price guide: $%d" % Stats.reference_price(item))
	return "\n".join(lines)


func setup_gone() -> void:
	_locked = true
	gone_label.visible = true
	gone_back.visible = true
	split.visible = false
	header.visible = false
	subtitle_label.visible = false
	panes.visible = false


func setup(listing: Dictionary, me: Dictionary, selected: int, drafts: Dictionary, pending: bool, waiting: bool, unfolded: bool) -> void:
	gone_label.visible = false
	gone_back.visible = false
	split.visible = true
	header.visible = true
	subtitle_label.visible = true
	panes.visible = true
	# On the inner display, keep listing identity with its details so the chat
	# can start at the top of the right column. The cover keeps its stacked header.
	if unfolded:
		var details := specs.get_node("Details")
		if header.get_parent() != details:
			header.reparent(details)
			subtitle_label.reparent(details)
		details.move_child(header, 0)
		details.move_child(subtitle_label, 1)
	elif header.get_parent() != self:
		header.reparent(self)
		subtitle_label.reparent(self)
		move_child(header, split.get_index())
		move_child(subtitle_label, split.get_index())
	contact_label.text = str(listing.seller)
	contact_label.tooltip_text = str(listing.seller)
	var selling: bool = int(listing.get("owner", 0)) == Game.local_id()
	var waiting_for_buyer: bool = selling and not listing.get("buyer_contacted", true)
	var private_thread: bool = int(listing.get("owner", 0)) > 0 and not selling
	var agreed_price := int(me.offers.get(selected, 0))
	var buyer_offer := int(me.get("counters", {}).get(selected, 0)) if selling else 0
	role_label.text = "Buyer" if selling else "Seller"
	part_art.show_item(listing)
	part_name.text = (str(listing.get("manufacturer", "")) + " " + str(listing.name)).strip_edges()
	subtitle_label.text = ("Your ask: $%d" if selling else "$%d") % int(listing.price)
	tagline_label.text = Characters.for_listing(listing).tagline
	compatibility_label.text = _compatibility_text(listing, me)
	spec_text.text = _specification_text(listing)
	specs.visible = unfolded
	conversation.visible = true
	var blocked := Relationships.blocked(me, listing)
	var terminal: bool = blocked or listing.status != "available" or bool(me.ready) or private_thread
	_locked = pending or waiting or terminal or waiting_for_buyer
	var context_text := ""
	if selling and buyer_offer > 0 and agreed_price <= 0:
		context_text = "Buyer offers $%d · Accept or negotiate." % buyer_offer
	if agreed_price > 0:
		context_text = "Agreed: $%d" % agreed_price
	if pending or waiting:
		context_text = "Waiting for reply."
	if waiting_for_buyer:
		context_text = "Waiting for buyer."
	if private_thread:
		context_text = "Another player's private buyer conversation."
	if bool(me.ready):
		context_text = "You're ready. Conversation is read-only."
	if listing.status != "available":
		context_text = str(listing.status).capitalize() + " · Conversation is read-only."
	if blocked:
		context_text = "Contact blocked trading. Try another buyer." if selling else "Contact blocked trading. Try another seller."
	context_label.text = context_text
	context_label.visible = context_text != ""
	for c in log.get_children():
		log.remove_child(c)
		c.queue_free()
	var messages: Array = me.chats.get(selected, [])
	for msg: Dictionary in messages:
		var row: HBoxContainer = MessageRowScene.instantiate()
		log.add_child(row)
		row.setup(msg, str(me.name))
	composer.placeholder_text = "Read-only conversation" if terminal else ("Waiting for buyer" if waiting_for_buyer else "Message…")
	composer.text = str(drafts.get(selected, ""))
	composer.editable = not terminal and not waiting_for_buyer
	_update_send()
	_quick_a_text = ""
	quick_a.visible = not terminal and not waiting_for_buyer and agreed_price <= 0 and (not selling or buyer_offer > 0)
	if selling:
		quick_a.text = "Accept $%d" % buyer_offer
		quick_a.tooltip_text = "Accept the buyer's $%d offer" % buyer_offer
		if quick_a.visible:
			_quick_a_text = "Deal"
	else:
		quick_a.text = "Available?"
		quick_a.tooltip_text = "Is it still available?"
		if quick_a.visible:
			_quick_a_text = "Is it still available?"
	quick_a.disabled = _locked
	quick_row.visible = quick_a.visible
	conversation.move_child(composer_row if unfolded else quick_row, conversation.get_child_count() - 1)
	fault_clearance.visible = unfolded
	fault_clearance.mouse_filter = Control.MOUSE_FILTER_IGNORE


func settle_message_text(fault: Rect2) -> void:
	if not _messages_ready or _fault_padding_settled:
		return
	var lines: Array[Rect2] = []
	var max_shift := 0
	for row: MessageRow in log.get_children():
		lines.append_array(row.text_line_bounds())
		max_shift = maxi(max_shift, row.label.get_line_height() + row.label.get_theme_constant("line_spacing"))
	if lines.is_empty():
		return
	_fault_padding_settled = true
	var clip := history_scroll.get_global_rect()
	var content := history_scroll.get_node("HistoryContent") as VBoxContainer
	var slack := maxf(0, clip.size.y - content.get_combined_minimum_size().y)
	var shift_up := slack <= max_shift
	var best_shift := 0
	var best_score := INF
	for shift in range(max_shift + 1):
		var coverage := 0.0
		for line: Rect2 in lines:
			line.position.y += -shift if shift_up else shift
			var overlap := fault.intersection(line.intersection(clip))
			if overlap.has_area():
				coverage = maxf(coverage, overlap.size.y / line.size.y)
		# Prefer the smallest layout nudge; leave most of each text line intact.
		var score := maxf(0, coverage - 0.25) * 10000 + shift
		if score < best_score:
			best_score = score
			best_shift = shift
	if best_shift == 0:
		return
	var spacer: Control = content.get_node("FaultBottomSpace" if shift_up else "FaultTopSpace")
	spacer.custom_minimum_size.y = best_shift + slack if shift_up else best_shift
	# Only settle the newest message. Manual scrolling never repositions text or damage.
	scroll_bottom_deferred()


func scroll_bottom_deferred() -> void:
	var ref: WeakRef = weakref(history_scroll)
	_scroll_bottom(ref)


func _scroll_bottom(scroll_reference: WeakRef) -> void:
	await get_tree().process_frame
	var scroll: ScrollContainer = scroll_reference.get_ref()
	if is_instance_valid(scroll) and scroll.is_inside_tree():
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await get_tree().process_frame
		if is_instance_valid(scroll) and scroll.is_inside_tree():
			_messages_ready = true
			messages_settled.emit()
