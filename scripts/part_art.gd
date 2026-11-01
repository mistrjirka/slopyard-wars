extends Control
## Code-drawn component illustrations. Unit space is 100 x 70.
const K = preload("res://scripts/ui_kit.gd")

var category: String = "cpu"
var item: Dictionary = {}
var dim: bool = false

func show_item(it: Dictionary, p_dim: bool = false) -> void:
	item = it
	category = String(it.get("category", "cpu"))
	dim = p_dim
	queue_redraw()

func _draw() -> void:
	var s: float = minf(size.x / 100.0, size.y / 70.0)
	if s <= 0.0:
		return
	var off := (size - Vector2(100, 70) * s) * 0.5
	var tint: Color = K.cat_color(category)
	if dim:
		tint = tint.darkened(0.4)
	draw_part(self, Transform2D(0.0, Vector2(s, s), 0.0, off + Vector2(50, 35) * s), category, item, tint, 1.0)

## Draws the part centered on xform's origin. Resets the draw transform afterwards.
static func draw_part(ci: CanvasItem, xform: Transform2D, cat: String, it: Dictionary, tint: Color, alpha: float) -> void:
	ci.draw_set_transform_matrix(xform * Transform2D(0.0, Vector2(-50, -35)))
	var body := Color(K.PANEL2.r, K.PANEL2.g, K.PANEL2.b, alpha)
	var dark := Color(K.NAVY0.r, K.NAVY0.g, K.NAVY0.b, alpha)
	var edge := Color(tint.r, tint.g, tint.b, alpha)
	var soft := Color(tint.r, tint.g, tint.b, 0.35 * alpha)
	var gold := Color(1.0, 0.8, 0.3, alpha)
	var cream := Color(K.CREAM.r, K.CREAM.g, K.CREAM.b, 0.8 * alpha)
	match cat:
		"case":
			ci.draw_rect(Rect2(30, 4, 40, 62), body)
			ci.draw_rect(Rect2(30, 4, 40, 62), edge, false, 1.4)
			ci.draw_rect(Rect2(34, 9, 26, 40), dark)
			ci.draw_rect(Rect2(34, 9, 26, 40), soft, false, 1.0)
			for i in 2:
				var c := Vector2(47, 21 + i * 19)
				ci.draw_arc(c, 8, 0, TAU, 24, edge, 1.0)
				for b in 4:
					ci.draw_arc(c, 6, b * TAU / 4.0, b * TAU / 4.0 + 1.0, 6, soft, 2.4)
				ci.draw_circle(c, 1.6, edge)
			for i in 6:
				ci.draw_line(Vector2(63, 10 + i * 6), Vector2(67, 10 + i * 6), soft, 1.2)
			ci.draw_rect(Rect2(34, 53, 26, 8), dark)
			ci.draw_line(Vector2(36, 57), Vector2(58, 57), soft, 1.0)
			ci.draw_rect(Rect2(32, 66, 6, 2.5), edge)
			ci.draw_rect(Rect2(62, 66, 6, 2.5), edge)
		"psu":
			ci.draw_rect(Rect2(12, 14, 76, 42), body)
			ci.draw_rect(Rect2(12, 14, 76, 42), edge, false, 1.4)
			var c := Vector2(36, 35)
			ci.draw_circle(c, 17, dark)
			for r in [5, 9, 13, 16]:
				ci.draw_arc(c, r, 0, TAU, 28, soft, 1.0)
			for a in 8:
				ci.draw_line(c, c + Vector2(16, 0).rotated(a * TAU / 8.0), soft, 0.8)
			ci.draw_circle(c, 2.5, edge)
			ci.draw_rect(Rect2(60, 20, 22, 30), dark)
			for i in 4:
				ci.draw_line(Vector2(63, 26 + i * 6), Vector2(79, 26 + i * 6), soft, 1.2)
			ci.draw_rect(Rect2(63, 22, 8, 2), edge)
			var wcols := [Color(1, 0.4, 0.2, alpha), Color(1, 0.8, 0.3, alpha), Color(0.4, 0.8, 1, alpha)]
			for i in 3:
				ci.draw_line(Vector2(88, 24 + i * 9), Vector2(97, 24 + i * 9), wcols[i], 2.0)
		"cpu":
			ci.draw_rect(Rect2(25, 10, 50, 50), body)
			ci.draw_rect(Rect2(25, 10, 50, 50), edge, false, 1.4)
			for i in 12:
				var x := 28.5 + i * 3.8
				ci.draw_rect(Rect2(x, 6, 1.6, 3), gold)
				ci.draw_rect(Rect2(x, 61, 1.6, 3), gold)
				ci.draw_rect(Rect2(21, 13.5 + i * 3.8, 3, 1.6), gold)
				ci.draw_rect(Rect2(76, 13.5 + i * 3.8, 3, 1.6), gold)
			ci.draw_rect(Rect2(33, 18, 34, 34), dark)
			ci.draw_rect(Rect2(33, 18, 34, 34), soft, false, 1.0)
			ci.draw_rect(Rect2(40, 25, 20, 20), Color(edge, 0.25))
			ci.draw_rect(Rect2(40, 25, 20, 20), edge, false, 1.2)
			for i in 3:
				ci.draw_line(Vector2(43, 31 + i * 5), Vector2(57, 31 + i * 5), soft, 1.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(25, 10), Vector2(36, 10), Vector2(25, 21)]), edge)
		"motherboard":
			ci.draw_rect(Rect2(18, 4, 64, 62), body)
			ci.draw_rect(Rect2(18, 4, 64, 62), edge, false, 1.4)
			ci.draw_rect(Rect2(28, 12, 18, 18), dark)
			ci.draw_rect(Rect2(28, 12, 18, 18), edge, false, 1.0)
			ci.draw_rect(Rect2(32, 16, 10, 10), soft)
			for i in 4:
				ci.draw_rect(Rect2(56 + i * 5, 8, 2.6, 28), dark)
				ci.draw_rect(Rect2(56 + i * 5, 8, 2.6, 28), soft, false, 0.6)
			for i in 3:
				ci.draw_rect(Rect2(22, 10 + i * 7, 4, 5), dark)
				ci.draw_rect(Rect2(22, 10 + i * 7, 4, 5), edge, false, 0.6)
			ci.draw_line(Vector2(30, 34), Vector2(30, 40), soft, 1.0)
			ci.draw_line(Vector2(30, 40), Vector2(60, 40), soft, 1.0)
			ci.draw_line(Vector2(60, 40), Vector2(60, 36), soft, 1.0)
			ci.draw_rect(Rect2(22, 44, 56, 4), dark)
			ci.draw_rect(Rect2(22, 44, 56, 4), edge, false, 0.8)
			ci.draw_rect(Rect2(22, 52, 56, 4), dark)
			ci.draw_rect(Rect2(22, 52, 56, 4), soft, false, 0.8)
			ci.draw_rect(Rect2(66, 59, 12, 4), dark)
			ci.draw_rect(Rect2(21, 60, 4, 3), edge)
		"gpu":
			ci.draw_rect(Rect2(4, 18, 4, 36), edge)
			ci.draw_rect(Rect2(8, 20, 86, 30), body)
			ci.draw_rect(Rect2(8, 20, 86, 30), edge, false, 1.4)
			for i in 2:
				var c := Vector2(32 + i * 32, 35)
				ci.draw_circle(c, 12, dark)
				ci.draw_arc(c, 12, 0, TAU, 28, edge, 1.0)
				for b in 5:
					var a := b * TAU / 5.0
					ci.draw_arc(c, 8, a, a + 1.0, 8, soft, 3.0)
				ci.draw_circle(c, 2, edge)
			ci.draw_rect(Rect2(84, 24, 8, 22), dark)
			ci.draw_line(Vector2(86, 28), Vector2(90, 28), soft, 1.0)
			ci.draw_line(Vector2(86, 32), Vector2(90, 32), soft, 1.0)
			ci.draw_rect(Rect2(14, 50, 50, 4), gold)
			for i in 10:
				ci.draw_line(Vector2(18 + i * 5, 50), Vector2(18 + i * 5, 54), dark, 1.0)
			ci.draw_rect(Rect2(66, 50, 6, 3), edge)
		"ram":
			ci.draw_rect(Rect2(6, 22, 88, 24), body)
			ci.draw_rect(Rect2(6, 22, 88, 24), edge, false, 1.4)
			for i in 6:
				ci.draw_rect(Rect2(12 + i * 13, 26, 10, 10), dark)
				ci.draw_rect(Rect2(12 + i * 13, 26, 10, 10), soft, false, 0.7)
			ci.draw_rect(Rect2(8, 39, 84, 3), Color(edge, 0.5 * alpha))
			for i in 28:
				ci.draw_rect(Rect2(8 + i * 3, 46, 1.6, 4), gold)
			ci.draw_rect(Rect2(50, 46, 3, 5), dark)
			ci.draw_rect(Rect2(6, 18, 6, 4), edge)
			ci.draw_rect(Rect2(88, 18, 6, 4), edge)
		"storage":
			var nm := String(it.get("name", "")).to_lower()
			var is_hdd := nm.contains("hdd") or nm.contains("hard") or nm.contains("barra") or nm.contains("rpm")
			if is_hdd:
				ci.draw_rect(Rect2(20, 6, 60, 58), body)
				ci.draw_rect(Rect2(20, 6, 60, 58), edge, false, 1.4)
				var c := Vector2(48, 32)
				ci.draw_circle(c, 21, dark)
				ci.draw_arc(c, 21, 0, TAU, 32, soft, 1.0)
				ci.draw_arc(c, 13, 0, TAU, 28, soft, 1.0)
				ci.draw_circle(c, 4, edge)
				ci.draw_line(Vector2(70, 56), c + Vector2(6, 4), cream, 1.6)
				ci.draw_circle(Vector2(70, 56), 2.2, edge)
				ci.draw_rect(Rect2(28, 58, 40, 4), gold)
			else:
				ci.draw_rect(Rect2(12, 14, 76, 40), body)
				ci.draw_rect(Rect2(12, 14, 76, 40), edge, false, 1.4)
				for i in 3:
					ci.draw_rect(Rect2(20 + i * 18, 20, 14, 14), dark)
					ci.draw_rect(Rect2(20 + i * 18, 20, 14, 14), soft, false, 0.8)
				ci.draw_rect(Rect2(20, 40, 40, 8), Color(edge, 0.25 * alpha))
				ci.draw_rect(Rect2(88, 22, 6, 24), gold)
				for i in 5:
					ci.draw_line(Vector2(89, 25 + i * 4.5), Vector2(93, 25 + i * 4.5), dark, 1.0)
		_:
			ci.draw_rect(Rect2(20, 10, 60, 50), body)
			ci.draw_rect(Rect2(20, 10, 60, 50), edge, false, 1.4)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
