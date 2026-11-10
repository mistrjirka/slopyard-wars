extends PanelContainer
## Authored summary, active listing and expandable asking-price form.
signal chat_requested
signal cancel_requested
signal post_requested(price: int)
signal expanded_changed(expanded: bool)

const Stats = preload("res://src/data/hardware_stats.gd")

@onready var content: VBoxContainer = $Content
@onready var name_label: Label = $Content/Name
@onready var guide_label: Label = $Content/Guide
@onready var status_label: Label = $Content/Status
@onready var status_advice: Label = $Content/StatusAdvice
@onready var active_actions: HBoxContainer = $Content/ActiveActions
@onready var chat_btn: Button = $Content/ActiveActions/ChatBtn
@onready var cancel_btn: Button = $Content/ActiveActions/CancelBtn
@onready var expand_btn: Button = $Content/ExpandBtn
@onready var draft_form: VBoxContainer = $Content/DraftForm
@onready var price: SpinBox = $Content/DraftForm/Row/Price
@onready var guide_btn: Button = $Content/DraftForm/Row/GuideBtn
@onready var quick_btn: Button = $Content/DraftForm/Row/QuickBtn
@onready var post_btn: Button = $Content/DraftForm/Row/PostBtn
@onready var draft_advice: Label = $Content/DraftForm/DraftAdvice

var _item: Dictionary = {}
var _has_draft := false


func setup(item: Dictionary, active: Dictionary, draft_price: int, expanded: bool = false, has_draft: bool = false) -> void:
	_item = item
	_has_draft = has_draft
	var guide := Stats.sale_guide(item)
	name_label.text = str(item.get("name", ""))
	guide_label.text = "Condition %d/100 · estimated guide $%d" % [int(item.get("condition", 100)), guide.value]
	tooltip_text = Stats.performance_text(item)
	var has_active := not active.is_empty()
	status_advice.visible = has_active
	active_actions.visible = has_active
	expand_btn.visible = false
	expand_btn.set_pressed_no_signal(expanded and not has_active)
	draft_form.visible = not has_active
	if has_active:
		var contacted := bool(active.get("buyer_contacted", false))
		status_label.text = "Asking $%d · %s" % [int(active.price), ("%s is interested" % str(active.seller)) if contacted else "Waiting for interest"]
		status_advice.text = Stats.sale_advice(item, int(active.price))
		chat_btn.visible = contacted
	else:
		price.set_value_no_signal(float(draft_price if draft_price > 0 else guide.value))
		guide_btn.text = "Use guide: $%d" % guide.value
		quick_btn.text = "Quick deal: $%d" % guide.quick
		draft_advice.text = Stats.sale_advice(item, int(price.value))
		_update_draft_summary()


func _ready() -> void:
	chat_btn.pressed.connect(func() -> void: chat_requested.emit())
	cancel_btn.pressed.connect(func() -> void: cancel_requested.emit())
	guide_btn.pressed.connect(func() -> void: price.value = float(Stats.sale_guide(_item).value))
	quick_btn.pressed.connect(func() -> void: price.value = float(Stats.sale_guide(_item).quick))
	post_btn.pressed.connect(func() -> void: post_requested.emit(int(price.value)))
	price.value_changed.connect(_on_price_changed)
	expand_btn.toggled.connect(_on_expand)


func _on_expand(expanded: bool) -> void:
	draft_form.visible = expanded
	_update_draft_summary()
	expanded_changed.emit(expanded)


func _update_draft_summary() -> void:
	expand_btn.text = "Hide price form" if expand_btn.button_pressed else ("Edit price" if _has_draft else "List for sale")
	status_label.text = "Draft ask $%d · Not listed" % int(price.value) if _has_draft else "Not listed"


func _on_price_changed(value: float) -> void:
	if _item.is_empty():
		return
	_has_draft = true
	draft_advice.text = Stats.sale_advice(_item, int(value))
	_update_draft_summary()
