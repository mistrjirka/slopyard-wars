extends Control
## Device presentation only. Both modes share two replaceable textures and live UI content.
const K = preload("res://src/ui/ui_kit.gd")
const FRAME = preload("res://assets/ui/luckyfold/device_frame.png")
const DISPLAY_FAULT = preload("res://assets/ui/luckyfold/display_fault.png")
const CLOSED_WIDTH := 424.0
const OPEN_WIDTH := 1000.0
const POCKET_HINT := "P / Esc: pocket · clock keeps running"
## Top of the damaged pixels in the replaceable 1024x768 overlay's art contract.
const DISPLAY_FAULT_TOP := 648.0 / 768.0
const DISPLAY_FAULT_BAND_BOTTOM := 656.0 / 768.0
const DISPLAY_FAULT_COLUMN_RIGHT := 516.0 / 1024.0
var unfolded := false
var _message_layout := false
var _message_bar_height := 36.0
var content: VBoxContainer
var _inset: MarginContainer
var _display: Panel
var _fault: TextureRect
var _hinge: ColorRect
var _brand: Label
var _caption: Label
var _pocket_hint: Label


func _init() -> void:
	custom_minimum_size = Vector2(CLOSED_WIDTH, 760)
	var frame := NinePatchRect.new()
	frame.texture = FRAME
	frame.patch_margin_left = 40
	frame.patch_margin_top = 40
	frame.patch_margin_right = 40
	frame.patch_margin_bottom = 40
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	_display = Panel.new()
	_display.add_theme_stylebox_override("panel", K.box(Color("080f20"), Color("28344b"), 18, 1, 0, 0))
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_display)
	_hinge = ColorRect.new()
	_hinge.color = Color(0.6, 0.68, 0.8, 0.08)
	_hinge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hinge)
	_inset = MarginContainer.new()
	_inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top"]:
		_inset.add_theme_constant_override("margin_" + side, 30)
	add_child(_inset)
	content = K.vbox(8)
	_inset.add_child(content)
	_fault = TextureRect.new()
	_fault.texture = DISPLAY_FAULT
	_fault.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fault.stretch_mode = TextureRect.STRETCH_SCALE
	_fault.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fault.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fault)
	_brand = K.lbl("LuckyFold Duo", "Big", K.CREAM)
	_brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_brand)
	_caption = K.lbl("Factory-installed mood lighting.", "Tiny", K.MUTED)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_caption)
	_pocket_hint = K.lbl(POCKET_HINT, "Tiny", K.MUTED)
	_pocket_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pocket_hint)
	resized.connect(_layout)
	_layout()


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()
	# Parenting can resolve our initial size before resized is emitted in the tree.
	# Apply the cover layout once that size is available, even while the phone is hidden.
	_layout()


func set_unfolded(value: bool) -> void:
	unfolded = value
	_fit()
	_layout()


func _fit() -> void:
	var available := get_viewport_rect().size if is_inside_tree() else Vector2(1440, 900)
	custom_minimum_size = Vector2(minf(OPEN_WIDTH if unfolded else CLOSED_WIDTH, available.x - 48), clampf(available.y - 48, 560, 760))


func set_message_layout(value: bool) -> void:
	if _message_layout == value:
		return
	_message_layout = value
	_layout()


func set_message_bar_height(value: float) -> void:
	if is_equal_approx(_message_bar_height, value):
		return
	_message_bar_height = value
	_layout()


func message_text_left() -> float:
	return _display.global_position.x + _display.size.x * DISPLAY_FAULT_COLUMN_RIGHT + 8.0


func _layout() -> void:
	if not is_instance_valid(_inset):
		return
	_display.position = Vector2(18, 18)
	_display.size = Vector2(maxf(0, size.x - 36), maxf(0, size.y - (36 if unfolded else 110)))
	_fault.position = _display.position
	_fault.size = _display.size
	_fault.visible = unfolded
	# Tuck the message bar's upper border into the stripe, leaving its text below it.
	var bottom_margin := 72 if unfolded else 96
	if unfolded and _message_layout:
		var bar_top := _display.position.y + _display.size.y * DISPLAY_FAULT_BAND_BOTTOM - 3.0
		bottom_margin = maxi(bottom_margin, roundi(size.y - bar_top - _message_bar_height))
	_inset.add_theme_constant_override("margin_bottom", bottom_margin)
	_hinge.position = Vector2(size.x * 0.5 - 1, 20)
	_hinge.size = Vector2(2, maxf(0, size.y - 40))
	_hinge.visible = unfolded
	_brand.position = Vector2(24, size.y - 82)
	_brand.size = Vector2(maxf(0, size.x - 48), 54)
	_brand.visible = not unfolded
	_caption.position = Vector2(size.x * 0.5, size.y - 56)
	_caption.size = Vector2(maxf(0, size.x * 0.5 - 32), _caption.get_combined_minimum_size().y)
	_caption.visible = unfolded
	_pocket_hint.position = Vector2(32, _caption.position.y)
	_pocket_hint.size = Vector2(maxf(0, size.x * 0.5 - 32), _caption.get_combined_minimum_size().y)
	_pocket_hint.visible = unfolded
