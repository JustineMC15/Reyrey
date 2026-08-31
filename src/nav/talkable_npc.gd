extends Area2D
class_name TalkableNPC

## Press E in range to talk.
##
## Dialogue behavior:
## - Words reveal automatically one at a time.
## - Press E while a line is revealing to instantly finish it.
## - Press E again to advance to the next line.
## - The first conversation goes through every line normally.
## - After the first conversation is finished, talking again only shows
##   the final dialogue line.
##
## Scene children expected:
##   CollisionShape2D
##   AnimatedSprite2D — optional
##   TalkSound — optional AudioStreamPlayer2D
##
## UI:
##   PromptPanel
##     └── Label
##
##   DialoguePanel
##     └── MarginContainer
##         └── VBoxContainer
##             ├── SpeakerLabel
##             └── DialogueLabel

@export_multiline var dialogue_lines: Array[String] = []

@export var speaker_name := ""

@export var prompt_panel: Panel
@export var dialogue_panel: Panel
@export var speaker_label: Label
@export var dialogue_label: Label

## Time between each revealed word.
@export var word_delay := 0.06

## Fade time for opening/closing the dialogue box.
@export var dialogue_fade_time := 0.2

@onready var animated_sprite: AnimatedSprite2D = \
	$AnimatedSprite2D if has_node("AnimatedSprite2D") else null

@onready var talk_sound: AudioStreamPlayer2D = \
	$TalkSound if has_node("TalkSound") else null

var player_inside := false
var is_talking := false
var current_line := 0

var is_revealing := false
var reveal_id := 0

## Becomes true after the NPC's full dialogue has been completed once.
var has_finished_dialogue := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	if prompt_panel:
		prompt_panel.modulate.a = 0.0
		prompt_panel.hide()

	if dialogue_panel:
		dialogue_panel.modulate.a = 0.0
		dialogue_panel.hide()

	if speaker_label:
		speaker_label.text = speaker_name
		speaker_label.visible = not speaker_name.is_empty()
		speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	if dialogue_label:
		dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		dialogue_label.visible_characters = -1

	_play_idle()


func _process(_delta: float) -> void:
	if not player_inside or dialogue_lines.is_empty():
		return

	if not Input.is_action_just_pressed("interact"):
		return

	if not is_talking:
		_start_talking()
		return

	if is_revealing:
		_finish_reveal()
		return

	_advance_line()


func _start_talking() -> void:
	is_talking = true

	# First conversation starts at line 0.
	# Every conversation after that starts on the final line.
	if has_finished_dialogue:
		current_line = dialogue_lines.size() - 1
	else:
		current_line = 0

	_hide_prompt()
	_show_line()
	_play_talk()


func _advance_line() -> void:
	if current_line < dialogue_lines.size() - 1:
		current_line += 1
		_show_line()
	else:
		# Dialogue is now completely finished.
		has_finished_dialogue = true
		_end_talking()


func _show_line() -> void:
	if not dialogue_label:
		return

	reveal_id += 1
	var this_reveal_id := reveal_id

	var line := dialogue_lines[current_line]

	dialogue_label.text = line
	dialogue_label.visible_characters = 0

	if speaker_label:
		speaker_label.text = speaker_name
		speaker_label.visible = not speaker_name.is_empty()
		speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	if talk_sound:
		talk_sound.play()

	is_revealing = true

	if dialogue_panel:
		dialogue_panel.show()

		var fade_tween := create_tween()
		fade_tween.tween_property(
			dialogue_panel,
			"modulate:a",
			1.0,
			dialogue_fade_time
		)

	_reveal_words(line, this_reveal_id)


func _reveal_words(line: String, this_reveal_id: int) -> void:
	var word_end_positions: Array[int] = []

	var in_word := false

	for i in range(line.length()):
		var character := line.substr(i, 1)

		var is_separator := (
			character == " "
			or character == "\n"
			or character == "\t"
			or character == "\r"
		)

		if not is_separator:
			in_word = true
		elif in_word:
			word_end_positions.append(i)
			in_word = false

	if in_word:
		word_end_positions.append(line.length())

	if word_end_positions.is_empty():
		_finish_reveal()
		return

	for end_position in word_end_positions:
		if this_reveal_id != reveal_id:
			return

		if not is_revealing:
			return

		dialogue_label.visible_characters = end_position

		await get_tree().create_timer(word_delay).timeout

	if this_reveal_id != reveal_id:
		return

	if is_revealing:
		_finish_reveal()


func _finish_reveal() -> void:
	reveal_id += 1

	if dialogue_label:
		dialogue_label.visible_characters = -1

	is_revealing = false


func _end_talking() -> void:
	reveal_id += 1
	is_revealing = false
	is_talking = false

	_play_idle()

	if dialogue_panel:
		var tween := create_tween()

		tween.tween_property(
			dialogue_panel,
			"modulate:a",
			0.0,
			dialogue_fade_time
		)

		tween.tween_callback(dialogue_panel.hide)

	if player_inside:
		_show_prompt()


func _play_talk() -> void:
	if animated_sprite \
	and animated_sprite.sprite_frames \
	and animated_sprite.sprite_frames.has_animation("talk"):
		animated_sprite.play("talk")


func _play_idle() -> void:
	if animated_sprite \
	and animated_sprite.sprite_frames \
	and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	player_inside = true

	if not is_talking:
		_show_prompt()


func _on_area_exited(area: Area2D) -> void:
	if not area.is_in_group("player_detection"):
		return

	player_inside = false

	_hide_prompt()

	if is_talking:
		_end_talking()


func _show_prompt() -> void:
	if not prompt_panel:
		return

	prompt_panel.show()

	var tween := create_tween()

	tween.tween_property(
		prompt_panel,
		"modulate:a",
		1.0,
		0.25
	)


func _hide_prompt() -> void:
	if not prompt_panel:
		return

	var tween := create_tween()

	tween.tween_property(
		prompt_panel,
		"modulate:a",
		0.0,
		0.25
	)

	tween.tween_callback(prompt_panel.hide)
