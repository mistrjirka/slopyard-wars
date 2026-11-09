extends Resource
## All authored character behavior lives in resources/characters.tres.
@export var id: StringName
@export var display_name: String
@export var tagline: String
@export_multiline var system_prompt: String
@export_multiline var backstory: String
@export_multiline var texting_style: String
@export_multiline var current_situation: String
@export var dialogue_examples: PackedStringArray = []
@export var conversation_hooks: PackedStringArray = []
@export var reply_delay_seconds := Vector2(3, 8)
@export var buyer_interest_delay_minutes := Vector2(8, 18)
@export_range(1.0, 3.0) var maximum_asking_ratio := 1.65
@export_range(2, 6) var patience_limit := 2
@export_range(0.1, 0.8) var lowball_fraction := 0.55
@export var block_on_lowball := true
@export_multiline var personal_boundaries: String
@export var sensitive_topics: PackedStringArray = []
@export var requires_conversation := false
@export var rapport_keywords: PackedStringArray = []
@export_multiline var rapport_invitation := "Before we talk prices, ask me a little about my day."
@export_multiline var patience_warning := "Easy. Repeated silly offers, insults or copy-paste messages and I'll stop dealing with you."
@export_multiline var refusal_line := "I'm done with this conversation. Please find another seller."
@export var refusal_by_reason: Dictionary = {} # hobby, lowball, conduct; offline/invalid-response fallbacks.
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
