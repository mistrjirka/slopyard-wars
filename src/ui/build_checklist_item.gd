extends VBoxContainer
## One compact, non-interactive component status in the world HUD.
const Art = preload("res://src/ui/art_library.gd")
const Progress = preload("res://src/trading/part_progress.gd")

@export_enum("case", "motherboard", "cpu", "ram", "gpu", "storage", "psu") var category := "case"
@onready var _icon: TextureRect = $Icon
@onready var _status: Label = $Status


func _ready() -> void:
	_icon.texture = Art.part(category, {"name": category})
	$Name.text = {"motherboard": "MB", "storage": "DISK"}.get(category, category.to_upper())
	show_status(Progress.Status.MISSING, "Missing")


func show_status(status: Progress.Status, detail: String) -> void:
	var color := Progress.color(status)
	_status.text = {Progress.Status.MISSING: "–", Progress.Status.OWNED: "✓", Progress.Status.NEGOTIATING: "…", Progress.Status.AGREED: "↔"}[status]
	_status.add_theme_color_override("font_color", color)
	$Name.add_theme_color_override("font_color", color)
	_icon.modulate = Color(0.4, 0.4, 0.4) if status == Progress.Status.MISSING else (color.lightened(0.35) if status in [Progress.Status.OWNED, Progress.Status.AGREED] else Color.WHITE)
	tooltip_text = category.capitalize() + " · " + detail
