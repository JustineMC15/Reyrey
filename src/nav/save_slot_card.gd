extends Button
class_name SaveSlotCard

## Layout lives in the "Layout" VBoxContainer. Resize the card via
## SlotCard's Custom Minimum Size; rebalance preview vs. label space
## via Size Flags → Stretch Ratio on Preview/Label in the Inspector.

signal picked(slot: int)

@onready var preview_rect: TextureRect = $Layout/Preview
@onready var label: Label = $Layout/Label

var slot: int = 0


func setup_empty(slot_number: int) -> void:
	slot = slot_number

	preview_rect.texture = load(AreaPreviews.FALLBACK)
	label.text = "Slot %d — New Game" % slot_number


func setup_from_save(slot_number: int, info: Dictionary) -> void:
	slot = slot_number

	preview_rect.texture = load(
		AreaPreviews.get_preview_path(
			info.get("area_id", -1)
		)
	)

	label.text = "Slot %d — %s" % [
		slot_number,
		info.get("area", "Unknown Area")
	]


func _ready() -> void:
	pressed.connect(func(): picked.emit(slot))
