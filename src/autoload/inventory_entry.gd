# inventory_entry.gd, attached to the PanelContainer root
extends PanelContainer

@onready var icon_rect: TextureRect = $HBox/Icon
@onready var name_label: Label = $HBox/VBox/NameLabel
@onready var description_label: Label = $HBox/VBox/DescriptionLabel

func setup(icon: Texture2D, entry_name: String, description_lines: Array) -> void:
	if icon:
		icon_rect.texture = icon
	name_label.text = entry_name
	description_label.text = "\n\n".join(description_lines)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
