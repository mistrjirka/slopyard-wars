extends Control
## Composition root. Screens own their UI; the session owns the game.
const K = preload("res://src/ui/ui_kit.gd")
const SCREENS = {
	"menu": preload("res://src/ui/menu_screen.tscn"),
	"lobby": preload("res://src/ui/lobby_screen.tscn"),
	"playing": preload("res://src/ui/game_screen.tscn"),
	"results": preload("res://src/ui/results_screen.tscn"),
}

@onready var _screen_layer: Control = $Screens
@onready var _toasts: VBoxContainer = $Toasts
var _screen: Control
var _phase := ""
var _match_id := -1


func _ready() -> void:
	resized.connect(queue_redraw)
	Game.changed.connect(_refresh)
	Game.notice.connect(_toasts.show_notice)
	_refresh()


func _refresh() -> void:
	var phase: String = Game.state.phase
	var match_id: int = Game.state.match_id
	if phase != _phase or match_id != _match_id:
		_phase = phase
		_match_id = match_id
		K.clear(_screen_layer)
		K.clear(_toasts)
		_screen = SCREENS[phase].instantiate()
		_screen_layer.add_child(_screen)
		match phase:
			"menu":
				_screen.solo_requested.connect(Game.solo)
				_screen.host_requested.connect(Game.host)
				_screen.join_requested.connect(Game.join_game)
			"lobby":
				_screen.start_requested.connect(Game.start_match)
				_screen.leave_requested.connect(Game.leave)
			"playing":
				_screen.notice_requested.connect(_toasts.show_notice)
				_screen.leave_requested.connect(Game.leave)
			"results":
				_screen.menu.connect(Game.leave)
				_screen.replay.connect(_replay)
	_screen.refresh()


func _replay() -> void:
	Game.solo(str(Game.me().get("name", "Scrapper")), int(Game.state.budget), str(Game.state.objective))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), K.NAVY0)
	var step := 48.0
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(K.LINE, 0.16), 1.0)
		x += step
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(K.LINE, 0.16), 1.0)
		y += step
	draw_rect(Rect2(0, 0, size.x, 4), K.LIME)
