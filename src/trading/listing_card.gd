extends PanelContainer
## Authored marketplace listing card. All rows are scene children; setup() only binds data.
const PartArt = preload("res://src/ui/part_art.gd")
const Stats = preload("res://src/data/hardware_stats.gd")

@onready var content: VBoxContainer = $Content
@onready var blocked_banner: Label = $Content/BlockedBanner
@onready var art: PartArt = $Content/Summary/Art
@onready var price_label: Label = $Content/Summary/Info/Price
@onready var name_label: Label = $Content/Summary/Info/Name
@onready var detail_label: Label = $Content/Detail
@onready var fault_label: Label = $Content/Fault
@onready var fire_label: Label = $Content/Fire
@onready var value_label: Label = $Content/Value
@onready var seller_label: Label = $Content/Seller
@onready var action_label: Label = $Content/Action


func setup(item: Dictionary, blocked: bool) -> void:
	tooltip_text = Stats.performance_text(item) + "\n" + Stats.value_text(item)
	if blocked:
		tooltip_text += "\nThis seller blocked you for this run. View the conversation only; messaging and buying are unavailable."
	action_label.text = "View conversation  ›" if blocked else "Message seller  ›"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	blocked_banner.visible = blocked
	art.show_item(item)
	art.modulate = Color(0.55, 0.55, 0.55) if blocked else Color.WHITE
	price_label.text = "$%d" % int(item.price)
	name_label.text = str(item.get("manufacturer", "")) + " " + str(item.name)
	var detail := "Condition %d/100" % int(item.get("condition", 100))
	if str(item.category) in ["cpu", "gpu", "ram", "storage"]:
		detail += " · stock %d" % roundi(Stats.stock_score(item))
	if float(item.get("oc_potential", 0)) > 0:
		detail += " · OC +%d%%" % roundi(float(item.oc_potential) * 100)
	detail_label.text = detail
	var fault := Stats.stock_failure_chance(item)
	fault_label.visible = fault > 0
	if fault > 0:
		fault_label.text = "Reliability risk · %.1f%% at stock" % (fault * 100)
	var fire := Stats.stock_fire_chance(item)
	fire_label.visible = fire > 0
	if fire > 0:
		fire_label.text = "Connector fire risk · %.1f%% at stock" % (fire * 100)
	value_label.text = "Used-price guide $%d" % Stats.reference_price(item)
	seller_label.text = str(item.seller) + " · " + str(item.location)
