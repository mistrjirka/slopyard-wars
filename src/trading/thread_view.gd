extends VBoxContainer
## Listing details and chat share the unfolded display; the cover shows chat alone.
signal back_pressed
signal send_text(text: String)
signal toggle_slots
signal track_requested
signal slot_chosen(label: String)

const Catalog = preload("res://src/data/catalog.gd")
const Characters = preload("res://src/data/characters.gd")
const Relationships = preload("res://src/trading/contact_relationships.gd")
const Trade = preload("res://src/trading/trade_rules.gd")
const MessageRowScene = preload("res://src/trading/message_row.tscn")
const MeetingPanelScene = preload("res://src/trading/meeting_panel.tscn")

@onready var split: HBoxContainer = $Split
@onready var gone_label: Label = $Gone
@onready var gone_back: Button = $GoneBack
@onready var header: HBoxContainer = $Header
@onready var back_btn: Button = $Header/Back
@onready var contact_label: Label = $Header/Contact
@onready var role_label: Label = $Header/Role
@onready var subtitle_label: Label = $Subtitle
@onready var panes: HBoxContainer = $Split/Right/Panes
@onready var specs: ScrollContainer = $Split/Right/Panes/Specs
@onready var tagline_label: Label = $Split/Right/Panes/Specs/Details/Tagline
@onready var spec_text: Label = $Split/Right/Panes/Specs/Details/SpecText
@onready var schedule_label: Label = $Split/Right/Panes/Specs/Details/Schedule
@onready var meeting_host_specs: VBoxContainer = $Split/Right/Panes/Specs/Details/MeetingHostSpecs
@onready var conversation: VBoxContainer = $Split/Right/Panes/Conversation
@onready var context_label: Label = $Split/Right/Panes/Conversation/Context
@onready var meeting_host_cover: VBoxContainer = $Split/Right/Panes/Conversation/MeetingHostCover
@onready var history_scroll: ScrollContainer = $Split/Right/Panes/Conversation/HistoryScroll
@onready var log: VBoxContainer = $Split/Right/Panes/Conversation/HistoryScroll/HistoryContent/Log
@onready var empty_log: Label = $Split/Right/Panes/Conversation/HistoryScroll/HistoryContent/EmptyLog
@onready var composer_row: HBoxContainer = $Split/Right/Panes/Conversation/ComposerRow
@onready var fault_clearance: Control = $Split/Right/Panes/Conversation/ComposerRow/FaultClearance
@onready var composer: LineEdit = $Split/Right/Panes/Conversation/ComposerRow/Composer
@onready var send_btn: Button = $Split/Right/Panes/Conversation/ComposerRow/Send
@onready var quick_row: HBoxContainer = $Split/Right/Panes/Conversation/QuickRow
@onready var quick_a: Button = $Split/Right/Panes/Conversation/QuickRow/QuickA
@onready var quick_b: Button = $Split/Right/Panes/Conversation/QuickRow/QuickB

var _meeting_panel: Control = null
var _locked := true
var _can_confirm := false
var _quick_a_text := ""


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	gone_back.pressed.connect(func() -> void: back_pressed.emit())
	composer.text_changed.connect(func(_text: String) -> void: _update_send())
	composer.text_submitted.connect(_submit)
	send_btn.pressed.connect(func() -> void: _submit(composer.text))
	quick_a.pressed.connect(func() -> void: _submit(_quick_a_text))
	quick_b.pressed.connect(func() -> void:
		if _can_confirm:
			_submit("Yes, that price, time and place works."))


func _update_send() -> void:
	send_btn.disabled = _locked or composer.text.strip_edges().is_empty()


func _submit(text: String) -> void:
	if not _locked and not text.strip_edges().is_empty():
		send_text.emit(text)


func setup_gone() -> void:
	_locked = true
	gone_label.visible = true
	gone_back.visible = true
	split.visible = false
	header.visible = false
	subtitle_label.visible = false
	panes.visible = false


func setup(listing: Dictionary, me: Dictionary, selected: int, drafts: Dictionary, pending: bool, waiting: bool, slots: bool, unfolded: bool) -> void:
	gone_label.visible = false
	gone_back.visible = false
	split.visible = true
	header.visible = true
	subtitle_label.visible = unfolded or not slots
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
	var proposal: Dictionary = me.get("meeting_proposals", {}).get(selected, {})
	var live_proposal := not proposal.is_empty() and Game.clock() < float(proposal.end)
	var buyer_offer := int(me.get("counters", {}).get(selected, 0)) if selling else 0
	role_label.text = "Buyer" if selling else "Seller"
	subtitle_label.text = str(listing.name) + (" · Your ask: $%d" if selling else " · $%d") % int(listing.price)
	subtitle_label.tooltip_text = subtitle_label.text
	tagline_label.text = Characters.for_listing(listing).tagline
	spec_text.text = Catalog.spec_text(listing)
	var schedule := Trade.profile(listing.seller, listing.location)
	schedule_label.text = str(schedule.note) + " Meets: " + ", ".join(schedule.places)
	specs.visible = unfolded
	conversation.visible = true
	var blocked := Relationships.blocked(me, listing)
	var terminal: bool = blocked or listing.status != "available" or bool(me.ready) or private_thread
	_locked = pending or waiting or terminal or waiting_for_buyer
	var has_meeting := false
	var context_text := "No deal yet."
	if selling and buyer_offer > 0 and agreed_price <= 0:
		context_text = "Buyer offers $%d · Accept or negotiate." % buyer_offer
	if me.meetings.has(selected):
		var m: Dictionary = me.meetings[selected]
		has_meeting = Game.clock() <= float(m.end)
		context_text = ("Meeting: " if has_meeting else "Missed — arrange another time: ") + str(m.label)
	elif me.offers.has(selected):
		context_text = "Agreed: $%d · Choose a time and place." % int(me.offers[selected])
	if agreed_price > 0 and live_proposal:
		context_text = "Suggested: " + str(proposal.label) + " · Confirm or choose another time."
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
	meeting_host_cover.visible = not unfolded and not terminal and not waiting_for_buyer
	meeting_host_specs.visible = unfolded and not terminal and not waiting_for_buyer
	for host in [meeting_host_specs, meeting_host_cover]:
		for c in host.get_children():
			host.remove_child(c)
			c.queue_free()
	_meeting_panel = MeetingPanelScene.instantiate()
	_meeting_panel.toggle_requested.connect(func() -> void: toggle_slots.emit())
	_meeting_panel.track_requested.connect(func() -> void: track_requested.emit())
	_meeting_panel.slot_chosen.connect(func(label: String) -> void: slot_chosen.emit(label))
	(meeting_host_specs if unfolded else meeting_host_cover).add_child(_meeting_panel)
	_meeting_panel.setup(Game.contact_options(listing), has_meeting and not terminal, slots, not unfolded, not _locked)
	for c in log.get_children():
		log.remove_child(c)
		c.queue_free()
	var messages: Array = me.chats.get(selected, [])
	empty_log.visible = messages.is_empty()
	empty_log.text = "Waiting for buyer." if waiting_for_buyer else ("Reply to the buyer." if selling else "Say hello.")
	for msg: Dictionary in messages:
		var row: HBoxContainer = MessageRowScene.instantiate()
		log.add_child(row)
		row.setup(msg, str(me.name))
	composer.placeholder_text = "Read-only conversation" if terminal else ("Waiting for buyer" if waiting_for_buyer else "Message…")
	composer.text = str(drafts.get(selected, ""))
	composer.editable = not terminal and not waiting_for_buyer
	var terms_ready := agreed_price > 0 and live_proposal and not terminal
	_can_confirm = terms_ready and not _locked
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
	quick_b.visible = terms_ready and not waiting_for_buyer
	quick_b.disabled = not _can_confirm
	quick_row.visible = (quick_a.visible or quick_b.visible) and (unfolded or not slots)
	conversation.move_child(composer_row if unfolded else quick_row, conversation.get_child_count() - 1)
	fault_clearance.visible = unfolded
	fault_clearance.mouse_filter = Control.MOUSE_FILTER_IGNORE


func scroll_bottom_deferred() -> void:
	var ref: WeakRef = weakref(history_scroll)
	_scroll_bottom(ref)


func _scroll_bottom(scroll_reference: WeakRef) -> void:
	await get_tree().process_frame
	var scroll: ScrollContainer = scroll_reference.get_ref()
	if is_instance_valid(scroll) and scroll.is_inside_tree():
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
