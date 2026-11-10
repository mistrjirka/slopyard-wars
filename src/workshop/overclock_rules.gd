extends RefCounted
## One deterministic preview shared by UI, scoring and host damage rolls.
const Stats = preload("res://src/data/hardware_stats.gd")
const HARD_VOLTAGE_LIMIT := 1.40


## Mount quality is a property of the player's build (player.workshop_modifiers["cpu_mount_quality"]),
## not of the tradeable CPU. Absent or non-numeric means 1.0, so a clean build keeps the old numbers.
static func cpu_mount_quality(modifiers: Dictionary) -> float:
	var raw: Variant = modifiers.get("cpu_mount_quality", 1.0)
	if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
		return 1.0
	var q := float(raw)
	if is_nan(q) or is_inf(q):
		return 1.0
	return clampf(q, 0.0, 1.0)


## Thermal paste coverage is also a build property, not a part stat: the CPU minigame reports a raw
## 0..3 amount (1.0 = enough), the host clamps it to 0..1, and anything above 1.0 is simply "enough".
static func cpu_paste_amount(modifiers: Dictionary) -> float:
	var raw: Variant = modifiers.get("cpu_paste_amount", 1.0)
	if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
		return 1.0
	var p := float(raw)
	if is_nan(p) or is_inf(p):
		return 1.0
	return clampf(p, 0.0, 1.0)


static func evaluate(item: Dictionary, clock: float, voltage: float,
		installed: Dictionary = {}, modifiers: Dictionary = {}) -> Dictionary:
	var health := clampf(float(item.get("condition", 100)), 0, 100)
	var potential := clampf(float(item.get("oc_potential", 0.25)), 0, 0.6)
	var limit := clampf(float(item.get("voltage_limit", 1.3)), 1.05, HARD_VOLTAGE_LIMIT)
	var case_part: Dictionary = installed.get("case", {})
	var board: Dictionary = installed.get("motherboard", {})
	var supply: Dictionary = installed.get("psu", {})
	var cooling := float(case_part.get("support_quality", 50)) * Stats.condition_factor(case_part)
	cooling = clampf(cooling + float(modifiers.get("cooling_bonus", 0)), 0, 100)
	var vrm := float(board.get("support_quality", 50)) * Stats.condition_factor(board)
	var regulation := float(supply.get("support_quality", 50)) * Stats.condition_factor(supply)
	var support := (cooling + vrm + regulation) / 300.0
	# Poor cooler mounting only affects the CPU it is clamped onto: less headroom, more heat.
	var mount := 1.0
	var mount_headroom := 1.0
	var mount_heat := 0.0
	if item.get("category", "") == "cpu":
		mount = cpu_mount_quality(modifiers)
		if mount < 1.0:
			mount_headroom = lerpf(0.8, 1.0, mount)
			mount_heat = 10.0 * (1.0 - mount)
	var headroom := potential * (0.75 + health * 0.0025) * (0.80 + support * 0.20) * mount_headroom
	var stable := 1.0 + headroom * clampf((voltage - 1.0) / (limit - 1.0), 0, 1)
	var excess := maxf(0, clock - stable)
	var multiplier := (1.0 + (clock - 1.0) * 0.9) * maxf(0.25, 1.0 - excess * 5.0)
	# Paste is a CPU-only performance multiplier (no paste = 50%), independent of the mount's
	# headroom/heat penalty. Too much paste is never penalised.
	var paste := 1.0
	var paste_multiplier := 1.0
	if item.get("category", "") == "cpu":
		paste = cpu_paste_amount(modifiers)
		if paste < 1.0:
			paste_multiplier = lerpf(0.5, 1.0, paste)
			multiplier *= paste_multiplier
	var temperature := 29.0 + 24.0 * float(item.get("thermal_load", 1)) * clock * voltage * voltage - cooling * 0.16 + mount_heat
	var voltage_stress := maxf(0, voltage - (limit - 0.04)) / 0.14
	var clock_stress := maxf(0, excess - 0.025) / 0.4
	var heat_stress := maxf(0, temperature - 82) / 35
	var chance := clampf((voltage_stress * 0.45 + clock_stress * 0.25 + heat_stress * 0.35) * (1.0 + (100 - health) * 0.008), 0, 0.95)
	# Stock removes tuning stress, but an authored reliability flaw can still fail.
	if clock <= 1.0001 and voltage <= 1.0001:
		chance = 0.0
	var stock_fault := Stats.stock_failure_chance(item)
	chance = 1.0 - (1.0 - chance) * (1.0 - stock_fault)
	# Only models with an authored connector flaw can catch fire. This is game balance,
	# not a physical connector model or a real-world hardware failure estimate.
	var fire := Stats.stock_fire_chance(item)
	if fire > 0:
		var power_stress := maxf(0, clock * voltage * voltage - 1.0)
		var poor_regulation := 1.0 + maxf(0, 70 - regulation) / 100.0
		var extra_fire := float(item.get("fire_power_sensitivity", 0)) * power_stress * poor_regulation + heat_stress * 0.04
		fire = clampf(fire + extra_fire * (1.0 + (100 - health) * 0.008), 0, 0.85)
	# Fire is a subset of destruction, not a second roll added to the displayed total.
	chance = fire + (1.0 - fire) * chance
	var uses_luck := chance > 0 and int(modifiers.get("lucky_tests", 0)) > 0 and voltage <= HARD_VOLTAGE_LIMIT + 0.0001
	if uses_luck:
		chance *= 0.75
		fire *= 0.75
	if voltage > HARD_VOLTAGE_LIMIT + 0.0001:
		chance = 1.0
	return {"stable_clock": stable, "multiplier": multiplier, "temperature": temperature, "stock_failure_chance": stock_fault,
		"damage_chance": chance, "fire_chance": fire, "uses_luck": uses_luck, "paste_amount": paste,
		"paste_multiplier": paste_multiplier, "cpu_mount_quality": mount, "mount_headroom_multiplier": mount_headroom,
		"mount_temperature_penalty": mount_heat,
		"wear": ceili(chance * 8) if chance > 0 else 0}


static func safe_preset(item: Dictionary, installed: Dictionary, modifiers: Dictionary = {}) -> Dictionary:
	# No zero-risk setting exists for a faulty model. The UI labels this fallback explicitly.
	if Stats.has_inherent_risk(item):
		return {"clock": 1.0, "voltage": 1.0}
	var voltage := minf(1.30, float(item.get("voltage_limit", 1.3)) - 0.06)
	while voltage > 1.0:
		var result := evaluate(item, 1.0, voltage, installed, modifiers)
		var clock := floorf(float(result.stable_clock) * 100) / 100
		if evaluate(item, clock, voltage, installed, modifiers).damage_chance == 0:
			return {"clock": clock, "voltage": snappedf(voltage, 0.01)}
		voltage -= 0.01
	return {"clock": 1.0, "voltage": 1.0}


static func fails(chance: float, roll: float) -> bool:
	return chance > 0 and roll < chance


static func failure_mode(result: Dictionary, roll: float) -> String:
	if fails(float(result.get("fire_chance", 0)), roll):
		return "fire"
	return "damage" if fails(float(result.damage_chance), roll) else ""


## Pure final-test plan shared by the finish dialog and host. A blessing applies once,
## to the first risky component. Execution stops if the rig can no longer run.
static func final_tests(installed: Dictionary, tuning: Dictionary, modifiers: Dictionary) -> Array[Dictionary]:
	var tests: Array[Dictionary] = []
	var remaining := modifiers.duplicate(true)
	for category in ["cpu", "gpu", "ram"]:
		if not installed.has(category) or not Stats.has_inherent_risk(installed[category]):
			continue
		var t: Dictionary = tuning.get(category, {"clock": 1.0, "voltage": 1.0})
		var result := evaluate(installed[category], float(t.get("clock", 1)), float(t.get("voltage", 1)), installed, remaining)
		tests.append({"category": category, "clock": float(t.get("clock", 1)), "voltage": float(t.get("voltage", 1)), "result": result})
		if result.uses_luck:
			remaining.lucky_tests = maxi(0, int(remaining.get("lucky_tests", 0)) - 1)
	return tests
