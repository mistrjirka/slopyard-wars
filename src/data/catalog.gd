extends RefCounted
## Hardware resources, listing generation and counterparty definitions.
const Stats = preload("res://src/data/hardware_stats.gd")
const Characters = preload("res://src/data/characters.gd")
const PartDefinition = preload("res://src/data/part_definition.gd")

const CATEGORIES := ["case", "psu", "cpu", "motherboard", "gpu", "ram", "storage"]
## Definitions are Resources editable in resources/hardware.tres.
## cpu "gpu" stat = integrated graphics score. motherboard integrated=true means it has video outputs.
const PARTS: Array = preload("res://resources/hardware.tres").parts

const LOCATIONS := {
	"Harbor Flea Market": Vector2(220, 438), "Grease Alley": Vector2(276, 220),
	"Old Mill Garage": Vector2(718, 224), "Suburb Cul-de-sac": Vector2(790, 432),
	"Uni Dorm Row": Vector2(790, 590), "Scrapyard Gate": Vector2(84, 288),
	"Lakeside Storage": Vector2(930, 302),
}

const CONDITIONS := ["Lightly used.", "Used, well loved.", "Dusty but works.", "Pulled from a working office PC.", "Slightly scuffed, tested OK.", "Garage find, cleaned."]


static func blank_item() -> Dictionary:
	return {"id": 0, "name": "", "category": "", "price": 0, "cpu": 0.0, "gpu": 0.0, "ram": 0.0, "storage": 0.0,
		"socket": "", "memory": "", "watts": 0, "capacity": 0, "integrated": false, "seller": "", "personality": "",
		"description": "", "location": "", "pos": Vector2.ZERO, "status": "available", "buyer": 0, "form": ""}


static func spec_text(it: Dictionary, include_value_guide: bool = true) -> String:
	var bits: Array[String] = []
	match it.category:
		"case": bits.append("Fits %s boards" % ("ATX and mATX" if it.form == "ATX" else "mATX only"))
		"psu": bits.append("%dW" % it.capacity)
		"cpu":
			bits.append("Socket %s" % it.socket)
			bits.append("Rated CPU score %d" % it.cpu)
			bits.append("%dW" % it.watts)
			bits.append("integrated graphics (score %d)" % it.gpu if it.integrated else "no integrated graphics")
		"motherboard":
			bits.append("Socket %s, %s, %s" % [it.socket, it.memory, it.form])
			bits.append("video outputs" if it.integrated else "NO video outputs")
		"gpu": bits.append("Rated GPU score %d, %dW" % [it.gpu, it.watts])
		"ram": bits.append("%s, rated RAM score %d" % [it.memory, it.ram])
		"storage": bits.append("Rated storage score %d" % it.storage)
	bits.append(Stats.performance_text(it))
	if include_value_guide:
		bits.append(Stats.value_text(it))
	bits.append(str(it.get("buying_notes", "")))
	return " · ".join(bits)


static func build_listing(rng: RandomNumberGenerator, tpl: PartDefinition, id: int, contact: Resource = null) -> Dictionary:
	var it := blank_item()
	it.id = id
	it.category = tpl.category
	it.name = tpl.display_name
	for field in ["model_id", "manufacturer", "product_family", "buying_notes", "oc_potential", "voltage_limit", "thermal_load", "stock_failure_chance", "fire_base_chance", "fire_power_sensitivity", "support_quality", "stock_clock_mhz", "capacity_gb", "cores"]:
		it[field] = tpl.get(field)
	it["condition"] = rng.randi_range(tpl.condition_min, tpl.condition_max)
	it["reference_base"] = tpl.base_price
	for k in tpl.stats:
		it[k] = tpl.stats[k]
	for k in ["cpu", "gpu", "ram", "storage"]:
		it[k] = float(it[k])
	# Both sides of the market price the unit's actual condition. Bargains still
	# exist, but a worn listing no longer routinely costs pristine retail money.
	it.price = maxi(5, roundi(Stats.reference_price(it) * rng.randf_range(0.85, 1.20)))
	var s: Resource = contact if contact != null else Characters.pick(rng)
	it.seller = s.display_name
	it["character_id"] = str(s.id)
	it.personality = s.tagline
	it.location = s.meeting_places[0]
	it.pos = LOCATIONS[it.location] + Vector2(rng.randf_range(-35, 35), rng.randf_range(-30, 30))
	it.description = CONDITIONS[rng.randi() % CONDITIONS.size()]
	return it


## Returns Array of {tpl, anchor}. Anchors guarantee enough cheap compatible budget builds for every player.


static func initial_picks(rng: RandomNumberGenerator, players: int) -> Array:
	var picks: Array = []
	for k in 2 * players + 1:
		var socket: String = ["OX3", "OX4"][k % 2]
		var memory: String = "DDR3" if socket == "OX3" else "DDR4"
		picks.append({"tpl": _cheap(rng, "case", 70), "anchor": true})
		picks.append({"tpl": _cheap(rng, "psu", 75, {"min_cap": 350}), "anchor": true})
		picks.append({"tpl": _cheap(rng, "cpu", 110, {"socket": socket, "integrated": true}), "anchor": true})
		picks.append({"tpl": _cheap(rng, "motherboard", 85, {"socket": socket, "integrated": true}), "anchor": true})
		picks.append({"tpl": _cheap(rng, "ram", 55, {"memory": memory}), "anchor": true})
		picks.append({"tpl": _cheap(rng, "storage", 65), "anchor": true})
	# Higher-budget players also need complete upgrade paths, rather than a
	# random CPU with no matching board or memory anywhere in the initial stock.
	for socket: String in ["NX5", "LX7"]:
		picks.append({"tpl": _cheap(rng, "cpu", 420 if socket == "NX5" else 350, {"socket": socket, "integrated": true, "reliable": true}), "anchor": true})
		picks.append({"tpl": _cheap(rng, "motherboard", 180 if socket == "NX5" else 150, {"socket": socket}), "anchor": true})
		picks.append({"tpl": _cheap(rng, "ram", 250 if socket == "NX5" else 145, {"memory": "DDR5" if socket == "NX5" else "DDR4"}), "anchor": true})
	for t in PARTS:
		if rng.randf() < 0.5:
			picks.append({"tpl": t, "anchor": false})
	return picks


static func random_pick(rng: RandomNumberGenerator, category: String = "") -> PartDefinition:
	var pool: Array = []
	for t in PARTS:
		if category == "" or t.category == category:
			pool.append(t)
	return pool[rng.randi() % pool.size()]


static func _cheap(rng: RandomNumberGenerator, cat: String, max_price: int, f: Dictionary = {}) -> PartDefinition:
	var pool: Array = []
	for t in PARTS:
		if t.category != cat or t.base_price > max_price:
			continue
		var st: Dictionary = t.stats
		if f.has("socket") and st.get("socket", "") != f.socket:
			continue
		if f.has("memory") and st.get("memory", "") != f.memory:
			continue
		if f.has("integrated") and bool(st.get("integrated", false)) != f.integrated:
			continue
		if f.has("min_cap") and int(st.get("capacity", 0)) < f.min_cap:
			continue
		if f.get("reliable", false) and (t.stock_failure_chance > 0 or t.fire_base_chance > 0):
			continue
		pool.append(t)
	return pool[rng.randi() % pool.size()]
