extends PanelContainer

const K = preload("res://src/ui/ui_kit.gd")

@onready var _solo: Label = $Content/SoloHigh
@onready var _note: Label = $Content/Note
@onready var _burnt: Label = $Content/Burnt

func _ready() -> void:
	pass

func configure(st: Dictionary, me: Dictionary) -> void:
	if st.get("assembly_test", false):
		_solo.text = "Assembly test: practice score only. Scores are not saved."
		_solo.visible = true
	elif st.mode == "solo":
		var total: int = int(me.get("score", {}).get("total", 0))
		var best: int = int(me.get("best", 0))
		_solo.text = "Local best · %s · $%d · %d day%s: %d%s" % [st.objective, st.budget, st.match_days, "" if st.match_days == 1 else "s", maxi(best, total), "  - NEW BEST!" if total > 0 and bool(me.get("new_best", false)) else ""]
		_solo.visible = true
	else:
		_solo.visible = false
	_note.text = "Scores use fictional benchmark units. Each category has diminishing returns; %s sets the weights. Improve weak parts or specialize for your objective." % st.objective
	var destroyed: Array = me.get("destroyed", [])
	if not destroyed.is_empty():
		_burnt.text = "You burnt out: " + ", ".join(destroyed)
		_burnt.visible = true
	else:
		_burnt.visible = false
