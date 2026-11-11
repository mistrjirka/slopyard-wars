extends RefCounted
## Local high scores are isolated from simulation and transport.
const Config = preload("res://src/core/game_config.gd")
const BALANCE_VERSION := "v2"


## Keep earlier records intact, but compare only equivalent economy/run settings.
static func key(objective: String, budget: int, days: int) -> String:
	return "%s|%s|%d|%d" % [BALANCE_VERSION, objective, budget, days]


static func load_best(path: String = Config.SAVE_PATH) -> Dictionary:
	if FileAccess.file_exists(path):
		var js = JSON.parse_string(FileAccess.get_file_as_string(path))
		if js is Dictionary:
			var scores := {}
			var valid_key := RegEx.create_from_string("^v[0-9]+\\|(Balanced|CPU|GPU|Storage)\\|[0-9]+\\|[1-7]$")
			for objective in js:
				if objective not in ["Balanced", "CPU", "GPU", "Storage"] and valid_key.search(str(objective)) == null:
					continue
				var value: Variant = js[objective]
				if (value is int or value is float) and is_finite(float(value)):
					scores[objective] = maxi(0, int(value))
			return scores
	return {}


static func save_best(d: Dictionary, path: String = Config.SAVE_PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
	else:
		push_warning("Could not save high scores: %s" % error_string(FileAccess.get_open_error()))
