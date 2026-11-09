extends RefCounted
## Shared palette, fonts, theme and tiny widget builders for the Slopyard Wars UI.

const NAVY0 := Color("050a1a")
const NAVY1 := Color("0a1330")
const PANEL := Color("101c3d")
const PANEL2 := Color("162651")
const LINE := Color("2a4075")
const CREAM := Color("f4ecd8")
const MUTED := Color("a2a9bd")
const FAINT := Color("5c6a92")
const LIME := Color("c6ff3d")
const LIME_DIM := Color("5f7f1d")
const ORANGE := Color("ff8a2a")
const DANGER := Color("ff4b3a")
const SKY := Color("6fb4ff")

const CATS: Array = ["case", "motherboard", "cpu", "gpu", "ram", "psu", "storage"]
const CAT_LABEL := {"case": "CASE", "psu": "PSU", "cpu": "CPU", "motherboard": "MOTHERBOARD", "gpu": "GRAPHICS", "ram": "RAM", "storage": "STORAGE"}
const CAT_COLOR := {
	"case": Color("8fb5ff"), "psu": Color("ffc857"), "cpu": Color("ff8a2a"), "motherboard": Color("5fd6a0"),
	"gpu": Color("c6ff3d"), "ram": Color("b79cff"), "storage": Color("6fe0f0")}

static var _fonts: Dictionary = {}
static var _tex: Dictionary = {}


static func _sys(names: Array, weight: int) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	return f


static func _hack(path: String, fallback: Font) -> Font:
	if ResourceLoader.exists(path):
		var f: Font = load(path)
		if f:
			return f
	return fallback


static func mono() -> Font:
	if not _fonts.has("mono"):
		_fonts["mono"] = _hack("res://assets/fonts/Hack-Regular.ttf", _sys(["JetBrains Mono", "IBM Plex Mono", "Fira Code", "DejaVu Sans Mono", "Consolas", "Menlo", "monospace"], 500))
	return _fonts["mono"]


static func mono_bold() -> Font:
	if not _fonts.has("monob"):
		_fonts["monob"] = _hack("res://assets/fonts/Hack-Bold.ttf", _sys(["JetBrains Mono", "IBM Plex Mono", "Fira Code", "DejaVu Sans Mono", "Consolas", "Menlo", "monospace"], 800))
	return _fonts["monob"]


static func body() -> Font:
	if not _fonts.has("body"):
		_fonts["body"] = _sys(["Inter", "IBM Plex Sans", "Noto Sans", "Segoe UI", "DejaVu Sans", "sans-serif"], 400)
	return _fonts["body"]


static func body_bold() -> Font:
	if not _fonts.has("bodyb"):
		_fonts["bodyb"] = _sys(["Inter", "IBM Plex Sans", "Noto Sans", "Segoe UI", "DejaVu Sans", "sans-serif"], 700)
	return _fonts["bodyb"]

# ---------- generic helpers ----------


static func money(n) -> String:
	var v: int = int(n)
	var s := str(absi(v))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-$" if v < 0 else "$") + out


static func geti(d: Dictionary, id: int, default: Variant = null) -> Variant:
	if d.has(id):
		return d[id]
	var s := str(id)
	if d.has(s):
		return d[s]
	return default


static func clock_text(remaining: float) -> String:
	var el: float = clampf(4320.0 - remaining, 0.0, 4320.0)
	var day: int = mini(int(el / 1440.0) + 1, 3)
	var tod: int = int(el) % 1440
	return "DAY %d  %02d:%02d" % [day, floori(tod / 60.0), tod % 60]


static func real_left(remaining: float) -> String:
	var secs: int = int(maxf(0.0, remaining) / 6.0)
	return "%d:%02d" % [floori(secs / 60.0), secs % 60]


static func cat_color(cat: String) -> Color:
	return CAT_COLOR.get(cat, CREAM)


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 6, bw: int = 0, ph: int = 12, pv: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = ph
	s.content_margin_right = ph
	s.content_margin_top = pv
	s.content_margin_bottom = pv
	s.anti_aliasing = true
	return s


static func dot_tex(color: Color, size: int = 16) -> Texture2D:
	var key := "%s%d" % [color.to_html(), size]
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for x in size:
		for y in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(c.x - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t

# ---------- theme ----------


static func _btn_variant(t: Theme, name: StringName, base: Dictionary, font_col: Color, font: Font = null, size: int = 14) -> void:
	t.add_type(name)
	t.set_type_variation(name, "Button")
	for k in base:
		t.set_stylebox(k, name, base[k])
	t.set_color("font_color", name, font_col)
	t.set_color("font_hover_color", name, font_col)
	t.set_color("font_pressed_color", name, font_col)
	t.set_color("font_focus_color", name, font_col)
	t.set_color("font_hover_pressed_color", name, font_col)
	t.set_color("font_disabled_color", name, FAINT)
	t.set_font("font", name, font if font else mono_bold())
	t.set_font_size("font_size", name, size)


static func _var_label(t: Theme, name: StringName, font: Font, size: int, col: Color) -> void:
	t.add_type(name)
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, col)


static func _var_panel(t: Theme, name: StringName, sb: StyleBox) -> void:
	t.add_type(name)
	t.set_type_variation(name, "PanelContainer")
	t.set_stylebox("panel", name, sb)


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = body()
	t.default_font_size = 14
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	# Panels
	t.set_stylebox("panel", "PanelContainer", box(PANEL, LINE, 8, 1, 14, 12))
	_var_panel(t, "Card", box(PANEL, LINE, 8, 1, 14, 12))
	_var_panel(t, "CardTight", box(PANEL, LINE, 8, 1, 10, 8))
	_var_panel(t, "CardHot", box(PANEL2, LIME, 8, 2, 14, 12))
	_var_panel(t, "CardRisk", box(Color("2a1a14"), ORANGE, 8, 2, 14, 12))
	_var_panel(t, "Inset", box(NAVY0, LINE, 6, 1, 10, 8))
	_var_panel(t, "Hero", box(PANEL2, LINE, 12, 1, 22, 20))
	_var_panel(t, "Topbar", box(Color("070e24"), LINE, 0, 0, 16, 8))
	_var_panel(t, "Toast", box(Color("0c1736"), LIME, 6, 1, 14, 10))
	_var_panel(t, "ToastRisk", box(Color("2a1a14"), ORANGE, 6, 1, 14, 10))
	_var_panel(t, "BubbleMe", box(Color("33481a"), LIME_DIM, 10, 1, 12, 8))
	_var_panel(t, "BubbleThem", box(PANEL2, LINE, 10, 1, 12, 8))
	_var_panel(t, "Pill", box(NAVY0, LINE, 20, 1, 10, 2))
	# Labels
	_var_label(t, "Title", mono_bold(), 30, CREAM)
	_var_label(t, "Display", mono_bold(), 54, CREAM)
	_var_label(t, "H2", mono_bold(), 18, CREAM)
	_var_label(t, "Eyebrow", mono_bold(), 11, LIME)
	_var_label(t, "Muted", body(), 13, MUTED)
	_var_label(t, "Mono", mono(), 13, CREAM)
	_var_label(t, "Big", mono_bold(), 22, CREAM)
	_var_label(t, "Tiny", mono(), 11, MUTED)
	# Buttons
	var nb := box(PANEL2, LINE, 6, 1, 14, 8)
	t.set_stylebox("normal", "Button", nb)
	t.set_stylebox("hover", "Button", box(Color("1d3166"), SKY, 6, 1, 14, 8))
	t.set_stylebox("pressed", "Button", box(NAVY0, LIME, 6, 1, 14, 8))
	t.set_stylebox("disabled", "Button", box(Color("0b1430"), Color("1b2a52"), 6, 1, 14, 8))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), LIME, 6, 2, 14, 8))
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", CREAM)
	t.set_color("font_pressed_color", "Button", LIME)
	t.set_color("font_disabled_color", "Button", FAINT)
	t.set_font("font", "Button", mono_bold())
	t.set_font_size("font_size", "Button", 13)
	_btn_variant(t, "PrimaryButton", {
		"normal": box(LIME, LIME, 6, 1, 18, 9), "hover": box(Color("dcff7a"), CREAM, 6, 1, 18, 9),
		"pressed": box(Color("93bf20"), CREAM, 6, 1, 18, 9), "disabled": box(Color("2a3a22"), Color("2a3a22"), 6, 1, 18, 9),
		"focus": box(Color(0, 0, 0, 0), CREAM, 6, 2, 18, 9)}, NAVY0, null, 14)
	_btn_variant(t, "RiskButton", {
		"normal": box(ORANGE, ORANGE, 6, 1, 18, 9), "hover": box(Color("ffab62"), CREAM, 6, 1, 18, 9),
		"pressed": box(Color("c4651a"), CREAM, 6, 1, 18, 9), "disabled": box(Color("3a2616"), Color("3a2616"), 6, 1, 18, 9),
		"focus": box(Color(0, 0, 0, 0), CREAM, 6, 2, 18, 9)}, NAVY0, null, 14)
	_btn_variant(t, "GhostButton", {
		"normal": box(Color(0, 0, 0, 0), LINE, 6, 1, 12, 7), "hover": box(Color(1, 1, 1, 0.06), SKY, 6, 1, 12, 7),
		"pressed": box(Color(1, 1, 1, 0.1), LIME, 6, 1, 12, 7), "disabled": box(Color(0, 0, 0, 0), Color("1b2a52"), 6, 1, 12, 7),
		"focus": box(Color(0, 0, 0, 0), LIME, 6, 2, 12, 7)}, CREAM, null, 12)
	_btn_variant(t, "TabButton", {
		"normal": box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 0, 14, 9), "hover": box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 4, 0, 14, 9),
		"pressed": box(PANEL2, LIME, 4, 1, 14, 9), "hover_pressed": box(PANEL2, LIME, 4, 1, 14, 9), "disabled": box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 0, 14, 9),
		"focus": box(Color(0, 0, 0, 0), LIME, 4, 2, 14, 9)}, MUTED, null, 13)
	t.set_color("font_pressed_color", "TabButton", LIME)
	t.set_color("font_hover_pressed_color", "TabButton", LIME)
	_btn_variant(t, "ChipButton", {
		"normal": box(NAVY0, LINE, 20, 1, 11, 4), "hover": box(PANEL2, SKY, 20, 1, 11, 4),
		"pressed": box(Color("2c3d12"), LIME, 20, 1, 11, 4), "hover_pressed": box(Color("2c3d12"), LIME, 20, 1, 11, 4), "disabled": box(NAVY0, LINE, 20, 1, 11, 4),
		"focus": box(Color(0, 0, 0, 0), LIME, 20, 2, 11, 4)}, MUTED, mono(), 12)
	t.set_color("font_pressed_color", "ChipButton", LIME)
	t.set_color("font_hover_pressed_color", "ChipButton", LIME)
	t.set_stylebox("normal", "OptionButton", nb)
	# LineEdit
	t.set_stylebox("normal", "LineEdit", box(NAVY0, LINE, 6, 1, 10, 8))
	t.set_stylebox("focus", "LineEdit", box(NAVY0, LIME, 6, 2, 10, 8))
	t.set_stylebox("read_only", "LineEdit", box(NAVY1, LINE, 6, 1, 10, 8))
	t.set_color("font_color", "LineEdit", CREAM)
	t.set_color("font_placeholder_color", "LineEdit", FAINT)
	t.set_color("caret_color", "LineEdit", LIME)
	t.set_color("selection_color", "LineEdit", Color(LIME, 0.3))
	t.set_font("font", "LineEdit", mono())
	t.set_font_size("font_size", "LineEdit", 14)
	# Popups
	t.set_stylebox("panel", "PopupMenu", box(PANEL, LIME, 6, 1, 6, 6))
	t.set_stylebox("hover", "PopupMenu", box(PANEL2, LIME, 4, 0, 6, 4))
	t.set_color("font_color", "PopupMenu", CREAM)
	t.set_color("font_hover_color", "PopupMenu", LIME)
	t.set_font("font", "PopupMenu", mono())
	t.set_stylebox("panel", "PopupPanel", box(PANEL, LIME, 6, 1, 6, 6))
	t.set_stylebox("panel", "AcceptDialog", box(PANEL, LIME, 8, 2, 16, 14))
	t.set_stylebox("embedded_border", "Window", box(PANEL, LIME, 8, 2, 16, 14))
	t.set_color("title_color", "Window", LIME)
	t.set_font("title_font", "Window", mono_bold())
	# Scroll bars
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, box(Color(1, 1, 1, 0.03), Color(0, 0, 0, 0), 4, 0, 3, 3))
		t.set_stylebox("grabber", bar, box(LINE, Color(0, 0, 0, 0), 4, 0, 3, 3))
		t.set_stylebox("grabber_highlight", bar, box(SKY, Color(0, 0, 0, 0), 4, 0, 3, 3))
		t.set_stylebox("grabber_pressed", bar, box(LIME, Color(0, 0, 0, 0), 4, 0, 3, 3))
	# Sliders / progress
	t.set_stylebox("slider", "HSlider", box(NAVY0, LINE, 3, 1, 0, 2))
	t.set_stylebox("grabber_area", "HSlider", box(LIME_DIM, LIME_DIM, 3, 0, 0, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(LIME, LIME, 3, 0, 0, 2))
	t.set_icon("grabber", "HSlider", dot_tex(LIME, 18))
	t.set_icon("grabber_highlight", "HSlider", dot_tex(CREAM, 18))
	t.set_icon("grabber_disabled", "HSlider", dot_tex(FAINT, 18))
	t.set_stylebox("background", "ProgressBar", box(NAVY0, LINE, 4, 1, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(LIME, LIME, 4, 0, 0, 0))
	t.set_color("font_color", "ProgressBar", CREAM)
	t.set_font_size("font_size", "ProgressBar", 11)
	t.set_font("font", "ProgressBar", mono())
	t.add_type("RiskBar")
	t.set_type_variation("RiskBar", "ProgressBar")
	t.set_stylebox("fill", "RiskBar", box(ORANGE, ORANGE, 4, 0, 0, 0))
	t.add_type("CyanBar")
	t.set_type_variation("CyanBar", "ProgressBar")
	t.set_stylebox("fill", "CyanBar", box(SKY, SKY, 4, 0, 0, 0))
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("default_color", "RichTextLabel", CREAM)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("h_separation", "HFlowContainer", 10)
	t.set_constant("v_separation", "HFlowContainer", 10)
	return t

# ---------- builders ----------


static func lbl(text: String, variation: String = "", color: Variant = null, autowrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if color != null:
		l.add_theme_color_override("font_color", color)
	if autowrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 40
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func btn(text: String, variation: String = "", cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if variation == "TabButton" or variation == "ChipButton":
		b.toggle_mode = true
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func panel(variation: String = "Card") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	return p


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(expand: bool = true, size: int = 0) -> Control:
	var c := Control.new()
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func pill(text: String, color: Color = LIME) -> PanelContainer:
	var p := panel("Pill")
	p.add_theme_stylebox_override("panel", box(Color(color, 0.12), Color(color, 0.7), 20, 1, 9, 2))
	var l := lbl(text, "Tiny", color)
	l.name = "L"
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func set_pill(p: PanelContainer, text: String, color: Color) -> void:
	p.add_theme_stylebox_override("panel", box(Color(color, 0.12), Color(color, 0.7), 20, 1, 9, 2))
	var l: Label = p.get_node("L")
	l.text = text
	l.add_theme_color_override("font_color", color)


static func scroll(h: bool = false) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if h else ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func hrule() -> ColorRect:
	var r := ColorRect.new()
	r.color = LINE
	r.custom_minimum_size = Vector2(0, 1)
	return r
