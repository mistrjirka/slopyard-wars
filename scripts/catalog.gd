extends RefCounted
## Fictional hardware catalogue, sellers, compatibility and scoring rules (pure data/logic, no state).

const CATEGORIES := ["case", "psu", "cpu", "motherboard", "gpu", "ram", "storage"]
const TUNABLE := ["cpu", "gpu", "ram"]
const HOME := Vector2(500, 300)
const MAX_SAFE_VOLTAGE := 1.40
const REF := {"cpu": 6000.0, "gpu": 6000.0, "ram": 4000.0, "storage": 4000.0}
const WEIGHTS := {
	"Balanced": {"cpu": 0.25, "gpu": 0.25, "ram": 0.25, "storage": 0.25},
	"CPU": {"cpu": 0.45, "gpu": 0.15, "ram": 0.20, "storage": 0.20},
	"GPU": {"cpu": 0.15, "gpu": 0.45, "ram": 0.20, "storage": 0.20},
	"Storage": {"cpu": 0.15, "gpu": 0.15, "ram": 0.20, "storage": 0.50},
}

## [category, name, base price, stats]. Sockets OX3/OX4/NX5, memory DDR3/DDR4/DDR5, forms ATX/mATX.
## cpu "gpu" stat = integrated graphics score. motherboard integrated=true means it has video outputs.
const T := [
	["case", "Tin Can mATX", 12, {"form": "mATX"}],
	["case", "Boxcar mATX Mini", 15, {"form": "mATX"}],
	["case", "Boxcar ATX Tower", 25, {"form": "ATX"}],
	["case", "Rackmate ATX", 45, {"form": "ATX"}],
	["case", "Glasshouse ATX RGB", 60, {"form": "ATX"}],
	["psu", "Ampere 350W", 20, {"capacity": 350}],
	["psu", "Ampere 450W", 30, {"capacity": 450}],
	["psu", "Wattson 550W Bronze", 45, {"capacity": 550}],
	["psu", "Wattson 650W Gold", 70, {"capacity": 650}],
	["psu", "Wattson 750W Gold", 95, {"capacity": 750}],
	["psu", "Titanforge 850W", 130, {"capacity": 850}],
	["psu", "Titanforge 1000W", 180, {"capacity": 1000}],
	["cpu", "Kestrel K3-2200", 28, {"cpu": 900, "gpu": 150, "socket": "OX3", "watts": 65, "integrated": true}],
	["cpu", "Kestrel K3-3400", 55, {"cpu": 1500, "gpu": 250, "socket": "OX3", "watts": 84, "integrated": true}],
	["cpu", "Kestrel K3-4700X", 95, {"cpu": 2300, "socket": "OX3", "watts": 95}],
	["cpu", "Nimbus N4-1200", 60, {"cpu": 2200, "gpu": 450, "socket": "OX4", "watts": 65, "integrated": true}],
	["cpu", "Nimbus N4-1500", 105, {"cpu": 3300, "socket": "OX4", "watts": 90}],
	["cpu", "Nimbus N4-2700X", 175, {"cpu": 4600, "socket": "OX4", "watts": 105}],
	["cpu", "Nimbus N4-3900", 260, {"cpu": 6000, "socket": "OX4", "watts": 125}],
	["cpu", "Helix H5-5400", 210, {"cpu": 5400, "gpu": 900, "socket": "NX5", "watts": 65, "integrated": true}],
	["cpu", "Helix H5-7700", 330, {"cpu": 7500, "gpu": 1000, "socket": "NX5", "watts": 105, "integrated": true}],
	["cpu", "Helix H5-9900X", 480, {"cpu": 9400, "socket": "NX5", "watts": 140}],
	["motherboard", "Voltra V3-A55 (mATX)", 30, {"socket": "OX3", "memory": "DDR3", "form": "mATX", "watts": 25, "integrated": true}],
	["motherboard", "Voltra V3-Z77 (ATX)", 55, {"socket": "OX3", "memory": "DDR3", "form": "ATX", "watts": 30, "integrated": true}],
	["motherboard", "Voltra V3-X79 Pro (ATX, no video out)", 80, {"socket": "OX3", "memory": "DDR3", "form": "ATX", "watts": 35}],
	["motherboard", "Voltra V4-B250 (mATX)", 60, {"socket": "OX4", "memory": "DDR4", "form": "mATX", "watts": 25, "integrated": true}],
	["motherboard", "Voltra V4-H370 (ATX)", 95, {"socket": "OX4", "memory": "DDR4", "form": "ATX", "watts": 30, "integrated": true}],
	["motherboard", "Voltra V4-Z390 Ultra (ATX)", 150, {"socket": "OX4", "memory": "DDR4", "form": "ATX", "watts": 35, "integrated": true}],
	["motherboard", "Voltra V5-B650 (mATX)", 140, {"socket": "NX5", "memory": "DDR5", "form": "mATX", "watts": 30, "integrated": true}],
	["motherboard", "Voltra V5-X670 Titan (ATX)", 260, {"socket": "NX5", "memory": "DDR5", "form": "ATX", "watts": 40, "integrated": true}],
	["ram", "Quill 4GB DDR3-1333", 12, {"ram": 400, "memory": "DDR3", "watts": 5}],
	["ram", "Quill 8GB DDR3-1600", 22, {"ram": 700, "memory": "DDR3", "watts": 6}],
	["ram", "Quill 16GB DDR3-1866", 40, {"ram": 1000, "memory": "DDR3", "watts": 7}],
	["ram", "Quill 8GB DDR4-2400", 30, {"ram": 1400, "memory": "DDR4", "watts": 6}],
	["ram", "Quill 16GB DDR4-3000", 55, {"ram": 2200, "memory": "DDR4", "watts": 7}],
	["ram", "Quill 32GB DDR4-3600", 100, {"ram": 3400, "memory": "DDR4", "watts": 8}],
	["ram", "Quill 16GB DDR5-5200", 90, {"ram": 3800, "memory": "DDR5", "watts": 8}],
	["ram", "Quill 32GB DDR5-6000", 160, {"ram": 5200, "memory": "DDR5", "watts": 9}],
	["ram", "Quill 32GB DDR5-7200", 230, {"ram": 6400, "memory": "DDR5", "watts": 10}],
	["gpu", "Pixelon P210", 25, {"gpu": 600, "watts": 40}],
	["gpu", "Pixelon P730", 45, {"gpu": 1100, "watts": 75}],
	["gpu", "Arcadia A470", 80, {"gpu": 1900, "watts": 110}],
	["gpu", "Arcadia A580", 120, {"gpu": 2600, "watts": 130}],
	["gpu", "Arcadia A1060", 190, {"gpu": 3600, "watts": 150}],
	["gpu", "Zephyr Z1660", 260, {"gpu": 4600, "watts": 170}],
	["gpu", "Zephyr Z2070", 380, {"gpu": 6000, "watts": 215}],
	["gpu", "Zephyr Z3080", 520, {"gpu": 8000, "watts": 300}],
	["storage", "Spindle 500GB HDD", 14, {"storage": 150, "watts": 6}],
	["storage", "Spindle 1TB HDD 7200rpm", 24, {"storage": 250, "watts": 7}],
	["storage", "Spindle 2TB HDD", 38, {"storage": 300, "watts": 8}],
	["storage", "Flashy 120GB SATA SSD", 18, {"storage": 700, "watts": 3}],
	["storage", "Flashy 480GB SATA SSD", 35, {"storage": 1100, "watts": 3}],
	["storage", "Flashy 1TB SATA SSD", 60, {"storage": 1400, "watts": 3}],
	["storage", "Bolt 500GB NVMe", 55, {"storage": 2400, "watts": 5}],
	["storage", "Bolt 1TB NVMe Gen4", 95, {"storage": 4200, "watts": 7}],
	["storage", "Bolt 2TB NVMe Gen5", 180, {"storage": 6500, "watts": 9}],
]

const LOCATIONS := {
	"Harbor Flea Market": Vector2(170, 440), "Grease Alley": Vector2(330, 170),
	"Old Mill Garage": Vector2(780, 130), "Suburb Cul-de-sac": Vector2(850, 420),
	"Uni Dorm Row": Vector2(600, 520), "Scrapyard Gate": Vector2(120, 120),
	"Lakeside Storage": Vector2(930, 260),
}

## floor = lowest accepted fraction of asking price (jittered per listing), patience = rejected offers tolerated,
## mix = how far a counter-offer sits between floor and asking price.
const PERSONALITIES := {
	"Friendly": {"floor": 0.86, "patience": 4, "mix": 0.3, "quirk": "warm, calls everyone buddy and over-shares each part's backstory"},
	"Stubborn": {"floor": 0.97, "patience": 2, "mix": 1.0, "quirk": "refuses to haggle on principle, quotes forum posts, curt"},
	"Shady": {"floor": 0.78, "patience": 2, "mix": 0.4, "quirk": "vague about the item's history, says 'trust me' too often, hints things fell off a truck"},
	"Haggler": {"floor": 0.80, "patience": 5, "mix": 0.5, "quirk": "adores bargaining and talks like an auctioneer"},
	"Desperate": {"floor": 0.72, "patience": 5, "mix": 0.2, "quirk": "is moving out tomorrow and needs cash fast, a bit pitiful"},
	"Nerdy": {"floor": 0.90, "patience": 4, "mix": 0.6, "quirk": "lectures about benchmarks, voltages and trivia, loves the hardware"},
}

const SELLERS := [
	{"name": "Sunny Dave", "personality": "Friendly", "location": "Suburb Cul-de-sac"},
	{"name": "Granite Greta", "personality": "Stubborn", "location": "Old Mill Garage"},
	{"name": "Slick Vic", "personality": "Shady", "location": "Grease Alley"},
	{"name": "Haggle Hank", "personality": "Haggler", "location": "Harbor Flea Market"},
	{"name": "Desperate Dana", "personality": "Desperate", "location": "Uni Dorm Row"},
	{"name": "Professor Pixel", "personality": "Nerdy", "location": "Lakeside Storage"},
	{"name": "Gentle Gus", "personality": "Friendly", "location": "Harbor Flea Market"},
	{"name": "Stone Sally", "personality": "Stubborn", "location": "Scrapyard Gate"},
	{"name": "Fast Eddie", "personality": "Shady", "location": "Scrapyard Gate"},
	{"name": "Bargain Bella", "personality": "Haggler", "location": "Lakeside Storage"},
	{"name": "Broke Brandon", "personality": "Desperate", "location": "Grease Alley"},
	{"name": "Benchmark Bea", "personality": "Nerdy", "location": "Uni Dorm Row"},
]

const CONDITIONS := ["Lightly used.", "Used, well loved.", "Dusty but works.", "Pulled from a working office PC.", "Slightly scuffed, tested OK.", "Garage find, cleaned."]


static func blank_item() -> Dictionary:
	return {"id": 0, "name": "", "category": "", "price": 0, "cpu": 0.0, "gpu": 0.0, "ram": 0.0, "storage": 0.0,
		"socket": "", "memory": "", "watts": 0, "capacity": 0, "integrated": false, "seller": "", "personality": "",
		"description": "", "location": "", "pos": Vector2.ZERO, "status": "available", "buyer": 0, "form": ""}


static func spec_text(it: Dictionary) -> String:
	var bits: Array[String] = []
	match it.category:
		"case": bits.append("Fits %s boards" % ("ATX and mATX" if it.form == "ATX" else "mATX only"))
		"psu": bits.append("%dW" % it.capacity)
		"cpu":
			bits.append("Socket %s" % it.socket)
			bits.append("CPU score %d" % it.cpu)
			bits.append("%dW" % it.watts)
			bits.append("integrated graphics (score %d)" % it.gpu if it.integrated else "no integrated graphics")
		"motherboard":
			bits.append("Socket %s, %s, %s" % [it.socket, it.memory, it.form])
			bits.append("video outputs" if it.integrated else "NO video outputs")
		"gpu": bits.append("GPU score %d, %dW" % [it.gpu, it.watts])
		"ram": bits.append("%s, RAM score %d" % [it.memory, it.ram])
		"storage": bits.append("Storage score %d" % it.storage)
	return ", ".join(bits)


static func build_listing(rng: RandomNumberGenerator, tpl: Array, id: int) -> Dictionary:
	var it := blank_item()
	it.id = id
	it.category = tpl[0]
	it.name = tpl[1]
	for k in tpl[3]:
		it[k] = tpl[3][k]
	for k in ["cpu", "gpu", "ram", "storage"]:
		it[k] = float(it[k])
	it.price = maxi(5, int(round(tpl[2] * rng.randf_range(0.7, 1.3))))
	var s: Dictionary = SELLERS[rng.randi() % SELLERS.size()]
	it.seller = s.name
	it.personality = s.personality
	it.location = s.location
	it.pos = LOCATIONS[s.location] + Vector2(rng.randf_range(-35, 35), rng.randf_range(-30, 30))
	it.description = CONDITIONS[rng.randi() % CONDITIONS.size()]
	return it


## Returns Array of {tpl, anchor}. Anchors guarantee enough cheap compatible budget builds for every player.
static func initial_picks(rng: RandomNumberGenerator, players: int) -> Array:
	var picks: Array = []
	for k in 2 * players + 1:
		var socket: String = ["OX3", "OX4"][k % 2]
		var memory: String = "DDR3" if socket == "OX3" else "DDR4"
		picks.append({"tpl": _cheap(rng, "case", 30), "anchor": true})
		picks.append({"tpl": _cheap(rng, "psu", 35, {"min_cap": 350}), "anchor": true})
		picks.append({"tpl": _cheap(rng, "cpu", 110, {"socket": socket, "integrated": true}), "anchor": true})
		picks.append({"tpl": _cheap(rng, "motherboard", 70, {"socket": socket, "integrated": true}), "anchor": true})
		picks.append({"tpl": _cheap(rng, "ram", 40, {"memory": memory}), "anchor": true})
		picks.append({"tpl": _cheap(rng, "storage", 40), "anchor": true})
	for t in T:
		if rng.randf() < 0.5:
			picks.append({"tpl": t, "anchor": false})
	return picks


static func random_pick(rng: RandomNumberGenerator, category: String = "") -> Array:
	var pool: Array = []
	for t in T:
		if category == "" or t[0] == category:
			pool.append(t)
	return pool[rng.randi() % pool.size()]


static func _cheap(rng: RandomNumberGenerator, cat: String, max_price: int, f: Dictionary = {}) -> Array:
	var pool: Array = []
	for t in T:
		if t[0] != cat or t[2] > max_price:
			continue
		var st: Dictionary = t[3]
		if f.has("socket") and st.get("socket", "") != f.socket: continue
		if f.has("memory") and st.get("memory", "") != f.memory: continue
		if f.has("integrated") and bool(st.get("integrated", false)) != f.integrated: continue
		if f.has("min_cap") and int(st.get("capacity", 0)) < f.min_cap: continue
		pool.append(t)
	return pool[rng.randi() % pool.size()]


## Reason string if `item` cannot be installed next to `installed` (category->item), "" when compatible.
## `installed` must NOT contain item's own category (it is being replaced).
static func compat(item: Dictionary, installed: Dictionary) -> String:
	var mb: Dictionary = installed.get("motherboard", {})
	var cs: Dictionary = installed.get("case", {})
	match item.get("category", ""):
		"case":
			if not mb.is_empty() and mb.form == "ATX" and item.form == "mATX":
				return "This mATX case cannot fit your ATX motherboard"
		"motherboard":
			if cs.is_empty(): return "Install a case first"
			if item.form == "ATX" and cs.form == "mATX": return "ATX motherboard does not fit your mATX case"
			var cpu: Dictionary = installed.get("cpu", {})
			if not cpu.is_empty() and cpu.socket != item.socket:
				return "Board socket %s does not match installed CPU socket %s" % [item.socket, cpu.socket]
			var ram: Dictionary = installed.get("ram", {})
			if not ram.is_empty() and ram.memory != item.memory:
				return "Board takes %s but installed RAM is %s" % [item.memory, ram.memory]
		"psu":
			if cs.is_empty(): return "Install a case first"
		"cpu", "ram", "gpu", "storage":
			if cs.is_empty(): return "Install a case first"
			if mb.is_empty(): return "Install a motherboard first"
			if item.category == "cpu" and item.socket != mb.socket:
				return "CPU socket %s does not match motherboard socket %s" % [item.socket, mb.socket]
			if item.category == "ram" and item.memory != mb.memory:
				return "RAM is %s but motherboard needs %s" % [item.memory, mb.memory]
		_:
			return "Unknown part category"
	return ""


static func igpu_usable(installed: Dictionary) -> bool:
	var cpu: Dictionary = installed.get("cpu", {})
	var mb: Dictionary = installed.get("motherboard", {})
	return not cpu.is_empty() and not mb.is_empty() and cpu.integrated and mb.integrated


static func tune_of(tuning: Dictionary, cat: String) -> Dictionary:
	var t: Dictionary = tuning.get(cat, {})
	return {"clock": float(t.get("clock", 1.0)), "voltage": float(t.get("voltage", 1.0))}


static func stable_clock(voltage: float) -> float:
	return 1.0 + (voltage - 1.0) * 1.3


## Score multiplier for an overclock setting (1.0 stock).
static func multiplier(clock: float, voltage: float) -> float:
	var m := 1.0 + (clock - 1.0) * 0.9
	var excess := clock - stable_clock(voltage)
	if excess > 0.0005:
		m *= maxf(0.25, 1.0 - excess * 5.0)
	return m


static func power_draw(installed: Dictionary, tuning: Dictionary) -> int:
	var w := 20.0  # fans/misc
	for cat in installed:
		var it: Dictionary = installed[cat]
		var x := float(it.watts)
		if cat in TUNABLE:
			var t := tune_of(tuning, cat)
			x *= t.clock * t.voltage
		w += x
	return int(ceil(w))


static func issues(installed: Dictionary, tuning: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for c in ["case", "motherboard", "cpu", "ram", "storage", "psu"]:
		if not installed.has(c):
			out.append("Missing %s" % c)
	if not installed.has("gpu") and not igpu_usable(installed):
		out.append("Missing graphics: add a GPU, or a CPU with integrated graphics on a motherboard with video outputs")
	for c in installed:
		var rest: Dictionary = installed.duplicate()
		rest.erase(c)
		var r := compat(installed[c], rest)
		if r != "" and not r.begins_with("Install a"):
			out.append(r)
	if installed.has("psu"):
		var need := power_draw(installed, tuning)
		if need > int(installed.psu.capacity):
			out.append("PSU overloaded: rig draws about %dW but PSU supplies %dW" % [need, installed.psu.capacity])
	return out


static func score(installed: Dictionary, tuning: Dictionary, objective: String) -> Dictionary:
	var cpu_t := tune_of(tuning, "cpu")
	var cpu_m := multiplier(cpu_t.clock, cpu_t.voltage)
	var s := {"cpu": 0.0, "gpu": 0.0, "ram": 0.0, "storage": 0.0}
	if installed.has("cpu"):
		s.cpu = installed.cpu.cpu * cpu_m
	if installed.has("gpu"):
		var g := tune_of(tuning, "gpu")
		s.gpu = installed.gpu.gpu * multiplier(g.clock, g.voltage)
	if igpu_usable(installed):
		s.gpu = maxf(s.gpu, installed.cpu.gpu * cpu_m)
	if installed.has("ram"):
		var r := tune_of(tuning, "ram")
		s.ram = installed.ram.ram * multiplier(r.clock, r.voltage)
	if installed.has("storage"):
		s.storage = installed.storage.storage
	var w: Dictionary = WEIGHTS.get(objective, WEIGHTS.Balanced)
	var total := 0.0
	for k in s:
		total += w[k] * s[k] / REF[k]
	var iss := issues(installed, tuning)
	var ok := iss.is_empty()
	return {"cpu": int(round(s.cpu)), "gpu": int(round(s.gpu)), "ram": int(round(s.ram)),
		"storage": int(round(s.storage)), "total": int(round(total * 1000.0)) if ok else 0, "valid": ok, "issues": iss}


## Cheapest valid stock build cost from available listings, -1 if none. For smoke checks.
static func cheapest_build(listings: Array) -> int:
	var by := {}
	for c in CATEGORIES:
		by[c] = []
	for l in listings:
		if l.status == "available":
			by[l.category].append(l)
	for c in CATEGORIES:
		by[c].sort_custom(func(a, b): return a.price < b.price)
	var best := -1
	for cs in by.case:
		for mb in by.motherboard:
			for cpu in by.cpu:
				if cpu.socket != mb.socket or (mb.form == "ATX" and cs.form == "mATX"):
					continue
				var ram = _first(by.ram, func(r): return r.memory == mb.memory)
				var sto = _first(by.storage, func(_r): return true)
				if ram == null or sto == null:
					continue
				var inst := {"case": cs, "motherboard": mb, "cpu": cpu, "ram": ram, "storage": sto}
				var cost: int = cs.price + mb.price + cpu.price + ram.price + sto.price
				if not igpu_usable(inst):
					var g = _first(by.gpu, func(_r): return true)
					if g == null:
						continue
					inst["gpu"] = g
					cost += g.price
				var ps = _first(by.psu, func(p): return p.capacity >= power_draw(inst, {}))
				if ps == null:
					continue
				cost += ps.price
				if best < 0 or cost < best:
					best = cost
	return best


static func _first(arr: Array, pred: Callable) -> Variant:
	for x in arr:
		if pred.call(x):
			return x
	return null
