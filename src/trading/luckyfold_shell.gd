extends Control
## Device presentation only. Both modes share two replaceable textures and live UI content.
## The damaged band drifts its hue slowly and answers pointer presses with one short pulse.
signal display_pressed
const K = preload("res://src/ui/ui_kit.gd")
const DISPLAY_FAULT = preload("res://assets/ui/luckyfold/display_fault.png")
const OPEN_ASPECT := 2670.0 / 1878.0
const MAX_HEIGHT := 700.0
const PERSPECTIVE_CLEARANCE := 1.25
const OPEN_WIDTH := MAX_HEIGHT * OPEN_ASPECT
const CLOSED_WIDTH := OPEN_WIDTH * 0.5
const POCKET_HINT := "P / Esc: pocket · clock keeps running"
## Top of the damaged pixels in the replaceable 1024x768 overlay's art contract.
const DISPLAY_FAULT_TOP := 648.0 / 768.0
const DISPLAY_FAULT_BAND_BOTTOM := 656.0 / 768.0
const DISPLAY_FAULT_COLUMN_RIGHT := 516.0 / 1024.0
## Small discrete hue steps; the band drifts toward each one instead of snapping.
const HUE_STEPS: Array[float] = [0.05, -0.035, 0.06, -0.045, 0.03, -0.06]
const HUE_DRIFT_SECONDS := 1.6
const PULSE_HUE := 0.2
@export var closed_shape: StyleBoxFlat
@export var open_shape: StyleBoxFlat
var unfolded := false
var _message_layout := false
var _message_bar_height := 36.0
var _navigation_height := 0.0
var _hue := 0.0
var _hue_target := 0.0
var _hue_step := 0
var _pulse := 0.0
var _hue_tween: Tween
var _pulse_tween: Tween
@onready var content: VBoxContainer = $Inset/Content
@onready var _inset: MarginContainer = $Inset
@onready var _display: Panel = $Display
@onready var _fault: TextureRect = $Fault
@onready var _hinge: ColorRect = $Hinge
@onready var _brand: Label = $Brand
@onready var _caption: Label = $Caption
@onready var _pocket_hint: Label = $PocketHint
@onready var _hue_timer: Timer = $HueTimer


func _ready() -> void:
	custom_minimum_size = Vector2(CLOSED_WIDTH, MAX_HEIGHT)
	var frame: Panel = $Frame
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hinge.color = Color(0.6, 0.68, 0.8, 0.08)
	_hinge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top"]:
		_inset.add_theme_constant_override("margin_" + side, 30)
	_fault.texture = DISPLAY_FAULT
	_fault.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fault.stretch_mode = TextureRect.STRETCH_SCALE
	_fault.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fault.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brand.text = "LuckyFold Duo"
	_brand.theme_type_variation = "Big"
	_brand.add_theme_color_override("font_color", K.CREAM)
	_brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.text = "Factory-installed mood lighting."
	_caption.theme_type_variation = "Tiny"
	_caption.add_theme_color_override("font_color", K.MUTED)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pocket_hint.text = POCKET_HINT
	_pocket_hint.theme_type_variation = "Tiny"
	_pocket_hint.add_theme_color_override("font_color", K.MUTED)
	_pocket_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_display_hue()
	_hue_timer.timeout.connect(_drift_hue)
	display_pressed.connect(_pulse_display)
	resized.connect(_layout)
	var host := _host_viewport()
	if host != null and not host.size_changed.is_connected(_fit):
		host.size_changed.connect(_fit)
	_fit()
	# Parenting can resolve our initial size before resized is emitted in the tree.
	# Apply the cover layout once that size is available, even while the phone is hidden.
	_layout()


func set_unfolded(value: bool) -> void:
	unfolded = value
	_fit()
	_layout()


func _fit() -> void:
	var host := _host_viewport()
	var available := host.get_visible_rect().size if host != null else Vector2(1440, 900)
	# Both modes use one physical scale fitted against the entire OPEN footprint.
	# The far edge approaches the viewer and reaches 1.25x height mid-turn.
	var height_limit := minf(MAX_HEIGHT, minf((available.y - 48.0) / PERSPECTIVE_CLEARANCE, (available.x - 48.0) / OPEN_ASPECT))
	var height := maxf(2.0, floorf(height_limit * 0.5) * 2.0)
	var half_limit := maxf(2.0, floorf((available.x - 48.0) * 0.25) * 2.0)
	var half_width := minf(half_limit, maxf(2.0, roundf(height * OPEN_ASPECT * 0.25) * 2.0))
	# Even physical dimensions keep both centered resting modes on whole pixels,
	# matching their integer SubViewport textures 1:1. A nearby even height can
	# avoid a disproportionate aspect error from rounding a narrow half-width.
	for step in range(1, 5):
		if absf(half_width * 2.0 / height / OPEN_ASPECT - 1.0) <= 0.002:
			break
		var candidate_height := maxf(2.0, floorf(height_limit * 0.5) * 2.0 - step * 2.0)
		var candidate_half := minf(half_limit, maxf(2.0, roundf(candidate_height * OPEN_ASPECT * 0.25) * 2.0))
		if absf(candidate_half * 2.0 / candidate_height / OPEN_ASPECT - 1.0) < absf(half_width * 2.0 / height / OPEN_ASPECT - 1.0):
			height = candidate_height
			half_width = candidate_half
	custom_minimum_size = Vector2(half_width * (2.0 if unfolded else 1.0), height)


## The device renders inside the phone's capture SubViewport, so its own viewport is only
## as large as the device. Fit against the viewport that shows the phone instead.
func _host_viewport() -> Viewport:
	if not is_inside_tree():
		return null
	var viewport := get_viewport()
	while viewport is SubViewport and viewport.get_parent() is SubViewportContainer:
		var host := viewport.get_parent().get_viewport()
		if host == null or host == viewport:
			break
		viewport = host
	return viewport


func _input(event: InputEvent) -> void:
	var hit := false
	var press := Vector2.ZERO
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		hit = true
		press = mouse.position
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed:
		hit = true
		press = touch.position
	if hit and get_global_rect().has_point(press):
		display_pressed.emit()


func _drift_hue() -> void:
	_hue_step = (_hue_step + 1) % HUE_STEPS.size()
	_hue_target = wrapf(_hue_target + HUE_STEPS[_hue_step], -0.5, 0.5)
	if _hue_tween != null and _hue_tween.is_valid():
		_hue_tween.kill()
	_hue_tween = create_tween()
	_hue_tween.tween_method(_set_hue, _hue, _hue_target, HUE_DRIFT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _pulse_display() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_method(_set_pulse, 0.0, 1.0, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_method(_set_pulse, 1.0, 0.0, 0.44).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_hue(value: float) -> void:
	_hue = value
	_apply_display_hue()


func _set_pulse(value: float) -> void:
	_pulse = value
	_apply_display_hue()


func _apply_display_hue() -> void:
	var material := _fault.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("hue_shift", _hue + _pulse * PULSE_HUE)


func set_message_layout(value: bool) -> void:
	if _message_layout == value:
		return
	_message_layout = value
	_layout()


func set_navigation_height(value: float) -> void:
	if is_equal_approx(_navigation_height, value):
		return
	_navigation_height = value
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
	var frame := $Frame as Panel
	frame.add_theme_stylebox_override("panel", open_shape if unfolded else closed_shape)
	_display.position = Vector2(18, 18)
	_display.size = Vector2(maxf(0, size.x - 36), maxf(0, size.y - (36 if unfolded else 110)))
	_fault.position = _display.position
	_fault.size = _display.size
	_fault.visible = unfolded
	# Tuck the message bar's upper border into the stripe, leaving its text below it.
	var bottom_margin := 24 if unfolded else 96
	if unfolded and _message_layout:
		var bar_top := _display.position.y + _display.size.y * DISPLAY_FAULT_BAND_BOTTOM - 3.0
		# The fitted phone can be shorter than the old 760px shell. Do not let a
		# fixed footer margin pull the composer above the physical damaged stripe.
		bottom_margin = maxi(18, roundi(size.y - bar_top - _message_bar_height - _navigation_height))
	_inset.add_theme_constant_override("margin_bottom", bottom_margin)
	_hinge.position = Vector2(size.x * 0.5 - 1, 20)
	_hinge.size = Vector2(2, maxf(0, size.y - 40))
	_hinge.visible = unfolded
	_brand.position = Vector2(24, size.y - 82)
	_brand.size = Vector2(maxf(0, size.x - 48), 54)
	_brand.visible = not unfolded
	_caption.position = Vector2(size.x * 0.5, size.y - 38)
	_caption.size = Vector2(maxf(0, size.x * 0.5 - 32), _caption.get_combined_minimum_size().y)
	_caption.visible = unfolded and is_zero_approx(_navigation_height)
	_pocket_hint.position = Vector2(32, _caption.position.y)
	_pocket_hint.size = Vector2(maxf(0, size.x * 0.5 - 32), _caption.get_combined_minimum_size().y)
	_pocket_hint.visible = _caption.visible
