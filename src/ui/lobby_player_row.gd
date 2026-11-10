extends PanelContainer

const K = preload("res://src/ui/ui_kit.gd")

@onready var _name: Label = $Row/Name
@onready var _host: PanelContainer = $Row/HostPill
@onready var _you: PanelContainer = $Row/YouPill

func _ready() -> void:
	K.set_pill(_host, "HOST", K.ORANGE)
	K.set_pill(_you, "YOU", K.LIME)
	_host.visible = false
	_you.visible = false

func configure(player_name: String, is_host: bool, is_you: bool) -> void:
	_name.text = player_name
	_host.visible = is_host
	_you.visible = is_you
