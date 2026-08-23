extends Node


# The AudioStreamPlayer inside music.tscn.
@onready var music_player: AudioStreamPlayer = $AudioStreamPlayer


# The music track currently being played.
var current_music: AudioStream = null


# The music that belongs to the current room.
#
# This is kept separate from current_music because current_music may
# temporarily contain the battle music during an enemy gauntlet.
var room_music: AudioStream = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func play_music(track: AudioStream, fade_time: float = 1.0) -> void:
	# Remember this as the current room's music.
	room_music = track

	# Don't restart the same song if it is already playing.
	if track == current_music and music_player.playing:
		return

	current_music = track

	# Fade out the current song first.
	if music_player.playing:
		var fade_out := create_tween()
		fade_out.tween_property(
			music_player,
			"volume_db",
			-40.0,
			fade_time
		)
		await fade_out.finished

	# Set and play the new song.
	music_player.stream = track
	music_player.volume_db = -40.0
	music_player.play()

	# Fade in the new song.
	var fade_in := create_tween()
	fade_in.tween_property(
		music_player,
		"volume_db",
		0.0,
		fade_time
	)


func play_battle_music(
	track: AudioStream,
	fade_time: float = 1.0
) -> void:
	# Don't restart the battle music if it is already playing.
	if track == current_music and music_player.playing:
		return

	current_music = track

	# Fade out the room music first.
	if music_player.playing:
		var fade_out := create_tween()
		fade_out.tween_property(
			music_player,
			"volume_db",
			-40.0,
			fade_time
		)
		await fade_out.finished

	# Play battle music.
	music_player.stream = track
	music_player.volume_db = -40.0
	music_player.play()

	# Fade battle music in.
	var fade_in := create_tween()
	fade_in.tween_property(
		music_player,
		"volume_db",
		0.0,
		fade_time
	)


func restore_room_music(fade_time: float = 1.0) -> void:
	# There is no room music assigned.
	if room_music == null:
		stop_music(fade_time)
		return

	# Already playing the room music.
	if current_music == room_music and music_player.playing:
		return

	current_music = room_music

	# Fade out battle music.
	if music_player.playing:
		var fade_out := create_tween()
		fade_out.tween_property(
			music_player,
			"volume_db",
			-40.0,
			fade_time
		)
		await fade_out.finished

	# Play the room music again.
	music_player.stream = room_music
	music_player.volume_db = -40.0
	music_player.play()

	# Fade it back in.
	var fade_in := create_tween()
	fade_in.tween_property(
		music_player,
		"volume_db",
		0.0,
		fade_time
	)


func stop_music(fade_time: float = 1.0) -> void:
	if not music_player.playing:
		return

	var fade_out := create_tween()
	fade_out.tween_property(
		music_player,
		"volume_db",
		-40.0,
		fade_time
	)

	await fade_out.finished

	music_player.stop()
	current_music = null
