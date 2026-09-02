extends Node
# audio_router.gd — autoload singleton "AudioRouter"
#
# Routes every AudioStreamPlayer / AudioStreamPlayer2D /
# AudioStreamPlayer3D under a given node onto the "SFX" bus, so the
# Settings "Sound Volume" slider controls checkpoint chimes, chest
# opens, footsteps, enemy hits, etc. without hand-editing the Bus
# field on every sound node in every scene. Nodes already explicitly
# wired to the "Music" bus (i.e. Music.gd's own player) are left
# alone.
#
# Requires an "SFX" child bus (and a "Music" child bus, for Music.gd)
# to exist under Master in the project's Audio panel — a one-time
# editor setup step, not something a script can create. Until "SFX"
# exists, route_to_sfx_bus() is a no-op and everything just stays on
# Master, same as before.

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"


func route_to_sfx_bus(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return

	if AudioServer.get_bus_index(SFX_BUS) == -1:
		return

	_route_recursive(root)


func _route_recursive(node: Node) -> void:
	if (
		node is AudioStreamPlayer
		or node is AudioStreamPlayer2D
		or node is AudioStreamPlayer3D
	):
		if node.bus != MUSIC_BUS:
			node.bus = SFX_BUS

	for child in node.get_children():
		_route_recursive(child)
