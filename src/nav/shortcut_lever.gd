extends Area2D
class_name ShortcutLever

## A one-time-use lever. Once pulled, permanently activates
## shortcut_id — every ShortcutObject sharing that id (a door,
## bridge, ladder, or breakable wall) opens for the rest of the save
## file. Use one lever with several ShortcutObjects sharing the same
## id if pulling it should open more than one blocker at once.
##
## Scene: this node IS the Area2D (collision_layer = 4,
## collision_mask = 5). Drag your prompt Panel into `prompt_panel`.
##
## Visual can be either TileMapLayer or Sprite2D.

@export var shortcut_id: String = ""
@export var prompt_panel: Panel

@onready var visual: CanvasItem = (
	$TileMapLayer if has_node("TileMapLayer")
	else $Sprite2D if has_node("Sprite2D")
	else null
)

var player_inside := false
var _pulled := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	if prompt_panel:
		prompt_panel.modulate.a = 0.0
		prompt_panel.hide()

	if GameState.is_shortcut_activated(shortcut_id):
		_pulled = true
		_set_pulled_look()


func _process(_delta: float) -> void:
	if _pulled or not player_inside:
		return

	if Input.is_action_just_pressed("interact"):
		_pulled = true

		if prompt_panel:
			prompt_panel.hide()

		GameState.activate_shortcut(shortcut_id)
		_set_pulled_look()


func _set_pulled_look() -> void:
	if visual:
		visual.modulate = Color(0.7, 0.7, 0.7, 1.0)


func _on_area_entered(area: Area2D) -> void:
	if _pulled or not area.is_in_group("player_detection"):
		return

	player_inside = true

	if not prompt_panel:
		return

	prompt_panel.show()
	var tween := create_tween()
	tween.tween_property(prompt_panel, "modulate:a", 1.0, 0.25)


func _on_area_exited(area: Area2D) -> void:
	if _pulled or not area.is_in_group("player_detection"):
		return

	player_inside = false

	if not prompt_panel:
		return

	var tween := create_tween()
	tween.tween_property(prompt_panel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(prompt_panel.hide)
