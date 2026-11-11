extends RefCounted
## One prop renderer for live depth-sorted scenery and opaque static map snapshots.
const Art = preload("res://src/ui/art_library.gd")
const K = preload("res://src/ui/ui_kit.gd")


static func draw_prop(canvas: Node2D, prop: Dictionary, show_labels: bool = true, alpha: float = 1.0) -> void:
	var tint := Color(1, 1, 1, alpha)
	if prop.kind == "sign":
		var at: Vector2 = prop.pos - Vector2(0, 4)
		var text: String = prop.text
		var text_width := K.world_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		canvas.draw_rect(Rect2(at + Vector2(-2, -38), Vector2(4, 42)), Color("75676a"))
		canvas.draw_rect(Rect2(at + Vector2(-(text_width + 8) * 0.5, -50), Vector2(text_width + 8, 12)), Color("f0dfac"))
		if show_labels:
			canvas.draw_string(K.world_font(), (at + Vector2(-text_width * 0.5, -41)).round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("30474e"))
		return
	canvas.draw_texture_rect(Art.WORLD[prop.key], prop.rect, false, tint)
	if prop.kind == "activity":
		var activity: Resource = prop.activity
		var at: Vector2 = activity.position
		if activity.overlay_art_key != "":
			var extent: Vector2 = activity.overlay_art_size
			canvas.draw_texture_rect(Art.WORLD[activity.overlay_art_key], Rect2(at - Vector2(extent.x / 2, extent.y - 4), extent), false, tint)
		if show_labels:
			_centered_label(canvas, at + Vector2(0, 16), activity.map_label, alpha)
	elif prop.kind == "building" and prop.key == "house_blue" and prop.rect.get_center().x == 496:
		if show_labels:
			_centered_label(canvas, Vector2(496, 254), "YOUR HOME", alpha)


static func _centered_label(canvas: Node2D, at: Vector2, text: String, alpha: float = 1.0) -> void:
	var width := K.world_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	canvas.draw_string(K.world_font(), (at - Vector2(width / 2, 0)).round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.188, 0.278, 0.306, alpha))


static func obscures_local(prop: Dictionary, at: Vector2, body: Rect2 = Rect2()) -> bool:
	# Small props/posts remain opaque even when they overlap part of the sprite.
	if prop.kind not in ["tree", "building", "activity", "furniture"] or at.y >= prop.pos.y:
		return false
	var cover: Rect2 = prop.rect
	if prop.kind == "tree":
		cover = cover.grow_individual(-10, -12, -8, -16)
	elif prop.kind == "building":
		cover = cover.grow_individual(-12, -26, -12, -6)
	elif prop.kind == "furniture":
		if prop.key not in ["bed", "bookshelf"]:
			return false
		cover = cover.grow_individual(-6, -6, -6, -4)
	else:
		var activity: Resource = prop.activity
		# Visible source bounds, not transparent PNG margins or the interaction ring.
		var visible := {"lucky_shrine": Rect2(8, 36, 114, 92), "salvage_bin": Rect2(16, 36, 102, 90),
			"dust_clinic": Rect2(18, 32, 106, 94), "paste_club": Rect2(6, 24, 116, 98),
			"advice_board": Rect2(12, 16, 106, 108)}
		var source: Rect2 = visible.get(prop.key, Rect2(16, 24, 96, 104))
		cover = Rect2(cover.position + source.position * cover.size / 128.0, source.size * cover.size / 128.0)
		if activity.overlay_art_key != "":
			var extent: Vector2 = activity.overlay_art_size
			cover = cover.merge(Rect2(activity.position - Vector2(extent.x / 2, extent.y - 4), extent))
	if cover.size.x < 32 or cover.size.y < 46:
		return false
	# Only near-whole body coverage yields transparency, never a mere intersection.
	return cover.encloses(body if body.has_area() else Rect2(at - Vector2(5, 25), Vector2(10, 23)))
