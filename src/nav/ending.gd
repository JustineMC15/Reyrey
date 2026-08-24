extends Area2D
class_name EndingTrigger

## Place in the telescope room at the top of the Tower. Picks which
## of the three endings to play based on shrine_count, then returns
## to the main menu.

var _triggered := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if _triggered or not area.is_in_group("player_detection"):
		return

	_triggered = true

	var lines: Array

	if GameState.shrine_count <= 0:
		lines = StoryContent.ENDING_BAD_LINES
	elif GameState.shrine_count >= 17:
		lines = StoryContent.ENDING_TRUE_LINES
	else:
		lines = StoryContent.ENDING_BASE_LINES

	await Cutscene.play(lines)

	get_tree().change_scene_to_file("res://src/nav/main_menu.tscn")
