extends RefCounted
## One owner for contact schedules, canonical meeting choices and readable game timestamps.
const Characters = preload("res://src/data/characters.gd")
const Catalog = preload("res://src/data/catalog.gd")
const Config = preload("res://src/core/game_config.gd")
const START := Config.START_MINUTE
const WINDOW := 90.0
const MIN_MEETING_LEAD := 60.0


## Only NEW agreements need an hour's notice; confirmed meetings remain valid as they approach.
static func can_agree(option: Dictionary, now: float) -> bool:
	return not option.is_empty() and float(option.get("start", 0)) >= now + MIN_MEETING_LEAD and float(option.get("end", 0)) > float(option.get("start", 0))
static func stamp(at: float) -> String:
	var m := maxi(0, int(at))
	return "Day %d · %02d:%02d" % [1 + m / 1440, (m % 1440) / 60, m % 60]


static func profile(name: String, location: String) -> Dictionary:
	var character := Characters.find(name)
	if character == null:
		return {"hours": [Vector2i(9, 18)], "note": "Daytime appointments.", "places": [location]}
	return {"hours": character.hours.duplicate(), "note": character.schedule_note,
		"places": Array(character.meeting_places)}


static func options(name: String, location: String, now: float, deadline: float = Config.DEADLINE) -> Array:
	var p := profile(name, location)
	var out: Array = []
	var day := int(now) / 1440
	for d in range(day, ceili(deadline / 1440.0)):
		for hours: Vector2i in p.hours:
			var start: float = maxf(float(d * 1440 + int(hours[0]) * 60), ceilf((now + MIN_MEETING_LEAD) / 30.0) * 30.0)
			var end: float = minf(deadline, minf(start + WINDOW, float(d * 1440 + int(hours[1]) * 60)))
			if end - start < 30 or start >= deadline:
				continue
			for place: String in p.places:
				out.append({"id": "%d@%s" % [int(start), place], "place": place, "start": start, "end": end, "pos": Catalog.LOCATIONS[place], "label": "%s at %s (until %02d:%02d)" % [stamp(start), place, (int(end) % 1440) / 60, int(end) % 60]})
			if out.size() >= 6:
				return out
	return out


## Count meetings, not alternative places or proposals; touching endpoints do not overlap.
static func player_overlap_count(player: Dictionary, listings: Array, listing_id: int, candidate: Dictionary, now: float) -> int:
	var count := 0
	for id in player.get("meetings", {}):
		if int(id) == listing_id or int(player.get("offers", {}).get(id, 0)) <= 0:
			continue
		var live := false
		for listing: Dictionary in listings:
			if int(listing.id) == int(id):
				live = listing.status == "available"
				break
		if not live:
			continue
		var meeting: Dictionary = player.meetings[id]
		if float(meeting.end) > now and float(candidate.start) < float(meeting.end) and float(candidate.end) > float(meeting.start):
			count += 1
	return count


static func find_option(options_list: Array, id: String) -> Dictionary:
	for o: Dictionary in options_list:
		if o.id == id:
			return o.duplicate(true)
	return {}
