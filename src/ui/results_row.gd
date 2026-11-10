extends VBoxContainer

const K = preload("res://src/ui/ui_kit.gd")

const CATS4: Array = ["cpu", "gpu", "ram", "storage"]
const LABELS := {"cpu": "CPU", "gpu": "GPU", "ram": "RAM", "storage": "STORAGE"}

@onready var card: PanelContainer = $Card
@onready var rank_label: Label = $Card/RowH/Left/Rank
@onready var name_label: Label = $Card/RowH/Left/Name
@onready var total_label: Label = $Card/RowH/Left/Total
@onready var cash_label: Label = $Card/RowH/Left/Cash
@onready var issue_label: Label = $Issue

var bars: Dictionary = {}

func _ready() -> void:
	bars = {
		"cpu": [$Card/RowH/Bars/CpuRow/CpuBar, $Card/RowH/Bars/CpuRow/CpuVal],
		"gpu": [$Card/RowH/Bars/GpuRow/GpuBar, $Card/RowH/Bars/GpuRow/GpuVal],
		"ram": [$Card/RowH/Bars/RamRow/RamBar, $Card/RowH/Bars/RamRow/RamVal],
		"storage": [$Card/RowH/Bars/StorageRow/StorageBar, $Card/RowH/Bars/StorageRow/StorageVal],
	}

func configure(rank: int, player_name: String, mine: bool, cash_text: String, sc: Dictionary, maxes: Dictionary, valid: bool, issues: Array) -> void:
	card.theme_type_variation = "CardHot" if mine else "Card"
	rank_label.text = "#%d" % rank
	name_label.text = player_name + ("  (YOU)" if mine else "")
	total_label.text = "..."
	cash_label.text = "Cash left %s" % cash_text
	for c in CATS4:
		var bar: ProgressBar = bars[c][0]
		var val: Label = bars[c][1]
		bar.max_value = maxes[c]
		bar.value = 0
		val.text = "0"
		bars[c].append(int(sc.get(c, 0)))
	if not valid:
		issue_label.text = "Rig invalid - total score 0. " + (String(issues[0]) if not issues.is_empty() else "")
		issue_label.visible = true
	else:
		issue_label.visible = false
