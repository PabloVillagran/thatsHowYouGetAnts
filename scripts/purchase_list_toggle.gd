extends Button

@onready var unit_list: VBoxContainer = get_node("../PurchaseScroll/PurchaseMenu/UnitList")
@onready var upgrade_list: VBoxContainer = get_node("../PurchaseScroll/PurchaseMenu/UpgradeList")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	pressed.connect(_toggle_lists)
	_refresh_label()


func _toggle_lists() -> void:
	var show_units := not unit_list.visible
	unit_list.visible = show_units
	upgrade_list.visible = not show_units
	_refresh_label()


func _refresh_label() -> void:
	text = "units" if upgrade_list.visible else "upgrades"
