extends RefCounted
## Player-facing match choices.
const BUDGETS: Array = [600, 800, 1000, 1500, 2500, 5000]
const OBJECTIVES := {
	"Balanced": "Equal weight on CPU, GPU, RAM and storage.",
	"CPU": "CPU counts 45%. Pick a strong processor and tune it.",
	"GPU": "Graphics counts 45%. A discrete GPU pays off.",
	"Storage": "Storage counts 50%. Fast drives win this one.",
}
const STEPS: Array = [
	["1  EXPLORE", "WASD / arrows to walk. E uses doors, your car, contacts and town activities. Pray at Lucky Square for a blessing."],
	["2  PHONE", "P opens the phone. Filter parts and sort prices in Browse; use the value guide in Sell. Agree price, place AND time in chat."],
	["3  MEET", "Walk outside, E to enter the car, then drive yourself. Park and walk to the contact at the agreed time."],
	["4  BUILD / SELL", "B at your home workbench opens assembly. Sell spare parts on the phone; NPC buyers will haggle."],
	["5  TUNE", "Tune CPU, GPU and RAM. Check headroom, condition and failure odds. Risky tests can destroy parts; surviving causes wear."],
	["6  BENCH", "One day, 08:00–22:00. Aim to head home by 19:00 for assembly and tuning. Finish early whenever your rig is ready."],
]
