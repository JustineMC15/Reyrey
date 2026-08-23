extends StaticBody2D
class_name BreakableFloor

## Only reacts to Martyr's Drop (ground slam) impacts — a sword or
## dash will not budge it. Falls away permanently once slammed,
## opening a shortcut downward.
##
## Requires the player.gd patch (see player_patch_notes.md) so
## deal_ground_slam_damage() calls slam_break() on this group.
##
## Scene:
##   CollisionShape2D — collision_layer = 1
##   TileMapLayer     — optional visual
##   Sprite2D         — optional alternative visual
##   BreakSound       — optional AudioStreamPlayer2D
##
## If using TileMapLayer, it should contain only this floor's tiles.

@export var floor_id: String = ""
@export var respawn_on_reload: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: CanvasItem = (
	$TileMapLayer if has_node("TileMapLayer")
	else $Sprite2D if has_node("Sprite2D")
	else null
)
@onready var break_sound: AudioStreamPlayer2D = $BreakSound if has_node("BreakSound") else null


func _ready() -> void:
	add_to_group("slam_breakable")

	if not respawn_on_reload and GameState.is_obstacle_broken(floor_id):
		queue_free()


func slam_break() -> void:
	if not respawn_on_reload:
		GameState.break_obstacle(floor_id)

	collision_shape.set_deferred("disabled", true)

	if break_sound:
		break_sound.play()

	if visual:
		var tween := create_tween()
		tween.tween_property(visual, "position:y", visual.position.y + 40.0, 0.3)
		tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.3)
		await tween.finished

	if break_sound and break_sound.playing:
		await break_sound.finished

	queue_free()
