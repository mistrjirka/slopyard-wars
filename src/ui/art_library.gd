extends RefCounted
## Explicit preloads make every art dependency exportable. No runtime directory scans.

## Assembly close-ups supplied alongside the inventory thumbnails.
const CPU_CLOSEUP = preload("res://assets/computer_parts/cpus/close_up/cpu_closeup.png")
const SOCKET_OPEN = preload("res://assets/computer_parts/cpus/close_up/socket_open.png")
const SOCKET_CLOSED = preload("res://assets/computer_parts/cpus/close_up/socket_closed.png")
const SOCKET_WITH_CPU = preload("res://assets/computer_parts/cpus/close_up/socket_closed_with_cpu.png")
const GPU_FAN_SIDES: Array[Texture2D] = [
	preload("res://assets/computer_parts/graphics_cards/gpu_fan_side_2_fans.png"),
	preload("res://assets/computer_parts/graphics_cards/gpu_fan_side_3_fans.png"),
]

const PARTS = {
	"case": [preload("res://assets/computer_parts/cases/case_a.png"), preload("res://assets/computer_parts/cases/case_b.png"), preload("res://assets/computer_parts/cases/case_detail_a.png"), preload("res://assets/computer_parts/cases/case_detail_b.png")],
	"cpu": [preload("res://assets/computer_parts/cpus/cpu_a.png"), preload("res://assets/computer_parts/cpus/cpu_b.png"), preload("res://assets/computer_parts/cpus/cpu_detail_a.png"), preload("res://assets/computer_parts/cpus/cpu_detail_b.png")],
	"gpu": [preload("res://assets/computer_parts/graphics_cards/gpu_a.png"), preload("res://assets/computer_parts/graphics_cards/gpu_b.png"), preload("res://assets/computer_parts/graphics_cards/gpu_detail_a.png"), preload("res://assets/computer_parts/graphics_cards/gpu_detail_b.png")],
	"motherboard": [preload("res://assets/computer_parts/motherboards/motherboard_a.png"), preload("res://assets/computer_parts/motherboards/motherboard_b.png"), preload("res://assets/computer_parts/motherboards/motherboard_detail_a.png"), preload("res://assets/computer_parts/motherboards/motherboard_detail_b.png")],
	"ram": [preload("res://assets/computer_parts/memory/ram_a.png"), preload("res://assets/computer_parts/memory/ram_b.png"), preload("res://assets/computer_parts/memory/ram_detail_a.png"), preload("res://assets/computer_parts/memory/ram_detail_b.png")],
	"psu": [preload("res://assets/computer_parts/power_supplies/psu_a.png"), preload("res://assets/computer_parts/power_supplies/psu_b.png"), preload("res://assets/computer_parts/power_supplies/psu_detail_a.png"), preload("res://assets/computer_parts/power_supplies/psu_detail_b.png")],
	"storage": [preload("res://assets/computer_parts/storage/storage_a.png"), preload("res://assets/computer_parts/storage/storage_b.png"), preload("res://assets/computer_parts/storage/storage_detail_a.png"), preload("res://assets/computer_parts/storage/storage_detail_b.png")],
}

const WORLD = {
	"lucky_shrine": preload("res://assets/world_activities/lucky_shrine.png"),
	"salvage_bin": preload("res://assets/world_activities/salvage_bin.png"),
	"dust_clinic": preload("res://assets/world_activities/dust_clinic.png"),
	"paste_club": preload("res://assets/world_activities/paste_club.png"),
	"advice_board": preload("res://assets/world_activities/advice_board.png"),
	"house_blue": preload("res://assets/buildings/house_blue.png"),
	"house_garage": preload("res://assets/buildings/house_garage.png"),
	"house_green": preload("res://assets/buildings/house_green.png"),
	"house_purple_porch": preload("res://assets/buildings/house_purple_porch.png"),
	"house_red_dormer": preload("res://assets/buildings/house_red_dormer.png"),
	"shop": preload("res://assets/buildings/shop.png"),
	"statue_lucky": preload("res://assets/decorations/lucky/statue_lucky.png"),
	"statue_lucky_gpu": preload("res://assets/decorations/lucky/statue_lucky_gpu.png"),
	"desk_metal": preload("res://assets/interior/desks/desk_metal.png"),
	"desk_wood": preload("res://assets/interior/desks/desk_wood.png"),
	"bed": preload("res://assets/interior/furniture/bed.png"),
	"bookshelf": preload("res://assets/interior/furniture/bookshelf.png"),
	"box": preload("res://assets/interior/furniture/box.png"),
	"window": preload("res://assets/interior/furniture/window.png"),
	"rug_a": preload("res://assets/interior/rugs/rug_a.png"),
	"rug_b": preload("res://assets/interior/rugs/rug_b.png"),
	"bench_metal": preload("res://assets/interior/workbenches/bench_metal.png"),
	"bench_wood": preload("res://assets/interior/workbenches/bench_wood.png"),
	"floor_tile_beige": preload("res://assets/tiles/floors/floor_tile_beige.png"),
	"floor_tile_gray": preload("res://assets/tiles/floors/floor_tile_gray.png"),
	"floor_wood_dark": preload("res://assets/tiles/floors/floor_wood_dark.png"),
	"floor_wood_light": preload("res://assets/tiles/floors/floor_wood_light.png"),
	"grass_00": preload("res://assets/tiles/grass/grass_00.png"),
	"grass_01": preload("res://assets/tiles/grass/grass_01.png"),
	"grass_02": preload("res://assets/tiles/grass/grass_02.png"),
	"grass_03": preload("res://assets/tiles/grass/grass_03.png"),
	"grass_04": preload("res://assets/tiles/grass/grass_04.png"),
	"grass_05": preload("res://assets/tiles/grass/grass_05.png"),
	"road_corner": preload("res://assets/tiles/roads/road_corner.png"),
	"road_cross": preload("res://assets/tiles/roads/road_cross.png"),
	"road_straight": preload("res://assets/tiles/roads/road_straight.png"),
	"bush_a": preload("res://assets/vegetation/bushes/bush_a.png"),
	"bush_b": preload("res://assets/vegetation/bushes/bush_b.png"),
	"bush_c": preload("res://assets/vegetation/bushes/bush_c.png"),
	"tree_a": preload("res://assets/vegetation/trees/tree_a.png"),
	"tree_b": preload("res://assets/vegetation/trees/tree_b.png"),
	"tree_c": preload("res://assets/vegetation/trees/tree_c.png"),
	"car_front": preload("res://assets/vehicles/car_front.png"),
	"car_rear": preload("res://assets/vehicles/car_rear.png"),
	"car_side": preload("res://assets/vehicles/car_side.png"),
	"car_top": preload("res://assets/vehicles/car_top.png"),
}


static func part(category: String, item: Dictionary, detailed: bool = false) -> Texture2D:
	var variants: Array = PARTS.get(category, PARTS.cpu)
	var variant := posmod(str(item.get("name", category)).hash(), 2)
	if category == "storage":
		variant = 0 if "HDD" in str(item.get("name", "")) else 1
	return variants[variant + (2 if detailed else 0)]
