extends VBoxContainer
## One compact, non-interactive component status in the world HUD.
const Art = preload("res://src/ui/art_library.gd")
const K = preload("res://src/ui/ui_kit.gd")
enum Status { MISSING, OWNED, NEGOTIATING, AGREED }

@export_enum("case", "motherboard", "cpu", "ram", "gpu", "storage", "psu") var category := "case"
@onready var _icon: TextureRect = $Icon
@onready var _status: Label = $Status


func _ready() -> void:
	_icon.texture = Art.part(category, {"name": category})
	$Name.text = {"motherboard": "MB", "storage": "DISK"}.get(category, category.to_upper())
	show_status(Status.MISSING, "Missing")


func show_status(status: Status, detail: String) -> void:
	var color: Color = {Status.MISSING: Color("8590a4"), Status.OWNED: Color("60d887"),
		Status.NEGOTIATING: K.ORANGE, Status.AGREED: Color("b9e5ae")}[status]
	_status.text = {Status.MISSING: "–", Status.OWNED: "✓", Status.NEGOTIATING: "…", Status.AGREED: "↔"}[status]
	_status.add_theme_color_override("font_color", color)
	$Name.add_theme_color_override("font_color", color)
	_icon.modulate = Color(0.4, 0.4, 0.4) if status == Status.MISSING else (color.lightened(0.35) if status in [Status.OWNED, Status.AGREED] else Color.WHITE)
	tooltip_text = category.capitalize() + " · " + detail
