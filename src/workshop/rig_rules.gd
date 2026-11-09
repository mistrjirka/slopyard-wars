extends RefCounted
## Pure compatibility, tuning, power and benchmark rules; no nodes or match mutations.
const Overclock = preload("res://src/workshop/overclock_rules.gd")
const Stats = preload("res://src/data/hardware_stats.gd")
const Catalog = preload("res://src/data/catalog.gd")
const TUNABLE := ["cpu", "gpu", "ram"]
const REF := {"cpu": 6000.0, "gpu": 6000.0, "ram": 4000.0, "storage": 4000.0}
const WEIGHTS := {
	"Balanced": {"cpu": 0.25, "gpu": 0.25, "ram": 0.25, "storage": 0.25},
	"CPU": {"cpu": 0.45, "gpu": 0.15, "ram": 0.20, "storage": 0.20},
	"GPU": {"cpu": 0.15, "gpu": 0.45, "ram": 0.20, "storage": 0.20},
	"Storage": {"cpu": 0.15, "gpu": 0.15, "ram": 0.20, "storage": 0.50},
}


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
			if cs.is_empty():
				return "Install a case first"
			if item.form == "ATX" and cs.form == "mATX":
				return "ATX motherboard does not fit your mATX case"
			var cpu: Dictionary = installed.get("cpu", {})
			if not cpu.is_empty() and cpu.socket != item.socket:
				return "Board socket %s does not match installed CPU socket %s" % [item.socket, cpu.socket]
			var ram: Dictionary = installed.get("ram", {})
			if not ram.is_empty() and ram.memory != item.memory:
				return "Board takes %s but installed RAM is %s" % [item.memory, ram.memory]
		"psu":
			if cs.is_empty():
				return "Install a case first"
		"cpu", "ram", "gpu", "storage":
			if cs.is_empty():
				return "Install a case first"
			if mb.is_empty():
				return "Install a motherboard first"
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


static func score(installed: Dictionary, tuning: Dictionary, objective: String, modifiers: Dictionary = {}) -> Dictionary:
	var cpu_t := tune_of(tuning, "cpu")
	var cpu_m: float = Overclock.evaluate(installed.get("cpu", {}), cpu_t.clock, cpu_t.voltage, installed, modifiers).multiplier
	var s := {"cpu": 0.0, "gpu": 0.0, "ram": 0.0, "storage": 0.0}
	if installed.has("cpu"):
		s.cpu = Stats.stock_score(installed.cpu, "cpu") * cpu_m
	if installed.has("gpu"):
		var g := tune_of(tuning, "gpu")
		s.gpu = Stats.stock_score(installed.gpu) * float(Overclock.evaluate(installed.gpu, g.clock, g.voltage, installed, modifiers).multiplier)
	if igpu_usable(installed):
		s.gpu = maxf(s.gpu, Stats.stock_score(installed.cpu, "gpu") * cpu_m)
	if installed.has("ram"):
		var r := tune_of(tuning, "ram")
		s.ram = Stats.stock_score(installed.ram) * float(Overclock.evaluate(installed.ram, r.clock, r.voltage, installed, modifiers).multiplier)
	if installed.has("storage"):
		s.storage = Stats.stock_score(installed.storage)
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
	for c in Catalog.CATEGORIES:
		by[c] = []
	for l in listings:
		if l.status == "available":
			by[l.category].append(l)
	for c in Catalog.CATEGORIES:
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
