extends Button
class_name InventoryIconButton

## A single inventory slot. Moving the mouse over this button, or
## reaching it via arrow-key focus navigation, both select it —
## mouse hover just grabs keyboard focus under the hood, so both
## input methods share one highlight (this node's "Focus" style
## override in the Inspector) and one signal.
##
## Resize/reposition this button freely in the 2D viewport — its
## parent is a plain Control, not a layout container, so nothing
## snaps it back. The icon auto-shrinks to fit whatever box you draw,
## because Icon's Expand Mode is "Ignore Size": the source image's
## own resolution never forces this button bigger than you want it.
##
## Border look lives entirely in Theme Overrides -> Styles on this
## node (Normal / Hover / Focus / Pressed). Swap any of them for a
## StyleBoxTexture pointing at hand-drawn border art later — no
## script changes needed.

signal hovered(id: String)

## Set on the currency slot only. Appended after the number shown by
## set_count(), e.g. " Fragments".
@export var count_suffix: String = ""

var item_id: String = ""

@onready var icon_rect: TextureRect = $Icon
@onready var count_label: Label = $CountLabel if has_node("CountLabel") else null


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(_on_mouse_entered)
	focus_entered.connect(_on_focus_entered)


func setup(id: String, icon: Texture2D) -> void:
	item_id = id
	icon_rect.texture = icon


func set_count(amount: int) -> void:
	if not count_label:
		return

	count_label.text = str(amount) + count_suffix
	count_label.show()


func _on_mouse_entered() -> void:
	grab_focus()


func _on_focus_entered() -> void:
	hovered.emit(item_id)
