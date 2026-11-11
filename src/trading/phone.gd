extends Control
## LuckyFold app controller. Cover messages and unfolded marketplace share one conversation/draft state.
const Device = preload("res://src/trading/luckyfold_shell.gd")
const MarketplaceViewScene = preload("res://src/trading/marketplace_view.tscn")
const SellViewScene = preload("res://src/trading/sell_view.tscn")
const InboxViewScene = preload("res://src/trading/inbox_view.tscn")
const InboxRowScene = preload("res://src/trading/inbox_row.tscn")
const ThreadViewScene = preload("res://src/trading/thread_view.tscn")
const K = preload("res://src/ui/ui_kit.gd")
const Trade = preload("res://src/trading/trade_rules.gd")
const Relationships = preload("res://src/trading/contact_relationships.gd")
## The live device renders inside this phone's own capture SubViewport. Folding shows
## cached snapshots of the old and new state instead of resizing a visible device.
const FOLD_DURATION := 1.15
const SHIFT_FRACTION := 0.2
# Duo reference model units, normalized to one uniform 7.89935-unit leaf.
# The axis sits ABOVE both open displays, leaving a positive closed-screen gap.
const MODEL_LEAF := 7.89935
const INNER_Z := 0.24948 / MODEL_LEAF
const OUTER_Z := -0.27463 / MODEL_LEAF
const AXIS_Z := 0.275454 / MODEL_LEAF
const CHASSIS_BEVEL := 0.006
signal close_requested
signal fold_finished
signal track_requested(listing_id: int)
var page := "browse"
var selected := -1
var _thread_origin := "messages"
var _body: VBoxContainer
var _clock: Label
var _tabs := {}
var _sig := ""
var _composer: LineEdit
var _send: Button
var _log: VBoxContainer
var _scroll: ScrollContainer
var _context: Label
var _browse_filters := {"query": "", "category": "", "sort": "price_asc"}
var _browse_view: Control
var _sale_prices: Dictionary = {}
var _slots := false
var _drafts := {}
var _device: Control
var _nav: HBoxContainer
var _mode_button: Button
var _heading: Label
var _cover_footer_space: Control
var _screen: SubViewportContainer
var _viewport: SubViewport
var _fold: Control
var _faces := {}
var _moving_chassis: Polygon2D
var _fixed_chassis: Polygon2D
var _hinge_spine: Polygon2D
var _folding := false
var _pocket_transition := false
var _fold_generation := 0
# Main recreates GameScreen (and this phone) for each match.
var _first_unfold_pending := true
var _first_unfold_active := false
var _fold_opening := false
var _fold_progress := 0.0
var _fold_tween: Tween
var _fold_old: ImageTexture
var _fold_new: ImageTexture
var _fold_target_size := Vector2.ZERO
var _fold_open_width := 0.0
var _fold_cover_screen := Vector4(0, 0, 1, 1)
var _fold_inner_screen := Vector4(0, 0, 1, 1)
var unfolded: bool:
	get:
		return _device.unfolded


static func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _ready() -> void:
	_screen = $Screen
	_viewport = $Screen/Viewport
	_fold = $Fold
	_faces = {"cover": _fold.get_node("Cover"), "left": _fold.get_node("InnerLeft"), "right": _fold.get_node("InnerRight")}
	_moving_chassis = _fold.get_node("MovingChassis")
	_fixed_chassis = _fold.get_node("FixedChassis")
	_hinge_spine = _fold.get_node("HingeSpine")
	_fold.visible = false
	_fold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_device = $Screen/Viewport/Device
	_device.minimum_size_changed.connect(_sync_size)
	_sync_size()
	resized.connect(_on_resized)
	visibility_changed.connect(_on_visibility_changed)
	var content: VBoxContainer = _device.get_node("Inset/Content")
	_clock = content.get_node("Status/Row/Clock")
	_clock.text = ""
	_clock.theme_type_variation = "Tiny"
	var close_btn: Button = content.get_node("Status/Row/Actions/Close")
	close_btn.pressed.connect(func(): close_requested.emit())
	_heading = content.get_node("Status/Heading")
	_heading.text = "Messages"
	_heading.theme_type_variation = "H2"
	_mode_button = content.get_node("Status/Row/Actions/ModeButton")
	content.get_node("Status").resized.connect(_layout_heading)
	_mode_button.text = "Unfold"
	_mode_button.pressed.connect(_toggle_fold)
	_nav = _device.get_node("Nav")
	_body = content.get_node("Body")
	_tabs = {
		"browse": _nav.get_node("Browse"),
		"messages": _nav.get_node("Messages"),
		"sell": _nav.get_node("Sell"),
	}
	(_tabs["browse"] as Button).pressed.connect(_show.bind("browse"))
	(_tabs["messages"] as Button).pressed.connect(_open_messages)
	(_tabs["sell"] as Button).pressed.connect(_show.bind("sell"))
	_nav.hide()
	_cover_footer_space = content.get_node("CoverFooterSpace")
	# Preserve the existing content bounds after removing the pocket caption.
	_cover_footer_space.custom_minimum_size.y = ceilf(content.get_theme_font("font", "Tiny").get_height(content.get_theme_font_size("font_size", "Tiny")))


func _sync_size() -> void:
	custom_minimum_size = _device.get_combined_minimum_size()


func _layout_heading() -> void:
	# Equal side reserves keep the title centered on the phone, clear of the
	# clock and Fold/X controls. Use smaller text on the narrow cover screen.
	var actions := _mode_button.get_parent() as Control
	var clock_width := _clock.get_theme_font("font").get_string_size(_clock.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _clock.get_theme_font_size("font_size")).x
	var side := maxf(clock_width, actions.get_combined_minimum_size().x) + 8.0
	_heading.offset_left = side
	_heading.offset_right = -side
	_heading.add_theme_font_size_override("font_size", 18 if unfolded else 13)


func _toggle_fold() -> void:
	set_unfolded_animated(not unfolded)


func set_pocket_transition(active: bool) -> void:
	_pocket_transition = active
	_viewport.gui_disable_input = active or _folding


func is_folding() -> bool:
	return _folding


func _update_render_mode() -> void:
	if not is_instance_valid(_viewport):
		return
	# Visibility-based texture updates can miss a cover that starts off screen.
	# Freeze only after the fold's target snapshot is ready, never before layout.
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if not is_visible_in_tree() or (_folding and _fold_new != null) else SubViewport.UPDATE_ALWAYS


func prepare_for_reveal() -> void:
	_screen.modulate = Color.WHITE
	_update_render_mode()
	# Container sizing and the replacement cover UI must settle before rendering.
	await get_tree().process_frame
	_device.fit_content()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


## Animated unfold/fold for player input. The functional state still changes immediately,
## so drafts, focus and the fault bounds are already final while the panels move.
func set_unfolded_animated(value: bool) -> void:
	# The dummy headless renderer has no display snapshots to animate.
	if DisplayServer.get_name() == "headless":
		set_unfolded(value)
		return
	if value == unfolded:
		if _folding:
			_finish_fold()
		return
	var previous := _capture_device()
	var previous_screen := _device_screen_rect()
	if _folding:
		_finish_fold()
	set_unfolded(value)
	if value and _first_unfold_pending:
		_first_unfold_pending = false
		_first_unfold_active = true
		_device.set_display_fault_enabled(false)
	_begin_fold(previous, value, _device.custom_minimum_size, previous_screen)
	if not _folding:
		_restore_display_fault()


func set_unfolded(value: bool) -> void:
	if _folding:
		_finish_fold()
	_save_draft()
	_device.set_unfolded(value)
	_mode_button.text = "Fold" if value else "Unfold"
	_mode_button.tooltip_text = "Use the cover screen for messages" if value else "Open the full marketplace"
	_sig = ""
	refresh()


func _capture_device() -> Image:
	if not is_instance_valid(_viewport) or DisplayServer.get_name() == "headless":
		return null
	return _viewport.get_texture().get_image()


## Shows the cached old state at once, then the cached target state after it rendered once.
func _device_screen_rect() -> Vector4:
	var display := _device.get_node("Display") as Control
	return Vector4(display.position.x / _device.size.x, display.position.y / _device.size.y,
		display.size.x / _device.size.x, display.size.y / _device.size.y)


func _begin_fold(old_image: Image, value: bool, target_size: Vector2, old_screen: Vector4) -> void:
	# Any start invalidates captures that are still waiting for their frame.
	_fold_generation += 1
	if old_image == null or old_image.is_empty() or target_size.x < 1.0 or target_size.y < 1.0:
		push_warning("LuckyFold transition skipped: device capture unavailable")
		return
	_fold_old = ImageTexture.create_from_image(old_image)
	_fold_new = null
	_fold_opening = value
	_fold_target_size = target_size
	_fold_open_width = target_size.x * (1.0 if value else 2.0)
	if value:
		_fold_cover_screen = old_screen
	else:
		_fold_inner_screen = old_screen
	_fold_progress = 0.0
	_folding = true
	_assign_fold_textures()
	_screen.modulate = Color(1, 1, 1, 0)
	_viewport.gui_disable_input = true
	_update_render_mode()
	_fold.mouse_filter = Control.MOUSE_FILTER_STOP
	_fold.visible = true
	_apply_fold(0.0)
	_capture_fold_target(_fold_generation)


## Resumes one frame later. A cancellation or a newer fold bumps the generation, so a stale
## continuation cannot assign textures to or start a tween for the fold now in flight.
func _capture_fold_target(generation: int) -> void:
	# The hidden live device renders the target state once before it is cached.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not _folding or generation != _fold_generation:
		return
	var image := _capture_device()
	if image == null or image.is_empty():
		push_warning("LuckyFold transition ended early: device capture unavailable")
		_finish_fold()
		return
	_fold_new = ImageTexture.create_from_image(image)
	_update_render_mode()
	if _fold_opening:
		_fold_inner_screen = _device_screen_rect()
	else:
		_fold_cover_screen = _device_screen_rect()
	_assign_fold_textures()
	_fold_tween = create_tween()
	if _first_unfold_active:
		# Catch just beyond half open: a pause and a small resisted movement,
		# then a much faster final swing. Both inner faces are still undamaged.
		_fold_tween.tween_method(_apply_fold, 0.0, 0.65, 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_fold_tween.tween_interval(0.18)
		_fold_tween.tween_method(_apply_fold, 0.65, 0.63, 0.10)
		_fold_tween.tween_method(_apply_fold, 0.63, 0.66, 0.12)
		_fold_tween.tween_interval(0.18)
		_fold_tween.tween_method(_apply_fold, 0.66, 1.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	else:
		_fold_tween.tween_method(_apply_fold, 0.0, 1.0, FOLD_DURATION)
	_fold_tween.finished.connect(_finish_fold)


func _assign_fold_textures() -> void:
	var closed_image := _fold_old if _fold_opening else _fold_new
	var open_image := _fold_new if _fold_opening else _fold_old
	(_faces["cover"] as TextureRect).texture = closed_image
	(_faces["left"] as TextureRect).texture = open_image
	(_faces["right"] as TextureRect).texture = open_image


func _apply_fold(progress: float) -> void:
	if not _folding:
		return
	_fold_progress = progress
	# One reversible path: centered closed -> translate right -> rotate left.
	# Target layout may already be closed; express the full-open rect around its center.
	var phase := progress if _fold_opening else 1.0 - progress
	var shift := smoothstep(0.0, SHIFT_FRACTION, phase)
	var turn := PI * smoothstep(SHIFT_FRACTION, 1.0, phase)
	var half := _fold_open_width * 0.5
	var origin := (_fold_target_size.x - _fold_open_width) * 0.5
	var hinge := origin + half * (0.5 + 0.5 * shift)
	var panel := Vector2(half, _fold_target_size.y)
	_place_face("right", hinge, panel, 0.0, false, _fold_inner_screen)
	_place_face("cover", hinge, panel, turn, false, _fold_cover_screen)
	_place_face("left", hinge, panel, turn, true, _fold_inner_screen)
	# Cull the two physical face normals against the perspective eye, not a
	# timed crossfade. The solid far rail remains visible between the faces.
	(_faces["cover"] as TextureRect).visible = cos(turn) * (5.0 - AXIS_Z) + OUTER_Z - AXIS_Z > 0.00001
	(_faces["left"] as TextureRect).visible = -cos(turn) * (5.0 - AXIS_Z) - INNER_Z + AXIS_Z > 0.00001
	_update_chassis(_fixed_chassis, panel, hinge, 0.0, true)
	_update_chassis(_moving_chassis, panel, hinge, turn, false)
	_update_hinge(panel, hinge)


func _place_face(face: String, hinge: float, panel: Vector2, angle: float, backside: bool, screen_rect: Vector4) -> void:
	var rect := _faces[face] as TextureRect
	rect.position = Vector2(hinge, 0.0)
	rect.size = panel
	rect.visible = true
	var material := rect.material as ShaderMaterial
	material.set_shader_parameter("panel_size", panel)
	material.set_shader_parameter("angle", angle)
	material.set_shader_parameter("backside", backside)
	material.set_shader_parameter("screen_rect", screen_rect)


# The moving slab uses the same rotateHinge transform as the reference:
# x = cos(theta)*a + sin(theta)*(z-axis),
# z = sin(theta)*a - cos(theta)*(z-axis) + axis.
# All chassis rings and snapshot faces share this transform and projection.
static func _chassis_project(point: Vector3, panel: Vector2, angle: float, stationary: bool) -> Vector2:
	var world := point
	var reference_z := INNER_Z * panel.x
	if not stationary:
		var c := cos(angle)
		var s := sin(angle)
		var axis := AXIS_Z * panel.x
		world = Vector3(c * point.x + s * (point.z - axis), point.y, s * point.x - c * (point.z - axis) + axis)
		# Normalize at the visible resting hinge plane so cached/live endpoints
		# stay exactly 1:1 pixels despite the outside face's different Z depth.
		reference_z = lerpf(2.0 * AXIS_Z - OUTER_Z, INNER_Z, (1.0 - c) * 0.5) * panel.x
	var perspective := (panel.x * 5.0 - reference_z) / (panel.x * 5.0 - world.z)
	return Vector2(world.x, world.y) * perspective + Vector2(0.0, panel.y * 0.5)


static func _chassis_perimeter(panel: Vector2, inset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var near_radius := maxf(1.0, 3.0 - inset)
	var far_radius := maxf(1.0, 38.0 - inset)
	var centers: Array[Vector2] = [
		Vector2(inset + near_radius, -panel.y * 0.5 + inset + near_radius),
		Vector2(panel.x - inset - far_radius, -panel.y * 0.5 + inset + far_radius),
		Vector2(panel.x - inset - far_radius, panel.y * 0.5 - inset - far_radius),
		Vector2(inset + near_radius, panel.y * 0.5 - inset - near_radius),
	]
	for corner in 4:
		var radius := near_radius if corner == 0 or corner == 3 else far_radius
		for segment in 9:
			var arc := PI + corner * PI * 0.5 + segment * PI / 16.0
			points.append(centers[corner] + Vector2(cos(arc), sin(arc)) * radius)
	return points


func _update_chassis(mesh: Polygon2D, panel: Vector2, hinge: float, angle: float, stationary: bool) -> void:
	mesh.position = Vector2(hinge, 0.0)
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var surfaces: Array[PackedInt32Array] = []
	var bevel := CHASSIS_BEVEL * panel.x
	var depths: Array[float] = [OUTER_Z * panel.x, OUTER_Z * panel.x + bevel, INNER_Z * panel.x - bevel, INNER_Z * panel.x]
	var rings: Array[PackedVector2Array] = []
	for layer in 4:
		var inset := 0.0 if layer == 0 or layer == 3 else bevel * 0.45
		var perimeter := _chassis_perimeter(panel, inset)
		var ring := PackedVector2Array()
		for point in perimeter:
			ring.append(_chassis_project(Vector3(point.x, point.y, depths[layer]), panel, angle, stationary))
		rings.append(ring)
	for layer in 3:
		for edge in rings[layer].size():
			var next := (edge + 1) % rings[layer].size()
			var quad := PackedVector2Array([rings[layer][edge], rings[layer][next], rings[layer + 1][next], rings[layer + 1][edge]])
			var area := 0.0
			for i in 4:
				area += quad[i].cross(quad[(i + 1) % 4])
			# Outward sidewall winding. Back-facing walls must not paint over
			# the display; a projected convex slab supplies its own occlusion.
			if area >= -0.001:
				continue
			var base := vertices.size()
			var shade := 0.88 + 0.12 * cos(float(edge) / rings[layer].size() * TAU - 0.7)
			var metal := Color("abb5c6") if layer != 1 else Color("414957")
			for point in quad:
				vertices.append(point)
				colors.append(Color(metal.r * shade, metal.g * shade, metal.b * shade, 1.0))
			surfaces.append(PackedInt32Array([base, base + 1, base + 2, base + 3]))
	mesh.polygons = []
	mesh.vertex_colors = PackedColorArray()
	mesh.polygon = vertices
	mesh.vertex_colors = colors
	mesh.polygons = surfaces
	mesh.visible = not surfaces.is_empty()


func _update_hinge(panel: Vector2, hinge: float) -> void:
	# A narrow metal knuckle sits in the positive gap, not through either glass.
	_hinge_spine.position = Vector2(hinge, 0.0)
	var radius := (AXIS_Z - INNER_Z) * panel.x * 0.8
	var points := PackedVector2Array()
	for end in 2:
		for segment in 9:
			var arc := PI * segment / 8.0 + (PI if end == 1 else 0.0)
			points.append(Vector2(cos(arc) * radius, (panel.y - 76.0) * (0.5 if end == 0 else -0.5) + sin(arc) * radius + panel.y * 0.5))
	_hinge_spine.polygon = points


func _restore_display_fault() -> void:
	if not _first_unfold_active:
		return
	_first_unfold_active = false
	_device.set_display_fault_enabled(true)


func _finish_fold() -> void:
	var was_folding := _folding
	_restore_display_fault()
	if _fold_tween != null and _fold_tween.is_valid():
		_fold_tween.kill()
	_fold_tween = null
	_folding = false
	_fold_generation += 1
	_fold_progress = 1.0
	_fold_old = null
	_fold_new = null
	for face in _faces:
		(_faces[face] as TextureRect).texture = null
	if is_instance_valid(_fold):
		_fold.visible = false
		_fold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_screen):
		_screen.modulate = Color(1, 1, 1, 1)
	if is_instance_valid(_viewport):
		_viewport.gui_disable_input = _pocket_transition
		_update_render_mode()
	if was_folding:
		fold_finished.emit()


func _on_resized() -> void:
	if not _folding:
		return
	var target := _device.custom_minimum_size
	if target.x < 1.0 or target.y < 1.0:
		_finish_fold()
		return
	_fold_target_size = target
	_fold_open_width = target.x * (1.0 if _fold_opening else 2.0)
	_apply_fold(_fold_progress)


func _focused_text_control() -> Control:
	if not is_instance_valid(_viewport):
		return null
	var owner := _viewport.gui_get_focus_owner()
	return owner if owner is LineEdit or owner is TextEdit else null


func has_text_focus() -> bool:
	return is_visible_in_tree() and _focused_text_control() != null


func move_keyboard_focus(backwards: bool) -> void:
	if _folding or _pocket_transition or not is_visible_in_tree():
		return
	var owner := _viewport.gui_get_focus_owner()
	var target: Control = _mode_button
	if owner != null:
		target = owner.find_prev_valid_focus() if backwards else owner.find_next_valid_focus()
	if target != null:
		target.grab_focus()


func release_text_focus() -> bool:
	var owner := _focused_text_control()
	if owner == null:
		return false
	owner.release_focus()
	return true


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _folding:
		return
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	var owner := _focused_text_control()
	if owner == null:
		return
	# The focused field belongs to the capture viewport, not the host window.
	var local_mouse := _screen.make_input_local(mouse) as InputEventMouseButton
	if local_mouse != null and not owner.get_global_rect().has_point(local_mouse.position):
		owner.release_focus()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		release_text_focus()
		if _folding:
			_finish_fold()
	# Apply after the capture container updates its own visibility.
	_update_render_mode.call_deferred()


func _open_marketplace() -> void:
	_save_draft()
	page = "browse"
	set_unfolded(true)


func _open_marketplace_animated() -> void:
	_save_draft()
	page = "browse"
	set_unfolded_animated(true)


func _open_messages() -> void:
	_inbox()


func _inbox() -> void:
	_save_draft()
	_composer = null
	selected = -1
	_show("messages")


func open_listing(id: int) -> void:
	# Switching contacts inside a thread must retain the original Back destination.
	if page != "messages" or selected < 0:
		_thread_origin = page
	_save_draft()
	_composer = null
	selected = id
	_slots = false
	_show("messages")


func _back_from_thread() -> void:
	_save_draft()
	_composer = null
	selected = -1
	_show(_thread_origin)


func _show(which: String) -> void:
	_save_draft()
	page = which
	if which != "messages" and not unfolded:
		set_unfolded(true)
		return
	_sig = ""
	refresh()


func _save_draft() -> void:
	if is_instance_valid(_composer):
		_drafts[selected] = _composer.text


func _listing(id: int) -> Dictionary:
	for l in Game.state.listings:
		if int(l.id) == id:
			return l
	return {}


func refresh() -> void:
	if not is_visible_in_tree() or Game.me().is_empty():
		return
	_clock.text = Trade.stamp(Game.clock()) + "   ·   $%d" % int(Game.me().cash)
	var me: Dictionary = Game.me()
	var active_page := page if unfolded else "messages"
	var in_thread := active_page == "messages" and selected >= 0
	_heading.text = {"browse": "Marketplace", "messages": "Messages", "sell": "Sell"}.get(active_page, "Messages")
	_heading.tooltip_text = _heading.text
	_layout_heading()
	_cover_footer_space.visible = not unfolded
	_nav.visible = unfolded
	_device.set_page_layout(active_page, in_thread)
	var sig := str(unfolded) + active_page + str(selected)
	sig += str(_waiting_for_reply()) + str(me.ready)
	sig += str(me.get("contact_relations", {}))
	if active_page == "messages" and selected >= 0:
		var l := _listing(selected)
		sig += str(me.chats.get(selected, [])).sha256_text() + str(me.offers.get(selected, 0)) + str(me.counters.get(selected, 0)) + str(me.meetings.get(selected, {})) + str(me.get("meeting_proposals", {}).get(selected, {})) + str(l.get("status", "gone")) + str(l.get("buyer_contacted", true)) + str(_slots)
		if me.meetings.has(selected):
			sig += str(Game.clock() > float(me.meetings[selected].end))
		if me.get("meeting_proposals", {}).has(selected):
			sig += str(Game.clock() >= float(me.meeting_proposals[selected].end))
	elif active_page == "sell":
		sig += str(me.inventory) + str(Game.state.listings.filter(func(l): return int(l.get("owner", 0)) == Game.local_id()))
	else:
		for l in Game.state.listings:
			sig += "%d%s%d" % [l.id, l.status, l.price]
		if active_page == "messages":
			sig += str(me.chats) + str(me.meetings)
	if sig == _sig:
		return
	if active_page == "browse" and is_instance_valid(_browse_view) and _browse_view.get_parent() == _body:
		_sig = sig
		_browse_view.update_listings(Game.state.listings, me)
		return
	var refocus := is_instance_valid(_composer) and _composer.has_focus()
	var caret := _composer.caret_column if refocus else 0
	_save_draft()
	_sig = sig
	_clear(_body)
	_composer = null
	for key in _tabs:
		(_tabs[key] as Button).button_pressed = key == active_page
	if active_page == "browse":
		_browse()
	elif active_page == "sell":
		_sell()
	elif selected < 0:
		_threads()
	else:
		_thread()
	if refocus and is_instance_valid(_composer):
		_composer.grab_focus()
		_composer.caret_column = caret


func _browse() -> void:
	_browse_view = MarketplaceViewScene.instantiate()
	_body.add_child(_browse_view)
	_browse_view.setup(_browse_filters, Game.state.listings, Game.me())
	_browse_view.listing_selected.connect(open_listing)


func _threads() -> void:
	var view: VBoxContainer = InboxViewScene.instantiate()
	_body.add_child(view)
	view.set_cover_mode(unfolded)
	view.unfold_requested.connect(_open_marketplace_animated)
	if not unfolded:
		var meetings: Array = Game.active_meetings(Game.me())
		view.set_appointment("" if meetings.is_empty() else "Upcoming: " + str(meetings[0].label))
	else:
		view.set_appointment("")
	var me: Dictionary = Game.me()
	view.set_empty_visible(me.chats.is_empty())
	_populate_threads(view.box)


func _populate_threads(box: VBoxContainer, current: int = -1) -> void:
	var me: Dictionary = Game.me()
	var ids: Array = me.chats.keys()
	ids.reverse()
	if current >= 0 and not ids.has(current):
		ids.push_front(current)
	for id in ids:
		var l := _listing(int(id))
		if l.is_empty():
			continue
		var msgs: Array = me.chats.get(id, [])
		var last: String = str(msgs[-1].text) if not msgs.is_empty() else "Start a conversation"
		var width := 80 if unfolded else 38
		var row: Button = InboxRowScene.instantiate()
		box.add_child(row)
		row.setup(str(l.seller), int(l.get("owner", 0)) > 0, str(l.name).left(width), last.left(width))
		row.set_current(int(id) == current)
		row.pressed.connect(open_listing.bind(int(id)))


func _thread() -> void:
	var view: VBoxContainer = ThreadViewScene.instantiate()
	_body.add_child(view)
	view.back_pressed.connect(_back_from_thread)
	view.back_btn.text = "‹"
	var back_label: String = {"browse": "Back to marketplace", "sell": "Back to your listings", "messages": "All messages"}.get(_thread_origin, "All messages")
	view.back_btn.tooltip_text = back_label
	view.gone_back.text = back_label
	view.send_text.connect(_send_text)
	var l := _listing(selected)
	if l.is_empty():
		view.setup_gone()
		return
	var me: Dictionary = Game.me()
	var pending := false
	for msg: Dictionary in me.chats.get(selected, []):
		pending = pending or bool(msg.get("pending", false))
	view.setup(l, me, selected, _drafts, pending, _waiting_for_reply(), unfolded)
	_composer = view.composer
	_send = view.send_btn
	_log = view.log
	_scroll = view.history_scroll
	_context = view.context_label
	if unfolded:
		view.composer_row.resized.connect(_fit_message_bar.bind(weakref(view.composer_row)), CONNECT_DEFERRED)
	view.scroll_bottom_deferred()


func _fit_message_bar(row_reference: WeakRef) -> void:
	var row := row_reference.get_ref() as HBoxContainer
	if not is_instance_valid(row):
		return
	_device.set_message_bar_height(row.get_combined_minimum_size().y)
	var fault_clearance := row.get_child(0) as Control
	fault_clearance.custom_minimum_size.x = maxf(0, _device.message_text_left() - row.global_position.x - row.get_theme_constant("separation"))


func _scroll_bottom(scroll_reference: WeakRef) -> void:
	await get_tree().process_frame
	var scroll: ScrollContainer = scroll_reference.get_ref()
	if is_instance_valid(scroll) and scroll.is_inside_tree():
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _waiting_for_reply() -> bool:
	for messages: Array in Game.me().get("chats", {}).values():
		for message: Dictionary in messages:
			if message.get("pending", false):
				return true
	return false


func _send_text(text: String) -> void:
	var listing := _listing(selected)
	if text.strip_edges() == "" or listing.is_empty() or listing.status != "available" or Game.me().ready:
		return
	if _waiting_for_reply() or Relationships.blocked(Game.me(), listing):
		return
	if not is_visible_in_tree():
		return
	Game.act("chat", {"listing_id": selected, "text": text})
	_drafts[selected] = ""
	if is_instance_valid(_composer):
		_composer.text = ""


func _sell() -> void:
	var view := SellViewScene.instantiate()
	_body.add_child(view)
	view.setup(Game.me(), Game.state.listings, _sale_prices)
	view.listing_selected.connect(open_listing)
