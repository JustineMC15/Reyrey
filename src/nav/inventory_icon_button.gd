extends Button
class_name InventoryIconButton

signal picked(id: String)

var item_id: String = ""

@onready var icon_rect: TextureRect = $Icon

func setup(id: String, icon: Texture2D) -> void:
	item_id = id
	icon_rect.texture = icon
	pressed.connect(func(): picked.emit(item_id))

func set_selected(is_selected: bool) -> void:
	modulate = Color(1.3, 1.3, 1.1, 1.0) if is_selected else Color.WHITE
