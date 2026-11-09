extends RefCounted
## Factual buying notes shared by listings, inventory, LLM context and scoring.


static func condition_factor(item: Dictionary) -> float:
	return 0.75 + 0.25 * clampf(float(item.get("condition", 100)), 0, 100) / 100.0


static func stock_score(item: Dictionary, category: String = "") -> float:
	var key := category if category != "" else str(item.get("category", ""))
	return float(item.get(key, 0)) * condition_factor(item)


static func stock_failure_chance(item: Dictionary) -> float:
	var health := clampf(float(item.get("condition", 100)), 0, 100)
	return clampf(float(item.get("stock_failure_chance", 0)) * (1 + (100 - health) * 0.008), 0, 0.95)


static func reference_price(item: Dictionary) -> int:
	return maxi(1, roundi(float(item.get("reference_base", item.get("price", 1))) * condition_factor(item)))


static func stock_fire_chance(item: Dictionary) -> float:
	var health := clampf(float(item.get("condition", 100)), 0, 100)
	return clampf(float(item.get("fire_base_chance", 0)) * (1 + (100 - health) * 0.008), 0, 0.85)


## Public guidance uses current condition, never the hidden buyer budget or old purchase price.
static func sale_guide(item: Dictionary) -> Dictionary:
	var guide := clampi(reference_price(item), 1, 5000)
	return {"value": guide, "quick": clampi(roundi(guide * 0.8), 1, 5000),
		"ask_low": guide, "ask_high": clampi(roundi(guide * 1.15), 1, 5000)}


static func sale_advice(item: Dictionary, asking_price: int) -> String:
	var guide := sale_guide(item)
	if asking_price < int(guide.quick):
		return "Below the quick-deal guide. Easy to underprice this part; you may be leaving money behind."
	if asking_price < int(guide.ask_low):
		return "A lower ask for an easier negotiation. Buyers may still counter; pickup is still required."
	if asking_price <= int(guide.ask_high):
		return "A reasonable starting ask with room to haggle. A buyer's opening offer can be much lower."
	return "Ambitious ask: above the suggested range. Expect a long wait, a lower counteroffer, or no replies at all."


static func has_inherent_risk(item: Dictionary) -> bool:
	return stock_failure_chance(item) > 0 or stock_fire_chance(item) > 0


static func value_text(item: Dictionary) -> String:
	var guide := reference_price(item)
	var ratio := float(item.get("price", guide)) / guide
	var verdict := "below guide" if ratio < 0.85 else ("above guide" if ratio > 1.15 else "near guide")
	return "Used-price guide $%d · %s (%.2fx guide)" % [guide, verdict, ratio]


static func performance_text(item: Dictionary) -> String:
	var category := str(item.get("category", ""))
	var details: Array[String] = [str(item.get("manufacturer", "")), "Condition %d/100" % int(item.get("condition", 100))]
	if int(item.get("cores", 0)) > 0:
		details.append("%d cores" % int(item.cores))
	if int(item.get("capacity_gb", 0)) > 0:
		details.append("%dGB" % int(item.capacity_gb))
	if int(item.get("stock_clock_mhz", 0)) > 0:
		details.append("%dMHz stock" % int(item.stock_clock_mhz))
	if category in ["cpu", "gpu", "ram", "storage"]:
		var score := stock_score(item)
		details.append("Stock score %d" % roundi(score))
		if float(item.get("watts", 0)) > 0:
			details.append("%.1f score/W" % (score / float(item.watts)))
	var support_labels := {"case": "Airflow", "motherboard": "VRM quality", "psu": "Power regulation"}
	if support_labels.has(category):
		details.append("%s %d/100" % [support_labels[category], int(item.get("support_quality", 50))])
	if category in ["cpu", "gpu", "ram"]:
		var fault := stock_failure_chance(item)
		if fault > 0:
			details.append("RELIABILITY WARNING: %.1f%% stock failure risk per test / final benchmark" % (fault * 100))
		var fire := stock_fire_chance(item)
		if fire > 0:
			details.append("CONNECTOR FIRE: %.1f%% stock risk per test / final benchmark; extra power, heat and weak PSU regulation increase OC risk" % (fire * 100))
		details.append("Model OC headroom +%d%%" % roundi(float(item.get("oc_potential", 0)) * 100))
		details.append("Voltage comfort limit %.2fx" % float(item.get("voltage_limit", 1.3)))
		details.append("Heat load %.2fx" % float(item.get("thermal_load", 1)))
	else:
		details.append("Not directly overclockable")
	return " · ".join(details)
