extends RefCounted
## Shared palette, fonts, theme and control updates for the Slopyard Wars UI.
const Config = preload("res://src/core/game_config.gd")
const Trade = preload("res://src/trading/trade_rules.gd")

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


## Designed on an 8-pixel grid, rather than shrinking the UI font into the world.
## Draw at 8px (or integer multiples); import settings preserve the pixel outlines.
static func world_font(bold: bool = false) -> Font:
	return preload("res://assets/fonts/pixel_operator/PixelOperator8-Bold.ttf") if bold else preload("res://assets/fonts/pixel_operator/PixelOperator8.ttf")


## The overview is drawn at screen resolution, so use the family's native 16px cut.
static func map_font(bold: bool = false) -> Font:
	return preload("res://assets/fonts/pixel_operator/PixelOperator-Bold.ttf") if bold else preload("res://assets/fonts/pixel_operator/PixelOperator.ttf")


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


static func clock_text(remaining: float, total_minutes: float = Config.TOTAL_MINUTES) -> String:
	return Trade.stamp(Config.START_MINUTE + clampf(total_minutes - remaining, 0, total_minutes))


static func real_left(remaining: float) -> String:
	var secs: int = ceili(maxf(0.0, remaining) / Config.RATE)
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


# ---------- theme ----------


static func make_theme() -> Theme:
	return preload("res://resources/ui/game_theme.tres")

# ---------- existing control updates ----------


static func set_pill(p: PanelContainer, text: String, color: Color) -> void:
	p.add_theme_stylebox_override("panel", box(Color(color, 0.12), Color(color, 0.7), 20, 1, 9, 2))
	var l: Label = p.get_node("L")
	l.text = text
	l.add_theme_color_override("font_color", color)



static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
