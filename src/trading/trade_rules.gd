extends RefCounted
## One owner for contact schedules, canonical meeting choices and readable game timestamps.
const Characters = preload("res://src/data/characters.gd")
const Catalog = preload("res://src/data/catalog.gd")
const Config = preload("res://src/core/game_config.gd")
const START := Config.START_MINUTE
const WINDOW := 90.0
static func stamp(at: float) -> String:
	var m := maxi(0, int(at))
	return "Day %d · %02d:%02d" % [1 + m / 1440, (m % 1440) / 60, m % 60]


static func profile(name: String, location: String) -> Dictionary:
	var character := Characters.find(name)
	if character == null:
		return {"hours": [Vector2i(9, 18)], "note": "Daytime appointments.", "places": [location]}
	return {"hours": character.hours.duplicate(), "note": character.schedule_note,
		"places": Array(character.meeting_places)}


static func options(name: String, location: String, now: float) -> Array:
	var p := profile(name, location)
	var out: Array = []
	var day := int(now) / 1440
	for d in range(day, ceili(Config.DEADLINE / 1440.0)):
		for hours: Vector2i in p.hours:
			var start: float = maxf(float(d * 1440 + int(hours[0]) * 60), ceilf((now + 12.0) / 30.0) * 30.0)
			var end: float = minf(Config.DEADLINE, minf(start + WINDOW, float(d * 1440 + int(hours[1]) * 60)))
			if end - start < 30 or start >= Config.DEADLINE:
				continue
			for place: String in p.places:
				out.append({"id": "%d@%s" % [int(start), place], "place": place, "start": start, "end": end, "pos": Catalog.LOCATIONS[place], "label": "%s at %s (until %02d:%02d)" % [stamp(start), place, (int(end) % 1440) / 60, int(end) % 60]})
			if out.size() >= 6:
				return out
	return out


static func find_option(options_list: Array, id: String) -> Dictionary:
	for o: Dictionary in options_list:
		if o.id == id:
			return o.duplicate(true)
	return {}
