extends Resource
## Editor-authored hardware specification; runtime ownership lives in match dictionaries.
@export_enum("case", "psu", "cpu", "motherboard", "gpu", "ram", "storage") var category: String
@export var display_name: String
@export_range(1, 5000, 1) var base_price: int = 10
@export var stats: Dictionary = {}
@export var model_id: StringName
@export var manufacturer: String
@export var product_family: String
@export_multiline var buying_notes: String
@export_range(1, 100) var condition_min := 75
@export_range(1, 100) var condition_max := 100
## Maximum extra clock under ideal conditions, e.g. 0.25 = +25%.
@export_range(0.0, 0.6) var oc_potential := 0.0
@export_range(1.05, 1.4) var voltage_limit := 1.3
@export_range(0.5, 2.0) var thermal_load := 1.0
## Fictional model reliability flaw: base failure chance per stress test/final benchmark, even at stock.
@export_range(0.0, 0.5) var stock_failure_chance := 0.0
## Fictional connector-fire probability at stock; zero disables this failure mode.
@export_range(0.0, 0.5) var fire_base_chance := 0.0
## Extra fire probability per unit of clock * voltage squared above stock power.
@export_range(0.0, 0.5) var fire_power_sensitivity := 0.0
## Case airflow / board VRM / PSU regulation, depending on category.
@export_range(0, 100) var support_quality := 50
@export var stock_clock_mhz := 0
@export var capacity_gb := 0
@export var cores := 0
