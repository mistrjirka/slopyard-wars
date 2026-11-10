extends VBoxContainer
## Conversation and optional listing details share the same phone page.
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
@onready var sidebar: VBoxContainer = $Split/Sidebar
@onready var sidebar_list: VBoxContainer = $Split/Sidebar/Scroll/List
@onready var gone_label: Label = $Gone
@onready var gone_back: Button = $GoneBack
@onready var header: HBoxContainer = $Split/Right/Header
@onready var back_btn: Button = $Split/Right/Header/Back
@onready var contact_label: Label = $Split/Right/Header/Contact
@onready var role_label: Label = $Split/Right/Header/Role
@onready var details_btn: Button = $Split/Right/Header/Details
@onready var subtitle_label: Label = $Split/Right/Subtitle
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
var _details_open := false
var _can_confirm := false


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	gone_back.pressed.connect(func() -> void: back_pressed.emit())
	details_btn.toggled.connect(_show_details)
	composer.text_changed.connect(func(_text: String) -> void: _update_send())
	composer.text_submitted.connect(_submit)
	send_btn.pressed.connect(func() -> void: _submit(composer.text))
	quick_a.pressed.connect(func() -> void: _submit("Is it still available?"))
	quick_b.pressed.connect(func() -> void:
		if _can_confirm:
			_submit("Yes, that price, time and place works."))


func _update_send() -> void:
	send_btn.disabled = _locked or composer.text.strip_edges().is_empty()


func _submit(text: String) -> void:
	if not _locked and not text.strip_edges().is_empty():
		send_text.emit(text)


func _show_details(open: bool) -> void:
	_details_open = open
	specs.visible = open
	conversation.visible = not open
	details_btn.text = "Chat" if open else "Details"


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
	sidebar.visible = unfolded
	header.visible = true
	subtitle_label.visible = unfolded or not slots
	panes.visible = true
	contact_label.text = str(listing.seller)
	contact_label.tooltip_text = str(listing.seller)
	role_label.text = "Buyer" if int(listing.get("owner", 0)) > 0 else "Seller"
	subtitle_label.text = str(listing.name) + " · $%d" % int(listing.price)
	subtitle_label.tooltip_text = subtitle_label.text
	tagline_label.text = Characters.for_listing(listing).tagline
	spec_text.text = Catalog.spec_text(listing)
	var schedule := Trade.profile(listing.seller, listing.location)
	schedule_label.text = str(schedule.note) + " Meets: " + ", ".join(schedule.places)
	_show_details(_details_open)
	var blocked := Relationships.blocked(me, listing)
	var terminal: bool = blocked or listing.status != "available" or bool(me.ready)
	_locked = pending or waiting or terminal
	var has_meeting := false
	var context_text := "No agreed price. Ask or make an offer."
	if me.meetings.has(selected):
		var m: Dictionary = me.meetings[selected]
		has_meeting = Game.clock() <= float(m.end)
		context_text = ("Meeting: " if has_meeting else "Missed — arrange another time: ") + str(m.label)
	elif me.offers.has(selected):
		context_text = "Agreed: $%d · Choose a time and place." % int(me.offers[selected])
	if pending or waiting:
		context_text = "Waiting for a reply. You can draft your next message."
	if bool(me.ready):
		context_text = "You're ready. Conversation is read-only."
	if listing.status != "available":
		context_text = str(listing.status).capitalize() + " · Conversation is read-only."
	if blocked:
		context_text = "Contact blocked trading. Try another seller."
	context_label.text = context_text
	meeting_host_cover.visible = not terminal
	meeting_host_specs.visible = false
	for host in [meeting_host_specs, meeting_host_cover]:
		for c in host.get_children():
			host.remove_child(c)
			c.queue_free()
	_meeting_panel = MeetingPanelScene.instantiate()
	_meeting_panel.toggle_requested.connect(func() -> void: toggle_slots.emit())
	_meeting_panel.track_requested.connect(func() -> void: track_requested.emit())
	_meeting_panel.slot_chosen.connect(func(label: String) -> void: slot_chosen.emit(label))
	meeting_host_cover.add_child(_meeting_panel)
	_meeting_panel.setup(Game.contact_options(listing), has_meeting and not terminal, slots, true, not _locked)
	for c in log.get_children():
		log.remove_child(c)
		c.queue_free()
	var messages: Array = me.chats.get(selected, [])
	empty_log.visible = messages.is_empty()
	for msg: Dictionary in messages:
		var row: HBoxContainer = MessageRowScene.instantiate()
		log.add_child(row)
		row.setup(msg, str(me.name))
	composer.placeholder_text = "Read-only conversation" if terminal else "Message…"
	composer.text = str(drafts.get(selected, ""))
	composer.editable = not terminal
	var terms_ready := int(me.offers.get(selected, 0)) > 0 and has_meeting and not terminal
	_can_confirm = terms_ready and not _locked
	_update_send()
	# In the compact cover, the open time picker replaces the quick shortcuts.
	quick_row.visible = not terminal and (unfolded or not slots)
	quick_a.disabled = _locked
	quick_b.visible = terms_ready
	quick_b.disabled = not _can_confirm
	fault_clearance.mouse_filter = Control.MOUSE_FILTER_IGNORE


func scroll_bottom_deferred() -> void:
	var ref: WeakRef = weakref(history_scroll)
	_scroll_bottom(ref)


func _scroll_bottom(scroll_reference: WeakRef) -> void:
	await get_tree().process_frame
	var scroll: ScrollContainer = scroll_reference.get_ref()
	if is_instance_valid(scroll) and scroll.is_inside_tree():
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
