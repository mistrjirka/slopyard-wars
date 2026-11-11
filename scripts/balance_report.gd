extends SceneTree
## Reproducible catalog frontier, using the real compatibility/benchmark rules.
## Run: godot --headless --path . --script res://scripts/balance_report.gd
## Base prices, average authored condition, stock clocks; not a promise of RNG
## availability, successful negotiation, free travel or surviving model defects.
const Catalog = preload("res://src/data/catalog.gd")
const Rig = preload("res://src/workshop/rig_rules.gd")
const Stats = preload("res://src/data/hardware_stats.gd")
const BUDGETS := [600, 800, 1000, 1500, 2500, 5000]
var by: Dictionary = {}
var best: Dictionary = {}
var checked := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 73
	for category: String in Catalog.CATEGORIES:
		by[category] = []
	for template: Resource in Catalog.PARTS:
		var part := Catalog.build_listing(random, template, checked)
		part.condition = roundi((template.condition_min + template.condition_max) / 2.0)
		part.price = template.base_price
		by[part.category].append(part)
		checked += 1
	for category: String in ["case", "psu"]:
		by[category].sort_custom(func(a, b): return a.price < b.price)
	checked = 0
	for board: Dictionary in by.motherboard:
		var cpus: Array = by.cpu.filter(func(part): return part.socket == board.socket)
		var memory: Array = by.ram.filter(func(part): return part.memory == board.memory)
		var cases: Array = by.case.filter(func(part): return part.form == "ATX" or board.form != "ATX")
		for cpu: Dictionary in cpus:
			for ram: Dictionary in memory:
				for storage: Dictionary in by.storage:
					var partial := {"case": cases[0], "motherboard": board, "cpu": cpu, "ram": ram, "storage": storage}
					if Rig.igpu_usable(partial):
						_consider(partial)
					for gpu: Dictionary in by.gpu:
						var with_gpu := partial.duplicate()
						with_gpu.gpu = gpu
						_consider(with_gpu)
	var rows: Array = []
	print("CATALOG FRONTIER: base prices, average condition, stock clocks, complete rigs")
	print("budget | objective | maximum score | risk-free score | max build cost")
	for budget: int in BUDGETS:
		for objective: String in Rig.WEIGHTS:
			var row: Dictionary = best[_key(budget, objective)]
			var safe: Dictionary = best[_key(budget, objective) + "|safe"]
			print("$%d | %s | %d | %d | $%d" % [budget, objective, row.score, safe.score, row.cost])
			rows.append({"budget": budget, "objective": objective, "maximum": row, "without_inherent_faults": safe})
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var file := FileAccess.open("res://artifacts/balance_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"complete_builds": checked, "assumptions": "Catalog base prices, average condition, stock clocks; no travel, negotiation, wear, availability or defect rolls.", "rows": rows}, "\t"))
	print("Compared %d complete powered builds. Details: artifacts/balance_report.json" % checked)
	quit()


func _key(budget: int, objective: String) -> String:
	return "%d|%s" % [budget, objective]


func _consider(partial: Dictionary) -> void:
	var draw := Rig.power_draw(partial, {})
	var supplies: Array = by.psu.filter(func(part): return part.capacity >= draw)
	if supplies.is_empty():
		return
	var installed := partial.duplicate()
	installed.psu = supplies[0]
	var cost := 0
	var safe := true
	var models: Array = []
	for part: Dictionary in installed.values():
		cost += int(part.price)
		models.append(part.model_id)
		safe = safe and not Stats.has_inherent_risk(part)
	if cost > BUDGETS[-1]:
		return
	checked += 1
	for objective: String in Rig.WEIGHTS:
		var score := Rig.score(installed, {}, objective)
		assert(score.valid)
		for budget: int in BUDGETS:
			if cost > budget:
				continue
			for key: String in [_key(budget, objective), _key(budget, objective) + "|safe"] if safe else [_key(budget, objective)]:
				var previous: Dictionary = best.get(key, {})
				if previous.is_empty() or score.total > previous.score or (score.total == previous.score and cost < previous.cost):
					best[key] = {"score": score.total, "cost": cost, "models": models, "cpu": score.cpu, "gpu": score.gpu, "ram": score.ram, "storage": score.storage}
