extends Button
class_name SaveSlotCard

signal picked(slot: int)

@onready var preview_rect: TextureRect = $Preview
@onready var label: Label = $Label

var slot: int = 0

func setup_empty(slot_number: int) -> void:
	slot = slot_number
	preview_rect.texture = load(AreaPreviews.FALLBACK)
	label.text = "Slot %d — New Game" % slot_number

func setup_from_save(slot_number: int, info: Dictionary) -> void:
	slot = slot_number
	preview_rect.texture = load(AreaPreviews.get_preview_path(info.get("checkpoint_scene_path", "")))
	label.text = "Slot %d — %s (%d shrines)" % [
		slot_number, info.get("room_name", "?"), info.get("shrine_count", 0)
	]

func _ready() -> void:
	pressed.connect(func(): picked.emit(slot))
