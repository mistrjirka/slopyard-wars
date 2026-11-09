extends Resource
## Authored encounter. Mechanics are implemented by ActivitySystem, never by resource scripts.
@export var id: StringName
@export var display_name: String
@export var map_label: String
@export_enum("town", "home") var area := "town"
@export var position := Vector2.ZERO
@export_range(12, 48) var radius := 27.0
@export var art_key: String
@export var art_size := Vector2(40, 40)
## Optional existing decoration layered over the activity prop (e.g. Lucky on his shrine).
@export var overlay_art_key: String
@export var overlay_art_size := Vector2(32, 48)
@export_enum("lucky", "salvage", "clean", "cooling", "advice") var kind := "advice"
@export_multiline var description: String
@export var action_label: String
## Optional named preparation, shown in the workshop after purchase.
@export var reward_name: String
@export_range(0, 500) var cash_cost := 0
@export_range(0, 120) var minutes_cost := 0
@export_range(0, 10) var uses_per_day := 0
@export_range(0, 1440) var cooldown_minutes := 0
@export var once_per_run := false
@export_range(0, 100) var strength := 0
@export var loot_models: PackedStringArray = []
@export var loot_condition := Vector2i(45, 70)
@export var result_lines: PackedStringArray = []
