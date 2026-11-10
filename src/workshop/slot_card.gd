extends PanelContainer
## Reusable bench slot card. Data is filled by bench_view.gd.

const K = preload("res://src/ui/ui_kit.gd")

@onready var art: Control = $Row/Art
@onready var category_label: Label = $Row/TextCol/CategoryLabel
@onready var name_label: Label = $Row/TextCol/NameLabel
@onready var spec_label: Label = $Row/TextCol/SpecLabel
@onready var oc_label: Label = $Row/TextCol/OcLabel
@onready var ok_pill: PanelContainer = $Row/OkPill
@onready var penalty_label: Label = $Row/TextCol/PenaltyLabel
@onready var reinstall_button: Button = $Row/TextCol/Reinstall


func _ready() -> void:
	K.set_pill(ok_pill, "OK", K.LIME)
	oc_label.visible = false