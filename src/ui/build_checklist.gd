extends PanelContainer
## Ownership and live buying progress only, not an assembly checklist.
const Entry = preload("res://src/ui/build_checklist_item.gd")
const Progress = preload("res://src/trading/part_progress.gd")
const RigRules = preload("res://src/workshop/rig_rules.gd")
var _phone_mode := false
@onready var _parts: GridContainer = $Box/Parts


func set_phone_mode(open: bool) -> void:
	if _phone_mode == open:
		return
	_phone_mode = open
	_parts.columns = 2 if open else 7
	_fit_size.call_deferred()


func _fit_size() -> void:
	size = Vector2(100 if _phone_mode else 270, get_combined_minimum_size().y)


func _ready() -> void:
	Game.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var player: Dictionary = Game.me()
	if player.is_empty():
		return
	var best: Dictionary = {}
	for part: Dictionary in Progress.tracked_parts(player, Game.state.listings):
		var category := str(part.item.category)
		if int(part.status) > int(best.get(category, {}).get("status", Progress.Status.MISSING)):
			best[category] = part
	if int(best.get("gpu", {}).get("status", Progress.Status.MISSING)) < Progress.Status.OWNED and RigRules.igpu_usable(player.get("installed", {})):
		best["gpu"] = {"status": Progress.Status.OWNED, "detail": "Owned: integrated CPU graphics"}
	for entry: Entry in $Box/Parts.get_children():
		var part: Dictionary = best.get(entry.category, {})
		entry.show_status(part.get("status", Progress.Status.MISSING), str(part.get("detail", "Missing")))
