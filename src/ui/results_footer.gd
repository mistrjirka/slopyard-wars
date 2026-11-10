extends PanelContainer

const K = preload("res://src/ui/ui_kit.gd")

@onready var _solo: Label = $Content/SoloHigh
@onready var _note: Label = $Content/Note
@onready var _burnt: Label = $Content/Burnt

func _ready() -> void:
	pass

func configure(st: Dictionary, me: Dictionary) -> void:
	if st.mode == "solo":
		var total: int = int(me.get("score", {}).get("total", 0))
		var best: int = int(me.get("best", 0))
		_solo.text = "Solo high score for objective %s: %d%s" % [st.objective, maxi(best, total), "  - NEW BEST!" if total >= best and total > 0 else ""]
		_solo.visible = true
	else:
		_solo.visible = false
	_note.text = "Scores use fictional benchmark units. The total is weighted by the objective (%s)." % st.objective
	var destroyed: Array = me.get("destroyed", [])
	if not destroyed.is_empty():
		_burnt.text = "You burnt out: " + ", ".join(destroyed)
		_burnt.visible = true
	else:
		_burnt.visible = false
