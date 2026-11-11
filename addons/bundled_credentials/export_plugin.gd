@tool
extends EditorExportPlugin

const Credential = preload("res://addons/bundled_credentials/credential.gd")


func _get_name() -> String:
	return "BundledOpenRouterCredential"


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	# Only the export process reads the local dotenv for bundling. Never serialize plaintext.
	var key := Credential.env_key("res://.env")
	if key.is_empty():
		push_warning("No local OpenRouter credential to bundle; exported sellers need a runtime key.")
		return
	var config := ConfigFile.new()
	config.set_value("openrouter", "api_key", key)
	var temporary := OS.get_cache_dir().path_join("slopyard-credential-%d-%d.enc" % [OS.get_process_id(), Time.get_ticks_usec()])
	var error := config.save_encrypted_pass(temporary, Credential.PASSPHRASE)
	key = ""
	config.clear()
	if error != OK:
		DirAccess.remove_absolute(temporary)
		push_error("Could not encrypt bundled OpenRouter credential (error %d)." % error)
		return
	var encrypted := FileAccess.get_file_as_bytes(temporary)
	var cleanup_error := DirAccess.remove_absolute(temporary)
	if cleanup_error != OK or encrypted.is_empty():
		push_error("Could not prepare or clean up encrypted OpenRouter export credential.")
		return
	add_file(Credential.PATH, encrypted, false)


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if Credential.is_plaintext_credential(path):
		skip()
