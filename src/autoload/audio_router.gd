extends Node

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
