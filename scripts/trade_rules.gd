extends RefCounted
## One owner for contact schedules, canonical meeting choices and readable game timestamps.
const Catalog = preload("res://scripts/catalog.gd")
const START := 480.0 # Day 1, 08:00
const WINDOW := 90.0
const PROFILES := [
	{"hours": [[8, 12], [16, 19]], "note": "Works afternoons. Usually around before lunch or after 4."},
	{"hours": [[17, 22]], "note": "At work all day. Evenings only, 5–10pm."},
	{"hours": [[11, 15], [20, 23]], "note": "Late riser. Lunch or after 8pm works."},
	{"hours": [[6, 10], [14, 17]], "note": "Early shifts. Mornings or mid-afternoon."},
	{"hours": [[9, 18]], "note": "Around during the day. No late-night pickups."},
	{"hours": [[12, 14], [18, 23]], "note": "Only lunch break or after work."},
]

static func stamp(at: float) -> String:
	var m := maxi(0, int(at))
	return "Day %d · %02d:%02d" % [1 + m / 1440, (m % 1440) / 60, m % 60]

static func profile(name: String, location: String) -> Dictionary:
	var h: int = int(name.hash())
	var p: Dictionary = PROFILES[h % PROFILES.size()].duplicate(true)
	var places: Array = [location]
	var keys: Array = Catalog.LOCATIONS.keys()
	var other: String = keys[(h / 7) % keys.size()]
	if other == location: other = keys[(h / 7 + 1) % keys.size()]
	places.append(other)
	p["places"] = places
	return p

static func options(name: String, location: String, now: float) -> Array:
	var p := profile(name, location)
	var out: Array = []
	var day := int(now) / 1440
	for d in range(day, 4):
		for hours: Array in p.hours:
			var start: float = maxf(float(d * 1440 + int(hours[0]) * 60), ceilf((now + 12.0) / 30.0) * 30.0)
			var end: float = minf(START + 4320, minf(start + WINDOW, float(d * 1440 + int(hours[1]) * 60)))
			if end - start < 30 or start >= START + 4320: continue
			for place: String in p.places:
				out.append({"id": "%d@%s" % [int(start), place], "place": place, "start": start, "end": end, "pos": Catalog.LOCATIONS[place], "label": "%s at %s (until %02d:%02d)" % [stamp(start), place, (int(end) % 1440) / 60, int(end) % 60]})
			if out.size() >= 6: return out
	return out

static func find_option(options_list: Array, id: String) -> Dictionary:
	for o: Dictionary in options_list:
		if o.id == id: return o.duplicate(true)
	return {}
