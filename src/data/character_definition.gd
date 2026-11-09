extends Resource
## All authored character behavior lives in resources/characters.tres.
@export var id: StringName
@export var display_name: String
@export var tagline: String
@export_multiline var system_prompt: String
@export_enum("Novice", "Hobbyist", "Expert") var technical_knowledge := 0
@export var favorite_topics: PackedStringArray = []
@export var pet_peeves: PackedStringArray = []
@export_range(0.5, 1.0) var price_floor_fraction := 0.85
@export_range(0.0, 1.0) var counter_bias := 0.4
@export var buyer_budget_range := Vector2(1.05, 1.4)
@export var meeting_places: PackedStringArray = []
@export var hours: Array[Vector2i] = [Vector2i(9, 18)]
@export var schedule_note: String
@export_multiline var greeting: String
@export_multiline var price_accept: String
@export_multiline var price_counter: String
@export_multiline var technical_reply: String
@export_multiline var buyer_opening: String
@export var smalltalk: PackedStringArray = []
