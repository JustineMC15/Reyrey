extends Button
class_name SaveSlotCard

signal picked(slot: int)
signal delete_requested(slot: int)

@onready var preview_rect: TextureRect = $Layout/Preview
@onready var label: Label = $Layout/Label
@onready var delete_button: Button = $Layout/DeleteButton

var slot: int = 0
var has_save: bool = false


func setup_empty(slot_number: int) -> void:
	slot = slot_number
	has_save = false

	preview_rect.texture = load(AreaPreviews.FALLBACK)
	label.text = "Slot %d — New Game" % slot_number

	delete_button.hide()


func setup_from_save(slot_number: int, info: Dictionary) -> void:
	slot = slot_number
	has_save = true

	preview_rect.texture = load(
		AreaPreviews.get_preview_path(
			info.get("area_id", -1)
		)
	)

	label.text = "Slot %d — %s" % [
		slot_number,
		info.get("area", "Unknown Area")
	]

	delete_button.show()


func _ready() -> void:
	pressed.connect(func(): picked.emit(slot))
	delete_button.pressed.connect(_on_delete_pressed)


func _on_delete_pressed() -> void:
	if not has_save:
		return

	delete_requested.emit(slot)
