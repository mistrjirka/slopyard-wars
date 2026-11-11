extends Button


func _ready() -> void:
	tooltip_text = "Sound settings · F8 mutes all audio"
	pressed.connect(Sound.open_settings)
