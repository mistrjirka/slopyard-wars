extends PanelContainer
## Reusable inventory card. Data is filled by bench_view.gd.

@onready var art: Control = $Row/Art
@onready var name_label: Label = $Row/TextCol/NameLabel
@onready var spec_label: Label = $Row/TextCol/SpecLabel
@onready var status_label: Label = $Row/TextCol/StatusLabel
@onready var install_button: Button = $Row/InstallButton