extends Control
## Solo-first setup; networking is an optional expandable section.
signal solo_requested(player_name: String, budget: int, objective: String)
signal host_requested(player_name: String)
signal join_requested(address: String, player_name: String)
const K = preload("res://src/ui/ui_kit.gd")
const PartArt = preload("res://src/ui/part_art.gd")
const Setup = preload("res://src/ui/match_setup.gd")
const BUDGETS = Setup.BUDGETS
const OBJECTIVES = Setup.OBJECTIVES
const STEPS = Setup.STEPS
var _name_edit: LineEdit
var _budget_opt: OptionButton
var _obj_opt: OptionButton
var _obj_desc: Label
var _addr_edit: LineEdit
var _menu_status: Label


func _ready() -> void:
	var sc := K.scroll()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sc)
	var mc := MarginContainer.new()
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right"]:
		mc.add_theme_constant_override("margin_" + s, 48)
	mc.add_theme_constant_override("margin_top", 36)
	mc.add_theme_constant_override("margin_bottom", 28)
	sc.add_child(mc)
	var h := K.hbox(36)
	mc.add_child(h)
	# hero side
	var hero := K.vbox(14)
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.size_flags_stretch_ratio = 1.25
	hero.add_child(K.lbl("3 DAYS. ONE BUDGET. A PILE OF USED PARTS.", "Eyebrow"))
	hero.add_child(K.lbl("SLOPYARD WARS", "Display"))
	hero.add_child(K.lbl("Hunt classifieds, haggle with eccentric sellers, drive across town for the parts, assemble the rig by hand, overclock it to the edge and out-benchmark your rivals.", "Muted", null, true))
	var art := Control.new()
	art.custom_minimum_size = Vector2(0, 150)
	art.draw.connect(func():
		var cats := ["cpu", "gpu", "ram", "motherboard", "storage"]
		var w: float = art.size.x
		for i in cats.size():
			var c: String = cats[i]
			var xf := Transform2D(deg_to_rad(-6 + i * 3.0), Vector2(1.5, 1.5), 0.0, Vector2(w * (0.1 + 0.2 * i), 80 + (i % 2) * 14))
			PartArt.draw_part(art, xf, c, {"category": c, "name": "ssd"}, K.cat_color(c), 1.0))
	art.resized.connect(art.queue_redraw)
	hero.add_child(art)
	hero.add_child(K.lbl("HOW IT WORKS", "Eyebrow"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for s in STEPS:
		var p := K.panel("CardTight")
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := K.vbox(2)
		v.add_child(K.lbl(String(s[0]), "Mono", K.LIME))
		v.add_child(K.lbl(String(s[1]), "Muted", null, true))
		p.add_child(v)
		grid.add_child(p)
	hero.add_child(grid)
	h.add_child(hero)
	# setup side
	var card := K.panel("Hero")
	card.size_flags_horizontal = Control.SIZE_FILL
	card.custom_minimum_size.x = 430
	var v := K.vbox(10)
	v.add_child(K.lbl("PLAYER", "Eyebrow"))
	_name_edit = LineEdit.new()
	_name_edit.text = "Scrapper"
	_name_edit.max_length = 16
	v.add_child(_name_edit)
	v.add_child(K.hrule())
	v.add_child(K.lbl("SOLO RUN", "Eyebrow"))
	var r1 := K.hbox(8)
	r1.add_child(K.lbl("Budget", "Muted"))
	_budget_opt = OptionButton.new()
	for b in BUDGETS:
		_budget_opt.add_item(K.money(b))
	_budget_opt.select(2)
	_budget_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(_budget_opt)
	v.add_child(r1)
	var r2 := K.hbox(8)
	r2.add_child(K.lbl("Goal", "Muted"))
	_obj_opt = OptionButton.new()
	for o in OBJECTIVES:
		_obj_opt.add_item(o)
	_obj_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(_obj_opt)
	v.add_child(r2)
	_obj_desc = K.lbl(String(OBJECTIVES["Balanced"]), "Tiny", K.SKY, true)
	v.add_child(_obj_desc)
	_obj_opt.item_selected.connect(func(i: int): _obj_desc.text = String(OBJECTIVES[_obj_opt.get_item_text(i)]))
	var solo := K.btn("PLAY SOLO", "PrimaryButton", func(): _start_solo())
	solo.custom_minimum_size.y = 46
	v.add_child(solo)
	v.add_child(K.hrule())
	var lan_toggle := K.btn("LAN MULTIPLAYER (EXPERIMENTAL)", "GhostButton")
	v.add_child(lan_toggle)
	var lan := K.vbox(8)
	lan.visible = false
	v.add_child(lan)
	lan_toggle.pressed.connect(func(): lan.visible = not lan.visible)
	lan.add_child(K.btn("HOST A GAME", "", func(): host_requested.emit(_pname())))
	var r3 := K.hbox(8)
	_addr_edit = LineEdit.new()
	_addr_edit.placeholder_text = "Host address, e.g. 192.168.1.20"
	_addr_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_addr_edit.text_submitted.connect(func(_t: String): join_requested.emit(_addr_edit.text, _pname()))
	r3.add_child(_addr_edit)
	r3.add_child(K.btn("JOIN", "", func(): join_requested.emit(_addr_edit.text, _pname())))
	lan.add_child(r3)
	lan.add_child(K.lbl("Same network, UDP port 24680. Players compete for the same shared listings: whoever arrives first gets the part.", "Tiny", K.MUTED, true))
	_menu_status = K.lbl("", "Tiny", K.ORANGE, true)
	v.add_child(_menu_status)
	card.add_child(v)
	h.add_child(card)


func _pname() -> String:
	var n := _name_edit.text.strip_edges()
	return n if n != "" else "Scrapper"


func _start_solo() -> void:
	solo_requested.emit(_pname(), int(BUDGETS[_budget_opt.selected]), _obj_opt.get_item_text(_obj_opt.selected))


func refresh() -> void:
	_menu_status.text = "Seller dialogue: " + Game.seller_status()
