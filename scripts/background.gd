extends Node2D

@export var player: Node2D
@export var x_follow_strength := 1.0

var start_y: float

func _ready() -> void:
	start_y = global_position.y

func _process(_delta: float) -> void:
	if player:
		global_position.x = player.global_position.x * x_follow_strength
		global_position.y = start_y
