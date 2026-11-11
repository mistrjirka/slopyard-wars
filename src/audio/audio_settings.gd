extends Control
@onready var _content: VBoxContainer = $Center/Panel/Margin/Content


func _ready() -> void:
	for bus: String in Sound.volumes:
		var slider := _content.get_node(bus + "/Slider") as HSlider
		slider.value_changed.connect(func(value: float):
			Sound.set_volume(bus, value / 100.0)
			_content.get_node(bus + "/Value").text = "%d%%" % roundi(value))
		# Persist keyboard and slider changes together when the overlay closes.
	_content.get_node("Mute").toggled.connect(Sound.set_muted)
	_content.get_node("Close").pressed.connect(hide)
	visibility_changed.connect(func():
		if not visible:
			Sound.save_settings())
	Sound.settings_changed.connect(sync)


func sync() -> void:
	if not is_node_ready():
		return
	for bus: String in Sound.volumes:
		var value := roundi(float(Sound.volumes[bus]) * 100.0)
		_content.get_node(bus + "/Slider").set_value_no_signal(value)
		_content.get_node(bus + "/Value").text = "%d%%" % value
	_content.get_node("Mute").set_pressed_no_signal(Sound.muted)


func focus_volume() -> void:
	_content.get_node("Master/Slider").grab_focus()
