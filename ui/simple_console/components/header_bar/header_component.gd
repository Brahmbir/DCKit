extends "../../../ui_base_class/header_comp_base.gd"

@export var label: Label
@export var button: Button

func _ready() -> void:
	button.pressed.connect(ui_close_requested.emit)


func set_title_bar_visibility(visibility: bool):
	button.get_parent().visible = visibility
	visible = visibility
