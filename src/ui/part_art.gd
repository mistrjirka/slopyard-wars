extends Control
## Shared asset-backed part illustration for listings, inventory and assembly minigames.
const Art = preload("res://src/ui/art_library.gd")

var category := "cpu"
var item: Dictionary = {}
var dim := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func show_item(value: Dictionary, p_dim: bool = false) -> void:
	item = value
	category = str(item.get("category", "cpu"))
	dim = p_dim
	queue_redraw()


func _draw() -> void:
	var texture := Art.part(category, item, size.y >= 90)
	var scale_factor := minf(size.x / texture.get_width(), size.y / texture.get_height())
	var extent := texture.get_size() * scale_factor
	draw_texture_rect(texture, Rect2((size - extent) * 0.5, extent), false,
		Color(0.5, 0.5, 0.5) if dim else Color.WHITE)


## Assembly uses the same dimensions for drawing, picking, and alignment outlines.
static func drawing_size(cat: String, value: Dictionary, scale_factor: float = 1.0) -> Vector2:
	var texture := Art.part(cat, value, true)
	return texture.get_size() * minf(100.0 / texture.get_width(), 70.0 / texture.get_height()) * scale_factor


static func draw_part(canvas: CanvasItem, transform: Transform2D, cat: String,
		value: Dictionary, _tint: Color, alpha: float) -> void:
	var texture := Art.part(cat, value, true)
	var extent := drawing_size(cat, value)
	canvas.draw_set_transform_matrix(transform)
	canvas.draw_texture_rect(texture, Rect2(-extent * 0.5, extent), false, Color(1, 1, 1, alpha))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
