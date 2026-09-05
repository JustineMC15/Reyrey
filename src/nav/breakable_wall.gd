extends StaticBody2D
class_name BreakableWall

## Takes hits from any player attack and disappears permanently once
## its hit points reach zero. Covers "attack wall until it breaks"
## and plain "breakable wall" — max_hits = 1 gives you the latter.
##
## Scene:
##   CollisionShape2D — collision_layer = 3
##   TileMapLayer     — optional visual
##   Sprite2D         — optional alternative visual
##   HitSound         — optional AudioStreamPlayer2D, plays per hit
##   BreakSound       — optional AudioStreamPlayer2D, plays once, on break
##
## TileMapLayer should contain only the tiles belonging to this wall.

@export var wall_id: String = ""
@export var max_hits: int = 3
@export var respawn_on_reload: bool = false
## true = ignore saved broken state (re-blocks on room reload)
@export var shake_strength: float = 6.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: CanvasItem = (
	$TileMapLayer if has_node("TileMapLayer")
	else $Sprite2D if has_node("Sprite2D")
	else null
)
@onready var hit_sound: AudioStreamPlayer2D = $HitSound if has_node("HitSound") else null
@onready var break_sound: AudioStreamPlayer2D = $BreakSound if has_node("BreakSound") else null

var hits_remaining: int
var _shake_tween: Tween
var _base_visual_position: Vector2


func _ready() -> void:
	add_to_group("attackable")

	if visual:
		_base_visual_position = visual.position

	if not respawn_on_reload and GameState.is_obstacle_broken(wall_id):
		queue_free()
		return

	hits_remaining = max_hits


func take_damage(_amount: int) -> void:
	hits_remaining -= 1

	if hit_sound:
		hit_sound.play()

	_flash()
	_shake()

	if hits_remaining <= 0:
		_break()


func _flash() -> void:
	if not visual:
		return

	var tween := create_tween()
	tween.tween_property(
		visual,
		"modulate",
		Color(2, 2, 2, 1),
		0.05
	)
	tween.tween_property(
		visual,
		"modulate",
		Color.WHITE,
		0.1
	)


func _shake() -> void:
	if not visual:
		return

	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	visual.position = _base_visual_position

	_shake_tween = create_tween()

	var step_time := 0.04

	_shake_tween.tween_property(visual, "position:x", _base_visual_position.x + shake_strength, step_time)
	_shake_tween.tween_property(visual, "position:x", _base_visual_position.x - shake_strength, step_time)
	_shake_tween.tween_property(visual, "position:x", _base_visual_position.x + shake_strength * 0.6, step_time)
	_shake_tween.tween_property(visual, "position:x", _base_visual_position.x - shake_strength * 0.6, step_time)
	_shake_tween.tween_property(visual, "position:x", _base_visual_position.x, step_time)


func _break() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	if visual:
		visual.position = _base_visual_position

	if not respawn_on_reload:
		GameState.break_obstacle(wall_id)

	collision_shape.set_deferred("disabled", true)

	if break_sound:
		break_sound.play()

	if visual:
		var tween := create_tween()
		tween.tween_property(visual, "modulate:a", 0.0, 0.25)
		await tween.finished

	if break_sound and break_sound.playing:
		await break_sound.finished

	queue_free()	
