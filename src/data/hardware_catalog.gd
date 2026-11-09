extends Resource
## Expand this array in the Inspector to tune parts without editing game logic.
const PartDefinition = preload("res://src/data/part_definition.gd")
@export var parts: Array[PartDefinition] = []
