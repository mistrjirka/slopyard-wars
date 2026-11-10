@tool
extends Control
## Decorative part illustration; the menu hierarchy and layout live in its scene.
const K = preload("res://src/ui/ui_kit.gd")
const PartArt = preload("res://src/ui/part_art.gd")


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var categories: Array[String] = ["cpu", "gpu", "ram", "motherboard", "storage"]
	for i in categories.size():
		var category := categories[i]
		var transform := Transform2D(deg_to_rad(-6 + i * 3.0), Vector2(1.5, 1.5), 0.0, Vector2(size.x * (0.1 + 0.2 * i), 80 + (i % 2) * 14))
		PartArt.draw_part(self, transform, category, {"category": category, "name": "ssd"}, K.cat_color(category), 1.0)
