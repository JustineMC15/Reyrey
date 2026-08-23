extends StaticBody2D
class_name ShortcutObject

## Any blocking piece — door, bridge, ladder, or breakable wall —
## that permanently opens once its shortcut_id has been activated by
## a ShortcutLever elsewhere in the world. Mechanically these are all
## the same thing (a blocker that becomes passable); only the visual
## and CollisionShape2D you author differ per use.
##
## Scene:
##   CollisionShape2D — collision_layer = 1
##   TileMapLayer     — optional visual
##   Sprite2D         — optional alternative visual
##   OpenSound        — optional AudioStreamPlayer2D, plays the
##                      moment it opens (never on the silent
##                      reload-from-save path)
##
## If using TileMapLayer, it should contain only this shortcut object's
## tiles.

@export var shortcut_id: String = ""
@export var fade_duration: float = 0.4

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: CanvasItem = (
	$TileMapLayer if has_node("TileMapLayer")
	else $Sprite2D if has_node("Sprite2D")
	else null
)
@onready var open_sound: AudioStreamPlayer2D = $OpenSound if has_node("OpenSound") else null


func _ready() -> void:
	GameState.shortcut_activated.connect(_on_shortcut_activated)

	if GameState.is_shortcut_activated(shortcut_id):
		_open(true)


func _on_shortcut_activated(activated_id: String) -> void:
	if activated_id != shortcut_id:
		return

	_open(false)


func _open(instant: bool) -> void:
	collision_shape.set_deferred("disabled", true)

	if not instant and open_sound:
		open_sound.play()

	if not visual:
		return

	if instant:
		visual.modulate.a = 0.15
		return

	var tween := create_tween()
	tween.tween_property(
		visual,
		"modulate:a",
		0.15,
		fade_duration
	)
