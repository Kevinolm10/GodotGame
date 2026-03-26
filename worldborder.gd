extends Area3D

@onready var player = $"../MainCharacter"  
var spawn_point = Vector3(35, 1, -22)

func _ready() -> void:
	connect("body_exited", _on_body_exited)

func _on_body_exited(body) -> void:
	if body == player:
		body.global_position = spawn_point
