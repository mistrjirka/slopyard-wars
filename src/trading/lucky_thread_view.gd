extends VBoxContainer
## Lucky's one-way conversation shares the inbox but never exposes trading or reply actions.
signal back_pressed
const MessageRowScene = preload("res://src/trading/message_row.tscn")
const Trade = preload("res://src/trading/trade_rules.gd")
@onready var portrait: TextureRect = $Panes/Portrait/Inset/Lucky
@onready var portrait_panel: PanelContainer = $Panes/Portrait
@onready var history_scroll: ScrollContainer = $Panes/Conversation/History
@onready var log: VBoxContainer = $Panes/Conversation/History/Log
@onready var latest_button: Button = $Panes/Conversation/Latest
var _count := 0
var _scroll_generation := 0


func _ready() -> void:
	$Header/Back.pressed.connect(func(): back_pressed.emit())
	latest_button.pressed.connect(_scroll_to_latest)
	history_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float):
		if _at_latest():
			latest_button.hide())


func setup(messages: Array, unfolded: bool) -> void:
	portrait_panel.visible = unfolded
	update_messages(messages)


func update_messages(messages: Array) -> void:
	if messages.size() == _count:
		return
	var follow := _count == 0 or _at_latest()
	for index in range(_count, messages.size()):
		var message: Dictionary = messages[index]
		var row: HBoxContainer = MessageRowScene.instantiate()
		log.add_child(row)
		var header := "Lucky · " + Trade.stamp(float(message.minute))
		var place := str(message.get("place", ""))
		# Use an empty player name so a player named Lucky still sees incoming texts.
		row.setup({"speaker": "Lucky", "header": header, "place": place, "text": str(message.text)}, "", portrait_panel.visible)
	_count = messages.size()
	if follow:
		_scroll_to_latest()
	else:
		latest_button.show()


func _at_latest() -> bool:
	var bar := history_scroll.get_v_scroll_bar()
	return bar.value >= bar.max_value - bar.page - 4.0


func _scroll_to_latest() -> void:
	latest_button.hide()
	_scroll_generation += 1
	var generation := _scroll_generation
	for frame in 4:
		await get_tree().process_frame
		if generation != _scroll_generation:
			return
		history_scroll.scroll_vertical = int(history_scroll.get_v_scroll_bar().max_value)
