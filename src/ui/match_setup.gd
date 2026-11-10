extends RefCounted
## Player-facing match choices.
const BUDGETS: Array = [600, 800, 1000, 1500, 2500, 5000]
const OBJECTIVES := {
	"Balanced": "Equal weight on CPU, GPU, RAM and storage.",
	"CPU": "CPU counts 45%. Pick a strong processor and tune it.",
	"GPU": "Graphics counts 45%. A discrete GPU pays off.",
	"Storage": "Storage counts 50%. Fast drives win this one.",
}
