extends Control
## A schematic assembly bench. Layout/controls are authored in assembly.tscn.
## Physical damage is committed by the host immediately, not deferred until completion.
signal completed(result: Dictionary)
signal cancelled
signal damage_requested(item_id: int, strike: int, reason: String)
signal stage_changed

const K = preload("res://src/ui/ui_kit.gd")
const PartArt = preload("res://src/ui/part_art.gd")
const Art = preload("res://src/ui/art_library.gd")
const Overclock = preload("res://src/workshop/overclock_rules.gd")
const RigRules = preload("res://src/workshop/rig_rules.gd")
const W := 780.0
const H := 540.0
const CASE_RECT := Rect2(30, 40, 480, 330)
const BOARD_RECT := Rect2(100, 65, 340, 270)
const BOARD_TARGET := BOARD_RECT.position + BOARD_RECT.size * 0.5
const TARGET := Vector2(270, 205)
const CPU_TARGET := Vector2(270, 230)
# Anchors refer to the supplied PNG pixels, including their transparent margins.
const SOCKET_ART_SCALE := 1.5
const SOCKET_CPU_ANCHOR := Vector2(98, 138)
const SOCKET_PINS_RECT := Rect2(65, 104, 65, 59)
const CPU_ART_SCALE := SOCKET_ART_SCALE * 0.75
const CPU_PACKAGE_SIZE := Vector2(96, 96) * CPU_ART_SCALE
const CPU_PASTE_RECT := Rect2(CPU_TARGET - Vector2(40, 40), Vector2(80, 80))
const GPU_ART_SCALE := 2.0
const GPU_SEATED_ORIGIN := Vector2(76, 178)
# Both supplied cards share this gold connector, despite their different shroud lengths.
const GPU_CONNECTOR_RECT := Rect2(25, 62, 54, 6)
const GPU_SLOT_RECT := Rect2(GPU_SEATED_ORIGIN + GPU_CONNECTOR_RECT.position * GPU_ART_SCALE - Vector2(3, 3),
	GPU_CONNECTOR_RECT.size * GPU_ART_SCALE + Vector2(6, 6))
const GPU_LATCH := GPU_SLOT_RECT.position + Vector2(GPU_SLOT_RECT.size.x + 16, GPU_SLOT_RECT.size.y * 0.5)
const MAX_STRIKES := 5
const SCREW_RATE := 65.0
const GPU_SAFE_SPEED := 220.0
const PSU_TARGET := Vector2(170, 280)
const PSU_SIZE := Vector2(240, 135)
const PSU_HOLES: Array[Vector2] = [Vector2(-108, -45), Vector2(108, -45), Vector2(-108, 60), Vector2(108, 60)]
# Schematic topology from ATX 2.2, Figure 2, p.10. Not a drilling template.
# Rear I/O is at the top. mATX adds B/R/S rather than being a smaller 3x3 grid.
const HOLES := {
	"A": Vector2(0.05, 0.07), "B": Vector2(0.285, 0.07), "C": Vector2(0.455, 0.07),
	"F": Vector2(0.95, 0.14), "G": Vector2(0.05, 0.65), "H": Vector2(0.455, 0.65),
	"J": Vector2(0.95, 0.65), "K": Vector2(0.05, 0.92), "L": Vector2(0.455, 0.92),
	"M": Vector2(0.95, 0.92), "R": Vector2(0.222, 0.65), "S": Vector2(0.285, 0.65),
}
const ATX_HOLES: Array[String] = ["A", "C", "F", "G", "H", "J", "K", "L", "M"]
const MATX_HOLES: Array[String] = ["B", "C", "F", "H", "J", "L", "M", "R", "S"]

var item: Dictionary = {}
var cat := ""
var steps: Array[Dictionary] = []
var si := 0
var slips := 0
var note := ""
var note_err := false
var _context: Dictionary = {}
var _standoffs: Dictionary = {}
var _repair_extras: Array[String] = []
var _strikes := 0
var _condition := 100
var _expected_strike := 0
var _damage_target_id := -1
var _pending_damage := false
var _destroyed := false
var _socket_destroyed := false
var _done := false
var _committed := false
var _board_fault := false
var _paste_amount := 0.0
var _paste_spots: Array[Vector2] = []
var _worst_pressure_spread := 0.0
var _held_paste := false
var _held_screw := -1
var _screw_direction := 0.0
var _dragging := false
var _grab := Vector2.ZERO
var _mouse := Vector2.ZERO
var _last_motion_us := 0
var _drag_speed := 0.0
var _flash := 0.0
var _t := 0.0

@onready var _primary: Button = $Actions/Primary
@onready var _secondary: Button = $Actions/Secondary
@onready var _retry: Button = $Actions/Retry
@onready var _hint: Label = $Hint
@onready var _penalties: Label = $Penalties


func begin(part: Dictionary, context: Dictionary = {}) -> void:
	item = part.duplicate(true)
	_context = context.duplicate(true)
	cat = str(item.get("category", ""))
	_strikes = int(item.get("assembly_strikes", 0))
	_condition = int(item.get("condition", 100))
	_reset_attempt()
	grab_focus()


func synchronize(part: Dictionary, installed: Dictionary, modifiers: Dictionary) -> void:
	item = part.duplicate(true)
	_context["modifiers"] = modifiers.duplicate(true)
	_strikes = int(item.get("assembly_strikes", 0))
	_condition = int(item.get("condition", 100))
	if cat == "cpu":
		var previous_board: Dictionary = _context.get("installed", {}).get("motherboard", {})
		var board: Dictionary = installed.get("motherboard", {})
		if int(board.get("id", -1)) != int(previous_board.get("id", -1)):
			if board.is_empty() and _pending_damage and _damage_target_id == int(previous_board.get("id", -1)) and _expected_strike >= MAX_STRIKES:
				mark_destroyed("motherboard")
			else:
				# The original socket is no longer available; never install against a stale board.
				cancelled.emit()
			return
	_context["installed"] = installed.duplicate(true)
	var damaged_part: Dictionary = item if _damage_target_id == int(item.get("id", -1)) else installed.get("motherboard", {})
	if _pending_damage and int(damaged_part.get("assembly_strikes", 0)) >= _expected_strike:
		_pending_damage = false
		if cat == "cpu" and _damage_target_id != int(item.get("id", -1)):
			note_err = false
	_refresh_controls()


func has_pending_fatal_damage() -> bool:
	return (_damage_target_id == int(item.get("id", -1)) and _expected_strike >= MAX_STRIKES) or _strikes >= MAX_STRIKES


func mark_destroyed(category: String = "", modifiers: Dictionary = {}) -> void:
	if not modifiers.is_empty():
		_context["modifiers"] = modifiers.duplicate(true)
	_destroyed = true
	_pending_damage = false
	_socket_destroyed = category == "motherboard" and cat == "cpu"
	if not _socket_destroyed:
		_strikes = MAX_STRIKES
	_stop_holding()
	note = "DO: Close installation and replace the destroyed motherboard.\nDON'T: Install the CPU without a working board." if _socket_destroyed else "DO: Close installation and replace this destroyed part.\nDON'T: Retry; five damage strikes are permanent."
	note_err = true
	_refresh_controls()
	stage_changed.emit()


func rotation_available() -> bool:
	return not _done and not _destroyed and not steps.is_empty() and int(steps[si].get("inc", 0)) > 0


func _reset_attempt() -> void:
	si = 0
	slips = 0
	_done = false
	_committed = false
	_board_fault = false
	_paste_amount = 0.0
	_paste_spots.clear()
	_worst_pressure_spread = 0.0
	_standoffs.clear()
	_repair_extras.clear()
	_stop_holding()
	steps = _build()
	_enter()


func _clk(pos: Vector2, count: int = 1, radius: float = 15.0) -> Dictionary:
	return {"p": pos, "n": count, "c": 0.0, "r": radius, "damaged": false}


func _clicks(title: String, hint: String, points: Array, style: String = "tighten") -> Dictionary:
	if style == "loosen":
		for point: Dictionary in points:
			point.c = 100.0
	return {"kind": "clicks", "title": title, "hint": hint, "pts": points, "style": style}


func _drag(title: String, hint: String, start: Vector2, target: Vector2, scale: float,
		rotation_step: int = 0, part: String = "") -> Dictionary:
	return {"kind": "drag", "title": title, "hint": hint, "pos": start, "target": target,
		"scale": scale, "inc": rotation_step, "rot": rotation_step if rotation_step > 0 else 0,
		"tol": 25.0, "part": part}


func _hole_ids() -> Array[String]:
	return MATX_HOLES if str(item.get("form", "ATX")) == "mATX" else ATX_HOLES


func _hole_pos(id: String) -> Vector2:
	return BOARD_RECT.position + Vector2(HOLES[id]) * BOARD_RECT.size


func _board_pcb_rect(rect: Rect2) -> Rect2:
	if str(item.get("form", "ATX")) == "mATX":
		rect.position.x += rect.size.x * 0.19
		rect.size.x *= 0.81
	return rect


func _corner_points(center: Vector2, hx: float, hy: float) -> Array:
	return [_clk(center + Vector2(-hx, -hy)), _clk(center + Vector2(hx, -hy)),
		_clk(center + Vector2(-hx, hy)), _clk(center + Vector2(hx, hy))]


func _uses_load_plate() -> bool:
	# OX4 is the PGA LuckyZen family. OX3 LuckyCore and newer sockets use LGA.
	return str(item.get("socket", "")) != "OX4"


func _cpu_lever_position(open_socket: bool) -> Vector2:
	if _uses_load_plate():
		var origin := CPU_TARGET - SOCKET_CPU_ANCHOR * SOCKET_ART_SCALE
		return origin + (Vector2(180, 54) if open_socket else Vector2(174, 180)) * SOCKET_ART_SCALE
	return CPU_TARGET + (Vector2(68, -55) if open_socket else Vector2(170, 40))


func _socket_pins_rect() -> Rect2:
	return Rect2(CPU_TARGET - SOCKET_CPU_ANCHOR * SOCKET_ART_SCALE + SOCKET_PINS_RECT.position * SOCKET_ART_SCALE,
		SOCKET_PINS_RECT.size * SOCKET_ART_SCALE)


func _gpu_texture() -> Texture2D:
	return Art.GPU_FAN_SIDES[posmod(str(item.get("name", "gpu")).hash(), Art.GPU_FAN_SIDES.size())]


func _gpu_target() -> Vector2:
	# Both card lengths mount to the same case edge; don't move the bracket with the fan count.
	return GPU_SEATED_ORIGIN + _gpu_texture().get_size() * GPU_ART_SCALE * 0.5


func _build() -> Array[Dictionary]:
	match cat:
		"case":
			return [_drag("1/2  SET THE CASE ON THE BENCH", "DO: Drag the case onto the outline.\nDON'T: Add standoffs yet; choose the motherboard first.", Vector2(650, 220), TARGET, 2.0),
				_clicks("2/2  OPEN THE SIDE PANEL", "DO: Hold right mouse on each panel screw to reach 0%.\nDON'T: Leave screws in. Metal case screws cannot cause damage.", _corner_points(TARGET, 185, 115), "loosen")]
		"motherboard":
			var points: Array = []
			for id in _hole_ids():
				var point := _clk(_hole_pos(id), 1, 11.0)
				point["hole"] = id
				points.append(point)
			return [{"kind": "standoffs", "title": "1/4  MATCH THE STANDOFFS", "hint": "Match the board's mounting holes with the case tray.\nClick a hole to fit or remove a standoff."},
				_drag("2/4  LOWER THE MOTHERBOARD", "DO: Match letters; keep blue REAR I/O edges at top.\nDON'T: Put supports under solid PCB; outside extras are safe.", Vector2(645, 220), BOARD_TARGET, 2.6, 0, "board"),
				{"kind": "board_check", "title": "3/4  CHECK SUPPORTS", "hint": "Inspect the board before fastening.\nLift Board to change the supports beneath it."},
				_clicks("4/4  FASTEN THE BOARD", "Hold left mouse to tighten; right mouse to loosen.\nDon't force a screw that resists.", points)]
		"cpu":
			var seating_hint := "DO: R / right-click CPU to rotate; match the gold corner.\nDON'T: "
			seating_hint += "Touch exposed pins: each click damages the board; 5 hits destroy it." if _uses_load_plate() else "Lock the socket until the CPU is seated flat."
			return [_clicks("1/6  RELEASE THE SOCKET", "DO: Click the retention lever to open the socket.\nDON'T: Force the CPU into a locked socket.", [_clk(_cpu_lever_position(false), 1, 20)], "lever"),
				_drag("2/6  SEAT THE CPU", seating_hint, Vector2(650, 230), CPU_TARGET, 1.6, 1),
				_clicks("3/6  LOCK THE SOCKET", "DO: Click the retention lever to secure the seated CPU.\nDON'T: Leave the socket unlocked before fitting the cooler.", [_clk(_cpu_lever_position(true), 1, 20)], "lever"),
				{"kind": "paste", "title": "4/6  APPLY THERMAL PASTE", "hint": "DO: Hold left mouse on CPU for paste; 100% is enough.\nDON'T: Use too little: up to 50% performance loss. Extra is harmless."},
				_drag("5/6  PLACE THE COOLER", "DO: Drag the supplied cooler squarely onto the CPU.\nDON'T: Skip paste; the cooler is already bundled with the CPU.", Vector2(650, 230), CPU_TARGET, 1.0, 0, "cooler"),
				_clicks("6/6  TIGHTEN EVENLY", "DO: Hold left mouse to tighten, right to loosen; alternate corners.\nDON'T: Finish one first or exceed 150% (damage). Safe: 100–150%.", _corner_points(CPU_TARGET, 88, 88), "cooler")]
		"gpu":
			return [_clicks("1/3  OPEN THE PCIe LATCH", "DO: Click the latch at the end of the PCIe slot.\nDON'T: Insert the GPU while the latch is closed.", [_clk(GPU_LATCH, 1, 18)], "lever"),
				{"kind": "gpu_drag", "title": "2/3  LOWER THE GRAPHICS CARD GENTLY", "hint": "DO: Align the gold connector with the slot; drag gently down.\nDON'T: Hit the slot fast; impact damages the GPU.", "pos": _gpu_target() - Vector2(0, 148), "target": _gpu_target(), "scale": 2.6, "inc": 0, "rot": 0, "tol": 24.0, "part": "gpu"},
				_clicks("3/3  SECURE THE CASE BRACKET", "DO: Hold left mouse on bracket screws to reach at least 100%.\nDON'T: Leave the bracket loose. Metal screws cannot cause damage.", [_clk(GPU_SEATED_ORIGIN + Vector2(8, 11) * GPU_ART_SCALE), _clk(GPU_SEATED_ORIGIN + Vector2(8, 55) * GPU_ART_SCALE)])]
		"ram":
			return [_clicks("1/3  OPEN THE CLIPS", "DO: Click both DIMM retention clips to open them.\nDON'T: Insert the RAM while the clips are closed.", [_clk(Vector2(118, 313), 1, 18), _clk(Vector2(562, 313), 1, 18)], "lever"),
				_drag("2/3  ALIGN THE NOTCH", "DO: Match the notch to the slot key; R / right-click flips RAM.\nDON'T: Force the stick in backwards.", Vector2(390, 110), Vector2(340, 263), 3.6, 2),
				_clicks("3/3  PRESS BOTH ENDS", "DO: Click each end three times to close both clips.\nDON'T: Leave one end unseated.", [_clk(Vector2(200, 258), 3, 20), _clk(Vector2(480, 258), 3, 20)], "press")]
		"psu":
			var points: Array = []
			for hole in PSU_HOLES:
				points.append(_clk(PSU_TARGET + hole))
			return [_drag("1/2  ALIGN THE POWER SUPPLY", "DO: Drag the PSU to align all four rear holes with the case.\nDON'T: Leave a mounting hole out of line.", Vector2(650, 180), PSU_TARGET, 1.0, 0, "psu"),
				_clicks("2/2  FASTEN TO THE CASE", "DO: Hold left mouse on all four PSU screws to reach 100%.\nDON'T: Leave screws loose. Metal screws cannot cause damage.", points)]
		"storage":
			return [_drag("1/2  ALIGN THE DRIVE", "DO: Drag the drive onto its mounting rails.\nDON'T: Leave the drive outside the outline.", Vector2(650, 230), Vector2(375, 205), 2.5),
				_clicks("2/2  SECURE THE DRIVE", "DO: Hold left mouse to tighten, right to loosen. Safe: 100–150%.\nDON'T: Exceed 150%; overtightening damages the drive.", [_clk(Vector2(262, 112)), _clk(Vector2(488, 112)), _clk(Vector2(262, 298)), _clk(Vector2(488, 298))])]
	return []


func _enter() -> void:
	_stop_holding()
	if si < steps.size():
		note = str(steps[si].hint)
		note_err = false
	_refresh_controls()
	stage_changed.emit()


func _stop_holding() -> void:
	_held_screw = -1
	_screw_direction = 0.0
	_held_paste = false
	_dragging = false


func _advance() -> void:
	si += 1
	if si >= steps.size():
		_done = true
		note = "DO: Review penalties below, then Install / Apply Reinstallation.\nDON'T: Expect damage to reset. Retry improves installation quality."
		note_err = false
		_stop_holding()
		_refresh_controls()
		stage_changed.emit()
	else:
		_enter()


func _request_damage(reason: String, message: String) -> void:
	if _pending_damage or _destroyed:
		return
	var damaged_part: Dictionary = _context.get("installed", {}).get("motherboard", {}) if reason == "socket_pins" else item
	if damaged_part.is_empty():
		return
	slips += 1
	_damage_target_id = int(damaged_part.get("id", -1))
	_expected_strike = int(damaged_part.get("assembly_strikes", 0)) + 1
	_pending_damage = true
	_flash = 0.5
	_stop_holding()
	note = message
	note_err = true
	damage_requested.emit(_damage_target_id, _expected_strike, reason)
	_refresh_controls()


func _mount_quality() -> float:
	return 1.0 - clampf((_worst_pressure_spread - 40.0) / 60.0, 0.0, 1.0)


func _preview() -> Dictionary:
	var modifiers: Dictionary = _context.get("modifiers", {}).duplicate(true)
	modifiers["cpu_mount_quality"] = _mount_quality()
	modifiers["cpu_paste_amount"] = minf(1.0, _paste_amount)
	return Overclock.evaluate(item, 1.0, 1.0, _context.get("installed", {}), modifiers)


func _screw_style(step: Dictionary) -> bool:
	return step.get("kind") == "clicks" and step.get("style") in ["tighten", "cooler", "loosen"]


func _sensitive_screws() -> bool:
	return cat in ["motherboard", "cpu", "storage"]


func _all_seated(step: Dictionary) -> bool:
	if step.get("style") == "loosen":
		return _all_backed_out(step)
	for point: Dictionary in step.pts:
		if float(point.c) < 100.0 or (_sensitive_screws() and float(point.c) > 150.0):
			return false
	return true


func _point_supported(point: Dictionary) -> bool:
	return cat != "motherboard" or bool(_standoffs.get(str(point.get("hole", "")), false))


func _support_count() -> int:
	return _hole_ids().size() - _missing_holes().size()


func _seated_screws() -> int:
	var count := 0
	for step: Dictionary in steps:
		if not _screw_style(step) or step.get("style") == "loosen":
			continue
		for point: Dictionary in step.pts:
			if _point_supported(point) and float(point.c) >= 100.0 and (not _sensitive_screws() or float(point.c) <= 150.0):
				count += 1
	return count


func _can_finish_fastening(step: Dictionary) -> bool:
	if cat != "motherboard":
		return _all_seated(step)
	if _board_fault or not _extra_holes().is_empty() or _support_count() < RigRules.BOARD_MIN_SCREWS or _seated_screws() < RigRules.BOARD_MIN_SCREWS:
		return false
	for point: Dictionary in step.pts:
		if float(point.c) > 150.0:
			return false
	return true


func _has_overtight_screw(step: Dictionary) -> bool:
	if not _sensitive_screws():
		return false
	for point: Dictionary in step.pts:
		if float(point.c) > 150.0:
			return true
	return false


func _all_backed_out(step: Dictionary) -> bool:
	for point: Dictionary in step.pts:
		if float(point.c) > 0.0:
			return false
	return true


func _missing_holes() -> Array[String]:
	var result: Array[String] = []
	for id in _hole_ids():
		if not bool(_standoffs.get(id, false)):
			result.append(id)
	return result


func _extra_holes() -> Array[String]:
	var result: Array[String] = []
	for id: String in _standoffs:
		if bool(_standoffs[id]) and id not in _hole_ids() and _board_pcb_rect(BOARD_RECT).has_point(_hole_pos(id)):
			result.append(id)
	return result


func _primary_pressed() -> void:
	if _pending_damage or _destroyed or _committed:
		return
	if _done:
		_committed = true
		completed.emit({"slips": slips, "mount_quality": _mount_quality(), "paste_amount": _paste_amount,
			"screws_seated": _seated_screws(), "supports": _support_count() if cat == "motherboard" else 0})
		return
	var step: Dictionary = steps[si]
	if step.kind == "board_check":
		if _support_count() < RigRules.BOARD_MIN_SCREWS:
			note = "Not enough supports."
			note_err = false
			return
	elif _screw_style(step) and not _can_finish_fastening(step):
		return
	_advance()


func _secondary_pressed() -> void:
	if _pending_damage or _destroyed or _done:
		return
	var step: Dictionary = steps[si]
	if step.kind == "paste":
		_paste_amount = 0.0
		_paste_spots.clear()
	elif cat == "motherboard" and si >= 2:
		if _screw_style(step) and not _all_backed_out(step):
			note = "DO: Hold right mouse: back every started screw out to 0%.\nDON'T: Lift the board until all screws are out."
			note_err = true
			return
		_board_fault = false
		si = 0
		steps[1].pos = Vector2(645, 220)
		for point: Dictionary in steps[3].pts:
			point.c = 0.0
			point.damaged = false
		_enter()
		if not _repair_extras.is_empty():
			note = "The suspect support is marked on the tray."
	_refresh_controls()


func _retry_requires_backout() -> bool:
	return cat == "motherboard" and _board_fault and not _all_backed_out(steps[3])


func _retry_pressed() -> void:
	if not _pending_damage and not _destroyed and not _committed and not _retry_requires_backout():
		_reset_attempt()


func _refresh_controls() -> void:
	if not is_node_ready():
		return
	_hint.text = note
	_hint.add_theme_font_override("font", K.body())
	_hint.add_theme_color_override("font_color", K.DANGER if note_err else K.CREAM)
	var status := "%sdamage %d/%d · %s" % ["CPU " if cat == "cpu" else "", _strikes, MAX_STRIKES,
		"DESTROYED" if _destroyed and not _socket_destroyed else "condition %d/100" % _condition]
	var screw_total := int(RigRules.ASSEMBLY_SCREWS.get(cat, 0))
	var seated := _seated_screws()
	if screw_total > 0:
		status += " · screws %d/%d" % [seated, screw_total]
	status += " · mistakes %d" % int(_context.get("modifiers", {}).get("assembly_mistakes", 0))
	if cat == "motherboard":
		status += "\nBuild quality: %d/%d matching supports · %d/%d seated screws" % [_support_count(), _hole_ids().size(), seated, screw_total]
	var board_strikes := 0
	if cat == "cpu":
		var board: Dictionary = _context.get("installed", {}).get("motherboard", {})
		board_strikes = MAX_STRIKES if _socket_destroyed else int(board.get("assembly_strikes", 0))
		status += "\nMotherboard damage %d/%d · %s" % [board_strikes, MAX_STRIKES,
			"DESTROYED" if _socket_destroyed else "condition %d/100" % int(board.get("condition", 100))]
	var paste_stage_reached := cat == "cpu" and si >= 3
	if paste_stage_reached:
		var preview := _preview()
		var paste_loss := roundi((1.0 - float(preview.paste_multiplier)) * 100)
		status += "\nAfter install: paste " + ("has no penalty" if paste_loss == 0 else "−%d%% CPU performance" % paste_loss)
		if _done or steps[si].get("style") == "cooler":
			var mount_loss := roundi((1.0 - float(preview.mount_headroom_multiplier)) * 100)
			status += " · mount " + ("has no penalty" if mount_loss == 0 else "−%d%% OC headroom, +%.0f°C" % [mount_loss, float(preview.mount_temperature_penalty)])
	if _pending_damage:
		status += " · awaiting host"
	_penalties.text = status
	var penalty_active := _strikes > 0 or board_strikes > 0 or (paste_stage_reached and (_paste_amount < 1.0 or _mount_quality() < 0.999))
	_penalties.add_theme_color_override("font_color", K.ORANGE if penalty_active else K.MUTED)
	var blocked := _pending_damage or _destroyed or _committed
	var primary_visible := _done and not _destroyed
	var primary_disabled := blocked
	var primary_text := "APPLY REINSTALLATION" if _context.get("reinstall", false) else "INSTALL"
	var primary_style: StringName = &"PrimaryButton"
	if cat == "motherboard" and si >= 3:
		primary_text += " · %d/%d SCREWS" % [seated, screw_total]
		if seated < screw_total:
			primary_style = &"AssemblyPartialButton"
	var secondary_visible := false
	var secondary_disabled := blocked
	var secondary_text := ""
	if not _done and not _destroyed and not steps.is_empty():
		var step: Dictionary = steps[si]
		primary_visible = step.kind in ["standoffs", "board_check", "paste"] or _screw_style(step)
		if step.kind == "standoffs":
			primary_text = "LOWER BOARD"
		elif step.kind == "board_check":
			primary_text = "START SCREWS"
			primary_disabled = blocked or _support_count() < RigRules.BOARD_MIN_SCREWS
		elif step.kind == "paste":
			primary_text = "FIT COOLER · PASTE %d%%" % roundi(minf(_paste_amount, 1.0) * 100)
			secondary_visible = true
			secondary_text = "CLEAR PASTE"
		elif _screw_style(step):
			primary_text = "CONTINUE" + (" · %d/%d SCREWS" % [seated, screw_total] if cat == "motherboard" else "")
			primary_disabled = blocked or not _can_finish_fastening(step)
		if cat == "motherboard" and si >= 2:
			secondary_visible = true
			secondary_text = "LIFT BOARD"
			secondary_disabled = blocked or (_screw_style(step) and not _all_backed_out(step))
	# Apply each final state once: hiding/re-showing a button every frame cancels clicks.
	_primary.visible = primary_visible
	_primary.disabled = primary_disabled
	_primary.text = primary_text
	_primary.theme_type_variation = primary_style
	_primary.tooltip_text = ""
	if primary_disabled and not blocked and not steps.is_empty():
		var current: Dictionary = steps[mini(si, steps.size() - 1)]
		if current.kind == "board_check":
			_primary.tooltip_text = "Not enough supports."
		elif _screw_style(current):
			_primary.tooltip_text = "Correct the screw tension first." if _board_fault or _has_overtight_screw(current) else "Not enough screws."
	_secondary.tooltip_text = "Back out the started screws before lifting." if secondary_disabled and secondary_text == "LIFT BOARD" else ""
	_secondary.visible = secondary_visible
	_secondary.disabled = secondary_disabled
	_secondary.text = secondary_text
	_retry.visible = not _destroyed and not _committed
	_retry.disabled = blocked or _retry_requires_backout()


func _gui_input(event: InputEvent) -> void:
	if _destroyed or _pending_damage or _done or steps.is_empty():
		return
	var step: Dictionary = steps[si]
	if event is InputEventMouseMotion:
		_mouse = event.position
		if _dragging:
			var now := Time.get_ticks_usec()
			var elapsed := maxf(0.001, float(now - _last_motion_us) / 1000000.0)
			_last_motion_us = now
			var previous: Vector2 = step.pos
			step.pos = (_mouse - _grab).clamp(Vector2(45, 65), Vector2(W - 45, 380))
			_drag_speed = Vector2(step.pos).distance_to(previous) / elapsed
			if step.kind == "gpu_drag" and previous.y < step.target.y and step.pos.y >= step.target.y:
				if absf(step.pos.x - step.target.x) <= float(step.tol):
					_seat_gpu(step, _drag_speed)
				else:
					step.pos.y = step.target.y - 8.0
	elif event is InputEventMouseButton:
		_mouse = event.position
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				_press(step, event.button_index == MOUSE_BUTTON_RIGHT)
			else:
				_release(step)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_rotate(step)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_R, KEY_Q, KEY_E]:
			_rotate(step)
			accept_event()
		elif event.keycode == KEY_ESCAPE:
			cancelled.emit()
			accept_event()
	_refresh_controls()
	queue_redraw()


func _press(step: Dictionary, right: bool) -> void:
	if cat == "cpu" and si == 1 and _uses_load_plate() and _socket_pins_rect().has_point(_mouse):
		var cpu_rect := Rect2(Vector2(step.pos) - CPU_PACKAGE_SIZE * 0.5, CPU_PACKAGE_SIZE)
		if not cpu_rect.has_point(_mouse):
			_request_damage("socket_pins", "The exposed pins took damage. Handle the CPU by its edges.\nMatch the gold corner, then seat it without touching the pins.")
			return
	if _screw_style(step):
		if cat == "motherboard" and _board_fault and not right:
			return
		for i in step.pts.size():
			if _mouse.distance_to(step.pts[i].p) <= 18.0:
				if not _point_supported(step.pts[i]):
					note = "No standoff under this hole."
					note_err = false
					return
				if cat == "motherboard" and not _board_fault:
					note = str(step.hint)
					note_err = false
				_held_screw = i
				_screw_direction = -1.0 if right else 1.0
				return
	elif right:
		_rotate(step)
	elif step.kind == "standoffs":
		for id: String in HOLES:
			if _mouse.distance_to(_hole_pos(id)) <= 9.0:
				_standoffs[id] = not bool(_standoffs.get(id, false))
				if not bool(_standoffs[id]) and id in _repair_extras:
					_repair_extras.erase(id)
					if _repair_extras.is_empty():
						note = str(step.hint)
						note_err = false
				return
	elif step.kind == "paste":
		_held_paste = CPU_PASTE_RECT.has_point(_mouse)
	elif step.kind == "clicks":
		for point: Dictionary in step.pts:
			if float(point.c) < float(point.n) and _mouse.distance_to(point.p) <= float(point.r) + 4:
				point.c = float(point.c) + 1.0
				for other: Dictionary in step.pts:
					if float(other.c) < float(other.n):
						return
				_advance()
				return
	elif step.kind in ["drag", "gpu_drag"]:
		var half := _part_size(step) * 0.5 + Vector2(8, 8)
		if Rect2(Vector2(step.pos) - half, half * 2).has_point(_mouse):
			_dragging = true
			_grab = _mouse - Vector2(step.pos)
			_last_motion_us = Time.get_ticks_usec()
			_drag_speed = 0.0


func _part_size(step: Dictionary, at_target: bool = false) -> Vector2:
	if step.get("part") == "board":
		return BOARD_RECT.size * (1.0 if at_target or Vector2(step.pos).distance_to(BOARD_TARGET) < 30 else 0.57)
	if step.get("part") == "cooler":
		return Vector2(176, 176)
	if step.kind == "gpu_drag":
		return _gpu_texture().get_size() * GPU_ART_SCALE
	if cat == "cpu":
		return CPU_PACKAGE_SIZE
	if step.get("part") == "psu":
		return PSU_SIZE * (1.0 if at_target or Vector2(step.pos).distance_to(PSU_TARGET) < 30 else 0.8)
	var extent := PartArt.drawing_size(cat, item, float(step.scale))
	return Vector2(extent.y, extent.x) if int(step.rot) % 2 != 0 else extent


func _release(step: Dictionary) -> void:
	_held_screw = -1
	_held_paste = false
	if not _dragging:
		return
	_dragging = false
	if Vector2(step.pos).distance_to(step.target) <= float(step.tol):
		if int(step.inc) > 0 and int(step.rot) % 4 != 0:
			note = "DO: R / right-click to match the gold triangle or notch.\nDON'T: Seat the part in this orientation."
			note_err = true
			return
		if step.kind == "gpu_drag":
			var age := float(Time.get_ticks_usec() - _last_motion_us) / 1000000.0
			_seat_gpu(step, _drag_speed if age < 0.18 else 0.0)
		else:
			step.pos = step.target
			_advance()


func _seat_gpu(step: Dictionary, speed: float) -> void:
	_dragging = false
	if speed > GPU_SAFE_SPEED:
		step.pos = Vector2(step.target) - Vector2(0, 100)
		_request_damage("gpu_impact", "DO: Try again; align the connector and lower gently.\nDON'T: Hit the slot fast. One permanent damage strike added.")
	else:
		step.pos = step.target
		_advance()


func rotate_current() -> void:
	if rotation_available() and not _pending_damage:
		_rotate(steps[si])
		queue_redraw()


func _rotate(step: Dictionary) -> void:
	if int(step.get("inc", 0)) > 0:
		step.rot = (int(step.rot) + int(step.inc)) % 4


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0, _flash - delta)
	if not is_visible_in_tree() or _done or _destroyed or _pending_damage or steps.is_empty():
		queue_redraw()
		return
	var step: Dictionary = steps[si]
	if _held_paste:
		if CPU_PASTE_RECT.has_point(_mouse):
			_paste_amount = minf(3.0, _paste_amount + delta * 0.6)
			if _paste_spots.size() < 128 and (_paste_spots.is_empty() or _paste_spots[-1].distance_to(_mouse) > 10):
				_paste_spots.append(_mouse)
	if _held_screw >= 0 and _screw_style(step):
		var point: Dictionary = step.pts[_held_screw]
		if _mouse.distance_to(point.p) > 24:
			_held_screw = -1
			_screw_direction = 0.0
		var next_tightness := clampf(float(point.c) + _screw_direction * SCREW_RATE * delta, 0, 200)
		if cat == "motherboard" and _screw_direction > 0.0:
			if _board_fault:
				_stop_holding()
				_refresh_controls()
				queue_redraw()
				return
			if next_tightness > 50.0 and not _extra_holes().is_empty():
				point.c = 50.0
				_board_fault = true
				_repair_extras = _extra_holes()
				_request_damage("extra_standoff", "Something is pressing against the board.\nBack out the started screws before lifting it to inspect.")
				queue_redraw()
				return
		point.c = next_tightness
		if _board_fault and _all_backed_out(step):
			note = "The screws are released. The board can be lifted."
			note_err = false
		if float(point.c) < 145:
			point.damaged = false
		if step.style == "cooler":
			var low := 200.0
			var high := 0.0
			for screw: Dictionary in step.pts:
				low = minf(low, float(screw.c))
				high = maxf(high, float(screw.c))
			if low < 80 and high >= 95:
				_worst_pressure_spread = maxf(_worst_pressure_spread, high - low)
				if _mount_quality() < 0.999:
					note = "DO: Retry to fix uneven mounting; see the penalty below.\nDON'T: Expect matching final tightness to erase uneven turns."
					note_err = true
		if _sensitive_screws() and float(point.c) > 150 and not bool(point.damaged):
			point.damaged = true
			_request_damage("overtighten", "DO: Hold right mouse back to 100–150%; one damage strike added.\nDON'T: Expect Retry to repair physical damage.")
	_refresh_controls()
	queue_redraw()


func _txt(pos: Vector2, text: String, font_size: int, color: Color, bold: bool = false) -> void:
	draw_string(K.mono_bold() if bold else K.mono(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), K.NAVY0)
	for x in range(0, int(W), 30):
		draw_line(Vector2(x, 0), Vector2(x, 390), Color(K.LINE, 0.2))
	for y in range(0, 390, 30):
		draw_line(Vector2(0, y), Vector2(W, y), Color(K.LINE, 0.2))
	if steps.is_empty():
		return
	_scene()
	for i in mini(si + 1, steps.size()):
		_draw_step(steps[i], i == si and not _done and not _destroyed)
	if cat == "motherboard" and si >= 2:
		_draw_board_errors()
	var title := "REVIEW INSTALLATION" if _done else str(steps[si].title)
	if _destroyed:
		title = "MOTHERBOARD DESTROYED" if _socket_destroyed else "PART DESTROYED"
	_txt(Vector2(16, 24), title, 18, K.DANGER if _destroyed else K.cat_color(cat), true)
	draw_rect(Rect2(0, 394, W, H - 394), K.NAVY1)
	draw_line(Vector2(0, 394), Vector2(W, 394), K.LINE)
	if _flash > 0:
		draw_rect(Rect2(0, 32, W, 360), Color(K.DANGER, _flash * 0.3))


func _scene() -> void:
	draw_rect(CASE_RECT, Color("0b1738"))
	draw_rect(CASE_RECT, K.LINE, false, 2)
	_txt(Vector2(42, 384), "CASE / INSTALLED HARDWARE", 10, K.FAINT)
	if cat != "gpu":
		draw_rect(Rect2(540, 40, 220, 330), Color(K.PANEL, 0.5))
		_txt(Vector2(550, 58), "PARTS BENCH", 10, K.FAINT)
	match cat:
		"cpu":
			var socket_open := si in [1, 2]
			if _uses_load_plate():
				var texture: Texture2D = Art.SOCKET_OPEN if socket_open else (Art.SOCKET_WITH_CPU if si >= 3 else Art.SOCKET_CLOSED)
				var origin := CPU_TARGET - SOCKET_CPU_ANCHOR * SOCKET_ART_SCALE
				draw_texture_rect(texture, Rect2(origin, texture.get_size() * SOCKET_ART_SCALE), false)
				_txt(Vector2(550, 90), "LGA · LOAD PLATE", 11, K.SKY)
			else:
				PartArt.draw_part(self, Transform2D(0, Vector2(2.6, 2.6), 0, CPU_TARGET), "motherboard", _context.get("installed", {}).get("motherboard", {}), K.cat_color("motherboard").darkened(0.35), 0.9)
				var socket_rect := Rect2(CPU_TARGET - Vector2(62, 62), Vector2(124, 124))
				draw_rect(socket_rect, K.NAVY0)
				draw_rect(socket_rect, K.FAINT, false, 5)
				for i in 8:
					for j in 8:
						draw_circle(CPU_TARGET - Vector2(48, 48) + Vector2(i, j) * 13.7, 1.6, Color("c9b176"))
				draw_colored_polygon(PackedVector2Array([socket_rect.position, socket_rect.position + Vector2(20, 0), socket_rect.position + Vector2(0, 20)]), Color("d9b95d"))
				draw_line(CPU_TARGET + Vector2(68, 40), _cpu_lever_position(socket_open), K.CREAM, 5)
				_txt(Vector2(550, 90), "PGA · RETENTION LEVER", 11, K.SKY)
		"gpu":
			draw_rect(Rect2(70, 80, 420, 265), K.LINE, false, 4)
			draw_rect(Rect2(75, 295, 405, 45), K.cat_color("motherboard").darkened(0.6))
			draw_rect(GPU_SLOT_RECT, K.NAVY0)
			draw_rect(GPU_SLOT_RECT, K.LIME, false, 2)
			_txt(Vector2(GPU_SLOT_RECT.position.x, 359), "PCIe SLOT BELOW", 11, K.FAINT)
			_txt(Vector2(540, 100), "FAN-SIDE VIEW", 11, K.SKY, true)
			_txt(Vector2(540, 124), "Lower slowly.", 11, K.MUTED)
			_txt(Vector2(540, 144), "Latch locks on seating.", 11, K.MUTED)
			draw_rect(Rect2(GPU_LATCH - Vector2(10, 7) - (Vector2(0, 12) if si == 1 else Vector2.ZERO), Vector2(20, 14)), K.ORANGE if si < 2 else K.LIME_DIM)
		"ram":
			draw_rect(Rect2(130, 300, 420, 26), K.NAVY0)
			draw_rect(Rect2(130, 300, 420, 26), K.cat_color(cat), false, 2)
			draw_rect(Rect2(335, 324, 10, 8), K.LIME)
			for x in [118, 562]:
				draw_rect(Rect2(x - 10, 296, 20, 34), K.ORANGE if si == 0 else K.LIME_DIM)
		"psu":
			draw_rect(Rect2(PSU_TARGET - PSU_SIZE * 0.5, PSU_SIZE), K.FAINT, false, 3)
			for hole in PSU_HOLES:
				draw_arc(PSU_TARGET + hole, 8, 0, TAU, 16, K.LIME, 2)
			_txt(Vector2(60, 200), "PSU REAR / CASE MOUNT", 10, K.FAINT)
		"storage":
			draw_rect(Rect2(250, 100, 250, 210), K.FAINT, false, 3)


func _draw_board(center: Vector2, scale_factor: float, alpha: float = 1.0) -> void:
	var rect := Rect2(center - BOARD_RECT.size * scale_factor * 0.5, BOARD_RECT.size * scale_factor)
	var board_rect := _board_pcb_rect(rect)
	draw_rect(board_rect, Color(K.cat_color("motherboard").darkened(0.55), alpha))
	draw_rect(board_rect, Color(K.cat_color("motherboard"), alpha), false, 2)
	draw_rect(Rect2(rect.position + rect.size * Vector2(0.53, 0.2), rect.size * Vector2(0.23, 0.26)), Color(K.FAINT, alpha))
	# Expansion slots run toward the same top/rear edge as the I/O ports.
	for i in 3:
		draw_rect(Rect2(rect.position + rect.size * Vector2(0.52 + i * 0.1, 0.55), rect.size * Vector2(0.035, 0.34)), Color(K.NAVY0, alpha))
	_draw_rear_edge(rect, alpha)
	for id in _hole_ids():
		var at := rect.position + Vector2(HOLES[id]) * rect.size
		draw_circle(at, 5.0 * scale_factor, Color(K.NAVY0, alpha))
		draw_arc(at, 7.0 * scale_factor, 0, TAU, 16, Color(K.CREAM, alpha), 1)
		_txt(at + Vector2(7, -8), id, 10, Color(K.CREAM, alpha))


func _draw_rear_edge(rect: Rect2, alpha: float = 1.0) -> void:
	var start := rect.position + Vector2(rect.size.x * 0.5, 0)
	var end := rect.position + Vector2(rect.size.x * 0.9, 0)
	draw_line(start, end, Color(K.SKY, alpha), 6)
	for i in 4:
		var at := start.lerp(end, (i + 0.5) / 4.0)
		draw_line(at - Vector2(0, 3), at + Vector2(0, 3), Color(K.NAVY0, alpha), 3)
	_txt(start + Vector2(0, -10), "REAR I/O", 10, Color(K.SKY, alpha))


func _draw_board_errors() -> void:
	var pulse := 0.45 + 0.55 * absf(sin(_t * 5))
	# Only highlight faults discovered through resistance, not optional unfilled holes.
	for id in _repair_extras:
		var at := _hole_pos(id)
		draw_circle(at, 9, Color(K.DANGER, pulse))
		draw_arc(at, 13, 0, TAU, 20, K.DANGER, 2)
		_txt(at + Vector2(-4, 4), "!", 13, K.CREAM, true)


func _draw_gpu(center: Vector2) -> void:
	var texture := _gpu_texture()
	var extent := texture.get_size() * GPU_ART_SCALE
	draw_texture_rect(texture, Rect2(center - extent * 0.5, extent), false)


func _draw_cpu(center: Vector2, turns: int) -> void:
	draw_set_transform_matrix(Transform2D(float(turns) * PI / 2, Vector2.ONE, 0, center))
	var extent := Art.CPU_CLOSEUP.get_size() * CPU_ART_SCALE
	draw_texture_rect(Art.CPU_CLOSEUP, Rect2(-extent * 0.5, extent), false)
	var corner := -CPU_PACKAGE_SIZE * 0.5
	draw_colored_polygon(PackedVector2Array([corner, corner + Vector2(10, 0), corner + Vector2(0, 10)]), Color("d9b95d"))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_psu(center: Vector2, scale_factor: float) -> void:
	draw_set_transform_matrix(Transform2D(0, Vector2(scale_factor, scale_factor), 0, center))
	draw_rect(Rect2(-PSU_SIZE * 0.5, PSU_SIZE), K.PANEL2)
	draw_rect(Rect2(-PSU_SIZE * 0.5, PSU_SIZE), K.CREAM, false, 2)
	for x in 8:
		for y in 6:
			draw_circle(Vector2(-83 + x * 13, -37 + y * 13), 3, K.NAVY0)
	draw_rect(Rect2(35, -8, 55, 34), K.NAVY0)
	for x in 3:
		draw_line(Vector2(46 + x * 13, 2), Vector2(46 + x * 13, 15), K.CREAM, 3)
	draw_rect(Rect2(50, -39, 28, 17), K.NAVY0)
	for hole in PSU_HOLES:
		draw_circle(hole, 6, K.NAVY0)
		draw_arc(hole, 7, 0, TAU, 16, K.CREAM, 1)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_cooler(center: Vector2) -> void:
	for offset in [Vector2(-88, -88), Vector2(88, -88), Vector2(-88, 88), Vector2(88, 88)]:
		draw_line(center, center + offset, K.LINE, 12)
		draw_circle(center + offset, 8, K.FAINT)
		draw_circle(center + offset, 4, K.NAVY0)
	draw_rect(Rect2(center - Vector2(72, 72), Vector2(144, 144)), K.FAINT)
	for i in 12:
		draw_line(center + Vector2(-67, -64 + i * 12), center + Vector2(67, -64 + i * 12), K.CREAM, 2)
	draw_circle(center, 54, K.NAVY0)
	for i in 8:
		var angle := i * TAU / 8
		draw_line(center, center + Vector2(cos(angle), sin(angle)) * 46, K.LINE, 12)
	draw_circle(center, 13, K.SKY)


func _draw_step(step: Dictionary, active: bool) -> void:
	match str(step.kind):
		"standoffs":
			_draw_rear_edge(BOARD_RECT)
			for id: String in HOLES:
				var at := _hole_pos(id)
				draw_circle(at, 6, K.NAVY0)
				draw_arc(at, 8, 0, TAU, 20, K.FAINT, 1)
				if bool(_standoffs.get(id, false)):
					draw_circle(at, 7, Color("d9a441"))
					draw_circle(at, 3, K.NAVY0)
					if id in _repair_extras:
						draw_arc(at, 11, 0, TAU, 24, K.ORANGE, 2)
				if active:
					_txt(at + Vector2(-4, -12), id, 10, K.MUTED)
			if active:
				_draw_board(Vector2(645, 220), 0.57)
				_txt(Vector2(550, 326), "%s MOUNTING HOLES" % item.get("form", "ATX"), 10, K.SKY)
				_txt(Vector2(550, 345), "Same view: rear at top", 10, K.MUTED)
		"paste":
			if _paste_amount > 0:
				var radius := 8.0 + 22.0 * sqrt(minf(_paste_amount, 2.0))
				var at := CPU_TARGET if _paste_spots.is_empty() else _paste_spots[0]
				draw_circle(at, radius, Color("bfc4d6"))
				for spot in _paste_spots:
					draw_circle(spot, minf(10, radius), Color("bfc4d6"))
			if active:
				_txt(Vector2(550, 200), "Paste applied: %d%%" % roundi(_paste_amount * 100), 13, K.SKY)
				_txt(Vector2(550, 224), "100% is enough.", 11, K.MUTED)
				_txt(Vector2(550, 245), "Extra: no penalty.", 11, K.MUTED)
		"clicks":
			for point: Dictionary in step.pts:
				var at: Vector2 = point.p
				if _screw_style(step):
					if not _point_supported(point):
						continue
					var value := float(point.c)
					var color := K.DANGER if _sensitive_screws() and value > 150 else (K.LIME if value >= 100 else K.CREAM)
					if step.style == "loosen":
						color = K.LIME if value <= 0 else K.CREAM
					draw_circle(at, 8, K.FAINT if value == 0 and not active else color)
					draw_line(at - Vector2(5, 0), at + Vector2(5, 0), K.NAVY0, 2)
					if active:
						draw_arc(at, 12, -PI / 2, -PI / 2 + TAU * minf(1, value / 100), 24, color, 2)
						_txt(at + Vector2(-13, 25), "%d%%" % roundi(value), 10, color)
				elif active and float(point.c) < float(point.n):
					draw_arc(at, float(point.r) + sin(_t * 5) * 2, 0, TAU, 24, K.LIME, 2)
					if int(point.n) > 1:
						_txt(at + Vector2(-4, 4), str(int(point.n) - int(point.c)), 13, K.LIME)
		"drag", "gpu_drag":
			var pos: Vector2 = step.pos
			if active:
				var target: Vector2 = step.target
				var outline := Rect2(target - _part_size(step, true) * 0.5, _part_size(step, true))
				draw_rect(outline, Color(K.LIME, 0.08))
				draw_rect(outline, K.LIME, false, 1)
			if step.get("part") == "board":
				_draw_board(pos, 1.0 if pos.distance_to(BOARD_TARGET) < 30 else 0.57)
			elif step.get("part") == "cooler":
				_draw_cooler(pos)
			elif step.get("part") == "psu":
				_draw_psu(pos, 1.0 if pos.distance_to(PSU_TARGET) < 30 else 0.8)
			elif step.kind == "gpu_drag":
				_draw_gpu(pos)
			elif cat == "cpu":
				# The closed LGA texture already includes the seated CPU under its plate.
				if not _uses_load_plate() or si < 3:
					_draw_cpu(pos, int(step.rot))
			else:
				var transform := Transform2D(float(step.rot) * PI / 2, Vector2(step.scale, step.scale), 0, pos)
				PartArt.draw_part(self, transform, cat, item, K.cat_color(cat), 1)
			if active and int(step.inc) > 0:
				_txt(pos + Vector2(-60, 95), "R / right-click: rotate", 10, K.ORANGE if int(step.rot) % 4 != 0 else K.LIME)
