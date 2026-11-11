@tool
extends RefCounted
## Shared dotenv parsing and build-only credential format. The passphrase is public obfuscation.

const PATH := "res://bundled_credentials.enc"
const PASSPHRASE := "Slopyard-Wars-build-credential-v1"


static func env_key(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges().trim_prefix("export ").strip_edges()
		var entry := line.split("=", true, 1)
		if entry.size() != 2 or entry[0].strip_edges() not in ["OPENROUTER_KEY", "OPENROUTER_API_KEY"]:
			continue
		var value := entry[1].strip_edges()
		if value.begins_with("\"") or value.begins_with("'"):
			var quote := value.left(1)
			var end := value.find(quote, 1)
			if end < 0:
				continue
			value = value.substr(1, end - 1)
		else:
			value = value.split(" #", true, 1)[0].strip_edges()
		if value != "":
			return value.strip_edges()
	return ""


static func load_key() -> String:
	if not FileAccess.file_exists(PATH):
		return ""
	var config := ConfigFile.new()
	if config.load_encrypted_pass(PATH, PASSPHRASE) != OK:
		return ""
	return str(config.get_value("openrouter", "api_key", "")).strip_edges()


static func is_plaintext_credential(path: String) -> bool:
	for part in path.trim_prefix("res://").replace("\\", "/").split("/"):
		if part == ".local" or part == ".env" or part.begins_with(".env."):
			return true
	return false
