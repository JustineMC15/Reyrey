extends Node


# The AudioStreamPlayer inside music.tscn.
@onready var music_player: AudioStreamPlayer = $AudioStreamPlayer


# The music track currently being played.
# This prevents the same song from restarting when changing rooms.
var current_music: AudioStream = null


func play_music(track: AudioStream, fade_time: float = 1.0) -> void:
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
