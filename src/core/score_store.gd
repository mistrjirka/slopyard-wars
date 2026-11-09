extends RefCounted
## Local high scores are isolated from simulation and transport.
const Config = preload("res://src/core/game_config.gd")


static func load_best(path: String = Config.SAVE_PATH) -> Dictionary:
	if FileAccess.file_exists(path):
		var js = JSON.parse_string(FileAccess.get_file_as_string(path))
		if js is Dictionary:
			var scores := {}
			for objective in ["Balanced", "CPU", "GPU", "Storage"]:
				var value: Variant = js.get(objective, 0)
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
